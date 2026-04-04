local json = require("json")
local timer = require("timer")
local uv = require("uv")
local http = require("coro-http")
local endpoints = require("rest/endpoints")
local Mutex = require("utils/Mutex")
local package = require("../../package.lua")

local JSON = "application/json"
local USER_AGENT = "ERLua (https://github.com/NickIsADev/erlua, " .. package.version .. ")"

local payloadRequired = { POST = true, PATCH = true, PUT = true }

local function realtime()
	local seconds, microseconds = uv.gettimeofday()
	return seconds + (microseconds / 1000000)
end

local API = require("class")("API")

function API:__init(client, apiVersion)
	self._client = client
	self._api_version = apiVersion or 2
	self._base_url = "https://api.policeroleplay.community/v" .. self._api_version
	self._buckets = setmetatable({}, {
		__mode = "v",
		__index = function(self, k)
			local limit = k:sub(1, 7) == "command" and 1 or 35

			self[k] = {
				mutex = Mutex(),
				remaining = limit,
				limit = limit,
				reset = 0
			}
			return self[k]
		end
	})
end

function API:authenticate(globalKey)
	if self._client then
		self._client:info("Authenticated with global key")
	end
	self._global_key = globalKey
	return true
end

function API:request(method, endpoint, payload, key, base)
	local _, main = coroutine.running()
	if main then
		return false, "Request cannot be made outside of a coroutine"
	elseif not key then
		return false, "Server key was not provided"
	elseif not key:match("%-(.+)") then
		return false, "Server key provided is invalid"
	end

	local url = (base or self._base_url) .. endpoint
	local headers = {
		{ "User-Agent", USER_AGENT },
		{ "Server-Key", key }
	}

	if self._global_key then
		table.insert(headers, { "Authorization", self._global_key })
	end

	if payloadRequired[method] then
		payload = payload and json.encode(payload) or "{}"
		table.insert(headers, { "Content-Type", JSON })
		table.insert(headers, { "Content-Length", #payload })
	end

	local bucketName = method == "POST" and endpoint == endpoints.SERVER_COMMAND and "command-" .. key or "global"
	local bucket = self._buckets[bucketName]

	bucket.mutex:lock()

	local now = realtime()
	if bucket.remaining <= 0 and bucket.reset > now then
		local delay = (bucket.reset - now) * 1000
		if self._client then
			self._client:info("Bucket %s is ratelimited; waiting %.2fms", bucketName, delay)
		end
		timer.sleep(delay)
		now = realtime()
	end

	local holding = true
	bucket.remaining = bucket.remaining - 1
	if bucket.remaining > 0 then
		bucket.mutex:unlock()
		holding = false
	end

	local data, err, headers = self:commit(method, url, headers, payload, 0)

	if headers then
		local limit = tonumber(headers["x-ratelimit-limit"])
		local remaining = tonumber(headers["x-ratelimit-remaining"])
		local reset = tonumber(headers["x-ratelimit-reset"])

		if limit then bucket.limit = limit end
		if reset then bucket.reset = reset + 0.1 end -- 100ms buffer

		if remaining then
			if remaining < bucket.remaining or bucket.remaining <= 0 then
				bucket.remaining = remaining
			end
		end
	end

	if holding then
		bucket.mutex:unlock()
	end

	return data, err
end

function API:commit(method, url, headers, payload, retries)
	local client = self._client
	if client then
		self._client:debug("%s %s", method, url)
	end
	local success, result, body = pcall(http.request, method, url, headers, payload)
	if self._client then
		self._client:debug("%d %s", result and result.code or 0, result and result.reason or "Unknown")
	end
	if not success then
		return false, result
	end

	for i, v in ipairs(result) do
		result[v[1]:lower()] = v[2]
		result[i] = nil
	end

	local data = result["content-type"] and result["content-type"]:sub(1, #JSON) == JSON and json.decode(body, 1, json.null) or body

	local retry = false
	local delay = 0
	if result.code < 300 then
		return data, nil, result
	elseif result.code == 422 and client and client._options and client._options.offlineEmpty then
		return {}, nil, result
	elseif result.code == 429 then
		if type(data) == "table" and data.retry_after and data.retry_after ~= json.null then
			delay = data.retry_after * 1000
		elseif result["retry-after"] then
			delay = tonumber(result["retry-after"]) * 1000
		end
		retry = retries < 2
	elseif result.code == 502 then
		delay = math.random(500, 2000)
		retry = retries < 2
	end

	if retry then
		if delay > 0 then
			timer.sleep(delay)
		end
		return self:commit(method, url, headers, payload, retries + 1)
	end

	local err
	if type(data) == "table" then
		err = string.format("PRC Error %i : %s", data.code or 0, data.message or "Unknown")
	else
		err = string.format("HTTP Error %i : %s", result.code or 0, result.reason or "Unknown")
	end

	if client and not (client._options and client._options.ignoredErrorCodes and client._options.ignoredErrorCodes[tostring(data.code or 0)]) then
		client:error(err)
	end

	return false, err, result
end

function API:getServer(key)
	local endpoint = string.format(endpoints.SERVER) .. ((self._api_version > 1 and "?Players=true&Vehicles=true&Staff=true&JoinLogs=true&Queue=true&KillLogs=true&CommandLogs=true&ModCalls=true&EmergencyCalls=true") or "")
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

function API:getServerModCalls(key)
	local endpoint = string.format(endpoints.SERVER_MODCALLS)
	return self:request("GET", endpoint, nil, key)
end

function API:getServerBans(key)
	local endpoint = string.format(endpoints.SERVER_BANS)
	return self:request("GET", endpoint, nil, key, "https://api.policeroleplay.community/v1")
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
