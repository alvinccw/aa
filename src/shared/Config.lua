--[[
	Neon Sky Maze — shared configuration.
	Tweaking values here changes gameplay for both server and client.
]]

local Config = {}

--------------------------------------------------------------------------------
-- Round timing
--------------------------------------------------------------------------------
Config.INTERMISSION_DURATION = 28 -- seconds (25–30)
Config.COUNTDOWN_DURATION = 5
Config.RESULTS_DURATION = 9 -- seconds (8–10)
Config.POST_WIN_CONTINUE = 20 -- others may finish for this long after 1st place
Config.MIN_PLAYERS_TO_START = 1 -- set higher for production lobbies

--------------------------------------------------------------------------------
-- Maze layout
--------------------------------------------------------------------------------
Config.MAZE_WIDTH = 21 -- odd preferred; 21 or 25
Config.MAZE_HEIGHT = 21
Config.CELL_SIZE = 20 -- studs (18–22)
Config.WALL_HEIGHT = 60 -- studs (50–70)
Config.WALL_THICKNESS = 2.5 -- studs (2–3)
Config.FLOOR_THICKNESS = 2
Config.MAZE_ORIGIN = Vector3.new(0, 5, 0) -- world offset for maze corner
Config.ENABLE_RAMPS = true -- occasional corridor ramps / platforms

--------------------------------------------------------------------------------
-- Neon palette
--------------------------------------------------------------------------------
Config.WALL_COLORS = {
	Color3.fromRGB(0, 255, 255), -- cyan
	Color3.fromRGB(255, 0, 200), -- magenta
	Color3.fromRGB(160, 40, 255), -- purple
	Color3.fromRGB(255, 140, 0), -- orange
}
Config.FLOOR_COLOR = Color3.fromRGB(12, 12, 22)
Config.GRID_LINE_COLOR = Color3.fromRGB(0, 220, 255)
Config.GOAL_COLOR = Color3.fromRGB(80, 255, 160)
Config.START_COLOR = Color3.fromRGB(255, 220, 60)

--------------------------------------------------------------------------------
-- Player movement defaults (restored after powerups / rounds)
--------------------------------------------------------------------------------
Config.DEFAULT_WALK_SPEED = 16
Config.DEFAULT_JUMP_POWER = 50
Config.DEFAULT_JUMP_HEIGHT = 7.2

--------------------------------------------------------------------------------
-- Powerups
--------------------------------------------------------------------------------
Config.POWERUP_COUNT_MIN = 8
Config.POWERUP_COUNT_MAX = 12
Config.POWERUP_MIN_DISTANCE_FROM_START = 4 -- cells away from start
Config.POWERUP_PICKUP_RADIUS = 6

Config.Powerups = {
	SpeedBoost = {
		Id = "SpeedBoost",
		DisplayName = "Speed Boost",
		Duration = 6,
		WalkSpeedBonus = 16,
		Color = Color3.fromRGB(0, 255, 255),
		Icon = "⚡",
	},
	SuperJump = {
		Id = "SuperJump",
		DisplayName = "Super Jump",
		Duration = 8,
		JumpPowerBonus = 40,
		Color = Color3.fromRGB(120, 255, 80),
		Icon = "⤒",
	},
	GhostMode = {
		Id = "GhostMode",
		DisplayName = "Ghost Mode",
		Duration = 4,
		Color = Color3.fromRGB(200, 160, 255),
		Icon = "👻",
	},
	SpeedTrap = {
		Id = "SpeedTrap",
		DisplayName = "Speed Trap",
		Duration = 5, -- slow duration on victims
		SlowWalkSpeed = 8,
		Color = Color3.fromRGB(255, 60, 60),
		Icon = "⚠",
	},
	GoalCompass = {
		Id = "GoalCompass",
		DisplayName = "Goal Compass",
		Duration = 8,
		Color = Color3.fromRGB(255, 200, 40),
		Icon = "◎",
	},
	DoubleBoost = {
		Id = "DoubleBoost",
		DisplayName = "Double Boost",
		Duration = 5,
		WalkSpeedBonus = 16,
		JumpPowerBonus = 40,
		Color = Color3.fromRGB(255, 100, 220),
		Icon = "✦",
	},
}

-- Spawn weights (relative). Missing types still appear via equal fallback.
Config.POWERUP_WEIGHTS = {
	SpeedBoost = 3,
	SuperJump = 2,
	GhostMode = 2,
	SpeedTrap = 2,
	GoalCompass = 2,
	DoubleBoost = 1,
}

--------------------------------------------------------------------------------
-- Lobby
--------------------------------------------------------------------------------
Config.LOBBY_SPAWN = Vector3.new(0, 12, -80)
Config.LOBBY_SIZE = Vector3.new(80, 2, 60)

--------------------------------------------------------------------------------
-- Tags (CollectionService)
--------------------------------------------------------------------------------
Config.TAG_WALL = "NeonMazeWall"
Config.TAG_POWERUP = "NeonPowerup"
Config.TAG_GOAL = "NeonGoal"
Config.TAG_START = "NeonStart"

--------------------------------------------------------------------------------
-- Collision groups
--------------------------------------------------------------------------------
Config.COLLISION_DEFAULT = "Default"
Config.COLLISION_WALLS = "MazeWalls"
Config.COLLISION_GHOST = "GhostPlayers"
Config.COLLISION_POWERUPS = "Powerups"

return Config
