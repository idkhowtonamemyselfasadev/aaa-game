# Progress

Content hours playable: 0
(walkable test valley with grass, oak groves and boulders; no quests, combat or shrines yet. Game scope is
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
- Session 2026-10-10 10:00 UTC:
  - **Fixed "everything in shadow renders pure black"** (top visual bug). Diagnosed with
    480x270 test shots (`--resolution 480x270`, 20 frames, ~2 min each — use these for
    A/B diagnostics, not full shots). Two independent zeros stacked: (1) sky-radiance
    ambient contributed ~0 in shadow (x4 ambient energy changed nothing); (2) SDFGI, which
    replaces the ambient term, also gave ~0 indirect light on lavapipe. Either alone kept
    shadows black. Fix in `world/world.gd`: ambient is now a time-of-day colour (blue-grey
    skylight warming toward dusk, moonlit blue at night); SDFGI auto-disables when the
    adapter is llvmpipe/lavapipe (`sdfgi_allowed` export for a future quality slider).
    SSAO/SSIL still on. Fog no longer washes the whole sky grey (`fog_sky_affect` 0.4→0.12,
    volumetric 0.3→0.1).
  - `shot.gd` diagnostics: `novol`, `norefl`, `skyrt`, `noupd`, `skyx=N`, `ambx=N`.
    Note: `noupd` freezes the clock at world's default 17.25 h, not the requested hour.
- Session 2026-10-10 09:00 UTC:
  - **Black-oak groves and mossy boulders** (`world/flora.gd`, all procedural): 4 oak
    variants (gnarled forking trunk → limbs → twigs as tapered knobbly tubes with root flare
    and bark UVs; ~1000 leaf-sprig cards per tree from a painted 1024² oak-leaf atlas,
    crown-shaped normals, back-light), 260 trees scattered in noise groves, 9 m spacing;
    6 boulder variants (noise-displaced, plane-cut, flattened icospheres), 420 rocks in
    slope outcrops + lone stones. MultiMesh, shadows on, trunk/boulder collision.
    Shaders: `bark` (seamless furrow noise + normal, moss on top/roots), `leaves` (alpha
    test, flutter), `rock` (strata/cracks/lichen/moss, damp foot), shared
    `tree_wind.gdshaderinc` so trees sway with the grass gusts.
  - Village floor (r < 38 m) and the diagonal road to the east ridge are kept clear.
  - `tools/bots.sh` runs each bot once (it ran twice) and FAILs on any SCRIPT ERROR (it
    used to PASS with a broken script); bots now also assert flora scattered.
  - `tools/shots.sh` timeout 240→600 s: with trees a Vulkan shot takes ~170 s at 30 frames
    and the old timeout silently fell back to opengl3. Use 30 frames. New spots `tree`,
    `rocks` (frame the nearest tree/boulder to the village edge).
- Session 2026-10-10 08:40 UTC (ran in parallel with the 08:00 one; merged onto it):
  - **Fixed the "hills float as ribbons" bug at its root: the terrain mesh had inverted
    triangle winding and was back-face culled, so it was invisible from above.** The ribbons
    were the far sides of hills seen from below; everything else was the sky's ground colour.
    Every M0 verdict about a "flat brown valley" was looking at the sky. Hills now render
    with real long shadows.
  - Day/night: proper sun arc (sunrise 06:00, noon `sun_peak_deg` 28, sunset 18:00), a cool
    moon DirectionalLight opposite the sun at night, procedural star field (bound to the
    PhysicalSky only after dusk, since it is added unattenuated), fog colour/albedo/emission,
    exposure and a moonlit ambient colour all follow the time of day. Volumetric fog cut to
    local haze (a dense volume ends at its length and leaves a band on far ridges).
  - `tools/shots.sh` diagnostics: `noshadow`, `nogi` (plus `nofog`, `nosdfgi`, `noglow`).
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

## Screenshot verdicts (2026-10-10 08:40 session, after the winding fix)
- `village` 12h: solid hill bowl behind a dense amber meadow; first shot that reads as a real
  landscape. Wukong? No (no trees/rocks/ruins/village, procedural terrain colour). Alive? Only wind.
- `side` 16.5h: long hill shadows sweep the valley; shadowed foreground crushed to black
  (raise shadow-side ambient / SDFGI warm-up), sky flat grey. Fail.
- `hill` 22.5h: moonlit grass and stars, readable. No moon disc, fireflies, sounds. Fail.

## Asset download situation (cloud box)
- **ambientcg.com, polyhaven.com/dl.polyhaven.org, huggingface.co and cdn.jsdelivr.net are
  blocked** by the egress proxy (403 on CONNECT). github.com, raw.githubusercontent.com,
  pypi.org and registry.npmjs.org work. So photoreal CC0 textures/models cannot be fetched from
  their home sites here; options for later sessions: CC0 assets mirrored in GitHub repos
  (e.g. godot-demo-projects ships Poly Haven 1k ship textures), or keep going procedural.
  Recheck each session with `curl -sI https://ambientcg.com`.

## Screenshot verdicts (2026-10-10 09:00 session)
- `tree` 15.5h: backlit oak grove, sun glare through crowns, trunk shadows across grass —
  atmospheric. Wukong? No: shadowed foreground crushed to pure black; leaf cards read as
  dark blobs up close. Alive? Wind only.
- `rocks` 12h: oak woodland on the hill crests over the meadow; reads as a real place for
  the first time. Boulders too small to notice; hill ground bare brown; sky flat. Fail.
- `village` 16.5h: oak line on the hills good; camera stands in a tree's shadow and the
  whole lower half is black. Fail -> Next 1.

## Screenshot verdicts (2026-10-10 10:00 session, after the shadow fix)
- `village` 16.5h: the formerly black lower half is now a readable shaded meadow. Sky is
  too dark navy for late afternoon; horizon empty. Wukong? No. Alive? Wind only.
- `tree` 15.5h: backlit grove with god-ray haze, trunks and shaded grass all readable —
  best shot so far. Leaf cards read as flat blobs up close. Fail (close).
- `rocks` 12h: oak hills over a meadow, shade readable; rocks tiny, ground bare. Fail.

## Next (milestone 1 — vertical slice, in order)
1. Afternoon sky too dark/navy (16–17 h): tune PhysicalSky rayleigh/exposure so late
   afternoon reads bright and warm; verify SDFGI on a real GPU some day (cloud box can't).
2. Flora polish: bigger hero boulders/outcrops (3–6 m) and ruins on hilltops, hedgerows,
   shrubs/ferns under trees, leaf atlas with normals and more leaf shape per card at close
   range, tree LOD/impostors beyond 150 m.
3. Horizon: far mountain ring beyond the 512 m tile so the world does not end at 256 m.
4. Terrain textures: CC0 grass/dirt/rock/moss (blocked here — see above); else improve the
   procedural layers.
5. Living world first pass: birds that scatter, a grazing sheep herd that flees (§8 DESIGN).
6. Harrowmere village blockout → final: slate roofs, timber, lantern posts (Kindle targets).
7. Character: realistic rig (Mixamo floor) + locomotion blend tree (idle/walk/run/sprint, jump, foot IK) to
   replace the capsule.
8. Combat (Ward stance): L×4 string, heavy with parry window, dodge + perfect dodge
   time-dilation, hit-stop, lock-on, stamina; Hollow Soldier enemy with telegraphs.
9. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
10. Every step: shots + bots, then update this file.

## Known bugs
- (fixed: shadowed surfaces pure black.) SDFGI is off on the cloud box (software GPU);
  whether SDFGI + sky ambient light shadows correctly on a real GPU is unverified.
- Late-afternoon sky renders dark navy.
- (fixed: hills floating as ribbons = inverted terrain winding.) World edge at 256 m is still
  visible from slopes; needs the far mountain ring (Next 3).
- Grass streaming builds chunks on the main thread (6/frame); fine at walking speed, may
  hitch when gliding/fast travel arrives — move to WorkerThreadPool then.
- Shots: a Vulkan screenshot now takes ~3 min on lavapipe (trees + shadows); budget 3–4.
- Tree collision is a 4 m trunk cylinder only; the player can walk through low limbs.
- A new `class_name` needs `godot --headless --import` before scripts can use it as a type.
- Player capsule starts 0.5 m above ground and drops (cosmetic).
- Audio driver errors on the cloud box (no ALSA device); harmless, run with
  `--audio-driver Dummy` to silence if needed.
