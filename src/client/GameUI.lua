--[[
	GameUI — ScreenGui HUD: timers, leaderboard, powerups, results, toasts.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GameUI = {}

local gui: ScreenGui
local timerLabel: TextLabel
local phaseLabel: TextLabel
local leaderboardFrame: Frame
local leaderboardList: Frame
local powerupFrame: Frame
local powerupList: Frame
local toastFrame: Frame
local resultsFrame: Frame
local spectateLabel: TextLabel

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = 0.25
	s.Parent = parent
	return s
end

local function pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

function GameUI.Init()
	local existing = playerGui:FindFirstChild("NeonSkyMazeUI")
	if existing then
		existing:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "NeonSkyMazeUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Top timer / phase
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 18)
	top.Size = UDim2.fromOffset(360, 72)
	top.BackgroundColor3 = Color3.fromRGB(8, 10, 24)
	top.BackgroundTransparency = 0.25
	top.Parent = gui
	corner(top, 14)
	stroke(top, Color3.fromRGB(0, 255, 255), 2)

	phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "Phase"
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Position = UDim2.fromOffset(0, 6)
	phaseLabel.Size = UDim2.new(1, 0, 0, 22)
	phaseLabel.Font = Enum.Font.GothamBold
	phaseLabel.TextSize = 16
	phaseLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
	phaseLabel.Text = "INTERMISSION"
	phaseLabel.Parent = top

	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.BackgroundTransparency = 1
	timerLabel.Position = UDim2.fromOffset(0, 28)
	timerLabel.Size = UDim2.new(1, 0, 0, 36)
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.TextSize = 30
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.Text = "0:28"
	timerLabel.Parent = top

	-- Leaderboard
	leaderboardFrame = Instance.new("Frame")
	leaderboardFrame.Name = "Leaderboard"
	leaderboardFrame.AnchorPoint = Vector2.new(1, 0)
	leaderboardFrame.Position = UDim2.new(1, -16, 0, 16)
	leaderboardFrame.Size = UDim2.fromOffset(230, 220)
	leaderboardFrame.BackgroundColor3 = Color3.fromRGB(8, 10, 24)
	leaderboardFrame.BackgroundTransparency = 0.28
	leaderboardFrame.Parent = gui
	corner(leaderboardFrame, 12)
	stroke(leaderboardFrame, Color3.fromRGB(255, 0, 200), 1.5)
	pad(leaderboardFrame, 10)

	local lbTitle = Instance.new("TextLabel")
	lbTitle.BackgroundTransparency = 1
	lbTitle.Size = UDim2.new(1, 0, 0, 22)
	lbTitle.Font = Enum.Font.GothamBlack
	lbTitle.TextSize = 15
	lbTitle.TextXAlignment = Enum.TextXAlignment.Left
	lbTitle.TextColor3 = Color3.fromRGB(255, 0, 200)
	lbTitle.Text = "LIVE BOARD"
	lbTitle.Parent = leaderboardFrame

	leaderboardList = Instance.new("Frame")
	leaderboardList.Name = "List"
	leaderboardList.BackgroundTransparency = 1
	leaderboardList.Position = UDim2.fromOffset(0, 28)
	leaderboardList.Size = UDim2.new(1, 0, 1, -28)
	leaderboardList.Parent = leaderboardFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = leaderboardList

	-- Active powerups
	powerupFrame = Instance.new("Frame")
	powerupFrame.Name = "Powerups"
	powerupFrame.Position = UDim2.new(0, 16, 1, -120)
	powerupFrame.Size = UDim2.fromOffset(260, 96)
	powerupFrame.BackgroundColor3 = Color3.fromRGB(8, 10, 24)
	powerupFrame.BackgroundTransparency = 0.35
	powerupFrame.Parent = gui
	corner(powerupFrame, 12)
	stroke(powerupFrame, Color3.fromRGB(160, 40, 255), 1.5)
	pad(powerupFrame, 8)

	local puTitle = Instance.new("TextLabel")
	puTitle.BackgroundTransparency = 1
	puTitle.Size = UDim2.new(1, 0, 0, 18)
	puTitle.Font = Enum.Font.GothamBold
	puTitle.TextSize = 13
	puTitle.TextXAlignment = Enum.TextXAlignment.Left
	puTitle.TextColor3 = Color3.fromRGB(200, 160, 255)
	puTitle.Text = "ACTIVE POWERUPS"
	puTitle.Parent = powerupFrame

	powerupList = Instance.new("Frame")
	powerupList.BackgroundTransparency = 1
	powerupList.Position = UDim2.fromOffset(0, 22)
	powerupList.Size = UDim2.new(1, 0, 1, -22)
	powerupList.Parent = powerupFrame
	local puLayout = Instance.new("UIListLayout")
	puLayout.FillDirection = Enum.FillDirection.Horizontal
	puLayout.Padding = UDim.new(0, 6)
	puLayout.Parent = powerupList

	-- Toasts
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toasts"
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, 100)
	toastFrame.Size = UDim2.fromOffset(420, 200)
	toastFrame.BackgroundTransparency = 1
	toastFrame.Parent = gui
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.Parent = toastFrame

	-- Results overlay
	resultsFrame = Instance.new("Frame")
	resultsFrame.Name = "Results"
	resultsFrame.Size = UDim2.fromScale(1, 1)
	resultsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	resultsFrame.BackgroundTransparency = 0.45
	resultsFrame.Visible = false
	resultsFrame.Parent = gui

	local resultsCard = Instance.new("Frame")
	resultsCard.Name = "Card"
	resultsCard.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsCard.Position = UDim2.fromScale(0.5, 0.5)
	resultsCard.Size = UDim2.fromOffset(420, 360)
	resultsCard.BackgroundColor3 = Color3.fromRGB(10, 12, 28)
	resultsCard.Parent = resultsFrame
	corner(resultsCard, 16)
	stroke(resultsCard, Color3.fromRGB(0, 255, 200), 2)
	pad(resultsCard, 18)

	local resultsTitle = Instance.new("TextLabel")
	resultsTitle.Name = "Title"
	resultsTitle.BackgroundTransparency = 1
	resultsTitle.Size = UDim2.new(1, 0, 0, 36)
	resultsTitle.Font = Enum.Font.GothamBlack
	resultsTitle.TextSize = 28
	resultsTitle.TextColor3 = Color3.fromRGB(0, 255, 200)
	resultsTitle.Text = "ROUND RESULTS"
	resultsTitle.Parent = resultsCard

	local resultsList = Instance.new("Frame")
	resultsList.Name = "List"
	resultsList.BackgroundTransparency = 1
	resultsList.Position = UDim2.fromOffset(0, 50)
	resultsList.Size = UDim2.new(1, 0, 1, -50)
	resultsList.Parent = resultsCard
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 8)
	rl.Parent = resultsList

	-- Spectate hint
	spectateLabel = Instance.new("TextLabel")
	spectateLabel.Name = "SpectateHint"
	spectateLabel.AnchorPoint = Vector2.new(0.5, 1)
	spectateLabel.Position = UDim2.new(0.5, 0, 1, -24)
	spectateLabel.Size = UDim2.fromOffset(480, 28)
	spectateLabel.BackgroundTransparency = 1
	spectateLabel.Font = Enum.Font.GothamMedium
	spectateLabel.TextSize = 16
	spectateLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	spectateLabel.Text = ""
	spectateLabel.Visible = false
	spectateLabel.Parent = gui

	return gui
end

local function formatTime(seconds: number): string
	seconds = math.max(0, seconds)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	local frac = math.floor((seconds % 1) * 100)
	if m > 0 then
		return string.format("%d:%02d.%02d", m, s, frac)
	end
	return string.format("%d.%02d", s, frac)
end

local function formatClock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

function GameUI.SetPhase(phase: string, remaining: number, raceTime: number?)
	phaseLabel.Text = string.upper(phase)
	if phase == "Racing" and raceTime then
		timerLabel.Text = formatTime(raceTime)
		phaseLabel.TextColor3 = Color3.fromRGB(80, 255, 160)
	elseif phase == "Countdown" then
		timerLabel.Text = tostring(math.max(0, math.ceil(remaining)))
		phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	elseif phase == "Results" then
		timerLabel.Text = formatClock(remaining)
		phaseLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
	else
		timerLabel.Text = formatClock(remaining)
		phaseLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
	end
end

function GameUI.UpdateLeaderboard(rows: { any })
	for _, child in ipairs(leaderboardList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local shown = 0
	for i, row in ipairs(rows) do
		if shown >= 8 then
			break
		end
		shown += 1
		local item = Instance.new("Frame")
		item.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
		item.BackgroundTransparency = 0.35
		item.Size = UDim2.new(1, 0, 0, 22)
		item.LayoutOrder = i
		item.Parent = leaderboardList
		corner(item, 6)

		local placeText = if row.Place then ("#" .. tostring(row.Place)) else "•"
		local left = Instance.new("TextLabel")
		left.BackgroundTransparency = 1
		left.Size = UDim2.new(0.55, 0, 1, 0)
		left.Position = UDim2.fromOffset(6, 0)
		left.Font = Enum.Font.GothamMedium
		left.TextSize = 13
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.TextColor3 = Color3.fromRGB(240, 240, 255)
		left.Text = placeText .. " " .. (row.Name or "?")
		left.TextTruncate = Enum.TextTruncate.AtEnd
		left.Parent = item

		local right = Instance.new("TextLabel")
		right.BackgroundTransparency = 1
		right.Size = UDim2.new(0.42, 0, 1, 0)
		right.Position = UDim2.new(0.55, 0, 0, 0)
		right.Font = Enum.Font.Gotham
		right.TextSize = 12
		right.TextXAlignment = Enum.TextXAlignment.Right
		right.TextColor3 = Color3.fromRGB(160, 220, 255)
		if row.Status == "Finished" and row.Time then
			right.Text = formatTime(row.Time)
		else
			right.Text = row.Status or ""
		end
		right.Parent = item
	end
end

function GameUI.UpdatePowerups(list: { any })
	for _, child in ipairs(powerupList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	powerupFrame.Visible = #list > 0
	for i, entry in ipairs(list) do
		local chip = Instance.new("Frame")
		chip.Size = UDim2.fromOffset(76, 58)
		chip.BackgroundColor3 = entry.Color or Color3.fromRGB(80, 80, 120)
		chip.BackgroundTransparency = 0.3
		chip.LayoutOrder = i
		chip.Parent = powerupList
		corner(chip, 8)
		stroke(chip, entry.Color or Color3.new(1, 1, 1), 1)

		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(1, 0, 0, 28)
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 20
		icon.Text = entry.Icon or "•"
		icon.TextColor3 = Color3.new(1, 1, 1)
		icon.Parent = chip

		local timeLabel = Instance.new("TextLabel")
		timeLabel.BackgroundTransparency = 1
		timeLabel.Position = UDim2.fromOffset(0, 28)
		timeLabel.Size = UDim2.new(1, 0, 0, 24)
		timeLabel.Font = Enum.Font.GothamBold
		timeLabel.TextSize = 14
		timeLabel.TextColor3 = Color3.new(1, 1, 1)
		timeLabel.Text = string.format("%.1fs", entry.Remaining or 0)
		timeLabel.Parent = chip
	end
end

local KIND_COLORS = {
	info = Color3.fromRGB(0, 200, 255),
	success = Color3.fromRGB(80, 255, 160),
	warn = Color3.fromRGB(255, 200, 60),
	danger = Color3.fromRGB(255, 80, 100),
	powerup = Color3.fromRGB(220, 120, 255),
}

function GameUI.Toast(message: string, kind: string?, duration: number?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(380, 36)
	toast.BackgroundColor3 = Color3.fromRGB(12, 14, 28)
	toast.BackgroundTransparency = 0.15
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.TextColor3 = color
	toast.Text = message
	toast.Parent = toastFrame
	corner(toast, 10)
	stroke(toast, color, 1.5)

	toast.TextTransparency = 1
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), {
		TextTransparency = 0,
		BackgroundTransparency = 0.15,
	}):Play()

	task.delay(duration or 2.5, function()
		local tw = TweenService:Create(toast, TweenInfo.new(0.25), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		tw:Play()
		tw.Completed:Wait()
		toast:Destroy()
	end)
end

function GameUI.ShowResults(placements: { any })
	resultsFrame.Visible = true
	local list = resultsFrame.Card.List
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local medals = { "1st", "2nd", "3rd" }
	local colors = {
		Color3.fromRGB(255, 215, 60),
		Color3.fromRGB(200, 210, 230),
		Color3.fromRGB(220, 140, 80),
	}

	if #placements == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Font = Enum.Font.GothamMedium
		empty.TextSize = 18
		empty.TextColor3 = Color3.fromRGB(180, 180, 200)
		empty.Text = "No finishers this round"
		empty.Parent = list
	end

	for i, entry in ipairs(placements) do
		if i > 8 then
			break
		end
		local row = Instance.new("TextLabel")
		row.BackgroundColor3 = Color3.fromRGB(24, 26, 48)
		row.BackgroundTransparency = 0.2
		row.Size = UDim2.new(1, 0, 0, 36)
		row.Font = Enum.Font.GothamBold
		row.TextSize = 18
		row.TextColor3 = colors[i] or Color3.fromRGB(220, 220, 255)
		local place = medals[entry.Place] or ("#" .. tostring(entry.Place))
		row.Text = string.format("%s  %s  —  %s", place, entry.Name, formatTime(entry.Time or 0))
		row.Parent = list
		corner(row, 8)
	end
end

function GameUI.HideResults()
	resultsFrame.Visible = false
end

function GameUI.SetSpectateHint(text: string?, visible: boolean?)
	spectateLabel.Visible = visible ~= false and text ~= nil and text ~= ""
	spectateLabel.Text = text or ""
end

function GameUI.FlashCountdown(n: number)
	local flash = Instance.new("TextLabel")
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.45)
	flash.Size = UDim2.fromOffset(200, 200)
	flash.BackgroundTransparency = 1
	flash.Font = Enum.Font.GothamBlack
	flash.TextSize = 120
	flash.TextColor3 = if n <= 0 then Color3.fromRGB(80, 255, 160) else Color3.fromRGB(255, 255, 255)
	flash.TextStrokeTransparency = 0.4
	flash.Text = if n <= 0 then "GO!" else tostring(n)
	flash.Parent = gui
	flash.TextTransparency = 0
	local tw = TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextSize = 160,
	})
	tw:Play()
	tw.Completed:Connect(function()
		flash:Destroy()
	end)
end

return GameUI
