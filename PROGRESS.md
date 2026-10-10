# Progress

Content hours playable: 0
(walkable test valley with streamed grass only; no quests, combat or shrines yet. Game scope is
now ~30 h per the owner's direction in CLAUDE.md.)
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
- Session 2026-10-10 08:00 UTC:
  - CLAUDE.md gained `# OWNER DIRECTION` (30 h scope, realistic Wukong look, living world).
  - DESIGN.md rescoped to 30 h: 4 regions (Vale, Greywold, Vellmarsh, Aurel) + small Depths,
    3 dungeons (Ashen Priory, Drowned Cistern, Chain Shaft), 30 shrines, 12 main quests,
    4 side arcs, realistic style guide, new §8 "living world" spec.
  - **Wind-blown grass** (`world/grass.gd` + `shaders/grass.gdshader`): real blade geometry
    (12 curved tapered blades per clump), streamed in 16 m MultiMesh chunks within 64 m of the
    active camera, distance LOD (far chunks thinner, bigger clumps), sink-fade at the edge,
    no grass on rock slopes, bare patches by noise. Wind = travelling gusts + swell +
    flutter; per-clump dry-amber/green tint, root occlusion, back-light translucency.
  - Sun arc now reaches 28 deg at noon (valley floor gets direct light), real night at -24.
  - Terrain shader: wind-combed thatch streaks, lower specular on soil/grass.
  - Bots assert grass streamed in (83–87 chunks); both routes PASS.
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

## Screenshot verdicts (2026-10-10 08:00 session)
- `ground` 12h: dense wind-combed amber meadow, convincing up close. Wukong? No — the ground
  between clumps is flat grey-brown, horizon is empty. Alive? No (only wind).
- `village` 17h (before density pass): sparse sprouts, looked like a rice paddy -> fixed by
  the density pass.
- `side` 16.5h: grass slope good; beyond 64 m the valley is an empty brown plane, distant
  hills float as ribbons above fog. Fail.
- **Biggest visual problems now, in order:** (1) nothing but grass: no trees, rocks, village;
  (2) far terrain/horizon: hills float in fog, world ends at 256 m — needs far mountains /
  horizon ring and fog height tuning; (3) bare-ground colour under grass.

## Asset download situation (cloud box)
- **ambientcg.com, polyhaven.com/dl.polyhaven.org, huggingface.co and cdn.jsdelivr.net are
  blocked** by the egress proxy (403 on CONNECT). github.com, raw.githubusercontent.com,
  pypi.org and registry.npmjs.org work. So photoreal CC0 textures/models cannot be fetched from
  their home sites here; options for later sessions: CC0 assets mirrored in GitHub repos
  (e.g. godot-demo-projects ships Poly Haven 1k ship textures), or keep going procedural.
  Recheck each session with `curl -sI https://ambientcg.com`.

## Next (milestone 1 — vertical slice, in order)
1. Trees + rocks: procedural black oaks (trunk/branch mesh + leaf cards with wind sway, shared
   wind uniforms with grass), mossy boulders (noise-displaced icosphere with triplanar rock
   shader), hedgerows; scatter them through the vale. (Grass: done.)
2. Horizon: far mountain ring beyond the 512 m tile + fog height tuning so hills don't float.
3. Terrain textures: CC0 grass/dirt/rock/moss (blocked here — see above); else improve the
   procedural layers.
4. Living world first pass: birds that scatter, a grazing sheep herd that flees (§8 DESIGN).
5. Harrowmere village blockout → final: slate roofs, timber, lantern posts (Kindle targets).
6. Character: realistic rig (Mixamo floor) + locomotion blend tree (idle/walk/run/sprint, jump, foot IK) to
   replace the capsule.
7. Combat (Ward stance): L×4 string, heavy with parry window, dodge + perfect dodge
   time-dilation, hit-stop, lock-on, stamina; Hollow Soldier enemy with telegraphs.
8. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
9. Every step: shots + bots, then update this file.

## Known bugs
- Distant terrain hills float as ribbons above the fog; world edge visible from slopes.
- Grass streaming builds chunks on the main thread (6/frame); fine at walking speed, may
  hitch when gliding/fast travel arrives — move to WorkerThreadPool then.
- `tools/bots.sh` hangs until its timeout if bot.gd has a parse error (no early exit).
- A new `class_name` needs `godot --headless --import` before scripts can use it as a type.
- Player capsule starts 0.5 m above ground and drops (cosmetic).
- Audio driver errors on the cloud box (no ALSA device); harmless, run with
  `--audio-driver Dummy` to silence if needed.
