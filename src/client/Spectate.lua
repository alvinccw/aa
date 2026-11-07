--[[
	Spectate — camera follow for early finishers. Q/E cycle targets; R stops.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Spectate = {}

local enabled = false
local targetUserId: number? = nil
local renderConn: RBXScriptConnection? = nil
local requestRemote: RemoteEvent? = nil
local onHint: ((string?, boolean?) -> ())? = nil

local function findTargetCharacter(): Model?
	if not targetUserId then
		return nil
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == targetUserId then
			return p.Character
		end
	end
	return nil
end

local function stopCamera()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function startCamera()
	if renderConn then
		renderConn:Disconnect()
	end
	camera.CameraType = Enum.CameraType.Scriptable
	renderConn = RunService.RenderStepped:Connect(function()
		local character = findTargetCharacter()
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = Vector3.new(0, 8, 14)
			camera.CFrame = CFrame.new(root.Position + offset, root.Position + Vector3.new(0, 2, 0))
		end
	end)
end

function Spectate.Init(remote: RemoteEvent, hintCallback: (string?, boolean?) -> ())
	requestRemote = remote
	onHint = hintCallback

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.DPadRight then
			if requestRemote then
				requestRemote:FireServer("next")
			end
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.DPadLeft then
			if requestRemote then
				requestRemote:FireServer("prev")
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			if requestRemote then
				requestRemote:FireServer("stop")
			end
			Spectate.SetEnabled(false)
		end
	end)
end

function Spectate.SetEnabled(isEnabled: boolean, targetId: number?, targetName: string?)
	enabled = isEnabled
	targetUserId = targetId
	if not enabled then
		stopCamera()
		if onHint then
			onHint(nil, false)
		end
		return
	end
	if targetId then
		startCamera()
		if onHint then
			onHint(("Spectating %s — Q/E cycle, R stop"):format(targetName or "racer"), true)
		end
	else
		-- Enabled but no target yet: request one
		if onHint then
			onHint("Finished! Press E to spectate — Q/E cycle, R stop", true)
		end
		if requestRemote then
			requestRemote:FireServer("next")
		end
	end
end

function Spectate.IsEnabled(): boolean
	return enabled
end

return Spectate
