local enums = require("enums")

local OfflinePlayer, get = require("class")("OfflinePlayer")

function OfflinePlayer:__init(server, name, id)
    self._server = server
    self._name = name
    self._id = id and tonumber(id) or 0
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

function get.profile(self)
    return "<https://roblox.com/users/" .. self._id .. "/profile>"
end

function get.hyperlink(self)
    return "[" .. self._name .. "](" .. self.profile .. ")"
end

return OfflinePlayer
