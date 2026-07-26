--!strict
-- Core tunables for the round/game loop. Central place so designers never touch service code.

export type GameConfig = {
	MinPlayersToStart: number,
	IntermissionSeconds: number,
	RoundLengthSeconds: number,
	RoundEndDisplaySeconds: number,
	WarheadFuseSeconds: number,
	ContainmentBreachChancePerMinute: number,
	SquadSize: number,
	SpectatorWalkSpeed: number,
	ChaosSpawnDelaySeconds: number,
	MTFReinforceDelaySeconds: number,
	CorpseLifetimeSeconds: number,
	ReinforcementWaveIntervalSeconds: number,
}

local GameConfig: GameConfig = {
	-- 1 so a lone developer can playtest end-to-end (round start, class spawn,
	-- missions) without needing extra test accounts. Raise this for a live
	-- server where you actually want multiple humans before a round begins.
	MinPlayersToStart = 1,
	IntermissionSeconds = 30,
	RoundLengthSeconds = 60 * 15,
	RoundEndDisplaySeconds = 12,
	WarheadFuseSeconds = 90,

	-- Rolled once per minute during an active round; on success a random contained SCP breaches.
	ContainmentBreachChancePerMinute = 0.12,

	SquadSize = 4,
	SpectatorWalkSpeed = 24,

	-- Chaos Insurgency and MTF are "wave" factions that do not exist at t=0.
	ChaosSpawnDelaySeconds = 60 * 3,
	MTFReinforceDelaySeconds = 60 * 5,

	CorpseLifetimeSeconds = 30,
	ReinforcementWaveIntervalSeconds = 45,
}

return GameConfig
