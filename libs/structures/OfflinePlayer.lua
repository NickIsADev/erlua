local enums = require("enums")

local OfflinePlayer, get = require("class")("OfflinePlayer")

function OfflinePlayer:__init(server, name, id)
    self._server = server
    self._name = name
    self._id = tonumber(id)
end

function OfflinePlayer:__tostring()
    return string.format("OfflinePlayer: %s (%d)", self._name, self._id)
end

function get.server(self)
    return self._server
end

function get.name(self)
    return self._name
end

function get.id(self)
    return self._id
end

return OfflinePlayer
