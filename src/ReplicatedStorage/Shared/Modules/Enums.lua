--!strict
-- String-constant "enums" shared by server and client so nobody typos a magic string.

local Enums = {}

Enums.RoundState = {
	Lobby = "Lobby",
	Intermission = "Intermission",
	Active = "Active",
	Ending = "Ending",
}

Enums.Faction = {
	DClass = "DClass",
	Foundation = "Foundation",
	ChaosInsurgency = "ChaosInsurgency",
	SCP = "SCP",
	Spectator = "Spectator",
}

Enums.RoundEndReason = {
	FoundationVictory = "FoundationVictory",
	ChaosVictory = "ChaosVictory",
	SCPVictory = "SCPVictory",
	TimeLimit = "TimeLimit",
	NotEnoughPlayers = "NotEnoughPlayers",
	Warhead = "Warhead",
}

return Enums
