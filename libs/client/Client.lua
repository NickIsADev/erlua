local openssl = require("openssl")
local opensslVersion = openssl.version()

local enums = require("enums")

local API = require("rest/API")
local Logger = require("utils/Logger")
local Emitter = require("utils/Emitter")
local Server = require("structures/Server")
local Player = require("structures/Player")

local Client = require("class")("Client", nil, Emitter)

local PRC_PUBLIC_KEY = "MCowBQYDK2VwAyEAjSICb9pp0kHizGQtdG8ySWsDChfGqi+gyFCttigBNOA="
local defaultOptions = {
	globalKey = nil,
	logLevel = enums.logLevel.info,
	dateTime = "%F %T",
	ignoredErrorCodes = {},
	offlineEmpty = true,
	apiVersion = 2,
	ttl = 5
}

function Client:__init(options)
	Emitter.__init(self)

	options = options or {}
	for k, v in pairs(defaultOptions) do
		if options[k] == nil then
			options[k] = v
		end
	end

	self._options = options
	self._api = API(self, options.apiVersion)
	self._logger = Logger(options.logLevel, options.dateTime)
	self._servers = {}

	if options.globalKey then
		options.ttl = math.max(options.ttl, 15)
		self._api:authenticate(options.globalKey)
	end
end

for name, level in pairs(enums.logLevel) do
	Client[name] = function(self, fmt, ...)
		local msg = self._logger:log(level, fmt, ...)
		return self:emit(name, msg or string.format(fmt, ...))
	end
end

function Client:_verifySignature(body, signature, timestamp)
	assert(opensslVersion >= "0.8.5", "lua-openssl 0.8.5 or higher is required for ed25519 support")

	local key = openssl.pkey.read(openssl.base64(PRC_PUBLIC_KEY, false), false)
	local digest = openssl.digest.verifyInit(nil, key)
	local sig = signature:gsub("%x%x", function(h)
		return string.char(tonumber(h, 16))
	end)

	return digest:verify(sig, timestamp .. body)
end

function Client:getServer(key)
	if key then
		local cached = self._servers[key]

		if key and cached and cached._server_key ~= key then
			cached:refresh()
			cached = self._servers[key]
		end

		if key and not cached then
			local data, err = self._api:getServer(key) -- fetch it using the key
			if data and next(data) then
				self._servers[key] = Server(self, key, data) -- cache it by id
			else
				return nil, err
			end
		end

		return self._servers[key]
	else
		return nil, "Invalid API key provided"
	end
end

function Client:handleWebhook(body, signature, timestamp)
	local verified, err = self:_verifySignature(body, signature, timestamp)
	if not verified then
		return false, 401, "The signature could not be validated: " .. (err or "unknown")
	end

	body = json.decode(body)
	if not body then
		return false, 401, "The body could not be decoded."
	end
	
	self:emit("raw", body)

	local serverId = body.server ~= "global" and body.server
	local server = serverId and self:getServer(serverId)
	for _, event in pairs(body.events) do
		if event.event == "WebhookProbe" then
			self:emit("probe")
		elseif event.event == "CustomCommand" then
			local command = event.data.command
			local args = event.data.argument ~= "" and string.split(event.argument, " ") or {}

			if server then
				local player = server:getPlayer(tonumber(event.origin))
				self:emit("command", server, player, command, args)
			else
				self:emit("commandUncached", serverId, tonumber(event.origin), command, args)
			end
		end
	end

	return true, 200, "The webhook event has been received and processed."
end

return Client
