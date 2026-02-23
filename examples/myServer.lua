local timer = require("timer")
local secrets = require("secrets")

local erlua = require("erlua")
local ERLC = erlua.Client()

local function fetch()
    local server, err = ERLC:getServer(secrets.server_key)
    if server then
        print(server.name, server.playercount .. "/" .. server.maxPlayercount)
    else
        return false, err
    end
end

fetch()

timer.setInterval(5000, fetch)