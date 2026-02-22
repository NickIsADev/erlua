local fs = require("fs")

local BLACK   = 30
local RED     = 31
local GREEN   = 32
local YELLOW  = 33
local BLUE    = 34
local MAGENTA = 35
local CYAN    = 36
local WHITE   = 37

local config = {
	{" ERROR   ", RED},
	{" WARNING ", YELLOW},
	{" INFO    ", GREEN},
	{" DEBUG   ", CYAN},
}

do
	local bold = 1
	for _, v in ipairs(config) do
		v[3] = string.format("\27[%i;%im%s\27[0m", bold, v[2], v[1])
	end
end

local Logger = require("class")("Logger", nil)

function Logger:__init(level, dateTime, file)
	self._level = level
	self._dateTime = dateTime
	self._file = file and fs.openSync(file, "a")
end

function Logger:log(level, msg, ...)
	if self._level < level then return end

	local tag = config[level]
	if not tag then return end

	msg = string.format(msg, ...)

	local d = os.date(self._dateTime)
	if self._file then
		fs.writeSync(self._file, -1, string.format("%s  %s %s\n", d, tag[1], msg))
	end
	process.stdout.handle:write(string.format("%s  %s %s\n", d, tag[3], msg))

	return msg
end

return Logger
