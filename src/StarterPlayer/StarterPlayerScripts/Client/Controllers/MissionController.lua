--!strict
-- Persistent top-left mission tracker: current mission name, active
-- objective text, and a completion flash. Driven entirely by MissionAssigned
-- / MissionProgress events for this player's squad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local MissionController = {}

function MissionController.Init()
	local gui = UIUtil.ScreenGui("MissionUI")
	gui.DisplayOrder = 15

	local panel = UIUtil.New("Frame", {
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 340, 0, 84),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, {
		UIUtil.Corner(8),
		UIUtil.New("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
		}, { UIUtil.Corner(2) }),
		UIUtil.New("TextLabel", {
			Name = "MissionName",
			Position = UDim2.new(0, 16, 0, 10),
			Size = UDim2.new(1, -28, 0, 22),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			TextColor3 = Theme.Text,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "No mission assigned",
		}),
		UIUtil.New("TextLabel", {
			Name = "ObjectiveText",
			Position = UDim2.new(0, 16, 0, 34),
			Size = UDim2.new(1, -28, 0, 36),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextColor3 = Theme.SubText,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = "",
		}),
	})
	panel.Parent = gui

	local missionName = panel:FindFirstChild("MissionName") :: TextLabel
	local objectiveText = panel:FindFirstChild("ObjectiveText") :: TextLabel

	Remotes.MissionAssigned.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		panel.Visible = true
		missionName.Text = `MISSION: {payload.displayName}`
		objectiveText.Text = `[{payload.objectiveIndex}/{payload.objectiveCount}] {payload.objectiveText or ""}`
	end)

	Remotes.MissionProgress.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.complete then
			missionName.Text = "MISSION COMPLETE"
			objectiveText.Text = "Standby for your next assignment..."
			missionName.TextColor3 = Theme.Success
			task.delay(3, function()
				missionName.TextColor3 = Theme.Text
			end)
		elseif payload.objectiveText then
			objectiveText.Text = `Objective updated: {payload.objectiveText}`
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return MissionController
