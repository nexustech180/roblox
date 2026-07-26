--!strict
-- Renders server-sent toasts (Remotes.Notify) as stacked, auto-fading cards
-- in the top-right corner. Purely presentational - every decision about
-- *whether* to notify was already made server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local NotifyController = {}

local KIND_COLOR = {
	info = Theme.Info,
	success = Theme.Success,
	warning = Theme.Warning,
	danger = Theme.Danger,
}

local function spawnToast(container: Instance, text: string, kind: string?)
	local color = KIND_COLOR[kind or "info"] or Theme.Info

	local card = UIUtil.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.05,
		LayoutOrder = math.floor(os.clock() * 1000) % 2000000000,
	}, {
		UIUtil.Corner(6),
		UIUtil.New("Frame", {
			Name = "AccentBar",
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { UIUtil.Corner(2) }),
		UIUtil.New("TextLabel", {
			Name = "Text",
			Position = UDim2.new(0, 14, 0, 0),
			Size = UDim2.new(1, -22, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Theme.FontMedium,
			TextColor3 = Theme.Text,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
		}, { UIUtil.Padding(10) }),
	})
	card.Parent = container

	card.BackgroundTransparency = 1
	UIUtil.Tween(card, TweenInfo.new(0.25), { BackgroundTransparency = 0.05 })

	task.delay(4.5, function()
		if card.Parent then
			local tween = UIUtil.Tween(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			tween.Completed:Once(function()
				card:Destroy()
			end)
		end
	end)
end

function NotifyController.Init()
	local gui = UIUtil.ScreenGui("Toasts")
	gui.DisplayOrder = 50

	local container = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 320, 1, -32),
		BackgroundTransparency = 1,
	}, {
		UIUtil.New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	container.Parent = gui

	Remotes.Notify.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.text) == "string" then
			spawnToast(container, payload.text, payload.kind)
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return NotifyController
