--!strict
-- Assigns every player a class (SCP:SL calls these "roles"), spawns their
-- character at the right tagged location with the right stats/tools, and
-- tracks who is alive per faction so RoundService can evaluate win conditions.
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
local Enums = require(ReplicatedStorage.Shared.Modules.Enums)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local ClassService = {}

local corpsesFolder = Instance.new("Folder")
corpsesFolder.Name = "Corpses"
corpsesFolder.Parent = Workspace

--- Clones a just-died character into a standalone, anchored "Corpse" model so
--- it survives the original character being destroyed by the respawn a moment
--- later. SCPAbilityService's SCP-049 Reanimate reads these via CollectionService.
local function spawnCorpse(player: Player, character: Model)
	local clone = character:Clone()
	clone.Name = `Corpse_{player.Name}`

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

	clone:SetAttribute("OwnerUserId", player.UserId)
	clone:SetAttribute("OwnerName", player.Name)
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
local spectatorQueue: { Player } = {} -- FIFO, players waiting for a reinforcement wave

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

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

--- Builds a weighted roster for the players present at round start.
--- Returns a map of player -> classId. SCPs are chosen first (fixed order so
--- SCP-173 is always in play), remaining players split across the classes
--- available from t=0 (DClass/Scientist/Guard) proportional to RosterWeight.
function ClassService.BuildInitialRoster(players: { Player }): { [Player]: string }
	local roster: { [Player]: string } = {}
	local pool = shuffled(players)
	local n = #pool

	-- Below 2 players there's nobody for an SCP to hunt (or be hunted by), so
	-- a solo tester gets a normal human class instead of always drawing the
	-- same lonely monster.
	local scpOrder = ClassConfig._SCPActivationOrder :: { string }
	local scpCount = if n < 2 then 0 else math.clamp(math.floor(n / 5), 1, #scpOrder)

	for i = 1, scpCount do
		local player = table.remove(pool) :: Player
		roster[player] = scpOrder[i]
	end

	local humanClassIds = { "DClass", "Scientist", "Guard" }
	local totalWeight = 0
	for _, id in ipairs(humanClassIds) do
		totalWeight += ClassConfig[id].RosterWeight
	end

	local remaining = #pool
	local counts: { [string]: number } = {}
	local assignedSoFar = 0
	for i, id in ipairs(humanClassIds) do
		if i == #humanClassIds then
			counts[id] = remaining - assignedSoFar
		else
			local share = math.floor(remaining * (ClassConfig[id].RosterWeight / totalWeight) + 0.5)
			counts[id] = share
			assignedSoFar += share
		end
	end

	for _, id in ipairs(humanClassIds) do
		for _ = 1, counts[id] or 0 do
			local player = table.remove(pool)
			if not player then
				break
			end
			roster[player] = id
		end
	end

	-- Leftover due to rounding (shouldn't normally happen) defaults to DClass.
	for _, player in ipairs(pool) do
		roster[player] = "DClass"
	end

	return roster
end

function ClassService.GetPlayerClass(player: Player): string?
	return playerClass[player]
end

function ClassService.GetPlayerFaction(player: Player): string?
	local classId = playerClass[player]
	if not classId then
		return nil
	end
	local def = ClassConfig[classId]
	return def and def.Faction or nil
end

function ClassService.IsAlive(player: Player): boolean
	return aliveState[player] == true
end

function ClassService.GetAlivePlayersByFaction(faction: string): { Player }
	local list = {}
	for player, isAlive in pairs(aliveState) do
		if isAlive and ClassService.GetPlayerFaction(player) == faction then
			table.insert(list, player)
		end
	end
	return list
end

function ClassService.GetAliveCountByFaction(faction: string): number
	return #ClassService.GetAlivePlayersByFaction(faction)
end

function ClassService.GetSpectatorQueue(): { Player }
	return table.clone(spectatorQueue)
end

function ClassService.PopFromSpectatorQueue(count: number): { Player }
	local popped = {}
	while #popped < count and #spectatorQueue > 0 do
		table.insert(popped, table.remove(spectatorQueue, 1))
	end
	return popped
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
		faction = def.Faction,
		isSCP = def.IsSCP,
	})
end

function ClassService._OnCharacterDied(player: Player)
	if not aliveState[player] then
		return
	end
	aliveState[player] = false

	if Deps.DataService then
		Deps.DataService.IncrementStat(player, "Deaths", 1)
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and Deps.CombatService then
			local killer = Deps.CombatService.GetLastAttacker(humanoid)
			if killer and killer ~= player and killer.Parent then
				if Deps.DataService then
					Deps.DataService.IncrementStat(killer, "Kills", 1)
					Deps.DataService.AddCredits(killer, 15)
					local killerClassId = playerClass[killer]
					if killerClassId and ClassConfig[killerClassId] and ClassConfig[killerClassId].IsSCP then
						Deps.DataService.IncrementStat(killer, "SCPKills", 1)
					end
				end
				if Deps.MissionService then
					Deps.MissionService.NotifyKill(killer, player)
				end
			end
			Deps.CombatService.ClearAttribution(humanoid)
		end
		spawnCorpse(player, character)
	end

	table.insert(spectatorQueue, player)

	if Deps.RoundService then
		Deps.RoundService.NotifyPlayerDied(player)
	end

	task.delay(2, function()
		if player.Parent and not aliveState[player] then
			ClassService._BecomeSpectator(player, "You died. Watch the round finish, or wait for a reinforcement wave.")
		end
	end)
end

--- Turns a player into a free-noclip ghost: invisible, non-colliding, fast.
--- Used both a beat after death and immediately for players who join mid-round.
function ClassService._BecomeSpectator(player: Player, description: string)
	playerClass[player] = "Spectator"
	player:LoadCharacter()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = GameConfig.SpectatorWalkSpeed
			humanoid.PlatformStand = false
		end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Transparency = 1
			elseif part:IsA("Decal") then
				part.Transparency = 1
			end
		end
	end
	Remotes.ClassAssigned:FireClient(player, {
		classId = "Spectator",
		displayName = "Spectator",
		description = description,
		faction = Enums.Faction.Spectator,
		isSCP = false,
	})
end

--- For players who join while a round is already Active: they can't be
--- slotted into a live roster, so they spectate and queue for the next
--- reinforcement wave (or the next round's roster, whichever comes first).
function ClassService.EnterSpectator(player: Player)
	aliveState[player] = false
	if not table.find(spectatorQueue, player) then
		table.insert(spectatorQueue, player)
	end
	ClassService._BecomeSpectator(player, "The round is already underway. Wait for a reinforcement wave or the next round.")
end

function ClassService.ResetForNewRound()
	table.clear(playerClass)
	table.clear(aliveState)
	table.clear(spectatorQueue)
	ClassService.ClearCorpses()
	if Deps and Deps.SCPAbilityService then
		Deps.SCPAbilityService.ResetForNewRound()
	end
end

function ClassService.Init(deps: any)
	Deps = deps

	Players.PlayerRemoving:Connect(function(player)
		playerClass[player] = nil
		aliveState[player] = nil
		local idx = table.find(spectatorQueue, player)
		if idx then
			table.remove(spectatorQueue, idx)
		end
	end)
end

return ClassService
