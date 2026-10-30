# Audio

Owner priority 0b (2026-10-30): stop synthesising audio, replace every sound with real
recorded CC0/CC-BY samples, add a real soundtrack and a music system, verify levels, then
audit every third-party file's license.

## Status of 0b

| Item | State |
|---|---|
| (a) Audit every sound | **done** 2026-10-30 18:00 (this file); the two un-bussed players were routed (wheatears -> Wildlife, fell bell -> SFX) |
| (b) Replace with recorded CC0/CC-BY samples | not started — see "Sourcing" below |
| (c) Music: tracks + music system | not started (Music bus + pause-menu slider already exist) |
| (d) Headless verification + peak levels | not started |
| (e) Copyright audit + in-game Credits screen | not started |

## The mix as it stands

Built at load by `game/world/audio_mix.gd`: buses Master > Ambience > Wildlife, Master > SFX,
Master > Music. Volumes per bus saved in `user://settings.cfg`; the pause menu
(`game/ui/pause_menu.gd`) has Master / Ambience / Wildlife / Effects / Music sliders. Inside
the ruined keep the SFX bus gets a short stone reverb and Ambience a low-pass.

Mix problems found in the audit:
- **No Voice bus** (needed for dialogue / NPC murmurs and for ducking music under dialogue).
- (fixed 2026-10-30) **Wheatear voices (`wheatears.gd`) and the fell bell knock (`fell_bell.gd`) set no bus**, so
  they play straight into Master and ignore the Wildlife / Effects sliders. Now routed to Wildlife and SFX.
- **No Music at all** — the Music bus is empty.
- Every stream is a 22.05 kHz (wind/thunder 11.025 kHz) mono AudioStreamWAV built from noise
  and oscillators at load; nothing has a real recorded transient or room.

## Every sound in the game

All 63 sound names below are **synthesised** (noise + oscillators, built in GDScript at load).
There are **no sample files in the repo**. Verdict for every one: **replace** (owner: synthesised
sound does not sound real). Priority 1 = worst offenders, replace first.

### Combat and body — `game/world/foley.gd` (bus SFX) — priority 1

| Name | What / when it plays | Variants | Verdict |
|---|---|---|---|
| swish | light staff strike, timed so its peak meets the blow (`_on_swing`) | 3 | replace: real staff/stick whoosh, 4-5 variations |
| whoom | heavy staff swing | 1 | replace: deep pole whoosh, 3 variations |
| spear | soldier's spear thrust (`struck`) | 1 | replace: spear/blade whoosh |
| straw | staff hits the straw training post | 2 | replace: stick into straw/sack hit |
| stone | staff hits the Hollows' ashen stone soldiers | 2 | replace: wood on stone impact + low thump layer |
| wood | staff hits wood; also pop-hole slide, gate knock, door latch | 1 | replace: wooden knock/impact, 3+ variations |
| body | hero is struck; hero's back hitting the ground (pitched 0.62) | 1 | replace: body blow / bodyfall |
| boom | low thump under blows with power >= 1.5 | 1 | replace: sub "thump" layer (Wukong-weight) |
| clang | parry; charge-tier pings (pitched up) | 2 | replace: metal-on-metal parry ring |
| slam | heavy meets the ground | 1 | replace: ground slam / earth impact + debris |
| dodge | dash / dodge cloth whoosh | 2 | replace: cloth whoosh |
| perfect | perfect-dodge swelling breath | 1 | replace: reverse whoosh / time-slow swell |

### Footsteps — `foley.gd` (bus SFX) — priority 1

| Name | Where | Variants | Verdict |
|---|---|---|---|
| step_grass | meadow turf (hero, Edda, Osric, soldiers) | 4 | replace: grass/earth footsteps, 5 variations |
| step_grit | keep floor | 3 | replace: gravel footsteps |
| step_wet | pools / soaked ground | 3 | replace: mud/water footsteps |
| step_stone | door slabs | 3 | replace: stone footsteps |
| step_stone_wet | door slabs in rain | 3 | replace: wet stone footsteps |

### Fire — `game/world/hearth.gd` (bus SFX) — priority 1

| Name | What | Verdict |
|---|---|---|
| crackle (loop) | Hesper's cookfire crackle and pops, gain follows the fire level | replace: campfire loop |
| flint | steel click/scrape on each strike while lighting | replace: flint and steel |
| blow | her breath into the tinder and the whump as it takes | replace: blowing on embers + small ignition whoomp |

### Animal and bird calls — priority 2

| Name | File / bus | What | Variants | Verdict |
|---|---|---|---|---|
| bark | foley / Wildlife | red deer hind alarm bark as the herd bolts | 3 | replace: red deer bark |
| roar | foley / Wildlife | stag rut roar at dusk / before dawn | 2 | replace: red deer stag roar |
| gallop, gallop_wet | foley / Wildlife | herd hooves on turf / wet ground | 3 + 2 | replace: deer/horse gallop on grass |
| fox_bark, fox_yelp | foley / Wildlife | fox night barks, yelp as it bolts | 3 + 2 | replace: red fox bark/scream |
| crunch | foley / Wildlife | fox eating | 3 | replace |
| dog_bark, dog_woof | foley / Wildlife | Brack the collie | 3 + 2 | replace: collie bark |
| cluck, squawk | foley / Wildlife | hens in the garth | 4 + 3 | replace: chicken recordings |
| bat_call, bat_buzz, bat_grumble | foley / Wildlife | bat at the lantern | 3 + 2 + 2 | replace (or drop: bats are near-ultrasonic, a faint real recording or nothing) |
| songs (6 kinds) | soundscape / Wildlife | dawn/dusk birdsong from the oak groves | 6 | replace: real woodland dawn-chorus recordings (blackbird, robin, wren, chaffinch) |
| caws | soundscape / Wildlife | rooks scattering, wing clatter | 1 | replace: rook/crow caws + wing flaps |
| kite (2 + harsh) | soundscape / Wildlife | red kite whistle high over the meadow | 3 | replace: red kite call |
| chack (calls) | wheatears / **no bus** | wheatear alarm "chack" | several | replace: northern wheatear call; route to Wildlife |
| song | wheatears / **no bus** | cock's song-flight warble | 1 | replace: wheatear song; route to Wildlife |

### Weather and ambience beds — `game/world/soundscape.gd` (bus Ambience) — priority 2

| Name | What | Verdict |
|---|---|---|
| wind (loop) | wind bed, swells with the weather | replace: real wind-on-open-moor loop (+ a gusty storm layer) |
| leaves (loop) | leaf rustle near the oaks | replace: wind in leaves loop |
| rain (loop) | rain hiss + drop patter | replace: rain loop (light + heavy) |
| crickets (loop) | crickets in the night grass | replace: night field insects loop |
| thunder_near / thunder_far | after each lightning stroke | replace: real thunder crack / distant rumble, 2-3 each |
| whoosh (loop) | `dust_devils.gd`: the dust devil's dry hiss and grit | replace: wind gust whoosh loop |

### Village, people, objects — `foley.gd` (bus SFX) — priority 3

| Name | What | Variants | Verdict |
|---|---|---|---|
| chop / thud | Edda splitting a round / axe sticking | 2 + 1 | replace: axe splitting wood |
| grunt | Edda heaving a round | 3 | replace (Voice bus), or drop until real voice work |
| hum | Edda humming on the bench | 3 | replace with a recorded hum or drop; synthetic humming is the worst-sounding of the voices |
| murmur, murmur_low | NPC speech murmur | 3 + 3 | replace with recorded walla or drop (Voice bus) |
| call | Edda calling the hens | 3 | replace or drop (Voice bus) |
| grain | feed scattering on the yard | 3 | replace: grain/seed scatter |
| creak | gate and door hinges | 3 | replace: wooden gate/door creak |
| knock (x3 pitches) | `fell_bell.gd`: the bronze bell's clonk, **no bus** | 3 | replace: real sheep/cow bell; route to SFX |

## Sourcing (cloud box, 2026-10-30)

Egress is restricted: kenney.nl, opengameart.org, freesound.org (+ cdn), incompetech.com,
freemusicarchive.org and archive.org are refused by the proxy; api.github.com answers 403.
**`git clone` from github.com works**, so samples must come from GitHub repositories that
carry CC0 / CC-BY audio with a clear license file, verified against the original source page
with WebFetch/WebSearch (rule 0b-e) before anything is committed. Leads found so far:
- KenneyNL/Starter-Kit-FPS, -3D-Platformer, -City-Builder (code MIT, Kenney assets CC0):
  only arcade jump/coin/blaster sounds — not usable for this tone.
- Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (states CC0 1.0, from Kenney +
  Freesound, with a LICENSES.md / manifest): mostly UI/motion-graphics sounds, but has
  Kenney Impact Sounds `impactPunch_heavy`, `impactSoft_heavy` and some cinematic impacts —
  candidates for the body/boom layers once each Freesound ID is checked.
- Next: look for GitHub mirrors of Kenney "Impact Sounds" and "RPG Audio" (CC0: footsteps,
  cloth, wood/metal impacts) and of CC0 Freesound field recordings (wind, rain, birds).
