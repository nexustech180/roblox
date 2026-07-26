--!strict
-- Server bootstrap. Requires every service exactly once, wires them together
-- through a shared "Deps" locator (so services never require each other and
-- can't deadlock on circular requires), then calls Init on each in dependency
-- order. SessionService.Init runs last because it immediately spawns anyone
-- whose profile has already loaded, which touches everything else.

local Players = game:GetService("Players")

-- Custom spawn locations (per-class, tagged) replace the default StarterPlayer
-- spawn flow entirely - ClassService decides exactly when/where to spawn.
Players.CharacterAutoLoads = false

local Services = script.Parent.Services
local Admin = script.Parent.Admin

local MapScaffold = require(script.Parent.MapScaffold)
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
local NPCService = require(Services.NPCService)
local MissionService = require(Services.MissionService)
local AdminCommands = require(Admin.AdminCommands)
local SessionService = require(Services.SessionService)

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
	NPCService = NPCService,
	MissionService = MissionService,
	AdminCommands = AdminCommands,
	SessionService = SessionService,
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
	NPCService,
	MissionService,
	AdminCommands,
	SessionService, -- last: spawns players once everything else is ready
}

for _, service in ipairs(INIT_ORDER) do
	local ok, err = pcall(service.Init, Deps)
	if not ok then
		LoggingService.Error(`Service failed to init: {err}`)
	end
end

LoggingService.Info("SCP Foundation: Chronicles server booted.")
