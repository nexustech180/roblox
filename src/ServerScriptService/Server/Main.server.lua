--!strict
-- Server bootstrap. Requires every service exactly once, wires them together
-- through a shared "Deps" locator (so services never require each other and
-- can't deadlock on circular requires), then calls Init on each in dependency
-- order. RoundService.Init runs last because it immediately starts checking
-- whether the round should begin, which touches everything else.

local Players = game:GetService("Players")

-- Custom spawn locations (per-class, tagged) replace the default StarterPlayer
-- spawn flow entirely - ClassService decides exactly when/where to spawn.
Players.CharacterAutoLoads = false

local Services = script.Services
local Admin = script.Admin

local MapScaffold = require(script.MapScaffold)
MapScaffold.Build()

local LoggingService = require(Services.LoggingService)
local AntiExploitService = require(Services.AntiExploitService)
local NotifyService = require(Services.NotifyService)
local DataService = require(Services.DataService)
local ClassService = require(Services.ClassService)
local InventoryService = require(Services.InventoryService)
local CombatService = require(Services.CombatService)
local KeycardService = require(Services.KeycardService)
local DoorService = require(Services.DoorService)
local SCPAbilityService = require(Services.SCPAbilityService)
local MissionService = require(Services.MissionService)
local RoundService = require(Services.RoundService)
local AdminCommands = require(Admin.AdminCommands)

local Deps = {
	LoggingService = LoggingService,
	AntiExploitService = AntiExploitService,
	NotifyService = NotifyService,
	DataService = DataService,
	ClassService = ClassService,
	InventoryService = InventoryService,
	CombatService = CombatService,
	KeycardService = KeycardService,
	DoorService = DoorService,
	SCPAbilityService = SCPAbilityService,
	MissionService = MissionService,
	RoundService = RoundService,
	AdminCommands = AdminCommands,
}

local INIT_ORDER = {
	LoggingService,
	AntiExploitService,
	NotifyService,
	DataService,
	ClassService,
	InventoryService,
	CombatService,
	KeycardService,
	DoorService,
	SCPAbilityService,
	MissionService,
	AdminCommands,
	RoundService, -- last: kicks off the Lobby/Intermission loop
}

for _, service in ipairs(INIT_ORDER) do
	local ok, err = pcall(service.Init, Deps)
	if not ok then
		LoggingService.Error(`Service failed to init: {err}`)
	end
end

LoggingService.Info("SCP Foundation: Chronicles server booted.")
