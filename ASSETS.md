# Assets and licenses

Every third-party asset in `game/` is listed here with its source and license. Only CC0,
CC-BY, OFL, or Mixamo-licensed content is allowed (public repo). Nothing over 50 MB.

| Path | What | Source | License |
|------|------|--------|---------|
| `game/player/models/vanguard.glb` | Rigged humanoid "Vanguard" (Mixamo character) with Idle/Walk/Run/TPose clips, 2.1 MB | Mixamo, via the three.js repo (`examples/models/gltf/Soldier.glb`) | Mixamo license (royalty-free use in games) |

## Copyright audit (owner rule 0b-e) -- status 2026-10-31 04:00

Every third-party file in the repo, by group, with what was checked and where. "Upstream" =
the per-file credit/license file of the repository or package the file was taken from, read
on 2026-10-31. **Blocked**: freesound.org, opengameart.org and kenney.nl do not resolve from
the cloud box (WebFetch: `getaddrinfo ENOTFOUND`, curl: no connection), so the original source
pages could not be opened; those rows stay "upstream-verified, source page pending" until a
session with those domains allowed re-opens them. Nothing found so far fails the rules.

| Group | Files | Checked against (2026-10-31) | Result |
|---|---|---|---|
| Combat whooshes/impacts (Freesound CC0 + Kenney CC0) | combat/swish_*, whoom_*, perfect_1, spear_*, straw_1-2, body_*, boom_*, slam_1-2 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/LICENSES.md` (git clone): "all CC0 1.0 ... only sounds whose page shows CC0 were used, verified per sound on 12 Oct 2026"; lists DeVern 524817, MeanRaccoon 830856, CVLTIV8R 810485, deleted_user_6479820 393811 etc. | pass (CC0); source pages pending |
| Kenney RPG Audio (CC0) | combat/straw_3, wood_4, clang_1-2, dodge_1-3, steps/step_grass_*, village/creak_*, chop_1 | via github.com/mminer/ggj2022; kenney.nl not reachable | pass (Kenney packs are CC0); source page pending |
| minetest_game sounds | combat/clang_3, stone_*, wood_1-3, steps/step_grit_*, step_wet_*, step_stone_*, fire/crackle_loop, flint_1, village/chop_2, thud_1 | github.com/luanti-org/minetest_game `mods/default/README.md` + `license.txt`, `mods/fire/README.md` + `license.txt` (git clone): Benboncan 71823 `default_dig_cracky` CC BY 3.0; Erdie 41579 `default_hard_footstep` CC BY 3.0; AGFX pack 1253 `default_water_footstep` CC BY 3.0; Sheyvan 476113 `default_dig_choppy` CC0; worthahep88 319224 `default_sand_footstep` CC0; lolamadeus 179341 `default_gravel_dug` CC0; qubodup `default_dug_metal` CC0; Dynamicell 17548 `fire_fire`/`fire_large` CC BY 3.0; Benboncan 66457 `fire_flint_and_steel` CC BY 3.0 | pass; CC BY credited on the Credits screen |
| Weather beds | weather/wind_loop, rain_loop, rain_heavy_loop, thunder_* | github.com/Muges/ambientsounds `readme.md`: Heavy Rain by D W (CC BY), Forest Rain by Corsica_S (CC BY), Thunderstorm by RHumphries (CC BY), Wind by felix.blume (CC0) | pass; CC BY credited |
| Blanket sounds | weather/leaves_loop, crickets_loop, birds/song_1-3 | raw.githubusercontent.com Vistaus/blanket `SOUNDS_LICENSING.md`: Wind felix.blume CC0, Birds kvgarlic CC0, Summer night Lisa Redfern (soundbible.com) Public Domain | pass |
| noixer | birds/song_4-6 | abetusk/noixer `README.md`: "chosen to be under a CC0 license", birds = sonidosreales245 517042 | pass |
| dogblocks / VoxeLibre | animals/dog_*, cluck_*, squawk_*, crunch_* | HybridDog/dogblocks `README.md` (terrier, Anton 157322, CC BY 3.0); VoxeLibre `mobs_mc/LICENSE-media.md` (evsecrets 346961 chicken; InspectorJ 429591 `animal_eat_generic` CC BY 3.0) | pass; CC BY credited |
| OpenClonk | village/grain_*, grunt_*, bell_*, fire/blow_1, weather/dust_devil_loop, birds/wings_* | openclonk `planet/Sound.ocg/authors.txt`: default CC BY 3.0; ERH WindLoop, CGEffex Inflame, bennychico11 Farmer Hurt1&2, Stephen Hall Dig1-5, Ringwaul Windbag, ala Bat Flutter + BucketHit | pass; CC BY credited |
| Music | game/audio/music/*.ogg (8) | Ubuntu `edgar-data` 1.37-1build2 (apt-get download), `usr/share/doc/edgar-data/copyright`: Decision, Heroes Theme, Medicine, Mystical Theme, Steeps of Destiny, Without = Alexandr Zhelanov CC-BY-3.0; Battle in the winter = Johan Brodd CC-BY-3.0; Lazy Day v0.9 = FoxSynergy CC-BY-3.0. Content ID: web search 2026-10-31 found no reported claims on Zhelanov's OGA tracks; none of the three artists is known to register with Content ID | pass (CC BY, not SA); OGA pages pending |
| Character | game/player/models/vanguard.glb + 2 textures | Mixamo character via three.js `examples/models/gltf/Soldier.glb`; Mixamo license allows use in games | pass (Mixamo); Adobe FAQ page not reachable from the box, recheck |
| Shaders / includes | game/shaders/*.gdshader, *.gdshaderinc | written for this project (git history), no third-party snippets | pass (original) |
| Fonts | none (Godot's built-in default font, MIT/OFL with the engine) | -- | pass |
| Engine | Godot 4.7.2 (not in the repo, fetched by tools/cloud-setup.sh) | MIT | credited on the Credits screen |

The in-game **Credits** screen (`game/ui/credits.gd`, pause menu > Credits; `Credits.roll()`
for after the ending) lists every CC BY author above; bot `credits` parses this file and fails
if a CC BY author in a table here is missing from the screen.

## Recorded sound effects (`game/audio/sfx/`)

Added 2026-10-30 (owner priority 0b-b). All files were converted to mono 44.1 kHz Ogg Vorbis
(q4; the fire loop q3), leading/trailing silence trimmed, peak-normalised to -3 dBFS, some
trimmed, faded, pitched or low-passed as noted. Paths are relative to `game/audio/sfx/`.

**License check (2026-10-30):** freesound.org, kenney.nl and opengameart.org are refused by
this cloud box's network proxy, so the source pages could not be opened with WebFetch. The
license shown is the one stated per file by the upstream repository the file was taken from
("Fetched via"). The Kenney packs are CC0 per kenney.nl (its RPG Audio page reads "licensed
under CC0 1.0 Universal", seen in search results 2026-10-30). Item (e) of the audio priority
must re-open every Freesound source page and confirm the license before release. The CC BY 3.0 files
must be credited in the in-game Credits screen (item e):
Benboncan, AGFX, Erdie and Dynamicell (all via Freesound, CC BY 3.0).

| File(s) | Original | Source page | Author | License | Fetched via |
|---|---|---|---|---|---|
| combat/swish_1, whoom_1 (pitched 0.72) | broomstick whoosh 3 (quiet) | https://freesound.org/people/Sadiquecat/sounds/816262/ | Sadiquecat | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/swish_2 | fast simple chop 5 | https://freesound.org/people/dave.des/sounds/127197/ | dave.des | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/swish_3 | whoosh | https://freesound.org/people/MeanRaccoon/sounds/830856/ | MeanRaccoon | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/swish_4 | swoosh v2 | https://freesound.org/people/migoreng1/sounds/786514/ | migoreng1 | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/swish_5 | whoosh | https://freesound.org/people/CVLTIV8R/sounds/810485/ | CVLTIV8R | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/whoom_2, perfect_1 (reversed) | woosh | https://freesound.org/people/florianreichelt/sounds/683096/ | florianreichelt | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/whoom_3 | swoosh | https://freesound.org/people/Halgrimm/sounds/169867/ | Halgrimm | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/spear_1 | swipe | https://freesound.org/people/LilMati/sounds/702773/ | LilMati | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/spear_2 | whoosh | https://freesound.org/people/deleted_user_6479820/sounds/393811/ | (deleted user) | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/spear_3 | quick woosh | https://freesound.org/people/florianreichelt/sounds/683101/ | florianreichelt | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/straw_1, straw_2 | impactSoft_heavy_000/001 | https://kenney.nl/assets/impact-sounds | Kenney | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/body_1, body_2 | impactPunch_heavy_000/001 | https://kenney.nl/assets/impact-sounds | Kenney | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/body_3 | impact | https://freesound.org/people/DeVern/sounds/524817/ | DeVern | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/boom_1 | lowFrequency_explosion_001 (first 0.7 s) | https://kenney.nl/assets/sci-fi-sounds | Kenney | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/boom_2, slam_3 (+ gravel layer) | dramatic hit (first 1.2 / 1.4 s) | https://freesound.org/people/qubodup/sounds/222517/ | qubodup | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/boom_3, slam_2 | cinematic impact | https://freesound.org/people/deleted_user_3277771/sounds/177242/ | (deleted user) | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/slam_1 | Michael Bay hit (first 1.6 s) | https://freesound.org/people/Kinoton/sounds/347561/ | Kinoton | CC0 1.0 | github.com/Barty-Bart/motion-graphics `skills/sound-effects/sfx/` (LICENSES.md + manifest.json state CC0, per-sound check 2026-10-12) |
| combat/straw_3 | DropLeather | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| combat/wood_4, village/chop_1 | Chop | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| combat/clang_1, clang_2 | metalPot2/3 | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| combat/dodge_1..3 | cloth1..3 | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| steps/step_grass_1..5 | footstep00/02/05/06/07 (lowpassed 7 kHz) | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| village/creak_1..3 | creak1..3 | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | github.com/mminer/ggj2022 `Assets/Audio/Game SFX/` (Kenney RPG Audio, per issue #7) |
| combat/clang_3 | default_dug_metal.1 (wood and metal SFX) | https://opengameart.org/users/qubodup | Iwan Gabovitch (qubodup) | CC0 1.0 | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| combat/stone_1..3 | default_dig_cracky.1..3 | https://freesound.org/people/Benboncan/sounds/71823/ | Benboncan | **CC BY 3.0** (credit required) | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| combat/wood_1..3, village/chop_2, village/thud_1 | default_dig_choppy.1..3 | https://freesound.org/people/Sheyvan/sounds/476113/ | Sheyvan | CC0 1.0 | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| steps/step_grit_1..3 | default_sand_footstep.1..3 | https://freesound.org/people/worthahep88/sounds/319224/ | worthahep88 | CC0 1.0 | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| steps/step_grit_4, combat/slam_3 (debris layer, gravel_dug.3) | default_gravel_dug.2 / .3 | https://freesound.org/people/lolamadeus/sounds/179341/ | lolamadeus | CC0 1.0 | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| steps/step_wet_1..3 (+ the splash in step_stone_wet) | default_water_footstep.1..3 | https://freesound.org/people/AGFX/packs/1253/ | AGFX | **CC BY 3.0** (credit required) | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| steps/step_stone_1..3 (+ step_stone_wet_1..3) | default_hard_footstep.1..3 | https://freesound.org/people/Erdie/sounds/41579/ | Erdie | **CC BY 3.0** (credit required) | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| fire/crackle_loop | fire_fire.1..3 + fire_large, crossfaded into an 18 s loop | https://freesound.org/people/Dynamicell/sounds/17548/ | Dynamicell | **CC BY 3.0** (credit required) | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |
| fire/flint_1 | fire_flint_and_steel | https://freesound.org/people/Benboncan/sounds/66457/ | Benboncan | **CC BY 3.0** (credit required) | github.com/luanti-org/minetest_game `mods/*/sounds` (per-file credits in mods/*/README.md + license.txt) |

### Weather beds, thunder and songbirds (added 2026-10-30 20:00)

Cut with ffmpeg + numpy from longer recordings in three GitHub repositories that list a
per-file source and license; mono 44.1 kHz Ogg Vorbis q4, beds made into seamless loops with an
equal-power crossfade, rain run through a gentle compressor, peaks <= -1.5 dBFS (thunder) and
<= -4 dBFS (beds). freesound.org and soundbible.com could not be reached from the cloud box
(WebFetch: host not resolvable), so licenses are as stated by those repositories, checked
2026-10-30; item (e) must re-open each source page. The CC BY ones must appear in the Credits:
Corsica_S, D W, RHumphries (all via Freesound, CC BY). Nothing CC BY-SA was taken (blanket's
pink/white noise and every unlisted file in those repos were skipped).

| File(s) | Original | Source page | Author | License | Fetched via |
|---|---|---|---|---|---|
| weather/wind_loop (s 20-110, high-passed 40 Hz) | Wind | https://freesound.org/people/felix.blume/sounds/139337/ | felix.blume | CC0 1.0 | github.com/Muges/ambientsounds `wind.ogg` (readme lists source + license per file) |
| weather/leaves_loop (whole take, high-passed 220 Hz) | Wind | https://freesound.org/people/felix.blume/sounds/217506/ | felix.blume (edit Porrumentzio) | CC0 1.0 | github.com/Vistaus/blanket `SOUNDS_LICENSING.md` (wind.ogg) |
| weather/rain_loop (s 5-65) | Forest Rain | https://freesound.org/people/Corsica_S/sounds/169031/ | Corsica_S | **CC BY** (credit required) | github.com/Muges/ambientsounds `forest-rain.ogg` |
| weather/rain_heavy_loop (s 2-48) | Heavy Rain | https://freesound.org/people/D%20W/sounds/136971/ | D W | **CC BY** (credit required) | github.com/Muges/ambientsounds `heavy-rain.ogg` |
| weather/thunder_near_1..3 (claps at 42 s, 83 s, 154 s), thunder_far_1..3 (56 s, 97 s, 15 s, low-passed 650 Hz) | Thunderstorm | https://freesound.org/people/RHumphries/sounds/2523/ | RHumphries | **CC BY** (credit required) | github.com/Muges/ambientsounds `thunderstorm.ogg` |
| weather/crickets_loop (s 1-48, high-passed 1.5 kHz) | Crickets Chirping At Night | https://soundbible.com/2083-Crickets-Chirping-At-Night.html | Lisa Redfern | Public Domain | github.com/Vistaus/blanket `SOUNDS_LICENSING.md` (summer-night.ogg) |
| birds/song_1..3 (4 s around single calls at 40, 64, 94 s; high-passed 900 Hz) | Birds | https://freesound.org/people/kvgarlic/sounds/156826/ | kvgarlic (edit Porrumentzio) | CC0 1.0 | github.com/Vistaus/blanket `SOUNDS_LICENSING.md` (birds.ogg) |
| birds/song_4..6 (4 s around calls at 46, 70, 101 s; high-passed 900 Hz) | forestday bw 66 | https://freesound.org/people/sonidosreales245/sounds/517042/ | sonidosreales245 | CC0 1.0 | github.com/abetusk/noixer `assets/` (README: sounds chosen CC0 from Freesound, table lists this file) |

### Collie, hens and the fox's crunch (added 2026-10-30 21:00)

Cut/normalised with ffmpeg (loudnorm -18 LUFS, limiter, peaks <= -3.7 dBFS), mono 44.1 kHz
Ogg Vorbis q5 under `game/audio/sfx/animals/`. Barks pitched down 6-10 % (woofs 18-20 % and
low-passed) so the small terrier reads as a working collie. freesound.org is still not
resolvable from the cloud box, so licenses are as stated by the repositories (checked
2026-10-30); item (e) must re-open each source page. Credit needed: **Anton** (CC BY 3.0),
**InspectorJ** (CC BY 3.0). Nothing CC BY-SA taken; dogblocks' other breeds (sources not
named) and its textures (CC BY-SA) were skipped.

| File(s) | Original | Source page | Author | License | Fetched via |
|---|---|---|---|---|---|
| animals/dog_bark_1..4, dog_woof_1..2 | terrier barks (`dogblocks_ft.1/2/5/14`, `.4/.6`) | https://freesound.org/people/Anton/sounds/157322/ | Anton | **CC BY 3.0** (credit required) | github.com/HybridDog/dogblocks README.md ("CC by 3.0 sounds: terrier ... Anton 157322"); VoxeLibre mobs_mc LICENSE-media.md also lists these |
| animals/cluck_1..4, squawk_1..3 | `mobs_mc_chicken_buck.1..3`, `mobs_mc_chicken_hurt` | https://freesound.org/people/evsecrets/sounds/346961/ | evsecrets | CC0 1.0 | github.com/VoxeLibre/VoxeLibre `mods/ENTITIES/mobs_mc/LICENSE-media.md` |
| animals/crunch_1..3 | `mobs_mc_animal_eat_generic` | https://freesound.org/people/InspectorJ/sounds/429591/ | InspectorJ | **CC BY 3.0** (credit required) | github.com/VoxeLibre/VoxeLibre `mods/ENTITIES/mobs_mc/LICENSE-media.md` |

### Grain, Edda's grunt, Hesper's breath and the dust devil (added 2026-10-31 01:00)

All from OpenClonk (github.com/openclonk/openclonk, `planet/Sound.ocg`; Ubuntu package
openclonk-data). Its `planet/Sound.ocg/authors.txt` states "If not stated otherwise, the sound
effects are licensed under the CC Attribution 3.0 license" and names each file's author and
Freesound source (checked on GitHub with WebFetch 2026-10-31). freesound.org is still not
resolvable from the cloud box, so item (e) must re-open each Freesound page. Cut/normalised
with ffmpeg, mono Ogg Vorbis, peaks <= -2.4 dBFS. Credit needed (all **CC BY 3.0**):
**Stephen Hall (shall555)**, **bennychico11**, **Ringwaul (OpenClonk team)**, **CGEffex**, **ERH**.

| File(s) | Original | Source page | Author | License | Fetched via |
|---|---|---|---|---|---|
| village/grain_1..3 | `Clonk.ocg/Action.ocg/Dig.ocg/Dig2/4/3.wav` (pitched up 25 %, high-passed: seed pattering on the yard) | https://freesound.org/people/shall555/sounds/72199/ | Stephen Hall (shall555) | **CC BY 3.0** | openclonk authors.txt |
| village/grunt_1..3 | `Clonk.ocg/Skin.ocg/Farmer.ocg/Hurt1/2.ogg` (3rd = Hurt1 pitched down 6 %) | https://freesound.org/people/bennychico11/sounds/80438/ | bennychico11 | **CC BY 3.0** | openclonk authors.txt |
| fire/blow_1 (two breaths) | `Objects.ocg/Windbag.ocg/Charge.ogg` x2, low-passed | https://github.com/openclonk/openclonk/tree/master/planet/Sound.ocg | Ringwaul (OpenClonk team) | **CC BY 3.0** | openclonk authors.txt |
| fire/blow_1 (the flame taking) | `Fire.ocg/Inflame.ogg` | https://freesound.org/people/CGEffex/sounds/94102/ | CGEffex | **CC BY 3.0** | openclonk authors.txt |
| weather/dust_devil_loop | `Environment.ocg/WindLoop.ogg` (high-passed 180 Hz) | https://freesound.org/people/ERH/sounds/34338/ | ERH | **CC BY 3.0** | openclonk authors.txt |

### Rook wings and the fell bell (added 2026-10-31 02:00)

Also OpenClonk (github.com/openclonk/openclonk, `planet/Sound.ocg`, cloned from GitHub
2026-10-31). `authors.txt` lists both under **ala** (OpenClonk team: "Animals/Bat: Chirp,
Flutter1&2&3, Noise1&2&3" and "Hits/BucketHit*"), with no other license stated, so the file's
default applies: **CC BY 3.0, credit required** (credit: **ala / OpenClonk team**). Both are
real recordings (spectrograms checked: irregular wing beats over a natural noise floor; a
struck metal bucket with tonal partials). Mono Ogg Vorbis q4, 44.1 kHz.

| File(s) | Original | Source page | Author | License | Fetched via |
|---|---|---|---|---|---|
| birds/wings_1..3 | `Animals.ocg/Bat.ocg/Flutter1/2/3.wav` (pitched down 15 %, high-passed 150 Hz, peak -8 dBFS): the clatter of a rook flock lifting off | https://github.com/openclonk/openclonk/tree/master/planet/Sound.ocg/Animals.ocg/Bat.ocg | ala (OpenClonk team) | **CC BY 3.0** | openclonk authors.txt |
| village/bell_1..3 | `Hits.ocg/BucketHit1/2.wav` (3rd = BucketHit1 pitched up 8 %; high-passed 200 Hz, peak -6 dBFS): the fell bell's clonk | https://github.com/openclonk/openclonk/tree/master/planet/Sound.ocg/Hits.ocg | ala (OpenClonk team) | **CC BY 3.0** | openclonk authors.txt |

## Music (`game/audio/music/`, added 2026-10-30 22:00)

Taken from Ubuntu's `edgar-data` 1.37 package (archive.ubuntu.com, noble/universe; extracted
from its `edgar.pak`), whose Debian `copyright` file credits each track by author and license.
Each license was then re-checked against the original OpenGameArt page through web search on
2026-10-30 (opengameart.org itself is not reachable from the cloud box; item (e) re-opens
each page). Re-encoded with ffmpeg: loudnorm to -16..-17 LUFS, true peak <= -1.4 dBFS, 44.1 kHz
Ogg Vorbis q4; the stinger is cut from the last 8.3 s of Heroes Theme with a 0.6 s fade-in
(a modification, allowed by CC BY). All **CC BY 3.0: credit required** in the Credits screen.
Rejected from the same package: "A Wintertale" (Johan Brodd; Debian says CC BY 3.0 but its OGA
page lists CC BY-SA 3.0 / GPL 3.0 -- share-alike music is not allowed), "Hope" (Szymon
Matuszewski; license not confirmable), every CC BY-SA track (Pant0don, grindhold, xXUnderTowerXx,
Eliot Corley, Matthew Pablo "Undead Rising"). None of the used artists is known to register
with YouTube Content ID (checked by search, 2026-10-30; recheck in (e)).

| File | Track | Source page | Author | License | Checked |
|---|---|---|---|---|---|
| music/vale_day_mystical_theme.ogg | Mystical Theme | https://opengameart.org/content/mystical-theme | Alexandr Zhelanov | **CC BY 3.0** | 2026-10-30 |
| music/vale_night_without.ogg | Without | https://opengameart.org/content/without | Alexandr Zhelanov | **CC BY 3.0** | 2026-10-30 |
| music/combat_battle_in_the_winter.ogg | Battle in the winter | https://opengameart.org/content/battle-in-the-winter | Johan Brodd (jobromedia) | **CC BY 3.0** (also offered as OGA-BY 3.0 / GPL 3.0; used under CC BY 3.0) | 2026-10-30 |
| music/victory_heroes_theme_end.ogg | Heroes Theme (last 8.3 s) | https://opengameart.org/content/heroes-theme | Alexandr Zhelanov | **CC BY 3.0** | 2026-10-30 |
| music/hearth_lazy_day.ogg | Lazy Day (v0.9) | https://opengameart.org/content/lazy-day | FoxSynergy | **CC BY 3.0** (Debian edgar-data copyright + OGA page via search; tags lute, flute, warm, village; added 2026-10-30 23:00, loudnorm -16.5 LUFS, peak -1.4 dBFS) | 2026-10-30 |
| music/vale_day_medicine.ogg | Medicine | https://opengameart.org/content/medicine | Alexandr Zhelanov | **CC BY 3.0** (Debian edgar-data copyright + OGA page via search: "Hollywood soundtrack" style; loudnorm -16.7 LUFS, peak -0.9 dBFS, Vorbis q2; 2026-10-31 03:00 re-encoded 1 dB down to -1.6 dBTP) | 2026-10-31 |
| music/boss_steeps_of_destiny.ogg | Steeps of Destiny | https://opengameart.org/content/steeps-of-destiny (lpc.opengameart.org/node/16918) | Alexandr Zhelanov | **CC BY 3.0** (Debian edgar-data copyright lists "music/Steeps of Destiny.ogg" under Alexandr Zhelanov CC-BY-3.0; OGA listing via web search 2026-10-31: "License(s): CC-BY 3.0", posted 2013-06-21; opengameart.org itself still DNS-blocked for WebFetch. Extracted from edgar.pak, loudnorm -14.5 LUFS, true peak -1.3 dBTP, Vorbis q4; the Ashen Knight's boss cue, added 2026-10-31 06:00) | 2026-10-31 |
| music/vale_day_decision.ogg | Decision | https://opengameart.org/content/decision (also lpc.opengameart.org/content/decision) | Alexandr Zhelanov | **CC BY 3.0** (Debian edgar-data copyright + OGA page via search; Legend of Rathnor collection; loudnorm -15.3 LUFS, peak -1.2 dBFS, Vorbis q2) | 2026-10-31 |

## Procedural (no license needed)
- Lantern post: `game/world/lantern_post.gd` (oak post, braced arm, wrought-iron lantern, horn panes, tallow candle; meshes built in code) with `game/shaders/lantern.gdshader`, `lantern_horn.gdshader`, `flame.gdshader` (original, procedural).
- `game/world/terrain.gd` — heightfield terrain from FastNoiseLite.
- `game/shaders/terrain.gdshader` — slope-blended grass/dirt/rock using a NoiseTexture2D.
- Oak trees, leaf atlas, boulders, bark/leaf/rock shaders: generated procedurally in `game/world/flora.gd` and `game/shaders/` (original, no third-party assets).
- Hero staff: `game/player/staff.gd` (lathe mesh: bronze caps with machined ridges, lacquered shaft, cloth grip) and `game/shaders/staff.gdshader` (procedural wood grain, lacquer wear, tarnish, weave) — original.
- Hollow Soldier: `game/enemies/hollow_soldier.gd` reuses `vanguard.glb` (above) with `game/shaders/hollow.gdshader` (ash-stone, Voronoi fissures, ember glow, dissolve); spear `game/enemies/spear.gd` + `game/shaders/spear.gdshader` (lathe + leaf blade, wood/iron/cord) — original.
- Limewashed cottage: `game/world/white_cottage.gd` (StoneCottage builder with its own shape) + limewash mode (a = 4) in `game/shaders/masonry.gdshader` — original.
- Briar Hounds: `game/enemies/briar_hound.gd` (the collie's procedural loft mesh `Dog.build_mesh`, scaled, char-grey coat and ember eyeshine in `game/shaders/dog.gdshader`); their snarl/yelp/bite reuse the recorded terrier and crunch samples credited above — original, no new third-party files.
- Red fox: `game/world/fox.gd` (procedural loft mesh via Herd's helpers) + `game/shaders/fox.gdshader` (trot/run/sit pose, coat, eyeshine) — original.
- Practice post: `game/world/training_post.gd` + `game/shaders/training_post.gdshader` (oak, straw, rope, iron, all procedural); impact chaff/dust in `game/fx/impact.gd` (code-generated particles, gradient texture) — original.
- Meadow wildflowers (ox-eye daisy, buttercup, knapweed, yarrow): `game/world/flowers.gd` (procedural stem/leaf/petal meshes) + `game/shaders/flower.gdshader`, `game/shaders/meadow_wind.gdshaderinc` — original.
- Watchtower ruin (chipped cut-stone blocks, keep, curtain wall, fallen stones): `game/world/ruins.gd` + `game/shaders/masonry.gdshader` — original, procedural.
- Ivy on the keep (climbing stems, lobed leaf blades, painted veins): `game/world/ivy.gd` + `game/shaders/ivy.gdshader` — original, procedural.
- Red deer herd (hinds and calves): `game/world/herd.gd` (lofted body/neck/head/legs/ears mesh, herd behaviour) + `game/shaders/deer.gdshader` (gait/grazing pose, coat markings, hair detail) — original, procedural. Model check: `game/tools/deer_view.gd`.
- The fold's wheatears (cock, hen, youngster: perch, bob, feed, flush; silent since 2026-10-31, no recording yet): `game/world/wheatears.gd` (rook mesh from `birds.gd`, rescaled) + `game/shaders/wheatear.gdshader` (pose + plumage) — original, procedural.
- Soundscape mixer `game/world/soundscape.gd` (code only; every sound it plays is a recorded file listed above).
- Hesper's cookfire (sooted ring stones, charred oak logs with glowing crazed char, ash bed, flame/smoke textures, sparks, moths, crackle loop): `game/world/hearth.gd` + `game/shaders/hearth.gdshader` — original, procedural; the crackle is the recorded `fire/crackle_loop` above.
- Harrowmere cottage (dry-stone footing from the ruin stone meshes, hewn oak frame, limewashed wattle-and-daub, plank door with iron straps, mullioned window, riven slate roof laid slate by slate, stone ridge and chimney): `game/world/cottage.gd` + `game/shaders/cottage.gdshader` — original, procedural.
- Harrowmere stone cottage (coursed rubble walls in the ruin stone, quoins, oak lintels/door/frames/shutters, graded riven slates, stone ridge, chimney stack + smoke, leaded window panes): `game/world/stone_cottage.gd` + `game/shaders/mortar.gdshader`, `slate.gdshader`, `timber.gdshader`, `pane.gdshader` — original, procedural.
