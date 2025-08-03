-- DestructionHandler.luau
-- Shared module for handling destruction of planets and emeralds with different effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DestructionHandler = {}

-- Configuration for different object types
local OBJECT_CONFIGS = {
	PLANET = {
		collectibleAsset = "Coin", -- Asset in ReplicatedStorage
		destructionSoundId = "rbxassetid://8044058354", -- Replace with actual ID
		collectionSoundId = "rbxassetid://6792279908", -- Replace with actual ID
		particleTexture = "rbxassetid://2122546039", -- Replace with actual ID
		particleColor = Color3.fromRGB(140, 140, 140), -- Gold color for coins
		collectibleColor = BrickColor.new("Bright yellow"),
		collectibleSize = Vector3.new(5, 5, 5),
		debrisLibraryName = "PlanetMeshLibrary" -- Debris library for planets
	},
	EMERALD = {
		collectibleAsset = "Star Crystal", -- Asset in ReplicatedStorage
		destructionSoundId = "rbxassetid://9114591322", -- Replace with actual ID
		collectionSoundId = "rbxassetid://9113397040", -- Replace with actual ID
		particleTexture = "rbxassetid://243728166", -- Replace with actual ID
		particleColor = Color3.fromRGB(85, 255, 127), -- Emerald green
		collectibleColor = BrickColor.new("Bright green"),
		collectibleSize = Vector3.new(5, 5, 5),
		debrisLibraryName = "CrystalMeshLibrary" -- Debris library for emeralds
	}
}

-- Table to track active collectibles and their target player
local activeCollectibles = {}

-- Heartbeat loop to magnetize collectibles toward their player
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function(dt)
	for i = #activeCollectibles, 1, -1 do
		local entry = activeCollectibles[i]
		local collectible = entry.collectible
		local player = entry.player
		local objectType = entry.objectType

		if collectible and collectible.Parent and player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = player.Character.HumanoidRootPart
			local direction = (hrp.Position - collectible.Position)
			local distance = direction.Magnitude
			if distance < 5 then -- Collect if close enough
				-- Play collection sound
				local collectionSound = Instance.new("Sound")
				collectionSound.SoundId = OBJECT_CONFIGS[objectType].collectionSoundId
				collectionSound.Volume = 0.2
				collectionSound.PlayOnRemove = true
				collectionSound.Parent = workspace
				collectionSound:Destroy()

				-- Award points
				local awardEvent = ReplicatedStorage:FindFirstChild("AwardPointEvent")
				if awardEvent then
					awardEvent:FireServer(1)
				end

				collectible:Destroy()
				table.remove(activeCollectibles, i)
			else
				-- Move toward player (lerp velocity for smoothness)
				local speed = math.clamp(20 / math.max(distance, 1), 50, 75) -- Faster when far, slower when close
				local newVel = direction.Unit * speed
				collectible.AssemblyLinearVelocity = collectible.AssemblyLinearVelocity:Lerp(newVel, 0.15)
			end
		else
			-- Clean up if collectible or player is gone
			table.remove(activeCollectibles, i)
		end
	end
end)

-- Function to determine object type based on parent folder
local function getObjectType(hitPart)
	-- Check if the part is in the LocalPlanets folder (planets)
	if hitPart.Parent and hitPart.Parent.Name == "LocalPlanets" then
		return "PLANET"
		-- Check if the part is in the Emeralds folder (emeralds)
	elseif hitPart.Parent and hitPart.Parent.Name == "Emeralds" then
		return "EMERALD"
		-- Check if the part is a planet collectible
	elseif hitPart.Name == "PlanetCollectible" then
		return "PLANET"
		-- Check if the part is an emerald asset
	elseif hitPart.Name == "emerald" or hitPart.Name:find("emerald") then
		return "EMERALD"
	else
		-- Default to planet if we can't determine
		return "PLANET"
	end
end

-- Function to handle destruction effects
function DestructionHandler.handleDestruction(hitPart, player)
	if not hitPart or not hitPart:IsA("BasePart") then
		return
	end

	local objectType = getObjectType(hitPart)
	local config = OBJECT_CONFIGS[objectType]
	
	-- Calculate size scale based on the destroyed object's size
	local objectSize = hitPart.Size
	local sizeScale = (objectSize.X + objectSize.Y + objectSize.Z) / 3 -- Average size
	local normalizedScale = math.clamp(sizeScale / 10, 0.5, 3.0) -- Scale between 0.5x and 3x

	-- Play destruction sound
	local destructionSound = Instance.new("Sound")
	destructionSound.SoundId = config.destructionSoundId
	destructionSound.Volume = 0.5
	destructionSound.PlayOnRemove = true
	destructionSound.Parent = workspace
	destructionSound:Destroy()

	-- Create particle effect with size based on object size
	local tempPart = Instance.new("Part")
	tempPart.Size = Vector3.new(1, 1, 1)
	tempPart.CFrame = hitPart.CFrame
	tempPart.Anchored = true
	tempPart.CanCollide = false
	tempPart.CanTouch = false
	tempPart.CanQuery = false
	tempPart.Transparency = 1
	tempPart.Parent = workspace

	local particle = Instance.new("ParticleEmitter")
	particle.Texture = config.particleTexture
	particle.Color = ColorSequence.new(config.particleColor)
	particle.Size = NumberSequence.new(20 * normalizedScale) -- Scale particle size
	particle.RotSpeed = NumberRange.new(70, 150)
	particle.Shape = Enum.ParticleEmitterShape.Sphere
	particle.Lifetime = NumberRange.new(4, 4)
	particle.Rate = 1
	particle.Speed = NumberRange.new(5 * normalizedScale, 15 * normalizedScale) -- Scale particle speed
	particle.Parent = tempPart

	particle:Emit(2)
	game.Debris:AddItem(tempPart, 4)

	-- Create debris effect using the appropriate library
	local debrisLibrary = ReplicatedStorage:WaitForChild(config.debrisLibraryName)
	if debrisLibrary then
		for _, meshTemplate in ipairs(debrisLibrary:GetChildren()) do
			if meshTemplate:IsA("MeshPart") then
				local debris = meshTemplate:Clone()
				debris.CFrame = hitPart.CFrame * CFrame.new(
					math.random(-2, 2),
					math.random(-1, 2),
					math.random(-2, 2)
				)
				
				-- Scale debris size based on object size
				debris.Size = debris.Size * normalizedScale
				
				debris.Anchored = false
				debris.CanCollide = false
				debris.CanQuery = false
				debris.CanTouch = false
				debris.Parent = workspace

				-- Add physics
				local attachment = Instance.new("Attachment", debris)

				local vectorForce = Instance.new("VectorForce")
				vectorForce.Attachment0 = attachment
				vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
				vectorForce.Force = Vector3.new(0, debris:GetMass() * workspace.Gravity, 0)
				vectorForce.Parent = debris

				-- Scale velocity based on object size
				local velocityScale = math.clamp(normalizedScale, 0.5, 2.0)
				debris.AssemblyLinearVelocity = Vector3.new(
					math.random(-15, 15) * velocityScale,
					math.random(5, 15) * velocityScale,
					math.random(-15, 15) * velocityScale
				)

				local angularVelocity = Instance.new("BodyAngularVelocity")
				angularVelocity.AngularVelocity = Vector3.new(
					math.random(), math.random(), math.random()
				) * 10 * velocityScale
				angularVelocity.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
				angularVelocity.Parent = debris

				game.Debris:AddItem(debris, 5)
			end
		end
	end

	-- Spawn collectibles
	local volume = hitPart.Size.X * hitPart.Size.Y * hitPart.Size.Z
	local numberOfCollectibles = math.clamp(math.floor(volume / 20), 1, 20)

	for i = 1, numberOfCollectibles do
		local collectible

		-- Try to use the asset from ReplicatedStorage first
		local collectibleAsset = ReplicatedStorage:FindFirstChild(config.collectibleAsset)
		if collectibleAsset then
			collectible = collectibleAsset:Clone()
		else
			-- Fallback to creating a basic part
			collectible = Instance.new("Part")
			collectible.Name = "CollectiblePoint"
			collectible.Shape = Enum.PartType.Ball
			collectible.Size = config.collectibleSize
			collectible.BrickColor = config.collectibleColor
		end

		collectible.Position = hitPart.Position + Vector3.new(
			math.random(-6, 6),
			2 + math.random(0, 2),
			math.random(-6, 6)
		)
		collectible.AssemblyLinearVelocity = Vector3.new(
			math.random(-350, 350),
			math.random(-350, 350),
			math.random(-350, 350)
		)
		collectible.Anchored = false
		collectible.CanCollide = false
		collectible.CanQuery = false
		collectible.Parent = workspace

		-- Track this collectible and its player for magnetization
		table.insert(activeCollectibles, {
			collectible = collectible, 
			player = player, 
			objectType = objectType
		})

		game.Debris:AddItem(collectible, 10)
	end

	-- Destroy the original part
	hitPart:Destroy()
end

return DestructionHandler 