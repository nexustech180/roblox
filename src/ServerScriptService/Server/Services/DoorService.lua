--!strict
-- Drives every access-controlled door in the facility. Map builders just need
-- to tag a BasePart "FoundationDoor" and set a RequiredLevel attribute (see
-- KeycardConfig) - this service adds the ProximityPrompt, checks clearance on
-- trigger, and animates the open/close with TweenService. No door needs a
-- script of its own.
--
-- MissionService calls UnlockGroup(...) when an objective (e.g. releasing the
-- Class-D cells) should blow a whole set of doors open regardless of keycard.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KeycardConfig = require(ReplicatedStorage.Shared.Config.KeycardConfig)

local DOOR_TAG = "FoundationDoor"
local OPEN_HOLD_SECONDS = 6
local SLIDE_TIME = 0.8

local DoorService = {}

local Deps: any = nil
local doorState: { [BasePart]: { closedCFrame: CFrame, open: boolean, permanentlyUnlocked: boolean } } = {}

local function ensurePrompt(door: BasePart): ProximityPrompt
	local prompt = door:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		return prompt
	end
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Door"
	prompt.ObjectText = door:GetAttribute("DoorName") or "Access Door"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	return prompt
end

local openDoor: (door: BasePart) -> ()
local closeDoor: (door: BasePart) -> ()

function openDoor(door)
	local state = doorState[door]
	if not state or state.open then
		return
	end
	state.open = true
	door.CanCollide = false
	local openCFrame = state.closedCFrame + Vector3.new(0, door.Size.Y, 0)
	local tween = TweenService:Create(door, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad), { CFrame = openCFrame })
	tween:Play()

	if not state.permanentlyUnlocked then
		task.delay(OPEN_HOLD_SECONDS, function()
			if doorState[door] == state and state.open and not state.permanentlyUnlocked then
				closeDoor(door)
			end
		end)
	end
end

function closeDoor(door)
	local state = doorState[door]
	if not state or not state.open then
		return
	end
	state.open = false
	local tween = TweenService:Create(door, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad), { CFrame = state.closedCFrame })
	tween:Play()
	tween.Completed:Once(function()
		if doorState[door] == state and not state.open then
			door.CanCollide = true
		end
	end)
end

local function onPromptTriggered(door: BasePart, player: Player)
	local state = doorState[door]
	if not state then
		return
	end
	if state.permanentlyUnlocked then
		openDoor(door)
		return
	end

	local requiredLevel = (door:GetAttribute("RequiredLevel") :: number?) or KeycardConfig.DefaultDoorLevel
	if Deps.KeycardService.HasAccess(player, requiredLevel) then
		openDoor(door)
	else
		Deps.NotifyService.Toast(player, "Access denied - insufficient clearance.", "warning")
	end
end

local function registerDoor(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local door = instance :: BasePart
	if doorState[door] then
		return
	end

	doorState[door] = {
		closedCFrame = door.CFrame,
		open = false,
		permanentlyUnlocked = door:GetAttribute("StartsUnlocked") == true,
	}

	local prompt = ensurePrompt(door)
	prompt.Triggered:Connect(function(player)
		onPromptTriggered(door, player)
	end)

	if doorState[door].permanentlyUnlocked then
		openDoor(door)
	end
end

--- Force every door tagged with Group == groupName wide open and keep it that way.
--- Used by MissionService when a mission unlocks a whole wing (e.g. Class-D cells).
function DoorService.UnlockGroup(groupName: string)
	for door, state in pairs(doorState) do
		if door:GetAttribute("Group") == groupName then
			state.permanentlyUnlocked = true
			openDoor(door)
		end
	end
end

function DoorService.ResetAllDoors()
	for door, state in pairs(doorState) do
		state.permanentlyUnlocked = door:GetAttribute("StartsUnlocked") == true
		state.open = false
		door.CFrame = state.closedCFrame
		door.CanCollide = true
		if state.permanentlyUnlocked then
			openDoor(door)
		end
	end
end

function DoorService.Init(deps: any)
	Deps = deps

	for _, instance in ipairs(CollectionService:GetTagged(DOOR_TAG)) do
		registerDoor(instance)
	end
	CollectionService:GetInstanceAddedSignal(DOOR_TAG):Connect(registerDoor)
	CollectionService:GetInstanceRemovedSignal(DOOR_TAG):Connect(function(instance)
		doorState[instance :: any] = nil
	end)
end

return DoorService
