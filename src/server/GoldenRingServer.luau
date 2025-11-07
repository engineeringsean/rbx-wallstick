-- GoldenRingServer.luau
-- Server-side handler for Golden Ring interactions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get or create the Golden Ring interaction event
local ringInteractionEvent = ReplicatedStorage:FindFirstChild("GoldenRingInteractionEvent")
if not ringInteractionEvent then
	ringInteractionEvent = Instance.new("RemoteEvent")
	ringInteractionEvent.Name = "GoldenRingInteractionEvent"
	ringInteractionEvent.Parent = ReplicatedStorage
end

-- Handle Golden Ring interactions from clients
ringInteractionEvent.OnServerEvent:Connect(function(player, ring, direction)
	-- Validate the player and ring
	if not player or not ring or not ring.Parent then
		return
	end

	-- Log the interaction for debugging
	print(string.format("Player %s passed through Golden Ring %s in direction %d", 
		player.Name, ring:GetFullName(), direction))

	-- You can add additional server-side logic here, such as:
	-- - Tracking statistics
	-- - Awarding achievements
	-- - Broadcasting to other players
	-- - Database logging

	-- Broadcast the interaction to all clients (optional)
	ringInteractionEvent:FireAllClients(player, ring, direction)
end)

-- Function to get information about all active Golden Rings
local function getActiveRingsInfo()
	local goldenRingsFolder = workspace:FindFirstChild("GoldenRings")
	if not goldenRingsFolder then
		return {}
	end

	local ringsInfo = {}
	for _, ring in ipairs(goldenRingsFolder:GetChildren()) do
		if ring:IsA("BasePart") then
			table.insert(ringsInfo, {
				name = ring.Name,
				position = ring.Position,
				size = ring.Size,
				cframe = ring.CFrame
			})
		end
	end

	return ringsInfo
end

-- Expose the function for other server scripts
local GoldenRingServer = {}
GoldenRingServer.getActiveRingsInfo = getActiveRingsInfo

return GoldenRingServer