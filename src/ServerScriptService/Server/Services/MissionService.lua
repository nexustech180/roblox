--!strict
-- Groups players into squads (see GameConfig.SquadSize) and runs the mission
-- board: assigns each squad an objective chain from MissionConfig, tracks
-- progress against world geometry (tagged zones/terminals) and kills, pays
-- out rewards, then loops a fresh mission so there is always something to do.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MissionConfig = require(ReplicatedStorage.Shared.Config.MissionConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

type Objective = MissionConfig.Objective
type MissionDefinition = MissionConfig.MissionDefinition

type Squad = {
	id: number,
	faction: string,
	members: { Player },
	missionDef: MissionDefinition?,
	objectiveIndex: number,
	eliminateProgress: number,
	objectiveToken: number,
}

local MissionService = {}

local Deps: any = nil

local squads: { [number]: Squad } = {}
local playerSquad: { [Player]: number } = {}
local nextSquadId = 1

-- Every ZoneTag / PartTag referenced anywhere in MissionConfig, discovered once
-- at Init so we only ever set up listeners for tags the design actually uses.
local zoneTagListeners: { [string]: boolean } = {}
local partTagListeners: { [string]: boolean } = {}

local function getSquad(player: Player): Squad?
	local id = playerSquad[player]
	return id and squads[id]
end

local function currentObjective(squad: Squad): Objective?
	if not squad.missionDef then
		return nil
	end
	return squad.missionDef.Objectives[squad.objectiveIndex]
end

local function broadcastProgress(squad: Squad, complete: boolean)
	for _, member in ipairs(squad.members) do
		if member.Parent then
			Remotes.MissionProgress:FireClient(member, {
				missionId = squad.missionDef and squad.missionDef.Id,
				objectiveIndex = squad.objectiveIndex,
				objectiveText = currentObjective(squad) and currentObjective(squad).Description or nil,
				complete = complete,
			})
		end
	end
end

local function broadcastAssigned(squad: Squad)
	local def = squad.missionDef
	if not def then
		return
	end
	for _, member in ipairs(squad.members) do
		if member.Parent then
			Remotes.MissionAssigned:FireClient(member, {
				missionId = def.Id,
				displayName = def.DisplayName,
				squadId = squad.id,
				objectiveText = currentObjective(squad) and currentObjective(squad).Description or nil,
				objectiveIndex = squad.objectiveIndex,
				objectiveCount = #def.Objectives,
			})
		end
	end
end

local advanceObjective: (squad: Squad) -> ()
local assignMissionToSquad: (squad: Squad) -> ()
local broadcastAssignedOne: (player: Player, squad: Squad) -> ()

--- SurviveTime objectives have no world trigger to complete them - they just
--- need "at least one squad member alive when the clock runs out". The token
--- check guards against a stale timer firing after the squad's mission (or
--- objective) has already moved on.
local function scheduleSurviveTimeCheck(squad: Squad, durationSeconds: number)
	local token = squad.objectiveToken
	task.delay(durationSeconds, function()
		if squads[squad.id] ~= squad or squad.objectiveToken ~= token then
			return
		end
		for _, member in ipairs(squad.members) do
			if Deps.ClassService.IsAlive(member) then
				advanceObjective(squad)
				return
			end
		end
	end)
end

local function completeMission(squad: Squad)
	local def = squad.missionDef
	if not def then
		return
	end
	for _, member in ipairs(squad.members) do
		if member.Parent then
			if Deps.DataService then
				Deps.DataService.AddCredits(member, def.RewardCredits)
				Deps.DataService.AddXP(member, def.RewardXP)
				Deps.DataService.IncrementStat(member, "MissionsCompleted", 1)
			end
			Deps.NotifyService.Toast(member, `Mission complete: {def.DisplayName} (+{def.RewardCredits} credits)`, "success")
		end
	end
	broadcastProgress(squad, true)

	task.delay(4, function()
		if squads[squad.id] == squad and Deps.RoundService.GetState() == "Active" then
			assignMissionToSquad(squad)
		end
	end)
end

function advanceObjective(squad: Squad)
	squad.objectiveIndex += 1
	squad.eliminateProgress = 0
	squad.objectiveToken += 1

	if not squad.missionDef or squad.objectiveIndex > #squad.missionDef.Objectives then
		completeMission(squad)
		return
	end

	broadcastProgress(squad, false)

	local objective = currentObjective(squad)
	if objective and objective.Type == "SurviveTime" and objective.DurationSeconds then
		scheduleSurviveTimeCheck(squad, objective.DurationSeconds)
	end
end

function assignMissionToSquad(squad: Squad)
	local pool = MissionConfig._PoolByFaction[squad.faction]
	if not pool or #pool == 0 then
		return
	end
	local missionId = pool[math.random(1, #pool)]
	squad.missionDef = MissionConfig[missionId]
	squad.objectiveIndex = 1
	squad.eliminateProgress = 0
	squad.objectiveToken += 1

	broadcastAssigned(squad)

	local objective = currentObjective(squad)
	if objective and objective.Type == "SurviveTime" and objective.DurationSeconds then
		scheduleSurviveTimeCheck(squad, objective.DurationSeconds)
	end
end

local function createSquad(faction: string, members: { Player }): Squad
	local squad: Squad = {
		id = nextSquadId,
		faction = faction,
		members = members,
		missionDef = nil,
		objectiveIndex = 1,
		eliminateProgress = 0,
		objectiveToken = 0,
	}
	nextSquadId += 1
	squads[squad.id] = squad
	for _, member in ipairs(members) do
		playerSquad[member] = squad.id
	end
	return squad
end

--- Forms squads for any of `players` not already in one, and tops up
--- under-strength existing squads for `faction` before creating new ones.
--- Safe to call repeatedly (e.g. every time a reinforcement wave spawns).
function MissionService.FormSquadsForFaction(faction: string, players: { Player })
	local unassigned = {}
	for _, player in ipairs(players) do
		if not playerSquad[player] and player.Parent then
			table.insert(unassigned, player)
		end
	end
	if #unassigned == 0 then
		return
	end

	for _, squad in pairs(squads) do
		if squad.faction == faction then
			while #squad.members < GameConfig.SquadSize and #unassigned > 0 do
				local player = table.remove(unassigned) :: Player
				table.insert(squad.members, player)
				playerSquad[player] = squad.id
				broadcastAssignedOne(player, squad)
			end
		end
	end

	while #unassigned > 0 do
		local members = {}
		for _ = 1, math.min(GameConfig.SquadSize, #unassigned) do
			table.insert(members, table.remove(unassigned))
		end
		local squad = createSquad(faction, members)
		assignMissionToSquad(squad)
	end
end

function broadcastAssignedOne(player, squad)
	local def = squad.missionDef
	if not def or not player.Parent then
		return
	end
	Remotes.MissionAssigned:FireClient(player, {
		missionId = def.Id,
		displayName = def.DisplayName,
		squadId = squad.id,
		objectiveText = currentObjective(squad) and currentObjective(squad).Description or nil,
		objectiveIndex = squad.objectiveIndex,
		objectiveCount = #def.Objectives,
	})
end

--- Called by ClassService whenever a hostile kill lands, to progress any
--- EliminateCount objective the killer's squad might currently have.
function MissionService.NotifyKill(killer: Player, victim: Player)
	local squad = getSquad(killer)
	if not squad then
		return
	end
	local objective = currentObjective(squad)
	if not objective or objective.Type ~= "EliminateCount" then
		return
	end
	local victimFaction = Deps.ClassService.GetPlayerFaction(victim)
	if victimFaction ~= objective.TargetFaction then
		return
	end
	squad.eliminateProgress += 1
	broadcastProgress(squad, false)
	if squad.eliminateProgress >= (objective.Count or 1) then
		advanceObjective(squad)
	end
end

local function handleZoneReached(player: Player, zoneTag: string)
	local squad = getSquad(player)
	if not squad then
		return
	end
	local objective = currentObjective(squad)
	if not objective or objective.Type ~= "ReachZone" or objective.ZoneTag ~= zoneTag then
		return
	end

	if zoneTag == "Zone_Surface" and Deps.DataService then
		Deps.DataService.IncrementStat(player, "Escapes", 1)
	end

	advanceObjective(squad)
end

local function handleTerminalUsed(player: Player, partTag: string)
	local squad = getSquad(player)
	if not squad then
		return
	end
	local objective = currentObjective(squad)
	if not objective or objective.Type ~= "InteractPart" or objective.PartTag ~= partTag then
		return
	end

	if partTag == "Terminal_CellRelease" and Deps.DoorService then
		Deps.DoorService.UnlockGroup("CellDoor")
	end

	advanceObjective(squad)
end

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

function MissionService.GetSquadId(player: Player): number?
	return playerSquad[player]
end

function MissionService.ResetForNewRound()
	table.clear(squads)
	table.clear(playerSquad)
	nextSquadId = 1
end

function MissionService.Init(deps: any)
	Deps = deps
	discoverTags()

	Players.PlayerRemoving:Connect(function(player)
		local squad = getSquad(player)
		if squad then
			local idx = table.find(squad.members, player)
			if idx then
				table.remove(squad.members, idx)
			end
		end
		playerSquad[player] = nil
	end)
end

return MissionService
