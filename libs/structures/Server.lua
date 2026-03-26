local uv = require("uv")
local Player = require("structures/Player")
local Vehicle = require("structures/Vehicle")
local KillLog = require("structures/KillLog")
local JoinLog = require("structures/JoinLog")
local CommandLog = require("structures/CommandLog")
local ModCall = require("structures/ModCall")
local EmergencyCall = require("structures/EmergencyCall")
local OfflinePlayer = require("structures/OfflinePlayer")

local function realtime()
    local seconds, microseconds = uv.gettimeofday()
    return seconds + (microseconds / 1000000)
end

local Server, get = require("class")("Server")

function Server:__init(client, serverKey, data)
    self._client = client
    self._server_key = serverKey
    self._id = serverKey:match("%-(.+)")
    self._ttl = client._options.ttl
    self:_load(data)
end

function Server:__tostring()
    return string.format("Server: %s", self._name)
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

    local players = {}
    local vehicles = {}
    local kill_logs = {}
    local join_logs = {}
    local command_logs = {}
    local mod_calls = {}
    local emergency_calls = {}

    if data.Players then
        for _, p in pairs(data.Players) do
            table.insert(players, Player(self, p))
        end
    end

    if data.Vehicles then
        for _, v in pairs(data.Vehicles) do
            table.insert(vehicles, Vehicle(self, v))
        end
    end

    if data.KillLogs then
        table.sort(data.KillLogs, function(a, b)
            return a.Timestamp < b.Timestamp
        end)

        for _, v in pairs(data.KillLogs) do
            table.insert(kill_logs, KillLog(self, v))
        end
    end

    if data.JoinLogs then
        table.sort(data.JoinLogs, function(a, b)
            return a.Timestamp < b.Timestamp
        end)

        for _, v in pairs(data.JoinLogs) do
            table.insert(join_logs, JoinLog(self, v))
        end
    end

    if data.CommandLogs then
        table.sort(data.CommandLogs, function(a, b)
            return a.Timestamp < b.Timestamp
        end)
        
        for _, v in pairs(data.CommandLogs) do
            table.insert(command_logs, CommandLog(self, v))
        end
    end

    if data.ModCalls then
        table.sort(data.ModCalls, function(a, b)
            return a.Timestamp < b.Timestamp
        end)

        for _, v in pairs(data.ModCalls) do
            table.insert(mod_calls, ModCall(self, v))
        end
    end

    if data.EmergencyCalls then
        table.sort(data.EmergencyCalls, function(a, b)
            return a.StartedAt < b.StartedAt
        end)

        for _, v in pairs(data.EmergencyCalls) do
            table.insert(emergency_calls, EmergencyCall(self, v))
        end
    end

    if data.Queue then
        self._queue = data.Queue
    end

    if data.Staff then
        self._staff = data.Staff
    end

    self._players = players
    self._vehicles = vehicles
    self._kill_logs = kill_logs
    self._join_logs = join_logs
    self._command_logs = command_logs
    self._mod_calls = mod_calls
    self._emergency_calls = emergency_calls
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

function Server:execute(command)
	command = ":" .. command:gsub("^:", "")
    return self._client._api:sendServerCommand(self._server_key, { command = command })
end

function Server:getPlayer(query, offline)
    for _, p in pairs(self.players) do
        if p.name == query or p.id == query then
            return p
        end
    end

    if offline then
        for _, l in pairs(self.joinLogs) do
            if l.player.name == query or l.player.id == query then
                return l.player
            end
        end
    end
end

function Server:raw()
    local function rawPlayer(player)
        return {
            name = player.name,
            id = player.id,
            profile = player.profile,
            hyperlink = player.hyperlink,
            team = player.team,
            callsign = player.callsign,
            permission = player.permission,
            wantedStars = player.wantedStars,
            location = player.location and {
                x = player.location.x,
                z = player.location.z,
                postalCode = player.location.postalCode,
                streetName = player.location.streetName,
                buildingNumber = player.location.buildingNumber,
            },
        }
    end

    local raw = {
        name = self.name,
        verificationLevel = self.verificationLevel,
        joinCode = self.joinCode,
        teamBalance = self.teamBalance,
        owner = self.owner,
        coOwners = self.coOwners,
        playercount = self.playercount,
        maxPlayercount = self.maxPlayercount,
        staff = self.staff,
        queue = self.queue,
        players = {},
        vehicles = {},
        killLogs = {},
        joinLogs = {},
        commandLogs = {},
        modCalls = {},
        emergencyCalls = {}
    }

    for _, v in pairs(self.players) do
        table.insert(raw.players, rawPlayer(v))
    end

    for _, v in pairs(self.vehicles) do
        table.insert(raw.vehicles, {
            name = v.name,
            make = v.make,
            model = v.model,
            year = v.year,
            owner = rawPlayer(v.owner),
            plate = v.plate,
            livery = v.livery,
            color = v.color,
            colorHex = v.colorHex,
        })
    end

    for _, v in pairs(self.killLogs) do
        table.insert(raw.killLogs, {
            killer = rawPlayer(v.killer),
            killed = rawPlayer(v.killed),
            timestamp = v.timestamp,
        })
    end

    for _, v in pairs(self.joinLogs) do
        table.insert(raw.joinLogs, {
            player = rawPlayer(v.player),
            join = v.join,
            timestamp = v.timestamp,
        })
    end

    for _, v in pairs(self.commandLogs) do
        table.insert(raw.commandLogs, {
            player = rawPlayer(v.player),
            command = v.command,
            timestamp = v.timestamp,
        })
    end

    for _, v in pairs(self.modCalls) do
        table.insert(raw.modCalls, {
            caller = rawPlayer(v.caller),
            moderator = v.moderator and rawPlayer(v.moderator),
            timestamp = v.timestamp,
        })
    end

    for _, v in pairs(self.emergencyCalls) do
        table.insert(raw.emergencyCalls, {
            team = v.team,
            caller = v.caller and rawPlayer(v.caller),
            description = v.description,
            number = v.number,
            position = v.position and {
                x = v.position.x,
                z = v.position.z
            },
            positionDescriptor = v.positionDescriptor,
            responders = v.responders,
            timestamp = v.timestamp,
        })
    end

    return raw
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
    return self._players and #self._players or 0
end

function get.maxPlayercount(self)
    return self._max_players
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

function get.killLogs(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._kill_logs
end

function get.joinLogs(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._join_logs
end

function get.commandLogs(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._command_logs
end

function get.modCalls(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._mod_calls
end

function get.emergencyCalls(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._emergency_calls
end

function get.queue(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._queue
end

function get.staff(self)
    if (realtime() - self._last_updated) > self._ttl then
        self:refresh()
    end

    return self._staff
end

return Server
