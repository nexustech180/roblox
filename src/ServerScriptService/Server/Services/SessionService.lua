--!strict
-- Solo session bootstrap. The moment a player's profile loads, spawn them as
-- whatever class they last used (Class-D on a brand new profile) and start
-- the mission board for that class. No lobby, no round timer, no other
-- players required - this is a solo progression game, always "on".

local Players = game:GetService("Players")

local SessionService = {}

local Deps: any = nil

local function beginSession(player: Player, profile: any)
	local classId = profile.CurrentClassId or "DClass"
	Deps.ClassService.SpawnCharacterForClass(player, classId)
	Deps.MissionService.StartForPlayer(player, classId)
end

function SessionService.Init(deps: any)
	Deps = deps

	Deps.DataService.ProfileLoaded:Connect(beginSession)

	-- Defensive: catch anyone whose profile finished loading before this
	-- service's Init ran and subscribed (shouldn't normally happen given
	-- DataStore calls yield, but costs nothing to guard against).
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Deps.DataService.GetProfile(player)
		if profile and not Deps.ClassService.GetPlayerClass(player) then
			beginSession(player, profile)
		end
	end
end

return SessionService
