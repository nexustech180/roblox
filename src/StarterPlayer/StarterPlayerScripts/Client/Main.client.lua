--!strict
-- Client bootstrap: requires every controller and initializes it. Controllers
-- are independent of each other (each owns its own ScreenGui) so order here
-- doesn't matter beyond "all of them eventually run".

local Controllers = script.Parent.Controllers

local CONTROLLER_NAMES = {
	"NotifyController",
	"ClassCardController",
	"ClassMenuController",
	"MissionController",
	"HUDController",
	"CombatController",
	"SCPAbilityController",
}

for _, name in ipairs(CONTROLLER_NAMES) do
	local controller = require(Controllers:WaitForChild(name))
	local ok, err = pcall(controller.Init)
	if not ok then
		warn(`[Client] Controller "{name}" failed to init: {err}`)
	end
end
