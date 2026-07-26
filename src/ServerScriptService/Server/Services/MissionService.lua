--!strict
-- Runs the solo mission board: draws missions for the player's current class
-- from a shuffled "bag" (no repeats until every mission in the pool has come
-- up once, so you keep grinding the same small pool without ever getting the
-- exact same mission twice in a row), scales objective counts/durations/
-- rewards up with level, and tracks progress against world geometry (tagged
-- zones/terminals) or spawned NPCs.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

type Objective = MissionConfig.Objective
type MissionDefinition = MissionConfig.MissionDefinition

type LiveObjective = {
	Type: string,
	ZoneTag: string?,
	PartTag: string?,
	Count: number?,
	DurationSeconds: number?,
	Description: string,
}

type PlayerState = {
	classId: string,
	missionDef: MissionDefinition?,
	liveObjectives: { LiveObjective },
	objectiveIndex: number,
	objectiveToken: number,
	npcProgress: number,
	activeNPCs: { Model },
	bag: { string },
	lastMissionId: string?,
}

local MissionService = {}

local Deps: any = nil

local states: { [Player]: PlayerState } = {}

local function shuffled(list: { string }): { string }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

--- How much harder/more rewarding a mission should be at the player's
--- current level. Every DifficultyLevelStep levels adds DifficultyScalePerStep.
local function difficultyScale(level: number): number
	return 1 + math.floor((level - 1) / GameConfig.DifficultyLevelStep) * GameConfig.DifficultyScalePerStep
end

local function buildLiveObjectives(def: MissionDefinition, scale: number): { LiveObjective }
	local live = {}
	for _, objective in ipairs(def.Objectives) do
		table.insert(live, {
			Type = objective.Type,
			ZoneTag = objective.ZoneTag,
			PartTag = objective.PartTag,
			Count = objective.BaseCount and math.max(1, math.ceil(objective.BaseCount * scale)),
			DurationSeconds = objective.BaseDurationSeconds and math.ceil(objective.BaseDurationSeconds * scale),
			Description = objective.Description,
		})
	end
	return live
end

local function currentObjective(state: PlayerState): LiveObjective?
	return state.liveObjectives[state.objectiveIndex]
end

local function clearActiveNPCs(state: PlayerState)
	for _, npc in ipairs(state.activeNPCs) do
		if npc.Parent then
			npc:Destroy()
		end
	end
	table.clear(state.activeNPCs)
end

local function broadcastAssigned(player: Player, state: PlayerState)
	local def = state.missionDef
	if not def or not player.Parent then
		return
	end
	local objective = currentObjective(state)
	Remotes.MissionAssigned:FireClient(player, {
		missionId = def.Id,
		displayName = def.DisplayName,
		objectiveText = objective and objective.Description,
		objectiveIndex = state.objectiveIndex,
		objectiveCount = #state.liveObjectives,
	})
end

local function broadcastProgress(player: Player, state: PlayerState, complete: boolean, extra: string?)
	if not player.Parent then
		return
	end
	local objective = currentObjective(state)
	Remotes.MissionProgress:FireClient(player, {
		missionId = state.missionDef and state.missionDef.Id,
		objectiveIndex = state.objectiveIndex,
		objectiveText = extra or (objective and objective.Description),
		complete = complete,
	})
end

local advanceObjective: (player: Player, state: PlayerState) -> ()
local assignNextMission: (player: Player) -> ()
local beginCurrentObjective: (player: Player, state: PlayerState) -> ()

local function completeMission(player: Player, state: PlayerState)
	local def = state.missionDef
	if not def then
		return
	end
	local profile = Deps.DataService.GetProfile(player)
	local level = profile and profile.Level or 1
	local scale = difficultyScale(level)
	local credits = math.ceil(def.BaseRewardCredits * scale)
	local xp = math.ceil(def.BaseRewardXP * scale)

	if Deps.DataService then
		Deps.DataService.AddCredits(player, credits)
		Deps.DataService.AddXP(player, xp)
		Deps.DataService.IncrementStat(player, "MissionsCompleted", 1)
	end
	Deps.NotifyService.Toast(player, `Mission complete: {def.DisplayName} (+{credits} credits, +{xp} XP)`, "success")
	broadcastProgress(player, state, true)

	state.lastMissionId = def.Id
	task.delay(3, function()
		if states[player] == state and player.Parent then
			assignNextMission(player)
		end
	end)
end

function advanceObjective(player, state)
	clearActiveNPCs(state)
	state.objectiveIndex += 1
	state.npcProgress = 0
	state.objectiveToken += 1

	if state.objectiveIndex > #state.liveObjectives then
		completeMission(player, state)
		return
	end

	broadcastProgress(player, state, false)
	beginCurrentObjective(player, state)
end

function beginCurrentObjective(player, state)
	local objective = currentObjective(state)
	if not objective then
		return
	end

	if objective.Type == "SurviveTime" and objective.DurationSeconds then
		local token = state.objectiveToken
		task.delay(objective.DurationSeconds, function()
			if states[player] == state and state.objectiveToken == token and player.Parent then
				advanceObjective(player, state)
			end
		end)
	elseif objective.Type == "EliminateNPCCount" and objective.Count then
		local character = player.Character
		local origin = character and character:FindFirstChild("HumanoidRootPart")
		local center = (origin :: BasePart?) and (origin :: BasePart).Position or Vector3.new(0, 5, 0)
		local token = state.objectiveToken

		local npcConfig = {
			Health = GameConfig.NPCBaseHealth * difficultyScale((Deps.DataService.GetProfile(player) or { Level = 1 }).Level),
			Damage = GameConfig.NPCBaseDamage,
			WalkSpeed = GameConfig.NPCBaseWalkSpeed,
			AttackRange = 5,
			AttackCooldown = 1.2,
		}

		for _ = 1, objective.Count do
			local offset = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
			local spawnPos = center + offset + Vector3.new(0, 3, 0)
			local npc = Deps.NPCService.SpawnHostile(spawnPos, player, npcConfig, function(_killer: Player?)
				if states[player] ~= state or state.objectiveToken ~= token then
					return
				end
				state.npcProgress += 1
				broadcastProgress(player, state, false, `{objective.Description} ({state.npcProgress}/{objective.Count})`)
				if state.npcProgress >= (objective.Count :: number) then
					advanceObjective(player, state)
				end
			end)
			table.insert(state.activeNPCs, npc)
		end
	end
end

function assignNextMission(player)
	local state = states[player]
	if not state then
		return
	end
	clearActiveNPCs(state)

	local pool = MissionConfig._PoolByClass[state.classId]
	if not pool or #pool == 0 then
		state.missionDef = nil
		return
	end

	if #state.bag == 0 then
		local bag = shuffled(pool)
		if state.lastMissionId and bag[1] == state.lastMissionId and #bag > 1 then
			local swapIndex = math.random(2, #bag)
			bag[1], bag[swapIndex] = bag[swapIndex], bag[1]
		end
		state.bag = bag
	end

	local missionId = table.remove(state.bag, 1) :: string
	local def = MissionConfig[missionId]
	local profile = Deps.DataService.GetProfile(player)
	local level = profile and profile.Level or 1
	local scale = difficultyScale(level)

	state.missionDef = def
	state.liveObjectives = buildLiveObjectives(def, scale)
	state.objectiveIndex = 1
	state.npcProgress = 0
	state.objectiveToken += 1

	broadcastAssigned(player, state)
	beginCurrentObjective(player, state)
end

local function handleZoneReached(player: Player, zoneTag: string)
	local state = states[player]
	if not state then
		return
	end
	local objective = currentObjective(state)
	if not objective or objective.Type ~= "ReachZone" or objective.ZoneTag ~= zoneTag then
		return
	end

	if zoneTag == "Zone_Surface" and Deps.DataService then
		Deps.DataService.IncrementStat(player, "Escapes", 1)
	end

	advanceObjective(player, state)
end

local function handleTerminalUsed(player: Player, partTag: string)
	local state = states[player]
	if not state then
		return
	end
	local objective = currentObjective(state)
	if not objective or objective.Type ~= "InteractPart" or objective.PartTag ~= partTag then
		return
	end

	if partTag == "Terminal_CellRelease" and Deps.DoorService then
		Deps.DoorService.UnlockGroup("CellDoor")
	end

	advanceObjective(player, state)
end

local zoneTagListeners: { [string]: boolean } = {}
local partTagListeners: { [string]: boolean } = {}

local function registerZoneTag(zoneTag: string)
	if zoneTagListeners[zoneTag] then
		return
	end
	zoneTagListeners[zoneTag] = true

	local function wire(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		instance.Touched:Connect(function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player then
				handleZoneReached(player, zoneTag)
			end
		end)
	end

	for _, instance in ipairs(CollectionService:GetTagged(zoneTag)) do
		wire(instance)
	end
	CollectionService:GetInstanceAddedSignal(zoneTag):Connect(wire)
end

local function registerPartTag(partTag: string)
	if partTagListeners[partTag] then
		return
	end
	partTagListeners[partTag] = true

	local function wire(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Interact"
			prompt.ObjectText = instance:GetAttribute("TerminalName") or "Terminal"
			prompt.HoldDuration = 1.5
			prompt.MaxActivationDistance = 8
			prompt.Parent = instance
		end
		prompt.Triggered:Connect(function(player)
			handleTerminalUsed(player, partTag)
		end)
	end

	for _, instance in ipairs(CollectionService:GetTagged(partTag)) do
		wire(instance)
	end
	CollectionService:GetInstanceAddedSignal(partTag):Connect(wire)
end

local function discoverTags()
	for _, def in pairs(MissionConfig) do
		if typeof(def) == "table" and def.Objectives then
			for _, objective in ipairs((def :: MissionDefinition).Objectives) do
				if objective.Type == "ReachZone" and objective.ZoneTag then
					registerZoneTag(objective.ZoneTag)
				elseif objective.Type == "InteractPart" and objective.PartTag then
					registerPartTag(objective.PartTag)
				end
			end
		end
	end
end

--- Called by ClassService right after a player's first spawn.
function MissionService.StartForPlayer(player: Player, classId: string)
	states[player] = {
		classId = classId,
		missionDef = nil,
		liveObjectives = {},
		objectiveIndex = 1,
		objectiveToken = 0,
		npcProgress = 0,
		activeNPCs = {},
		bag = {},
		lastMissionId = nil,
	}
	assignNextMission(player)
end

--- Called by ClassService.RequestClassChange: your old class's mission and
--- any NPCs it spawned don't carry over, but your bag-based no-repeat
--- history does reset per class (each class has its own small pool anyway).
function MissionService.OnClassChanged(player: Player, classId: string)
	MissionService.StartForPlayer(player, classId)
end

function MissionService.Init(deps: any)
	Deps = deps
	discoverTags()

	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			clearActiveNPCs(state)
		end
		states[player] = nil
	end)
end

return MissionService
