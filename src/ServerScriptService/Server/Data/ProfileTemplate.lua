--!strict
-- Shape of a player's persisted profile. DataService fills in this template for
-- new players and migrates old profiles forward by merging missing keys.

export type Profile = {
	Glint: number, -- everyday currency: buying Helper SCPs, gear
	AethericDucats: number, -- rare currency: Cybernetics upgrades only
	XP: number,
	Level: number,
	Kills: number,
	Deaths: number,
	MissionsCompleted: number,
	SCPKills: number, -- kills recorded while playing a Helper SCP
	Escapes: number, -- flavor stat: "reach the surface"-style objective completions
	CurrentClassId: string, -- persists across sessions so you resume as whatever you last picked
	OwnedSCPIds: { string }, -- Helper SCPs bought at the Lab or stolen via PvP
	UpgradedSCPIds: { string }, -- which owned SCPs have had Cybernetics applied
	SchemaVersion: number,
}

local ProfileTemplate: Profile = {
	Glint = 100,
	AethericDucats = 0,
	XP = 0,
	Level = 1,
	Kills = 0,
	Deaths = 0,
	MissionsCompleted = 0,
	SCPKills = 0,
	Escapes = 0,
	CurrentClassId = "DClass",
	OwnedSCPIds = {},
	UpgradedSCPIds = {},
	SchemaVersion = 3,
}

return ProfileTemplate
