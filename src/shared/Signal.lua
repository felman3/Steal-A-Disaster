--[[
	Signal — tiny synchronous signal for server-side service events.
	Handlers run in order; an erroring handler is reported and does not stop the rest.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self.handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
		end,
	}
end

function Signal:Fire(...)
	local snapshot = {}
	for _, h in ipairs(self.handlers) do
		if h.connected then
			table.insert(snapshot, h)
		end
	end
	self.handlers = snapshot
	for _, h in ipairs(snapshot) do
		local ok, err = pcall(h.fn, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

return Signal
