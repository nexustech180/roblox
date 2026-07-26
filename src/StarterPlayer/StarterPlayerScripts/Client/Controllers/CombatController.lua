--!strict
-- Turns raw input into combat remotes. No Tool ever carries a script - this
-- single controller watches whatever Tool is currently equipped on the local
-- character and fires WeaponFire/WeaponReload/UseConsumable/ToggleFlashlight
-- accordingly. The server re-validates everything; this just makes it feel
-- responsive and draws the crosshair/ammo counter.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local CombatController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local equippedTool: Tool? = nil
local lastFireClientTime = 0
local mouseDown = false

local function getToolDef(tool: Tool)
	local toolId = tool:GetAttribute("ToolId")
	return typeof(toolId) == "string" and ToolConfig[toolId] or nil
end

local function fireWeapon()
	local tool = equippedTool
	if not tool then
		return
	end
	local def = getToolDef(tool)
	if not def or def.Kind ~= "Weapon" then
		return
	end

	local now = os.clock()
	if now - lastFireClientTime < (def.FireRate or 0.1) then
		return
	end
	lastFireClientTime = now

	Remotes.WeaponFire:FireServer({
		toolId = def.Id,
		origin = camera.CFrame.Position,
		direction = camera.CFrame.LookVector,
	})
end

local function reloadWeapon()
	local tool = equippedTool
	local def = tool and getToolDef(tool)
	if def and def.Kind == "Weapon" then
		Remotes.WeaponReload:FireServer({ toolId = def.Id })
	end
end

local function useConsumable()
	local tool = equippedTool
	local def = tool and getToolDef(tool)
	if def and def.Kind == "Consumable" then
		Remotes.UseConsumable:FireServer({ toolId = def.Id })
	end
end

local function toggleFlashlight()
	local tool = equippedTool
	local def = tool and getToolDef(tool)
	if def and def.Id == "Flashlight" then
		Remotes.ToggleFlashlight:FireServer({ toolId = def.Id })
	end
end

local function buildCrosshairAndAmmo()
	local gui = UIUtil.ScreenGui("CombatUI")
	gui.DisplayOrder = 12

	local crosshair = UIUtil.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 6, 0, 6),
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, { UIUtil.Corner(3) })
	crosshair.Parent = gui

	local ammoLabel = UIUtil.New("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -24),
		Size = UDim2.new(0, 160, 0, 28),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextColor3 = Theme.Text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Text = "",
	})
	ammoLabel.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return crosshair, ammoLabel :: TextLabel
end

function CombatController.Init()
	local crosshair, ammoLabel = buildCrosshairAndAmmo()

	local function refreshEquipped()
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		equippedTool = tool

		local def = tool and getToolDef(tool)
		if def and def.Kind == "Weapon" then
			crosshair.Visible = true
			ammoLabel.Visible = true
			ammoLabel.Text = `{tool:GetAttribute("Ammo") or 0} / {tool:GetAttribute("Reserve") or 0}`
		else
			crosshair.Visible = false
			ammoLabel.Visible = false
		end
	end

	local function onCharacterAdded(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(refreshEquipped)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(refreshEquipped)
			end
		end)
		refreshEquipped()
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	Remotes.InventoryUpdated.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and equippedTool and equippedTool:GetAttribute("ToolId") == payload.equipped then
			ammoLabel.Text = `{payload.ammo or 0} / {payload.reserve or 0}`
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = true
			fireWeapon()
		elseif input.KeyCode == Enum.KeyCode.R then
			reloadWeapon()
		elseif input.KeyCode == Enum.KeyCode.H then
			useConsumable()
		elseif input.KeyCode == Enum.KeyCode.F then
			toggleFlashlight()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = false
		end
	end)

	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function()
		if mouseDown then
			local tool = equippedTool
			local def = tool and getToolDef(tool)
			-- Automatic weapons keep firing on held mouse; single-use tools don't care since fireWeapon no-ops for them.
			if def and def.Kind == "Weapon" then
				fireWeapon()
			end
		end
	end)
end

return CombatController
