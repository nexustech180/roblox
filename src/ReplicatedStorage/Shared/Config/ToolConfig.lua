--!strict
-- Definitions for every equippable Tool. Tools are built at runtime by InventoryService
-- (see BuildTool) rather than stored as pre-made instances, so balance changes here
-- take effect immediately without touching any binary asset.

export type ToolKind = "Weapon" | "Utility" | "Consumable"

export type ToolDefinition = {
	Id: string,
	DisplayName: string,
	Kind: ToolKind,
	Damage: number?,
	FireRate: number?, -- seconds between shots
	Range: number?,
	MagazineSize: number?,
	ReserveAmmo: number?,
	ReloadSeconds: number?,
	HealAmount: number?,
	UseSeconds: number?, -- channel time for consumables
	HandleColor: Color3,
	HandleSize: Vector3,
}

local ToolConfig: { [string]: ToolDefinition } = {

	Radio = {
		Id = "Radio",
		DisplayName = "Radio",
		Kind = "Utility",
		HandleColor = Color3.fromRGB(40, 40, 40),
		HandleSize = Vector3.new(0.6, 1, 0.4),
	},

	Flashlight = {
		Id = "Flashlight",
		DisplayName = "Flashlight",
		Kind = "Utility",
		HandleColor = Color3.fromRGB(200, 200, 180),
		HandleSize = Vector3.new(0.4, 1.2, 0.4),
	},

	P90 = {
		Id = "P90",
		DisplayName = "FN P90",
		Kind = "Weapon",
		Damage = 22,
		FireRate = 0.1,
		Range = 300,
		MagazineSize = 50,
		ReserveAmmo = 150,
		ReloadSeconds = 2.5,
		HandleColor = Color3.fromRGB(60, 60, 65),
		HandleSize = Vector3.new(0.6, 0.6, 2.4),
	},

	AK = {
		Id = "AK",
		DisplayName = "AK-74",
		Kind = "Weapon",
		Damage = 34,
		FireRate = 0.12,
		Range = 350,
		MagazineSize = 30,
		ReserveAmmo = 90,
		ReloadSeconds = 2.8,
		HandleColor = Color3.fromRGB(80, 55, 30),
		HandleSize = Vector3.new(0.6, 0.6, 2.8),
	},

	AKChaos = {
		Id = "AKChaos",
		DisplayName = "AK-74 (Modified)",
		Kind = "Weapon",
		Damage = 34,
		FireRate = 0.12,
		Range = 350,
		MagazineSize = 30,
		ReserveAmmo = 90,
		ReloadSeconds = 2.8,
		HandleColor = Color3.fromRGB(40, 20, 20),
		HandleSize = Vector3.new(0.6, 0.6, 2.8),
	},

	Medkit = {
		Id = "Medkit",
		DisplayName = "Medkit",
		Kind = "Consumable",
		HealAmount = 60,
		UseSeconds = 3,
		HandleColor = Color3.fromRGB(230, 230, 230),
		HandleSize = Vector3.new(0.8, 0.6, 1),
	},
}

return ToolConfig
