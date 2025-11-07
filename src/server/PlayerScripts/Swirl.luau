-- Swirl Script (LocalScript for StarterCharacterScripts)
-- Activated by pressing "E" key (now supports holding)

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
local SWIRL_ANIMATION_ID = "rbxassetid://99813553277327"
local RAYCAST_COUNT = 12
local RAYCAST_DISTANCE = 4
local COOLDOWN_TIME = 0.0

local isOnCooldown = false
local animationTrack = nil
local isHoldingE = false
local swirlCoroutine = nil

local function createTrailInHand(hand)
	local attach0 = Instance.new("Attachment")
	attach0.Name = "TrailAttachment0"
	attach0.Position = Vector3.new(0, 0.5, 0)
	attach0.Parent = hand

	local attach1 = Instance.new("Attachment")
	attach1.Name = "TrailAttachment1"
	attach1.Position = Vector3.new(0, -0.5, 0)
	attach1.Parent = hand

	local trail = Instance.new("Trail")
	trail.Name = "SpinTrail"
	trail.Attachment0 = attach0
	trail.Attachment1 = attach1
	trail.Color = ColorSequence.new(Color3.fromRGB(0, 170, 255))
	trail.WidthScale = NumberSequence.new(0.5)
	trail.LightEmission = 1
	trail.Lifetime = 0.4
	trail.Enabled = false
	trail.Parent = hand

	return trail
end

local function setupTrail()
	local rightHand = character:WaitForChild("RightHand", 3)
	if not rightHand then return end

	-- Check if trail already exists, if not create it
	local trail = rightHand:FindFirstChild("SpinTrail")
	if not trail then
		trail = createTrailInHand(rightHand)
	end

	return trail
end

-- Load the swirl animation
local function loadSwirlAnimation()
	local animation = Instance.new("Animation")
	animation.AnimationId = SWIRL_ANIMATION_ID

	animationTrack = humanoid:LoadAnimation(animation)
	animationTrack.Priority = Enum.AnimationPriority.Action
	animationTrack.Looped = false

	-- Set up trail when animation is loaded
	setupTrail()
end

-- Perform circular raycasts around the player
local function performCircularRaycasts()
	local origin = humanoidRootPart.Position
	local results = {}
	local hitParts = {}

	local upVector = humanoidRootPart.CFrame.UpVector
	local rightVector = humanoidRootPart.CFrame.RightVector
	local forwardVector = humanoidRootPart.CFrame.LookVector

	for i = 1, RAYCAST_COUNT do
		local angle = (i - 1) * (2 * math.pi / RAYCAST_COUNT)
		local direction = (rightVector * math.cos(angle) + forwardVector * math.sin(angle)).Unit

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {character}

		local result = workspace:Raycast(origin, direction * RAYCAST_DISTANCE, raycastParams)

		if result and result.Instance and not hitParts[result.Instance] then
			hitParts[result.Instance] = true
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

-- Single swirl execution
local function performSingleSwirl()
	local fakeHumanoid, fakeRoot = getFakeHumanoidAndRoot()
	if not (fakeHumanoid and fakeRoot) then
		return false
	end

	-- Play animation
	if animationTrack then
		animationTrack:Play()

		-- Enable trail after a short delay
		task.delay(0.1, function()
			local rightHand = character:FindFirstChild("RightHand")
			if rightHand then
				local trail = rightHand:FindFirstChild("SpinTrail")
				if trail and not trail.Enabled then
					trail.Enabled = true

					task.delay(0.3, function()
						if trail then
							trail.Enabled = false
						end
					end)
				end
			end
		end)
	end

	-- Wait a bit for animation to start
	--wait(0.1)

	if isFakeInFreefall() then
		local up = getUpVector()
		if up and fakeRoot then
			fakeRoot.AssemblyLinearVelocity = up * 75
		end
	end

	local duration = 0.5
	local elapsed = 0

	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		-- Perform raycasts and destroy objects
		local results = performCircularRaycasts()
		destroyHitObjects(results)
	end

	return true
end

-- Continuous swirl loop while holding E
local function startContinuousSwirl()
	swirlCoroutine = coroutine.create(function()
		while isHoldingE do
			if not isOnCooldown then
				isOnCooldown = true

				local success = performSingleSwirl()

				-- Wait for cooldown
				wait(COOLDOWN_TIME)
				isOnCooldown = false

				-- If the swirl failed (fake character not found), break the loop
				if not success then
					break
				end
			else
				wait(0.1)
			end
		end
	end)

	coroutine.resume(swirlCoroutine)
end

-- Stop continuous swirl
local function stopContinuousSwirl()
	isHoldingE = false
	if swirlCoroutine then
		swirlCoroutine = nil
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.E then
		if not isHoldingE then
			isHoldingE = true
			startContinuousSwirl()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		stopContinuousSwirl()
	end
end)

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	-- Stop any ongoing swirl
	stopContinuousSwirl()

	-- Reload animation for new character
	loadSwirlAnimation()
end)

-- Initial setup
loadSwirlAnimation()