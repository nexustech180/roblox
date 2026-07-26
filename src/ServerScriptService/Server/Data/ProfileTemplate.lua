--!strict
-- Shape of a player's persisted profile. DataService fills in this template for
-- new players and migrates old profiles forward by merging missing keys.

export type Profile = {
	Credits: number,
	XP: number,
	Level: number,
	Kills: number,
	Deaths: number,
	MissionsCompleted: number,
	SCPKills: number, -- kills recorded while playing an SCP prestige class
	Escapes: number, -- flavor stat: "reach the surface"-style objective completions
	CurrentClassId: string, -- persists across sessions so you resume as whatever you last picked
	SchemaVersion: number,
}

local ProfileTemplate: Profile = {
	Credits = 100,
	XP = 0,
	Level = 1,
	Kills = 0,
	Deaths = 0,
	MissionsCompleted = 0,
	SCPKills = 0,
	Escapes = 0,
	CurrentClassId = "DClass",
	SchemaVersion = 2,
}

return ProfileTemplate
