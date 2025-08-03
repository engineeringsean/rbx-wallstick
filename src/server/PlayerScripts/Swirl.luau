-- Swirl Script (LocalScript for StarterCharacterScripts)
-- Activated by pressing "Q" key

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Import the shared destruction handler
local DestructionHandler = require(ReplicatedStorage.SharedPackages.DestructionHandler)

-- Configuration
local SWIRL_ANIMATION_ID = "rbxassetid://122328402461733" -- Replace with your swirl animation ID
local RAYCAST_COUNT = 12 -- Number of raycasts in the circle
local RAYCAST_DISTANCE = 4 -- How far each raycast goes
local COOLDOWN_TIME = 0.2 -- Seconds between uses

local isOnCooldown = false
local animationTrack = nil

-- Collectible tracking is now handled by the shared DestructionHandler

-- Load the swirl animation
local function loadSwirlAnimation()
	local animation = Instance.new("Animation")
	animation.AnimationId = SWIRL_ANIMATION_ID

	animationTrack = humanoid:LoadAnimation(animation)
	animationTrack.Priority = Enum.AnimationPriority.Action
	animationTrack.Looped = false
end

-- Perform circular raycasts around the player
local function performCircularRaycasts()
	local origin = humanoidRootPart.Position
	local results = {}
	
	-- Local up vector (e.g., normal to surface)
	local upVector = humanoidRootPart.CFrame.UpVector
	
	-- Generate an orthonormal basis (right and forward vectors perpendicular to up)
	local rightVector = humanoidRootPart.CFrame.RightVector
	local forwardVector = humanoidRootPart.CFrame.LookVector

	for i = 1, RAYCAST_COUNT do
		local angle = (i - 1) * (2 * math.pi / RAYCAST_COUNT)
		-- Rotate within the plane perpendicular to upVector
		local direction = (rightVector * math.cos(angle) + forwardVector * math.sin(angle)).Unit

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {character}

		local result = workspace:Raycast(origin, direction * RAYCAST_DISTANCE, raycastParams)

		if result then
			table.insert(results, result)
		end
	end

	return results
end

-- Destroy objects hit by raycasts using shared handler
local function destroyHitObjects(results)
	for _, result in ipairs(results) do
		local hitPart = result.Instance

		if hitPart and hitPart:IsA("BasePart") then
			-- Use the shared destruction handler
			DestructionHandler.handleDestruction(hitPart, player)
		end
	end
end

local function getFakeChar()
	local wallstickFolder = workspace:FindFirstChild("Wallstick")
	return wallstickFolder and wallstickFolder:FindFirstChild(player.Name)
end

local function getFakeHumanoidAndRoot()
	local fakeChar = getFakeChar()
	if not fakeChar then return nil, nil end
	local fakeHumanoid = fakeChar:FindFirstChildOfClass("Humanoid")
	local fakeRoot = fakeChar:FindFirstChild("HumanoidRootPart")
	return fakeHumanoid, fakeRoot
end

local function getUpVector()
	local _, fakeRoot = getFakeHumanoidAndRoot()
	if fakeRoot then
		return fakeRoot.CFrame.UpVector
	end
end

local function isFakeInFreefall(): boolean
	local fakeHumanoid, _ = getFakeHumanoidAndRoot()
	if not fakeHumanoid then
		return false
	end
	return fakeHumanoid:GetState() == Enum.HumanoidStateType.Freefall
end

-- Main swirl function
local function performSwirl()
	if isOnCooldown then
		return
	end

	isOnCooldown = true
	
	local fakeHumanoid, fakeRoot = getFakeHumanoidAndRoot()
	if not (fakeHumanoid and fakeRoot) then return end

	-- Play animation
	if animationTrack then
		animationTrack:Play()
	end

	-- Wait a bit for animation to start
	wait(0.1)
	
	if isFakeInFreefall() then
		local up = getUpVector()
		if up and fakeRoot then
			fakeRoot.AssemblyLinearVelocity = up * 500
		end
	end

	-- Perform raycasts and destroy objects
	local results = performCircularRaycasts()
	destroyHitObjects(results)

	-- Wait for animation to finish
	if animationTrack then
		animationTrack.Stopped:Wait()
	end

	-- Reset cooldown
	wait(COOLDOWN_TIME - 0.1)
	isOnCooldown = false
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		performSwirl()
	end
end)

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	-- Reload animation for new character
	loadSwirlAnimation()
end)

-- Initial setup
loadSwirlAnimation() 