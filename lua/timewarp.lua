#!/usr/bin/env lua

local stationaryTime, travelerTime
local SPEED_OF_LIGHT = 299792458 -- m/s

if not arg[1] then
  io.write("Enter how much passes for normal person: ")
  stationaryTime = io.read("n")
else
  stationaryTime = tonumber(arg[1])
end

if not arg[2] then
  io.write("Enter how much passes for you (traveler): ")
  travelerTime = io.read("n")
else
  travelerTime = tonumber(arg[2])
end

local gamma = stationaryTime / travelerTime
local fraction = math.sqrt(1 - 1 / (gamma ^ 2))
local speed = SPEED_OF_LIGHT * fraction

local travelerHandle = io.popen(string.format("sec2time %d", travelerTime), "r")
local travelerRelativeTime, stationaryRelativeTime
if travelerHandle ~= nil then
  local result = travelerHandle:read("*a") -- read all output
  travelerRelativeTime = tostring(result):gsub("\n", "")
  travelerHandle:close()
end

local stationaryHandle = io.popen(string.format("sec2time %d", stationaryTime), "r")
if stationaryHandle ~= nil then
  local result = stationaryHandle:read("*a") -- read all output
  stationaryRelativeTime = tostring(result):gsub("\n", "")
  stationaryHandle:close()
end


io.write(
  string.format(
    "To make %s feel like %s in normal speed\nThe traveler must move at speed %.2fm/s which is %.4f%% the speed of light\n",
    stationaryRelativeTime, travelerRelativeTime, speed, fraction * 100)
)
