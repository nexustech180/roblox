--!strict
-- Server-authoritative combat: every shot, reload, heal and flashlight toggle
-- is a validated RemoteEvent handler here. Tools carry zero scripts - the
-- client only ever *asks* to fire/reload/heal, this service decides if it
-- actually happens. Also the single choke point ("ApplyDamage") that SCP
-- abilities route through, so kill attribution works the same everywhere.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

local CombatService = {}

local Deps: any = nil

-- Humanoid -> { player: Player, time: number }. Used for kill attribution by
-- ClassService when Humanoid.Died fires, and by MissionService for EliminateCount.
local lastDamager: { [Humanoid]: { player: Player, time: number } } = {}

local ATTRIBUTION_WINDOW_SECONDS = 12

local function isHostile(factionA: string?, factionB: string?): boolean
	if factionA == nil or factionB == nil then
		return true
	end
	return factionA ~= factionB
end

function CombatService.ApplyDamage(attacker: Player?, targetHumanoid: Humanoid, damage: number)
	if targetHumanoid.Health <= 0 then
		return
	end
	if attacker then
		lastDamager[targetHumanoid] = { player = attacker, time = os.clock() }
	end
	targetHumanoid:TakeDamage(damage)
end

function CombatService.GetLastAttacker(humanoid: Humanoid): Player?
	local info = lastDamager[humanoid]
	if info and (os.clock() - info.time) < ATTRIBUTION_WINDOW_SECONDS then
		return info.player
	end
	return nil
end

function CombatService.ClearAttribution(humanoid: Humanoid)
	lastDamager[humanoid] = nil
end

local function getEquippedValidatedTool(player: Player, expectedToolId: string): (Model?, Tool?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("ToolId") ~= expectedToolId then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, tool, humanoid
end

local function onWeaponFire(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local toolId, origin, direction = payload.toolId, payload.origin, payload.direction
	if typeof(toolId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.01 then
		return
	end

	local def = ToolConfig[toolId]
	if not def or def.Kind ~= "Weapon" then
		return
	end

	local character, tool, humanoid = getEquippedValidatedTool(player, toolId)
	if not character or not tool or not humanoid or humanoid.Health <= 0 then
		return
	end

	if not Deps.AntiExploitService.CheckRate(player, "WeaponFire", math.max(def.FireRate - 0.03, 0.03)) then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoidRootPart and (origin - humanoidRootPart.Position).Magnitude > 12 then
		Deps.AntiExploitService.Flag(player, "WeaponFire origin too far from character")
		return
	end

	local ammo = tool:GetAttribute("Ammo") :: number
	if ammo == nil or ammo <= 0 then
		return
	end
	local reserve = tool:GetAttribute("Reserve") :: number
	tool:SetAttribute("Ammo", ammo - 1)
	Remotes.InventoryUpdated:FireClient(player, { equipped = toolId, ammo = ammo - 1, reserve = reserve })

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(origin, direction.Unit * def.Range, rayParams)
	if not result then
		return
	end

	local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
	if not hitCharacter then
		return
	end
	local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
	if not hitHumanoid or hitHumanoid.Health <= 0 then
		return
	end

	local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
	if hitPlayer then
		local attackerFaction = Deps.ClassService.GetPlayerFaction(player)
		local victimFaction = Deps.ClassService.GetPlayerFaction(hitPlayer)
		if not isHostile(attackerFaction, victimFaction) then
			return
		end
	end

	local damage = def.Damage :: number
	if result.Instance.Name == "Head" then
		damage *= 1.75
	end

	CombatService.ApplyDamage(player, hitHumanoid, damage)
end

local function onWeaponReload(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.toolId) ~= "string" then
		return
	end
	local toolId = payload.toolId
	local def = ToolConfig[toolId]
	if not def or def.Kind ~= "Weapon" then
		return
	end

	local _, tool = getEquippedValidatedTool(player, toolId)
	if not tool then
		return
	end

	local ammo = tool:GetAttribute("Ammo") :: number
	local reserve = tool:GetAttribute("Reserve") :: number
	if ammo >= def.MagazineSize or reserve <= 0 then
		return
	end
	if not Deps.AntiExploitService.CheckRate(player, "WeaponReload", (def.ReloadSeconds or 1)) then
		return
	end

	task.delay(def.ReloadSeconds or 1, function()
		if tool.Parent == nil then
			return
		end
		local currentAmmo = tool:GetAttribute("Ammo") :: number
		local currentReserve = tool:GetAttribute("Reserve") :: number
		local needed = def.MagazineSize - currentAmmo
		local take = math.min(needed, currentReserve)
		tool:SetAttribute("Ammo", currentAmmo + take)
		tool:SetAttribute("Reserve", currentReserve - take)
		Remotes.InventoryUpdated:FireClient(player, {
			equipped = toolId,
			ammo = currentAmmo + take,
			reserve = currentReserve - take,
		})
	end)
end

local function onUseConsumable(player: Player, payload: any)
	if typeof(payload) ~= "table" or typeof(payload.toolId) ~= "string" then
		return
	end
	local toolId = payload.toolId
	local def = ToolConfig[toolId]
	if not def or def.Kind ~= "Consumable" then
		return
	end

	local character, tool, humanoid = getEquippedValidatedTool(player, toolId)
	if not character or not tool or not humanoid or humanoid.Health <= 0 then
		return
	end

	if not Deps.AntiExploitService.CheckRate(player, "UseConsumable", (def.UseSeconds or 1) + 0.5) then
		return
	end

	Remotes.Notify:FireClient(player, { text = `Using {def.DisplayName}...`, kind = "info" })

	task.delay(def.UseSeconds or 0, function()
		if tool.Parent and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (def.HealAmount or 0))
			tool:Destroy()
			Remotes.Notify:FireClient(player, { text = `{def.DisplayName} used.`, kind = "success" })
		end
	end)
end

local function onToggleFlashlight(player: Player, _payload: any)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("ToolId") ~= "Flashlight" then
		return
	end
	if not Deps.AntiExploitService.CheckRate(player, "ToggleFlashlight", 0.2) then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local light = handle and handle:FindFirstChild("Beam")
	if not light then
		return
	end
	local newState = not tool:GetAttribute("On")
	tool:SetAttribute("On", newState)
	local beam = light :: SpotLight
	beam.Enabled = newState
end

function CombatService.Init(deps: any)
	Deps = deps

	Remotes.WeaponFire.OnServerEvent:Connect(onWeaponFire)
	Remotes.WeaponReload.OnServerEvent:Connect(onWeaponReload)
	Remotes.UseConsumable.OnServerEvent:Connect(onUseConsumable)
	Remotes.ToggleFlashlight.OnServerEvent:Connect(onToggleFlashlight)
end

return CombatService
