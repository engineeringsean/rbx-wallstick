--!strict

local PhysicsService = game:GetService("PhysicsService") :: PhysicsService

local PlayerScripts = require(script.PlayerScripts)

-- Private

local function setupCollisions()
	PhysicsService:RegisterCollisionGroup("WallstickCollision")
	PhysicsService:RegisterCollisionGroup("WallstickNoCollision")

	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(group.name, "WallstickCollision", false)
		PhysicsService:CollisionGroupSetCollidable(group.name, "WallstickNoCollision", false)
	end

	PhysicsService:CollisionGroupSetCollidable("WallstickCollision", "WallstickCollision", true)
end

--

local folder = Instance.new("Folder")
folder.Name = "Wallstick"
folder.Parent = workspace

PlayerScripts.setup()
setupCollisions()
