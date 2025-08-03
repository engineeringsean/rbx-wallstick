# Destruction System Documentation

## Overview
The destruction system has been reorganized to handle different collectibles, sounds, and particle effects for planets vs emeralds. All destruction scripts (Swirl, Swing, GroundPound) now use a shared `DestructionHandler` module.

## File Structure Changes

### New Files
- `src/shared/DestructionHandler.luau` - Shared module handling all destruction effects

### Modified Files
- `src/client/PlanetFieldGeneratorModule` - Now creates both planets and emeralds in separate folders
- `src/server/PlayerScripts/Swirl.luau` - Updated to use shared handler
- `src/server/StarterPack/Swing` - Updated to use shared handler  
- `src/server/PlayerScripts/GroundPound` - Updated to use shared handler

## Configuration Required

### 1. Asset IDs in DestructionHandler.luau
Replace the placeholder asset IDs in `src/shared/DestructionHandler.luau`:

```lua
PLANET = {
    destructionSoundId = "rbxassetid://PLANET_DESTRUCTION_SOUND_ID", -- Replace with actual ID
    collectionSoundId = "rbxassetid://COIN_COLLECTION_SOUND_ID", -- Replace with actual ID
    particleTexture = "rbxassetid://PLANET_PARTICLE_TEXTURE_ID", -- Replace with actual ID
    -- ...
},
EMERALD = {
    destructionSoundId = "rbxassetid://EMERALD_DESTRUCTION_SOUND_ID", -- Replace with actual ID
    collectionSoundId = "rbxassetid://STAR_CRYSTAL_COLLECTION_SOUND_ID", -- Replace with actual ID
    particleTexture = "rbxassetid://EMERALD_PARTICLE_TEXTURE_ID", -- Replace with actual ID
    -- ...
}
```

### 2. Collectible Assets in ReplicatedStorage
Ensure these assets exist in ReplicatedStorage:
- `Coins` - Asset for planet collectibles
- `Star Crystals` - Asset for emerald collectibles

## How It Works

### Object Type Detection
The system automatically detects object types based on:
- **Planets**: Parts in "LocalPlanets" folder or named "PlanetCollectible"
- **Emeralds**: Parts in "Emeralds" folder or with "emerald" in the name

### Different Effects
- **Planets** drop "Coins" with gold particle effects
- **Emeralds** drop "Star Crystals" with emerald green particle effects
- Each type has unique destruction and collection sounds
- Collectibles have different sizes and colors

### Mechanics
- All collectibles use the same magnetization system
- Same debris effects for both types
- Same physics and collection mechanics
- Only visual/audio effects differ

## Benefits
1. **Centralized Logic**: All destruction code is in one place
2. **Easy Configuration**: Asset IDs and effects are easily configurable
3. **Consistent Behavior**: All destruction methods work the same way
4. **Maintainable**: Changes to destruction effects only need to be made in one file

## Testing
After configuring the asset IDs, test that:
1. Planets drop coins with gold effects
2. Emeralds drop star crystals with green effects
3. Different sounds play for destruction and collection
4. All three destruction methods (Swirl, Swing, GroundPound) work correctly 