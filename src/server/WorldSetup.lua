--[[
	WorldSetup module — lobby, lighting, collision groups (idempotent Init).
]]

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local WorldSetup = {}
local initialized = false

local function ensureCollisionGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setupCollision()
	ensureCollisionGroup(Config.COLLISION_WALLS)
	ensureCollisionGroup(Config.COLLISION_GHOST)
	ensureCollisionGroup(Config.COLLISION_POWERUPS)

	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(Config.COLLISION_GHOST, Config.COLLISION_WALLS, false)
		PhysicsService:CollisionGroupSetCollidable(Config.COLLISION_GHOST, Config.COLLISION_GHOST, false)
		PhysicsService:CollisionGroupSetCollidable(Config.COLLISION_POWERUPS, Config.COLLISION_WALLS, false)
		PhysicsService:CollisionGroupSetCollidable(Config.COLLISION_POWERUPS, "Default", false)
	end)
end

local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(12, 12, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 45)
	Lighting.FogColor = Color3.fromRGB(5, 5, 20)
	Lighting.FogStart = 60
	Lighting.FogEnd = 850

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(30, 20, 60)
	atmosphere.Decay = Color3.fromRGB(10, 10, 30)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 0.85

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	cc.Saturation = 0.15
	cc.Contrast = 0.12
	cc.TintColor = Color3.fromRGB(230, 230, 255)

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Parent = Lighting
	end
	rays.Intensity = 0.05
	rays.Spread = 0.4
end

local function setupLobby()
	local lobbyFolder = Workspace:FindFirstChild("Lobby")
	if not lobbyFolder then
		lobbyFolder = Instance.new("Folder")
		lobbyFolder.Name = "Lobby"
		lobbyFolder.Parent = Workspace
	end

	for _, child in ipairs(lobbyFolder:GetChildren()) do
		if child:GetAttribute("NeonSkyMazeAuto") then
			child:Destroy()
		end
	end

	local pad = Instance.new("Part")
	pad.Name = "LobbyPad"
	pad.Size = Config.LOBBY_SIZE
	pad.Position = Config.LOBBY_SPAWN
	pad.Anchored = true
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(18, 18, 32)
	pad:SetAttribute("NeonSkyMazeAuto", true)
	pad.Parent = lobbyFolder

	local rim = Instance.new("Part")
	rim.Name = "LobbyRim"
	rim.Size = Vector3.new(Config.LOBBY_SIZE.X + 2, 1, Config.LOBBY_SIZE.Z + 2)
	rim.Position = Config.LOBBY_SPAWN + Vector3.new(0, -0.5, 0)
	rim.Anchored = true
	rim.Material = Enum.Material.Neon
	rim.Color = Color3.fromRGB(0, 255, 255)
	rim:SetAttribute("NeonSkyMazeAuto", true)
	rim.Parent = lobbyFolder

	local title = Instance.new("Part")
	title.Name = "LobbySign"
	title.Size = Vector3.new(40, 8, 1)
	title.Position = Config.LOBBY_SPAWN + Vector3.new(0, 14, -Config.LOBBY_SIZE.Z / 2 + 1)
	title.Anchored = true
	title.Transparency = 1
	title.CanCollide = false
	title:SetAttribute("NeonSkyMazeAuto", true)
	title.Parent = lobbyFolder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = title
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "NEON SKY MAZE"
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(0, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Config.LOBBY_SPAWN + Vector3.new(0, 1.5, 0)
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(255, 0, 200)
	spawn.CanCollide = false
	spawn:SetAttribute("NeonSkyMazeAuto", true)
	spawn.Parent = lobbyFolder

	for i, color in ipairs({
		Color3.fromRGB(0, 255, 255),
		Color3.fromRGB(255, 0, 200),
		Color3.fromRGB(160, 40, 255),
	}) do
		local lightPart = Instance.new("Part")
		lightPart.Name = "LobbyLight_" .. i
		lightPart.Size = Vector3.new(2, 2, 2)
		lightPart.Shape = Enum.PartType.Ball
		lightPart.Material = Enum.Material.Neon
		lightPart.Color = color
		lightPart.Anchored = true
		lightPart.CanCollide = false
		lightPart.Position = Config.LOBBY_SPAWN + Vector3.new((i - 2) * 18, 8, 10)
		lightPart:SetAttribute("NeonSkyMazeAuto", true)
		lightPart.Parent = lobbyFolder
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Brightness = 2
		pl.Range = 40
		pl.Parent = lightPart
	end
end

function WorldSetup.Init()
	if initialized then
		return
	end
	initialized = true

	Remotes.Init()
	setupCollision()
	setupLighting()
	setupLobby()

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 0.3
		baseplate.Color = Color3.fromRGB(10, 10, 18)
	end

	print("[NeonSkyMaze] WorldSetup ready — lobby + lighting + collision groups")
end

return WorldSetup
