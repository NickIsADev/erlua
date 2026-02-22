local timer = require("timer")

local Emitter = require("class")("Emitter", nil)

function Emitter:__init()
	self._listeners = {}
end

local function new(self, name, listener)
	local listeners = self._listeners[name]
	if not listeners then
		listeners = {}
		self._listeners[name] = listeners
	end
	table.insert(listeners, listener)
	return listener.fn
end

function Emitter:on(name, fn)
	return new(self, name, {fn = fn})
end

function Emitter:once(name, fn)
	return new(self, name, {fn = fn, once = true})
end

function Emitter:onSync(name, fn)
	return new(self, name, {fn = fn, sync = true})
end

function Emitter:onceSync(name, fn)
	return new(self, name, {fn = fn, once = true, sync = true})
end

function Emitter:emit(name, ...)
	local listeners = self._listeners[name]
	if not listeners then return end
	for i = 1, #listeners do
		local listener = listeners[i]
		if listener then
			local fn = listener.fn
			if listener.once then
				listeners[i] = false
				listeners._removed = true
			end
			if listener.sync then
				fn(...)
			else
				coroutine.wrap(fn)(...)
			end
		end
	end
	if listeners._removed then
		for i = #listeners, 1, -1 do
			if not listeners[i] then
				table.remove(listeners, i)
			end
		end
		if #listeners == 0 then
			self._listeners[name] = nil
		end
		listeners._removed = nil
	end
end

function Emitter:getListeners(name)
	local listeners = self._listeners[name]
	if not listeners then return function() end end
	local i = 0
	return function()
		while i < #listeners do
			i = i + 1
			if listeners[i] then
				return listeners[i].fn
			end
		end
	end
end

function Emitter:getListenerCount(name)
	local listeners = self._listeners[name]
	if not listeners then return 0 end
	local n = 0
	for _, listener in ipairs(listeners) do
		if listener then
			n = n + 1
		end
	end
	return n
end

function Emitter:removeListener(name, fn)
	local listeners = self._listeners[name]
	if not listeners then return end
	for i, listener in ipairs(listeners) do
		if listener and listener.fn == fn then
			listeners[i] = false
		end
	end
	listeners._removed = true
end

function Emitter:removeAllListeners(name)
	if name then
		self._listeners[name] = nil
	else
		for k in pairs(self._listeners) do
			self._listeners[k] = nil
		end
	end
end

function Emitter:waitFor(name, timeout, predicate)
	local thread = coroutine.running()
	local fn
	fn = self:onSync(name, function(...)
		if predicate and not predicate(...) then return end
		if timeout then
			table.clearTimeout(timeout)
		end
		self:removeListener(name, fn)
		return assert(coroutine.resume(thread, true, ...))
	end)
	timeout = timeout and table.setTimeout(timeout, function()
		self:removeListener(name, fn)
		return assert(coroutine.resume(thread, false))
	end)
	return coroutine.yield()
end

return Emitter
