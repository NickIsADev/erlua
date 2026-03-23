local enums = require("enums")

local Log = require("structures/abstract/Log")
local OfflinePlayer = require("structures/OfflinePlayer")

local JoinLog, get = require("class")("JoinLog", nil, Log)

function JoinLog:__init(server, data)
    Log.__init(self, server, data)
    
    local name, id = data.Player:match("(.+):(%d+)")
    self._player_name = name
    self._player_id = tonumber(id)

    self._join = data.Join
end

function JoinLog:__tostring()
    return string.format("JoinLog: %s (%d) %s the server", self._player_name, self._player_id, self._join and "joined" or "left")
end

function get.player(self)
    return self._server:getPlayer(self._player_id) or OfflinePlayer(self._server, self._player_name, self._player_id)
end

function get.type(self)
    return self._join and enums.joinLogType.join or enums.joinLogType.leave
end

return JoinLog
