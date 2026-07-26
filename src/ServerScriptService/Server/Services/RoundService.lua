--!strict
-- The conductor. Owns the Lobby -> Intermission -> Active -> Ending state
-- machine, builds the roster at round start, runs the win-condition poll,
-- spawns reinforcement waves (MTF/Chaos), and drives the warhead subsystem.
-- Nothing about this requires an admin: PlayerAdded/Removing plus a handful
-- of timers are the only inputs, matching the "fully automated" brief.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local Enums = require(ReplicatedStorage.Shared.Modules.Enums)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local RoundService = {}

local Deps: any = nil

local state: string = Enums.RoundState.Lobby
local roundToken = 0
local roundStartClock = 0
local warheadArmed = false
local warheadPanelsWired = false

-- Forward declarations: several functions below call each other out of the
-- order they're defined in (e.g. checkWinConditions calls endRound, which is
-- defined near the bottom). Lua scoping is lexical, so these locals must
-- exist before anything that closes over them - including the public
-- RoundService.ForceStart*/GetState functions right below.
local startIntermission: () -> ()
local startActiveRound: () -> ()
local endRound: (reason: string) -> ()

function RoundService.GetState(): string
	return state
end

--- Admin-only escape hatches (see Admin/AdminCommands.lua). Bypasses the
--- normal population/timer gates for testing and moderator overrides.
function RoundService.ForceStartIntermission()
	if state == Enums.RoundState.Lobby then
		startIntermission()
	end
end

function RoundService.ForceEndRound(reason: string)
	if state == Enums.RoundState.Active then
		endRound(reason)
	end
end

local function broadcast(payload: { [string]: any })
	payload.state = state
	Remotes.RoundStateChanged:FireAllClients(payload)
end

-- ============================== Lobby / Intermission =========================

local function maybeStartFromLobby()
	if state ~= Enums.RoundState.Lobby then
		return
	end
	if #Players:GetPlayers() >= GameConfig.MinPlayersToStart then
		startIntermission()
	end
end

function startIntermission()
	state = Enums.RoundState.Intermission
	local myToken = roundToken
	local timeLeft = GameConfig.IntermissionSeconds

	task.spawn(function()
		while timeLeft > 0 do
			if roundToken ~= myToken or state ~= Enums.RoundState.Intermission then
				return
			end
			if #Players:GetPlayers() < GameConfig.MinPlayersToStart then
				state = Enums.RoundState.Lobby
				broadcast({ reason = Enums.RoundEndReason.NotEnoughPlayers })
				return
			end
			broadcast({ timeLeft = timeLeft })
			task.wait(1)
			timeLeft -= 1
		end
		if roundToken == myToken and state == Enums.RoundState.Intermission then
			startActiveRound()
		end
	end)
end

-- ================================== Active ====================================

local function spawnRosterWave(classId: string, faction: string, players: { Player })
	if #players == 0 then
		return
	end
	for _, player in ipairs(players) do
		Deps.ClassService.SpawnCharacterForClass(player, classId)
	end
	Deps.MissionService.FormSquadsForFaction(faction, players)
end

local function runReinforcementLoop(myToken: number)
	while roundToken == myToken and state == Enums.RoundState.Active do
		task.wait(GameConfig.ReinforcementWaveIntervalSeconds)
		if roundToken ~= myToken or state ~= Enums.RoundState.Active then
			return
		end

		local elapsed = os.clock() - roundStartClock
		local queue = Deps.ClassService.GetSpectatorQueue()
		if #queue == 0 then
			continue
		end

		local foundationAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.Foundation)
		local chaosAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.ChaosInsurgency)
		local scpAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.SCP)

		local mtfEligible = elapsed >= GameConfig.MTFReinforceDelaySeconds and foundationAlive < 12
		local chaosEligible = elapsed >= GameConfig.ChaosSpawnDelaySeconds and chaosAlive < 8

		if mtfEligible and foundationAlive <= (scpAlive + chaosAlive) then
			local group = Deps.ClassService.PopFromSpectatorQueue(GameConfig.SquadSize)
			spawnRosterWave("MTF", Enums.Faction.Foundation, group)
			Deps.NotifyService.ToastAll("MTF Nu-7 reinforcements have arrived.", "info")
		elseif chaosEligible then
			local group = Deps.ClassService.PopFromSpectatorQueue(GameConfig.SquadSize)
			spawnRosterWave("Chaos", Enums.Faction.ChaosInsurgency, group)
			Deps.NotifyService.ToastAll("Chaos Insurgency operatives have infiltrated the facility.", "warning")
		end
	end
end

local function checkWinConditions()
	if state ~= Enums.RoundState.Active then
		return
	end
	local elapsed = os.clock() - roundStartClock
	local chaosInPlay = elapsed >= GameConfig.ChaosSpawnDelaySeconds

	local scpAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.SCP)
	local foundationAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.Foundation)
	local chaosAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.ChaosInsurgency)
	local dclassAlive = Deps.ClassService.GetAliveCountByFaction(Enums.Faction.DClass)

	if scpAlive == 0 then
		endRound(Enums.RoundEndReason.FoundationVictory)
		return
	end

	if foundationAlive + chaosAlive + dclassAlive == 0 then
		endRound(Enums.RoundEndReason.SCPVictory)
		return
	end

	if chaosInPlay and foundationAlive == 0 and chaosAlive > 0 then
		endRound(Enums.RoundEndReason.ChaosVictory)
		return
	end
end

function RoundService.NotifyPlayerDied(_player: Player)
	task.defer(checkWinConditions)
end

local function detonateWarhead(myToken: number)
	if roundToken ~= myToken or state ~= Enums.RoundState.Active or not warheadArmed then
		return
	end
	Deps.NotifyService.ToastAll("The facility has been destroyed by the warhead.", "danger")
	Remotes.WarheadUpdate:FireAllClients({ active = false, detonated = true })

	for _, player in ipairs(Players:GetPlayers()) do
		if Deps.ClassService.IsAlive(player) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				Deps.CombatService.ApplyDamage(nil, humanoid, math.huge)
			end
		end
	end

	endRound(Enums.RoundEndReason.Warhead)
end

local function refreshWarheadPromptText(prompt: ProximityPrompt)
	prompt.ActionText = warheadArmed and "Disarm Warhead" or "Arm Warhead"
	prompt.ObjectText = "Alpha Warhead Control"
end

local function wireWarheadPanel(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 2
		prompt.MaxActivationDistance = 8
		prompt.Parent = instance
	end
	refreshWarheadPromptText(prompt)

	prompt.Triggered:Connect(function(player: Player)
		if state ~= Enums.RoundState.Active then
			return
		end
		if not Deps.KeycardService.HasAccess(player, 4) then
			Deps.NotifyService.Toast(player, "Insufficient clearance for warhead control.", "warning")
			return
		end

		if warheadArmed then
			warheadArmed = false
			Deps.NotifyService.ToastAll("Warhead disarmed.", "info")
			Remotes.WarheadUpdate:FireAllClients({ active = false })
		else
			warheadArmed = true
			local myToken = roundToken
			Deps.NotifyService.ToastAll(
				`WARHEAD ARMED by {player.Name}. Detonation in {GameConfig.WarheadFuseSeconds} seconds.`,
				"danger"
			)
			Remotes.WarheadUpdate:FireAllClients({ active = true, duration = GameConfig.WarheadFuseSeconds })
			task.delay(GameConfig.WarheadFuseSeconds, function()
				detonateWarhead(myToken)
			end)
		end
		refreshWarheadPromptText(prompt)
	end)
end

local function setupWarheadPanels()
	if warheadPanelsWired then
		return
	end
	warheadPanelsWired = true
	for _, instance in ipairs(CollectionService:GetTagged("WarheadPanel")) do
		wireWarheadPanel(instance)
	end
	CollectionService:GetInstanceAddedSignal("WarheadPanel"):Connect(wireWarheadPanel)
end

function startActiveRound()
	state = Enums.RoundState.Active
	roundToken += 1
	local myToken = roundToken
	roundStartClock = os.clock()
	warheadArmed = false

	Deps.ClassService.ResetForNewRound()
	Deps.MissionService.ResetForNewRound()
	Deps.DoorService.ResetAllDoors()

	local players = Players:GetPlayers()
	local roster = Deps.ClassService.BuildInitialRoster(players)

	local byFaction: { [string]: { Player } } = {}
	for player, classId in pairs(roster) do
		Deps.ClassService.SpawnCharacterForClass(player, classId)
		local faction = ClassConfig[classId].Faction
		byFaction[faction] = byFaction[faction] or {}
		table.insert(byFaction[faction], player)
	end

	for _, faction in ipairs({ Enums.Faction.Foundation, Enums.Faction.DClass }) do
		if byFaction[faction] then
			Deps.MissionService.FormSquadsForFaction(faction, byFaction[faction])
		end
	end

	broadcast({ timeLeft = GameConfig.RoundLengthSeconds })

	task.spawn(runReinforcementLoop, myToken)

	task.spawn(function()
		local remaining = GameConfig.RoundLengthSeconds
		while remaining > 0 do
			if roundToken ~= myToken or state ~= Enums.RoundState.Active then
				return
			end
			task.wait(3)
			remaining -= 3
			checkWinConditions()
		end
		if roundToken == myToken and state == Enums.RoundState.Active then
			endRound(Enums.RoundEndReason.TimeLimit)
		end
	end)
end

function endRound(reason: string)
	if state ~= Enums.RoundState.Active then
		return
	end
	state = Enums.RoundState.Ending
	roundToken += 1
	broadcast({ reason = reason })
	Deps.NotifyService.ToastAll(`Round over: {reason}`, "info")

	task.delay(GameConfig.RoundEndDisplaySeconds, function()
		state = Enums.RoundState.Lobby
		maybeStartFromLobby()
	end)
end

function RoundService.Init(deps: any)
	Deps = deps

	Remotes.GetInitialState.OnServerInvoke = function(player: Player)
		return {
			state = state,
			classId = Deps.ClassService.GetPlayerClass(player),
		}
	end

	Players.PlayerAdded:Connect(function(player)
		if state == Enums.RoundState.Active then
			Deps.ClassService.EnterSpectator(player)
		end
		maybeStartFromLobby()
	end)

	Players.PlayerRemoving:Connect(function()
		-- Falling below MinPlayersToStart mid-intermission is handled by the
		-- intermission loop's own check each second; only Active needs a nudge
		-- here since a departing player might complete a win condition.
		if state == Enums.RoundState.Active then
			task.defer(checkWinConditions)
		end
	end)

	setupWarheadPanels()
	maybeStartFromLobby()
end

return RoundService
