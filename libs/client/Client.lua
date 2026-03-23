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
	local id = key:match("%-(.+)")

	if not self._servers[id] then
		local data, err = self._api:getServer(key)
		if data then
			self._servers[id] = Server(self, key, data)
		else
			return nil, err
		end
	end

	return self._servers[id]
end

function Client:handleWebhook(body, signature, timestamp)
	local verified, err = self:_verifySignature(body, signature, timestamp)
	if not verified then
		return false, 401, "The signature could not be validated: " .. (err or "unknown")
	end

	body = json.decode(body)
	self:emit("data", body)

	return true, 200, "The webhook event has been received and processed."
end

return Client
