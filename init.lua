local erlua = {
    GlobalKey = nil,
    ServerKey = nil
}

local http = require("coro-http")
local json = require("json")
local timer = require("timer")

local RateLimits = {}

--[[ Utility Functions ]] --

local function log(text, mode)
    mode = mode or "info"

    local date = os.date("%x @ %I:%M:%S%p", os.time())

    if mode == "success" then
        print(date .. " | \27[32m\27[1m[ERLUA]\27[0m | " .. text)
    elseif mode == "warning" then
        print(date .. " | \27[33m\27[1m[ERLUA]\27[0m | " .. text)
    elseif mode == "error" then
        print(date .. " | \27[31m\27[1m[ERLUA]\27[0m | " .. text)
    elseif mode == "info" then
        print(date .. " | \27[35m\27[1m[ERLUA]\27[0m | " .. text)
    end
end

local function getHeader(headers, name)
    if (not headers) or (type(headers) ~= "table") or (not name) or (name == "") then
        return
    end

    for _, header in pairs(headers) do
        if (type(header) == "table") and (header[1]:lower() == name:lower()) then
            return header[2]
        end
    end
end

function split(str, delim)
    local ret = {}
    if not str then
        return ret
    end
    if not delim or delim == '' then
        for c in string.gmatch(str, '.') do
            table.insert(ret, c)
        end
        return ret
    end
    local n = 1
    while true do
        local i, j = string.find(str, delim, n)
        if not i then break end
        table.insert(ret, string.sub(str, n, i - 1))
        n = j + 1
    end
    table.insert(ret, string.sub(str, n))
    return ret
end

local function Error(code, message)
    log(message, "error")
    return { code = code, message = message }
end

local function RateLimited(bucket)
    if (bucket) and (RateLimits[bucket]) and (RateLimits[bucket].remaining) and (RateLimits[bucket].reset) and (os.time() < RateLimits[bucket].reset) and (RateLimits[bucket].remaining < 1) then
        return true
    else
        return false
    end
end

local function updateRateLimit(result, bucket)
    local rateLimitBucket = bucket or getHeader(result, "X-RateLimit-Bucket")
    local rateLimitRemaining = getHeader(result, "X-RateLimit-Remaining")
    local rateLimitReset = getHeader(result, "X-RateLimit-Reset")

    if rateLimitBucket and rateLimitRemaining and rateLimitReset and tonumber(rateLimitRemaining) and tonumber(rateLimitReset) then
        RateLimits[rateLimitBucket] = {
            remaining = tonumber(rateLimitRemaining),
            reset = tonumber(rateLimitReset)
        }
    end
end

local function getBucket(method, serverkey, globalkey)
    local bucket

    if method == "POST" then
        bucket = "commmand-" .. (serverkey or erlua.ServerKey)
    elseif globalkey or erlua.GlobalKey then
        bucket = "global"
    else
        bucket = "unauthenticated-global"
    end

    return bucket
end

-- [[ ERLua Functions ]] --

function erlua:SetGlobalKey(gk)
    erlua.GlobalKey = gk
    log("Set global key to [HIDDEN].", "info")
    return erlua
end

function erlua:SetServerKey(sk)
    erlua.ServerKey = sk
    log("Set server key to [HIDDEN].", "info")
    return erlua
end

function erlua:request(method, endpoint, body, serverkey, globalkey)
    local url = "https://api.policeroleplay.community/v1/" .. endpoint
    local headers = {}

    if (not serverkey) and (not erlua.ServerKey) then
        return false, Error(400, "A server key was not provided to " .. method .. " /" .. endpoint .. ".")
    else
        table.insert(headers, { "Server-Key", serverkey or erlua.ServerKey })
    end

    local bucket = getBucket(method, serverkey, globalkey)

    if RateLimited(bucket) then
        return false, Error(4001, "The resource is being ratelimited.")
    end

    if globalkey or erlua.GlobalKey then
        table.insert(headers, { "Authorization", globalkey or erlua.GlobalKey })
    end

    if method == "POST" then
        table.insert(headers, { "Content-Type", "application/json" })
    end

    if type(body) == "table" then
        local success, encoded = pcall(json.encode, body)

        if not success then
            return false, Error(500, "Body could not be encoded.")
        else
            body = encoded
        end
    end

    local result, response = http.request(method, url, headers, body)

    if type(response) == "string" then
        local success, decoded = pcall(json.decode, response)

        if not success then
            return false, Error(500, "Response could not be decoded.")
        else
            response = decoded
        end
    end

    updateRateLimit(result, bucket)

    if result.code == 200 then
        return true, response
    elseif result.code == 404 then
        return false, Error(404, "Endpoint /" .. endpoint .. " was not found. (" .. url .. ")")
    elseif response and response.code then
        return false, response
    elseif result.code and result.reason then
        return false, Error(result.code, result.reason)
    else
        return false, Error(444, "The PRC API did not respond.")
    end
end

-- [[ Endpoint Functions ]] --

function erlua.Server(serverKey, globalKey)
    return erlua:request("GET", "server", nil, serverKey, globalKey)
end

function erlua.Players(serverKey, globalKey)
    local players = {}

    local success, response = erlua:request("GET", "server/players", nil, serverKey, globalKey)

    if not success then
        return false, response
    end

    for _, player in pairs(response) do
        if player.Player then
            table.insert(players, {
                Name = split(player.Player, ":")[1],
                ID = split(player.Player, ":")[2],
                Player = player.Player,
                Permission = player.Permission,
                Callsign = player.Callsign,
                Team = player.Team
            })
        end
    end

    return true, players
end

function erlua.Vehicles(serverKey, globalKey)
    return erlua:request("GET", "server/vehicles", nil, serverKey, globalKey)
end

function erlua.PlayerLogs(serverKey, globalKey)
    local success, response = erlua:request("GET", "server/joinlogs", nil, serverKey, globalKey)

    if not success then
        return false, response
    end

    return true, table.sort(response, function(a, b)
        if (not a.Timestamp) or (not b.Timestamp) then
            return false
        else
            return a.Timestamp > b.Timestamp
        end
    end)
end

function erlua.KillLogs(serverKey, globalKey)
    local success, response = erlua:request("GET", "server/killlogs", nil, serverKey, globalKey)

    if not success then
        return false, response
    end

    return true, table.sort(response, function(a, b)
        if (not a.Timestamp) or (not b.Timestamp) then
            return false
        else
            return a.Timestamp > b.Timestamp
        end
    end)
end

function erlua.CommandLogs(serverKey, globalKey)
    local success, response = erlua:request("GET", "server/commandlogs", nil, serverKey, globalKey)

    if not success then
        return false, response
    end

    return true, table.sort(response, function(a, b)
        if (not a.Timestamp) or (not b.Timestamp) then
            return false
        else
            return a.Timestamp > b.Timestamp
        end
    end)
end

function erlua.ModCalls(serverKey, globalKey)
    local success, response = erlua:request("GET", "server/modcalls", nil, serverKey, globalKey)

    if not success then
        return false, response
    end

    return true, table.sort(response, function(a, b)
        if (not a.Timestamp) or (not b.Timestamp) then
            return false
        else
            return a.Timestamp > b.Timestamp
        end
    end)
end

function erlua.Bans(serverKey, globalKey)
    return erlua:request("GET", "server/bans", nil, serverKey, globalKey)
end

function erlua.Queue(serverKey, globalKey)
    return erlua:request("GET", "server/queue", nil, serverKey, globalKey)
end

-- [[ Custom Functions ]] --

function erlua.Staff(serverKey, globalKey, preloadPlayers)
    local staff = {}

    local success, players

    if preloadPlayers then
        success = true
        players = preloadPlayers
    else
        success, players = erlua.Players(serverKey, globalKey)
    end

    if not players then
        return false, players
    end

    for _, player in pairs(players) do
        if (player.Permission) and (player.Permission ~= "Normal") then
            table.insert(staff, player)
        end
    end

    return true, staff
end

function erlua.Team(teamName, serverKey, globalKey, preloadPlayers)
    if (not teamName) or (not table.find(teamName, { "civilian", "police", "sheriff", "fire", "dot", "jail" })) then
        return
            Error(400, "An invalid team name ('" .. tostring(teamName) .. "') was provided.")
    end

    local team = {}

    local success, players

    if preloadPlayers then
        success = true
        players = preloadPlayers
    else
        success, players = erlua.Players(serverKey, globalKey)
    end


    if not players then
        return false, players
    end

    for _, player in pairs(players) do
        if (player.Team) and (player.Team:lower() == teamName:lower()) then
            table.insert(team, player)
        end
    end

    return true, team
end

function erlua.TrollUsernames(serverKey, globalKey, preloadPlayers)
    local trolls = {}

    local success, players

    if preloadPlayers then
        success = true
        players = preloadPlayers
    else
        success, players = erlua.Players(serverKey, globalKey)
    end


    if not players then
        return false, players
    end

    for _, player in pairs(players) do
        if (player.Player) and ((player.Player:sub(1, 3):lower() == "all") or (player.Player:sub(1, 6):lower() == "others") or (player.Player:find("lI") or (player.Player:find("Il")))) then
            table.insert(trolls, player)
        end
    end

    return true, trolls
end

function erlua.Command(command, serverKey, globalKey)
    return erlua:request("POST", "server/command", { command = command }, serverKey, globalKey)
end

return erlua
