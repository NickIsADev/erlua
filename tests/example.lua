local erlua = require("erlua")
local secrets = require("secrets")
local timer = require("timer")
local Location = erlua.Location
local ERLC = erlua.Client({
    -- globalKey = secrets.global_key,
    apiVersion = 2
})

local key = secrets.key

local function test()
    local server, err = ERLC:getServer(key)
    if server then
        -- os.execute("cls")
        for _, vehicle in pairs(server.vehicles) do
            print(string.format("Location({LocationX = %d, LocationZ = %d})", vehicle.owner.location.x, vehicle.owner.location.z))
        end
    else
        p("ERROR", err)
    end
end

test()

timer.setInterval(1000, function()
    coroutine.wrap(test)()
end)
