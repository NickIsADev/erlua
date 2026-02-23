local Region, get = require("class")("Region")

function Region:__init(name, points)
    self._name = name
    self._points = points

    local area = 0
    local n = #points
    for i = 1, n do
        local j = (i % n) + 1
        area = area + points[i].x * points[j].z
        area = area - points[j].x * points[i].z
    end
    self._area = math.abs(area) / 2
end

function Region:contains(location)
    local x, z = location._x, location._z
    local inside = false
    local n = #self._points
    local j = n
    for i = 1, n do
        local xi, zi = self._points[i].x, self._points[i].z
        local xj, zj = self._points[j].x, self._points[j].z
        if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
            inside = not inside
        end
        j = i
    end
    return inside
end

function get.name(self)
    return self._name
end

function get.area(self)
    return self._area
end

return Region
