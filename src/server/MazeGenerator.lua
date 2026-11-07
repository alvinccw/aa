--[[
	MazeGenerator — Recursive Backtracking maze builder.
	Produces a solvable neon maze under Workspace.CurrentMaze.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MazeGenerator = {}

export type MazeInfo = {
	Folder: Folder,
	Width: number,
	Height: number,
	CellSize: number,
	StartCell: Vector2,
	GoalCell: Vector2,
	StartWorld: Vector3,
	GoalWorld: Vector3,
	GoalPart: BasePart,
}

local DIRS = {
	{ dx = 0, dy = -1, wall = "N", opposite = "S" },
	{ dx = 0, dy = 1, wall = "S", opposite = "N" },
	{ dx = 1, dy = 0, wall = "E", opposite = "W" },
	{ dx = -1, dy = 0, wall = "W", opposite = "E" },
}

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

local function cellCenter(ox: number, oy: number, oz: number, x: number, y: number, cellSize: number): Vector3
	return Vector3.new(
		ox + (x - 0.5) * cellSize,
		oy,
		oz + (y - 0.5) * cellSize
	)
end

local function makeNeonMaterial(part: BasePart, color: Color3, neon: boolean?)
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = color
	part.Reflectance = if neon then 0.15 else 0.05
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function assignWallCollision(part: BasePart)
	pcall(function()
		part.CollisionGroup = Config.COLLISION_WALLS
	end)
end

local function varyColor(base: Color3): Color3
	local h, s, v = base:ToHSV()
	h = (h + (math.random() - 0.5) * 0.06) % 1
	s = math.clamp(s + (math.random() - 0.5) * 0.1, 0.55, 1)
	v = math.clamp(v + (math.random() - 0.5) * 0.12, 0.7, 1)
	return Color3.fromHSV(h, s, v)
end

local function rainbowAt(t: number): Color3
	return Color3.fromHSV((t % 1), 0.9, 1)
end

--------------------------------------------------------------------------------
-- Grid carving
--------------------------------------------------------------------------------

type Cell = {
	visited: boolean,
	N: boolean,
	S: boolean,
	E: boolean,
	W: boolean,
}

local function createGrid(width: number, height: number): { { Cell } }
	local grid = table.create(width)
	for x = 1, width do
		grid[x] = table.create(height)
		for y = 1, height do
			grid[x][y] = { visited = false, N = true, S = true, E = true, W = true }
		end
	end
	return grid
end

local function carve(grid: { { Cell } }, x: number, y: number, width: number, height: number)
	grid[x][y].visited = true
	local order = { 1, 2, 3, 4 }
	shuffle(order)
	for _, idx in ipairs(order) do
		local dir = DIRS[idx]
		local nx, ny = x + dir.dx, y + dir.dy
		if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not grid[nx][ny].visited then
			grid[x][y][dir.wall] = false
			grid[nx][ny][dir.opposite] = false
			carve(grid, nx, ny, width, height)
		end
	end
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

local function clearPrevious()
	local existing = Workspace:FindFirstChild("CurrentMaze")
	if existing then
		existing:Destroy()
	end
end

local function createFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "CurrentMaze"
	folder.Parent = Workspace
	return folder
end

local function buildFloor(
	folder: Folder,
	width: number,
	height: number,
	cellSize: number,
	origin: Vector3
)
	local floors = Instance.new("Folder")
	floors.Name = "Floors"
	floors.Parent = folder

	local totalW = width * cellSize
	local totalH = height * cellSize
	local cx = origin.X + totalW / 2
	local cz = origin.Z + totalH / 2

	local base = Instance.new("Part")
	base.Name = "MazeFloor"
	base.Size = Vector3.new(totalW + Config.WALL_THICKNESS * 2, Config.FLOOR_THICKNESS, totalH + Config.WALL_THICKNESS * 2)
	base.Position = Vector3.new(cx, origin.Y - Config.FLOOR_THICKNESS / 2, cz)
	makeNeonMaterial(base, Config.FLOOR_COLOR, false)
	base.Material = Enum.Material.SmoothPlastic
	base.Parent = floors

	-- Neon grid lines (visual only)
	local lines = Instance.new("Folder")
	lines.Name = "GridLines"
	lines.Parent = floors

	local lineThickness = 0.35
	local lineY = origin.Y + 0.05

	for x = 0, width do
		local line = Instance.new("Part")
		line.Name = "GridX_" .. x
		line.Size = Vector3.new(lineThickness, 0.12, totalH)
		line.Position = Vector3.new(origin.X + x * cellSize, lineY, cz)
		makeNeonMaterial(line, Config.GRID_LINE_COLOR, true)
		line.CanCollide = false
		line.Transparency = 0.35
		line.Parent = lines
	end
	for y = 0, height do
		local line = Instance.new("Part")
		line.Name = "GridZ_" .. y
		line.Size = Vector3.new(totalW, 0.12, lineThickness)
		line.Position = Vector3.new(cx, lineY, origin.Z + y * cellSize)
		makeNeonMaterial(line, Config.GRID_LINE_COLOR, true)
		line.CanCollide = false
		line.Transparency = 0.35
		line.Parent = lines
	end
end

local function wallColorFor(x: number, y: number, width: number, height: number): Color3
	local palette = Config.WALL_COLORS
	local t = ((x - 1) + (y - 1)) / math.max(1, width + height - 2)
	if math.random() < 0.35 then
		return varyColor(rainbowAt(t + math.random() * 0.15))
	end
	local pick = palette[((x + y * 3 - 2) % #palette) + 1]
	return varyColor(pick)
end

local function createWallPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	makeNeonMaterial(part, color, true)
	assignWallCollision(part)
	CollectionService:AddTag(part, Config.TAG_WALL)
	part.Parent = parent

	-- Soft point light for atmosphere (sparse)
	if math.random() < 0.08 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 1.2
		light.Range = 28
		light.Parent = part
	end
	return part
end

local function buildWalls(
	folder: Folder,
	grid: { { Cell } },
	width: number,
	height: number,
	cellSize: number,
	origin: Vector3
)
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = folder

	local wallH = Config.WALL_HEIGHT
	local thick = Config.WALL_THICKNESS
	local y = origin.Y + wallH / 2

	-- Internal + perimeter walls from cell flags
	for x = 1, width do
		for yCell = 1, height do
			local cell = grid[x][yCell]
			local center = cellCenter(origin.X, y, origin.Z, x, yCell, cellSize)
			local color = wallColorFor(x, yCell, width, height)

			if cell.N then
				createWallPart(
					wallsFolder,
					("W_%d_%d_N"):format(x, yCell),
					Vector3.new(cellSize + thick * 0.5, wallH, thick),
					Vector3.new(center.X, y, origin.Z + (yCell - 1) * cellSize),
					color
				)
			end
			if cell.W then
				createWallPart(
					wallsFolder,
					("W_%d_%d_W"):format(x, yCell),
					Vector3.new(thick, wallH, cellSize + thick * 0.5),
					Vector3.new(origin.X + (x - 1) * cellSize, y, center.Z),
					color
				)
			end
			-- Draw East/South only on outer edges to avoid double walls
			if x == width and cell.E then
				createWallPart(
					wallsFolder,
					("W_%d_%d_E"):format(x, yCell),
					Vector3.new(thick, wallH, cellSize + thick * 0.5),
					Vector3.new(origin.X + x * cellSize, y, center.Z),
					color
				)
			end
			if yCell == height and cell.S then
				createWallPart(
					wallsFolder,
					("W_%d_%d_S"):format(x, yCell),
					Vector3.new(cellSize + thick * 0.5, wallH, thick),
					Vector3.new(center.X, y, origin.Z + yCell * cellSize),
					color
				)
			end
		end
	end
end

local function buildRamps(
	folder: Folder,
	grid: { { Cell } },
	width: number,
	height: number,
	cellSize: number,
	origin: Vector3
)
	if not Config.ENABLE_RAMPS then
		return
	end
	local ramps = Instance.new("Folder")
	ramps.Name = "Ramps"
	ramps.Parent = folder

	local placed = 0
	local target = math.floor((width * height) * 0.035)
	for _ = 1, target * 4 do
		if placed >= target then
			break
		end
		local x = math.random(2, width - 1)
		local yCell = math.random(2, height - 1)
		-- Prefer open corridors (few walls)
		local cell = grid[x][yCell]
		local open = 0
		if not cell.N then open += 1 end
		if not cell.S then open += 1 end
		if not cell.E then open += 1 end
		if not cell.W then open += 1 end
		if open < 2 then
			continue
		end
		local center = cellCenter(origin.X, origin.Y + 1.5, origin.Z, x, yCell, cellSize)
		local ramp = Instance.new("Part")
		ramp.Name = ("Ramp_%d_%d"):format(x, yCell)
		ramp.Size = Vector3.new(cellSize * 0.55, 1.2, cellSize * 0.55)
		ramp.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(12), math.rad(math.random(0, 3) * 90), 0)
		makeNeonMaterial(ramp, Color3.fromRGB(40, 40, 70), false)
		ramp.Material = Enum.Material.Metal
		ramp.Parent = ramps
		placed += 1
	end
end

local function buildStartMarker(folder: Folder, worldPos: Vector3): Part
	local pad = Instance.new("Part")
	pad.Name = "StartPad"
	pad.Size = Vector3.new(Config.CELL_SIZE * 0.7, 1, Config.CELL_SIZE * 0.7)
	pad.Position = worldPos + Vector3.new(0, 0.6, 0)
	makeNeonMaterial(pad, Config.START_COLOR, true)
	pad.CanCollide = false
	pad.Transparency = 0.25
	CollectionService:AddTag(pad, Config.TAG_START)
	pad.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pad
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "START"
	label.TextColor3 = Config.START_COLOR
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard

	local light = Instance.new("PointLight")
	light.Color = Config.START_COLOR
	light.Brightness = 2
	light.Range = 24
	light.Parent = pad
	return pad
end

local function buildGoalPortal(folder: Folder, worldPos: Vector3): Part
	local goal = Instance.new("Part")
	goal.Name = "GoalPortal"
	goal.Shape = Enum.PartType.Cylinder
	goal.Size = Vector3.new(4, Config.CELL_SIZE * 0.75, Config.CELL_SIZE * 0.75)
	goal.CFrame = CFrame.new(worldPos + Vector3.new(0, Config.WALL_HEIGHT * 0.35, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	makeNeonMaterial(goal, Config.GOAL_COLOR, true)
	goal.CanCollide = false
	goal.Transparency = 0.35
	CollectionService:AddTag(goal, Config.TAG_GOAL)
	goal.Parent = folder

	local ring = Instance.new("Part")
	ring.Name = "GoalRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(2, Config.CELL_SIZE * 0.9, Config.CELL_SIZE * 0.9)
	ring.CFrame = goal.CFrame
	makeNeonMaterial(ring, Color3.fromRGB(255, 255, 255), true)
	ring.CanCollide = false
	ring.Transparency = 0.55
	ring.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = Config.GOAL_COLOR
	light.Brightness = 4
	light.Range = 40
	light.Parent = goal

	local attachment = Instance.new("Attachment")
	attachment.Parent = goal

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Rate = 40
	particles.Lifetime = NumberRange.new(0.6, 1.4)
	particles.Speed = NumberRange.new(2, 6)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Color = ColorSequence.new(Config.GOAL_COLOR, Color3.fromRGB(255, 255, 255))
	particles.LightEmission = 1
	particles.Parent = goal

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 42)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = goal
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GOAL"
	label.TextColor3 = Config.GOAL_COLOR
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = billboard

	-- Invisible touch volume at floor level
	local trigger = Instance.new("Part")
	trigger.Name = "GoalTrigger"
	trigger.Size = Vector3.new(Config.CELL_SIZE * 0.85, 8, Config.CELL_SIZE * 0.85)
	trigger.Position = worldPos + Vector3.new(0, 4, 0)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.Anchored = true
	CollectionService:AddTag(trigger, Config.TAG_GOAL)
	trigger.Parent = folder

	return trigger
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function MazeGenerator.Clear()
	clearPrevious()
end

function MazeGenerator.Generate(seed: number?): MazeInfo
	if seed then
		math.randomseed(seed)
	else
		math.randomseed(os.clock() * 1000 % 1e9)
	end

	clearPrevious()

	local width = Config.MAZE_WIDTH
	local height = Config.MAZE_HEIGHT
	local cellSize = Config.CELL_SIZE
	local origin = Config.MAZE_ORIGIN

	local grid = createGrid(width, height)
	carve(grid, 1, 1, width, height)

	-- Ensure start/goal corners have open feel: open one inner wall if fully boxed (shouldn't happen)
	grid[1][1].visited = true
	grid[width][height].visited = true

	local folder = createFolder()
	buildFloor(folder, width, height, cellSize, origin)
	buildWalls(folder, grid, width, height, cellSize, origin)
	buildRamps(folder, grid, width, height, cellSize, origin)

	local startWorld = cellCenter(origin.X, origin.Y + 3, origin.Z, 1, 1, cellSize)
	local goalWorld = cellCenter(origin.X, origin.Y + 3, origin.Z, width, height, cellSize)

	buildStartMarker(folder, startWorld)
	local goalPart = buildGoalPortal(folder, goalWorld)

	-- Invisible ceiling kill/boundary is skipped; walls enclose the maze.
	-- Kill brick under maze for fallouts
	local kill = Instance.new("Part")
	kill.Name = "FallBarrier"
	kill.Size = Vector3.new(width * cellSize + 200, 2, height * cellSize + 200)
	kill.Position = Vector3.new(
		origin.X + width * cellSize / 2,
		origin.Y - 40,
		origin.Z + height * cellSize / 2
	)
	kill.Transparency = 1
	kill.Anchored = true
	kill.CanCollide = true
	kill.Parent = folder

	return {
		Folder = folder,
		Width = width,
		Height = height,
		CellSize = cellSize,
		StartCell = Vector2.new(1, 1),
		GoalCell = Vector2.new(width, height),
		StartWorld = startWorld,
		GoalWorld = goalWorld,
		GoalPart = goalPart,
	}
end

function MazeGenerator.WorldToCell(world: Vector3, maze: MazeInfo): Vector2
	local origin = Config.MAZE_ORIGIN
	local x = math.clamp(math.floor((world.X - origin.X) / maze.CellSize) + 1, 1, maze.Width)
	local y = math.clamp(math.floor((world.Z - origin.Z) / maze.CellSize) + 1, 1, maze.Height)
	return Vector2.new(x, y)
end

function MazeGenerator.CellToWorld(cell: Vector2, maze: MazeInfo, yOffset: number?): Vector3
	local origin = Config.MAZE_ORIGIN
	local y = origin.Y + (yOffset or 3)
	return cellCenter(origin.X, y, origin.Z, cell.X, cell.Y, maze.CellSize)
end

return MazeGenerator
