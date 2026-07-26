--!strict
-- Generates a minimal, ugly-but-functional placeholder facility at server
-- boot: one spawn pad per class and the mission zones/terminals
-- MissionConfig references. This means the whole game (classes, missions,
-- combat, SCP abilities, leveling) is testable the moment you hit Play, with
-- zero manual map setup. Replace this with a real Studio-built map by
-- tagging your own geometry with the same CollectionService tags and
-- deleting this script's call in Main.server.lua - every other service only
-- ever looks at tags, never at this generated geometry directly.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.ClassConfig)

local MapScaffold = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	return part
end

local function makeZone(name: string, tag: string, position: Vector3, color: Color3): Part
	local zone = makePart({
		Name = name,
		Size = Vector3.new(30, 1, 30),
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	CollectionService:AddTag(zone, tag)
	return zone
end

local function makeTerminal(name: string, tag: string, position: Vector3): Part
	local terminal = makePart({
		Name = name,
		Size = Vector3.new(2, 3, 1),
		Position = position,
		Color = Color3.fromRGB(40, 200, 220),
		Material = Enum.Material.Neon,
	})
	terminal:SetAttribute("TerminalName", name)
	CollectionService:AddTag(terminal, tag)
	return terminal
end

local function makeDoor(name: string, position: Vector3, requiredLevel: number, group: string?): Part
	local door = makePart({
		Name = name,
		Size = Vector3.new(6, 8, 1),
		Position = position,
		Color = Color3.fromRGB(90, 90, 100),
		Material = Enum.Material.Metal,
		CanCollide = true,
	})
	door:SetAttribute("RequiredLevel", requiredLevel)
	door:SetAttribute("DoorName", name)
	if group then
		door:SetAttribute("Group", group)
	end
	CollectionService:AddTag(door, "FoundationDoor")
	return door
end

function MapScaffold.Build()
	local existing = Workspace:FindFirstChild("GeneratedFacility")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "GeneratedFacility"
	root.Parent = Workspace

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(400, 2, 400),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Concrete,
	})
	floor.Parent = root

	-- One spawn pad per class, laid out in a grid, driven entirely by
	-- ClassConfig so a new class automatically gets a spawn point.
	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "Spawns"
	spawnsFolder.Parent = root

	local classIds = {}
	for classId, def in pairs(ClassConfig) do
		if typeof(def) == "table" and def.SpawnTag then
			table.insert(classIds, classId)
		end
	end
	table.sort(classIds)

	local columns = 5
	for index, classId in ipairs(classIds) do
		local def = ClassConfig[classId]
		local col = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local position = Vector3.new(-160 + col * 40, 1, -120 + row * 40)

		local pad = makePart({
			Name = "Spawn_" .. classId,
			Size = Vector3.new(6, 1, 6),
			Position = position,
			Color = def.TeamColor,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
		})
		CollectionService:AddTag(pad, def.SpawnTag)
		pad.Parent = spawnsFolder
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root
	makeZone("Zone_Surface", "Zone_Surface", Vector3.new(180, 1, 0), Color3.fromRGB(80, 220, 120)).Parent = zonesFolder
	makeZone("Zone_DClassCells", "Zone_DClassCells", Vector3.new(-180, 1, 0), Color3.fromRGB(196, 160, 84)).Parent =
		zonesFolder
	makeZone("Zone_Armory", "Zone_Armory", Vector3.new(0, 1, 180), Color3.fromRGB(80, 140, 220)).Parent = zonesFolder
	makeZone("Zone_SCPContainment", "Zone_SCPContainment", Vector3.new(0, 1, -180), Color3.fromRGB(220, 60, 60)).Parent =
		zonesFolder

	local terminalsFolder = Instance.new("Folder")
	terminalsFolder.Name = "Terminals"
	terminalsFolder.Parent = root
	makeTerminal("Terminal_Containment", "Terminal_Containment", Vector3.new(5, 2, -178)).Parent = terminalsFolder
	makeTerminal("Terminal_Intel", "Terminal_Intel", Vector3.new(60, 2, 60)).Parent = terminalsFolder
	makeTerminal("Terminal_CellRelease", "Terminal_CellRelease", Vector3.new(-178, 2, 5)).Parent = terminalsFolder

	local doorsFolder = Instance.new("Folder")
	doorsFolder.Name = "Doors"
	doorsFolder.Parent = root
	makeDoor("Door_Checkpoint", Vector3.new(20, 4, -100), 3).Parent = doorsFolder
	makeDoor("Door_CellBlock", Vector3.new(-170, 4, -20), 1, "CellDoor").Parent = doorsFolder
end

return MapScaffold
