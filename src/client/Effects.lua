--[[
	Effects — goal compass beam, collect/win particles, lightweight sounds.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Effects = {}

local compassBeam: Beam? = nil
local compassAtt0: Attachment? = nil
local compassAtt1: Attachment? = nil
local compassPart: Part? = nil
local soundFolder: Folder

local function ensureSounds()
	if soundFolder and soundFolder.Parent then
		return
	end
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "NeonSkyMazeSounds"
	soundFolder.Parent = SoundService

	local function make(name: string, id: string, volume: number)
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = volume
		s.Parent = soundFolder
		return s
	end

	-- Roblox built-in / catalog-safe placeholders
	make("Collect", "rbxassetid://9113888926", 0.55)
	make("Countdown", "rbxassetid://9114224570", 0.45)
	make("Go", "rbxassetid://9114221323", 0.6)
	make("Win", "rbxassetid://9114397400", 0.7)
	make("Notify", "rbxassetid://9113890072", 0.35)
end

function Effects.Init()
	ensureSounds()
end

function Effects.Play(name: string)
	ensureSounds()
	local template = soundFolder:FindFirstChild(name)
	if not template or not template:IsA("Sound") then
		return
	end
	local s = template:Clone()
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Effects.SetCompass(enabled: boolean, goalPosition: Vector3?)
	if not enabled then
		if compassBeam then
			compassBeam:Destroy()
			compassBeam = nil
		end
		if compassPart then
			compassPart:Destroy()
			compassPart = nil
		end
		compassAtt0 = nil
		compassAtt1 = nil
		return
	end

	local root = getRoot()
	if not root or not goalPosition then
		return
	end

	Effects.SetCompass(false)

	compassAtt0 = Instance.new("Attachment")
	compassAtt0.Name = "CompassA0"
	compassAtt0.Parent = root

	compassPart = Instance.new("Part")
	compassPart.Name = "CompassTarget"
	compassPart.Anchored = true
	compassPart.CanCollide = false
	compassPart.Transparency = 1
	compassPart.Size = Vector3.new(1, 1, 1)
	compassPart.Position = goalPosition
	compassPart.Parent = Workspace

	compassAtt1 = Instance.new("Attachment")
	compassAtt1.Parent = compassPart

	compassBeam = Instance.new("Beam")
	compassBeam.Attachment0 = compassAtt0
	compassBeam.Attachment1 = compassAtt1
	compassBeam.Width0 = 0.6
	compassBeam.Width1 = 1.4
	compassBeam.FaceCamera = true
	compassBeam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 80, 200))
	compassBeam.LightEmission = 1
	compassBeam.Transparency = NumberSequence.new(0.2, 0.6)
	compassBeam.Parent = root
end

function Effects.BurstAt(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.Position = position
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(8, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(30)
	Debris:AddItem(part, 1.5)
end

function Effects.CollectBurst(color: Color3)
	local root = getRoot()
	if root then
		Effects.BurstAt(root.Position, color)
	end
	Effects.Play("Collect")
end

function Effects.WinBurst()
	local root = getRoot()
	if root then
		Effects.BurstAt(root.Position, Color3.fromRGB(80, 255, 160))
		Effects.BurstAt(root.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 255, 120))
	end
	Effects.Play("Win")
end

function Effects.ScreenPulse(color: Color3)
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("NeonSkyMazeUI")
	if not gui then
		return
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.7
	flash.BorderSizePixel = 0
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.5)
end

return Effects
