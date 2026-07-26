--!strict
-- Bottom-center health bar. Reads the local character's Humanoid directly -
-- health is already server-authoritative and replicated, no remote needed.

local Players = game:GetService("Players")
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local HUDController = {}

function HUDController.Init()
	local player = Players.LocalPlayer
	local gui = UIUtil.ScreenGui("HUD")
	gui.DisplayOrder = 10

	local barBack = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 280, 0, 22),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
	}, {
		UIUtil.Corner(6),
		UIUtil.New("Frame", {
			Name = "Fill",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Theme.Success,
			BorderSizePixel = 0,
		}, { UIUtil.Corner(6) }),
		UIUtil.New("TextLabel", {
			Name = "Label",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			TextColor3 = Theme.Text,
			TextSize = 14,
			Text = "100 / 100",
		}),
	})
	barBack.Parent = gui

	local fill = barBack:FindFirstChild("Fill") :: Frame
	local label = barBack:FindFirstChild("Label") :: TextLabel

	local function colorForRatio(ratio: number): Color3
		if ratio > 0.5 then
			return Theme.Success
		elseif ratio > 0.25 then
			return Theme.Warning
		end
		return Theme.Danger
	end

	local function bindHumanoid(humanoid: Humanoid)
		local function refresh()
			local ratio = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
			fill.Size = UDim2.new(ratio, 0, 1, 0)
			fill.BackgroundColor3 = colorForRatio(ratio)
			label.Text = `{math.max(0, math.floor(humanoid.Health))} / {math.floor(humanoid.MaxHealth)}`
		end
		humanoid.HealthChanged:Connect(refresh)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
		refresh()
	end

	local function onCharacterAdded(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			bindHumanoid(humanoid)
		end
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HUDController
