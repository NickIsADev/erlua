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

function get.player(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._player_name then
            return p
        end
    end

    return OfflinePlayer(self._server, self._player_name, self._player_id)
end

function get.type(self)
    return self._join and "join" or "leave"
end

return JoinLog
