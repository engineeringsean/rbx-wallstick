-- WallstickServer.lua
--!strict

local PhysicsService = game:GetService("PhysicsService") :: PhysicsService

local PlayerScripts = require(script.PlayerScripts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for or create the planet destruction event
local destructionEvent = ReplicatedStorage:FindFirstChild("PlanetDestructionEvent")
if not destructionEvent then
	destructionEvent = Instance.new("RemoteEvent")
	destructionEvent.Name = "PlanetDestructionEvent"
	destructionEvent.Parent = ReplicatedStorage
end

-- When a client fires the event (planet destroyed), relay it to all clients
destructionEvent.OnServerEvent:Connect(function(player)
	-- Relay the event to all clients
	destructionEvent:FireAllClients()
end)

-- Private

local function setupCollisions()
	PhysicsService:RegisterCollisionGroup("WallstickCollision")
	PhysicsService:RegisterCollisionGroup("WallstickNoCollision")

	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(group.name, "WallstickCollision", false)
		PhysicsService:CollisionGroupSetCollidable(group.name, "WallstickNoCollision", false)
	end

	-- Allow WallstickCollision to collide with itself
	PhysicsService:CollisionGroupSetCollidable("WallstickCollision", "WallstickCollision", true)
	
end

--

local folder = Instance.new("Folder")
folder.Name = "Wallstick"
folder.Parent = workspace

PlayerScripts.setup()
setupCollisions()
