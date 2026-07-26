--!strict
-- Press C to open the class menu: every class you've unlocked (profile
-- Level >= ClassConfig.UnlockLevel) is selectable, locked ones show the
-- level you still need. This is the only way to change class - there's no
-- automatic reassignment anymore, you pick your own progression path.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local ClassMenuController = {}

function ClassMenuController.Init()
	local player = Players.LocalPlayer
	local currentClassId: string? = nil

	local gui = UIUtil.ScreenGui("ClassMenu")
	gui.DisplayOrder = 40

	local panel = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 420, 0, 460),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, {
		UIUtil.Corner(12),
		UIUtil.Stroke(Theme.Accent, 1),
		UIUtil.New("TextLabel", {
			Name = "Title",
			Position = UDim2.new(0, 16, 0, 12),
			Size = UDim2.new(1, -32, 0, 30),
			BackgroundTransparency = 1,
			Font = Theme.FontBlack,
			TextColor3 = Theme.Text,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Career Path",
		}),
		UIUtil.New("TextLabel", {
			Name = "Hint",
			Position = UDim2.new(0, 16, 0, 42),
			Size = UDim2.new(1, -32, 0, 20),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextColor3 = Theme.SubText,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Press C to close",
		}),
		UIUtil.New("ScrollingFrame", {
			Name = "List",
			Position = UDim2.new(0, 12, 0, 70),
			Size = UDim2.new(1, -24, 1, -82),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, {
			UIUtil.New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}),
	})
	panel.Parent = gui

	local list = panel:FindFirstChild("List") :: ScrollingFrame
	local rows: { [string]: Frame } = {}

	local function buildRows()
		for _, classId in ipairs(ClassConfig._UnlockOrder) do
			local def = ClassConfig[classId]
			local row = UIUtil.New("Frame", {
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Panel,
				BackgroundTransparency = 0.1,
			}, {
				UIUtil.Corner(8),
				UIUtil.New("TextLabel", {
					Name = "Name",
					Position = UDim2.new(0, 12, 0, 6),
					Size = UDim2.new(1, -100, 0, 22),
					BackgroundTransparency = 1,
					Font = Theme.FontBold,
					TextColor3 = Theme.Text,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = def.DisplayName,
				}),
				UIUtil.New("TextLabel", {
					Name = "Requirement",
					Position = UDim2.new(0, 12, 0, 28),
					Size = UDim2.new(1, -100, 0, 20),
					BackgroundTransparency = 1,
					Font = Theme.Font,
					TextColor3 = Theme.SubText,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = `Requires level {def.UnlockLevel}`,
				}),
				UIUtil.New("TextButton", {
					Name = "SelectButton",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0, 80, 0, 34),
					BackgroundColor3 = Theme.Accent,
					Font = Theme.FontBold,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 14,
					Text = "Select",
				}, { UIUtil.Corner(6) }),
			})
			row.Parent = list
			rows[classId] = row

			local button = row:FindFirstChild("SelectButton") :: TextButton
			button.Activated:Connect(function()
				if button.Text == "Select" then
					Remotes.RequestClassChange:FireServer({ classId = classId })
				end
			end)
		end
	end

	local function refreshLocks()
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level") :: IntValue?
		local level = levelValue and levelValue.Value or 1

		for classId, row in pairs(rows) do
			local def = ClassConfig[classId]
			local unlocked = level >= def.UnlockLevel
			local isCurrent = classId == currentClassId

			local button = row:FindFirstChild("SelectButton") :: TextButton
			local requirement = row:FindFirstChild("Requirement") :: TextLabel

			if isCurrent then
				button.Text = "Current"
				button.BackgroundColor3 = Theme.Success
				button.AutoButtonColor = false
			elseif unlocked then
				button.Text = "Select"
				button.BackgroundColor3 = Theme.Accent
				button.AutoButtonColor = true
			else
				button.Text = "Locked"
				button.BackgroundColor3 = Theme.PanelLight
				button.AutoButtonColor = false
			end

			requirement.Text = unlocked and "Unlocked" or `Requires level {def.UnlockLevel} (you are {level})`
			requirement.TextColor3 = unlocked and Theme.Success or Theme.SubText
		end
	end

	buildRows()

	local leaderstats = player:WaitForChild("leaderstats", 10)
	local levelValue = leaderstats and leaderstats:WaitForChild("Level", 10) :: IntValue?
	if levelValue then
		levelValue:GetPropertyChangedSignal("Value"):Connect(refreshLocks)
	end
	refreshLocks()

	Remotes.ClassAssigned.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" then
			currentClassId = payload.classId
			refreshLocks()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			panel.Visible = not panel.Visible
			if panel.Visible then
				refreshLocks()
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return ClassMenuController
