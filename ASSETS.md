# Assets and licenses

Every third-party asset in `game/` is listed here with its source and license. Only CC0,
CC-BY, OFL, or Mixamo-licensed content is allowed (public repo). Nothing over 50 MB.

| Path | What | Source | License |
|------|------|--------|---------|
| `game/player/models/vanguard.glb` | Rigged humanoid "Vanguard" (Mixamo character) with Idle/Walk/Run/TPose clips, 2.1 MB | Mixamo, via the three.js repo (`examples/models/gltf/Soldier.glb`) | Mixamo license (royalty-free use in games) |

## Procedural (no license needed)
- `game/world/terrain.gd` — heightfield terrain from FastNoiseLite.
- `game/shaders/terrain.gdshader` — slope-blended grass/dirt/rock using a NoiseTexture2D.
- Oak trees, leaf atlas, boulders, bark/leaf/rock shaders: generated procedurally in `game/world/flora.gd` and `game/shaders/` (original, no third-party assets).
- Hero staff: `game/player/staff.gd` (lathe mesh: bronze caps with machined ridges, lacquered shaft, cloth grip) and `game/shaders/staff.gdshader` (procedural wood grain, lacquer wear, tarnish, weave) — original.
