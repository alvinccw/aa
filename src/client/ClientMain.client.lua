--[[
	ClientMain — wires remotes → UI / effects / spectate for Neon Sky Maze.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientFolder = script.Parent
local GameUI = require(ClientFolder:WaitForChild("GameUI"))
local Effects = require(ClientFolder:WaitForChild("Effects"))
local Spectate = require(ClientFolder:WaitForChild("Spectate"))

Remotes.Init()
Effects.Init()
GameUI.Init()

local player = Players.LocalPlayer

local phase = "Intermission"
local phaseEndsAt = os.clock() + 28
local serverOffset = 0 -- serverNow - localNow approximation via payload.ServerTime
local raceStartedAt: number? = nil
local lastCountdownSecond: number? = nil
local activePowerups: { any } = {}

local function localNow(): number
	return os.clock()
end

local function serverNow(): number
	return localNow() + serverOffset
end

Spectate.Init(Remotes.Event("RequestSpectate"), function(text, visible)
	GameUI.SetSpectateHint(text, visible)
end)

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

Remotes.Event("RoundStateChanged").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	phase = payload.Phase or phase
	if typeof(payload.ServerTime) == "number" then
		serverOffset = payload.ServerTime - localNow()
	end
	if typeof(payload.EndsAt) == "number" then
		phaseEndsAt = payload.EndsAt
	end
	raceStartedAt = payload.RaceStartedAt

	if phase ~= "Results" then
		GameUI.HideResults()
	end
	if phase == "Intermission" then
		Spectate.SetEnabled(false)
		Effects.SetCompass(false)
		lastCountdownSecond = nil
	end
end)

Remotes.Event("LeaderboardUpdate").OnClientEvent:Connect(function(rows)
	if typeof(rows) == "table" then
		GameUI.UpdateLeaderboard(rows)
	end
end)

Remotes.Event("Notification").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	GameUI.Toast(payload.Message or "", payload.Kind, payload.Duration)
	Effects.Play("Notify")
end)

Remotes.Event("PowerupCollected").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local color = payload.Color or Color3.fromRGB(0, 255, 255)
	Effects.CollectBurst(color)
	Effects.ScreenPulse(color)
	GameUI.Toast((payload.Icon or "•") .. " " .. (payload.DisplayName or "Powerup"), "powerup", 2)
end)

Remotes.Event("PowerupExpired").OnClientEvent:Connect(function(_id)
	-- Active list refresh comes via PowerupActiveUpdate
end)

Remotes.Event("PowerupActiveUpdate").OnClientEvent:Connect(function(list)
	if typeof(list) == "table" then
		activePowerups = list
		GameUI.UpdatePowerups(list)
	end
end)

Remotes.Event("ResultsShow").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	GameUI.ShowResults(payload.Placements or {})
	Effects.Play("Win")
end)

Remotes.Event("PlayerFinished").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.UserId == player.UserId then
		Effects.WinBurst()
		Effects.ScreenPulse(Color3.fromRGB(80, 255, 160))
	end
end)

Remotes.Event("GoalCompass").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	Effects.SetCompass(payload.Enabled == true, payload.GoalPosition)
end)

Remotes.Event("SpectateState").OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	Spectate.SetEnabled(payload.Enabled == true, payload.TargetUserId, payload.TargetName)
end)

Remotes.Event("FreezeState").OnClientEvent:Connect(function(_frozen)
	-- Anchoring is handled server-side; client can add vignette later if desired.
end)

--------------------------------------------------------------------------------
-- Frame loop: timers + countdown flashes + powerup remaining
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local remaining = phaseEndsAt - serverNow()
	local raceTime = nil
	if phase == "Racing" and typeof(raceStartedAt) == "number" then
		raceTime = serverNow() - raceStartedAt
	end
	GameUI.SetPhase(phase, remaining, raceTime)

	if phase == "Countdown" then
		local sec = math.max(0, math.ceil(remaining))
		if lastCountdownSecond ~= sec then
			lastCountdownSecond = sec
			if sec > 0 then
				GameUI.FlashCountdown(sec)
				Effects.Play("Countdown")
			else
				GameUI.FlashCountdown(0)
				Effects.Play("Go")
			end
		end
	end

	-- Tick down local powerup chips between server updates
	if #activePowerups > 0 then
		local changed = false
		local nextList = {}
		for _, entry in ipairs(activePowerups) do
			if typeof(entry.EndsAt) == "number" then
				entry.Remaining = math.max(0, entry.EndsAt - serverNow())
				if entry.Remaining > 0 then
					table.insert(nextList, entry)
				else
					changed = true
				end
			else
				table.insert(nextList, entry)
			end
		end
		if changed or #nextList > 0 then
			activePowerups = nextList
			GameUI.UpdatePowerups(activePowerups)
		end
	end
end)

print("[NeonSkyMaze] Client ready")
