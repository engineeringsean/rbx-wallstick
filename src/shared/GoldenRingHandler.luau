-- GoldenRingHandler.luau
-- Shared module for handling Golden Ring interactions and effects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GoldenRingHandler = {}

-- Configuration for Golden Ring effects
local RING_CONFIG = {
	coinSpawnCount = 50,           -- Number of coins to spawn when passing through
	coinSpawnRadius = 15,         -- Radius around ring center to spawn coins
	coinMagnetizeDistance = 5,    -- Distance at which coins start magnetizing to player
	coinMagnetizeSpeed = 150,     -- Speed at which coins move toward player
}

-- Track active rings and their effects
local activeRings = {}
local activeCoins = {}

-- Create or get the Golden Ring interaction event
local ringInteractionEvent = ReplicatedStorage:FindFirstChild("GoldenRingInteractionEvent")
if not ringInteractionEvent then
	ringInteractionEvent = Instance.new("RemoteEvent")
	ringInteractionEvent.Name = "GoldenRingInteractionEvent"
	ringInteractionEvent.Parent = ReplicatedStorage
end

-- Function to check if a player is passing through a ring
local function isPlayerPassingThroughRing(player, ring)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return false, nil
	end

	local hrp = player.Character.HumanoidRootPart
	local ringCFrame = ring.CFrame
	local ringSize = ring.Size

	-- Get the ring's Y-axis (up direction) and the XZ plane
	local ringUp = ringCFrame.UpVector
	local ringCenter = ringCFrame.Position

	-- Calculate the player's position relative to the ring's center
	local relativePos = hrp.Position - ringCenter

	-- Project the relative position onto the ring's XZ plane
	local projectedPos = relativePos - (relativePos:Dot(ringUp) * ringUp)

	-- Check if player is within the ring's XZ bounds
	local ringRadius = math.max(ringSize.X, ringSize.Z) / 2
	if projectedPos.Magnitude <= ringRadius then
		-- Check if player is crossing the Y plane of the ring
		local yDistance = math.abs(relativePos:Dot(ringUp))
		local yThreshold = ringSize.Y / 2 + 10 -- Increased tolerance

		if yDistance <= yThreshold then
			-- Determine which direction the player is moving through the ring
			local playerVelocity = hrp.AssemblyLinearVelocity
			local velocityInRingDirection = playerVelocity:Dot(ringUp)

			return true, velocityInRingDirection > 0 and 1 or -1
		end
	end

	return false, nil
end

-- Function to create explosion effects for the ring
local function createRingExplosion(ring)
	-- Create explosion sound
	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = "rbxassetid://9114591322" -- Explosion sound
	explosionSound.Volume = 0.8
	explosionSound.PlayOnRemove = true
	explosionSound.Parent = workspace
	explosionSound:Destroy()

	-- Create particle explosion effect
	local explosionPart = Instance.new("Part")
	explosionPart.Size = Vector3.new(1, 1, 1)
	explosionPart.CFrame = ring.CFrame
	explosionPart.Anchored = true
	explosionPart.CanCollide = false
	explosionPart.CanQuery = false
	explosionPart.CanTouch = false
	explosionPart.Transparency = 1
	explosionPart.Parent = workspace

	-- Add explosion particle effect
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxassetid://2122546039" -- Gold particle texture
	particle.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- Gold color
	particle.Size = NumberSequence.new(8, 0)
	particle.RotSpeed = NumberRange.new(100, 200)
	particle.Shape = Enum.ParticleEmitterShape.Sphere
	particle.Lifetime = NumberRange.new(2, 3)
	particle.Rate = 200
	particle.Speed = NumberRange.new(30, 80)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Parent = explosionPart

	-- Emit particles
	particle:Emit(100)

	-- Clean up explosion effect
	game.Debris:AddItem(explosionPart, 3)

	-- Create debris pieces
	for i = 1, 8 do
		local debris = Instance.new("Part")
		debris.Size = Vector3.new(1, 1, 1)
		debris.CFrame = ring.CFrame * CFrame.new(
			math.random(-3, 3),
			math.random(-3, 3),
			math.random(-3, 3)
		)
		debris.Anchored = false
		debris.CanCollide = false
		debris.CanQuery = false
		debris.CanTouch = false
		debris.Color = Color3.fromRGB(255, 215, 0) -- Gold color
		debris.Material = Enum.Material.Neon
		debris.Parent = workspace

		-- Add physics to debris
		debris.AssemblyLinearVelocity = Vector3.new(
			math.random(-50, 50),
			math.random(20, 80),
			math.random(-50, 50)
		)

		-- Clean up debris
		game.Debris:AddItem(debris, 5)
	end
end

-- Function to spawn coins around a ring
local function spawnCoinsAroundRing(ring, player)
	local coinAsset = ReplicatedStorage:FindFirstChild("Coin")
	if not coinAsset then
		warn("Coin asset not found in ReplicatedStorage")
		return
	end

	local ringCenter = ring.CFrame.Position
	local ringUp = ring.CFrame.UpVector

	for i = 1, RING_CONFIG.coinSpawnCount do
		local coin = coinAsset:Clone()

		-- Random position around the ring
		local angle = math.random() * 2 * math.pi
		local radius = math.random() * RING_CONFIG.coinSpawnRadius
		local height = math.random(-5, 5)

		local offset = Vector3.new(
			math.cos(angle) * radius,
			height,
			math.sin(angle) * radius
		)

		-- Transform offset to ring's coordinate system
		local ringRight = ring.CFrame.RightVector
		local ringForward = ring.CFrame.LookVector
		local finalOffset = ringRight * offset.X + ringUp * offset.Y + ringForward * offset.Z

		coin.Position = ringCenter + finalOffset

		-- Use higher initial velocity like DestructionHandler for better magnetization
		coin.AssemblyLinearVelocity = Vector3.new(
			math.random(-200, 200),
			math.random(-100, 100),
			math.random(-200, 200)
		)

		coin.Anchored = false
		coin.CanCollide = false
		coin.CanQuery = false
		coin.Parent = workspace

		-- Track this coin for magnetization - USE SAME STRUCTURE AS DESTRUCTIONHANDLER
		table.insert(activeCoins, {
			collectible = coin,  -- Use 'collectible' like DestructionHandler
			player = player,     -- Keep 'player'
			objectType = "COIN"  -- Add 'objectType' like DestructionHandler
		})

		game.Debris:AddItem(coin, 30) -- Clean up after 30 seconds
	end
end

-- Function to handle ring interaction
local function handleRingInteraction(player, ring)
	local isPassing, direction = isPlayerPassingThroughRing(player, ring)

	if isPassing then
		-- Spawn coins
		spawnCoinsAroundRing(ring, player)

		-- Create explosion effects
		createRingExplosion(ring)

		-- Fire the interaction event
		ringInteractionEvent:FireServer(ring, direction)

		-- Destroy the ring after a short delay to let effects play
		task.delay(0.1, function()
			if ring and ring.Parent then
				ring:Destroy()
			end
		end)
	end
end

-- Timer for ring checking (instead of every frame)
local lastRingCheckTime = 0
local checkInterval = 0.1 -- Check every 0.1 seconds

-- Heartbeat loop to check for ring interactions
RunService.Heartbeat:Connect(function(dt)
	-- Only check rings at intervals, not every frame
	local currentTime = tick()
	if currentTime - lastRingCheckTime < checkInterval then
		return
	end
	lastRingCheckTime = currentTime

	-- Check all rings for player interactions
	local rings = workspace:FindFirstChild("GoldenRings")
	if rings then
		for _, ring in ipairs(rings:GetChildren()) do
			if ring:IsA("BasePart") then
				local players = game.Players:GetPlayers()
				for _, player in ipairs(players) do
					-- Only check if player has a character and is within reasonable distance
					if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						local hrp = player.Character.HumanoidRootPart
						local distanceToRing = (hrp.Position - ring.Position).Magnitude

						-- Only check rings within 100 studs
						if distanceToRing <= 100 then
							handleRingInteraction(player, ring)
						end
					end
				end
			end
		end
	end
end)

-- Heartbeat loop to  magnetize coins
RunService.Heartbeat:Connect(function(dt)

	-- Magnetize coins toward players (using improved logic from DestructionHandler)
	for i = #activeCoins, 1, -1 do
		local entry = activeCoins[i]
		local collectible = entry.collectible  -- Use 'collectible' like DestructionHandler
		local player = entry.player

		if collectible and collectible.Parent and player and player.Character and 
			player.Character:FindFirstChild("HumanoidRootPart") then

			local hrp = player.Character.HumanoidRootPart
			local direction = (hrp.Position - collectible.Position)
			local distance = direction.Magnitude

			if distance < RING_CONFIG.coinMagnetizeDistance then
				-- Coin is close enough to collect
				local collectionSound = Instance.new("Sound")
				collectionSound.SoundId = "rbxassetid://6792279908" -- Coin collection sound
				collectionSound.Volume = 0.2
				collectionSound.PlayOnRemove = true
				collectionSound.Parent = workspace
				collectionSound:Destroy()

				-- Award coins to the player
				local awardEvent = ReplicatedStorage:FindFirstChild("AwardCollectibleEvent")
				if awardEvent then
					awardEvent:FireServer("COIN", 1)
				end

				collectible:Destroy()  -- Use 'collectible' like DestructionHandler
				table.remove(activeCoins, i)
			else
				-- Keep ETA ~1–3s regardless of distance (same as DestructionHandler)
				local targetTime = math.clamp(distance / 150, 1, 3)
				local desiredSpeed = distance / targetTime

				-- Optional: protect against absurd speeds if your map is huge
				desiredSpeed = math.clamp(desiredSpeed, 75, 2000)

				local newVel = direction.Unit * desiredSpeed

				-- Framerate-independent smoothing (same as DestructionHandler)
				local blend = 1 - math.exp(-10 * dt)
				collectible.AssemblyLinearVelocity = collectible.AssemblyLinearVelocity:Lerp(newVel, blend)
			end
		else
			-- Clean up invalid entries
			table.remove(activeCoins, i)
		end
	end
end)

-- Function to register a new ring
function GoldenRingHandler.registerRing(ring)
	if not ring:IsA("BasePart") then
		warn("Attempted to register non-part as Golden Ring")
		return
	end

	-- Ensure the ring is in the correct folder
	if ring.Parent and ring.Parent.Name ~= "GoldenRings" then
		local goldenRingsFolder = workspace:FindFirstChild("GoldenRings")
		if not goldenRingsFolder then
			goldenRingsFolder = Instance.new("Folder")
			goldenRingsFolder.Name = "GoldenRings"
			goldenRingsFolder.Parent = workspace
		end
		ring.Parent = goldenRingsFolder
	end

	-- Make rings indestructible (until they're triggered)
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
end

-- Function to unregister a ring
function GoldenRingHandler.unregisterRing(ring)
	local ringId = ring:GetFullName()
	if activeRings[ringId] then
		activeRings[ringId] = nil
	end
end

-- Function to get active rings info
function GoldenRingHandler.getActiveRingsInfo()
	local info = {}
	for ringId, playerData in pairs(activeRings) do
		info[ringId] = {
			playerCount = 0,
			lastInteraction = 0
		}
		for playerId, lastTime in pairs(playerData) do
			info[ringId].playerCount = info[ringId].playerCount + 1
			if lastTime > info[ringId].lastInteraction then
				info[ringId].lastInteraction = lastTime
			end
		end
	end
	return info
end

return GoldenRingHandler