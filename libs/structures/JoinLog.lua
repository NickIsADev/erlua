local Log = require("structures/abstract/Log")
local JoinLog, get = require("class")("JoinLog", nil, Log)

function JoinLog:__init(data, server)
    Log.__init(self, data, server)
    
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
end

function get.type(self) -- TODO: Cleanup this temporary solution
    return self._join and "join" or "leave"
end

return JoinLog
