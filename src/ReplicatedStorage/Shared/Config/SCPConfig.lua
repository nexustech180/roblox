--!strict
-- Ability tuning for the two prestige SCP classes. Consumed exclusively by
-- SCPAbilityService (server-authoritative); the client only ever reads this
-- to draw cooldown UI, never to decide outcomes.
--
-- SCP-173 and SCP-096 aren't here: both of their signature mechanics
-- (freezing when observed, enraging when its face is seen) only make sense
-- with another human in the room to do the observing. In a solo game there's
-- nobody to fill that role, so they're cut rather than shipped as a
-- confusing no-op class. SCP-049 and SCP-106 both work solo since their kit
-- is "hunt down hostiles with unique abilities," same as any other class.

export type SCP049Config = {
	TouchOfDeathRange: number,
	TouchOfDeathCooldown: number,
	TouchOfDeathDamage: number,
	ReanimateRange: number,
	ReanimateWindowSeconds: number, -- how long after death a corpse can still be reanimated
	ZombieWalkSpeed: number,
	ZombieMaxHealth: number,
	ZombieBiteDamage: number,
	ZombieBiteCooldown: number,
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
