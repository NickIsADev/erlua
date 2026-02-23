local Region = require("structures/Region")
local Location = require("structures/Location")

return {
    Region(
        "Spawn",
        {
            Location({LocationX = 760, LocationZ = 2520}),
            Location({LocationX = 900, LocationZ = 2520}),
            Location({LocationX = 900, LocationZ = 2420}),
            Location({LocationX = 760, LocationZ = 2420})
        }
    ),
    Region(
        "Fountain",
        {
            Location({LocationX = 700, LocationZ = 2175}),
            Location({LocationX = 815, LocationZ = 2175}),
            Location({LocationX = 815, LocationZ = 2000}),
            Location({LocationX = 700, LocationZ = 2000})
        }
    )  -- TODO: Add more regions
}
