--!strict
-- Small cleanup-tracking utility. Add() anything with a :Destroy()/:Disconnect()
-- (or a plain function), Clean() tears everything down in reverse insertion order.
-- Keeps per-round and per-player teardown in services from leaking connections.

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable(
	{} :: {
		_items: { any },
	},
	Trove
))

function Trove.new(): Trove
	return setmetatable({
		_items = {},
	}, Trove)
end

function Trove.Add(self: Trove, item: any): any
	table.insert(self._items, item)
	return item
end

local function cleanupOne(item: any)
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" then
		item:Disconnect()
	elseif itemType == "Instance" then
		item:Destroy()
	elseif itemType == "function" then
		item()
	elseif itemType == "table" then
		if typeof(item.Disconnect) == "function" then
			item:Disconnect()
		elseif typeof(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Trove.Clean(self: Trove)
	for i = #self._items, 1, -1 do
		local ok, err = pcall(cleanupOne, self._items[i])
		if not ok then
			warn("[Trove] cleanup failed:", err)
		end
		self._items[i] = nil
	end
end

return Trove
