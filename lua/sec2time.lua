#!/usr/bin/env lua

if arg[1] == nil then os.execute("log-error 'Seconds must be provided'") end
local isShort = arg[2] ~= nil and (arg[2] == '-s' or arg[2] == '--short')

local ONE_DAY = 86400
local ONE_HOUR = 3600
local ONE_MINUTE = 60

local result = ""
local seconds = tonumber(arg[1])
if seconds == nil then os.execute("log-error 'seconds must be a number'") end

seconds = math.floor(seconds or 0)

local function getSuffix(suffixes, unit)
  local time = math.floor(seconds / unit)

  if time > 0 then
    local suffix
    if isShort then
      suffix = suffixes.short
    elseif time == 1 then
      suffix = suffixes.single
    else
      suffix = suffixes.multiple
    end

    seconds = seconds % unit
    return string.format("%d%s", time, suffix)
  end

  return nil
end

local days = getSuffix(
  {
    short = 'd',
    single = ' day',
    multiple = ' days'
  },
  ONE_DAY
)

local hours = getSuffix(
  {
    short = 'h',
    single = ' hour',
    multiple = ' hours'
  },
  ONE_HOUR
)

local minutes = getSuffix(
  {
    short = 'm',
    single = ' minute',
    multiple = ' minutes'
  },
  ONE_MINUTE
)

local secondsFormatted = getSuffix(
  {
    short = 's',
    single = ' second',
    multiple = ' seconds'
  },
  1
)

local temp = { days, hours, minutes, secondsFormatted }

---@type string[]
local output = {}

for _, value in ipairs(temp) do
  if value ~= nil then
    table.insert(output, value)
  end
end

local len = #output
for i = 1, len do
  result = result .. output[i]
  if i < len and isShort then
    result = result .. ' '
  elseif i == len - 1 then
    result = result .. ' and '
  elseif i <= len - 2 then
    result = result .. ', '
  end
end

print(result)
