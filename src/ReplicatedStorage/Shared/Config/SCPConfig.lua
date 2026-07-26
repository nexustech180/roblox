--!strict
-- Ability tuning for each SCP. Consumed exclusively by SCPAbilityService (server-authoritative);
-- the client only ever reads this to draw cooldown UI, never to decide outcomes.

export type SCP173Config = {
	LungeRange: number,
	LungeDamage: number,
	ObserverConeDegrees: number,
	ObserverMaxDistance: number,
	MoveSpeedWhenUnobserved: number,
	NeckSnapCooldown: number,
}

export type SCP049Config = {
	TouchOfDeathRange: number,
	TouchOfDeathCooldown: number,
	TouchOfDeathDamage: number,
	ReanimateRange: number,
	ReanimateWindowSeconds: number, -- how long after death the corpse can still be reanimated
	ZombieWalkSpeed: number,
	ZombieMaxHealth: number,
	ZombieBiteDamage: number,
	ZombieBiteCooldown: number,
}

export type SCP096Config = {
	ViewConeDegrees: number,
	ViewMaxDistance: number,
	CalmToEnrageDelaySeconds: number,
	EnrageWalkSpeed: number,
	EnrageDurationSeconds: number,
	SwipeDamage: number,
	SwipeRange: number,
	SwipeCooldown: number,
	PostEnrageCryDurationSeconds: number,
}

export type SCP106Config = {
	CorrodeDamagePerTick: number,
	CorrodeTickSeconds: number,
	PhaseCooldown: number,
	PhaseDurationSeconds: number,
	PhaseSpeedMultiplier: number,
	PocketDimensionDuration: number,
	PocketDimensionDamagePerTick: number,
}

local SCPConfig = {
	SCP173 = {
		LungeRange = 8,
		LungeDamage = 9999, -- instant kill on unobstructed contact, matches SL canon
		ObserverConeDegrees = 100,
		ObserverMaxDistance = 90,
		MoveSpeedWhenUnobserved = 40,
		NeckSnapCooldown = 0.5,
	} :: SCP173Config,

	SCP049 = {
		TouchOfDeathRange = 6,
		TouchOfDeathCooldown = 3,
		TouchOfDeathDamage = 9999,
		ReanimateRange = 7,
		ReanimateWindowSeconds = 25,
		ZombieWalkSpeed = 14,
		ZombieMaxHealth = 150,
		ZombieBiteDamage = 35,
		ZombieBiteCooldown = 1.5,
	} :: SCP049Config,

	SCP096 = {
		ViewConeDegrees = 60,
		ViewMaxDistance = 60,
		CalmToEnrageDelaySeconds = 2.5,
		EnrageWalkSpeed = 42,
		EnrageDurationSeconds = 20,
		SwipeDamage = 85,
		SwipeRange = 7,
		SwipeCooldown = 0.8,
		PostEnrageCryDurationSeconds = 4,
	} :: SCP096Config,

	SCP106 = {
		CorrodeDamagePerTick = 6,
		CorrodeTickSeconds = 1,
		PhaseCooldown = 12,
		PhaseDurationSeconds = 6,
		PhaseSpeedMultiplier = 1.6,
		PocketDimensionDuration = 8,
		PocketDimensionDamagePerTick = 10,
	} :: SCP106Config,
}

return SCPConfig
