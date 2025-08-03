--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPackages = ReplicatedStorage.SharedPackages
local RaycastHelper = require(SharedPackages.RaycastHelper)
local OmniRaycast = require(ReplicatedStorage.OmniRaycast)

local WallstickClass = require(ReplicatedStorage.Wallstick)
local SprintController = require(ReplicatedStorage.Wallstick.SprintController)


local function findBestStickSurface(character: Model)
	local humanoid = character and character:WaitForChild("Humanoid") :: Humanoid
	local hrp = humanoid and humanoid.RootPart :: BasePart

	local hrpCF = hrp.CFrame

	local hits = OmniRaycast.sphereCast(hrpCF.Position, {
		rayCount = 3600,
		radius = 300,
		excludeInstances = {character :: Instance},
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
		
		if wallstick:getFallDistance() < -75 then
			wallstick:set(workspace.Terrain, Vector3.yAxis)
			return
		end
		
		local rayParams = RaycastHelper.params({
			filterType = Enum.RaycastFilterType.Exclude,
			instances = { character :: Instance },
		})

		local hipHeight = humanoid.HipHeight
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			hipHeight = 2
		end

		local hrpCF = hrp.CFrame
		local result = RaycastHelper.raycast({
			origin = hrpCF.Position,
			direction = -(hipHeight + hrp.Size.Y / 2 + 0.1) * hrpCF.YVector,
			rayParams = rayParams,
		})
		
		if result then
			local stickPart = (result.Instance :: BasePart).AssemblyRootPart
			local stickNormal = stickPart.CFrame:VectorToObjectSpace(result.Normal)

			wallstick:setAndPivot(stickPart, stickNormal, result.Position)

		elseif wallstick.fake.humanoid:GetState() == Enum.HumanoidStateType.Freefall then
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
