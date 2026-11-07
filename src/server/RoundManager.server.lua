--[[
	RoundManager — server-authoritative Neon Sky Maze round loop.

	Phases: Intermission → Generating → Countdown → Racing → Results → …
	Mid-joiners wait in the lobby until the next intermission/race cycle.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ServerFolder = script.Parent
local WorldSetup = require(ServerFolder:WaitForChild("WorldSetup"))
local MazeGenerator = require(ServerFolder:WaitForChild("MazeGenerator"))
local PowerupManager = require(ServerFolder:WaitForChild("PowerupManager"))

WorldSetup.Init()
Remotes.Init()
PowerupManager.Init()

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local Phase = {
	Intermission = "Intermission",
	Generating = "Generating",
	Countdown = "Countdown",
	Racing = "Racing",
	Results = "Results",
}

local currentPhase = Phase.Intermission
local phaseEndsAt = os.clock() + Config.INTERMISSION_DURATION
local raceStartedAt: number? = nil
local currentMaze = nil :: any
local placements: { { Player: Player, Name: string, UserId: number, Time: number, Place: number } } = {}
local finishedSet: { [Player]: boolean } = {}
local raceParticipants: { [Player]: boolean } = {} -- who was teleported into this race
local spectateTargets: { [Player]: number } = {} -- viewer → target userId
local goalConnections: { RBXScriptConnection } = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function now(): number
	return os.clock()
end

local function fireRoundState(extra: { [string]: any }?)
	local payload = {
		Phase = currentPhase,
		EndsAt = phaseEndsAt,
		ServerTime = now(),
		RaceStartedAt = raceStartedAt,
		PlacementCount = #placements,
	}
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	Remotes.Event("RoundStateChanged"):FireAllClients(payload)
end

local function notifyAll(message: string, kind: string?, duration: number?)
	Remotes.Event("Notification"):FireAllClients({
		Message = message,
		Kind = kind or "info",
		Duration = duration or 2.5,
	})
end

local function notifyPlayer(player: Player, message: string, kind: string?, duration: number?)
	Remotes.Event("Notification"):FireClient(player, {
		Message = message,
		Kind = kind or "info",
		Duration = duration or 2.5,
	})
end

local function getHumanoidRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function teleportTo(player: Player, position: Vector3)
	local root = getHumanoidRoot(player)
	if root then
		root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function teleportToLobby(player: Player)
	teleportTo(player, Config.LOBBY_SPAWN + Vector3.new(math.random(-8, 8), 0, math.random(-6, 6)))
end

local function setFrozen(player: Player, frozen: boolean)
	local humanoid = getHumanoid(player)
	local root = getHumanoidRoot(player)
	if humanoid then
		if frozen then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		else
			humanoid.WalkSpeed = Config.DEFAULT_WALK_SPEED
			humanoid.UseJumpPower = true
			humanoid.JumpPower = Config.DEFAULT_JUMP_POWER
		end
	end
	if root then
		root.Anchored = frozen
	end
	Remotes.Event("FreezeState"):FireClient(player, frozen)
end

local function buildLeaderboardPayload()
	local rows = {}
	-- Finished placements first
	for _, entry in ipairs(placements) do
		table.insert(rows, {
			UserId = entry.UserId,
			Name = entry.Name,
			Time = entry.Time,
			Status = "Finished",
			Place = entry.Place,
		})
	end
	-- Racing / waiting
	for player in pairs(raceParticipants) do
		if player.Parent and not finishedSet[player] then
			table.insert(rows, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Time = if raceStartedAt then now() - raceStartedAt else 0,
				Status = if currentPhase == Phase.Racing then "Racing" else currentPhase,
				Place = nil,
			})
		end
	end
	-- Lobby / mid-join
	for _, player in ipairs(Players:GetPlayers()) do
		if not raceParticipants[player] then
			table.insert(rows, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Time = 0,
				Status = "Lobby",
				Place = nil,
			})
		end
	end
	return rows
end

local function broadcastLeaderboard()
	Remotes.Event("LeaderboardUpdate"):FireAllClients(buildLeaderboardPayload())
end

local function disconnectGoal()
	for _, conn in ipairs(goalConnections) do
		conn:Disconnect()
	end
	table.clear(goalConnections)
end

local function registerFinish(player: Player)
	if finishedSet[player] then
		return
	end
	if currentPhase ~= Phase.Racing then
		return
	end
	if not raceParticipants[player] then
		return
	end
	if not raceStartedAt then
		return
	end

	finishedSet[player] = true
	local finishTime = now() - raceStartedAt
	local place = #placements + 1
	table.insert(placements, {
		Player = player,
		Name = player.DisplayName,
		UserId = player.UserId,
		Time = finishTime,
		Place = place,
	})

	PowerupManager.MarkFinished(player)
	Remotes.Event("PlayerFinished"):FireAllClients({
		UserId = player.UserId,
		Name = player.DisplayName,
		Place = place,
		Time = finishTime,
	})
	notifyAll(("%s finished #%d (%.2fs)"):format(player.DisplayName, place, finishTime), "success", 3)
	broadcastLeaderboard()

	-- Enable spectate for early finishers
	Remotes.Event("SpectateState"):FireClient(player, { Enabled = true })

	-- First place starts the post-win continuation clock
	if place == 1 then
		phaseEndsAt = now() + Config.POST_WIN_CONTINUE
		fireRoundState({ FirstPlace = player.DisplayName, FirstTime = finishTime })
		notifyAll("First place! Race ends in " .. Config.POST_WIN_CONTINUE .. "s", "warn", 3)
	end

	-- Everyone finished?
	local remaining = 0
	for p in pairs(raceParticipants) do
		if p.Parent and not finishedSet[p] then
			remaining += 1
		end
	end
	if remaining == 0 then
		phaseEndsAt = now() -- end race ASAP; loop will enter Results
	end
end

local function hookGoal(maze)
	disconnectGoal()
	local goalPart = maze.GoalPart
	local conn = goalPart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			registerFinish(player)
		end
	end)
	table.insert(goalConnections, conn)

	-- Also listen via CollectionService tagged goal parts
	for _, part in ipairs(CollectionService:GetTagged(Config.TAG_GOAL)) do
		if part:IsA("BasePart") and part ~= goalPart then
			local c = part.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					registerFinish(player)
				end
			end)
			table.insert(goalConnections, c)
		end
	end
end

--------------------------------------------------------------------------------
-- Phase transitions
--------------------------------------------------------------------------------

local function enterIntermission()
	currentPhase = Phase.Intermission
	phaseEndsAt = now() + Config.INTERMISSION_DURATION
	raceStartedAt = nil
	placements = {}
	finishedSet = {}
	raceParticipants = {}
	disconnectGoal()
	PowerupManager.Clear()
	PowerupManager.ResetAll()
	MazeGenerator.Clear()
	currentMaze = nil

	for _, player in ipairs(Players:GetPlayers()) do
		setFrozen(player, false)
		PowerupManager.ResetPlayer(player)
		teleportToLobby(player)
		Remotes.Event("SpectateState"):FireClient(player, { Enabled = false })
		Remotes.Event("GoalCompass"):FireClient(player, { Enabled = false })
	end

	fireRoundState()
	broadcastLeaderboard()
	notifyAll("Intermission — next maze soon!", "info", 3)
end

local function enterGenerating()
	currentPhase = Phase.Generating
	phaseEndsAt = now() + 3
	fireRoundState()
	notifyAll("Generating neon maze…", "info", 2)

	currentMaze = MazeGenerator.Generate()
	PowerupManager.SpawnForMaze(currentMaze)
	hookGoal(currentMaze)

	-- Teleport racers to start with small spread
	local racers = Players:GetPlayers()
	for i, player in ipairs(racers) do
		raceParticipants[player] = true
		finishedSet[player] = nil
		PowerupManager.ResetPlayer(player)
		local offset = Vector3.new(((i - 1) % 3) - 1, 0, math.floor((i - 1) / 3) * 2)
		teleportTo(player, currentMaze.StartWorld + offset)
		setFrozen(player, true)
		Remotes.Event("SpectateState"):FireClient(player, { Enabled = false })
	end

	broadcastLeaderboard()
end

local function enterCountdown()
	currentPhase = Phase.Countdown
	phaseEndsAt = now() + Config.COUNTDOWN_DURATION
	for player in pairs(raceParticipants) do
		if player.Parent then
			setFrozen(player, true)
		end
	end
	fireRoundState()
	broadcastLeaderboard()
end

local function enterRacing()
	currentPhase = Phase.Racing
	raceStartedAt = now()
	phaseEndsAt = now() + 600 -- soft cap; normally ends via first+20 or all finish
	PowerupManager.SetCollecting(true)

	for player in pairs(raceParticipants) do
		if player.Parent then
			setFrozen(player, false)
		end
	end

	fireRoundState()
	broadcastLeaderboard()
	notifyAll("GO!", "success", 1.5)
end

local function enterResults()
	currentPhase = Phase.Results
	phaseEndsAt = now() + Config.RESULTS_DURATION
	PowerupManager.SetCollecting(false)

	local results = {}
	for _, entry in ipairs(placements) do
		table.insert(results, {
			Place = entry.Place,
			Name = entry.Name,
			UserId = entry.UserId,
			Time = entry.Time,
		})
	end

	Remotes.Event("ResultsShow"):FireAllClients({
		Placements = results,
		Duration = Config.RESULTS_DURATION,
	})
	fireRoundState({ Placements = results })
	broadcastLeaderboard()

	for _, player in ipairs(Players:GetPlayers()) do
		setFrozen(player, false)
		Remotes.Event("SpectateState"):FireClient(player, { Enabled = false })
	end
end

--------------------------------------------------------------------------------
-- Spectate requests
--------------------------------------------------------------------------------

Remotes.Event("RequestSpectate").OnServerEvent:Connect(function(player, action)
	if typeof(action) ~= "string" then
		return
	end
	if not finishedSet[player] and currentPhase == Phase.Racing then
		return -- only finishers spectate during race
	end
	if action == "stop" then
		spectateTargets[player] = nil
		Remotes.Event("SpectateState"):FireClient(player, { Enabled = false })
		return
	end

	local candidates = {}
	for p in pairs(raceParticipants) do
		if p.Parent and not finishedSet[p] then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return
	end

	table.sort(candidates, function(a, b)
		return a.UserId < b.UserId
	end)

	local currentId = spectateTargets[player]
	local index = 1
	if currentId then
		for i, p in ipairs(candidates) do
			if p.UserId == currentId then
				index = i
				break
			end
		end
	end
	if action == "next" then
		index = (index % #candidates) + 1
	elseif action == "prev" then
		index = index - 1
		if index < 1 then
			index = #candidates
		end
	end
	local target = candidates[index]
	spectateTargets[player] = target.UserId
	Remotes.Event("SpectateState"):FireClient(player, {
		Enabled = true,
		TargetUserId = target.UserId,
		TargetName = target.DisplayName,
	})
end)

--------------------------------------------------------------------------------
-- Player lifecycle
--------------------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	PowerupManager.OnCharacterAdded(player, character)
	task.defer(function()
		if currentPhase == Phase.Intermission or currentPhase == Phase.Results or currentPhase == Phase.Generating then
			teleportToLobby(player)
			setFrozen(player, false)
		elseif currentPhase == Phase.Countdown then
			if raceParticipants[player] and currentMaze then
				teleportTo(player, currentMaze.StartWorld)
				setFrozen(player, true)
			else
				teleportToLobby(player)
			end
		elseif currentPhase == Phase.Racing then
			-- Mid-join: stay in lobby until next round
			if not raceParticipants[player] then
				teleportToLobby(player)
				setFrozen(player, false)
				notifyPlayer(player, "Joined mid-round — wait for the next race!", "info", 4)
			elseif finishedSet[player] then
				teleportToLobby(player)
			elseif currentMaze then
				teleportTo(player, currentMaze.StartWorld)
				setFrozen(player, false)
			end
		end
		fireRoundState()
		broadcastLeaderboard()
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	task.defer(function()
		fireRoundState()
		broadcastLeaderboard()
		if currentPhase == Phase.Racing or currentPhase == Phase.Countdown then
			notifyPlayer(player, "Mid-join — you'll race next round.", "info", 4)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	raceParticipants[player] = nil
	finishedSet[player] = nil
	spectateTargets[player] = nil
	PowerupManager.OnPlayerRemoving(player)
	-- Strip from placements display is fine to keep historical times
	broadcastLeaderboard()
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

--------------------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------------------

local function waitForPlayers(): boolean
	if #Players:GetPlayers() >= Config.MIN_PLAYERS_TO_START then
		return true
	end
	return false
end

-- Periodic leaderboard during race
task.spawn(function()
	while true do
		task.wait(0.5)
		if currentPhase == Phase.Racing or currentPhase == Phase.Countdown then
			broadcastLeaderboard()
		end
	end
end)

print("[NeonSkyMaze] RoundManager online")

enterIntermission()

while true do
	if currentPhase == Phase.Intermission then
		while now() < phaseEndsAt do
			if not waitForPlayers() then
				phaseEndsAt = now() + Config.INTERMISSION_DURATION
				fireRoundState({ WaitingForPlayers = true })
			end
			task.wait(0.25)
		end
		if waitForPlayers() then
			enterGenerating()
			task.wait(1.25) -- let clients see generating + maze stream in
			enterCountdown()
		else
			enterIntermission()
		end
	elseif currentPhase == Phase.Countdown then
		while now() < phaseEndsAt do
			task.wait(0.1)
		end
		enterRacing()
	elseif currentPhase == Phase.Racing then
		while now() < phaseEndsAt do
			task.wait(0.1)
			-- Soft end if somehow no participants left
			local alive = 0
			for p in pairs(raceParticipants) do
				if p.Parent then
					alive += 1
				end
			end
			if alive == 0 then
				break
			end
		end
		enterResults()
	elseif currentPhase == Phase.Results then
		while now() < phaseEndsAt do
			task.wait(0.2)
		end
		enterIntermission()
	else
		enterIntermission()
	end
end
