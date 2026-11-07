--[[
	Ensures all Neon Sky Maze remotes exist under ReplicatedStorage.Remotes.
	Safe to require from server or client; server creates missing instances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_FOLDER_NAME = "Remotes"

-- name → "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent"
local DEFINITIONS = {
	RoundStateChanged = "RemoteEvent", -- phase, endsAt, extras
	LeaderboardUpdate = "RemoteEvent", -- array of {userId, name, time, status}
	Notification = "RemoteEvent", -- message, kind, duration
	PowerupCollected = "RemoteEvent", -- powerupId, displayName, duration, color
	PowerupExpired = "RemoteEvent", -- powerupId
	PowerupActiveUpdate = "RemoteEvent", -- list of active {id, displayName, endsAt, color, icon}
	ResultsShow = "RemoteEvent", -- placements [{place, name, time}]
	PlayerFinished = "RemoteEvent", -- userId, place, time
	GoalCompass = "RemoteEvent", -- enabled, goalWorldPosition?
	SpectateState = "RemoteEvent", -- enabled, targetUserId?
	RequestSpectate = "RemoteEvent", -- client → server next/prev/stop
	FreezeState = "RemoteEvent", -- frozen bool (countdown)
}

local Remotes = {}
local cache: { [string]: Instance } = {}

local function getFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	folder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME, 30)
	assert(folder and folder:IsA("Folder"), "[NeonSkyMaze] Remotes folder missing")
	return folder
end

local function createRemote(className: string, name: string, parent: Folder): Instance
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

function Remotes.Init()
	local folder = getFolder()
	for name, className in pairs(DEFINITIONS) do
		local existing = folder:FindFirstChild(name)
		if existing then
			cache[name] = existing
		elseif RunService:IsServer() then
			cache[name] = createRemote(className, name, folder)
		else
			cache[name] = folder:WaitForChild(name, 30)
		end
	end
	return Remotes
end

function Remotes.Get(name: string): Instance
	if cache[name] then
		return cache[name]
	end
	local folder = getFolder()
	local remote = folder:FindFirstChild(name) or folder:WaitForChild(name, 30)
	assert(remote, "[NeonSkyMaze] Missing remote: " .. name)
	cache[name] = remote
	return remote
end

function Remotes.Event(name: string): RemoteEvent
	return Remotes.Get(name) :: RemoteEvent
end

return Remotes
