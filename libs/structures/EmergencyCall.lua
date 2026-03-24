local Location = require("structures/Location")
local OfflinePlayer = require("structures/OfflinePlayer")
local EmergencyCall, get = require("class")("EmergencyCall")

function EmergencyCall:__init(server, data)
    self._server = server
    self._team = data.Team
    self._description = data.Description
    self._caller = tonumber(data.Caller)
    self._call_number = tonumber(data.CallNumber)
    self._position = data.Position and Location({LocationX = data.Position[1], LocationZ = data.Position[2]})
    self._position_descriptor = data.PositionDescriptor
    self._players = {}

    for _, id in pairs(data.Players) do
        local player = server:getPlayer(id)
        if player then
            table.insert(self._players, player)
        end
    end
    
    self._started_at = data.StartedAt
end

function EmergencyCall:__tostring()
    return string.format("EmergencyCall: %d", self._call_number)
end

function get.server(self)
    return self._server
end

function get.team(self)
    return self._team
end

function get.players(self)
    return self._players
end

function get.description(self)
    return self._description
end

function get.caller(self)
    return self._server:getPlayer(self._caller, true) or OfflinePlayer(self._server, nil, self._caller_id)
end

function get.number(self)
    return self._call_number
end

function get.position(self)
    return self._position
end

function get.positionDescriptor(self)
    return self._position_descriptor
end

function get.timestamp(self)
    return self._started_at
end

return EmergencyCall
