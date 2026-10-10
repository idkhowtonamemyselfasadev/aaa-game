# Progress

Content hours playable: 0 (walkable test valley only; no quests, combat or shrines yet)
Current milestone: 1 (vertical slice, Harrowmere Vale). Milestone 0 is done: DESIGN.md written.

## Environment / renderer (cloud box)
- Godot 4.7.2 is fetched by `tools/cloud-setup.sh` into `.tools/godot` (gitignored).
  Run it first thing every session.
- **Forward+ (Vulkan) renders headless** under `xvfb-run` with Mesa lavapipe/llvmpipe
  (verified: "Vulkan 1.4 - Forward+ - llvmpipe"). SDFGI, SSAO, SSIL, volumetric fog, glow all
  run. A 1280x720 screenshot with 60 warm-up frames takes ~75 s of CPU; budget shots
  accordingly (3–5 per session, run them in the background while editing).
- `tools/shots.sh "<spot> <name> [frames] [hour]"` -> `shots/<name>.png`. Spots are defined in
  `game/tools/shot.gd` (village, hill, valley, ridge, player). Falls back to opengl3 if Vulkan
  fails. Uses Weston on the local box, xvfb on cloud.
- `tools/bots.sh [route...]` runs `game/tools/bot.gd` headless (routes: walk, ridge). Bots run at
  4x time scale; both pass in ~10 s wall each.
- Headless import: `.tools/godot --headless --path game --import` (needed once per fresh box;
  the bot/shot runs do it implicitly but print a lot).

## Done
- M0: `DESIGN.md` — world (8 surface regions + Shelf + Depths), 4 lantern abilities, 3
  stances + 4 spells, 6 dungeon bosses with phase mechanics, 24 main quests (35 h), 5 side
  arcs (25 h), shrine rules, 100 h budget table, one-page story, style guide.
- Godot project `game/` (Forward+, Jolt physics, 1080p, full input map kb/m + pad).
- Procedural 512 m terrain (`world/terrain.gd`): heightfield mesh + HeightMapShape3D collision,
  flat village floor in the centre, hills rising to the edges; slope-blended PBR terrain shader.
- Third-person player (`player/player.gd`): walk/run/sprint, jump, stamina, orbit camera with
  SpringArm collision, bot-driveable.
- Day/night driver (`world/world.gd`): Long-Dusk sun arc, physical sky, SDFGI/SSAO/SSIL,
  ACES, bloom, fog + volumetric fog, grading. Environment built in code so it's diffable.
- Screenshot tool and headless bot (see above); both verified on this box.

## Screenshot verdicts (this session)
See `shots/` (gitignored). 8 shots taken, all looked at. Verdict for every one: does NOT pass
the 2024-console bar. Findings that the next session must act on first:
- The valley floor sits in the hills' shadow whenever the sun is under ~15 deg, so the
  ground gets only dim sky ambient and reads as a flat brown gradient. Either raise the
  Long-Dusk max elevation (DESIGN says 8-15 deg; use the top of that range at midday and
  keep the hills lower/further), or add bounce (SDFGI needs >150 warm-up frames on
  llvmpipe to say anything; untested beyond that).
- `tools/shots.sh` spot names: village, hill, side, east, valley, ridge, ground, player.
  Extra args after the hour: `nofog`, `noglow`, `nosdfgi` for A/B diagnostics.
- A NoiseTexture2D bound as a shader sampler produced no visible effect; the terrain shader
  now uses in-shader fbm value noise and has no texture dependency. Real CC0 textures are
  still step 1 of milestone 1.
- `east` at hour 12.0 with the sun behind the camera shows the procedural material (grass/dirt
  blend, detail normals) working on lit slopes, so the material is fine: it is the shadowing.
- Shots looking into the sun are blown out by volumetric fog scatter; keep sun behind or
  beside the camera for judgement shots.

## Next (milestone 1 — vertical slice, in order)
1. Terrain textures: import CC0 grass/dirt/rock/moss from ambientCG (albedo+normal+rough,
   2K, ≤ 50 MB total), wire into `terrain.gdshader` as triplanar layers; record in ASSETS.md.
2. Grass: GPU multimesh scatter with wind, distance fade; trees (procedural or CC0 black-oak),
   rocks, hedgerows.
3. Harrowmere village blockout → final: slate roofs, timber, lantern posts (Kindle targets).
4. Character: Mixamo rig + locomotion blend tree (idle/walk/run/sprint, jump, foot IK) to
   replace the capsule.
5. Combat (Ward stance): L×4 string, heavy with parry window, dodge + perfect dodge
   time-dilation, hit-stop, lock-on, stamina; Hollow Soldier enemy with telegraphs.
6. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
7. Every step: shots + bots, then update this file.

## Known bugs
- Player capsule starts 0.5 m above ground and drops (cosmetic).
- Audio driver errors on the cloud box (no ALSA device); harmless, run with
  `--audio-driver Dummy` to silence if needed.
