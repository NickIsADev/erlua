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
        for _, player in pairs(server.players) do
            local region = "None"

            for _, r in pairs(erlua.regions) do
                if r:contains(player.location) then
                    region = r.name
                    break
                end
            end

            print(tostring(player), region)
        end
    else
        p("ERROR", err)
    end
end

test()

timer.setInterval(1000, function()
    coroutine.wrap(test)()
end)
