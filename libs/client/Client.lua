local enums = require("enums")

local API = require("rest/API")
local Logger = require("utils/Logger")
local Emitter = require("utils/Emitter")
local Server = require("structures/Server")
local Player = require("structures/Player")

local Client = require("class")("Client", nil, Emitter)

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
    self._servers = setmetatable({}, { __mode = "v" })
    
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

return Client
