local erlua = {
	GlobalKey = nil,
	ServerKey = nil,
	LogLevel = 0,
	Requests = {},
	Ratelimits = {},
	ActiveBuckets = {},
	RequestOrigins = {},
	ValidTeams = {
		civilian = true,
		police = true,
		sheriff = true,
		fire = true,
		dot = true,
		jail = true,
	},
}

--[[
	Log Levels:
	- Error = 2
	- Warning = 1
	- Info = 0
]]

local http = require("coro-http")
local json = require("json")
local timer = require("timer")
local uv = require("uv")

--[[
if not success or type(response) ~= "table" or response.code then
  return false, response
end
]]

--[[ Utility Functions ]]
--

local function log(text, mode)
	text = text or "no text provided"
	mode = mode or "info"

	local date = os.date("%x @ %I:%M:%S%p", os.time())

	if mode == "success" then -- unused??
		print(date .. " | \27[32m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "info" and not (erlua.LogLevel > 0) then
		print(date .. " | \27[32m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "warning" and not (erlua.LogLevel > 1) then
		print(date .. " | \27[35m\27[1m[ERLUA]\27[0m | " .. text)
	elseif mode == "error" then
		print(date .. " | \27[31m\27[1m[ERLUA]\27[0m | " .. text)
	end
end

local function split(str, delim)
	local ret = {}
	if not str then
		return ret
	end
	if not delim or delim == "" then
		for c in string.gmatch(str, ".") do
			table.insert(ret, c)
		end
		return ret
	end
	local n = 1
	while true do
		local i, j = string.find(str, delim, n)
		if not i then
			break
		end
		table.insert(ret, string.sub(str, n, i - 1))
		n = j + 1
	end
	table.insert(ret, string.sub(str, n))
	return ret
end

local function header(headers, name)
	for _, header in pairs(headers) do
		if type(header) == "table" and type(header[1]) == "string" and header[1]:lower() == name:lower() then
			return header[2]
		end
	end
end

local function realtime()
	local seconds, microseconds = uv.gettimeofday()

	return seconds + (microseconds / 1000000)
end

local function Error(code, message)
	message = message or "unknown error"
	log(message, "error")
	return {
		code = code,
		message = message,
	}
end

local function safeResume(co, ...)
	if type(co) ~= "thread" then return false, "Invalid coroutine" end
	if coroutine.status(co) ~= "suspended" then return false, "Coroutine not suspended" end

	local ok, result = coroutine.resume(co, ...)
	if not ok then
		return false, result
	end
	return true, result
end

local function origin()
	local debugInfo
	for i = 1, 10 do
		debugInfo = debug.getinfo(i, "Sl")
		if (debugInfo) and (not debugInfo.short_src:lower():find("erlua")) and (debugInfo.what ~= "C") then
			break
		end
	end
	return (debugInfo and (debugInfo.short_src .. ":" .. debugInfo.currentline)) or nil
end

-- [[ ERLua Functions ]] --

function erlua:SetGlobalKey(gk)
	erlua.GlobalKey = gk
	log("Set global key to [HIDDEN].", "info")
	return erlua
end

function erlua:SetServerKey(sk)
	erlua.ServerKey = sk
	log("Set server key to [HIDDEN].", "info")
	return erlua
end

function erlua:setLogLevel(logLevel)
	if tonumber(logLevel) and tonumber(logLevel) >= 0 and tonumber(logLevel) < 3 then
		erlua.LogLevel = tonumber(logLevel)
	elseif type(logLevel) == "string" then
		if logLevel:lower() == "info" then
			erlua.LogLevel = 0
		elseif logLevel:lower() == "warning" then
			erlua.LogLevel = 1
		elseif logLevel:lower() == "error" then
			erlua.LogLevel = 2
		end
	end

	return erlua
end

function erlua:request(method, endpoint, body, process, serverKey, globalKey)
	serverKey = (serverKey or erlua.ServerKey) or nil
	globalKey = (globalKey or erlua.GlobalKey) or nil
	if not serverKey then
		return false, Error(400, "A server key was not provided.")
	end

	local url = "https://api.policeroleplay.community/v1/" .. endpoint
	local headers = {
		{ "Content-Type", "application/json" },
		{ "Server-Key", serverKey },
	}
	if globalKey then
		table.insert(headers, { "Authorization", globalKey })
	end

	log("Requesting " .. method .. " /" .. endpoint .. ".", "info")
	local ok, result, response = pcall(function()
		return http.request(method, url, headers, (body and json.encode(body)) or nil)
	end)

	response = response and json.decode(response)

	if ok and result.code == 200 then
		if process then
			response = process(response)
		end
		return true, result, response
	elseif ok then
		return false, result, response
	else
		local errObject = Error(500, "HTTP request attempt returned not ok.")
		return false, errObject, errObject
	end
end

function erlua:queue(request)
	log("Request " .. request.method .. " /" .. request.endpoint .. " queued.", "info")
	request.timestamp = request.timestamp or os.time()
	request.co = coroutine.running()
	assert(request.co, "erlua:queue must be called from inside a coroutine")

	local b = (request.method == "POST" and "command-" .. (request.serverKey or "unauthorized"))
		or ((erlua.GlobalKey or request.globalKey) and "global")
		or "unauthenticated-global"

	erlua.Requests[b] = erlua.Requests[b] or {}
	table.insert(erlua.Requests[b], request)

	if request.origin then
		erlua.RequestOrigins[request.origin] = (erlua.RequestOrigins[request.origin] or 0) + 1
	end

	return coroutine.yield()
end

function erlua:dump()
	log("Scanning queue for runnable requests...", "info")

	local now = realtime()

	for bucket, list in pairs(erlua.Requests) do
		if bucket == "global" or not erlua.ActiveBuckets[bucket] then
			erlua.ActiveBuckets[bucket] = true

			coroutine.wrap(function()
				local req = table.remove(list, 1)
				if not req then
					erlua.ActiveBuckets[bucket] = nil
					return
				end

				local ok, err = pcall(function()
					local state = erlua.Ratelimits[bucket]

					if state and state.retry and now < (state.updated + state.retry) then
						table.insert(list, 1, req)
						return
					end

					local ok, result, response =
						erlua:request(req.method, req.endpoint, req.body, req.process, req.serverKey, req.globalKey)

					local headers = result or {}
					local remaining = header(headers, "X-RateLimit-Remaining")
					local reset = header(headers, "X-RateLimit-Reset")

					erlua.Ratelimits[bucket] = {
						updated = realtime(),
						retry = response and response.retry_after,
						remaining = remaining and tonumber(remaining),
						reset = reset and tonumber(reset),
					}

					if not ok and result.code == 429 then
						log("The " .. (bucket or "unknown") .. " bucket was ratelimited, requeueing.", "warning")
						table.insert(list, 1, req)
					else
						log("Request " .. req.method .. " /" .. req.endpoint .. " fulfilled.")
						if #list == 0 then
							erlua.Requests[bucket] = nil
						end
						safeResume(req.co, ok, response, result)
					end
				end)

				erlua.ActiveBuckets[bucket] = nil

				if not ok then
					Error(500, "Error during bucket dump: " .. tostring(err))
				end
			end)()

		end
	end
end

local dumpTimer = uv.new_timer()

uv.timer_start(dumpTimer, 0, 5, function()
	if next(erlua.Requests) then
		erlua:dump()
	end
end)

-- [[ Endpoint Functions ]] --

function erlua.Server(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin()
	})
end

function erlua.Players(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/players",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin(),
		process = function(data)
			local players = {}

			for _, player in pairs(data) do
				if player.Player then
					table.insert(players, {
						Name = split(player.Player, ":")[1],
						ID = split(player.Player, ":")[2],
						Player = player.Player,
						Permission = player.Permission,
						Callsign = player.Callsign,
						Team = player.Team,
					})
				end
			end

			return players
		end,
	})
end

function erlua.Vehicles(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/vehicles",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin()
	})
end

function erlua.PlayerLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/joinlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin(),
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.KillLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/killlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin(),
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.CommandLogs(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/commandlogs",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin(),
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.ModCalls(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/modcalls",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin(),
		process = function(data)
			table.sort(data, function(a, b)
				if (not a.Timestamp) or not b.Timestamp then
					return false
				else
					return a.Timestamp < b.Timestamp
				end
			end)

			return data
		end,
	})
end

function erlua.Bans(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/bans",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin()
	})
end

function erlua.Queue(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/queue",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin()
	})
end

function erlua.Permissions(serverKey, globalKey)
	return erlua:queue({
		method = "GET",
		endpoint = "server/staff",
		serverKey = serverKey,
		globalKey = globalKey,
		origin = origin()
	})
end

-- [[ Custom Functions ]] --

function erlua.Staff(serverKey, globalKey, preloadPlayers)
	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local staff = {}

	for _, player in pairs(players) do
		if player.Permission and player.Permission ~= "Normal" then
			table.insert(staff, player)
		end
	end

	return true, staff, result
end

function erlua.Team(serverKey, globalKey, teamName, preloadPlayers)
	if not teamName or not erlua.ValidTeams[teamName:lower()] then
		return false, Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided.")
	end

	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local team = {}
	local teamNameLower = teamName:lower()

	for _, player in pairs(players) do
		if player.Team and player.Team:lower() == teamNameLower then
			table.insert(team, player)
		end
	end

	return true, team, result
end

function erlua.TrollUsernames(serverKey, globalKey, preloadPlayers)
	local players
	local result
	if preloadPlayers then
		players = preloadPlayers
	else
		local ok
		ok, players, result = erlua.Players(serverKey, globalKey)
		if not ok then
			return ok, players, result
		end
	end

	local trolls = {}

	for _, player in pairs(players) do
		local name = player.Player
		if name then
			local lname = name:lower()
			local startsWithAll = lname:sub(1, 3) == "all"
			local startsWithOthers = lname:sub(1, 6) == "others"

			local countIl = select(2, name:gsub("Il", ""))
			local countlI = select(2, name:gsub("lI", ""))
			local total = countIl + countlI

			if startsWithAll or startsWithOthers or total >= 2 then
				table.insert(trolls, player)
			end
		end
	end

	return true, trolls, result
end

function erlua.Command(command, serverKey, globalKey)
	return erlua:queue({
		method = "POST",
		endpoint = "server/command",
		body = {
			command = (command:sub(1, 1) == ":" and command) or (":" .. command),
		},
		serverKey = serverKey,
		globalKey = globalKey,
	})
end

return erlua
