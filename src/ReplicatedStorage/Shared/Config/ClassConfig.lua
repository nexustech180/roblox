--!strict
-- Single source of truth for every playable class (SCP:SL-style "roles").
-- RoundService reads this to build the roster; ClassService reads it to spawn/equip;
-- client controllers read it to render class cards. Never hardcode class stats elsewhere.

export type ClassId = string

export type ClassDefinition = {
	Id: ClassId,
	DisplayName: string,
	Faction: string, -- "DClass" | "Foundation" | "ChaosInsurgency" | "SCP"
	MaxHealth: number,
	WalkSpeed: number,
	KeycardLevel: number, -- 0..5, see KeycardConfig
	Tools: { string },
	Description: string,
	SpawnTag: string, -- CollectionService tag on SpawnLocation parts
	TeamColor: Color3,
	IsSCP: boolean,
	AvailableFromStart: boolean,
	UnlockDelay: number?, -- seconds into the round before this class can be assigned
	RosterWeight: number, -- relative share of the initial (t=0) roster
	MaxRosterCount: number?, -- hard cap regardless of weight (mainly for SCPs)
}

local GameConfig = require(script.Parent.GameConfig)

local ClassConfig: { [ClassId]: ClassDefinition } = {

	DClass = {
		Id = "DClass",
		DisplayName = "Class-D Personnel",
		Faction = "DClass",
		MaxHealth = 100,
		WalkSpeed = 16,
		KeycardLevel = 0,
		Tools = {},
		Description = "No weapon. No keycard. Your only ways out are the surface elevator, an unlocked door, or a Foundation escort who takes pity on you.",
		SpawnTag = "Spawn_DClass",
		TeamColor = Color3.fromRGB(196, 160, 84),
		IsSCP = false,
		AvailableFromStart = true,
		RosterWeight = 0.34,
	},

	Scientist = {
		Id = "Scientist",
		DisplayName = "Facility Scientist",
		Faction = "Foundation",
		MaxHealth = 100,
		WalkSpeed = 16,
		KeycardLevel = 2,
		Tools = { "Radio", "Flashlight" },
		Description = "Keep the lights on and the containment procedures running. You can open most labs, but you are unarmed and fragile.",
		SpawnTag = "Spawn_Scientist",
		TeamColor = Color3.fromRGB(255, 255, 255),
		IsSCP = false,
		AvailableFromStart = true,
		RosterWeight = 0.20,
	},

	Guard = {
		Id = "Guard",
		DisplayName = "Facility Guard",
		Faction = "Foundation",
		MaxHealth = 110,
		WalkSpeed = 16,
		KeycardLevel = 3,
		Tools = { "P90", "Flashlight", "Radio" },
		Description = "Front-line Foundation security. Escort D-Class, hold checkpoints, and respond to containment breaches.",
		SpawnTag = "Spawn_Guard",
		TeamColor = Color3.fromRGB(60, 100, 200),
		IsSCP = false,
		AvailableFromStart = true,
		RosterWeight = 0.21,
	},

	MTF = {
		Id = "MTF",
		DisplayName = "MTF Nu-7 \"Hammer Down\"",
		Faction = "Foundation",
		MaxHealth = 125,
		WalkSpeed = 16,
		KeycardLevel = 4,
		Tools = { "AK", "Flashlight", "Radio", "Medkit" },
		Description = "Heavy reinforcements dropped in once the situation deteriorates. Best gear on the Foundation side.",
		SpawnTag = "Spawn_MTF",
		TeamColor = Color3.fromRGB(20, 60, 20),
		IsSCP = false,
		AvailableFromStart = false,
		UnlockDelay = GameConfig.MTFReinforceDelaySeconds,
		RosterWeight = 0.15,
	},

	Chaos = {
		Id = "Chaos",
		DisplayName = "Chaos Insurgency",
		Faction = "ChaosInsurgency",
		MaxHealth = 115,
		WalkSpeed = 17,
		KeycardLevel = 0,
		Tools = { "AKChaos", "Radio" },
		Description = "Former D-Class turned insurgents. Free your brothers and put the Foundation in the ground.",
		SpawnTag = "Spawn_Chaos",
		TeamColor = Color3.fromRGB(120, 30, 30),
		IsSCP = false,
		AvailableFromStart = false,
		UnlockDelay = GameConfig.ChaosSpawnDelaySeconds,
		RosterWeight = 0.10,
	},

	SCP173 = {
		Id = "SCP173",
		DisplayName = "SCP-173 \"The Sculpture\"",
		Faction = "SCP",
		MaxHealth = 300,
		WalkSpeed = 0, -- movement is entirely ability-driven (see SCPAbilityService)
		KeycardLevel = 0,
		Tools = {},
		Description = "Do not look away. Do not blink. It only moves when it is not observed.",
		SpawnTag = "Spawn_SCP_173",
		TeamColor = Color3.fromRGB(140, 140, 140),
		IsSCP = true,
		AvailableFromStart = true,
		RosterWeight = 0,
		MaxRosterCount = 1,
	},

	SCP049 = {
		Id = "SCP049",
		DisplayName = "SCP-049 \"The Plague Doctor\"",
		Faction = "SCP",
		MaxHealth = 175,
		WalkSpeed = 16,
		KeycardLevel = 0,
		Tools = {},
		Description = "He believes he can cure the Pestilence. He is wrong, and his cure does not leave survivors.",
		SpawnTag = "Spawn_SCP_049",
		TeamColor = Color3.fromRGB(40, 70, 40),
		IsSCP = true,
		AvailableFromStart = true,
		RosterWeight = 0,
		MaxRosterCount = 1,
	},

	SCP096 = {
		Id = "SCP096",
		DisplayName = "SCP-096 \"The Shy Guy\"",
		Faction = "SCP",
		MaxHealth = 400,
		WalkSpeed = 8,
		KeycardLevel = 0,
		Tools = {},
		Description = "Passive until its face is seen. Then nothing in the facility can stop it from reaching you.",
		SpawnTag = "Spawn_SCP_096",
		TeamColor = Color3.fromRGB(200, 200, 210),
		IsSCP = true,
		AvailableFromStart = true,
		RosterWeight = 0,
		MaxRosterCount = 1,
	},

	SCP106 = {
		Id = "SCP106",
		DisplayName = "SCP-106 \"The Old Man\"",
		Faction = "SCP",
		MaxHealth = 500,
		WalkSpeed = 14,
		KeycardLevel = 0,
		Tools = {},
		Description = "Corrodes everything it touches and phases through solid matter at will. There is no safe room.",
		SpawnTag = "Spawn_SCP_106",
		TeamColor = Color3.fromRGB(50, 35, 25),
		IsSCP = true,
		AvailableFromStart = true,
		RosterWeight = 0,
		MaxRosterCount = 1,
	},
}

-- SCPs are capped/gated by population, not by RosterWeight, so callers should
-- iterate this list to decide which SCPs are "in play" for the current headcount.
ClassConfig._SCPActivationOrder = { "SCP173", "SCP049", "SCP096", "SCP106" }

return ClassConfig
