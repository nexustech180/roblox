--!strict
-- Minimal chat-command admin panel for testing/moderation. The game itself
-- never needs these (spawning, missions, and leveling all run automatically -
-- see SessionService) - they exist purely so a developer can jump straight to
-- a given level/class to test progression without grinding for real.

local Players = game:GetService("Players")

-- Add trusted UserIds here before shipping. The place owner (Studio test /
-- solo-published games) is always trusted so testing never locks you out.
local ADMIN_USER_IDS: { number } = {}

local AdminCommands = {}

local Deps: any = nil

local function isAdmin(player: Player): boolean
	if table.find(ADMIN_USER_IDS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return false
end

local function findPlayerByName(partialName: string): Player?
	local lower = string.lower(partialName)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == lower then
			return player
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(player.Name), lower, 1, true) then
			return player
		end
	end
	return nil
end

local COMMANDS: { [string]: (caller: Player, args: { string }) -> () } = {
	-- Bypasses the level gate entirely (unlike the in-game class menu) so you
	-- can test any class's kit immediately. Persists like a normal pick.
	setclass = function(caller, args)
		local target = args[1] and findPlayerByName(args[1])
		local classId = args[2]
		if not target or not classId then
			Deps.NotifyService.Toast(caller, "Usage: /setclass <player> <classId>", "warning")
			return
		end
		Deps.DataService.SetCurrentClass(target, classId)
		Deps.ClassService.SpawnCharacterForClass(target, classId)
		Deps.MissionService.OnClassChanged(target, classId)
		Deps.NotifyService.Toast(caller, `Set {target.Name} to {classId}.`, "success")
	end,

	credits = function(caller, args)
		local target = args[1] and findPlayerByName(args[1])
		local amount = args[2] and tonumber(args[2])
		if not target or not amount then
			Deps.NotifyService.Toast(caller, "Usage: /credits <player> <amount>", "warning")
			return
		end
		Deps.DataService.AddCredits(target, amount)
		Deps.NotifyService.Toast(caller, `Gave {target.Name} {amount} credits.`, "success")
	end,

	addxp = function(caller, args)
		local target = args[1] and findPlayerByName(args[1])
		local amount = args[2] and tonumber(args[2])
		if not target or not amount then
			Deps.NotifyService.Toast(caller, "Usage: /addxp <player> <amount>", "warning")
			return
		end
		Deps.DataService.AddXP(target, amount)
		local profile = Deps.DataService.GetProfile(target)
		Deps.NotifyService.Toast(caller, `Gave {target.Name} {amount} XP (now level {profile and profile.Level or "?"}).`, "success")
	end,
}

local function onChatted(player: Player, message: string)
	if not string.match(message, "^/%a") then
		return
	end
	if not isAdmin(player) then
		return
	end

	local parts = string.split(message, " ")
	local commandName = string.sub(parts[1], 2)
	local args = table.move(parts, 2, #parts, 1, {})

	local handler = COMMANDS[string.lower(commandName)]
	if handler then
		local ok, err = pcall(handler, player, args)
		if not ok then
			Deps.LoggingService.Warn(`[AdminCommands] "{message}" from {player.Name} failed: {err}`)
		end
	end
end

function AdminCommands.Init(deps: any)
	Deps = deps
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end)
end

return AdminCommands
