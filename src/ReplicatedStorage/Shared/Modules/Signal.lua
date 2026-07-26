--!strict
-- Minimal pure-Lua signal (GoodSignal-style). No BindableEvent overhead,
-- used internally by services for decoupled server-side eventing.

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable(
	{} :: {
		_handlers: { (...any) -> () },
	},
	Signal
))

function Signal.new(): Signal
	return setmetatable({
		_handlers = {},
	}, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ())
	table.insert(self._handlers, fn)
	local connection = {
		Connected = true,
	}
	function connection.Disconnect(c)
		c.Connected = false
		local idx = table.find(self._handlers, fn)
		if idx then
			table.remove(self._handlers, idx)
		end
	end
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Copy so a handler disconnecting mid-fire can't shift indices under us.
	local handlers = table.clone(self._handlers)
	for _, fn in ipairs(handlers) do
		task.spawn(fn, ...)
	end
end

function Signal.DisconnectAll(self: Signal)
	table.clear(self._handlers)
end

return Signal
