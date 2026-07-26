--!strict
-- Builds Tool instances at runtime from ToolConfig and hands them to players.
-- No tool ever ships as a pre-made binary asset: balance lives in one Lua table
-- (ToolConfig) and every Tool instance is generated from it, so a design change
-- there is instantly live. All per-tool logic (firing, reload, heal, flashlight)
-- lives in CombatService, driven purely by RemoteEvents - Tools carry no scripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)

local InventoryService = {}

local Deps: any = nil

function InventoryService.BuildTool(toolId: string): Tool?
	local def = ToolConfig[toolId]
	if not def then
		warn(`[InventoryService] Unknown toolId "{toolId}"`)
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = def.DisplayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("ToolId", def.Id)
	tool:SetAttribute("Kind", def.Kind)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = def.HandleSize
	handle.Color = def.HandleColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	if def.Kind == "Weapon" then
		tool:SetAttribute("Ammo", def.MagazineSize)
		tool:SetAttribute("Reserve", def.ReserveAmmo)
	end

	if def.Id == "Flashlight" then
		local light = Instance.new("SpotLight")
		light.Name = "Beam"
		light.Brightness = 3
		light.Range = 30
		light.Angle = 45
		light.Enabled = false
		light.Parent = handle
		tool:SetAttribute("On", false)
	end

	return tool
end

function InventoryService.EquipStartingTools(player: Player, toolIds: { string })
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	for _, existing in ipairs(backpack:GetChildren()) do
		if existing:IsA("Tool") then
			existing:Destroy()
		end
	end
	local character = player.Character
	if character then
		for _, existing in ipairs(character:GetChildren()) do
			if existing:IsA("Tool") then
				existing:Destroy()
			end
		end
	end

	for _, toolId in ipairs(toolIds) do
		local tool = InventoryService.BuildTool(toolId)
		if tool then
			tool.Parent = backpack
		end
	end
end

function InventoryService.GetEquippedTool(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool
end

function InventoryService.Init(deps: any)
	Deps = deps
end

return InventoryService
