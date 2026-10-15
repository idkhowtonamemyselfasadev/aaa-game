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
- Hollow Soldier: `game/enemies/hollow_soldier.gd` reuses `vanguard.glb` (above) with `game/shaders/hollow.gdshader` (ash-stone, Voronoi fissures, ember glow, dissolve); spear `game/enemies/spear.gd` + `game/shaders/spear.gdshader` (lathe + leaf blade, wood/iron/cord) — original.
- Practice post: `game/world/training_post.gd` + `game/shaders/training_post.gdshader` (oak, straw, rope, iron, all procedural); impact chaff/dust in `game/fx/impact.gd` (code-generated particles, gradient texture) — original.
- Meadow wildflowers (ox-eye daisy, buttercup, knapweed, yarrow): `game/world/flowers.gd` (procedural stem/leaf/petal meshes) + `game/shaders/flower.gdshader`, `game/shaders/meadow_wind.gdshaderinc` — original.
- Watchtower ruin (chipped cut-stone blocks, keep, curtain wall, fallen stones): `game/world/ruins.gd` + `game/shaders/masonry.gdshader` — original, procedural.
- Ivy on the keep (climbing stems, lobed leaf blades, painted veins): `game/world/ivy.gd` + `game/shaders/ivy.gdshader` — original, procedural.
- Red deer herd (hinds and calves): `game/world/herd.gd` (lofted body/neck/head/legs/ears mesh, herd behaviour) + `game/shaders/deer.gdshader` (gait/grazing pose, coat markings, hair detail) — original, procedural. Model check: `game/tools/deer_view.gd`.
- Soundscape (wind, leaf rustle, rain, crickets, six birdsong phrases, rook caws + wing clatter, near/far thunder): synthesised at load in `game/world/soundscape.gd` from noise and oscillators — original, no sample files.
