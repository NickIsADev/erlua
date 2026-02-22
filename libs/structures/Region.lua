local Region = require("class")("Region")

function Region:__init(corners)
    assert(corners and #corners == 4, "exactly 4 Locations must be provided when creating a Region")
    self._min_x, self._max_x = 0, 0
    self._min_z, self._max_z = 0, 0

    for _, corner in pairs(corners) do
        if corner._x < self._min_x then
            self._min_x = corner._x
        elseif corner._x > self._max_x then
            self._max_x = corner._x
        end

        if corner._z < self._min_z then
            self._min_z = corner._z
        elseif corner._z > self._max_z then
            self._max_z = corner._z
        end
    end
end

function Region:contains(location)
    return
        location._x >= self._min_x and 
        location._x <= self._max_x and
        location._z >= self._min_z and
        location._z <= self._max_z
end

return Region
