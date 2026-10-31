# Audio

Owner priority 0b (2026-10-30): stop synthesising audio, replace every sound with real
recorded CC0/CC-BY samples, add a real soundtrack and a music system, verify levels, then
audit every third-party file's license.

## Status of 0b

| Item | State |
|---|---|
| (a) Audit every sound | **done** 2026-10-30 18:00 (this file); the two un-bussed players were routed (wheatears -> Wildlife, fell bell -> SFX) |
| (b) Replace with recorded CC0/CC-BY samples | **priority 1 done** 2026-10-30 19:00 (combat, footsteps, fire except `blow`, gate creak, wood chop); **weather + songbirds done** 2026-10-30 20:00 (wind, leaves, light + heavy rain, crickets, 3 near + 3 far thunder, 6 songbird calls; `game/audio/sfx/weather`, `/birds`, 2.9 MB). **collie, hens, fox crunch done; bat voice dropped** 2026-10-30 21:00 (`game/audio/sfx/animals`). **all done 2026-10-31 02:00**: every remaining name is a recording (grain, grunt, blow, dust devil 01:00; rook wings, fell bell 02:00) or dropped to silence (voices; deer, fox, rook caws, kite, wheatear) — see "Replaced" below |
| (c) Music: tracks + music system | **first pass done** 2026-10-30 22:00: `game/world/music.gd` + 4 CC BY 3.0 files in `game/audio/music/` (see "Music" below). **hearth theme done** 2026-10-30 23:00 (Lazy Day, FoxSynergy, CC BY 3.0). **day rotation done** 2026-10-31 00:00: the day cue cycles Mystical Theme -> Medicine -> Decision (all Zhelanov, CC BY 3.0), ~9 min before a repeat. Spare candidate: Steeps of Destiny (epic, CC BY 3.0, same package) for a boss/dungeon later |
| (d) Headless verification + peak levels | **done** 2026-10-31 03:00: `tools/audio_peaks.sh` sweeps all 117 files (true peak + LUFS, fails above -1 dBTP): all pass after Medicine was re-encoded 1 dB down (was -0.9 dBTP). Voice bus added; hard limiter (ceiling -1 dBFS) last on Master. Bots `mix` `music` `sound` `foley` `hearth` check streams, crossfades, routing, limiter |
| (e) Copyright audit + in-game Credits screen | not started |

## The mix as it stands

Built at load by `game/world/audio_mix.gd`: buses Master > Ambience > Wildlife, Master > SFX,
Master > Music, Master > Voice; a hard limiter (-1 dBFS) last on Master. Volumes per bus saved in `user://settings.cfg`; the pause menu
(`game/ui/pause_menu.gd`) has Master / Ambience / Wildlife / Effects / Voices / Music sliders. Inside
the ruined keep the SFX bus gets a short stone reverb and Ambience a low-pass.

Mix problems found in the audit:
- (fixed 2026-10-31 03:00) **No Voice bus** — `Voice` (Master > Voice) now exists with a "Voices" pause-menu slider, ready for recorded lines; music already ducks under dialogue.
- (added 2026-10-31 03:00) **Nothing stopped the summed mix clipping** — an `AudioEffectHardLimiter` (ceiling -1 dBFS, release 0.1 s) now sits last on Master.
- (fixed 2026-10-30) **Wheatear voices (`wheatears.gd`) and the fell bell knock (`fell_bell.gd`) set no bus**, so
  they play straight into Master and ignore the Wildlife / Effects sliders. Now routed to Wildlife and SFX.
- (fixed 2026-10-30 22:00) **No Music at all** — the Music bus now carries the score (`music.gd`).
- Every stream is a 22.05 kHz (wind/thunder 11.025 kHz) mono AudioStreamWAV built from noise
  and oscillators at load; nothing has a real recorded transient or room.

## Music (2026-10-30 22:00)

`game/world/music.gd` (class `Music`, built by `world.gd` as node `Music`), every player on the Music bus
(pause-menu Music slider). One looping player per track, gains eased on the wall clock (unaffected by the
perfect-dodge slow-mo), equal-power crossfades so two tracks are never both at full:

| Cue | When | Track | Trim | Fade |
|---|---|---|---|---|
| day | Harrowmere Vale, 05:30-20:30 | rotation: Mystical Theme (-4 dB) -> Medicine (-3.5 dB) -> Decision (-5 dB), all Alexandr Zhelanov; the next piece crossfades in 3 s before the current one would loop, the finished one rewinds | per piece | 3 s |
| night | 20:30-05:30 | Without — Alexandr Zhelanov | -8 dB | 3 s |
| hearth | within 16 m of Hesper's fire by day | Lazy Day — FoxSynergy (lute, flute, warm bass) | -6 dB | 3 s |
| hearth_night | the same, 20:30-05:30 | Lazy Day, settling softer | -9 dB | 3 s (trim eased 2 dB/s) |
| combat | a Hollow Soldier within 32 m leaves IDLE, or the hero locks on; held 4 s after | Battle in the Winter — Johan Brodd | -3 dB | 1.6 s in and out |
| victory stinger | a fight ends with an enemy crumbled; the vale cue waits under it, then fades back | Heroes Theme, last 8.3 s — Alexandr Zhelanov | -3 dB | one-shot |

Dialogue duck: -6 dB over 0.6 s while Hesper, Edda, the neighbour, Wat or Hild has a line on screen.
Paused tracks keep their position. File levels (ffmpeg ebur128): -15.4..-16.9 LUFS (Lazy Day -16.5 LUFS, peak -1.4 dBFS), true peak -1.4..-3.9 dBFS,
nothing clips. Bot `music` proves: day fades in and plays; day->night crossfade at the mid point is 0.50/0.50
with power sum 1.00; night takes over and the day track pauses; hearth theme takes over by the fire at night (night track out), and is >= 2 dB warmer at noon; duck under a line;
combat comes in within 1.6 s of the soldier stirring with the day track out; held after the kill, then the
stinger plays and the day theme returns; the day theme hands over piece to piece (mid-handover power sum 1.00), each
next piece starts from the top, the old one stops, and the rotation cycles all three and back.

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

Collie, hens, fox crunch (2026-10-30 21:00), `Foley.RECORDED["animals"]`, files in `game/audio/sfx/animals`:

| Name | Variants | Recording |
|---|---|---|
| dog_bark / dog_woof | 4 / 2 | Anton terrier barks (CC BY 3.0) pitched down to collie size |
| cluck / squawk | 4 / 3 | evsecrets chicken (CC0): real hen clucks; the hurt squawk at three pitches |
| crunch | 3 | InspectorJ animal eating (CC BY 3.0) |
| bat_call / buzz / grumble | — | **dropped**: real pipistrelle calls are near-ultrasonic; the bat is now silent and the synthesis code is gone |

Village and weather extras (2026-10-31 01:00), all OpenClonk CC BY 3.0 (see ASSETS.md):

| Name | Where | Variants | Recording |
|---|---|---|---|
| grain | `foley.gd`, Edda scattering feed over the garth wall | 3 | shall555 digging in soil, pitched up and high-passed into a seed patter |
| grunt | `foley.gd`, Edda heaving a round onto the block | 3 | bennychico11 farmer grunts |
| blow | `hearth.gd`, Hesper's two breaths into the tinder and the flame taking | 1 | Ringwaul breath gusts + CGEffex fire inflame |
| dust devil whoosh | `dust_devils.gd` (bus Ambience), looping, gain follows the whirl | 1 loop, 52 s | ERH wind loop, high-passed |
| call, hum, murmur, murmur_low | `foley.gd` | — | **dropped** (silent, `Foley.SILENT`): no real voice recording yet; the synthesis code is gone. The schedules still run, they just make no sound |

Last pass (2026-10-31 02:00): **nothing is synthesised any more.** Every sound name is either a recording or silent.

| Name | Where | Variants | Recording |
|---|---|---|---|
| rook wing clatter | `soundscape.gd` `_rook_scatter` (Wildlife), the nearest rook when a flock lifts off | 3 | OpenClonk bat flutter (ala, CC BY 3.0), pitched down 15 % |
| fell bell knock | `fell_bell.gd` (SFX), each hard turn of the swinging bell | 3 | OpenClonk metal bucket hits (ala, CC BY 3.0), one pitched up 8 % |
| bark, roar, gallop, gallop_wet | `foley.gd`, red deer | — | **dropped** (silent, `Foley.SILENT`): no CC0/CC-BY red deer or hoof recording reachable (searched VoxeLibre, Veloren [GPL/CC BY-SA, rejected], OpenClonk, minetest_game) |
| fox_bark, fox_yelp | `foley.gd`, the fox | — | **dropped** (silent, same reason) |
| rook caws, kite whistle (soaring + harsh) | `soundscape.gd` | — | **dropped**: the caw and kite synthesis and the kite's voice are gone; birds.gd still runs the behaviour |
| wheatear chack + song | `wheatears.gd` | — | **dropped**: synthesis and the per-bird voices removed; `chacks` still counts the alarm |

Synthesis code that remains is only a fallback for a missing file (foley, hearth, soundscape beds, dust devil);
with the repo's files present none of it plays. Bots `foley` (SILENT names have no stream), `fox`, `herd`, `kite`
(behaviour fires, nothing sounds), `sound` (wing clatter recorded), `flockbell` (bell knocks are recorded Ogg).

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
- Still to find: red deer (bark, roar, gallop), fox bark/scream, rooks, red kite, wheatear. Checked and rejected 2026-10-30 21:00: remvze/moodist (no per-file licenses, Pixabay mixed in), Skandarella/animalworld ("Creative Commons" with no per-file license), ElCeejo/animalia (no sound credits), jenius-apps/ambie (no animals). Used: VoxeLibre/VoxeLibre mobs_mc (per-file LICENSE-media.md; its wolf/horse/bat files are other candidates), HybridDog/dogblocks.
- Earlier note: look for GitHub mirrors of Kenney "Impact Sounds" and "RPG Audio" (CC0: footsteps,
  cloth, wood/metal impacts) and of CC0 Freesound field recordings (wind, rain, birds).

## Level sweep (2026-10-31 03:00, `tools/audio_peaks.sh`)

117 files. Loudest true peaks: music/vale_day_decision -1.2, hearth_lazy_day -1.4, combat_battle -1.4,
thunder_near_1..3 -1.5..-1.7, clang_2 -2.0 dBTP; every SFX file at or below -1.5 dBTP. Music integrated
loudness -15..-18 LUFS (balanced by per-track trims in `music.gd`). vale_day_medicine was -0.9 dBTP: re-encoded
1 dB down (Vorbis q2, now -1.6 dBTP) and its trim raised -3.5 -> -2.5 dB so it plays as loud as before.
Rerun the sweep after adding any audio file.
