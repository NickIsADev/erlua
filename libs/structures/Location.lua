local Location, get = require("class")("Location")

function Location:__init(data)
    self._x = data.LocationX
    self._z = data.LocationZ
    self._postal_code = data.PostalCode
    self._street_name = data.StreetName
    self._building_number = data.BuildingNumber
end

function Location:__tostring()
    return string.format("%d %s, Postal Code %d (%d, %d)", self._building_number, self._street_name, self._postal_code, self._x, self._z)
end

function Location:distance(other)
    local dx = self._x - other._x
    local dz = self._z - other._z
    return math.sqrt(dx * dx + dz * dz)
end

function get.x(self)
    return self._x
end

function get.z(self)
    return self._z
end

function get.postalCode(self)
    return self._postal_code
end

function get.streetName(self)
    return self._street_name
end

function get.buildingNumber(self)
    return self._building_number
end

return Location