--!strict
-- Small constructor helpers so controllers build UI declaratively instead of
-- repeating the same five-line Instance.new/property-set dance everywhere.

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local UIUtil = {}

local function applyProps(instance: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
end

function UIUtil.New(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)
	applyProps(instance, props)
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance
end

function UIUtil.Corner(radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	return corner
end

function UIUtil.Stroke(color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Accent
	stroke.Thickness = thickness or 1
	return stroke
end

function UIUtil.Padding(all: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, all)
	padding.PaddingBottom = UDim.new(0, all)
	padding.PaddingLeft = UDim.new(0, all)
	padding.PaddingRight = UDim.new(0, all)
	return padding
end

function UIUtil.ScreenGui(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

function UIUtil.Tween(instance: Instance, info: TweenInfo, props: { [string]: any })
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function UIUtil.FormatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

return UIUtil
