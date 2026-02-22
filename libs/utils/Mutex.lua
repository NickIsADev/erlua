local Deque = require("utils/Deque")
local timer = require("timer")

local Mutex = require("class")("Mutex", nil, Deque)

function Mutex:__init()
	Deque.__init(self)
	self._active = false
end

function Mutex:lock(prepend)
	if self._active then
		if prepend then
			return coroutine.yield(self:pushLeft(coroutine.running()))
		else
			return coroutine.yield(self:pushRight(coroutine.running()))
		end
	else
		self._active = true
	end
end

function Mutex:unlock()
	if self:getCount() > 0 then
		return assert(coroutine.resume(self:popLeft()))
	else
		self._active = false
	end
end

local unlock = Mutex.unlock
function Mutex:unlockAfter(delay)
	return timer.setTimeout(delay, unlock, self)
end

return Mutex
