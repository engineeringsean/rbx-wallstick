--SimpleSurfaceWalker.lua
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPackages = ReplicatedStorage.SharedPackages
local RaycastHelper = require(SharedPackages.RaycastHelper)

-- Simple surface walking system for mitochondria
local function createSurfaceWalker(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart

	if not hrp then
		warn("No HumanoidRootPart found!")
		return
	end

	-- Store original properties
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower

	-- Movement variables
	local moveVector = Vector3.new(0, 0, 0)
	local isOnSurface = false
	local surfaceNormal = Vector3.new(0, 1, 0)
	local surfacePart = nil

	-- Input handling
	local function onInputBegan(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.W then
			moveVector = moveVector + Vector3.new(0, 0, -1)
		elseif input.KeyCode == Enum.KeyCode.S then
			moveVector = moveVector + Vector3.new(0, 0, 1)
		elseif input.KeyCode == Enum.KeyCode.A then
			moveVector = moveVector + Vector3.new(-1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.D then
			moveVector = moveVector + Vector3.new(1, 0, 0)
		end
	end

	local function onInputEnded(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.W then
			moveVector = moveVector - Vector3.new(0, 0, -1)
		elseif input.KeyCode == Enum.KeyCode.S then
			moveVector = moveVector - Vector3.new(0, 0, 1)
		elseif input.KeyCode == Enum.KeyCode.A then
			moveVector = moveVector - Vector3.new(-1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.D then
			moveVector = moveVector - Vector3.new(1, 0, 0)
		end
	end

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Anchor the HRP to have direct control over its position
	hrp.Anchored = true

	-- Surface detection and movement
	local connection = RunService.Heartbeat:Connect(function()
		local desiredDistance = hrp.Size.Y / 2 + humanoid.HipHeight
		
		-- Raycast from current position toward surface
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {character}

		local rayOrigin = hrp.Position
		-- Use the normal from last frame, or default to down
		local rayDirection = -surfaceNormal * 10

		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)

		if raycastResult then
			-- Re-anchor if we're on surface
			if not hrp.Anchored then
				hrp.Anchored = true
			end
			
			isOnSurface = true
			local newSurfaceNormal = raycastResult.Normal
			surfacePart = raycastResult.Instance

			-- Calculate target position on the surface
			local targetPosition = raycastResult.Position + newSurfaceNormal * desiredDistance

			-- If moving, project movement onto the surface
			if moveVector.Magnitude > 0 then
				-- Project movement vector onto surface plane
				local projectedMove = moveVector - newSurfaceNormal * moveVector:Dot(newSurfaceNormal)
				local moveDirection = projectedMove.Unit
				local moveSpeed = 16 / 60 -- studs per frame
				
				-- Calculate new position by moving along surface
				local potentialPosition = targetPosition + moveDirection * moveSpeed
				
				-- Re-raycast to maintain surface distance
				local reRayDirection = -newSurfaceNormal * 10
				local reRayResult = workspace:Raycast(potentialPosition, reRayDirection, rayParams)
				
				if reRayResult then
					targetPosition = reRayResult.Position + reRayResult.Normal * desiredDistance
					newSurfaceNormal = reRayResult.Normal
				end
				
				-- Align rotation to surface normal and movement direction
				local rightVector = moveDirection:Cross(newSurfaceNormal)
				if rightVector.Magnitude < 0.01 then
					-- If movement is parallel to normal, use a default right vector
					rightVector = Vector3.new(1, 0, 0):Cross(newSurfaceNormal)
				end
				rightVector = rightVector.Unit
				local newRotation = CFrame.fromMatrix(Vector3.zero, rightVector, newSurfaceNormal)
				hrp.CFrame = CFrame.new(targetPosition) * newRotation
			else
				-- Not moving, just align to surface
				-- Keep current forward direction
				local currentLookDirection = hrp.CFrame.LookVector
				local surfaceAlignment = currentLookDirection:Cross(newSurfaceNormal)
				
				if surfaceAlignment.Magnitude > 0.01 then
					local rightVector = surfaceAlignment.Unit
					local newRotation = CFrame.fromMatrix(Vector3.zero, rightVector, newSurfaceNormal)
					hrp.CFrame = CFrame.new(targetPosition) * newRotation
				else
					hrp.CFrame = CFrame.new(targetPosition, targetPosition + newSurfaceNormal)
				end
			end
			
			surfaceNormal = newSurfaceNormal
		else
			isOnSurface = false
			-- When not on surface, temporarily unanchor to let gravity work
			hrp.Anchored = false
		end
	end)

	-- Cleanup when character dies
	humanoid.Died:Connect(function()
		connection:Disconnect()
		UserInputService.InputBegan:Disconnect(onInputBegan)
		UserInputService.InputEnded:Disconnect(onInputEnded)
		hrp.Anchored = false
	end)
	
	-- Initialize surface normal to down for first raycast
	local function initializeFirstRay()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {character}
		
		local initResult = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
		if initResult then
			surfaceNormal = initResult.Normal
		end
	end
	
	initializeFirstRay()
end

-- Initialize the surface walker when character spawns
local function onCharacterAdded(character: Model)
	print("Character added:", character.Name)

	-- Ensure camera follows the character
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	workspace.CurrentCamera.CameraSubject = humanoid

	createSurfaceWalker(character)
end

-- Start the system
if Players.LocalPlayer.Character then
	onCharacterAdded(Players.LocalPlayer.Character)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)