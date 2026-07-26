--!strict
-- Owns the solo player's current class: spawning them with the right stats/
-- tools at the right tagged location, gating class changes behind
-- profile.Level (see ClassConfig.UnlockLevel), and handling death/respawn.
--
-- Services never require each other directly (avoids ModuleScript require
-- cycles). Main.server.lua requires every service once and calls Init(deps)
-- on each with a shared locator table; from then on a service reaches its
-- neighbors through Deps.<ServiceName>, resolved lazily at call time.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local ClassService = {}

local corpsesFolder = Instance.new("Folder")
corpsesFolder.Name = "Corpses"
corpsesFolder.Parent = Workspace

--- Clones a just-died character into a standalone, anchored "Corpse" model so
--- it survives the original character being destroyed by the respawn a moment
--- later. SCPAbilityService's SCP-049 Reanimate reads these via CollectionService
--- (both player corpses and NPC corpses NPCService creates the same way).
local function spawnCorpse(ownerName: string, ownerUserId: number, character: Model)
	local clone = character:Clone()
	clone.Name = `Corpse_{ownerName}`

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy() -- corpse has no humanoid until/unless SCP-049 reanimates it
	end

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	clone:SetAttribute("OwnerUserId", ownerUserId)
	clone:SetAttribute("OwnerName", ownerName)
	clone:SetAttribute("DiedAt", os.clock())
	clone:SetAttribute("Reanimated", false)
	CollectionService:AddTag(clone, "Corpse")
	clone.Parent = corpsesFolder

	task.delay(GameConfig.CorpseLifetimeSeconds, function()
		if clone.Parent and clone:GetAttribute("Reanimated") ~= true then
			clone:Destroy()
		end
	end)

	return clone
end

function ClassService.ClearCorpses()
	corpsesFolder:ClearAllChildren()
end

local Deps: any = nil

local playerClass: { [Player]: string } = {}
local aliveState: { [Player]: boolean } = {}

local function getSpawnPart(spawnTag: string): BasePart?
	local tagged = CollectionService:GetTagged(spawnTag)
	local parts = {}
	for _, inst in ipairs(tagged) do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
		end
	end
	if #parts == 0 then
		warn(`[ClassService] No spawn parts tagged "{spawnTag}" - falling back to world origin`)
		return nil
	end
	return parts[math.random(1, #parts)]
end

function ClassService.GetPlayerClass(player: Player): string?
	return playerClass[player]
end

function ClassService.IsAlive(player: Player): boolean
	return aliveState[player] == true
end

--- Every class whose UnlockLevel the player's profile has already met.
function ClassService.GetUnlockedClassIds(player: Player): { string }
	local profile = Deps.DataService.GetProfile(player)
	local level = profile and profile.Level or 1
	local unlocked = {}
	for _, classId in ipairs(ClassConfig._UnlockOrder) do
		if level >= ClassConfig[classId].UnlockLevel then
			table.insert(unlocked, classId)
		end
	end
	return unlocked
end

local function applyHumanoidStats(character: Model, classId: string)
	local def = ClassConfig[classId]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = def.MaxHealth
	humanoid.Health = def.MaxHealth
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.BreakJointsOnDeath = true
end

function ClassService.SpawnCharacterForClass(player: Player, classId: string)
	local def = ClassConfig[classId]
	if not def then
		warn(`[ClassService] Unknown classId "{classId}" for {player.Name}`)
		return
	end

	playerClass[player] = classId
	aliveState[player] = true

	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()

	applyHumanoidStats(character, classId)

	local spawnPart = getSpawnPart(def.SpawnTag)
	if spawnPart then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoidRootPart then
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
		end
	end

	if Deps.InventoryService then
		Deps.InventoryService.EquipStartingTools(player, def.Tools)
	end

	if Deps.SCPAbilityService then
		if def.IsSCP then
			Deps.SCPAbilityService.RegisterSCP(player, classId)
		else
			Deps.SCPAbilityService.DeregisterSCP(player)
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local diedConn: RBXScriptConnection
		diedConn = humanoid.Died:Connect(function()
			diedConn:Disconnect()
			ClassService._OnCharacterDied(player)
		end)
	end

	Remotes.ClassAssigned:FireClient(player, {
		classId = classId,
		displayName = def.DisplayName,
		description = def.Description,
		track = def.Track,
		isSCP = def.IsSCP,
	})
end

--- Server-validated class change, called from the class-change terminal /
--- menu. Silently refuses (with a toast) if the level requirement isn't met.
function ClassService.RequestClassChange(player: Player, classId: string)
	local def = ClassConfig[classId]
	if not def then
		return
	end

	local profile = Deps.DataService.GetProfile(player)
	local level = profile and profile.Level or 1
	if level < def.UnlockLevel then
		Deps.NotifyService.Toast(player, `Requires level {def.UnlockLevel} ({def.DisplayName}). You are level {level}.`, "warning")
		return
	end

	Deps.DataService.SetCurrentClass(player, classId)
	ClassService.SpawnCharacterForClass(player, classId)
	if Deps.MissionService then
		Deps.MissionService.OnClassChanged(player, classId)
	end
	Deps.NotifyService.Toast(player, `You are now: {def.DisplayName}`, "success")
end

function ClassService._OnCharacterDied(player: Player)
	if not aliveState[player] then
		return
	end
	aliveState[player] = false

	if Deps.DataService then
		Deps.DataService.IncrementStat(player, "Deaths", 1)
		Deps.DataService.AddGlint(player, -GameConfig.DeathGlintPenalty)
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and Deps.CombatService then
			Deps.CombatService.ClearAttribution(humanoid)
		end
		spawnCorpse(player.Name, player.UserId, character)
	end

	Deps.NotifyService.Toast(player, `You died. Respawning in {GameConfig.RespawnDelaySeconds}s (-{GameConfig.DeathGlintPenalty} Glint).`, "danger")

	task.delay(GameConfig.RespawnDelaySeconds, function()
		if player.Parent and not aliveState[player] then
			local classId = playerClass[player] or "DClass"
			ClassService.SpawnCharacterForClass(player, classId)
		end
	end)
end

function ClassService.Init(deps: any)
	Deps = deps

	Remotes.RequestClassChange.OnServerEvent:Connect(function(player: Player, payload: any)
		if typeof(payload) ~= "table" or typeof(payload.classId) ~= "string" then
			return
		end
		if not Deps.AntiExploitService.CheckRate(player, "RequestClassChange", 1) then
			return
		end
		ClassService.RequestClassChange(player, payload.classId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerClass[player] = nil
		aliveState[player] = nil
	end)
end

return ClassService
