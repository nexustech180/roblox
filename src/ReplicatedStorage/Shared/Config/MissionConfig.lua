--!strict
-- Mission pool consumed by MissionService. Each class has its own small pool
-- of missions; MissionService hands them out one at a time from a shuffled
-- "bag" per player (draw without replacement, reshuffle when the bag empties)
-- so you keep repeating missions to grind XP without ever getting the exact
-- same one twice in a row.
--
-- ObjectiveType meanings (enforced server-side in MissionService):
--   "ReachZone"         -> touch a part tagged with ZoneTag
--   "InteractPart"      -> use the ProximityPrompt on a part tagged with PartTag
--   "EliminateNPCCount" -> kill BaseCount hostile NPCs spawned for this attempt
--   "SurviveTime"        -> stay alive until BaseDuration elapses
--
-- BaseCount/BaseDuration/BaseRewardGlint/BaseRewardXP are all scaled up by
-- MissionService using GameConfig.DifficultyLevelStep/DifficultyScalePerStep,
-- so the same mission gets meaningfully harder (and more rewarding) as you level.

export type ObjectiveType = "ReachZone" | "InteractPart" | "EliminateNPCCount" | "SurviveTime"

export type Objective = {
	Type: ObjectiveType,
	ZoneTag: string?,
	PartTag: string?,
	BaseCount: number?,
	BaseDurationSeconds: number?,
	Description: string,
}

export type MissionDefinition = {
	Id: string,
	DisplayName: string,
	ClassId: string, -- which class's pool this mission belongs to
	Objectives: { Objective },
	BaseRewardGlint: number,
	BaseRewardXP: number,
}

local MissionConfig: { [string]: MissionDefinition } = {

	-- ===== Class-D Personnel: unarmed errands, no combat =====
	SupplyRun = {
		Id = "SupplyRun",
		DisplayName = "Supply Run",
		ClassId = "DClass",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Surface", Description = "Carry the supply crate to the surface elevator." },
			{ Type = "ReachZone", ZoneTag = "Zone_DClassCells", Description = "Bring the empty crate back to the cell block." },
		},
		BaseRewardGlint = 20,
		BaseRewardXP = 40,
	},
	FileTheReport = {
		Id = "FileTheReport",
		DisplayName = "File The Incident Report",
		ClassId = "DClass",
		Objectives = {
			{ Type = "InteractPart", PartTag = "Terminal_Intel", Description = "File the incident report at the terminal." },
		},
		BaseRewardGlint = 15,
		BaseRewardXP = 30,
	},
	LateShift = {
		Id = "LateShift",
		DisplayName = "Late Shift",
		ClassId = "DClass",
		Objectives = {
			{ Type = "SurviveTime", BaseDurationSeconds = 90, Description = "Survive the late shift without incident." },
		},
		BaseRewardGlint = 20,
		BaseRewardXP = 35,
	},

	-- ===== Class-C Personnel =====
	RecoverResearchData = {
		Id = "RecoverResearchData",
		DisplayName = "Recover Research Data",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "InteractPart", PartTag = "Terminal_Intel", Description = "Pull the research data from the terminal." },
		},
		BaseRewardGlint = 35,
		BaseRewardXP = 70,
	},
	ContainTheBreach = {
		Id = "ContainTheBreach",
		DisplayName = "Contain The Breach",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Reach the containment wing." },
			{ Type = "InteractPart", PartTag = "Terminal_Containment", Description = "Lock down containment from the terminal." },
		},
		BaseRewardGlint = 45,
		BaseRewardXP = 90,
	},
	InventoryCheck = {
		Id = "InventoryCheck",
		DisplayName = "Armory Inventory Check",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Armory", Description = "Count the armory stock." },
		},
		BaseRewardGlint = 30,
		BaseRewardXP = 60,
	},

	NeutralizeIntruders = {
		Id = "NeutralizeIntruders",
		DisplayName = "Neutralize Intruders",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 3, Description = "Neutralize the intruders." },
		},
		BaseRewardGlint = 60,
		BaseRewardXP = 120,
	},
	SecureTheArmory = {
		Id = "SecureTheArmory",
		DisplayName = "Secure The Armory",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Armory", Description = "Secure the armory." },
		},
		BaseRewardGlint = 40,
		BaseRewardXP = 80,
	},
	CellBlockPatrol = {
		Id = "CellBlockPatrol",
		DisplayName = "Cell Block Patrol",
		ClassId = "ClassC",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_DClassCells", Description = "Patrol the cell block." },
			{ Type = "EliminateNPCCount", BaseCount = 2, Description = "Put down the rioters." },
		},
		BaseRewardGlint = 65,
		BaseRewardXP = 130,
	},

	-- ===== Class-B Personnel =====
	RaidTheArmory = {
		Id = "RaidTheArmory",
		DisplayName = "Raid The Armory",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Armory", Description = "Raid the armory." },
		},
		BaseRewardGlint = 55,
		BaseRewardXP = 110,
	},
	EliminateFoundationPatrol = {
		Id = "EliminateFoundationPatrol",
		DisplayName = "Eliminate Foundation Patrol",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 4, Description = "Eliminate the Foundation patrol." },
		},
		BaseRewardGlint = 80,
		BaseRewardXP = 160,
	},
	FreeThePrisoners = {
		Id = "FreeThePrisoners",
		DisplayName = "Free The Prisoners",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_DClassCells", Description = "Reach the cell block." },
			{ Type = "InteractPart", PartTag = "Terminal_CellRelease", Description = "Release the cell locks." },
		},
		BaseRewardGlint = 70,
		BaseRewardXP = 140,
	},

	PurgeHostiles = {
		Id = "PurgeHostiles",
		DisplayName = "Purge Hostiles",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 5, Description = "Purge all hostiles in the sector." },
		},
		BaseRewardGlint = 100,
		BaseRewardXP = 200,
	},
	RecoverClassifiedIntel = {
		Id = "RecoverClassifiedIntel",
		DisplayName = "Recover Classified Intel",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 3, Description = "Clear the guards off the terminal." },
			{ Type = "InteractPart", PartTag = "Terminal_Intel", Description = "Download the classified intel." },
		},
		BaseRewardGlint = 110,
		BaseRewardXP = 220,
	},
	ContainAndTerminate = {
		Id = "ContainAndTerminate",
		DisplayName = "Contain And Terminate",
		ClassId = "ClassB",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Reach the containment wing." },
			{ Type = "EliminateNPCCount", BaseCount = 4, Description = "Terminate the breach." },
		},
		BaseRewardGlint = 115,
		BaseRewardXP = 230,
	},

	-- ===== Class-A Personnel: endgame conventional tier =====
	FullFacilitySweep = {
		Id = "FullFacilitySweep",
		DisplayName = "Full Facility Sweep",
		ClassId = "ClassA",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 8, Description = "Sweep the entire facility." },
		},
		BaseRewardGlint = 160,
		BaseRewardXP = 320,
	},
	CommandOverride = {
		Id = "CommandOverride",
		DisplayName = "Command Override",
		ClassId = "ClassA",
		Objectives = {
			{ Type = "InteractPart", PartTag = "Terminal_Containment", Description = "Override containment protocols." },
			{ Type = "InteractPart", PartTag = "Terminal_Intel", Description = "Override the intel network." },
		},
		BaseRewardGlint = 140,
		BaseRewardXP = 280,
	},
	TotalLockdownResponse = {
		Id = "TotalLockdownResponse",
		DisplayName = "Total Lockdown Response",
		ClassId = "ClassA",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 6, Description = "Respond to the lockdown." },
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Personally secure containment." },
		},
		BaseRewardGlint = 175,
		BaseRewardXP = 350,
	},

	-- ===== SCP-049: prestige =====
	HuntTheLiving = {
		Id = "HuntTheLiving",
		DisplayName = "Hunt The Living",
		ClassId = "SCP049",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 5, Description = "Find a cure for all of them." },
		},
		BaseRewardGlint = 200,
		BaseRewardXP = 400,
	},
	PurgeTheWing = {
		Id = "PurgeTheWing",
		DisplayName = "Purge The Wing",
		ClassId = "SCP049",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Return to your wing." },
			{ Type = "EliminateNPCCount", BaseCount = 7, Description = "Purge the wing of the Pestilence." },
		},
		BaseRewardGlint = 230,
		BaseRewardXP = 460,
	},
	EndlessPlague = {
		Id = "EndlessPlague",
		DisplayName = "Endless Plague",
		ClassId = "SCP049",
		Objectives = {
			{ Type = "SurviveTime", BaseDurationSeconds = 240, Description = "Outlast the outbreak." },
		},
		BaseRewardGlint = 210,
		BaseRewardXP = 420,
	},

	-- ===== SCP-106: prestige, hardest tier =====
	CorrodeTheFoundation = {
		Id = "CorrodeTheFoundation",
		DisplayName = "Corrode The Foundation",
		ClassId = "SCP106",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 6, Description = "Corrode everything in your path." },
		},
		BaseRewardGlint = 260,
		BaseRewardXP = 520,
	},
	VanishAndReturn = {
		Id = "VanishAndReturn",
		DisplayName = "Vanish And Return",
		ClassId = "SCP106",
		Objectives = {
			{ Type = "ReachZone", ZoneTag = "Zone_Armory", Description = "Phase into the armory." },
			{ Type = "ReachZone", ZoneTag = "Zone_SCPContainment", Description = "Phase back to containment." },
		},
		BaseRewardGlint = 240,
		BaseRewardXP = 480,
	},
	TheOldMansHunt = {
		Id = "TheOldMansHunt",
		DisplayName = "The Old Man's Hunt",
		ClassId = "SCP106",
		Objectives = {
			{ Type = "EliminateNPCCount", BaseCount = 9, Description = "There is no corner of the facility you cannot reach." },
		},
		BaseRewardGlint = 300,
		BaseRewardXP = 600,
	},
}

MissionConfig._PoolByClass = {
	DClass = { "SupplyRun", "FileTheReport", "LateShift" },
	ClassC = { "RecoverResearchData", "ContainTheBreach", "InventoryCheck", "NeutralizeIntruders", "SecureTheArmory", "CellBlockPatrol" },
	ClassB = { "RaidTheArmory", "EliminateFoundationPatrol", "FreeThePrisoners", "PurgeHostiles", "RecoverClassifiedIntel", "ContainAndTerminate" },
	ClassA = { "FullFacilitySweep", "CommandOverride", "TotalLockdownResponse" },
	SCP049 = { "HuntTheLiving", "PurgeTheWing", "EndlessPlague" },
	SCP106 = { "CorrodeTheFoundation", "VanishAndReturn", "TheOldMansHunt" },
}

return MissionConfig
