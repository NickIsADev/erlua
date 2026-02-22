local erlua = require("erlua")
local secrets = require("secrets")
local API = erlua.API()

for i = 1, 5 do
    local server, err = API:sendServerCommand(secrets.key, "pm hi")
    if server then
        p(i, server)
    else
        print("FAILED: " .. err)
    end
end
