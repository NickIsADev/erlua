local Location = require("structures/Location")
local OfflinePlayer = require("structures/OfflinePlayer")
local Modcall, get = require("class")("Modcall")

function Modcall:__init(server, data)
    self._server = server

    local callerName, callerID = data.Caller:match("(.+):(%d+)")
    self._caller_name = callerName
    self._caller_id = tonumber(callerID)
    
    if data.Moderator then
        local moderatorName, moderatorID = data.Moderator:match("(.+):(%d+)")
        self._moderator_name = moderatorName
        self._moderator_id = moderatorID and tonumber(moderatorID)
    end
    
    self._timestamp = data.Timestamp
end

function Modcall:__tostring()
    return string.format("Modcall: %s", self._caller_name)
end

function get.server(self)
    return self._server
end

function get.caller(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._caller_name then
            return p
        end
    end

    return OfflinePlayer(self._server, self._caller_name, self._caller_id)
end

function get.moderator(self) -- TODO: Cleanup this temporary solution
    if self._moderator_name then
        for _, p in pairs(self._server.players) do
            if p.name == self._moderator_name then
                return p
            end
        end

        return OfflinePlayer(self._server, self._moderator_name, self._moderator_id)
    end
end

function get.timestamp(self)
    return self._timestamp
end

return Modcall
