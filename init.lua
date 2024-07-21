local erlua = {}
local http = require("coro-http")
local json = require("json")
local gk = nil
local ak = nil

function erlua:SetGlobalKey(ngk)
	gk = ngk
	print("[ERLua] | Set global key to " .. gk)
	return erlua
end

function erlua:SetAPIKey(nak)
	ak = nak
	print("[ERLua] | Set API key to " .. ak)
	return erlua
end

local function find(tbl, tofind)
	for i, v in pairs(tbl) do
		if v == tofind then return v end
	end
	return nil
end

local function split(str, delim)
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
		local i, j = find(str, delim, n)
		if not i then break end
		table.insert(ret, sub(str, n, i - 1))
		n = j + 1
	end
	table.insert(ret, sub(str, n))
	return ret
end

local function getBody(endpoint, headers)
    local url = "https://api.policeroleplay.community/v1/" .. endpoint
    local res, body = http.request("GET", url, headers)
    body = json.decode(body)
    if res.code == 200 then
        return body
    else
        for i, v in pairs(res) do
            if type(v) == "table" then
                if v[1] == "Retry-After" then
                    local start = os.time()
                    local wait = math.floor(v[2] + 0.5)
                    repeat until os.time() >= start + wait
                    return getBody(endpoint, headers)
                end
            end
        end
        return nil, body
    end
end

local function post(endpoint, headers, body)
    local url = "https://api.policeroleplay.community/v1/" .. endpoint
    table.insert(headers, {"Content-Type", "application/json"})
    local res = http.request("POST", url, headers, body)
    for i, v in pairs(res) do
        if type(v) == "table" then
            if v[1] == "Retry-After" then
                local start = os.time()
                local wait = math.floor(v[2] + 0.5)
                repeat until os.time() >= start + wait
                return post(endpoint, headers, body)
            end
        end
    end
    return res
end

local function err(str)
    print("[ERLua] Error | " .. str)
end

function erlua.Server(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server", headers)
    if not body then return res end
    return body
end

function erlua.Players(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return {code = 789, message = "No API Key"}, err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/players", headers)
    if not body then return res end
    local toret = {}
    
    for i, v in pairs(body) do
        table.insert(toret, {
            Name = v.Player:split(":")[1],
            ID = v.Player:split(":")[2],
            Permission = v.Permission,
            Callsign = v.Callsign,
            Team = v.Team
        })
    end

    return toret
end

function erlua.Vehicles(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/vehicles", headers)
    if not body then return res end
    return body
end

function erlua.PlayerLogs(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/joinlogs", headers)
    if not body then return res end
    return body
end

function erlua.KillLogs(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/killlogs", headers)
    if not body then return res end
    return body
end

function erlua.CommandLogs(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/commandlogs", headers)
    if not body then return res end
    return body
end

function erlua.Bans(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/bans", headers)
    if not body then return res end
    return body
end

function erlua.ModCalls(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/modcalls", headers)
    if not body then return res end
    return body
end

function erlua.Queue(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local body, res = getBody("server/queue", headers)
    if not body then return res end
    return body
end

function erlua.Staff(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    local staff = {}
    local players = erlua.Players(apikey, globalkey)
    if players.code then return players end
    for i, v in pairs(players) do
        if v.Permission ~= "Normal" then
            table.insert(staff, v)
        end
    end
    return staff
end

local validTeamNames = {"civilian", "police", "sheriff", "firefighter", "dot"}

function erlua.Team(teamName, apikey, globalkey)
    if not teamName then err("A team name was not provided") return nil end
    if not find(validTeamNames, teamName:lower()) then
        err("Invalid team name: " .. teamName)
        return nil
    end
    apikey = apikey or ak
    globalkey = globalkey or gk
    local team = {}
    local players = erlua.Players(apikey, globalkey)
    if players.code then return players end
    for i, v in pairs(players) do
        if v.Team:lower() == teamName:lower() then
            table.insert(team, v)
        end
    end
    return staff
end


function erlua.TrollUsernames(apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    local trollusers = {}
    local players = erlua.Players(apikey, globalkey)
    if players.code then return players end
    for i, v in pairs(players) do
        if v.Name:lower():sub(1,3) == "all" or v.Name:lower():sub(1,6) == "others" then
            table.insert(trollusers, v)
        end
    end
    return trollusers
end

function erlua.NotInDiscord(guild, apikey, globalkey)
    if not guild then print("[ERLua] | A Guild must be provided as the first parameter to erlua.NotInDiscord().") return nil end
    if (not guild.members) or (type(guild.members) ~= "table") then print("[ERLua] | An invalid guild was provided to erlua.NotInDiscord().") return nil end
    apikey = apikey or ak
    globalkey = globalkey or gk
    local nid = {}
    local players = erlua.Players(apikey, globalkey)
    if players.code then return players end
    for i, v in pairs(players) do
        local ind = false
        for _, member in pairs(guild.members) do
            if member.name:lower():find(v.Name:lower()) then
                ind = true
            end
        end
        if ind == false then
            table.insert(nid, v)
        end
    end
    return nid
end

function erlua.Command(command, apikey, globalkey)
    apikey = apikey or ak
    globalkey = globalkey or gk
    if not apikey then return err("An API Key was not provided.") end
    if not command then return err("A command to run was not provided.") end
    local headers = {
        {"Server-Key", apikey}
    }
    local body = json.encode({command = command})
    print(body)
    if globalkey then table.insert(headers, {"Authorization", globalkey}) end
    local res = post("server/command", headers, body)
    if res.code == 200 then
        return true
    elseif res.code == 500 then
        return false, "An error occurred while attempting to communicate with the Roblox server. Please try again later."
    elseif res.code == 400 then
        return false, "Bad Request **|** This error should not appear; if it does and you are reading this, please submit a bug report."
    elseif res.code == 403 then
        return false, "Unauthorized **|** This error should not appear; if it does and you are reading this, please submit a bug report."
    elseif res.code == 422 then
        return false, "The in-game server has no players in it, and is therefore offline."
    end
end

return erlua