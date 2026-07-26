--!strict
-- Spawns simple hostile NPC "dummies" for EliminateNPCCount mission
-- objectives. Deliberately minimal rigs (a torso-sized HumanoidRootPart plus
-- a Head, welded together) rather than full character models - this is a
-- solo game, the point is a believable target to shoot/melee, not a
-- cosmetic showcase. Swap in real rigs later by editing buildRig below;
-- every caller only ever sees a Model + Humanoid so nothing else changes.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local NPCService = {}

local Deps: any = nil

local npcFolder = Instance.new("Folder")
npcFolder.Name = "HostileNPCs"
npcFolder.Parent = Workspace

export type NPCCombatConfig = {
	Health: number,
	Damage: number,
	WalkSpeed: number,
	AttackRange: number,
	AttackCooldown: number,
}

local function buildRig(position: Vector3): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = "Hostile"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(position)
	root.Color = Color3.fromRGB(150, 30, 30)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0))
	head.Color = Color3.fromRGB(180, 60, 60)
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root
end

local function runChaseAI(model: Model, humanoid: Humanoid, root: BasePart, target: Player, cfg: NPCCombatConfig)
	local lastAttack = 0
	while model.Parent and humanoid.Health > 0 do
		local character = target.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")

		if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
			local distance = (targetRoot.Position - root.Position).Magnitude
			humanoid:MoveTo(targetRoot.Position)

			if distance <= cfg.AttackRange then
				local now = os.clock()
				if now - lastAttack >= cfg.AttackCooldown then
					lastAttack = now
					Deps.CombatService.ApplyDamage(nil, targetHumanoid, cfg.Damage)
				end
			end
		end

		task.wait(0.3)
	end
end

--- Spawns one hostile NPC near `position` that chases and melees `target`.
--- Calls onDied(killer) exactly once, when the NPC's Humanoid dies, with
--- whoever CombatService last attributed damage to (nil if it just expired).
function NPCService.SpawnHostile(position: Vector3, target: Player, cfg: NPCCombatConfig, onDied: (Player?) -> ()): Model
	local model, humanoid, root = buildRig(position)
	humanoid.MaxHealth = cfg.Health
	humanoid.Health = cfg.Health
	humanoid.WalkSpeed = cfg.WalkSpeed

	CollectionService:AddTag(model, "HostileNPC")
	model.Parent = npcFolder

	local diedConn: RBXScriptConnection
	diedConn = humanoid.Died:Connect(function()
		diedConn:Disconnect()
		local killer = Deps.CombatService.GetLastAttacker(humanoid)
		Deps.CombatService.ClearAttribution(humanoid)

		task.delay(6, function()
			if model.Parent then
				model:Destroy()
			end
		end)

		onDied(killer)
	end)

	task.spawn(runChaseAI, model, humanoid, root, target, cfg)

	return model
end

function NPCService.DespawnAll()
	npcFolder:ClearAllChildren()
end

function NPCService.Init(deps: any)
	Deps = deps
end

return NPCService
