--!strict
-- Single source of truth for every class. This is a solo career-progression
-- game: you start as Class-D and unlock better classes by leveling up (see
-- UnlockLevel), then freely switch between anything you've already unlocked
-- via the class-change terminal - exactly like unlocking fighting styles/
-- islands by level in a game like Blox Fruits. ClassService reads UnlockLevel
-- to gate MissionService.RequestClassChange; MapScaffold reads SpawnTag to
-- lay out one spawn pad per class automatically.

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
		Description = "Where everyone starts. No weapon, no keycard, no respect. Grind enough menial errands and you'll earn a real job.",
		SpawnTag = "Spawn_DClass",
		TeamColor = Color3.fromRGB(196, 160, 84),
		IsSCP = false,
		UnlockLevel = 1,
	},

	Scientist = {
		Id = "Scientist",
		DisplayName = "Facility Scientist",
		Track = "Foundation",
		MaxHealth = 100,
		WalkSpeed = 16,
		KeycardLevel = 2,
		Tools = { "Radio", "Flashlight" },
		Description = "Real clearance, still unarmed. Keeps the lights on and the containment logs current.",
		SpawnTag = "Spawn_Scientist",
		TeamColor = Color3.fromRGB(255, 255, 255),
		IsSCP = false,
		UnlockLevel = 50,
	},

	Guard = {
		Id = "Guard",
		DisplayName = "Facility Guard",
		Track = "Foundation",
		MaxHealth = 110,
		WalkSpeed = 16,
		KeycardLevel = 3,
		Tools = { "P90", "Flashlight", "Radio" },
		Description = "First armed job in the Foundation. Escort duty, patrol duty, and containment response.",
		SpawnTag = "Spawn_Guard",
		TeamColor = Color3.fromRGB(60, 100, 200),
		IsSCP = false,
		UnlockLevel = 150,
	},

	ChaosRenegade = {
		Id = "ChaosRenegade",
		DisplayName = "Chaos Renegade",
		Track = "Renegade",
		MaxHealth = 115,
		WalkSpeed = 18,
		KeycardLevel = 0,
		Tools = { "AKChaos", "Radio" },
		Description = "You went rogue. No clearance, no rules, better gear - a faster, harder-hitting off-the-books path.",
		SpawnTag = "Spawn_ChaosRenegade",
		TeamColor = Color3.fromRGB(120, 30, 30),
		IsSCP = false,
		UnlockLevel = 400,
	},

	MTF = {
		Id = "MTF",
		DisplayName = "MTF Nu-7 \"Hammer Down\"",
		Track = "Foundation",
		MaxHealth = 130,
		WalkSpeed = 16,
		KeycardLevel = 4,
		Tools = { "AK", "Flashlight", "Radio", "Medkit" },
		Description = "Elite tactical response. Best conventional loadout the Foundation issues.",
		SpawnTag = "Spawn_MTF",
		TeamColor = Color3.fromRGB(20, 60, 20),
		IsSCP = false,
		UnlockLevel = 550,
	},

	SiteDirector = {
		Id = "SiteDirector",
		DisplayName = "Site Director (O5 Command)",
		Track = "Foundation",
		MaxHealth = 150,
		WalkSpeed = 17,
		KeycardLevel = 5,
		Tools = { "AK", "Medkit", "Flashlight", "Radio" },
		Description = "The big milestone. Full clearance, command-grade loadout, and the respect of everyone still stuck as D-Class.",
		SpawnTag = "Spawn_SiteDirector",
		TeamColor = Color3.fromRGB(180, 20, 20),
		IsSCP = false,
		UnlockLevel = 700,
	},

	SCP049 = {
		Id = "SCP049",
		DisplayName = "SCP-049 \"The Plague Doctor\"",
		Track = "SCP",
		MaxHealth = 200,
		WalkSpeed = 16,
		KeycardLevel = 0,
		Tools = {},
		Description = "First prestige unlock. He believes he can cure the Pestilence - his cure does not leave survivors.",
		SpawnTag = "Spawn_SCP_049",
		TeamColor = Color3.fromRGB(40, 70, 40),
		IsSCP = true,
		UnlockLevel = 1200,
	},

	SCP106 = {
		Id = "SCP106",
		DisplayName = "SCP-106 \"The Old Man\"",
		Track = "SCP",
		MaxHealth = 300,
		WalkSpeed = 14,
		KeycardLevel = 0,
		Tools = {},
		Description = "The final unlock. Corrodes everything it touches and phases through solid matter at will.",
		SpawnTag = "Spawn_SCP_106",
		TeamColor = Color3.fromRGB(50, 35, 25),
		IsSCP = true,
		UnlockLevel = 1800,
	},
}

-- Ordered ascending by UnlockLevel, used to render the class-change menu and
-- to find "what's the next class I haven't unlocked yet" for UI hints.
ClassConfig._UnlockOrder = {
	"DClass",
	"Scientist",
	"Guard",
	"ChaosRenegade",
	"MTF",
	"SiteDirector",
	"SCP049",
	"SCP106",
}

return ClassConfig
