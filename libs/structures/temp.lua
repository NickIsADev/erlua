local OfflinePlayer = require("structures/OfflinePlayer")
local ModCall, get = require("class")("ModCall")

function ModCall:__init(server, data)
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

function ModCall:__tostring()
    return string.format("ModCall: %s", self._caller_name)
end

function get.server(self)
    return self._server
end

function get.caller(self)
    return self._server:getPlayer(self._caller_id) or OfflinePlayer(self._server, self._caller_name, self._caller_id)
end

function get.moderator(self)
    if self._moderator_name then
        return self._server:getPlayer(self._moderator_id) or OfflinePlayer(self._server, self._moderator_name, self._moderator_id)
    end
end

function get.timestamp(self)
    return self._timestamp
end

return ModCall
