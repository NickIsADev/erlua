local erlua = require("erlua")
local secrets = require("secrets")
local Location = erlua.Location
local ERLC = erlua.Client({
    apiVersion = 1
})

local serverKey = secrets.key

local server, err = ERLC:getServer(serverKey)
if server then
    p(server)
else
    p("failed", err)
end