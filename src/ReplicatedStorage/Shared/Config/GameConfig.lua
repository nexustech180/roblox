--!strict
-- Core tunables for the progression loop. Central place so designers
-- never touch service code.

export type GameConfig = {
	RespawnDelaySeconds: number,
	CorpseLifetimeSeconds: number,
	DeathGlintPenalty: number,

	-- XP curve: xpRequiredForLevel(level) = XPCurveBase * level ^ XPCurveExponent.
	-- Exponent > 1 makes each level cost more than the last (Blox-Fruits-style
	-- grind that gets steeper the higher you go), not a flat per-level cost.
	-- Tuned so cumulative XP at the clearance breakpoints (700/1500/2450) lands
	-- around 230K/1.1M/3.0M - a real grind, not the ~4.5 BILLION the naive
	-- base=80/exponent=1.4 pairing produced at this level cap.
	XPCurveBase: number,
	XPCurveExponent: number,

	-- Mission difficulty scaling: every DifficultyLevelStep levels, objective
	-- counts/durations/NPC health/rewards scale up by DifficultyScalePerStep.
	DifficultyLevelStep: number,
	DifficultyScalePerStep: number,

	NPCBaseHealth: number,
	NPCBaseDamage: number,
	NPCBaseWalkSpeed: number,
}

local GameConfig: GameConfig = {
	RespawnDelaySeconds = 4,
	CorpseLifetimeSeconds = 30,
	DeathGlintPenalty = 25,

	XPCurveBase = 0.7,
	XPCurveExponent = 1.05,

	DifficultyLevelStep = 25,
	DifficultyScalePerStep = 0.12,

	NPCBaseHealth = 100,
	NPCBaseDamage = 12,
	NPCBaseWalkSpeed = 14,
}

return GameConfig
