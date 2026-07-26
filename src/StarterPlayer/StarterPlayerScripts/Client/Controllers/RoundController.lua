--!strict
-- Top-center round-state banner: intermission countdown, live round timer,
-- and a big result card when the round ends. Everything here is derived
-- straight from RoundStateChanged payloads - no local prediction.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Enums = require(ReplicatedStorage.Shared.Modules.Enums)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local RoundController = {}

local RESULT_TEXT: { [string]: { text: string, color: Color3 } } = {
	[Enums.RoundEndReason.FoundationVictory] = { text = "FOUNDATION VICTORY", color = Theme.Info },
	[Enums.RoundEndReason.ChaosVictory] = { text = "CHAOS INSURGENCY VICTORY", color = Theme.Danger },
	[Enums.RoundEndReason.SCPVictory] = { text = "CONTAINMENT FAILED - SCP VICTORY", color = Theme.Danger },
	[Enums.RoundEndReason.TimeLimit] = { text = "TIME LIMIT REACHED", color = Theme.Warning },
	[Enums.RoundEndReason.Warhead] = { text = "ALPHA WARHEAD DETONATED", color = Theme.Danger },
	[Enums.RoundEndReason.NotEnoughPlayers] = { text = "NOT ENOUGH PLAYERS", color = Theme.Warning },
}

function RoundController.Init()
	local gui = UIUtil.ScreenGui("RoundUI")
	gui.DisplayOrder = 20

	local banner = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 260, 0, 44),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
	}, {
		UIUtil.Corner(8),
		UIUtil.New("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			TextColor3 = Theme.Text,
			TextSize = 18,
			Text = "Waiting for players...",
		}),
	})
	banner.Parent = gui

	local resultCard = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.new(0, 560, 0, 140),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		Visible = false,
	}, {
		UIUtil.Corner(12),
		UIUtil.Stroke(Theme.Accent, 2),
		UIUtil.New("TextLabel", {
			Name = "ResultLabel",
			Size = UDim2.new(1, -40, 1, -20),
			Position = UDim2.new(0, 20, 0, 10),
			BackgroundTransparency = 1,
			Font = Theme.FontBlack,
			TextColor3 = Theme.Text,
			TextSize = 30,
			TextWrapped = true,
			Text = "",
		}),
	})
	resultCard.Parent = gui

	local label = banner:FindFirstChild("Label") :: TextLabel
	local resultLabel = resultCard:FindFirstChild("ResultLabel") :: TextLabel

	-- The server only broadcasts the round timer once at Active start (and on
	-- each win-condition tick, which isn't timer-related); we count the
	-- remaining seconds down locally between updates rather than re-fetching
	-- every second over the network.
	local activeSecondsLeft: number? = nil

	RunService.Heartbeat:Connect(function(dt: number)
		if activeSecondsLeft == nil then
			return
		end
		activeSecondsLeft = math.max(0, activeSecondsLeft - dt)
		label.Text = `Round time: {UIUtil.FormatClock(activeSecondsLeft)}`
	end)

	Remotes.RoundStateChanged.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.state == Enums.RoundState.Lobby then
			activeSecondsLeft = nil
			banner.Visible = true
			resultCard.Visible = false
			label.Text = "Waiting for players..."
		elseif payload.state == Enums.RoundState.Intermission then
			activeSecondsLeft = nil
			banner.Visible = true
			resultCard.Visible = false
			if payload.reason == Enums.RoundEndReason.NotEnoughPlayers then
				label.Text = "Not enough players - waiting..."
			else
				label.Text = `Next round in {payload.timeLeft or 0}s`
			end
		elseif payload.state == Enums.RoundState.Active then
			banner.Visible = true
			resultCard.Visible = false
			if payload.timeLeft then
				activeSecondsLeft = payload.timeLeft
				label.Text = `Round time: {UIUtil.FormatClock(activeSecondsLeft)}`
			end
		elseif payload.state == Enums.RoundState.Ending then
			activeSecondsLeft = nil
			banner.Visible = false
			local info = RESULT_TEXT[payload.reason] or { text = "ROUND OVER", color = Theme.Text }
			resultLabel.Text = info.text
			resultLabel.TextColor3 = info.color
			resultCard.Visible = true
			resultCard.BackgroundTransparency = 1
			UIUtil.Tween(resultCard, TweenInfo.new(0.3), { BackgroundTransparency = 0.05 })
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return RoundController
