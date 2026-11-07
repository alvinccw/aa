--[[
	PowerupManager — server-authoritative neon powerup spawn + collect + effects.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local PowerupManager = {}

export type MazeRef = {
	Width: number,
	Height: number,
	CellSize: number,
	StartCell: Vector2,
	GoalCell: Vector2,
	GoalWorld: Vector3,
	Folder: Folder,
}

type ActiveEffect = {
	Id: string,
	EndsAt: number,
	Token: number,
}

local activeFolder: Folder? = nil
local mazeRef: MazeRef? = nil
local collectingEnabled = false
local playerEffects: { [Player]: { [string]: ActiveEffect } } = {}
local finishedPlayers: { [Player]: boolean } = {}
local effectTokens: { [Player]: number } = {}
local weightedIds: { string } = {}

local function rebuildWeights()
	table.clear(weightedIds)
	for id, weight in pairs(Config.POWERUP_WEIGHTS) do
		if Config.Powerups[id] then
			for _ = 1, weight do
				table.insert(weightedIds, id)
			end
		end
	end
	if #weightedIds == 0 then
		for id in pairs(Config.Powerups) do
			table.insert(weightedIds, id)
		end
	end
end

local function notify(player: Player, message: string, kind: string?, duration: number?)
	Remotes.Event("Notification"):FireClient(player, {
		Message = message,
		Kind = kind or "info",
		Duration = duration or 2.5,
	})
end

local DISPLAY_FALLBACKS = {
	SpeedTrapVictim = {
		DisplayName = "Slowed",
		Color = Color3.fromRGB(255, 80, 80),
		Icon = "❄",
	},
}

local function pushActiveUpdate(player: Player)
	local list = {}
	local effects = playerEffects[player]
	if effects then
		local clock = os.clock()
		for id, effect in pairs(effects) do
			if effect.EndsAt > clock then
				local def = Config.Powerups[id]
				local fallback = DISPLAY_FALLBACKS[id]
				table.insert(list, {
					Id = id,
					DisplayName = (def and def.DisplayName) or (fallback and fallback.DisplayName) or id,
					EndsAt = effect.EndsAt,
					Color = (def and def.Color) or (fallback and fallback.Color) or Color3.new(1, 1, 1),
					Icon = (def and def.Icon) or (fallback and fallback.Icon) or "•",
					Remaining = effect.EndsAt - clock,
				})
			end
		end
	end
	Remotes.Event("PowerupActiveUpdate"):FireClient(player, list)
end

local function restoreMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.DEFAULT_WALK_SPEED
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.DEFAULT_JUMP_POWER
	end
end

local function setGhost(player: Player, enabled: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = if enabled then Config.COLLISION_GHOST else "Default"
			end)
		end
	end
	-- Highlight for ghost feedback
	local existing = character:FindFirstChild("GhostHighlight")
	if enabled then
		if not existing then
			local hl = Instance.new("Highlight")
			hl.Name = "GhostHighlight"
			hl.FillColor = Color3.fromRGB(200, 160, 255)
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.55
			hl.OutlineTransparency = 0.2
			hl.Parent = character
		end
	elseif existing then
		existing:Destroy()
	end
end

local function applyWalkJump(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local walk = Config.DEFAULT_WALK_SPEED
	local jump = Config.DEFAULT_JUMP_POWER
	local effects = playerEffects[player]
	if effects then
		local now = os.clock()
		-- Speed trap overrides / stacks as min
		local trapped = false
		if effects.SpeedTrapVictim and effects.SpeedTrapVictim.EndsAt > now then
			walk = Config.Powerups.SpeedTrap.SlowWalkSpeed
			trapped = true
		end
		if not trapped then
			if effects.SpeedBoost and effects.SpeedBoost.EndsAt > now then
				walk += Config.Powerups.SpeedBoost.WalkSpeedBonus
			end
			if effects.DoubleBoost and effects.DoubleBoost.EndsAt > now then
				walk += Config.Powerups.DoubleBoost.WalkSpeedBonus
				jump += Config.Powerups.DoubleBoost.JumpPowerBonus
			end
		end
		if effects.SuperJump and effects.SuperJump.EndsAt > now then
			jump += Config.Powerups.SuperJump.JumpPowerBonus
		end
		if effects.DoubleBoost and effects.DoubleBoost.EndsAt > now and trapped then
			-- still allow jump while trapped
			jump += Config.Powerups.DoubleBoost.JumpPowerBonus
		end
	end
	humanoid.WalkSpeed = walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jump
end

local function clearEffect(player: Player, effectId: string)
	local effects = playerEffects[player]
	if not effects or not effects[effectId] then
		return
	end
	effects[effectId] = nil
	if effectId == "GhostMode" then
		setGhost(player, false)
	end
	if effectId == "GoalCompass" then
		Remotes.Event("GoalCompass"):FireClient(player, { Enabled = false })
	end
	Remotes.Event("PowerupExpired"):FireClient(player, effectId)
	applyWalkJump(player)
	pushActiveUpdate(player)
end

local function scheduleExpiry(player: Player, effectId: string, duration: number)
	effectTokens[player] = (effectTokens[player] or 0) + 1
	local token = effectTokens[player]
	local endsAt = os.clock() + duration
	playerEffects[player] = playerEffects[player] or {}
	playerEffects[player][effectId] = { Id = effectId, EndsAt = endsAt, Token = token }

	task.delay(duration, function()
		local effects = playerEffects[player]
		if not effects then
			return
		end
		local effect = effects[effectId]
		if effect and effect.Token == token and effect.EndsAt <= os.clock() + 0.05 then
			clearEffect(player, effectId)
		end
	end)
end

local function applyPowerup(player: Player, powerupId: string)
	local def = Config.Powerups[powerupId]
	if not def then
		return
	end

	if powerupId == "SpeedTrap" then
		-- Slow everyone else currently racing
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and not finishedPlayers[other] then
				scheduleExpiry(other, "SpeedTrapVictim", def.Duration)
				applyWalkJump(other)
				pushActiveUpdate(other)
				notify(other, "You hit a Speed Trap!", "danger", 2.5)
			end
		end
		notify(player, "Speed Trap deployed!", "success", 2)
		Remotes.Event("PowerupCollected"):FireClient(player, {
			Id = powerupId,
			DisplayName = def.DisplayName,
			Duration = def.Duration,
			Color = def.Color,
			Icon = def.Icon,
		})
		pushActiveUpdate(player)
		return
	end

	scheduleExpiry(player, powerupId, def.Duration)

	if powerupId == "GhostMode" then
		setGhost(player, true)
	elseif powerupId == "GoalCompass" then
		local maze = mazeRef
		Remotes.Event("GoalCompass"):FireClient(player, {
			Enabled = true,
			GoalPosition = maze and maze.GoalWorld or Vector3.zero,
			Duration = def.Duration,
		})
	end

	applyWalkJump(player)
	Remotes.Event("PowerupCollected"):FireClient(player, {
		Id = powerupId,
		DisplayName = def.DisplayName,
		Duration = def.Duration,
		Color = def.Color,
		Icon = def.Icon,
	})
	notify(player, def.DisplayName .. "!", "powerup", 2)
	pushActiveUpdate(player)
end

local function createPowerupVisual(parent: Folder, powerupId: string, position: Vector3): BasePart
	local def = Config.Powerups[powerupId]
	local part = Instance.new("Part")
	part.Name = "Powerup_" .. powerupId
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = def.Color
	part.Reflectance = 0.2
	CollectionService:AddTag(part, Config.TAG_POWERUP)
	part:SetAttribute("PowerupId", powerupId)
	part.Parent = parent

	pcall(function()
		part.CollisionGroup = Config.COLLISION_POWERUPS
	end)

	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Brightness = 2.5
	light.Range = 18
	light.Parent = part

	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 18
	particles.Lifetime = NumberRange.new(0.4, 0.9)
	particles.Speed = NumberRange.new(1, 3)
	particles.Size = NumberSequence.new(0.4, 0)
	particles.LightEmission = 1
	particles.Color = ColorSequence.new(def.Color)
	particles.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(70, 70)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = def.Icon
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	-- Idle bob
	task.spawn(function()
		local base = position
		local t0 = os.clock()
		while part.Parent do
			local t = os.clock() - t0
			part.Position = base + Vector3.new(0, math.sin(t * 3) * 0.6, 0)
			part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, t * 2, 0)
			task.wait(0.03)
		end
	end)

	return part
end

local function cellWorld(maze: MazeRef, x: number, y: number): Vector3
	local origin = Config.MAZE_ORIGIN
	return Vector3.new(
		origin.X + (x - 0.5) * maze.CellSize,
		origin.Y + 4,
		origin.Z + (y - 0.5) * maze.CellSize
	)
end

local function distanceCells(a: Vector2, b: Vector2): number
	return math.abs(a.X - b.X) + math.abs(a.Y - b.Y)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PowerupManager.Init()
	rebuildWeights()
	Remotes.Init()
end

function PowerupManager.Clear()
	collectingEnabled = false
	if activeFolder then
		activeFolder:Destroy()
		activeFolder = nil
	end
	mazeRef = nil
end

function PowerupManager.ResetPlayer(player: Player)
	local effects = playerEffects[player]
	if effects then
		if effects.GhostMode then
			setGhost(player, false)
		end
		if effects.GoalCompass then
			Remotes.Event("GoalCompass"):FireClient(player, { Enabled = false })
		end
	end
	playerEffects[player] = {}
	finishedPlayers[player] = nil
	restoreMovement(player)
	pushActiveUpdate(player)
end

function PowerupManager.ResetAll()
	for _, player in ipairs(Players:GetPlayers()) do
		PowerupManager.ResetPlayer(player)
	end
	finishedPlayers = {}
end

function PowerupManager.MarkFinished(player: Player)
	finishedPlayers[player] = true
	-- Clear racing powerups so winners don't keep ghosting in spectate oddly
	PowerupManager.ResetPlayer(player)
	finishedPlayers[player] = true
end

function PowerupManager.SetCollecting(enabled: boolean)
	collectingEnabled = enabled
end

function PowerupManager.SpawnForMaze(maze: MazeRef)
	PowerupManager.Clear()
	mazeRef = maze
	rebuildWeights()

	local folder = Instance.new("Folder")
	folder.Name = "Powerups"
	folder.Parent = maze.Folder
	activeFolder = folder

	local count = math.random(Config.POWERUP_COUNT_MIN, Config.POWERUP_COUNT_MAX)
	local used: { [string]: boolean } = {}
	local spawned = 0
	local attempts = 0

	while spawned < count and attempts < count * 40 do
		attempts += 1
		local x = math.random(1, maze.Width)
		local y = math.random(1, maze.Height)
		local key = x .. ":" .. y
		if used[key] then
			continue
		end
		local cell = Vector2.new(x, y)
		if distanceCells(cell, maze.StartCell) < Config.POWERUP_MIN_DISTANCE_FROM_START then
			continue
		end
		if distanceCells(cell, maze.GoalCell) < 2 then
			continue
		end
		used[key] = true

		local powerupId = weightedIds[math.random(1, #weightedIds)]
		local part = createPowerupVisual(folder, powerupId, cellWorld(maze, x, y))

		part.Touched:Connect(function(hit)
			if not collectingEnabled then
				return
			end
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or finishedPlayers[player] then
				return
			end
			if part:GetAttribute("Collected") then
				return
			end
			part:SetAttribute("Collected", true)

			local id = part:GetAttribute("PowerupId")
			part:Destroy()
			if typeof(id) == "string" then
				applyPowerup(player, id)
			end
		end)

		spawned += 1
	end
end

function PowerupManager.OnCharacterAdded(player: Player, character: Model)
	-- Re-apply movement defaults; active effects re-applied if still valid
	task.defer(function()
		if playerEffects[player] then
			if playerEffects[player].GhostMode and playerEffects[player].GhostMode.EndsAt > os.clock() then
				setGhost(player, true)
			end
			applyWalkJump(player)
		else
			restoreMovement(player)
		end
	end)
end

function PowerupManager.OnPlayerRemoving(player: Player)
	playerEffects[player] = nil
	finishedPlayers[player] = nil
	effectTokens[player] = nil
end

return PowerupManager
