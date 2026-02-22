local uv = require("uv")

local function realtime()
	local seconds, microseconds = uv.gettimeofday()
	return seconds + (microseconds / 1000000)
end

local meta = {}
local names = {}

function meta:__call(...)
	local obj = setmetatable({}, self)
	if self.__ttl then
		obj.__last_touched = realtime()
    	table.insert(self.__instances, obj)
	end
	if obj.__init then
		obj:__init(...)
	end
	return obj
end

function meta:__tostring()
	return "class " .. self.__name
end

local default = {}

function default:__tostring()
	return self.__name
end

local pruner = uv.new_timer()
uv.timer_start(pruner, 1000, 1000, function()
	local now = realtime()
	for _, class in pairs(names) do
		if class.__ttl then
			for i = #class.__instances, 1, -1 do
				local obj = class.__instances[i]
				if obj and now - obj.__last_touched > class.__ttl then
					if obj.__destroy then obj:__destroy() end
					for k in pairs(obj) do obj[k] = nil end
					table.remove(class.__instances, i)
				end
			end
		end
	end
end)

return setmetatable({
	classes = names
}, {
	__call = function(_, name, ttl, ...)
		if names[name] then
			error(string.format("Class %q already defined", name))
		end

		if ttl == true then
			ttl = 30
		end

		local class = setmetatable({}, meta)

		for k, v in pairs(default) do
			class[k] = v
		end

		local bases = {...}
		local getters = {}

		for _, base in ipairs(bases) do
			for k, v in pairs(base) do
				if class[k] == nil then
					class[k] = v
				end
			end
			if base.__getters then
				for k, v in pairs(base.__getters) do
					getters[k] = v
				end
			end
		end

		class.__name = name
		class.__bases = bases
		class.__getters = getters
		class.__ttl = ttl
		class.__instances = setmetatable({}, { __mode = "v" }) -- mode v makes everything in this table able to be gc'd even if they still exist here so that prevents memory leak :yesyes:

		function class:__index(k)
			if ttl then
				rawset(self, "__last_touched", realtime())
			end
			if getters[k] then
				return getters[k](self)
			end
			return class[k]
		end

		names[name] = class

		return class, getters
	end
})
