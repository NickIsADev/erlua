local Log = require("structures/abstract/Log")
local OfflinePlayer = require("structures/OfflinePlayer")
local KillLog, get = require("class")("KillLog", nil, Log)

function KillLog:__init(server, data)
    Log.__init(self, server, data)
    
    local killerName, killerID = data.Killer:match("(.+):(%d+)")
    self._killer_name = killerName
    self._killer_id = killerID and tonumber(killerID)

    local killedName, killedID = data.Killed:match("(.+):(%d+)")
    self._killed_name = killedName
    self._killed_id = killedID and tonumber(killedID)
end

function KillLog:__tostring()
    return string.format("KillLog: %s (%d) killed %s (%d)", self._killer_name, self._killer_id, self._killed_name, self._killed_id)
end

function get.killer(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._killer_name then
            return p
        end
    end
    
    return OfflinePlayer(self._server, self._killer_name, self._killer_id)
end

function get.killed(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._killed_name then
            return p
        end
    end

    return OfflinePlayer(self._server, self._killed_name, self._killed_id)
end

return KillLog
