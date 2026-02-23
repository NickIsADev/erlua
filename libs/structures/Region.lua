local Region, get = require("class")("Region")

function Region:__init(name, corners)
    assert(corners and #corners == 4, "exactly 4 Locations must be provided when creating a Region")

    self._name = name
    self._min_x, self._max_x = nil, nil
    self._min_z, self._max_z = nil, nil

    for _, corner in pairs(corners) do
        if (not self._min_x) or corner._x < self._min_x then
            self._min_x = corner._x
        elseif (not self._max_x) or corner._x > self._max_x then
            self._max_x = corner._x
        end

        if (not self._min_z) or corner._z < self._min_z then
            self._min_z = corner._z
        elseif (not self._max_z) or corner._z > self._max_z then
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

function get.name(self)
    return self._name
end

function get.minX(self)
    return self._min_x
end

function get.maxX(self)
    return self._max_x
end

function get.minZ(self)
    return self._min_z
end

function get.maxZ(self)
    return self._max_z
end

return Region
