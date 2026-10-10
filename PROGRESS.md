# Progress

Content hours playable: 0
(walkable test valley with grass, oak groves, boulders and rook flocks, played as a rigged animated humanoid; no
quests, combat or shrines yet. Game scope is
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
- Session 2026-10-10 14:00 UTC:
  - **The capsule is gone: the player is a rigged, animated humanoid (was Next 7, first half).**
    `game/player/models/vanguard.glb` (Mixamo "Vanguard", 1.83 m, skinned, PBR body + visor,
    fetched from the three.js repo on GitHub; see ASSETS.md). `player.gd` builds an
    AnimationTree in code: BlendSpace1D Idle(0) -> Walk(1.9 m/s) -> Run(6.0 m/s) on smoothed
    horizontal speed, plus a TimeScale node so sprint (9 m/s) plays the run faster and slow
    walking slows the walk cadence (less foot skate). Model rotated 180° (it faces -Z). The
    lantern sphere is gone; its warm light stays at the hip.
  - Bots: both routes assert the AnimationTree is active and blends fully into the run (PASS).
  - Shot spots `hero` (3/4 front portrait of the idle player) and `herorun` (follow camera,
    player running sideways).
  - Verdicts: `hero` 15.5h — a real human silhouette standing in the meadow, PBR armour reads.
    Fail for Wukong: it is a sci-fi armoured soldier with a visor (wrong for a mythic setting,
    no visible face/hair/cloth), lit flat by the hip light, no weapon. `herorun` — mid-stride
    run cycle with proper arm/leg motion. Fail: same model problem, feet partly hidden in grass.
- Session 2026-10-10 13:00 UTC:
  - **Living world first pass: rook flocks and soaring kites (was Next 5, birds half).**
    New `world/birds.gd` + `shaders/bird.gdshader`, all procedural: one rook mesh (~0.45 m,
    0.85 m span: lofted body, head, pale beak, eye beads, fanned tail, wings with five
    fingered primaries, legs and toes), posed per instance through INSTANCE_CUSTOM (wing
    flap angle, leg tuck, head peck, wing fold). 3 flocks x 14 rooks feed on open meadow
    sites (sites rejected near trees/slopes): they hop, turn and peck. When the player or
    camera comes within 11 m (+1.4 m per m/s of horizontal speed) the flock bursts up, the
    nearest birds first, climbs on fast beats, wheels overhead with flap/glide bursts and
    banking for 8–13 s, then picks a clear site away from the threat and glides in with a
    flare (fast beats, legs down). Flocks also lift off unprompted every 70–160 s. Two red
    kites soar high circles by day (hidden at night). Bird sim clamps dt to 1/30 so slow
    screenshot frames don't teleport them.
  - Grass: `GrassField.cropped_spots` — turf is cropped short (22 %) around feeding sites
    so the rooks are visible instead of buried in 50 cm grass.
  - Bots: `walk` asserts the rooks scatter when the route crosses their site (PASS,
    4 scatters, 1 landing); `ridge` PASS. Shot spots `birds` (camera 9 m: take-off) and
    `rooks` (15.5 m: feeding).
  - Verdicts: `rooks` 14h — black rooks hopping on a cropped patch under the oak line;
    reads like a real field. Fail: birds tiny, crop patch shows the bare brown ground.
    `birds` 11h — rooks lifting out of the meadow; alive in motion, specks in a still. Fail.
- Session 2026-10-10 12:00 UTC:
  - **Far mountain ring: the world no longer ends at 256 m (was Next 3).** New
    `world/horizon.gd` + `shaders/horizon.gdshader`: one ArrayMesh on a non-uniform grid
    from the tile edge out to 2.8 km (2 m cells on the seam, sharing the terrain's edge
    vertices exactly; growing to 40 m cells), cells inside the tile skipped. Height follows
    `Terrain.height_at` at the seam, blends into rolling foothills, then a ridged mountain
    wall up to ~520 m with a lower notch to the south-east (the Greywold road). Shader:
    meadow at the seam, forest patches on foothills, strata rock on steep faces, snow above
    ~380 m. Visual only (no collision). ~246k tris, builds in ~1.5 s on the cloud CPU.
  - Verdicts: `village` 12h — hazy blue-grey ranges with snowy peaks close the horizon;
    first shot with real depth. Ridges look faceted at distance, peaks a uniform sawtooth.
    Fail (close). `hill` 16.5h — layered ranges good; foreground grass in deep shadow.
    `east` 17.5h — mountains lit beige under a navy dusk sky (dusk sky still too dark).
- Session 2026-10-10 11:00 UTC (ran in parallel with the 10:00 one; rebased onto it):
  - **Afternoon sky no longer navy (was Next 1).** The PhysicalSky is calibrated for a
    ~1.0 sun and ours is 3.0, so the sky (and its reflections) rendered far too dark.
    `sky_energy_scale` default 1.0 -> 2.6: clear blue at noon and 16:30.
  - Sky material is written only when energy/stars actually change (each write restarts
    the incremental radiance bake).
  - `tools/shots.sh` forwards extra words to shot.gd, so the diagnostic flags work:
    `tools/shots.sh "village v 30 16.5 nosdfgi"` (before, only the hour got through).
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
1. (done 11:00: sky_energy_scale 2.6.) Still to do: dusk (17.5–18.5 h) sky colour check, and
   verify SDFGI on a real GPU some day (cloud box can't).
2. Flora polish: bigger hero boulders/outcrops (3–6 m) and ruins on hilltops, hedgerows,
   shrubs/ferns under trees, leaf atlas with normals and more leaf shape per card at close
   range, tree LOD/impostors beyond 150 m.
3. (done 12:00: far mountain ring.) Polish: per-pixel normals / more ridge detail so far
   ridges are not faceted, vary peak shapes (domain warp), forest impostor speckle on
   foothills, playable-edge border (cliffs) with collision.
4. Terrain textures: CC0 grass/dirt/rock/moss (blocked here — see above); else improve the
   procedural layers.
5. (done 13:00: rook flocks + kites.) Still to do: a grazing sheep/deer herd that flees
   (needs a believable quadruped — procedural or CC0 from a GitHub mirror), bird calls once
   there is audio, birds roosting in trees at night, insects/fireflies in the light.
6. Harrowmere village blockout → final: slate roofs, timber, lantern posts (Kindle targets).
7. (done 14:00: rigged Mixamo humanoid + idle/walk/run blend.) Still to do: replace the sci-fi
   "Vanguard" with a mythic hero (robes, hair, face) — look for CC0/CC-BY realistic humanoids in
   GitHub repos (github/raw.githubusercontent work; the clip names Idle/Walk/Run + mixamorig bones
   let a Mixamo-rigged model drop in and retarget); jump/fall clips, foot IK on slopes, turn-in-
   place, cloth/hair sway; the staff (procedural PBR: worn iron caps, lacquered wood, cloth wrap)
   held via BoneAttachment3D on mixamorig_RightHand.
8. Combat (Ward stance): L×4 string, heavy with parry window, dodge + perfect dodge
   time-dilation, hit-stop, lock-on, stamina; Hollow Soldier enemy with telegraphs.
9. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
10. Every step: shots + bots, then update this file.

## Known bugs
- Player model is a sci-fi armoured soldier (Mixamo Vanguard) — placeholder-floor; no jump clip
  (airborne holds the walk stride), no foot IK, so feet float/clip on slopes.
- Rooks fly through tree crowns (no avoidance; the wheel anchor is 14 m up, crowns ~10 m).
- Cropped turf at rook sites shows the flat brown bare-ground colour (same root cause as the
  bare-ground bug: terrain shader needs a short-turf/soil layer).
- Rooks stay on the ground at night (should roost in trees).
- `village` shot spot: a dark wedge fills the left edge — the camera at (-30, 40) sits against a
  tree trunk; move the spot or keep flora clear of fixed camera spots.
- (fixed: shadowed surfaces pure black.) SDFGI is off on the cloud box (software GPU);
  whether SDFGI + sky ambient light shadows correctly on a real GPU is unverified.
- Late-afternoon sky renders dark navy.
- (fixed 12:00: world edge at 256 m — far mountain ring.) The ring has no collision; the
  player can walk off the tile edge onto nothing (needs a border in the streaming milestone).
- Far ridges look faceted (vertex normals on 40 m cells); dusk lights them beige under a navy sky.
- Grass streaming builds chunks on the main thread (6/frame); fine at walking speed, may
  hitch when gliding/fast travel arrives — move to WorkerThreadPool then.
- Shots: a Vulkan screenshot now takes ~3 min on lavapipe (trees + shadows); budget 3–4.
- Tree collision is a 4 m trunk cylinder only; the player can walk through low limbs.
- A new `class_name` needs `godot --headless --import` before scripts can use it as a type.
- Player capsule starts 0.5 m above ground and drops (cosmetic).
- Audio driver errors on the cloud box (no ALSA device); harmless, run with
  `--audio-driver Dummy` to silence if needed.
