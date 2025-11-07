--WallstickClient.lua
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPackages = ReplicatedStorage.SharedPackages
local RaycastHelper = require(SharedPackages.RaycastHelper)
local OmniRaycast = require(ReplicatedStorage.OmniRaycast)

local WallstickClass = require(ReplicatedStorage.Wallstick)
local SprintController = require(ReplicatedStorage.Wallstick.SprintController)

-- Track when planet destructions occur
local lastPlanetDestructionTime = 0
local EXTENDED_RADIUS_DURATION = 3 -- seconds to use extended radius after planet destruction

-- Multi-raycast configuration
local MULTI_RAY_CONFIG = {
	rayCount = 8, -- Number of rays to cast in a circle
	circleRadius = 2, -- Radius of the circle around the player (in studs)
	rayDistance = 10, -- Distance each ray travels (in studs)
	minHitCount = 3, -- Minimum number of hits required to use averaged normal
	normalDotThreshold = 0.7, -- Minimum dot product for normals to be considered similar
}

-- Store previous normal for smoothing
local lastValidNormal = Vector3.yAxis
local normalSmoothingFactor = 0.3 -- How much to smooth between frames (0-1, lower = more smoothing)

-- Listen for planet destructions
local function onPlanetDestroyed()
	lastPlanetDestructionTime = tick()
end

-- Connect to destruction events (you'll need to fire this from your DestructionHandler)
local destructionEvent = ReplicatedStorage:FindFirstChild("PlanetDestructionEvent")
if not destructionEvent then
	destructionEvent = Instance.new("RemoteEvent")
	destructionEvent.Name = "PlanetDestructionEvent"
	destructionEvent.Parent = ReplicatedStorage
end
destructionEvent.OnClientEvent:Connect(onPlanetDestroyed)

-- Function to cast multiple rays in a circle around the player and average normals
local function castMultiRayCircle(character: Model, rayCount: number, rayDistance: number, circleRadius: number): {
	validHits: {{
		Instance: Instance,
		Position: Vector3,
		Normal: Vector3,
		Distance: number,
		Material: Enum.Material,
		RayOrigin: Vector3,
	}},
	averageNormal: Vector3,
	closestHit: {
		Instance: Instance,
		Position: Vector3,
		Normal: Vector3,
		Distance: number,
		Material: Enum.Material,
		RayOrigin: Vector3,
	},
	hitCount: number,
	similarCount: number,
}?
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	local hrp = humanoid and humanoid.RootPart :: BasePart
	local hrpCF = hrp.CFrame
	
	local rayParams = RaycastHelper.params({
		filterType = Enum.RaycastFilterType.Exclude,
		instances = { character :: Instance },
	})
	
	local validHits = {}
	local similarNormals = {}
	local hitCount = 0
	
	-- Cast rays in a circle around the player
	for i = 1, rayCount do
		local angle = (i - 1) * (2 * math.pi / rayCount)
		local offset = Vector3.new(
			math.cos(angle) * circleRadius,
			0,
			math.sin(angle) * circleRadius
		)
		
		local rayOrigin = hrpCF.Position + hrpCF:VectorToWorldSpace(offset)
		local rayDirection = -hrpCF.YVector * rayDistance
		
		local result = RaycastHelper.raycast({
			origin = rayOrigin,
			direction = rayDirection,
			rayParams = rayParams,
		})
		
		if result then
			table.insert(validHits, {
				Instance = result.Instance,
				Position = result.Position,
				Normal = result.Normal,
				Distance = result.Distance,
				Material = result.Material,
				RayOrigin = rayOrigin
			})
			hitCount = hitCount + 1
		end
	end
	
	-- If we don't have enough hits, return nil to fall back to single raycast
	if hitCount < MULTI_RAY_CONFIG.minHitCount then
		return nil
	end
	
	-- Find the most common surface by grouping similar normals
	local referenceNormal = validHits[1].Normal
	local totalNormal = Vector3.zero
	local similarCount = 0
	
	for _, hit in validHits do
		-- Check if this normal is similar to our reference normal
		local dotProduct = math.abs(hit.Normal:Dot(referenceNormal))
		if dotProduct >= MULTI_RAY_CONFIG.normalDotThreshold then
			totalNormal = totalNormal + hit.Normal
			similarCount = similarCount + 1
		end
	end
	
	-- If we don't have enough similar normals, use the closest hit's normal
	local averageNormal
	if similarCount >= MULTI_RAY_CONFIG.minHitCount then
		averageNormal = (totalNormal / similarCount).Unit
	else
		-- Fall back to using the closest hit's normal
		local closestHit = validHits[1]
		local closestDistance = closestHit.Distance
		
		for _, hit in validHits do
			if hit.Distance < closestDistance then
				closestDistance = hit.Distance
				closestHit = hit
			end
		end
		averageNormal = closestHit.Normal
	end
	
	-- Smooth the normal with the previous frame's normal
	averageNormal = lastValidNormal:Lerp(averageNormal, normalSmoothingFactor).Unit
	lastValidNormal = averageNormal
	
	-- Find the closest hit for position reference
	local closestHit = validHits[1]
	local closestDistance = closestHit.Distance
	
	for _, hit in validHits do
		if hit.Distance < closestDistance then
			closestDistance = hit.Distance
			closestHit = hit
		end
	end
	
	return {
		validHits = validHits,
		averageNormal = averageNormal,
		closestHit = closestHit,
		hitCount = hitCount,
		similarCount = similarCount
	}
end

local function findBestStickSurface(character: Model)
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	local hrp = humanoid and humanoid.RootPart :: BasePart

	local hrpCF = hrp.CFrame

	-- Determine radius based on recent planet destruction
	local currentTime = tick()
	local timeSinceDestruction = currentTime - lastPlanetDestructionTime
	local radius = (timeSinceDestruction <= EXTENDED_RADIUS_DURATION) and 200 or 75

	local hits = OmniRaycast.sphereCast(hrpCF.Position, {
		rayCount = 3600,
		radius = radius,
		excludeInstances = {character :: Instance, workspace:FindFirstChild("Emeralds")},
	})

	-- Find the closest surface
	local bestHit = nil
	local closestDistance = math.huge

	for _, hit in hits do
		local distance = hit.Distance
		if distance < closestDistance then
			closestDistance = distance
			bestHit = hit
		end
	end

	return bestHit
end

local function onCharacterAdded(character: Model)
	local wallstick = WallstickClass.new({
		parent = workspace:WaitForChild("Wallstick"),
		origin = CFrame.new(2000, 0, 0),
		retainWorldVelocity = true,
		camera = {
			tilt = true,
			spin = true,
		},
	})

	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	local hrp = humanoid and humanoid.RootPart :: BasePart

	-- Initialize sprint controller with real and fake humanoids
	SprintController.init(humanoid, wallstick.fake.humanoid)

	local LARGE_COOLDOWN = 0.00
	local cooldownLeft = 0.00

	local simulationConnection = RunService.PreSimulation:Connect(function(_dt)

		if cooldownLeft > 0 then
			cooldownLeft -= _dt
		end 

		--[[
		if wallstick:getFallDistance() < -75 then
			wallstick:set(workspace.Terrain, Vector3.yAxis)
			return
		end
		]]

		local rayParams = RaycastHelper.params({
			filterType = Enum.RaycastFilterType.Exclude,
			instances = { character :: Instance },
		})

		local hipHeight = humanoid.HipHeight
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			hipHeight = 2
		end

		local hrpCF = hrp.CFrame
		local rayDistance = hipHeight + hrp.Size.Y / 2 + 0.1
		
		-- Try multi-raycast system first
		local multiRayResult = castMultiRayCircle(character, MULTI_RAY_CONFIG.rayCount, rayDistance, MULTI_RAY_CONFIG.circleRadius)
		
		if multiRayResult then
			-- Use the closest hit for position and part reference
			local closestHit = multiRayResult.closestHit
			local stickPart = (closestHit.Instance :: BasePart).AssemblyRootPart
			
			-- Use the averaged normal for better alignment
			local stickNormal = stickPart.CFrame:VectorToObjectSpace(multiRayResult.averageNormal)

			-- Debug output (uncomment for testing)
			--[[
			print("Multi-Raycast Results:")
			print("- Hit Count:", multiRayResult.hitCount)
			print("- Similar Count:", multiRayResult.similarCount)
			print("- Average Normal:", multiRayResult.averageNormal)
			print("- Closest Distance:", closestHit.Distance)
			print("- Part:", stickPart:GetFullName())
			]]

			wallstick:setAndPivot(stickPart, stickNormal, closestHit.Position)
		else
			-- Fall back to single raycast if multi-raycast doesn't have enough valid hits
			local result = RaycastHelper.raycast({
				origin = hrpCF.Position,
				direction = -rayDistance * hrpCF.YVector,
				rayParams = rayParams,
			})

			if result then
				local stickPart = (result.Instance :: BasePart).AssemblyRootPart
				local stickNormal = stickPart.CFrame:VectorToObjectSpace(result.Normal)

				wallstick:setAndPivot(stickPart, stickNormal, result.Position)
			end
		end

		if wallstick.fake.humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			local bestSurface = findBestStickSurface(character)

			if bestSurface and cooldownLeft <= 0 then

				-- Print detailed information about the surface

				--[[
				print("Best Surface Found:")
				print("- Instance:", bestSurface.Instance:GetFullName())
				print("- Position:", bestSurface.Position)
				print("- Normal:", bestSurface.Normal)
				print("- Distance:", bestSurface.Distance)
				print("- Material:", bestSurface.Material)
				print("------------------------")
				]]

				local stickPart = (bestSurface.Instance :: BasePart).AssemblyRootPart
				local stickNormal = stickPart.CFrame:VectorToObjectSpace(bestSurface.Normal)

				wallstick:rotateKeepingOrigin(stickPart, stickNormal)

				cooldownLeft = LARGE_COOLDOWN

			end
		end
	end)

	humanoid.Died:Wait()
	simulationConnection:Disconnect()
	wallstick:Destroy()
end

assert(not workspace.StreamingEnabled, "Wallstick does not support streaming enabled.")

if Players.LocalPlayer.Character then
	onCharacterAdded(Players.LocalPlayer.Character)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)