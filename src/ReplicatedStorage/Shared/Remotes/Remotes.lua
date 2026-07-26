--!strict
-- Central registry of every RemoteEvent/RemoteFunction. The server creates the
-- instances (first require, at boot, before players can join); the client just
-- waits for them. Both sides require this exact module so nobody hand-rolls a
-- FindFirstChild path and silently no-ops when a name is misspelled.

local RunService = game:GetService("RunService")

local folder = script.Parent :: Folder

local EVENT_NAMES = {
	"ClassAssigned", -- server -> client: { classId, displayName, description, track, isSCP }
	"RequestClassChange", -- client -> server: { classId }
	"MissionAssigned", -- server -> client: { missionId, displayName, objectiveText, objectiveIndex, objectiveCount }
	"MissionProgress", -- server -> client: { missionId, objectiveIndex, objectiveText, complete }
	"WeaponFire", -- client -> server: { toolId, origin, direction }
	"WeaponReload", -- client -> server: { toolId }
	"UseConsumable", -- client -> server: { toolId }
	"ToggleFlashlight", -- client -> server: { toolId, on }
	-- Doors and mission terminals use engine-native ProximityPrompt.Triggered
	-- (fires on the server automatically) instead of a custom remote.
	"SCPAbility", -- client -> server: { ability, ... }
	"SCPAbilityCooldown", -- server -> client: { ability, duration }
	"Notify", -- server -> client: { text, kind }
	"InventoryUpdated", -- server -> client: { equipped, ammo, reserve }
}

local FUNCTION_NAMES = {
	"GetInitialState", -- client -> server request, returns a full snapshot
}

local Remotes = {}

local function getOrCreate(className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end

	if RunService:IsServer() then
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	end

	local waited = folder:WaitForChild(name, 15)
	assert(waited, `Remote "{name}" never appeared - server may not have booted yet`)
	return waited
end

for _, name in ipairs(EVENT_NAMES) do
	Remotes[name] = getOrCreate("RemoteEvent", name)
end

for _, name in ipairs(FUNCTION_NAMES) do
	Remotes[name] = getOrCreate("RemoteFunction", name)
end

return Remotes
