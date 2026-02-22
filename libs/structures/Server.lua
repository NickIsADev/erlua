local uv = require("uv")
local Player = require("structures/Player")
local Vehicle = require("structures/Vehicle")

local function realtime()
    local seconds, microseconds = uv.gettimeofday()
    return seconds + (microseconds / 1000000)
end

local Server, get = require("class")("Server")

function Server:__init(client, serverKey, data, ttl)
    self._client = client
    self._server_key = serverKey
    self._id = serverKey:match("%-(.+)")
    self._ttl = ttl or 15
    self:_load(data)
end

function Server:__tostring()
    return self._name
end

function Server:_load(data)
    self._name = data.Name
    self._join_key = data.JoinKey
    self._account_verification_requirement = data.AccVerifiedReq
    self._team_balance = data.TeamBalance
    self._owner_id = data.OwnerId
    self._co_owner_ids = data.CoOwnerIds
    self._current_players = data.CurrentPlayers -- unreliable
    self._max_players = data.MaxPlayers
    self._players = setmetatable({}, { __mode = "v" })
    self._vehicles = setmetatable({}, { __mode = "v" })

    data.Players = data.Players or self._client._api:getServerPlayers(self._server_key) -- temporary solution until api v2 is accessible
    data.Vehicles = data.Vehicles or self._client._api:getServerVehicles(self._server_key) -- temporary solution until api v2 is accessible

    if data.Players then
        for _, p in pairs(data.Players) do
            table.insert(self._players, Player(self, p))
        end
    end

    if data.Vehicles then
        for _, v in pairs(data.Vehicles) do
            table.insert(self._vehicles, Vehicle(self, v))
        end
    end

    self._last_updated = realtime()
end

function Server:refresh()
    local data, err = self._client._api:getServer(self._server_key)
    if data then
        return self:_load(data)
    else
        return false, err
    end
end

function get.name(self)
    return self._name
end

function get.id(self)
    return self._id
end

function get.verificationLevel(self)
    return self._account_verification_requirement
end

function get.joinCode(self)
    return self._join_key
end

function get.teamBalance(self)
    return not not self._team_balance
end

function get.owner(self)
    return self._owner_id
end

function get.coOwners(self)
    return self._co_owner_ids
end

function get.playercount(self)
    return self._current_players
end

function get.maxPlayercount(self)
    return self.max_players
end

function get.players(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._players
end

function get.vehicles(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._vehicles
end

return Server