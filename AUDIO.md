# Audio

Owner priority 0b (2026-10-30): stop synthesising audio, replace every sound with real
recorded CC0/CC-BY samples, add a real soundtrack and a music system, verify levels, then
audit every third-party file's license.

## Status of 0b

| Item | State |
|---|---|
| (a) Audit every sound | **done** 2026-10-30 18:00 (this file); the two un-bussed players were routed (wheatears -> Wildlife, fell bell -> SFX) |
| (b) Replace with recorded CC0/CC-BY samples | **priority 1 done** 2026-10-30 19:00 (combat, footsteps, fire except `blow`, gate creak, wood chop); **weather + songbirds done** 2026-10-30 20:00 (wind, leaves, light + heavy rain, crickets, 3 near + 3 far thunder, 6 songbird calls; `game/audio/sfx/weather`, `/birds`, 2.9 MB). Remaining: `blow`, the animal calls (deer, fox, collie, hens, bat), rooks' caws, kite, wheatears, dust devil, voices, grain, fell bell — see "Replaced" below |
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

## Replaced with recordings (2026-10-30 19:00)

Loaded by `game/world/samples.gd` (`Samples.load_set(group, name)` probes `res://audio/sfx/<group>/<name>_N.ogg`);
`Foley.RECORDED` lists the names, and the synthesised stand-in stays only where no set exists. Every play keeps
the old +-5 % pitch and -1.5..+1 dB volume jitter, picks a random variant. Each blow now also plays a
quiet recorded low thump (`boom`) under the impact, a full boom from power 1.5 up. Files are mono 44.1 kHz
Ogg Vorbis, peak <= -2 dBFS after encoding (checked with ffmpeg astats). Sources and licenses: ASSETS.md.

| Name | Variants | Recording |
|---|---|---|
| swish | 5 | Freesound CC0 stick/broom whooshes |
| whoom | 3 | broomstick whoosh pitched down + two long woosh/swoosh |
| spear | 3 | swipe/whoosh (CC0) |
| straw | 3 | Kenney impactSoft_heavy x2 + leather drop |
| stone | 3 | pick on stone (Benboncan, CC BY 3.0) |
| wood | 4 | chopping wood (Sheyvan CC0) + Kenney Chop |
| body | 3 | Kenney impactPunch_heavy x2 + DeVern impact |
| boom | 3 | low-frequency explosion head, dramatic hit, cinematic impact (low thump layer) |
| clang | 3 | Kenney metal pot x2 + qubodup metal hit |
| slam | 3 | cinematic hits, one with a gravel debris layer |
| dodge | 3 | Kenney cloth |
| perfect | 1 | reversed woosh (swell) |
| step_grass / grit / wet / stone / stone_wet | 5 / 4 / 3 / 3 / 3 | Kenney footsteps; sand + gravel; water footsteps (AGFX); hard footsteps (Erdie); hard + splash |
| creak / chop / thud | 3 / 2 / 1 | Kenney creaks; Kenney chop + chopping wood; chopping wood pitched down |
| hearth crackle (loop) | 1 | Dynamicell campfire, 4 takes crossfaded into a seamless 18 s loop |
| hearth flint | 1 | flint and steel (Benboncan, CC BY 3.0) |

Weather and songbirds (2026-10-30 20:00), loaded by `soundscape.gd` (`_rec_or`, `Samples`); each layer keeps its
synthesised stand-in only if its file is missing, and `Soundscape.recorded` says which layers are recordings:

| Layer | Files | Recording |
|---|---|---|
| wind bed | weather/wind_loop (90 s) | felix.blume open wind (CC0); pitch now bends only +-2 % with strength |
| leaves bed | weather/leaves_loop (13 s) | felix.blume wind, high-passed (CC0) |
| rain bed | weather/rain_loop (58 s) | Corsica_S forest rain (CC BY) |
| heavy rain bed (new) | weather/rain_heavy_loop (44 s) | D W heavy rain (CC BY); fades in above rain 0.45, full at 1.0 |
| crickets bed | weather/crickets_loop (45 s) | Lisa Redfern crickets at night (PD) |
| thunder | weather/thunder_near_1..3, thunder_far_1..3 | RHumphries thunderstorm (CC BY): three cracks, three low-passed distant rolls |
| songbird calls (positional, from the oaks) | birds/song_1..6 (4 s each) | single calls cut from kvgarlic and sonidosreales245 woodland recordings (CC0) |

Bots: `foley` fails unless the priority-1 names are recorded `AudioStreamOggVorbis` sets of 3+; `hearth` fails
unless the crackle is a looping recorded stream and the flint is recorded; `sound` fails unless the five beds are
looping recordings, thunder is 3+3 recordings and the songbird calls are 5+ recordings.

## Every sound in the game

As audited 2026-10-30 18:00, all 63 sound names below were **synthesised** (see "Replaced" above for what is now recorded).
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
- **Used (19:00 10-30):** github.com/mminer/ggj2022 (part of Kenney RPG Audio, CC0), github.com/luanti-org/minetest_game
  (per-file credits; only CC0 and CC BY 3.0 files taken, none of its CC BY-SA ones), Barty-Bart/motion-graphics (CC0).
  WebFetch also cannot reach freesound.org / kenney.nl, so licenses are as stated by those repos; (e) must re-check.
- Still to find: animal and bird recordings (red deer, fox, collie, hens, rooks, red kite, wheatear, dawn chorus),
  wind / rain / night-insect / thunder beds. Leads: Luanti games with mobs and weather on GitHub (check each file's
  credit: CC0 or CC BY only, never CC BY-SA), Godot demo projects.
- Earlier note: look for GitHub mirrors of Kenney "Impact Sounds" and "RPG Audio" (CC0: footsteps,
  cloth, wood/metal impacts) and of CC0 Freesound field recordings (wind, rain, birds).
