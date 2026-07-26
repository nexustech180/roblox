--!strict
-- Server-authoritative behaviour for every SCP class. Two kinds of logic live
-- here:
--   1. Passive, continuous checks run on a throttled Heartbeat loop (SCP-173's
--      observer freeze/lunge, SCP-096's view-detection/enrage, SCP-106's touch
--      corrode) - these never trust the client at all.
--   2. Active abilities requested via the SCPAbility RemoteEvent (SCP-049's
--      Touch of Death / Reanimate, SCP-106's Phase / Pocket Dimension) - the
--      client only asks; this service validates class, range and cooldown
--      before anything happens.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SCPConfig = require(ReplicatedStorage.Shared.Config.SCPConfig)
local Enums = require(ReplicatedStorage.Shared.Modules.Enums)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local SCPAbilityService = {}

local Deps: any = nil

local HEARTBEAT_INTERVAL = 0.15

type SCPState = {
	classId: string,
	-- SCP-096
	viewedSince: number?,
	enraged: boolean,
	enrageEndsAt: number,
	cryUntil: number,
	-- SCP-106
	phasing: boolean,
	phaseCooldownUntil: number,
	lastCorrodeTick: number,
	-- SCP-049 / SCP-173 shared
	lastAbilityUse: { [string]: number },
}

local registry: { [Player]: SCPState } = {}
local pocketDimensionRoom: BasePart? = nil
local pocketVictims: { [Player]: { returnCFrame: CFrame, expiresAt: number } } = {}

local function newState(classId: string): SCPState
	return {
		classId = classId,
		enraged = false,
		enrageEndsAt = 0,
		cryUntil = 0,
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
	pocketVictims[player] = nil
end

function SCPAbilityService.ResetForNewRound()
	table.clear(registry)
	table.clear(pocketVictims)
end

-- ============================== shared helpers ==============================

local function getAliveHostiles(): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Deps.ClassService.IsAlive(player) and Deps.ClassService.GetPlayerFaction(player) ~= Enums.Faction.SCP then
			table.insert(list, player)
		end
	end
	return list
end

local function hasLineOfSight(fromPos: Vector3, toPos: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(fromPos, toPos - fromPos, params)
	if not result then
		return true
	end
	-- Something solid is between the two points if the hit is meaningfully
	-- short of the target distance.
	return (result.Position - toPos).Magnitude < 1.5
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

-- ================================ SCP-173 ===================================

local function updateSCP173(player: Player, state: SCPState)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local cfg = SCPConfig.SCP173
	local hostiles = getAliveHostiles()
	local observed = false

	for _, hostile in ipairs(hostiles) do
		local hostileChar = hostile.Character
		local hostileHead = hostileChar and hostileChar:FindFirstChild("Head") :: BasePart?
		if hostileHead then
			local toSCP = root.Position - hostileHead.Position
			local distance = toSCP.Magnitude
			if distance <= cfg.ObserverMaxDistance then
				local lookVector = hostileHead.CFrame.LookVector
				local angle = math.deg(math.acos(math.clamp(lookVector.Unit:Dot(toSCP.Unit), -1, 1)))
				if angle <= cfg.ObserverConeDegrees / 2 and hasLineOfSight(hostileHead.Position, root.Position, { character, hostileChar :: Instance }) then
					observed = true
					break
				end
			end
		end
	end

	humanoid.WalkSpeed = observed and 0 or cfg.MoveSpeedWhenUnobserved

	if not observed then
		local now = os.clock()
		local lastLunge = state.lastAbilityUse["Lunge"] or 0
		if now - lastLunge >= cfg.NeckSnapCooldown then
			for _, hostile in ipairs(hostiles) do
				local hostileChar = hostile.Character
				local hostileRoot = hostileChar and hostileChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hostileHumanoid = hostileChar and hostileChar:FindFirstChildOfClass("Humanoid")
				if hostileRoot and hostileHumanoid and hostileHumanoid.Health > 0 then
					if (hostileRoot.Position - root.Position).Magnitude <= cfg.LungeRange then
						Deps.CombatService.ApplyDamage(player, hostileHumanoid, cfg.LungeDamage)
						Deps.NotifyService.Toast(hostile, "Your neck snaps before you even hear it move.", "danger")
						state.lastAbilityUse["Lunge"] = now
						break
					end
				end
			end
		end
	end
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
		local nearest: Player? = nil
		local nearestDist = math.huge
		for _, hostile in ipairs(getAliveHostiles()) do
			local hostileRoot = hostile.Character and hostile.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hostileRoot then
				local dist = (hostileRoot.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = hostile
				end
			end
		end

		if nearest then
			local hostileRoot = nearest.Character:FindFirstChild("HumanoidRootPart") :: BasePart
			humanoid:MoveTo(hostileRoot.Position)
			if nearestDist <= 5 then
				local now = os.clock()
				if now - lastBite >= cfg.ZombieBiteCooldown then
					lastBite = now
					local hostileHumanoid = nearest.Character:FindFirstChildOfClass("Humanoid")
					if hostileHumanoid then
						Deps.CombatService.ApplyDamage(nil, hostileHumanoid, cfg.ZombieBiteDamage)
					end
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

local function tryTouchOfDeath(player: Player, state: SCPState)
	if isOnCooldown(player, "TouchOfDeath") then
		return
	end
	local cfg = SCPConfig.SCP049
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local best: Player? = nil
	local bestDist = cfg.TouchOfDeathRange
	for _, hostile in ipairs(getAliveHostiles()) do
		local hostileRoot = hostile.Character and hostile.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hostileRoot then
			local dist = (hostileRoot.Position - root.Position).Magnitude
			if dist <= bestDist then
				bestDist = dist
				best = hostile
			end
		end
	end

	setCooldown(player, "TouchOfDeath", cfg.TouchOfDeathCooldown)

	if best then
		local hostileHumanoid = best.Character:FindFirstChildOfClass("Humanoid")
		if hostileHumanoid then
			Deps.CombatService.ApplyDamage(player, hostileHumanoid, cfg.TouchOfDeathDamage)
			Deps.NotifyService.Toast(best, "The Plague Doctor's cure finds you.", "danger")
		end
	end
end

local function tryReanimate(player: Player, state: SCPState)
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

-- ================================ SCP-096 ===================================

local function updateSCP096(player: Player, state: SCPState)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local cfg = SCPConfig.SCP096
	local now = os.clock()

	if state.enraged then
		if now >= state.enrageEndsAt then
			state.enraged = false
			state.cryUntil = now + cfg.PostEnrageCryDurationSeconds
			humanoid.WalkSpeed = 8
			return
		end

		local nearest: Player? = nil
		local nearestDist = math.huge
		for _, hostile in ipairs(getAliveHostiles()) do
			local hostileRoot = hostile.Character and hostile.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hostileRoot then
				local dist = (hostileRoot.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = hostile
				end
			end
		end

		if nearest then
			local hostileRoot = nearest.Character:FindFirstChild("HumanoidRootPart") :: BasePart
			humanoid:MoveTo(hostileRoot.Position)
			if nearestDist <= cfg.SwipeRange then
				local lastSwipe = state.lastAbilityUse["Swipe"] or 0
				if now - lastSwipe >= cfg.SwipeCooldown then
					state.lastAbilityUse["Swipe"] = now
					local hostileHumanoid = nearest.Character:FindFirstChildOfClass("Humanoid")
					if hostileHumanoid then
						Deps.CombatService.ApplyDamage(player, hostileHumanoid, cfg.SwipeDamage)
					end
				end
			end
		end
		return
	end

	if now < state.cryUntil then
		humanoid.WalkSpeed = 4
		return
	end

	humanoid.WalkSpeed = 8

	local viewer = false
	for _, hostile in ipairs(getAliveHostiles()) do
		local hostileChar = hostile.Character
		local hostileHead = hostileChar and hostileChar:FindFirstChild("Head") :: BasePart?
		if hostileHead then
			local toSCP = root.Position - hostileHead.Position
			local distance = toSCP.Magnitude
			if distance <= cfg.ViewMaxDistance then
				local lookVector = hostileHead.CFrame.LookVector
				local angle = math.deg(math.acos(math.clamp(lookVector.Unit:Dot(toSCP.Unit), -1, 1)))
				if angle <= cfg.ViewConeDegrees / 2 and hasLineOfSight(hostileHead.Position, root.Position, { character, hostileChar :: Instance }) then
					viewer = true
					break
				end
			end
		end
	end

	if viewer then
		state.viewedSince = state.viewedSince or now
		if now - state.viewedSince >= cfg.CalmToEnrageDelaySeconds then
			state.enraged = true
			state.enrageEndsAt = now + cfg.EnrageDurationSeconds
			state.viewedSince = nil
			humanoid.WalkSpeed = cfg.EnrageWalkSpeed
			Deps.NotifyService.ToastAll("SCP-096 has been seen. Run.", "danger")
		end
	else
		state.viewedSince = nil
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

local function returnPocketVictim(victim: Player)
	local info = pocketVictims[victim]
	pocketVictims[victim] = nil
	if not info then
		return
	end
	local character = victim.Character
	if character and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health > 0 then
		character:PivotTo(info.returnCFrame)
	end
end

local function tryPocketDimension(player: Player, state: SCPState)
	if isOnCooldown(player, "PocketDimension") then
		return
	end
	local cfg = SCPConfig.SCP106
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local target: Player? = nil
	for _, hostile in ipairs(getAliveHostiles()) do
		local hostileRoot = hostile.Character and hostile.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hostileRoot and (hostileRoot.Position - root.Position).Magnitude <= 7 then
			target = hostile
			break
		end
	end

	setCooldown(player, "PocketDimension", 20)

	if not target then
		return
	end

	local floor = ensurePocketDimension()
	local targetCharacter = target.Character
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	local returnCFrame = targetRoot.CFrame
	pocketVictims[target] = { returnCFrame = returnCFrame, expiresAt = os.clock() + cfg.PocketDimensionDuration }
	targetCharacter:PivotTo(floor.CFrame + Vector3.new(0, 6, 0))
	Deps.NotifyService.Toast(target, "You are dragged into somewhere that should not exist.", "danger")

	task.spawn(function()
		local elapsed = 0
		while elapsed < cfg.PocketDimensionDuration do
			task.wait(1)
			elapsed += 1
			local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				pocketVictims[target] = nil
				return
			end
			Deps.CombatService.ApplyDamage(player, humanoid, cfg.PocketDimensionDamagePerTick)
		end
		returnPocketVictim(target)
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

	for _, hostile in ipairs(getAliveHostiles()) do
		local hostileRoot = hostile.Character and hostile.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hostileHumanoid = hostile.Character and hostile.Character:FindFirstChildOfClass("Humanoid")
		if hostileRoot and hostileHumanoid and (hostileRoot.Position - root.Position).Magnitude <= 4 then
			Deps.CombatService.ApplyDamage(player, hostileHumanoid, cfg.CorrodeDamagePerTick)
			state.lastCorrodeTick = now
			break
		end
	end
end

-- ================================ dispatch ==================================

local UPDATERS: { [string]: (Player, SCPState) -> () } = {
	SCP173 = updateSCP173,
	SCP096 = updateSCP096,
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
			tryTouchOfDeath(player, state)
		elseif ability == "Reanimate" then
			tryReanimate(player, state)
		end
	elseif state.classId == "SCP106" then
		if ability == "Phase" then
			tryPhase(player, state)
		elseif ability == "PocketDimension" then
			tryPocketDimension(player, state)
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
