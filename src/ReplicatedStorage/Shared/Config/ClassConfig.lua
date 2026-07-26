--!strict
-- Single source of truth for every class. This is a career-progression
-- game: you start as Class-D and rank up through personnel clearance by
-- leveling (see UnlockLevel), then freely switch between anything you've
-- unlocked via the class menu - exactly like sailing to a new Sea by level
-- in a game like Blox Fruits. The clearance ladder below uses the same
-- breakpoints Blox Fruits uses for its Seas (700 / 1500 / 2450) since
-- that's the exact pacing being borrowed.
--
-- ClassService reads UnlockLevel to gate RequestClassChange; MapScaffold
-- reads SpawnTag to lay out one spawn pad per class automatically.
--
-- NOTE: SCP-049/SCP-106 are still defined here as classes for now, but
-- they're moving to a separate, price-gated "Helper SCP" system (own +
-- equip many, not level-locked to one at a time) - see the project plan.
-- Their UnlockLevel is bumped above Class-A purely so the interim class
-- menu orders sensibly; don't tune these further, they're getting replaced.

export type ClassId = string

export type ClassDefinition = {
	Id: ClassId,
	DisplayName: string,
	Track: string, -- flavor grouping for UI color/label only, no gameplay meaning
	MaxHealth: number,
	WalkSpeed: number,
	KeycardLevel: number, -- 0..5, see KeycardConfig
	Tools: { string },
	Description: string,
	SpawnTag: string, -- CollectionService tag on the spawn part for this class
	TeamColor: Color3,
	IsSCP: boolean,
	UnlockLevel: number, -- profile.Level required before this class can be selected
}

local ClassConfig: { [ClassId]: ClassDefinition } = {

	DClass = {
		Id = "DClass",
		DisplayName = "Class-D Personnel",
		Track = "DClass",
		MaxHealth = 100,
		WalkSpeed = 16,
		KeycardLevel = 0,
		Tools = {},
		Description = "Where everyone starts. No weapon, no keycard, no respect. Grind enough menial errands and you'll earn real clearance.",
		SpawnTag = "Spawn_DClass",
		TeamColor = Color3.fromRGB(196, 160, 84),
		IsSCP = false,
		UnlockLevel = 1,
	},

	ClassC = {
		Id = "ClassC",
		DisplayName = "Class-C Personnel",
		Track = "Foundation",
		MaxHealth = 110,
		WalkSpeed = 16,
		KeycardLevel = 3,
		Tools = { "P90", "Flashlight", "Radio" },
		Description = "Real clearance, first weapon. Handles security-lite duty and can finally carry a sidearm. Helper SCPs become usable from here on.",
		SpawnTag = "Spawn_ClassC",
		TeamColor = Color3.fromRGB(255, 255, 255),
		IsSCP = false,
		UnlockLevel = 700,
	},

	ClassB = {
		Id = "ClassB",
		DisplayName = "Class-B Personnel",
		Track = "Foundation",
		MaxHealth = 125,
		WalkSpeed = 16,
		KeycardLevel = 4,
		Tools = { "AK", "Flashlight", "Radio", "Medkit" },
		Description = "Frontline tactical response. Rifle, medkit, and the access to back it up.",
		SpawnTag = "Spawn_ClassB",
		TeamColor = Color3.fromRGB(60, 100, 200),
		IsSCP = false,
		UnlockLevel = 1500,
	},

	ClassA = {
		Id = "ClassA",
		DisplayName = "Class-A Personnel (O5 Command)",
		Track = "Foundation",
		MaxHealth = 150,
		WalkSpeed = 17,
		KeycardLevel = 5,
		Tools = { "AK", "Medkit", "Flashlight", "Radio" },
		Description = "The top of the conventional ladder. Full clearance, command-grade loadout - everything below answers to you.",
		SpawnTag = "Spawn_ClassA",
		TeamColor = Color3.fromRGB(180, 20, 20),
		IsSCP = false,
		UnlockLevel = 2450,
	},

	SCP049 = {
		Id = "SCP049",
		DisplayName = "SCP-049 \"The Plague Doctor\"",
		Track = "SCP",
		MaxHealth = 200,
		WalkSpeed = 16,
		KeycardLevel = 0,
		Tools = {},
		Description = "He believes he can cure the Pestilence - his cure does not leave survivors.",
		SpawnTag = "Spawn_SCP_049",
		TeamColor = Color3.fromRGB(40, 70, 40),
		IsSCP = true,
		UnlockLevel = 2600,
	},

	SCP106 = {
		Id = "SCP106",
		DisplayName = "SCP-106 \"The Old Man\"",
		Track = "SCP",
		MaxHealth = 300,
		WalkSpeed = 14,
		KeycardLevel = 0,
		Tools = {},
		Description = "Corrodes everything it touches and phases through solid matter at will.",
		SpawnTag = "Spawn_SCP_106",
		TeamColor = Color3.fromRGB(50, 35, 25),
		IsSCP = true,
		UnlockLevel = 3200,
	},
}

-- Ordered ascending by UnlockLevel, used to render the class-change menu and
-- to find "what's the next class I haven't unlocked yet" for UI hints.
ClassConfig._UnlockOrder = {
	"DClass",
	"ClassC",
	"ClassB",
	"ClassA",
	"SCP049",
	"SCP106",
}

return ClassConfig
