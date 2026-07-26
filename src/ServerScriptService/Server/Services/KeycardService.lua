--!strict
-- Keycard levels are derived from a player's class (see ClassConfig.KeycardLevel)
-- rather than being a separate inventory item - matches SCP:SL's model where your
-- role *is* your clearance. DoorService is the only consumer of this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local KeycardService = {}

local Deps: any = nil

function KeycardService.GetKeycardLevel(player: Player): number
	local classId = Deps.ClassService.GetPlayerClass(player)
	if not classId then
		return 0
	end
	local def = ClassConfig[classId]
	return def and def.KeycardLevel or 0
end

function KeycardService.HasAccess(player: Player, requiredLevel: number): boolean
	return KeycardService.GetKeycardLevel(player) >= requiredLevel
end

function KeycardService.Init(deps: any)
	Deps = deps
end

return KeycardService
