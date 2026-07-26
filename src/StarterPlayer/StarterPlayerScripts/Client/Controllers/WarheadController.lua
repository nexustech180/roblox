--!strict
-- Big red countdown banner while the Alpha Warhead is armed. Counts down
-- locally between updates like RoundController does for the round timer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local WarheadController = {}

function WarheadController.Init()
	local gui = UIUtil.ScreenGui("WarheadUI")
	gui.DisplayOrder = 25

	local banner = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0, 320, 0, 40),
		BackgroundColor3 = Theme.Danger,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, {
		UIUtil.Corner(6),
		UIUtil.New("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.FontBlack,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 18,
			Text = "WARHEAD ARMED",
		}),
	})
	banner.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = banner:FindFirstChild("Label") :: TextLabel
	local secondsLeft: number? = nil

	RunService.Heartbeat:Connect(function(dt: number)
		if secondsLeft == nil then
			return
		end
		secondsLeft = math.max(0, secondsLeft - dt)
		label.Text = `WARHEAD DETONATION IN {UIUtil.FormatClock(secondsLeft)}`
	end)

	Remotes.WarheadUpdate.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.active then
			secondsLeft = payload.duration or 0
			banner.Visible = true
		else
			secondsLeft = nil
			banner.Visible = false
		end
	end)
end

return WarheadController
