local Log = require("structures/abstract/Log")
local CommandLog, get = require("class")("CommandLog", nil, Log)

function CommandLog:__init(data, server)
    Log.__init(self, data, server)
    
    local name, id = data.Player:match("(.+):(%d+)")
    self._player_name = name
    self._player_id = tonumber(id)

    self._command = data.Command
end

function CommandLog:__tostring()
    return string.format("CommandLog: %s (%d) used %s", self._player_name, self._player_id, self._command)
end

function get.player(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._player_name then
            return p
        end
    end
end

function get.command(self)
    return self._command
end

return CommandLog
