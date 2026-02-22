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
    apiVersion = 2
}

function Client:__init(options)
    Emitter.__init(self)

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

function Client:getServerPlayers(key)
	local data, err = self._api:getServerPlayers(key)
    if data then
        local players = {}

        for _, player in pairs(data) do
            player.Location = {
                LocationX = 1084.965,
                LocationZ = 2302.28,
                PostalCode = "218",
                StreetName = "Park Street",
                BuildingNumber = "2083"
            }
            table.insert(players, Player(player))
        end

        return players
    else
        return nil, err
    end
end

function Client:getServerJoinLogs(key)
	return self._api:getServerJoinLogs(key)
end

function Client:getServerQueue(key)
	return self._api:getServerQueue(key)
end

function Client:getServerKillLogs(key)
	return self._api:getServerKillLogs(key)
end

function Client:getServerCommandLogs(key)
	return self._api:getServerCommandLogs(key)
end

function Client:getServerModcalls(key)
	return self._api:getServerModcalls(key)
end

function Client:getServerBans(key)
	return self._api:getServerBans(key)
end

function Client:getServerVehicles(key)
	return self._api:getServerVehicles(key)
end

function Client:getServerStaff(key)
	return self._api:getServerStaff(key)
end

function Client:sendServerCommand(key, command)
	command = ":" .. command:gsub("^:", "")
	return self._api:sendServerCommand(key, { command = command })
end

return Client
