--!strict
-- Ability hotbar for the two SCPs with player-triggered abilities (049 and
-- 106). SCP-173's freeze/lunge and SCP-096's enrage are fully passive and
-- server-driven, so they need no client input at all - just movement.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local SCPAbilityController = {}

type AbilityBinding = { key: Enum.KeyCode, ability: string, label: string }

local CLASS_ABILITIES: { [string]: { AbilityBinding } } = {
	SCP049 = {
		{ key = Enum.KeyCode.E, ability = "TouchOfDeath", label = "[E] Touch of Death" },
		{ key = Enum.KeyCode.R, ability = "Reanimate", label = "[R] Reanimate" },
	},
	SCP106 = {
		{ key = Enum.KeyCode.E, ability = "Phase", label = "[E] Phase Through Matter" },
		{ key = Enum.KeyCode.R, ability = "PocketDimension", label = "[R] Pocket Dimension" },
	},
}

function SCPAbilityController.Init()
	local currentClassId: string? = nil

	local gui = UIUtil.ScreenGui("SCPAbilityUI")
	gui.DisplayOrder = 14

	local container = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -64),
		Size = UDim2.new(0, 260, 0, 70),
		BackgroundTransparency = 1,
		Visible = false,
	}, {
		UIUtil.New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	container.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local abilityRows: { [string]: Frame } = {}

	local function buildRows(bindings: { AbilityBinding })
		container:ClearAllChildren()
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.Parent = container

		table.clear(abilityRows)

		for _, binding in ipairs(bindings) do
			local row = UIUtil.New("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = Theme.Panel,
				BackgroundTransparency = 0.15,
			}, {
				UIUtil.Corner(6),
				UIUtil.New("TextLabel", {
					Name = "Label",
					Size = UDim2.new(1, -12, 1, 0),
					Position = UDim2.new(0, 8, 0, 0),
					BackgroundTransparency = 1,
					Font = Theme.FontMedium,
					TextColor3 = Theme.Text,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = binding.label,
				}),
			})
			row.Parent = container
			abilityRows[binding.ability] = row
		end
	end

	Remotes.ClassAssigned.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		currentClassId = payload.classId
		local bindings = currentClassId and CLASS_ABILITIES[currentClassId]
		if bindings then
			buildRows(bindings)
			container.Visible = true
		else
			container.Visible = false
		end
	end)

	Remotes.SCPAbilityCooldown.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		local row = abilityRows[payload.ability]
		if not row then
			return
		end
		local label = row:FindFirstChild("Label") :: TextLabel
		local originalText = label.Text
		local duration = payload.duration or 1

		local endTime = os.clock() + duration
		task.spawn(function()
			while os.clock() < endTime and row.Parent do
				label.Text = `{originalText} ({math.ceil(endTime - os.clock())}s)`
				task.wait(0.2)
			end
			if row.Parent then
				label.Text = originalText
			end
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not currentClassId then
			return
		end
		local bindings = CLASS_ABILITIES[currentClassId]
		if not bindings then
			return
		end
		for _, binding in ipairs(bindings) do
			if input.KeyCode == binding.key then
				Remotes.SCPAbility:FireServer({ ability = binding.ability })
				break
			end
		end
	end)
end

return SCPAbilityController
