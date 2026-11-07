--[[
	Bootstrap Script — ensures WorldSetup runs even if RoundManager loads later.
]]

local WorldSetup = require(script.Parent:WaitForChild("WorldSetup"))
WorldSetup.Init()
