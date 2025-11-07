-- DestructionHandler.lua (Client Version)
-- Shared module for handling destruction of planets and emeralds with different effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlanetFieldGenerator = require(ReplicatedStorage:WaitForChild("PlanetFieldGeneratorModule"))

local DestructionHandler = {}

-- Create or get the planet destruction event
local destructionEvent = ReplicatedStorage:FindFirstChild("PlanetDestructionEvent")
if not destructionEvent then
	destructionEvent = Instance.new("RemoteEvent")
	destructionEvent.Name = "PlanetDestructionEvent"
	destructionEvent.Parent = ReplicatedStorage
end

-- Configuration for different object types
local OBJECT_CONFIGS = {
	PLANET = {
		collectibleAsset = "Coin", -- Asset in ReplicatedStorage
		destructionSoundId = "rbxassetid://8044058354", -- Replace with actual ID
		collectionSoundId = "rbxassetid://6792279908", -- Replace with actual ID
		particleTexture = "rbxassetid://2122546039", -- Replace with actual ID
		particleColor = Color3.fromRGB(140, 140, 140), -- Grey color for rocks
		collectibleColor = BrickColor.new("Bright yellow"),
		collectibleSize = Vector3.new(5, 5, 5),
		debrisLibraryName = "PlanetMeshLibrary" -- Debris library for planets
	},
	EMERALD = {
		collectibleAsset = "Star Crystal", -- Asset in ReplicatedStorage
		destructionSoundId = "rbxassetid://9114591322", -- Replace with actual ID
		collectionSoundId = "rbxassetid://9113397040", -- Replace with actual ID
		particleTexture = "rbxassetid://298984512", -- Replace with actual ID
		particleColor = Color3.fromRGB(255, 255, 255), -- white
		collectibleColor = BrickColor.new("Bright green"),
		collectibleSize = Vector3.new(8, 8, 8),
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

			if distance < 5 then
				local collectionSound = Instance.new("Sound")
				collectionSound.SoundId = OBJECT_CONFIGS[objectType].collectionSoundId
				collectionSound.Volume = 0.2
				collectionSound.PlayOnRemove = true
				collectionSound.Parent = workspace
				collectionSound:Destroy()

				local awardEvent = ReplicatedStorage:FindFirstChild("AwardCollectibleEvent")
				if awardEvent then
					local collectibleType = (objectType == "PLANET") and "COIN" or "CRYSTAL"
					awardEvent:FireServer(collectibleType, 1)
				end

				collectible:Destroy()
				table.remove(activeCollectibles, i)
			else
				-- Keep ETA ~1–3s regardless of distance
				-- 150 studs/sec is the "neutral" speed where ETA ~= distance/150
				local targetTime = math.clamp(distance / 150, 1, 3)
				local desiredSpeed = distance / targetTime

				-- Optional: protect against absurd speeds if your map is huge
				desiredSpeed = math.clamp(desiredSpeed, 75, 2000)

				local newVel = direction.Unit * desiredSpeed

				-- Framerate-independent smoothing (similar to Lerp(..., ~0.15) at 60fps)
				local blend = 1 - math.exp(-10 * dt)
				collectible.AssemblyLinearVelocity = collectible.AssemblyLinearVelocity:Lerp(newVel, blend)
			end
		else
			table.remove(activeCollectibles, i)
		end
	end
end)


-- Function to determine object type based on parent folder
local function getObjectType(hitPart)
	-- Check if the part is in the Planets folder (client-local planets)
	if hitPart.Parent and hitPart.Parent.Name == "Planets" then
		return "PLANET"
		-- Check if the part is in the Emeralds folder (client-local emeralds)
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

-- Function to check if a part is destructible
local function isDestructible(hitPart)
	if not hitPart or not hitPart:IsA("BasePart") then
		return false
	end

	-- Only allow destruction of planets and emeralds
	local objectType = getObjectType(hitPart)
	return objectType == "PLANET" or objectType == "EMERALD"
end

-- Expose the destructibility check function
DestructionHandler.isDestructible = isDestructible

-- Returns the visual planet "root" (the MeshPart/Part we used when generating)
-- and its welded invisible collider (named PlanetCollider), if present.
local function resolvePlanetAssembly(hitPart)
	-- Start with what we know
	local root, collider

	-- If we hit the collider, note it
	if hitPart.Name == "PlanetCollider" then
		collider = hitPart
	end
	-- If we hit the visual planet, note it
	if hitPart:IsA("MeshPart") or (hitPart:IsA("Part") and hitPart.CanCollide == false) then
		root = hitPart
	end

	-- Look at welded/connected parts to find the other half
	for _, p in ipairs(hitPart:GetConnectedParts(true)) do
		if not collider and p.Name == "PlanetCollider" then
			collider = p
		end
		if not root and (p:IsA("MeshPart") or (p:IsA("Part") and p.CanCollide == false)) then
			root = p
		end
	end

	-- Fallback to the hitPart as root if we didn't find anything else
	return root or hitPart, collider
end

-- If the planet is spinning, it has AlignPosition whose Attachment1 sits on an anchor Part.
-- This removes that anchor to avoid orphaned invisible parts.
local function destroySpinAnchorIfAny(planetRoot)
	local ap = planetRoot:FindFirstChild("PlanetAlignToAnchor")
	if ap and ap:IsA("AlignPosition") then
		local anchorAtt = ap.Attachment1
		if anchorAtt and anchorAtt.Parent and anchorAtt.Parent.Name == "SpinAnchor" then
			anchorAtt.Parent:Destroy()
		end
	end
end


-- Function to create destruction effects for a part
local function createDestructionEffects(hitPart, objectType, player)
	local config = OBJECT_CONFIGS[objectType]

	-- Calculate size scale based on the destroyed object's size
	local objectSize = hitPart.Size
	local sizeScale = (objectSize.X + objectSize.Y + objectSize.Z) / 3 -- Average size
	local normalizedScale = math.clamp(sizeScale / 10, 0.1, 0.5) -- Scale between 0.5x and 3x

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
	particle.Size = NumberSequence.new(5 * normalizedScale) -- Scale particle size
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
	local size = hitPart.Size.X * hitPart.Size.Y
	local numberOfCollectibles = math.clamp(math.floor(size / 400), 1, 500)	
	if objectType == "EMERALD" then

		numberOfCollectibles = math.random(5,10)

	end	

	for i = 1, numberOfCollectibles do
		local collectible

		-- Try to use the asset from ReplicatedStorage first
		local collectibleAsset = ReplicatedStorage:FindFirstChild(config.collectibleAsset)
		if collectibleAsset then
			collectible = collectibleAsset:Clone()
		end

		collectible.Position = hitPart.Position + Vector3.new(
			math.random(-6, 6),
			2 + math.random(0, 2),
			math.random(-6, 6)
		)
		collectible.AssemblyLinearVelocity = Vector3.new(
			math.random(-500, 500),
			math.random(-500, 500),
			math.random(-500, 500)
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

		game.Debris:AddItem(collectible, 100)
	end
end

-- Function to handle destruction effects
function DestructionHandler.handleDestruction(hitPart, player)
	if not hitPart or not hitPart:IsA("BasePart") then
		return
	end

	-- Check if the part is destructible
	if not isDestructible(hitPart) then
		return
	end

	local objectType = getObjectType(hitPart)

	if objectType == "PLANET" then
		-- Fire the planet destruction event to the server, which will relay to all clients
		destructionEvent:FireServer()

		-- Find the visual planet root and its collider (works whether we clicked mesh or collider)
		local planetRoot, collider = resolvePlanetAssembly(hitPart)

		-- Blow up emeralds mapped to the planet root (your generator maps by the visual mesh)
		local emeralds = PlanetFieldGenerator.GetPlanetEmeralds(planetRoot)
		for _, emerald in ipairs(emeralds) do
			if emerald and emerald.Parent then
				createDestructionEffects(emerald, "EMERALD", player)
				emerald:Destroy()
			end
		end
		PlanetFieldGenerator.CleanupPlanetMapping(planetRoot)

		-- VFX/SFX once, based on the root (mesh size == collider size anyway)
		createDestructionEffects(planetRoot, "PLANET", player)

		-- Clean up spin anchor if this planet had one
		destroySpinAnchorIfAny(planetRoot)

		-- Destroy both pieces of the assembly
		if collider and collider.Parent then collider:Destroy() end
		if planetRoot and planetRoot.Parent then planetRoot:Destroy() end

		return
	end

	-- Emeralds (or anything else classified as EMERALD) follow the old path
	createDestructionEffects(hitPart, objectType, player)
	hitPart:Destroy()
end


return DestructionHandler