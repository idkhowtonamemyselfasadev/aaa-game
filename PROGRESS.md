# Progress

Content hours playable: 0.18
(walkable test valley with grass, oak groves, boulders, rook flocks, fireflies at night and midges in the evening light, played as a rigged animated humanoid
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
5. (done 13:00: rook flocks + kites; 01:00: fireflies + midge swarms.) Still to do: a grazing sheep/deer herd that flees
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
   (done 00:00: sweep.) a rag/cloth tabard and
   hood to hide the sci-fi armour on the soldier, hit sounds once audio exists; a soldier
   patrol/camp near the start road.
9. Climbing + glide. Then the first shrine (Bind) and the Ashen Knight 3-phase boss.
10. Every step: shots + bots, then update this file.

## Known bugs
- Night: the far mountain ring glows blue (fog light) brighter than the black starry sky, so the
  ridge line reads as a cut-out; the sky needs a faint night glow/moonlit haze near the horizon.
- A warm orange light pool sits on the grass around the hero/practice post at night (seen in
  the `player`/`fireflies` 21:00 shots); not from the insects, source not tracked down yet.
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
- Spin finisher's recovery (last key -> guard) grazes the chest surface for ~0.05 s
  (`pose_check -v` mid14 clearance 1.05 torso radii, the pass mark). An extra key would fix it.
- Arm IK still clamps to a 0.43 m shoulder reach with no elbow/clavicle motion, so every pose
  is built around reachable grips; a real staff-form mocap clip set would read better.
- The hero has no hit reaction: a thrust that lands during a heavy charge does not interrupt
  it (no flinch/hyper-armour rule yet).
- No gold "parryable" flash on the soldier's tell yet (DESIGN.md colour code); the blade glint
  doubles for it.
- Lock-on has no strafe clips: moving while locked the hero turns to run in the stick
  direction (only standing still squares up). Needs Mixamo strafe/walk-back clips.
- Lock-on target switching is mouse-flick only; no right-stick binding yet (no camera stick
  action exists for pads at all).
- `pkill -f <pattern>` in a session shell kills the shell itself when the pattern appears in
  the command line; kill stray godot processes by pid instead.
- Hollow Soldier reuses the Vanguard mesh under the ash shader: the sci-fi armour silhouette
  still shows. Needs its own model or cloth/rag overlays. Its spear grip hands are IK-placed
  but wrists don't wrap the shaft (same as the hero).
- Soldier has no avoidance/pathing (walks straight at the hero; can snag on trees) and no
  "lost the hero" search; it returns home past 22 m.
- The hero has no death yet: health can reach 0 and nothing happens.
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
