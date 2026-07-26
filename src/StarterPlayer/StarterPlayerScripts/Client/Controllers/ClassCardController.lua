--!strict
-- Full-screen "You are now: <class>" card shown whenever the server (re-)
-- spawns you as a class - first join, respawn after death, or a class change
-- you picked from the class menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local ClassCardController = {}

local TRACK_COLOR = {
	DClass = Color3.fromRGB(196, 160, 84),
	Foundation = Color3.fromRGB(90, 160, 230),
	Renegade = Color3.fromRGB(200, 60, 60),
	SCP = Color3.fromRGB(180, 180, 190),
}

function ClassCardController.Init()
	local gui = UIUtil.ScreenGui("ClassCard")
	gui.DisplayOrder = 30

	local card = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 520, 0, 200),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		Visible = false,
	}, {
		UIUtil.Corner(14),
		UIUtil.New("Frame", {
			Name = "AccentBar",
			Size = UDim2.new(1, 0, 0, 6),
			BorderSizePixel = 0,
		}, { UIUtil.Corner(3) }),
		UIUtil.New("TextLabel", {
			Name = "TrackLabel",
			Position = UDim2.new(0, 24, 0, 20),
			Size = UDim2.new(1, -48, 0, 20),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			TextColor3 = Theme.SubText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "TRACK",
		}),
		UIUtil.New("TextLabel", {
			Name = "NameLabel",
			Position = UDim2.new(0, 24, 0, 44),
			Size = UDim2.new(1, -48, 0, 44),
			BackgroundTransparency = 1,
			Font = Theme.FontBlack,
			TextColor3 = Theme.Text,
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Class Name",
		}),
		UIUtil.New("TextLabel", {
			Name = "DescLabel",
			Position = UDim2.new(0, 24, 0, 96),
			Size = UDim2.new(1, -48, 1, -116),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextColor3 = Theme.SubText,
			TextSize = 16,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Description",
		}),
	})
	card.Parent = gui

	local accentBar = card:FindFirstChild("AccentBar") :: Frame
	local trackLabel = card:FindFirstChild("TrackLabel") :: TextLabel
	local nameLabel = card:FindFirstChild("NameLabel") :: TextLabel
	local descLabel = card:FindFirstChild("DescLabel") :: TextLabel

	local hideToken = 0

	Remotes.ClassAssigned.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		local color = TRACK_COLOR[payload.track] or Theme.Accent
		accentBar.BackgroundColor3 = color
		trackLabel.Text = string.upper(tostring(payload.track or ""))
		trackLabel.TextColor3 = color
		nameLabel.Text = tostring(payload.displayName or "")
		descLabel.Text = tostring(payload.description or "")

		card.Visible = true
		card.BackgroundTransparency = 1
		UIUtil.Tween(card, TweenInfo.new(0.3), { BackgroundTransparency = 0.08 })

		hideToken += 1
		local myToken = hideToken
		task.delay(6, function()
			if hideToken == myToken and card.Visible then
				local tween = UIUtil.Tween(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
				tween.Completed:Once(function()
					if hideToken == myToken then
						card.Visible = false
					end
				end)
			end
		end)
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return ClassCardController
