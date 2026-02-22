local Location = require("structures/Location")
local Player, get = require("class")("Player")

function Player:__init(server, data)
    self._server = server
    local name, id = data.Player:match("(.+):(%d+)")
    self._name = name
    self._id = tonumber(id)
    self._callsign = data.Callsign
    self._team = data.Team
    self._permission = data.Permission
    self._wanted_stars = data.WantedStars
    self._location = data.Location and Location(data.Location, self)
end

function Player:__tostring()
    return string.format("Player: %s (%d)", self._name, self._id)
end

function get.name(self)
    return self._name
end

function get.id(self)
    return self._id
end

function get.team(self)
    return self._team
end

function get.permission(self)
    return self._permission
end

function get.wantedStars(self)
    return self._wanted_stars
end

function get.location(self)
    return self._location
end

return Player
