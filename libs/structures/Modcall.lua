local Location = require("structures/Location")
local Modcall, get = require("class")("Modcall")

function Modcall:__init(server, data)
    self._server = server

    local callerName, callerID = data.Caller:match("(.+):(%d+)")
    self._caller_name = callerName
    self._caller_id = tonumber(callerID)
    
    local moderatorName, moderatorID = data.Moderator and data.Moderator:match("(.+):(%d+)")
    self._moderator_name = moderatorName
    self._moderator_id = moderatorID and tonumber(moderatorID)
    
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
end

function get.moderator(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._moderator_name then
            return p
        end
    end
end

function get.timestamp(self)
    return self._timestamp
end

return Modcall
