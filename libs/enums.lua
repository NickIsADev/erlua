local function enum(tbl)
	local call = {}
	for k, v in pairs(tbl) do
		if call[v] then
			return error(string.format('enum clash for %q and %q', k, call[v]))
		end
		call[v] = k
	end
	return setmetatable({}, {
		__call = function(_, k)
			if call[k] then
				return call[k]
			else
				return error('invalid enumeration: ' .. tostring(k))
			end
		end,
		__index = function(_, k)
			if tbl[k] then
				return tbl[k]
			else
				return error('invalid enumeration: ' .. tostring(k))
			end
		end,
		__pairs = function()
			return next, tbl
		end,
		__newindex = function()
			return error('cannot overwrite enumeration')
		end,
	})
end

local enums = {enum = enum}

enums.logLevel = enum {
	none    = 0,
	error   = 1,
	warning = 2,
	info    = 3,
	debug   = 4,
}

enums.permission = enum {
	normal		  = 0,
	helper		  = 1,
	moderator	  = 2,
	administrator = 3,
	coOwner		  = 4,
	owner		  = 5
}

return enums
