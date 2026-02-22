local json = require("json")
local timer = require("timer")
local uv = require("uv")
local http = require("coro-http")
local endpoints = require("rest/endpoints")
local Logger = require("utils/Logger")
local Mutex = require("utils/Mutex")
local package = require("../../package.lua")

local JSON = "application/json"
local USER_AGENT = "ERLua (https://github.com/NickIsADev/erlua, " .. package.version .. ")"

local payloadRequired = {POST = true, PATCH = true, PUT = true}

local function urlencode(obj)
	return (string.gsub(tostring(obj), "%W", tohex))
end

local function realtime()
	local seconds, microseconds = uv.gettimeofday()
	return seconds + (microseconds / 1000000)
end

local API = require("class")("API")

function API:__init(client, apiVersion)
    self._client = client
	self._api_version = apiVersion or 2
	self._base_url = "https://api.policeroleplay.community/v" .. self._api_version
    self._global = Mutex()
    self._buckets = setmetatable({}, {
		__mode = "v",
		__index = function(self, k)
			self[k] = Mutex()
			return self[k]
		end
	})
end

function API:authenticate(globalKey)
    self._global_key = globalKey
    return true
end

function API:request(method, endpoint, payload, key)
    local _, main = coroutine.running()
    if main then
        return false, "Request cannot be made outside of a coroutine"
	elseif not key then
		return false, "Server key was not provided"
	end

    local url = self._base_url .. endpoint
    local headers = {
        {"User-Agent", USER_AGENT},
        {"Server-Key", key}
    }

    if self._global_key then
        table.insert(headers, {"Authorization", self._global_key})
    end

    if payloadRequired[method] then
        payload = payload and json.encode(payload) or "{}"
        table.insert(headers, {"Content-Type", JSON})
        table.insert(headers, {"Content-Length", #payload})
    end

    local global = self._global
    local server = method == "POST" and endpoint == "/server/command" and self._buckets["command-" .. key]

    global:lock()
    if server then
        server:lock()
    end

	local data, err, delay = API:commit(method, url, headers, payload, 0)

    global:unlockAfter(delay.global)
    if server then
        server:unlockAfter(delay.server)
    end

    return data, err
end

function API:commit(method, url, headers, payload, retries)
	local delay = { global = 0, server = 0 }

	local success, result, body = pcall(http.request, method, url, headers, payload)
	if not success then
		return false, result, delay
	end

	for i, v in ipairs(result) do
		result[v[1]:lower()] = v[2]
		result[i] = nil
	end

	local bucket = result["x-ratelimit-bucket"]
	local remaining = tonumber(result["x-ratelimit-remaining"])
	local reset = tonumber(result["x-ratelimit-reset"])

	if remaining == 0 and reset then
		local wait = math.max(((reset - os.time()) + 1) * 1000, 0)
		if bucket and bucket:sub(1, 7) == "command" then
			delay.server = wait
		else
			delay.global = wait
		end
	end

	local data = result["content-type"]:sub(1, #JSON) == JSON and json.decode(body, 1, json.null) or body

	local retry = false
	if result.code < 300 then
		return data, nil, delay
	elseif result.code == 429 and type(data) == "table" and data.retry_after then
		local wait = data.retry_after * 1000
		if bucket and bucket:sub(1, 7) == "command" then
			delay.server = wait
		else
			delay.global = wait
		end
		retry = retries < 2
	elseif result.code == 502 then
		delay.global = delay.global + math.random(0, 2000)
		retry = retries < 2
	end

	if retry then
		local wait = delay.global > 0 and delay.global or delay.server
		if wait > 0 then timer.sleep(wait) end
		return self:commit(method, url, headers, payload, retries + 1)
	end

	local err
	if type(data) == "table" then
		err = string.format("PRC Error %i : %s", data.code or 0, data.message or "Unknown")
	else
		err = string.format("HTTP Error %i : %s", result.code or 0, result.reason or "Unknown")
	end

	local client = self._client
	if client then
		client:error(err)
	end

	return false, err, delay
end

function API:getServer(key)
	local endpoint = string.format(endpoints.SERVER) .. ((self._api_version > 1 and "?Players=true&Staff=true&Joinlogs=true&Queue=true&KillLogs=true&CommandLogs=true&ModCalls=true&Vehicles=true") or "")
	return self:request("GET", endpoint, nil, key)
end

function API:getServerPlayers(key)
	local endpoint = string.format(endpoints.SERVER_PLAYERS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerJoinLogs(key)
	local endpoint = string.format(endpoints.SERVER_JOINLOGS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerQueue(key)
	local endpoint = string.format(endpoints.SERVER_QUEUE)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerKillLogs(key)
	local endpoint = string.format(endpoints.SERVER_KILLLOGS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerCommandLogs(key)
	local endpoint = string.format(endpoints.SERVER_COMMANDLOGS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerModcalls(key)
	local endpoint = string.format(endpoints.SERVER_MODCALLS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerBans(key)
	local endpoint = string.format(endpoints.SERVER_BANS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerVehicles(key)
	local endpoint = string.format(endpoints.SERVER_VEHICLES)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerStaff(key)
	local endpoint = string.format(endpoints.SERVER_STAFF)
	return self:request("GET", endpoint, nil, key)
end

function API:sendServerCommand(key, payload)
	local endpoint = string.format(endpoints.SERVER_COMMAND)
	return self:request("POST", endpoint, payload, key)
end

return API
