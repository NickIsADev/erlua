local erlua = require("erlua")
local secrets = require("secrets")
local timer = require("timer")
local Location = erlua.Location
local ERLC = erlua.Client({
    apiVersion = 1
})

local serverKey = secrets.key

local server, err = ERLC:getServer(serverKey)
if server then
    p(server)

    timer.sleep(5000)

    local server, err = ERLC:getServer(serverKey)
    p(server, err)

    timer.sleep(2500)


    p(ERLC._servers)
else
    p("failed", err)
end