local erlua = require("erlua")
local secrets = require("secrets")
local timer = require("timer")
local Location = erlua.Location
local ERLC = erlua.Client({
    apiVersion = 2
})

local key = secrets.key

local function test()
    local server, err = ERLC:getServer(key)
    if server then
        for _, player in pairs(server.players) do
            print(player.name, tostring(player.location))
        end
    else
        p("ERROR", err)
    end
end

test()

timer.setInterval(1000, function()
    coroutine.wrap(test)()
end)
