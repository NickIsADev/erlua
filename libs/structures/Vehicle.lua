local Vehicle, get = require("class")("Vehicle")

function Vehicle:__init(server, data)
    self._server = server
    self._name = data.Name

    local make, model, year = data.Name:match("^(%S+)%s+(.+)%s+(%d%d%d%d)$")
    self._make = make
    self._model = model or data.Name
    self._year = tonumber(year)
    
    self._owner = data.Owner
    self._texture = data.Texture
    self._color_hex = data.ColorHex
    self._color_name = data.ColorName
end

function Vehicle:__tostring()
    return string.format("Vehicle: %s", self._name)
end

function get.server(self)
    return self._server
end

function get.name(self)
    return self._name
end

function get.make(self)
    return self._make
end

function get.model(self)
    return self._model
end

function get.year(self)
    return self._year
end

function get.owner(self) -- TODO: Cleanup this temporary solution
    for _, p in pairs(self._server.players) do
        if p.name == self._owner then
            return p
        end
    end
end

function get.livery(self)
    return self._texture
end

function get.color(self)
    return self._colox_name
end

function get.colorHex(self)
    return self._color_hex
end

return Vehicle
