--!strict
-- Core tunables for the solo progression loop. Central place so designers
-- never touch service code.

export type GameConfig = {
	RespawnDelaySeconds: number,
	CorpseLifetimeSeconds: number,
	DeathCreditPenalty: number,

	-- XP curve: xpRequiredForLevel(level) = XPCurveBase * level ^ XPCurveExponent.
	-- Exponent > 1 makes each level cost more than the last (Blox-Fruits-style
	-- grind that gets steeper the higher you go), not a flat per-level cost.
	XPCurveBase: number,
	XPCurveExponent: number,

	-- Mission difficulty scaling: every DifficultyLevelStep levels, objective
	-- counts/durations/NPC health scale up by DifficultyScalePerStep.
	DifficultyLevelStep: number,
	DifficultyScalePerStep: number,

	NPCBaseHealth: number,
	NPCBaseDamage: number,
	NPCBaseWalkSpeed: number,
}

local GameConfig: GameConfig = {
	RespawnDelaySeconds = 4,
	CorpseLifetimeSeconds = 30,
	DeathCreditPenalty = 25,

	XPCurveBase = 80,
	XPCurveExponent = 1.4,

	DifficultyLevelStep = 25,
	DifficultyScalePerStep = 0.12,

	NPCBaseHealth = 100,
	NPCBaseDamage = 12,
	NPCBaseWalkSpeed = 14,
}

return GameConfig
