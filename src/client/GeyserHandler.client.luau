-- StarterPlayerScripts/GeyserHandler.client.luau (LocalScript)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local JUMP_POWER = 100 -- Adjust this value to control jump height
local COOLDOWN_TIME = 1.0 -- Cooldown between jumps in seconds
local PROXIMITY_RADIUS = 4 -- How close the character needs to be to trigger (in studs)

local BOUNCER_POWER = 50 -- Adjust this value to control bouncer height
local BOUNCER_COOLDOWN_TIME = 0.5 -- Cooldown between bouncer activations in seconds
local BOUNCER_PROXIMITY_RADIUS = 5 -- How close the character needs to be to trigger bouncer (in studs)

local lastJumpTime = 0
local lastBouncerTime = 0

-- Wait for the geysers folder to be created by PlanetFieldGeneratorModule
local geysersFolder = workspace:WaitForChild("Geysers")

-- Function to safely get geysers folder
local function getGeysersFolder()
	if not geysersFolder or not geysersFolder.Parent then
		geysersFolder = workspace:FindFirstChild("Geysers")
	end
	return geysersFolder
end

-- Function to apply jump velocity to fake character (relative to character orientation)
local function applyJumpVelocity()
	local currentTime = tick()
	
	-- Check cooldown
	if currentTime - lastJumpTime < COOLDOWN_TIME then
		return
	end
	
	-- Find the fake character in the Wallstick folder
	local wallstickFolder = workspace:WaitForChild("Wallstick")
	local fakeChar = wallstickFolder:FindFirstChild(Players.LocalPlayer.Name)
	
	if fakeChar then
		local fakeRoot = fakeChar:FindFirstChild("HumanoidRootPart")
		if fakeRoot then
			-- Calculate upward velocity relative to fake character's orientation (like Swirl script)
			local characterUp = fakeRoot.CFrame.UpVector
			local jumpVelocity = characterUp * JUMP_POWER
			
			-- Debug: Print velocity information
			print("Jump triggered!")
			print("Fake character up vector:", characterUp)
			print("Jump velocity:", jumpVelocity)
			print("Jump power:", JUMP_POWER)
			
			-- Apply the jump velocity
			fakeRoot.AssemblyLinearVelocity = jumpVelocity
			lastJumpTime = currentTime
			
			-- Optional: Play a sound effect
			local jumpSound = Instance.new("Sound")
			jumpSound.SoundId = "rbxasset://sounds/swoosh.wav"
			jumpSound.Volume = 0.5
			jumpSound.Parent = fakeRoot
			jumpSound:Play()
			game:GetService("Debris"):AddItem(jumpSound, 1)
		end
	end
end

-- Function to apply bouncer velocity to fake character (relative to character orientation)
local function applyBouncerVelocity()
	local currentTime = tick()
	
	-- Check cooldown
	if currentTime - lastBouncerTime < BOUNCER_COOLDOWN_TIME then
		return
	end
	
	-- Find the fake character in the Wallstick folder
	local wallstickFolder = workspace:WaitForChild("Wallstick")
	local fakeChar = wallstickFolder:FindFirstChild(Players.LocalPlayer.Name)
	
	if fakeChar then
		local fakeRoot = fakeChar:FindFirstChild("HumanoidRootPart")
		if fakeRoot then
			-- Calculate upward velocity relative to fake character's orientation (like Swirl script)
			local characterUp = fakeRoot.CFrame.UpVector
			local bouncerVelocity = characterUp * BOUNCER_POWER
			
			-- Debug: Print velocity information
			print("Bouncer triggered!")
			print("Fake character up vector:", characterUp)
			print("Bouncer velocity:", bouncerVelocity)
			print("Bouncer power:", BOUNCER_POWER)
			
			-- Apply the bouncer velocity
			fakeRoot.AssemblyLinearVelocity = bouncerVelocity
			lastBouncerTime = currentTime
			
			-- Optional: Play a sound effect
			local bouncerSound = Instance.new("Sound")
			bouncerSound.SoundId = "rbxasset://sounds/swoosh.wav"
			bouncerSound.Volume = 0.3
			bouncerSound.Parent = fakeRoot
			bouncerSound:Play()
			game:GetService("Debris"):AddItem(bouncerSound, 1)
		end
	end
end

-- Function to check proximity and trigger effects
local function checkProximityAndTrigger()
	-- Get the real character for proximity detection
	local realChar = Players.LocalPlayer.Character
	local realRoot = realChar and realChar:FindFirstChild("HumanoidRootPart")
	
	if realRoot then
		local triggeredJump = false
		local triggeredBouncer = false
		
		-- Check all geysers in the geysers folder
		local currentGeysersFolder = getGeysersFolder()
		if currentGeysersFolder then
			for _, geyser in pairs(currentGeysersFolder:GetChildren()) do
				if geyser:IsA("BasePart") or geyser:IsA("Model") then
					-- Check for JumpPart within the geyser
					local jumpPart = geyser:FindFirstChild("JumpPart")
					if jumpPart and not triggeredJump then
						local jumpDistance = (realRoot.Position - jumpPart.Position).Magnitude
						if jumpDistance <= PROXIMITY_RADIUS then
							applyJumpVelocity()
							triggeredJump = true
						end
					end
					
					-- Check for bouncer part within the geyser
					local bouncer = geyser:FindFirstChild("Bouncer")
					if bouncer and not triggeredBouncer then
						local bouncerDistance = (realRoot.Position - bouncer.Position).Magnitude
						if bouncerDistance <= BOUNCER_PROXIMITY_RADIUS then
							applyBouncerVelocity()
							triggeredBouncer = true
						end
					end
				end
			end
		end
	end
end

-- Connect to RunService to check proximity every frame
local proximityConnection = RunService.Heartbeat:Connect(checkProximityAndTrigger)

-- Clean up connection when script is destroyed
script.Destroying:Connect(function()
	if proximityConnection then
		proximityConnection:Disconnect()
	end
end)
