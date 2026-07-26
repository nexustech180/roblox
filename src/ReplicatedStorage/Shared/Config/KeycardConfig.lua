--!strict
-- Access levels shared by KeycardService (grants) and DoorService (checks).
-- Higher number = more access. A class's KeycardLevel (see ClassConfig) must be
-- >= a door's RequiredLevel attribute for the door to open.

export type KeycardLevelInfo = {
	Level: number,
	Name: string,
	Color: Color3,
}

local KeycardConfig = {
	Levels = {
		[0] = { Level = 0, Name = "None", Color = Color3.fromRGB(120, 120, 120) },
		[1] = { Level = 1, Name = "Class-D Tag", Color = Color3.fromRGB(196, 160, 84) },
		[2] = { Level = 2, Name = "Scientist Keycard", Color = Color3.fromRGB(255, 255, 255) },
		[3] = { Level = 3, Name = "Guard Keycard", Color = Color3.fromRGB(60, 100, 200) },
		[4] = { Level = 4, Name = "MTF Override", Color = Color3.fromRGB(20, 120, 20) },
		[5] = { Level = 5, Name = "O5 Clearance", Color = Color3.fromRGB(180, 20, 20) },
	},

	-- Default RequiredLevel to fall back on if a Door instance is missing the attribute.
	DefaultDoorLevel = 0,
}

return KeycardConfig
