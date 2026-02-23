local timer = require("timer")
local secrets = require("secrets")

local erlua = require("erlua")
local ERLC = erlua.Client()

local function fetch()
    local server, err = ERLC:getServer(secrets.server_key)
    if server then
        print(string.format("Server: %s (Code: %s)\nPlayers: %d/%d\nVehicles: %d\n=======================================", server.name, server.joinCode, server.playercount, server.maxPlayercount, #server.vehicles))
    else
        return false, err
    end
end

fetch()

timer.setInterval(1000, fetch)
