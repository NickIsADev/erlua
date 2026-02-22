local Log, get = require("class")("Log")

function Log:__init(server, data)
    self._server = server
    self._timestamp = data.Timestamp
end

function get.server(self)
    return self._server
end

function get.timestamp(self)
    return self._timestamp
end

return Log
