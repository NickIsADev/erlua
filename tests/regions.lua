local erlua = require("erlua")
local Location = erlua.Location
local Region = erlua.Region

local function loc(x, z)
    return Location({
        LocationX = x,
        LocationZ = z
    })
end

local spawn = Region({
    loc(0, 0),
    loc(0, 5),
    loc(5, 0),
    loc(5, 5)
})

for x = 0, 6 do
    for z = 0, 6 do
        p(x, z, spawn:contains(loc(x, z)))
    end
end