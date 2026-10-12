# Progress

Content hours playable: 0.49
(the soldier fight can now be lost and retried from the rest point; walkable test valley under a drifting cloud sky whose cumulus throw moving shadows across the meadow and the far ridges, with weather fronts that roll in (cumulus thicken into a grey deck, wind, grey light, rain, wet ground, puddles that fill the hollows and dance with raindrop rings, drops that splash on the ground, and pools the hero splashes through, leaving rings spreading behind each step; heavy fronts throw lightning in the far deck that flashes the clouds and the land), grass, oak groves, boulders, rook flocks, wildflower drifts, butterflies by day, fireflies at night and midges in the evening light, played as a rigged animated humanoid
who can draw the staff, land a four-hit string and a chargeable heavy smash on a practice post, parry, and lock on to and fight one Hollow Soldier (thrust + sweep) down the meadow
(a few minutes of real combat); no quests or shrines yet. Game scope is
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
- Session 2026-10-11 23:00 UTC:
  - **Lightning for strong fronts (next item 9 pick).** New `world/lightning.gd` (child of
    Weather, `Weather.lightning`): once rain passes `min_rain` 0.7, a bolt strikes every
    7–26 s (slower in a weaker storm) 700–2400 m out, 70 % within the camera's forward
    arc. Each strike: 2–4 return strokes (spikes decaying in 50 ms, 60–160 ms apart); a
    branching channel (`_jag` midpoint displacement from the 1500 m cloud base to the
    Horizon/terrain ground, 4–7 branches + twigs) drawn as camera-facing ribbons with
    `shaders/bolt.gdshader` (white core in a violet glow, veiled by distant rain); a
    `Flash` DirectionalLight (blue-white, from the bolt's side, high) lights the land; the
    cloud shader gets `flash`/`flash_at`/`flash_col` and glows hot over the strike with a
    dimmer sheet across the deck; ambient, depth-fog and volumetric-fog light jump with the
    flash (added after world.gd rebuilds them each frame). Far strikes flash weaker (`_near`).
  - Gotcha: the bolt first drew as dark dashes. Not the glow (same with `noglow`) and not
    the bolt itself (bright in an isolated scene): TAA together with volumetric fog rejects
    a ~1 px line that only lives a few frames. Fix: ribbon ~8 px / core ~2 px wide at any
    range, additive at moderate HDR (also: keep blooming pixels moderate under the
    softlight glow, c + g * (sqrt(c) - c) goes negative for big g), render_priority 10 so
    it draws after the cloud dome (which sorted nearer and covered the bolt's top).
  - Bot `weather`: >= 2 strikes on their own in a full storm (3 in 22 s), a held strike
    flashes the deck/land (cloud flash, light > 0.5, ~800-tri bolt within the strike
    ring), all dark after, and no strikes once the sky clears. 13/13 bots pass.
  - Shot arg `bolt=<m>[,<yaw deg>]`: a strike ahead of the camera, frozen just after its
    first stroke. Shots `lt_night`..`lt_night4` (dark-bolt bug hunts), `lt_dbg` (red
    debug bolt: geometry right), `lt_ng` (no glow: still dark), `lt_night5`/`lt_day5`
    (fixed: a white jagged bolt under the lit deck, land flashed blue-white at night).
    Verdict: fail as Wukong shots (flat faceted mountain ring, ribbon grass), but the storm
    finally has a moment.
- Session 2026-10-11 22:00 UTC:
  - **Wake rings + a bigger foot splash where the hero wades (next item 9 pick).** Each
    footfall in a pool now starts a ring train in the water itself: `Weather.wade_splash()`
    writes (x, z, age, strength) into one of 8 new shader globals `wade_ring_0..7`
    (round-robin), `_update_wake()` ages them and clears them after `WAKE_LIFE` 1.8 s, and
    `terrain.gdshader`'s `wade_ripples()` adds a packet of ~3 crests (~9 cm apart) running
    out from the foot (front ~0.06 + 0.55 t^0.6 m, amplitude falling with age and 1/sqrt(r))
    to the puddle's normal, only inside pools (branch on `pud`), so the rings bend the
    SSR/sky reflection on the real water surface and never float or clip. Foot crown
    0.5 -> 0.75 m, opacity 0.9, a whiter tint, life 0.5 s.
  - Bot `weather`: rings spread while the hero runs through the pool and all fade after
    (up to 6 at once, 0 after). 13/13 bots pass.
  - Shot arg `wet=<0..1>` soaks the ground independent of the rain (pools under a light
    shower). Shots (rendered with `--fixed-fps 60`, run by hand, not via shots.sh):
    `wade wk_wade 72 13 rain=1.0` (downpour: the bigger foot crown reads, rings drowned by
    rain rings), `wade wk_wade3 58 13 rain=0.7 wet=1.0` (light rain: wake rings trail the
    hero's path across the pool). Verdict: fail as Wukong shots (Vanguard hero, ribbon
    grass); the foot crown's cup sheet reads as a white sickle at the foot (tune or drop it).
- Session 2026-10-11 21:00 UTC:
  - **Rain splashes + the hero splashing through pools (next item 9 pick).** New
    `shaders/splash.gdshader`: an upright camera-turned quad per particle drawing a crown of
    9 droplets on ballistic arcs over a thin cup-shaped sheet that collapses in the first
    third of its life (age from INSTANCE_CUSTOM.y, seeded by landing position).
    `Weather._update_splashes()` emits ~1500 splashes/s x rain on the terrain height inside
    the camera's view cone within 14 m (CPU-placed via `emit_particle`); `pool_at(x, z)`
    mirrors the terrain shader's puddle threshold (baked hollow vs the wet-driven level;
    new `Terrain.baked_hollow()`), and `_update_wade()` puts a big crown (0.5 m) + a small
    one at each footfall (every half stride, alternating feet) while the hero runs through
    standing water.
  - Tried first: rain drops colliding with a camera-following
    `GPUParticlesCollisionHeightField3D` and spawning splashes through a sub-emitter (would
    also have kept the ground under oak crowns dry). Under lavapipe neither the collision
    nor the sub-emitter fired (isolated test scene: no splashes), so it was dropped as
    unverifiable; worth retrying on a real GPU for rain occlusion under crowns.
  - Gotcha: ParticleProcessMaterial rewrites each particle's scale every step, so the
    scale in an `emit_particle` transform is ignored; splash size is the shader's `size`
    per emitter (`Splashes` 0.3 m, `WadeSplashes` 0.5 m).
  - Bot `weather`: drop splashes emitted while raining (>= 100 per 0.5 s), and the hero run
    across the nearest pool splashes >= 2 times there and <= 1 on the dry run-up (8 / 0).
    13/13 bots pass.
  - Shot spot `wade` (hero runs +X across the nearest pool, side view; render with
    `--fixed-fps 60` so the run and the splash ages are deterministic). Shots: `sp_pud`
    (downpour over a pool, before the CPU splashes), `sp_wade` (no splashes: the
    sub-emitter path), `sp_wade4` (drop splashes speckle the grass and pool, a small foot
    splash at the hero's stride).
- Session 2026-10-11 20:00 UTC:
  - **Oak crowns no longer blow out to white toward the sun (bug, next item 9 pick).** Cause:
    leaf `SPECULAR = 0.4` gives f0 = 0.16 * 0.4^2 = 0.026, and Godot's Fresnel peak
    f90 = clamp(f0 * 50) clamps to 1.0, so every sun-facing card hit full grazing sheen
    looking toward the sun. Now SPECULAR 0.2 (f90 ~0.3), roughness 0.72, backlight
    `col * (0.5, 0.6, 0.3)` (yellow-green transmission, weaker than the lit face).
  - Leaf atlas: the saturated rust leaves (12 %) read as apples at close range; now 4 % dull
    brown, the yellowing share more olive.
  - Shots: `lf_valley` (14 h toward the sun, same view as `cs_valley`: crowns olive with lit
    tops, no blossom), `lf_ridge`/`lf_ridge2` (15 h near oak: apple look gone after the atlas
    tweak). 13/13 bots pass. Note: the first Vulkan shot on a fresh box needs ~8 min (shader
    cache) and the `timeout 600` in shots.sh can let it fall back to opengl3; run the import
    first and allow time.
- Session 2026-10-11 19:00 UTC:
  - **Cloud shadows on the land (next item 9 / bug "clouds cast no shadows").** New
    `shaders/cloud_shadow.gdshaderinc` holds the deck's density function, shared by the sky
    dome (`clouds.gdshader` now includes it, so the deck drawn in the sky and the shadows on
    the ground are the same clouds) and `cloud_shade_at(world_pos)`: projects the point
    along the sun onto the 1.5 km deck (+ the wind drift) and darkens by up to 55 %. It is
    included through `weather.gdshaderinc`, computed per vertex in terrain, grass, leaves,
    bark, rocks and flowers (shadows are ~km-scale, so vertex rate is plenty and cheap) and
    per pixel on the coarse far mountain ring; multiplies ALBEDO and BACKLIGHT (Godot has
    no directional-light cookie, so it also dims the ambient share a bit).
  - Cheap 3/2-octave calls are levelled to the sky's 5/3 by padding the missing octaves'
    mean (agrees with the full deck on 96 % of points). New shader globals `cloud_drift`,
    `cloud_cover`, `cloud_thick`, `cloud_sun`, `cloud_shadow` (CloudLayer pushes them);
    strength = sun energy / 2.4, faded out as a front closes the deck (cloud 0.45 -> 0.9)
    and at night. `CloudLayer.shade_at()` is a CPU mirror for bots (later: audio/AI).
  - Bot `weather` checks the shadows: strength 1.0 at clear noon, 43 % of a 12 km window in
    cloud shade, strength 0 under the rain deck. 13/13 bots pass.
  - Shots: `cs_ridge` (15 h: sunlit golden valley on the left, foothills in cloud shade on
    the right, dappled midground: gives the Vale depth), `cs_hill` (11 h, low meadow view,
    no shadow edge in frame: reads unchanged), `cs_ridge2`/`cs_valley` (see gallery).
- Session 2026-10-11 18:00 UTC:
  - **Puddles + raindrop ripples (next item 9).** `Terrain.hollow_at(x, z)` (ring mean of 16
    heights at 3 m and 7 m minus the height) is baked into the terrain mesh's vertex colour;
    `Terrain.pond_at()` reads it back (bilinear) for placement. The terrain shader floods flat
    hollows (slope < 0.025) as the ground soaks: deepest dips first (0.85 m), down to
    0.27 m when soaked (~8 % of the ground), with a noise-wandering shoreline and a
    saturated mud ring. Water: level normal, roughness 0.03, murky albedo, plus a Fresnel
    sky-sheen emission fed the live haze colour by `world._apply_clouds` (`puddle_sky`),
    since the engine's sky reflection only sees the dim bare PhysicalSky, not the cloud mesh.
  - New shader global `weather_rain` (Weather pushes it); `rain_ripples()` in
    `weather.gdshaderinc`: 2 layers x 3x3 cells of drops (0.3 m cells, 0.9-1.4 s life), each a
    damped ring wave spreading 0.28 m; the drop rate follows the rain.
  - **SSR switched on** (was never enabled): 64 steps, pools mirror tufts and trees.
  - Grass clumps (rng only consumed where a pool can form, so the meadow layout elsewhere is
    unchanged) and flowers keep out of the pools; a few tufts stand in the water.
  - Shot spot `puddles` (nearest sure pool to the hero, looking toward the sun from 4.5 m).
    Bot `weather` checks the pool coverage (0.3-12 % of the ground; 8.0 %). 13/13 bots pass.
  - Shots: `pud1-3` (no pool / a black hole: the camera picked shallow dips, and the overcast
    sky radiance is too dim to reflect), `pud5` (flooded meadow pool with tufts mirrored at
    the far edge: reads as water), `pud6` (rain rings dance across the pool: good), `pud_eve` (17.6 h, rain 0.7 -> wet 0.31:
    no water yet, correct, but the dry hollow read as a bald dark patch where the grass was
    thinned -> thinning cut from 90 % to 75 %).
- Session 2026-10-11 16:00 UTC:
  - **Cloud sky (next item 9 / bug "the overcast sky has no cloud forms").** New `CloudLayer`
    (`world/clouds.gd` + `shaders/clouds.gdshader`, created by `world.gd` as `$Clouds`): an
    inside-out hemisphere (r 3.4 km, beyond the mountain ring, inside the 4 km camera far)
    riding on the camera. Each pixel projects its view ray onto a flat deck 1.5 km up, so
    the clouds foreshorten toward the horizon; domain-warped fbm cells with billow erosion
    give cumulus with cauliflower edges. 3-sample light march toward the light (sky sun by
    day, so sunset clouds glow rose; the moon at night) gives grey bellies and bright tops,
    plus a forward-scatter silver lining. Fair-weather cover 0.4 on clear days; a front
    raises cover to 1.0 and thickness (darker bellies); the deck drifts with the wind (4x
    faster in a front). Fog disabled on the dome; the far deck fades into the fog colour,
    and under a front it sinks fully into the rain haze toward the horizon.
  - `world._apply_clouds()` feeds light dir/colour, ambient-derived shade colour and the fog
    colour each frame (`cloud_light`, `cloud_shade` exports).
  - Fixed the dark/patchy overcast haze: under cloud the depth fog no longer takes half its
    colour from the PhysicalSky radiance (overcast radiance is dark away from the sun and
    bakes incrementally, so repeated shots disagreed): `fog_aerial_perspective` 0.5 -> 0.05,
    `fog_light_energy` 0.6 -> 1.0, volumetric anisotropy 0.6 -> 0.1 with cloud.
  - Shot tool: `tilt=<deg>` pitches the view up (sky shots); free camera far 3000 -> 4000 to
    match the player camera; prints weather/fog state after each shot.
  - Bot `weather` now also checks the deck: cover 0.40 -> 0.91 under the front, drift 24 m
    vs 80 m per 60 ticks, dome on the camera. All 13 routes pass.
  - Shots: `valley cl_noon2 60 12.5 tilt=12` (cumulus with shaded bellies over the ridges:
    the sky finally has shapes), `valley cl_rain6 60 12.5 tilt=12 rain=1.0` (one grey ceiling
    into the rain haze; first passes showed the fogged ridges as a bright cut-out, then
    black on the anti-sun side — fixed above), `sunset cl_dusk 60 17.4 tilt=10` (rose-lit
    clouds over the low sun). Fresh box note: run the headless `--import` before the first
    shot or every class_name fails to parse.
- Session 2026-10-11 15:00 UTC:
  - **Weather fronts (owner's "alive" list: rain, fog, storms, wind).** New `Weather`
    (`world/weather.gd`, created by `world.gd` as `$Weather`): long dry spells (6-15 min),
    then a front builds over ~70 s (cloud leads, rain sets in once the sky is mostly
    covered), rains for 2.5-6 min and clears; `cloud`, `rain`, `wind` (gusting with the
    front), `wet` (soaks in ~40 s of rain, dries over ~4 min). `force(strength, instant)` for
    bots/shots.
  - Shader globals `weather_wind` / `weather_wet` declared in `project.godot`
    `[shader_globals]`, shared via `shaders/weather.gdshaderinc` (`weather_wetten()` darkens
    porous surfaces and glosses them). Grass bends further with much stronger gusts and
    flutter; flowers (and perched butterflies) through `meadow_wind`; tree limbs lean and
    thrash via `tree_wind`; terrain, grass, bark, leaves and rocks get wet.
  - `world._apply_weather()`: cloud dims sun/moon/sky-sun, PhysicalSky goes Mie-hazy grey
    (less Rayleigh, flattened forward peak, lower energy; writes only on change), ambient goes
    flat grey, depth fog 0.0012 -> 0.008, more volumetric haze, colour drains (sat 0.82).
  - Rain: 9000 GPU particles in a 44 m box riding above the camera, velocity-aligned
    streaks turned to face the camera (`shaders/rain.gdshader`), slanted by the wind, faded
    near the lens and into the distance, darker at night.
  - Butterflies shelter as the cloud builds; midges and fireflies stop in the rain.
  - Bot route `weather`: clear noon -> forced front (arrives over 60 s, rain 0.85, light
    0.3x, fog up, drops emitting, insects gone) -> clears (sun and 40 butterflies back, ground
    drying) -> an automatic front is scheduled. All 13 routes pass.
  - Shot arg `rain=<0..1>` forces a front. Shots: `valley rain_valley 60 13 rain=1.0`
    (first pass: the wet slope went chrome white -> wet gloss floor raised to 0.3-0.55),
    `rain_valley2` (grey rain veil, wind-combed grass, ridges in haze: reads as weather; the sky
    is a flat grey with no cloud forms: fail), `player rain_hero` (soaked dark meadow with
    streaks; placeholder hero, no splashes: fail), `village rain_village 60 16.5 rain=0.7`
    (sky goes dark navy, not grey — see bugs).
- Session 2026-10-11 14:00 UTC:
  - **Meadow floor ground layer (bug "close-up grass over bare brown soil", next item 4).**
    `shaders/terrain.gdshader` rewritten: the flat ground is now a short sward of lying blades
    (two crossing stroke layers, combed by a noise wind direction, live green blades over dead
    thatch), white-clover patches (trefoil leaflets with the pale chevron), moss cushions on
    the cool north-east banks and hollows, trodden-earth patches with lobed dead leaves, twigs
    and small pebbles, and rock with lichen speckle on steep slopes. Each layer has a height;
    the shading normal is bumped per pixel from screen-space derivatives (replaces the old
    NORMAL_MAP that was not tangent-correct). Fine detail fades to its average by pixel
    footprint, so nothing shimmers far out. Rook feeding sites get the same turf.
  - Shot spot `turf [dx=] [dz=]`: 1.4 m up looking down at the floor a few metres from the hero.
  - Shots: `turf1` (first pass: litter blobs like coffee beans, white pebbles, red-brown soil:
    fail), `turf4 60 10.5 dx=-20 dz=12` — the gaps between clumps read as a straw-strewn
    meadow floor; still darker than a real one in clump shadow, and the clumps themselves are
    the weak point (flat ribbons, too regular). `flowers fl_new 60 10.5` vs the old `base_fl`:
    the black void under the drift is gone, the far meadow floor reads golden-green; at
    grazing angles the stroke pattern repeats like tread plate (vary blade length/curve).
    All 12 bot routes pass (shader-only change).
- Session 2026-10-11 13:00 UTC:
  - **Meadow wildflowers + butterflies perch on them (next item 5 / bug "butterflies hover on
    nothing").** New `MeadowFlowers` (`world/flowers.gd`): four procedural species with real
    geometry — ox-eye daisy (21 rays round a yellow disc, lobed basal leaves, 514 tris),
    meadow buttercup (two glossy 5-petal cups on a branched stem, 282), common knapweed (scaly
    bract bulb + purple floret brush, 536), yarrow (flat umbel of 64 five-lobed florets,
    feathery leaves, 816). `GrassField` scatters them per grass chunk within 56 m in drifts
    (drift noise; a slow species field so each drift is mostly one flower), dense near the
    camera and sparse farther (~6600 heads, ~3.6 M tris at the start), heads 0.5-0.9 m just
    over the grass tops, and keeps each chunk's head positions: `flower_near(p, r, rng,
    species)`, `flower_count()`.
  - `shaders/flower.gdshader`: per-part colour (stem/leaf, petal, disc, bract), glossy
    buttercups, petal backlight. New `meadow_wind.gdshaderinc`: the grass wind field
    evaluated at the plant root, so a flower sways as one; `butterfly.gdshader` adds the same
    offset scaled by `rest`, so a settled butterfly rides its flower head.
  - `Butterflies._spot` lands on a real flower head 85 % of the time (within 3 m of the
    chosen spot). Bot `butterflies` now also checks >= 500 heads loaded and >= half the
    settled butterflies on a head (6606 heads, 16/20). All 12 routes pass.
  - Shot spot `flowers [species=0..3]`: knee height in a drift near the hero with soft far DOF.
    `tools/flower_tris.gd` prints each flower mesh's triangle count.
  - Shots: `butterflies fl1 60 11 species=0` — a tortoiseshell settled on a yarrow umbel
    (first version, umbel too sparse; densified after). `flowers fl4 60 10.5` — a buttercup
    drift speckles the meadow with yellow heads above the grass: reads as a living meadow;
    still fails Wukong because of the black under-grass soil and flat grass ribbons.
- Session 2026-10-11 12:20 UTC:
  - **Butterflies by day (next item 5, owner's "alive" list).** New `Butterflies`
    (`world/butterflies.gd`, created by `Insects` as its child) streams 40 butterflies in a 30 m
    bubble round the camera from 8.5-10 h to 17.6-18.6 h. Four species: small tortoiseshell,
    cabbage white, common blue, peacock (weighted, sized per species, 3.4-6.2 cm span). Each
    settles over the grass heads (0.42-0.72 m) for 4-14 s, wings shut overhead and slowly
    working, or (non-whites, 60 %) held open to bask with an occasional close; takes off on a
    jinking, bobbing flight to a perch 3-12 m away; bursts up and away when the hero comes within
    2.2 m (+0.3 m per m/s of run speed), then drifts off to settle away from them.
  - New `shaders/butterfly.gdshader`: one PlaneMesh per insect hinged at x = 0; ~9 Hz beat
    with a fast downstroke and a lagging hindwing in the vertex shader; wing outline (forewing
    + hindwing ellipses), body, head, antennae, radial veins, dark margin, pale scale fringe;
    per-species upper side (front face) and duller underside (back face), backlight
    translucency (whites most).
  - Bot route `butterflies` (added to the default list): noon census 22 settled/18 flying,
    height band, a settled one put up by the walking hero, streaming after a 300-tick run,
    none out at 20 h. All 12 routes pass.
  - Shot spot `butterflies [species=0..3]`: macro camera 20 cm from a settled one with
    far depth of field (`CameraAttributesPractical`).
  - Shots: `butterflies bf3 60 11 species=0` — macro with DOF, reads as a basking butterfly,
    pattern washed out by the grade, hovers on no stem; `bf2` (old 0.5 m framing) peacock is
    too small to read. Fails Wukong (flat grass ribbons over bare soil dominate the close-up).
- Session 2026-10-11 11:00 UTC:
  - **Soldier thigh and boot wraps (next item 8).** `HollowRags` now also winds fitted hemp
    bandages round each thigh (UpLeg -> Leg, 16..90 %, 9 turns) and each boot (Foot -> ToeBase,
    0..92 %, 4 turns, like puttees), with the same armour-fitted radius as the shin/forearm
    wraps, so no Vanguard plate shows on the legs any more. 8 wraps per soldier; they burn away
    with the body. Bot `soldier` checks 8. All 11 routes pass.
  - Shots: `soldierface legs3 60 11 u=0.2 lit legs nograss` — thighs and shins read as bound
    cloth; the boot wrap is a shapeless lump at the ankle and the thigh wrap is very thick (it
    hugs the plated thigh). `soldierface wraps3 60 11 u=0.2 lit` — side: the whole silhouette
    is now hood, mantle, tabards and bandages; coherent revenant, but padded/bulky. Fails Wukong.
  - Fresh-box gotcha: run `.tools/godot --headless --path game --import` BEFORE the first shot
    or bot, or the class cache is missing ("HollowSoldier not declared") and shots fall back.
- Session 2026-10-11 10:00 UTC:
  - **Soldier shin and forearm wraps (next item 8: leg wraps/greave cloth).** `HollowRags._wrap`
    winds a hemp bandage tube round each shin (LeftLeg/RightLeg -> Foot, 14..93 % of the bone)
    and forearm (ForeArm -> Hand, 22..97 %). The tube's radius is fitted to the armour
    underneath: every skinned vertex weighted >= 0.25 to the bone is taken to body space via the
    skin's bind pose and the bone rest, binned by height (10) and angle (16), the max radius per
    cell kept, empty cells filled/smoothed (neighbour max x0.9/0.94, floor 0.42 x max), +1 cm /
    0.8 cm pad. So nothing pokes through; measured greave is 6-8 cm in front, 16 cm at the calf.
    Each turn steps out 4 mm at its leading edge. Rides the bone rigidly (BoneAttachment3D).
  - `rag.gdshader`: new `wrap_turns` uniform: spiral bandage strips with a shadowed crease under
    each lap (albedo, AO and normal), no sway/flutter on wraps; the frayed end is at the
    ankle/wrist. The wraps share ember/hit_flash/dissolve so they burn away with the body.
  - Shot options `legs` (low close camera on the soldier's shins, with `soldierface ... lit`) and
    `nograss`. Bot `soldier` checks 4 wraps. All 11 routes pass.
  - Shots: `soldierface legs2 60 11 u=0.2 lit legs nograss` — bandaged shins, strips visible;
    still bulky (the greave itself flares 16 cm at the calf). `soldierface wraps2 ... lit` — side:
    the silhouette is now cloth over most of the body. Fails Wukong: Vanguard thighs/boots,
    padded look.
- Session 2026-10-11 09:00 UTC:
  - **Hollow Soldier rags (known bug: the sci-fi Vanguard armour silhouette showed).** New
    `HollowRags` (`enemies/rags.gd`) builds five procedural cloth pieces in body space and
    hangs them on skeleton bones via BoneAttachment3D (an offset node makes the children's
    local space the body space at rest): a deep hood on the head, open at the face so the
    face sits in a dark void and closing at the throat; a shoulder mantle on Spine2, open at
    the front so the ember chest shows, longer at the back, 9 soft folds; a sash round the
    hips; and a front and back tabard on pivots at the waist. The tabards swing about the
    waist with whichever thigh goes forward/back (read from the bone poses, x1.1, capped
    40 deg, smoothed), and every hem trails the body's motion through a damped spring
    (`sway` uniform) plus a slow flutter.
  - New `shaders/rag.gdshader`: woven hemp (over-under weave that fades to its average below
    a pixel, thread relief in the normal map), grime streaks, dye/rust stains, soot climbing
    from the hem, torn hems and moth holes by discard, singed hem edges that glow faintly with
    `ember`; shares `ember`/`hit_flash`/`dissolve` with the hollow skin so the rags flare and
    burn away with the body (the soldier's `_mats` include them).
  - Bot `soldier` extended: 5 rag pieces, tabard swung up to 40 deg in the fight, rags
    dissolve 1.02 after the death. All 11 routes pass.
  - New shot option `soldierface ... lit` (camera swung toward the light-travel side).
  - Shots: `soldierface rags5 60 11 u=0.2` — front: hooded, mantled, tabarded revenant with the
    ember glowing through the open chest; reads as a cloaked Hollow, not sci-fi. Fails Wukong:
    backlit, greaves still the Vanguard's, tabards boxy. `soldierface rags4 60 11 u=0.2 lit` —
    side: hood/mantle/sash read as cloth; tabards hang stiff as boards.
- Session 2026-10-11 08:00 UTC (ran in parallel with 07:00, which landed hero death first; this
  session's version was folded into it):
  - **Death fall bends at the joints, the staff drops (known bug: legs sank into the ground,
    plank pose, staff stayed gripped).** A new `Crumple` SkeletonModifier3D
    (`player/crumple.gd`, last on the skeleton, after the arm IK) folds the knees 95 deg,
    flexes the hips 18 deg, curls the spine 22 deg, swings the arms forward and bends the
    elbows, and turns the head 70 deg aside as the body lands. The model now sinks only by the
    shin's swing (capped so the knee rests on the grass, measured from the skeleton) and tips
    80 deg forward about the knees while the knee bend unwinds, so the shins swing back flat and
    the body lies face-down with the legs extended. A drawn staff falls out of the hands and
    topples flat into the grass (`StaffCombat.drop`, new DROPPED state, gravity fall); on waking
    `StaffCombat.restore` puts it back on the back (replaces the `_wield` follow).
  - Bot `death` extended (staff drawn first): staff dropped, 0.06 m above the grass once down;
    knelt hips 0.47 m, knee 0.06 m (on the grass, not through it); staff on the back after
    waking. Bots: all 11 routes pass.
  - Shots: `soldier kneel2 60 15.5 strike u=0.5 fallen fallen=0.55` — hunched on folded knees,
    one arm out. `... fallen=1.6` — face-down, legs extended, head turned. Both read as a body
    going down; fail Wukong on the Vanguard armour and coarse grass, which does not flatten
    under the body.
- Session 2026-10-11 07:00 UTC:
  - **Hero death (known bug: health 0 did nothing).** The killing blow now rocks the hero back,
    the knees buckle (hips sink 0.46 m, chest folds 22 deg), then the body pitches forward from
    the knees like a falling weight, bounces a few degrees and lies face-down (88 deg). The
    staff and grip targets go down with the body (`combat._wield` follows the death transform).
    The idle clip runs down to a stop as the body hits the ground. All input is dead; further
    blows miss. At 1.9 s the screen sinks to a warm black over 1 s, "F A L L E N" surfaces in
    pale bone with a thin rule, and at 3.4 s the hero wakes at the rest point (the start until
    lamplighter shrines exist; `Player.respawn_point/respawn_yaw`, set by `world.gd`) at full
    vitality and stamina, camera behind, and the black lifts over 1.2 s. Hollow Soldiers stop
    treating a fallen hero as a target (walk back to their post), and on waking every living
    enemy `return_to_post()`s at full health, at ease. DESIGN.md combat section has the rule.
  - New bot route `death` (in `tools/bots.sh` defaults): thrust kills a hero at 10 hp, 0 swings
    and 0 dodges while down, body tips 88 deg, soldier strikes 0 times on the body, veil reaches
    1.0, hero wakes 0.00 m from the rest point at 100/100 after falling 26 m away, soldier back
    at its post at 90/90, veil gone, hero can be hit, walk and swing again.
  - New shot option `soldier ... fallen fallen=<s>` (the hero `s` seconds after a killing blow,
    framed on the body).
  - Bots: all 11 routes pass.
  - Shots (Forward+ lavapipe): `soldier fallen 60 15.5 strike u=0.5 fallen fallen=0.6` — the hero
    on buckled knees, arms down with the staff (before the `_wield` fix the hands stayed up in
    the air). Fails Wukong: hero at the frame edge, soldier missing, Vanguard armour.
    `... fallen=1.6` (camera looking down on the body) — face-down in the grass, reads as a
    fallen body; fails on the rigid plank pose and the sci-fi armour.
- Session 2026-10-11 06:00 UTC:
  - **Hero hit reaction (known bug).** A blow that gets through now staggers the hero for
    0.5 s: the upper body snaps back 17 deg from the hip away from the attacker (with a small
    twist and sink) and settles, a 0.65 m shove decays out, any swing or heavy charge is
    broken off to guard, attacks are locked out, stamina does not recover, and a dodge can
    break it after 0.24 s. A hit late in a dodge (past the i-frames) loses the dash. The
    released heavy's downswing (release .. end of its hit window) is armoured: it takes the
    damage with a lighter shake and keeps coming (`StaffCombat.has_hyper_armour`). DESIGN.md
    Ward row and the telegraph paragraph updated.
  - New bot route `flinch` (in `tools/bots.sh` defaults): thrust on an early-raised charge
    breaks it, 0 swings while mashing light in the stagger, 17 deg lean, 0.53 m shove away
    from the soldier, dodge refused at once and taken after 0.24 s, heavy downswing armoured.
  - New shot option `soldier ... strike u=0.5 flinch` (the hero at the stagger's peak).
  - Bots: all 10 routes pass.
  - Shots (Forward+ lavapipe): `soldier flinch 60 15.5 strike u=0.5 flinch` — the hero rocked
    back with the staff thrown wide and a dust burst: the reaction reads. Fails Wukong: the
    soldier is again missing from the frame (same bug as the stagger shot), hero small,
    faceted ridges. `village dawn 60 5.6` — first dawn check: mauve glow behind the east
    ridges, valley mist, blue west sky; reads as a real pre-dawn. Fails on the faceted ridges
    and a dark near-camera rock clipping the left edge.
- Session 2026-10-11 05:00 UTC:
  - **Last sunlight and twilight desaturated (known bugs).** The low-sun colour went from
    (1.0, 0.62, 0.36) to a warmer gold (1.0, 0.76, 0.56), and the rose grazing light under the
    horizon from (0.95, 0.5, 0.45) to a dusty mauve (0.84, 0.7, 0.72). The red-brown ground
    had been saturating both into an orange/rose wash.
  - **Stars fade in (known bug).** PhysicalSky has no night-sky energy, so `world.gd` builds
    the star field at 4 brightness levels (0.12/0.3/0.55/1.0) and steps through them from 3 deg
    below the horizon (first stars, ~18.4 h) to 10 deg (full field, ~19.4 h). Dawn is the
    same in reverse. Only 4 sky rebinds per dusk. Star tint is now cooler, to offset the
    gold extinction tint.
  - Bots: all 9 routes pass. Shots (Forward+ lavapipe, ~5 min each on this box): `sunset`
    17.75 before/after: an orange-red meadow before, gold after. Now reads as golden hour,
    but fails Wukong on the faceted ridges and the leaf-card canopies. `sunset` 18.4: mauve
    afterglow, no rose wash. Fails on near-black canopies and coarse grass. `hill` 19.0:
    sparse first stars over fireflies. Fails, because the sky there is a brown/amber colour
    (see bugs).
- Session 2026-10-11 04:40 UTC (a parallel session; its own sky-only-light fix collided with
  04:00's, which was kept, and these follow-ups were ported on top):
  - **Twilight land no longer goes black.** The ambient now follows the afterglow
    (`max(day, 0.8*afterglow)`, afterglow = 1 with the sun up .. 0 at -9 deg), and as the sun
    fades out a faint rose light (0.4 * afterglow^2) stays, grazing from 1 deg up on the sunset
    side, so near grass, trunks and valley haze read under the glow.
  - **Volumetric haze no longer buries the afterglow.** `volumetric_fog_sky_affect` was keyed to
    `day`, which is ~0.1 right at sunset, so the dark haze covered 90% of the glowing sky. It now
    stays 0.1 until -3 deg and reaches 1.0 (the full-night value) at -9 deg.
  - Bots: all 9 routes pass. Shot: `sunset` 18.4 — warm glow behind the peaks under a violet sky,
    backlit oaks, the meadow and grass lit: reads as a real evening; fails Wukong on the
    over-saturated rose/red valley floor, leaf-card canopies and faceted ridges.
- Session 2026-10-11 04:00 UTC:
  - **Dusk afterglow (known bug / Next 1 dusk check).** Root cause: PhysicalSky's sun energy
    term is ~(1-exp(-elevation)), so the sky went black the moment the sun set, while the sun
    (still `visible` down to -6 deg) kept washing the meadow red. `world.gd` now splits them:
    the real `Sun` is `SKY_MODE_LIGHT_ONLY` and fades out between +1.5 and -1 deg elevation;
    a new sky-only `SkySun` (no shadow, cull mask 0) paints the sky, holds at 2.5 deg while the
    sun sinks, fades over 0..-9 deg (civil/nautical twilight) with a x1.6 boost on its floor,
    loses its disc once the sun is down, and cools amber -> blue-violet into the blue hour.
  - New shot spot `sunset` (looks +Z, the evening sun's side).
  - Bots: all 9 routes pass (no gameplay change).
  - Verdicts (Forward+ lavapipe): `ridge` 18.4 before = black sky over a deep red meadow;
    after = dark navy dusk, no red wash. `sunset` 18.2: a warm afterglow behind silhouetted
    ridges — the first dusk frame that reads as a real evening, but fails Wukong on faceted
    ridges and a near-black foreground. `sunset` 18.6: violet blue hour with stars — fails on
    the stars snapping on too dense and gold-tinted. `ridge` 17.8 (sun still up): the
    low-sun light paints the whole meadow a saturated orange-red; too strong.
- Session 2026-10-11 02:00 UTC:
  - **Night sky / ridge cut-out fixed (known bug).** Root cause: the blue "glowing ridges" were
    the moonlit *volumetric* fog in front of the far ring; `volumetric_fog_sky_affect` was 0.1,
    so the same fog covered the mountains fully but the sky only 10%, and the ridges read as a
    cut-out on black. `world.gd` now sets `volumetric_fog_sky_affect = lerp(1.0, 0.1, day)` and
    `fog_sky_affect = lerp(0.6, 0.12, day)`: at night the haze continues into the sky (deep
    moonlit blue, stars still visible), ridges are soft layered silhouettes; daytime unchanged.
    (Tried first: an airglow band in the star texture. No effect, because PhysicalSky scales
    `night_sky` by extinction, which is ~0 near the horizon. Reverted.)
  - **Orange light pool fixed (known bug).** It was `Body/Lantern/LanternLight` in
    `player.tscn`: a 2.5-energy, 7 m shadowed OmniLight with no lantern mesh, on day and
    night. Removed; at night the hero is lit by the moon and fireflies only.
  - Bots: all 9 routes pass. Shots: `hill` 22:00 before/after, `player` 21:30 before/after,
    `day` 10:00 (no regression), `ridge` 18.4 (dusk, see bugs).
  - Verdicts: night meadow: sky and ridges now read as one moonlit place, but fail Wukong
    (faceted ridges, coarse close grass). Moonlit hero: correct light now, but fails on the
    sci-fi placeholder hero and tree canopies blowing out in the haze.
- Session 2026-10-11 01:00 UTC:
  - **Insects in the light (Next 5, owner's "alive" list).** New `world/insects.gd` +
    `shaders/insect.gdshader` (additive camera-facing glow dots on two MultiMeshes, CPU motion).
    - Fireflies after dusk (fade in 18.3–19.3 h, out 4.3–5.4 h, the active share ramps with
      the night): 420 in a 34 m bubble that streams with the camera (re-enter ahead of travel,
      full refill on a teleport), meadow only (no rock slopes), hover 0.35–2.8 m with a slow
      wandering flight and bob, each blinks on its own 2.4–5.5 s rhythm (0.6–1.4 s swell).
      The hero walking or running through them scatters them away and upward, all flickering
      bright for 1.4–2.4 s. The 6 brightest near the camera carry a small OmniLight (2.4 m,
      no shadow) so the grass glows green around them.
    - Midge swarms by day (7–9 h in, gone by 19 h): 6 swarms x 40 beside tree trunks near the
      camera, head high, a dancing 0.6 m cloud; brightness is a CPU backlight term (camera ->
      swarm vs. the sun), so they glint against the low sun and almost vanish with it behind
      you. Crowd one and it drifts off, then settles back by its trunk.
  - Bots: new `insects` route (noon: none lit, midges on; walk into a swarm -> it flees;
    22:00: 100/420 lit, 0.14–2.87 m over the ground; sprint 136 m through them -> 152 startled,
    bubble kept within 38 m of the camera; dawn: none lit). All 9 routes pass.
  - Shot spots `fireflies` (low over the night meadow beside the hero) and `midges` (a swarm
    framed against the sun).
  - Verdicts (Forward+ lavapipe): `fireflies` 21:30 — ~15 lit specks with soft halos and green
    pools of light on the grass: it finally reads as a living night meadow, but fails Wukong on
    the sci-fi hero and the far ridges glowing brighter than the black sky. `midges` 17:36 —
    tiny glints by the trunk in the golden backlight: right scale, subtle in a still; canopy
    leaf cards still flat/large. Both fail the Wukong bar for those reasons.
  - Note: a per-instance "backlight weight" through INSTANCE_CUSTOM.b + a sun_dir uniform made
    the midges invisible in renders (never root-caused); the CPU-side per-swarm term replaced it.
- Session 2026-10-11 00:00 UTC:
  - **Hollow Soldier sweep (Next 8, eighth part).** A second spear move so the fight can't be
    read by distance alone: when the hero crowds inside 2.1 m (or after two thrusts in a row)
    the soldier slides its grip 0.22 m toward the butt, winds the spear low round to its
    right (blade behind it, chest turned away, crouched 0.14 m, a trembling coil at the end),
    same ember flare + blade glint, then cuts a flat right-to-left arc (-111..88 deg measured
    from the placed spear) in 0.36 s with up to a 1.3 m stride that stops 1.15 m short of the hero (the first cut
    shot showed it walking into the hero's body), 26 damage, long 1.15 s recovery.
    It tracks the hero until the release (turn rate 6*(1-u^3)), so a strafe that beats the
    thrust gets caught. Contact is the blade's real bearing passing the hero's (inside 2.6 m),
    so it lands on the side the blade actually is. Parry and dodge rules are the same as the
    thrust's (shared `receive_attack`).
  - Sweep poses: the butt hand stays planted at the belly as the pivot, the front hand swings
    out with the blade, chest turns 0.3x the blade angle; tuned with an offline grid search
    over the same reach model (`_place`) for <11 deg axis error, hands outside the torso,
    0.6 m arm reach (the thrust poses keep 0.45). `_place` and `_lerp_pose` accept optional
    5th/6th elements (grip slide, reach).
  - Bots: new `sweep` route — crowded at 1.7 m it picks the sweep, stood -> hit (100 -> 74);
    strafing through the last 0.45 s of the wind-up: thrust **miss**, sweep **hit**; dodge back
    on the glint -> dodged, no damage; heavy raised 0.06 s before release -> parried, soldier
    staggers. The `soldier` and `heavy` routes pin thrusts for their scripted steps
    (`force_move`); the soldier fight now mixes in sweeps. All 8 routes pass.
  - Shot flag `sweep` on the `soldier` spot (wind-up or `strike` u=...).
  - Verdicts (Forward+ on lavapipe): `sweep_wind` — spear coiled flat behind the soldier's
    right side, ember flaring, clearly a different tell from the thrust's draw-back;
    `sweep_mid` — spear cutting flat through the hero at waist height. Both fail the Wukong
    bar: sci-fi placeholder bodies, no spear trail, faceted far ridges. Not a living-place
    clip either (empty meadow, no wildlife in frame).
- Session 2026-10-10 22:00 UTC:
  - **Staff poses re-authored (Next 8, seventh part).** Every light-string key, the guard,
    the raised hold and the heavy smash were re-solved so the staff points where it was
    authored (axis error 0–4 deg everywhere; was up to 65 deg, staff lying sideways) and the
    shaft never passes through the chest or head, including mid-blend between keys (checked
    at 5–7 points per segment). Done with an offline optimizer over the same grip-reach model
    the game uses; grip error in the combat bot dropped 0.063 m -> 0.000 m.
  - New optional 6th key element **grip slide** (metres, negative = hands toward the butt):
    the heavy smash and the overhead (step 3) come down on the centre line 1.3–1.37 m ahead
    with a long grip; the spin finisher lets the staff run out 0.3 m through the hands after
    the wind-up (tip radius 1.25 -> 1.55 m) and draws it back before the recovery.
  - Guard is now a chest-high diagonal (tip forward-left, a little low) instead of a belly
    guard that solved sideways.
  - Bug fixed: hit detection sub-steps interpolated the staff pose but not the body's spin,
    so the spin finisher tunnelled past targets (28 deg of body yaw per tick at bot speed,
    ~15 deg at 30 fps). Sub-steps now turn the body back by the yaw applied this tick.
  - `tools/pose_check.py` now parses `combat.gd` directly (every key + halfway blends,
    torso/head clearance, grip slide) and exits 1 on a failure — run it after touching poses.
  - Bots: all 7 routes pass (combat now hits on all four steps, punish smash lands).
  - Verdicts (Forward+ on lavapipe, ~4 min/shot; the spin shot fell back to opengl3 once):
    sweep (`swing0`) — staff flat at shoulder height through the post with chaff: reads as a
    sweep; overhead (`swing2`) — vertical trail on the centre line; spin (`swing3`) — staff out
    to the side. All fail: placeholder sci-fi body, and the swing camera puts the post in front
    of the hero (shot-tool framing should orbit to the side). Note: in `tools/shots.sh` args
    the 2nd token is the output name, so `swing0 u=0.45` names the file `u=0.45.png`.
- Session 2026-10-10 21:00 UTC:
  - **Ward heavy + parry (Next 8, sixth part).** `attack_heavy` (right mouse / pad) is now
    live. Press raises the staff overhead (0.18 s ease from wherever the arms were, chest
    turned away, a tremble that grows per tier); hold climbs tiers at 0.5 s / 1.1 s (a cold
    metal glint at the ferrule + small shake per tier); release (or 2.6 s held) brings it
    down: a hitch at the top, then the smash into the ground ahead with a soil/grit burst and
    shake. Tier stamina 16/22/28, power 1.8/2.4/3.2 (hit-stop up to 0.21 s; tier 2 breaks the
    soldier's poise even mid-thrust). A tap still raises for 0.16 s then smashes at tier 0.
    While charging the hero shuffles at 1.1 m/s, tracks the lock / nearest foe, no stamina
    regen. The smash steps in with one decisive stride (4 m/s from release, 4x accel) and
    stops at reach. From a light swing the heavy cuts in once the strike is past, otherwise
    it queues; a dodge cancels the charge back to guard.
  - **Parry:** the first 0.25 s of the raise deflects a blow (`Player.receive_attack` asks
    `StaffCombat.try_parry` first -> "parried"): 0.13 s freeze on both fighters, a big metal
    spark burst between them, shake, the charge jumps to tier 1. `HollowSoldier.parried()`
    bats the spear aside: 1.3 s stagger with a 1.8x recoil lean, poise reset, short
    knock-back — the window for the charged punish.
  - Found + fixed: the authored low smash pose was unreachable (grips clamp to shoulder
    reach and the solved staff came out ~96 deg off, lying sideways at chest height).
    `tools/pose_check.py` replays `_solve()` offline and prints each pose's axis error —
    it also shows the *light string* guard/sweep/overhead-end poses are 30–65 deg off (bug below).
  - DESIGN.md: Ward heavy is now the chargeable rising smash with the parry on the raise;
    Pillar's heavy keeps the AoE slam and gains hyper-armour charging.
  - Bots: new `heavy` route — tap -> post hit at power 1.8 with slam FX; hold 1.4 s -> tier 2,
    power 3.2, stamina -28; raise 0.1 s before the thrust lands -> "parried", no damage,
    soldier STAGGER, tier 1; keep charging to tier 2, shuffle in, release while it reels ->
    hit (90 -> 48); raise 0.7 s early -> window gone, thrust hits (100 -> 78).
  - Shot spot flags `soldier ... strike parry` (deflect moment) and `soldier ... stagger smash`.
    The action runs after the warm-up frames: pausing the tree (as `impact` does) froze the
    world's sky/terrain update and grass streaming — the first parry shot had bare red ground.
  - Verdicts: `parry2` 10h — the deflect reads (spark burst between staff and spear, soldier
    recoiling); fail: placeholder sci-fi bodies, spark is a soft orange blob without streaks,
    flat glaring foreground grass. `smash2` 10h — staff driven down low ahead of the hero;
    fail: slam dust renders as a grey sphere, a tier-glint cloud hangs in the sky, the
    staggered soldier is not in frame (shot tool), placeholder body. Renderer unchanged:
    Forward+ on lavapipe under xvfb, ~3 min per shot.
- Session 2026-10-10 20:00 UTC:
  - **Lock-on (Next 8, fifth part).** `lock_on` (middle mouse / pad R3) toggles. The pick takes
    the hittable nearest the camera's line of sight within 16 m (score = angle·6 + dist·0.35);
    enemies always beat practice targets. Pressing with nothing to lock recentres the camera
    behind the hero. While locked: the camera yaw/pitch ease (rate 10) to put the target's upper
    chest ahead and a little below centre (steeper when close so both fighters fit), the spring
    arm draws back to 5 m, the mouse no longer orbits — a sharp sideways flick (> 90 px within
    0.25 s) switches to the nearest target on that side; every swing opens toward the target
    regardless of the stick; standing still, the hero squares up to it. Lock breaks past 24 m;
    when the target dies it hands over to the next enemy in range or releases.
  - HUD reticle: bone-white dot in a thin pale-gold ring with a dark halo at the target's chest;
    a new lock pops the ring in from wide; fades on release (`Hud.reticle_visible()`).
  - Bot bug fixed: scripted routes (combat/dodge/soldier) also ran the walk-waypoint follower,
    which fed stick input underneath the test. Scripted routes now get an empty route.
  - Bots: new `lockon` route — far press doesn't lock the 20 m soldier; near press from 34° off
    locks it; camera error 0.16 → 0.000 rad in 1 s; circle-strafe at run speed worst 0.17 rad;
    square-up 0.000 rad; reticle on screen; kill → lock releases, reticle gone. All six PASS.
  - Over-the-shoulder framing: while locked the camera slides from 0.5 to 1.05 m right and the
    aim is solved from the camera's real position, so the hero stands left of frame and no
    longer hides the target (`lock2` had the soldier completely behind the hero).
  - Shot spot `lockon [u=]`: soldier 4.7 m ahead in its wind-up, follow camera swung by the lock.
  - Verdicts: `lock1` — locked the post (shot tool's camera pivot was stale), camera at -0.6
    pitch staring at grass: fixed (pivot updated, pitch floor -0.45). `lock3` 10h — both
    fighters framed, reticle on the soldier's chest reads; fail: placeholder sci-fi bodies,
    foreground grass glare, framing a bit steep.
- Session 2026-10-10 19:00 UTC:
  - **First enemy: the Hollow Soldier, spear variant (Next 8, fourth part).**
    `enemies/hollow_soldier.gd` (`HollowSoldier`, CharacterBody3D, layer 4; the hero now
    collides with it). Body = the rigged humanoid at 1.06–1.08x scale with
    `shaders/hollow.gdshader`: its own albedo/normal detail turned to grey ash-stone, warped
    Voronoi fissures + soot, ember glow concentrated in a chest band (feet-relative world
    height, front-facing), `ember` / `hit_flash` / `dissolve` uniforms. A chest OmniLight
    (cull-masked off its own visual layer 2) throws ember light on the ground and the hero.
    `enemies/spear.gd` (`HollowSpear`): 2.25 m lathe — iron butt spike, grey checked ash-wood,
    two tarred cord bindings, forged socket, leaf blade with a diamond section;
    `shaders/spear.gdshader` (wood / pitted rusted iron / cord). Held two-handed with
    TwoBoneIK3D + SpineTwist like the staff.
  - AI: IDLE (holds its post, notices at 12 m) → STALK (closes in, eases off near 2.7 m)
    → WINDUP 0.78 s (tracks early, commits late; draws the spear back, leans away, chest ember
    flares to ~4x, a star glint runs up the blade at 55–92%) → STRIKE 0.24 s (1.1 m lunging
    thrust; resolves at 35% via `Player.receive_attack` — a hero who was in the line when the
    thrust launched is still "caught", so a dash out of it scores the perfect dodge) →
    RECOVER 0.95 s (punish window) → STALK. Health 90, 13 per unit of staff power; poise 30:
    hits during the later wind-up/thrust don't interrupt unless poise breaks; otherwise
    STAGGER 0.5 s with knockback. Death: leaves the hittable group, folds forward along the
    killing blow, the ember gutters, the body dissolves into ash flakes (burning edges), the
    spear topples flat onto the ground; freed after 5 s. Hit-stop freezes it with the hero.
  - Soft lock: with no stick input, a swing's opening turns the hero toward the nearest
    hittable within 3.4 m / ±75° (`StaffCombat.magnet_target`). Fixes the "opening sweep
    misses" known bug.
  - Bug found by the combat bot: a CharacterBody added at the origin and moved afterwards
    shoves the hero on the first physics step — set `position` before `add_child`.
  - Bots: new `soldier` route — idle at 20 m, notices + closes in (3.6 s), thrust 1 hits
    (100→78), max ember 4.2, a dodge on the thrust's launch → perfect, then the string kills
    it (6–9 s, 5 staggers), removed from hittable, freed. All five routes PASS.
  - Shot spots `soldier [u=] [strike|stagger|dead]` (side-on, both fighters) and
    `soldierface` (close 3/4 portrait). They step the soldier by hand: awaiting physics
    frames with the render loop off stalled under Vulkan on this spot.
  - Verdicts: `sol1` (first shader) — reads as a lava golem, fissures everywhere: fixed.
    `sol3` portrait at the glint — grey ash body, ember chest, glint on the blade reads as a
    tell; fail: sci-fi Vanguard silhouette under the ash, backlit, foreground grass blown out.
- Session 2026-10-10 18:00 UTC:
  - **Dodge, perfect dodge and a vitality/stamina HUD (Next 8, third part).** `dodge` (Ctrl /
    pad B): a low dash-step 3.6 m toward the stick (camera-relative), or a 2.4 m hop back with
    no input. Speed falls off as 1-u² over 0.42 s; the hero turns into the dash, leans 24° from
    the hips and sinks 17 cm, the run stride plays at 1.9x (the hop back plays the walk in
    reverse, leaning away). Costs 16 stamina, no regen during it; i-frames 0.02–0.32 s; a second
    dodge can chain from 0.34 s. A dodge cancels a swing in progress (not during hit-stop) and
    the arms ease back to guard over 0.16 s from wherever the swing was (`cancel_to_guard`).
  - Enemy hook: `Player.receive_attack(attacker, damage) -> "perfect" | "dodged" | "hit"`.
    A blow arriving in the first 0.17 s of a dodge is a **perfect dodge**: the world drops to
    0.25x for 0.45 s (unscaled) and eases back over 0.25 s, +25 stamina, and a burst of pale-gold
    motes with a warm flash sheds where the blow passed (`fx/dodge_fx.gd`). Later in the
    i-frames it is just dodged; otherwise it costs health and shakes the camera. Health 100.
  - `ui/hud.gd` (`Hud`): bottom-left, 1080p-scaled thin vitality bar (deep red) over a thinner
    stamina bar (pale gold) with a brass rim, a faint top highlight and a pale "lost" segment
    that holds and drains after damage/spend. Fades out 2.5 s after both are full.
  - Bots: new `dodge` route — dash ≥ 2.8 m right (got 3.2 m), stamina 100→84, i-frames, lean
    0.41 rad, model restored; swing cancelled by a dodge; perfect dodge at 0.067 s → slow-mo
    (time scale 4→1→4 in the bot's 4x), stamina 34→59, FX spawned, no damage; late (0.22 s) →
    dodged, no slow-mo; unguarded → 20 damage, HUD shown. `tools/bots.sh` now runs all four
    routes by default (walk, ridge, combat, dodge): all PASS.
  - Shot spot `dodge [u=0.35]`: dash to +X frozen at u, side-on from the sun side, HUD up.
  - Verdicts: `dodge1` 10h u=0.35 — low committed lean past the post reads as a dash; vitality
    bar visible, stamina bar was lost against the bright grass (fixed: thicker, darker backing,
    min pixel heights). `dg2` 10h u=0.6 — both bars readable; pose reads as a running lean, not
    a Wukong dodge. Both fail on the placeholder model. A 16.5 h shot timed out on lavapipe.
- Session 2026-10-10 17:00 UTC:
  - **The light string now connects (Next 8, second part): hit detection, hit-stop, camera
    shake, impact VFX, stamina cost.** New `world/training_post.gd` (`TrainingPost`): a
    weathered oak practice post planted 1.45 m ahead of the start, its middle bound in a straw
    bundle with three hemp rope rings and a rusted iron band under the chamfered top; lathe mesh
    with per-vertex irregularity + `shaders/training_post.gdshader` (oak grain/checking cracks/
    damp moss foot, straw stalks with nodes, twisted rope plies, rust flakes). It rocks in its
    socket on each hit (damped spring) and freezes during the hit-stop.
  - Contact (`combat.gd`): anything in group `hittable` exposing `hurt_capsule()` /
    `take_hit(point, dir, power, hitstop)` is tested against the whole shaft. The authored arc is
    re-evaluated at ~4 ms sub-steps between ticks (a straight lerp between two tick poses cut
    inside the arc and missed at low frame rates — the 4x-time-scale bot found it). One hit per
    target per swing. Hit-stop 0.065 s × power (slam 1.6 → 0.10 s): combat time, lunge and the
    AnimationTree all freeze. Camera shake: trauma² on two sines per axis via Camera3D h/v
    offset. `fx/impact.gd` (`ImpactFX`): chaff thrown along the swing + soft dust puffs
    (CPUParticles3D, kinds straw/wood/stone/metal; metal adds a flash light). The lunge stops
    0.95 m from a target so the hero no longer walks into the post. These hooks are what the
    Hollow Soldier will implement.
  - Stamina: 9/9/14/12 per hit of the string, no regen mid-swing; at 0 the string breaks off.
  - Bots: `combat` now asserts all 4 hits connect with the post, hit-stop ≥ 0.05 s, the post
    tilts, impact FX spawn and stamina drops (got 4/4 hits on steps 0–3, hit-stop 0.104 s, stamina
    100→56). `walk`, `ridge` PASS.
  - Shot spot `impact<step> [after=N]`: runs the string until hit <step> lands, N more ticks,
    then freezes; side-on from the sun side.
  - Verdicts: `imp2` 10h slam — dust burst + chaff + trail at the post's top read as a real
    hit. Fail: soldier model, dust a bit bright. `imp0` sweep — contact visible but chaff too
    small at 3 m, staff hidden behind the body; fail. `hero` 10h — the post close-up: straw and
    rope read well, shaded oak top near-black and smooth; fail (model, and the post now crowds
    the hero portrait spot).
- Session 2026-10-10 16:00 UTC:
  - **Ward-stance light string: the staff comes off the back and swings (Next 8, first part).**
    Left mouse / RB (`attack_light`): the staff is drawn into both hands (0.22 s blend), then a
    chained 4-hit string — right-to-left sweep, backhand, overhead slam, spinning sweep (the
    body turns a full 360°). Press during the back 65 % of a hit to queue the next; idle 5 s
    and it is slung back. New `player/combat.gd` (`StaffCombat`): swings are authored as body-
    space keys (staff yaw/pitch, grip centre, spine twist) with smoothstep easing; both hands
    are solved onto the shaft by a `TwoBoneIK3D` (arm/forearm/hand, elbow poles down-out); the
    grips are clamped into each shoulder's 0.43 m reach (shoulders turn with the twist) and the
    staff is laid through the two grips, so hands never leave the shaft. New
    `player/spine_twist.gd` (`SpineTwist`, a GDScript `SkeletonModifier3D`) winds the chest
    into each swing over Spine/Spine1/Spine2. Lunge during the strike window, steering is a
    snap at the start of each hit, no sprint while the staff is out. Swing trail:
    `shaders/swing_trail.gdshader` ribbon from the tip down the shaft, 0.14 s life, strike
    window only. (DESIGN.md lists thrust/sweep/overhead/spin; the thrust is reserved for the
    heavy follow-up.)
  - Bots: new `combat` route (`tools/bots.sh combat`): chains all 4 hits, asserts tip path
    > 8 m and strike speed > 8 m/s (got 32 m, 29 m/s), IK grip error < 12 cm (0.000 — read in
    the IK's `modification_processed`, the modified pose is gone after rendering), spin ≈ 2π,
    and the staff is back on the back after idling. `walk` and `ridge` PASS.
  - Shot spots `swing<step> [u=0..1]`: freezes the string at that hit/phase (simulates with
    the render loop off, one physics tick per step, then pauses the tree), camera on the
    sun's side with the hero turned 3/4 to it.
  - Verdicts: `sw2b` 10h overhead wind-up — hands raised over the head on the shaft, chest
    wound back; the pose reads as a staff strike. Fail: sci-fi soldier, legs stay in idle,
    red bare ground under grass. `sw0b` 10h mid-sweep — trail visible as a faint pale wedge;
    fail: two-handed grip reads like a rifle hold from this angle, trail too faint. (First
    attempt `sw2` had the hands stuck at the chest with the staff vertical: the wind-up key
    was out of arm reach — raised to 2.0 m.)
- Session 2026-10-10 15:00 UTC:
  - **The hero carries a staff (was Next 7, staff part).** `player/staff.gd` builds a 1.86 m
    lathe mesh in code: worn-bronze end caps with machined ridges, a red-brown lacquered
    shaft, a cloth-wrapped grip at the balance point. `shaders/staff.gdshader` adds all detail
    procedurally (wood grain, lacquer worn through to wood, tarnish in pits/polished highs,
    diagonal wrap bands with weave and dirt) plus derivative bump. Out of combat it is slung
    diagonally across the back (right shoulder to left hip) on a BoneAttachment3D on
    `mixamorig_Spine2`; the attachment offset is solved at the rest pose so it is body-scaled
    whatever the skeleton's import scale. It sways with the torso in every clip.
  - Bots: both routes assert the staff sits behind the torso at 0.9–1.6 m and measures 1.86 m
    in world space (PASS; centre moves with the run lean).
  - Shot spots `heroback` (rear 3/4, 3 m) and `staff` (rear close-up, 1.6 m).
  - Verdicts: `staff2` 10h — the staff itself would pass: bronze caps catch the light, red
    lacquer and hemp wrap read at 1.6 m. Fail overall: sci-fi soldier model, no strap holds it.
    `heroback` 15.5h backlit — staff silhouette at the right scale across the back. Fail: model.
    `hero` 10h — staff visible over the shoulder from the front. Fail: model, harsh rim light.
  - First-pass staff colours were too dark under backlight (caps read black); brightened.
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
1. (done 11:00: sky_energy_scale 2.6; 04:00: dusk afterglow via a sky-only twilight sun;
   05:00: star fade-in, desaturated low sun/twilight.) Still to do: the brown 19 h sky (see
   bugs), dawn check, and verify SDFGI on a real GPU some day (cloud box can't).
2. Flora polish: bigger hero boulders/outcrops (3–6 m) and ruins on hilltops, hedgerows,
   shrubs/ferns under trees, leaf atlas with normals and more leaf shape per card at close
   range, tree LOD/impostors beyond 150 m.
3. (done 12:00: far mountain ring.) Polish: per-pixel normals / more ridge detail so far
   ridges are not faceted, vary peak shapes (domain warp), forest impostor speckle on
   foothills, playable-edge border (cliffs) with collision.
4. Terrain textures: CC0 grass/dirt/rock/moss (blocked here — see above). (done 14:00 (10-11):
   procedural turf/clover/moss/litter/rock floor with per-pixel bump.) Still to do: moss at
   tree bases and round boulders (pass tree/rock positions in a mask texture), a path/road
   layer, grass blade albedo detail + softer clump shadows.
5. (done 13:00: rook flocks + kites; 01:00: fireflies + midge swarms; 12:20 (10-11):
   butterflies; 13:00 (10-11): wildflower drifts, butterflies perch on flower heads.) Still to
   do: flower LOD (a cross-card impostor past ~20 m), red clover/poppies, bees on the
   flowers, two butterflies spiralling up together, a grazing sheep/deer herd that flees
   (needs a believable quadruped — procedural or CC0 from a GitHub mirror), bird calls once
   there is audio, birds roosting in trees at night, moths around lanterns/campfires once
   they exist, butterflies by day.
6. Harrowmere village blockout → final: slate roofs, timber, lantern posts (Kindle targets).
7. (done 14:00: rigged Mixamo humanoid + idle/walk/run blend.) Still to do: replace the sci-fi
   "Vanguard" with a mythic hero (robes, hair, face) — look for CC0/CC-BY realistic humanoids in
   GitHub repos (github/raw.githubusercontent work; the clip names Idle/Walk/Run + mixamorig bones
   let a Mixamo-rigged model drop in and retarget); jump/fall clips, foot IK on slopes, turn-in-
   place, cloth/hair sway; the staff.
   (done 15:00: staff slung on the back.) Still to do: draw it into the right hand when combat
   starts (needs a staff-grip/attack clip set), swing trails, impact VFX.
8. (done 16:00: draw + L×4 string + trail; 17:00: contact, hit-stop, shake, impact VFX,
   stamina cost, practice post; 18:00: dodge, perfect dodge slow-mo, HUD bars.) Still to do:
   (done 19:00: Hollow Soldier spear variant, telegraphed thrust, poise/stagger, ash death,
   soft lock; 20:00: lock-on + reticle; 21:00: chargeable heavy + parry; 22:00: all staff
   poses reachable + clear of the body, grip slide.) Next: a
   (done 00:00: sweep; 09:00 (10-11): hood, mantle, sash, swinging tabards on the soldier.)
   (done 10:00: fitted bandage wraps on shins + forearms; 11:00: thighs + boots.) Still to do:
   slim the leg wraps (shrink the Vanguard leg mesh under them, or hide it), a shaped boot
   wrap; ideally a real CC0 humanoid for the
   soldier; hit sounds once audio exists; a soldier patrol/camp near the start road.
9. Weather follow-ups: (done 16:00 (10-11): procedural cloud deck; 18:00: puddles in the
   hollows + raindrop ripples, SSR on; 19:00: cloud shadows on the land.)
   (done 20:00: oak leaf blowout fixed; 21:00: drop splashes + hero splashing through pools.)
   (done 22:00: wake rings on the pools + bigger foot splash; 23:00: lightning bolts +
   flashes.)
   Next session pick: rain on the hero (wet cloth darkening), then thunder once audio
   exists (delay by distance / 343 m/s), cloud-to-cloud sheet flashes with no channel. Still to do: rolling
   structure in the overcast deck (dark rain bellies, low scud below the deck, rain shafts
   under far cells), cloud shadows on the hero/soldier (their imported materials do not take them yet), clouds in the sky radiance/reflections
   (they are a mesh, so SSR/water won't see them), rain splashes + ripples on the
   ground, puddles in hollows, rain occlusion under tree crowns, lightning + thunder for
   strong fronts, fog banks in the morning, rain on the hero (wet cloth darkening), NPCs and
   rooks shelter. Then climbing + glide.
10. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
11. Every step: shots + bots, then update this file.

## Known bugs
- Lightning: no thunder (no audio in the game yet); the flash light casts no shadows (a
  second shadowed directional would split the sun's shadow atlas; try on a real GPU); the
  segment of a bolt seen against the mountains (not the sky) still gets a dark outline
  around its white core under TAA + volumetric fog; the
  bolt is a fixed ribbon (no per-stroke channel flicker/re-branching, no ground glow at
  the foot); bolts above the deck base can be hidden behind the cloud dome where it is
  hazed; strikes are visual only (do not hit trees or the hero).
- (fixed 20:00: white blowout.) Oak leaf cards are oversized at close range (each sprig
  card reads as a few big leaves) and the crowns are dark and flat inside with no fine
  silhouette detail; needs smaller sprigs / more cards near the camera (flora item 2).
- Clouds: the overcast deck is too uniform (no rolling bellies); far ridges stay a darker
  grey silhouette against it in rain; clouds overhead at dusk are a touch too pink; cloud
  shadows darken albedo (so ambient too) rather than the sun term only, skip the hero,
  soldier and staff (imported/standard materials), and are vertex-rate on grass and trees
  (soft edges; fine at km scale). Clouds are not in the sky radiance (reflections show the bare sky). The
  PhysicalSky behind a partial deck (cloud ~0.7, late afternoon) may still go navy in the
  gaps. Rain falls through tree
  crowns and roofs (no occlusion; drop splashes also land under crowns); the hero does not
  get wet. Drop splashes are CPU-placed on the terrain height only (they ignore rocks, the
  hero, the soldier), all the same white-grey (no muddy tint on soil), and are faint at a
  distance; footfalls are timed by distance, not by the run clip's feet.
  Puddles: the water is a shaded terrain layer, not a level plane (it follows the hollow's
  curve, so a pool's far side can tilt a few cm); the near half of a pool is very dark at
  steep view angles (physically right, but reads as a hole in dim light); pools stay after
  the ground dries only as long as `weather_wet` > 0.35 (no separate slow evaporation);
  wake rings are 8 slots (at a full run the oldest is recycled after ~1.5 s, when it is
  nearly gone) and only the hero makes them (not the soldier or wildlife); the shoreline is hard at close range. Dry
  hollows still carry thinner grass (sparse sedge) whether or not they hold water; the
  ripple rings are evenly dense across a pool (no gusty patches of heavier drops).
  SSR cost on a real GPU is unmeasured.
  `RenderingServer.global_shader_parameter_get` returns null headless (bot falls back to
  Weather's values). Wind does not yet move the rain particles' spawn upwind beyond a fixed
  6 m offset.
- 15 % of butterflies (and all of them where no drift is loaded) still perch at a random
  height over the grass; perched ones follow the flower's wind sway but not the flutter
  exactly (few mm). Flowers have no LOD (full mesh to 56 m) and no shadow; they are not
  flattened by the hero walking through. Their patterns read pale under the warm grade; no
  shadow (casting off); they do not avoid trees or the hero's body in flight. Rain does not
  ground them (no weather yet).
- (fixed 14:00: ground layer.) Close-up grass blades are still flat untextured ribbons (no
  albedo/vein/translucency detail) and the clumps read regular; ground in clump shadow is
  near-black in low-angle macro shots (`flowers` spot), partly the harsh grass shadows.
  Moss/clover are noise-placed, not tied to trees/rocks (no moss at tree bases yet).
- At 19.0 h (sun -7 deg) the sky behind the first stars is a dark brown/amber, not blue, and
  the stars still look slightly gold. Cause not found yet: candidates are the PhysicalSky
  extinction on `night_sky`, or the amber sky-sun scattering under the volumetric haze. Try
  a 19.0 shot with `night_sky = null` to split the two. At the same hour the moon (held at
  >= 8 deg, 0.5 energy) lights the far ridges a bright blue against that dark sky. Ramp the
  moon in later or lower its floor.
- Dawn checked once (`village` 5.6 h, looks right); `village` spot has a dark rock right at
  the camera on the left edge.
- Midge glints are only a few px at 3 m: right for a still, may need a touch more size in
  motion; fireflies have no wing/body mesh (glow dots only, fine at night distance).
- Soldier sweep: the arms reach 0.6 m (thrust poses 0.45) and the spear axis is up to ~11 deg
  off the authored arc mid-swing; no swing trail on the spear; contact uses the hero's centre
  only (no low/high: can't be jumped, there is no jump yet). A backstep dodge started early
  still escapes it — the honest counter, but a follow-up thrust for a hero who backs off would
  make reading it matter more.
- Heavy FX: the ground-slam burst (ImpactFX "stone" at the tip) renders as a soft grey
  sphere, and the tier glints ("metal" at the tip) leave a brown cloud high up. Needs a
  proper debris/dust-ring effect and a small sharp glint sprite.
- `soldier ... stagger smash` shot: the soldier is missing from the frame (not investigated).
  Same for `soldierface ... u=0.5 strike` (10:00).
- Soldier boot wrap (11:00) is a shapeless lump at the ankle; thigh wraps are ~1.5x a real
  thigh because they hug the plated Vanguard thigh. Fix by shrinking the skinned leg verts
  under the wraps (a vertex pass at build) and fitting the wrap to the slimmer leg.
- Soldier wraps follow the bone rigidly; the shin wrap reads barrel-shaped because it hugs the
  greave's calf flare. Forearm wraps not yet checked in a close shot.
- Spin finisher's recovery (last key -> guard) grazes the chest surface for ~0.05 s
  (`pose_check -v` mid14 clearance 1.05 torso radii, the pass mark). An extra key would fix it.
- Arm IK still clamps to a 0.43 m shoulder reach with no elbow/clavicle motion, so every pose
  is built around reachable grips; a real staff-form mocap clip set would read better.
- The hero's flinch is a procedural whole-body rock from the hip (no arm/head reaction, no
  Mixamo hit-reaction clip); a heavy blow has no knockdown yet. During flinch/dodge leans the
  grip targets stay put (only death moves `_wield` with the body).
- No gold "parryable" flash on the soldier's tell yet (DESIGN.md colour code); the blade glint
  doubles for it.
- Lock-on has no strafe clips: moving while locked the hero turns to run in the stick
  direction (only standing still squares up). Needs Mixamo strafe/walk-back clips.
- Lock-on target switching is mouse-flick only; no right-stick binding yet (no camera stick
  action exists for pads at all).
- `pkill -f <pattern>` in a session shell kills the shell itself when the pattern appears in
  the command line; kill stray godot processes by pid instead.
- Hollow Soldier reuses the Vanguard mesh under the ash shader: the rags (hood, mantle, sash,
  tabards) now hide head, shoulders and hips, but the shins, forearms and the upper arms
  between mantle and elbow still show the sci-fi armour. Rags are rigid per bone (no cloth
  sim): tabards are flat boards that swing as one piece, the mantle can be pierced by a
  raised upper arm, the hood does not deform with the neck. The `lit` shot framing is
  backlit at low evening sun. Its spear grip hands are IK-placed
  but wrists don't wrap the shaft (same as the hero).
- Soldier has no avoidance/pathing (walks straight at the hero; can snag on trees) and no
  "lost the hero" search; it returns home past 22 m.
- Death is procedural (Crumple bone bends + model tilt about the knees), not a ragdoll or a
  death clip: no foot/body contact on slopes (the body tips in the body frame), the prone head
  sits ~0.3 m up, grass does not flatten under the body, no get-up animation on waking.
  No rest points exist yet besides the start; no lamplighter shrine to light.
- Shots: awaiting physics_frame with `render_loop_enabled = false` stalled in the soldier spot
  under Vulkan (headless it runs) — soldier spot steps by hand; root cause unknown.
- Dodge is procedural (lean + sink + fast run stride), not a real roll/dash clip; the feet
  slide a little at the dash's peak speed (13 m/s vs a 6 m/s stride). Wants a Mixamo dodge clip.
- Dash covers 3.2 m instead of the designed 3.6 m (first tick lost to discrete integration).
- Perfect-dodge slow-mo is global `Engine.time_scale` (the hero slows too); fine as a reward
  beat, but a per-actor "witch time" would let the hero act at full speed.
- `await physics_frame` in bots resumes once per frame while 4 physics steps run at 4x: write
  bot waits as state conditions, never tick counts.
- Practice post sits 1.45 m in front of the spawn and now crowds the `hero` shot spot; move it
  (and the player spawn) into a proper training yard when the village goes in.
- Hits always use the "straw" impact kind on the post, even when the slam lands on the oak/iron
  top (no per-height material lookup).
- Light string: hands are IK-placed but the wrists are not rotated around the shaft (palms
  don't wrap it); the legs keep playing idle/walk during swings (no lower-body attack stance);
  swings hit nothing yet. Swing poses are hand-keyed in code — a real Mixamo staff clip set
  would read better.
- The staff floats against the back (no strap/frog) and can clip the arms in extreme poses;
  it has no collision (cosmetic only).
- Player model is a sci-fi armoured soldier (Mixamo Vanguard) — placeholder-floor; no jump clip
  (airborne holds the walk stride), no foot IK, so feet float/clip on slopes.
- Rooks fly through tree crowns (no avoidance; the wheel anchor is 14 m up, crowns ~10 m).
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
