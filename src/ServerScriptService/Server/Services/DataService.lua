--!strict
-- Owns all player persistence: DataStore load/save, leaderstats, and the
-- XP/level/credits economy that missions and kills feed into.
--
-- Deliberately simple (load-on-join, save-on-leave/interval/close) rather than
-- a full session-locking profile library - correct for a single-server game,
-- and easy to swap for ProfileService later if this ever needs cross-server play.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

type Profile = ProfileTemplate.Profile

local DataStore = DataStoreService:GetDataStore("SCPFoundation_PlayerProfiles_v1")

local AUTOSAVE_INTERVAL_SECONDS = 120
local SAVE_RETRY_ATTEMPTS = 3

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player: Player, profile: Profile)
DataService.LeveledUp = Signal.new() -- (player: Player, newLevel: number)

local profiles: { [Player]: Profile } = {}
local savingInProgress: { [Player]: boolean } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value :: any) do
		copy[k] = deepCopy(v)
	end
	return (copy :: any) :: T
end

-- "Studio access to API Services" being off (the default for a new/unpublished
-- place) makes every DataStore call fail immediately and permanently - no
-- amount of retrying fixes that. Recognize it and bail after one attempt
-- instead of burning ~4.5 real seconds retrying a call that can never
-- succeed, which otherwise reads as "the game is stuck/broken" on first test.
local function isStudioApiDisabledError(err: string): boolean
	local lower = string.lower(err)
	return string.find(lower, "studio", 1, true) ~= nil
		or string.find(lower, "api services", 1, true) ~= nil
end

local function withRetry<T>(fn: () -> T, attempts: number): (boolean, T | string)
	local lastError: string = "unknown error"
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if isStudioApiDisabledError(lastError) then
			break
		end
		task.wait(1.5 * attempt)
	end
	return false, lastError
end

local function mergeMissingKeys(profile: { [string]: any }, template: { [string]: any })
	for key, value in pairs(template) do
		if profile[key] == nil then
			-- Must deep-copy: assigning `value` directly for a table-typed
			-- default (e.g. OwnedSCPIds) would alias every migrated profile
			-- to the SAME shared ProfileTemplate table, so mutating one
			-- player's list (table.insert) would corrupt everyone else's.
			profile[key] = deepCopy(value)
		end
	end
end

local function xpRequiredForLevel(level: number): number
	-- math.max(1, ...) matters: with the current curve, level 1 floors to 0
	-- XP required, which would silently advance a brand-new (XP=0) profile
	-- straight to level 2 the moment recomputeLevel runs below.
	return math.max(1, math.floor(GameConfig.XPCurveBase * level ^ GameConfig.XPCurveExponent))
end

local function recomputeLevel(profile: Profile)
	local level = 1
	local xpLeft = profile.XP
	while xpLeft >= xpRequiredForLevel(level) do
		xpLeft -= xpRequiredForLevel(level)
		level += 1
	end
	return level
end

local function buildLeaderstats(player: Player, profile: Profile)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Level
	level.Parent = leaderstats

	local glint = Instance.new("IntValue")
	glint.Name = "Glint"
	glint.Value = profile.Glint
	glint.Parent = leaderstats

	local ducats = Instance.new("IntValue")
	ducats.Name = "Ducats"
	ducats.Value = profile.AethericDucats
	ducats.Parent = leaderstats

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = profile.Kills
	kills.Parent = leaderstats

	leaderstats.Parent = player
end

local function syncLeaderstats(player: Player, profile: Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	local glint = leaderstats:FindFirstChild("Glint") :: IntValue?
	local ducats = leaderstats:FindFirstChild("Ducats") :: IntValue?
	local kills = leaderstats:FindFirstChild("Kills") :: IntValue?
	if level then
		level.Value = profile.Level
	end
	if glint then
		glint.Value = profile.Glint
	end
	if ducats then
		ducats.Value = profile.AethericDucats
	end
	if kills then
		kills.Value = profile.Kills
	end
end

function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.LoadProfile(player: Player)
	local key = "Player_" .. player.UserId

	local ok, result = withRetry(function()
		return DataStore:GetAsync(key)
	end, SAVE_RETRY_ATTEMPTS)

	local profile: Profile
	if ok and type(result) == "table" then
		profile = result :: Profile
		mergeMissingKeys(profile :: any, ProfileTemplate :: any)
	else
		if not ok then
			local hint = isStudioApiDisabledError(tostring(result))
				and " (enable \"Studio Access to API Services\" in Game Settings > Security to persist data while testing)"
				or ""
			warn(`[DataService] Failed to load profile for {player.Name}: {result}. Using a fresh profile.{hint}`)
		end
		profile = deepCopy(ProfileTemplate)
	end

	profile.Level = recomputeLevel(profile)
	profiles[player] = profile

	buildLeaderstats(player, profile)
	DataService.ProfileLoaded:Fire(player, profile)
end

function DataService.SaveProfile(player: Player, isFinal: boolean?): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if savingInProgress[player] and not isFinal then
		return false
	end

	savingInProgress[player] = true
	local key = "Player_" .. player.UserId
	local snapshot = deepCopy(profile)

	local ok, err = withRetry(function()
		DataStore:SetAsync(key, snapshot)
	end, SAVE_RETRY_ATTEMPTS)

	savingInProgress[player] = false

	if not ok then
		warn(`[DataService] Failed to save profile for {player.Name}: {err}`)
	end
	return ok
end

function DataService.AddGlint(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Glint = math.max(0, profile.Glint + amount)
	syncLeaderstats(player, profile)
end

function DataService.AddDucats(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.AethericDucats = math.max(0, profile.AethericDucats + amount)
	syncLeaderstats(player, profile)
end

function DataService.AddXP(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.XP += amount
	local newLevel = recomputeLevel(profile)
	if newLevel > profile.Level then
		profile.Level = newLevel
		DataService.LeveledUp:Fire(player, newLevel)
	end
	syncLeaderstats(player, profile)
end

function DataService.SetCurrentClass(player: Player, classId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.CurrentClassId = classId
end

function DataService.IncrementStat(player: Player, statName: string, amount: number?)
	local profile = profiles[player]
	if not profile then
		return
	end
	local current = (profile :: any)[statName]
	if type(current) ~= "number" then
		return
	end
	(profile :: any)[statName] = current + (amount or 1)
	syncLeaderstats(player, profile)
end

function DataService.Init()
	Players.PlayerAdded:Connect(DataService.LoadProfile)
	Players.PlayerRemoving:Connect(function(player)
		DataService.SaveProfile(player, true)
		profiles[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.LoadProfile, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.SaveProfile(player, false)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.SaveProfile(player, true)
		end
	end)
end

return DataService
