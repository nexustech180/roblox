--!strict
-- Server-authoritative behaviour for the two prestige SCP classes. In a solo
-- game there's no second player to be observed by or to hunt, so both
-- abilities target hostile NPCs (the same "HostileNPC"-tagged dummies
-- NPCService spawns for mission objectives) instead of other players:
--   - SCP-049: "E" Touch of Death (instant kill in melee range), "R"
--     Reanimate (raises a nearby corpse into a hostile zombie with its own
--     chase AI - works on old player-death corpses too, not just NPCs).
--   - SCP-106: "E" Phase (noclip through walls for a few seconds), "R"
--     Pocket Dimension (banishes a target to an isolated room and damages
--     it over time); passive corrode-on-touch runs on a heartbeat loop.
--
-- Every kill still routes through CombatService.ApplyDamage, so NPCService's
-- own death/attribution handling (and therefore mission progress) works
-- identically whether an NPC died to a gun or to an SCP ability.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SCPConfig = require(ReplicatedStorage.Shared.Config.SCPConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local SCPAbilityService = {}

local Deps: any = nil

local HEARTBEAT_INTERVAL = 0.15

type SCPState = {
	classId: string,
	-- SCP-106
	phasing: boolean,
	phaseCooldownUntil: number,
	lastCorrodeTick: number,
	-- shared cooldown bookkeeping
	lastAbilityUse: { [string]: number },
}

local registry: { [Player]: SCPState } = {}
local pocketDimensionRoom: BasePart? = nil
local pocketVictims: { [Model]: { returnCFrame: CFrame, expiresAt: number } } = {}

local function newState(classId: string): SCPState
	return {
		classId = classId,
		phasing = false,
		phaseCooldownUntil = 0,
		lastCorrodeTick = 0,
		lastAbilityUse = {},
	}
end

function SCPAbilityService.RegisterSCP(player: Player, classId: string)
	registry[player] = newState(classId)
end

function SCPAbilityService.DeregisterSCP(player: Player)
	registry[player] = nil
end

-- ============================== shared helpers ==============================

type HostileHandle = { model: Model, root: BasePart, humanoid: Humanoid }

local function getNearbyHostileNPCs(): { HostileHandle }
	local list = {}
	for _, model in ipairs(CollectionService:GetTagged("HostileNPC")) do
		if model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and root and humanoid.Health > 0 then
				table.insert(list, { model = model, root = root, humanoid = humanoid })
			end
		end
	end
	return list
end

local function setCooldown(player: Player, ability: string, seconds: number)
	local state = registry[player]
	if not state then
		return
	end
	state.lastAbilityUse[ability] = os.clock() + seconds
	Remotes.SCPAbilityCooldown:FireClient(player, { ability = ability, duration = seconds })
end

local function isOnCooldown(player: Player, ability: string): boolean
	local state = registry[player]
	if not state then
		return true
	end
	local until_ = state.lastAbilityUse[ability]
	return until_ ~= nil and os.clock() < until_
end

-- ================================ SCP-049 ===================================

local ZOMBIE_TAG = "SCP049Zombie"

local function runZombieAI(zombie: Model, cfg: SCPConfig.SCP049Config)
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	local root = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end

	local lastBite = 0
	while zombie.Parent and humanoid.Health > 0 do
		local nearest: HostileHandle? = nil
		local nearestDist = math.huge
		for _, hostile in ipairs(getNearbyHostileNPCs()) do
			local dist = (hostile.root.Position - root.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = hostile
			end
		end

		if nearest then
			humanoid:MoveTo(nearest.root.Position)
			if nearestDist <= 5 then
				local now = os.clock()
				if now - lastBite >= cfg.ZombieBiteCooldown then
					lastBite = now
					Deps.CombatService.ApplyDamage(nil, nearest.humanoid, cfg.ZombieBiteDamage)
				end
			end
		end

		task.wait(0.5)
	end
end

local function reanimateCorpse(corpse: Model, cfg: SCPConfig.SCP049Config)
	corpse:SetAttribute("Reanimated", true)
	CollectionService:AddTag(corpse, ZOMBIE_TAG)

	local existingHumanoid = corpse:FindFirstChildOfClass("Humanoid")
	local humanoid = existingHumanoid or Instance.new("Humanoid")
	humanoid.Parent = corpse
	humanoid.MaxHealth = cfg.ZombieMaxHealth
	humanoid.Health = cfg.ZombieMaxHealth
	humanoid.WalkSpeed = cfg.ZombieWalkSpeed
	humanoid.PlatformStand = false

	for _, descendant in ipairs(corpse:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = descendant.Name ~= "Head"
		end
	end

	if not corpse.PrimaryPart then
		corpse.PrimaryPart = corpse:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	task.spawn(runZombieAI, corpse, cfg)
end

local function tryTouchOfDeath(player: Player)
	if isOnCooldown(player, "TouchOfDeath") then
		return
	end
	local cfg = SCPConfig.SCP049
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local best: HostileHandle? = nil
	local bestDist = cfg.TouchOfDeathRange
	for _, hostile in ipairs(getNearbyHostileNPCs()) do
		local dist = (hostile.root.Position - root.Position).Magnitude
		if dist <= bestDist then
			bestDist = dist
			best = hostile
		end
	end

	setCooldown(player, "TouchOfDeath", cfg.TouchOfDeathCooldown)

	if best then
		Deps.CombatService.ApplyDamage(player, best.humanoid, cfg.TouchOfDeathDamage)
	end
end

local function tryReanimate(player: Player)
	if isOnCooldown(player, "Reanimate") then
		return
	end
	local cfg = SCPConfig.SCP049
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local now = os.clock()
	local best: Model? = nil
	local bestDist = cfg.ReanimateRange
	for _, corpse in ipairs(CollectionService:GetTagged("Corpse")) do
		if corpse:GetAttribute("Reanimated") ~= true then
			local corpseRoot = corpse:FindFirstChild("HumanoidRootPart") :: BasePart?
			local diedAt = corpse:GetAttribute("DiedAt") :: number?
			if corpseRoot and diedAt and (now - diedAt) <= cfg.ReanimateWindowSeconds then
				local dist = (corpseRoot.Position - root.Position).Magnitude
				if dist <= bestDist then
					bestDist = dist
					best = corpse :: Model
				end
			end
		end
	end

	setCooldown(player, "Reanimate", 5)

	if best then
		reanimateCorpse(best, cfg)
		Deps.NotifyService.Toast(player, "The corpse rises to serve you.", "success")
	else
		Deps.NotifyService.Toast(player, "No reanimatable corpse nearby.", "warning")
	end
end

-- ================================ SCP-106 ===================================

local function ensurePocketDimension(): BasePart
	if pocketDimensionRoom then
		return pocketDimensionRoom
	end

	local folder = Instance.new("Folder")
	folder.Name = "PocketDimension"
	folder.Parent = Workspace

	local center = Vector3.new(0, -750, 0)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(40, 2, 40)
	floor.Position = center
	floor.Material = Enum.Material.Basalt
	floor.Color = Color3.fromRGB(20, 15, 20)
	floor.Parent = folder

	for _, offset in ipairs({ Vector3.new(20, 10, 0), Vector3.new(-20, 10, 0), Vector3.new(0, 10, 20), Vector3.new(0, 10, -20) }) do
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = if offset.X ~= 0 then Vector3.new(2, 20, 40) else Vector3.new(40, 20, 2)
		wall.Position = center + offset
		wall.Material = Enum.Material.Basalt
		wall.Color = Color3.fromRGB(10, 8, 10)
		wall.Parent = folder
	end

	pocketDimensionRoom = floor
	return floor
end

local function tryPhase(player: Player, state: SCPState)
	if state.phasing or os.clock() < state.phaseCooldownUntil then
		return
	end
	local cfg = SCPConfig.SCP106
	local character = player.Character
	if not character then
		return
	end

	state.phasing = true
	state.phaseCooldownUntil = os.clock() + cfg.PhaseCooldown
	setCooldown(player, "Phase", cfg.PhaseCooldown)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local originalWalkSpeed = humanoid and humanoid.WalkSpeed or 14
	if humanoid then
		humanoid.WalkSpeed = originalWalkSpeed * cfg.PhaseSpeedMultiplier
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	task.delay(cfg.PhaseDurationSeconds, function()
		state.phasing = false
		if character.Parent then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "Head" then
					part.CanCollide = true
				end
			end
			if humanoid then
				humanoid.WalkSpeed = originalWalkSpeed
			end
		end
	end)
end

local function returnPocketVictim(victim: Model)
	local info = pocketVictims[victim]
	pocketVictims[victim] = nil
	if not info then
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if victim.Parent and humanoid and humanoid.Health > 0 then
		victim:PivotTo(info.returnCFrame)
	end
end

local function tryPocketDimension(player: Player)
	if isOnCooldown(player, "PocketDimension") then
		return
	end
	local cfg = SCPConfig.SCP106
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local target: HostileHandle? = nil
	for _, hostile in ipairs(getNearbyHostileNPCs()) do
		if (hostile.root.Position - root.Position).Magnitude <= 7 then
			target = hostile
			break
		end
	end

	setCooldown(player, "PocketDimension", 20)

	if not target then
		return
	end

	local floor = ensurePocketDimension()
	local returnCFrame = target.root.CFrame
	pocketVictims[target.model] = { returnCFrame = returnCFrame, expiresAt = os.clock() + cfg.PocketDimensionDuration }
	target.model:PivotTo(floor.CFrame + Vector3.new(0, 6, 0))

	task.spawn(function()
		local elapsed = 0
		while elapsed < cfg.PocketDimensionDuration do
			task.wait(1)
			elapsed += 1
			if not target.model.Parent or target.humanoid.Health <= 0 then
				pocketVictims[target.model] = nil
				return
			end
			Deps.CombatService.ApplyDamage(player, target.humanoid, cfg.PocketDimensionDamagePerTick)
		end
		returnPocketVictim(target.model)
	end)
end

local function updateSCP106(player: Player, state: SCPState)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local cfg = SCPConfig.SCP106
	local now = os.clock()
	if now - state.lastCorrodeTick < cfg.CorrodeTickSeconds then
		return
	end

	for _, hostile in ipairs(getNearbyHostileNPCs()) do
		if (hostile.root.Position - root.Position).Magnitude <= 4 then
			Deps.CombatService.ApplyDamage(player, hostile.humanoid, cfg.CorrodeDamagePerTick)
			state.lastCorrodeTick = now
			break
		end
	end
end

-- ================================ dispatch ==================================

local UPDATERS: { [string]: (Player, SCPState) -> () } = {
	SCP106 = updateSCP106,
}

local function onAbilityRequest(player: Player, payload: any)
	local state = registry[player]
	if not state then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.ability) ~= "string" then
		return
	end
	local ability = payload.ability

	if not Deps.AntiExploitService.CheckRate(player, "SCPAbility_" .. ability, 0.25) then
		return
	end

	if state.classId == "SCP049" then
		if ability == "TouchOfDeath" then
			tryTouchOfDeath(player)
		elseif ability == "Reanimate" then
			tryReanimate(player)
		end
	elseif state.classId == "SCP106" then
		if ability == "Phase" then
			tryPhase(player, state)
		elseif ability == "PocketDimension" then
			tryPocketDimension(player)
		end
	end
end

local accumulator = 0
local function onHeartbeat(dt: number)
	accumulator += dt
	if accumulator < HEARTBEAT_INTERVAL then
		return
	end
	accumulator = 0

	for player, state in pairs(registry) do
		local updater = UPDATERS[state.classId]
		if updater and player.Parent then
			local ok, err = pcall(updater, player, state)
			if not ok then
				warn(`[SCPAbilityService] updater error for {state.classId}: {err}`)
			end
		end
	end
end

function SCPAbilityService.Init(deps: any)
	Deps = deps
	Remotes.SCPAbility.OnServerEvent:Connect(onAbilityRequest)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return SCPAbilityService
