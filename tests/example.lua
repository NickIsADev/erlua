local erlua = require("erlua")
local secrets = require("secrets")
local timer = require("timer")
local Location = erlua.Location
local ERLC = erlua.Client({
    apiVersion = 1
})

local key = secrets.key

local function test()
    local server, err = ERLC:getServer(key)
    if server then
        print("VEHICLES:")
        for _, vehicle in pairs(server.vehicles) do
            p(vehicle.make, vehicle.model, vehicle.year, vehicle.owner.name, vehicle.owner.id)
        end
    else
        p("ERROR", err)
    end
end

test()

timer.setInterval(5000, function()
    coroutine.wrap(test)()
end)
