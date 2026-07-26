--!strict
-- Mission pool consumed by MissionService. Missions are handed out per-squad
-- (see GameConfig.SquadSize), not per-player, so a group of friends always
-- works the same objective together.
--
-- ObjectiveType meanings (enforced server-side in MissionService):
--   "ReachZone"      -> any squad member touches a part tagged with ZoneTag
--   "InteractPart"   -> any squad member fires the InteractPart remote while
--                        near a part tagged with PartTag (e.g. a terminal)
--   "EliminateCount" -> squad's combined kills against TargetFaction reach Count
--   "SurviveTime"    -> squad has at least one member alive when DurationSeconds elapses

export type ObjectiveType = "ReachZone" | "InteractPart" | "EliminateCount" | "SurviveTime"

export type Objective = {
	Type: ObjectiveType,
	ZoneTag: string?,
	PartTag: string?,
	TargetFaction: string?,
	Count: number?,
	DurationSeconds: number?,
	Description: string,
}

export type MissionDefinition = {
	Id: string,
	DisplayName: string,
	Faction: string, -- which faction pool this mission is drawn for
	Objectives: { Objective }, -- completed in order
	RewardCredits: number,
	RewardXP: number,
	-- Minimum total players on the server for this mission to be eligible.
	-- Defaults to 1 (solo-friendly) when omitted. EliminateCount missions need
	-- actual hostile targets to exist, so they set this higher - see
	-- MissionService.assignMissionToSquad, which filters the pool by this
	-- against #Players:GetPlayers() before picking.
	MinPlayers: number?,
}

local MissionConfig: { [string]: MissionDefinition } = {

	ContainTheBreach = {
		Id = "ContainTheBreach",
		DisplayName = "Contain The Breach",
		Faction = "Foundation",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Reach the containment wing." },
			{ Type = "InteractPart", PartTag = "Terminal_Containment", Description = "Lock down containment from the terminal." },
		},
		RewardCredits = 150,
		RewardXP = 100,
	},

	RecoverIntel = {
		Id = "RecoverIntel",
		DisplayName = "Recover Classified Intel",
		Faction = "Foundation",
		Objectives = {
			{ Type = "InteractPart", PartTag = "Terminal_Intel", Description = "Download the files from the intel terminal." },
		},
		RewardCredits = 100,
		RewardXP = 75,
	},

	NeutralizeChaosCell = {
		Id = "NeutralizeChaosCell",
		DisplayName = "Neutralize Chaos Cell",
		Faction = "Foundation",
		Objectives = {
			{ Type = "EliminateCount", TargetFaction = "ChaosInsurgency", Count = 3, Description = "Eliminate 3 Chaos Insurgency operatives." },
		},
		RewardCredits = 175,
		RewardXP = 125,
		MinPlayers = 4,
	},

	LiberateClassD = {
		Id = "LiberateClassD",
		DisplayName = "Liberate Class-D",
		Faction = "ChaosInsurgency",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_DClassCells", Description = "Reach the Class-D holding cells." },
			{ Type = "InteractPart", PartTag = "Terminal_CellRelease", Description = "Release the cell locks." },
		},
		RewardCredits = 150,
		RewardXP = 100,
	},

	SeizeArmory = {
		Id = "SeizeArmory",
		DisplayName = "Seize The Armory",
		Faction = "ChaosInsurgency",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Armory", Description = "Take control of the armory." },
		},
		RewardCredits = 120,
		RewardXP = 80,
	},

	EliminateCommand = {
		Id = "EliminateCommand",
		DisplayName = "Eliminate Foundation Command",
		Faction = "ChaosInsurgency",
		Objectives = {
			{ Type = "EliminateCount", TargetFaction = "Foundation", Count = 3, Description = "Eliminate 3 Foundation personnel." },
		},
		RewardCredits = 175,
		RewardXP = 125,
		MinPlayers = 4,
	},

	ReachTheSurface = {
		Id = "ReachTheSurface",
		DisplayName = "Reach The Surface",
		Faction = "DClass",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Surface", Description = "Escape through the surface elevator." },
		},
		RewardCredits = 200,
		RewardXP = 150,
	},

	SurviveTheNight = {
		Id = "SurviveTheNight",
		DisplayName = "Survive",
		Faction = "DClass",
		Objectives = {
			{ Type = "SurviveTime", DurationSeconds = 600, Description = "Stay alive for 10 minutes." },
		},
		RewardCredits = 100,
		RewardXP = 90,
	},
}

MissionConfig._PoolByFaction = {
	Foundation = { "ContainTheBreach", "RecoverIntel", "NeutralizeChaosCell" },
	ChaosInsurgency = { "LiberateClassD", "SeizeArmory", "EliminateCommand" },
	DClass = { "ReachTheSurface", "SurviveTheNight" },
}

return MissionConfig
