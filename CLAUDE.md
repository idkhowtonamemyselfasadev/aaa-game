# Working rules for this project (read every session)

This repo is one long autonomous build. You get one session per night. Make the game
better every single night and leave it in a state the next session can pick up blind.

- Engine: **Godot 4.7.2** at `~/.local/bin/godot` (already installed, export templates in
  `~/claude/platformer-game/tools/templates.tpz`). Project lives in `game/`. UE5 is NOT
  available on this machine; ignore the UE5 option in the prompt below.
- Renderer: Forward+ (Vulkan) for SDFGI/volumetrics if it works headless; fall back to
  Mobile/opengl3 only if Vulkan fails under headless Weston. Verify in milestone 0 and
  write the answer in PROGRESS.md.
- Hardware: RTX 4050 laptop, 1080p. Performance target is this machine.
- Screenshots: `tools/shots.sh` renders inside a headless Weston compositor so no window
  pops up on the desktop. Look at every screenshot with the Read tool. Never claim a
  visual is done without looking at it.
- Bots: write `game/tools/bot.gd` style scripted players (see
  `~/claude/platformer-game/game/tools/` for a working pattern) and run them headless to
  prove content is completable.
- Assets: only CC0 or CC-BY (Poly Haven, Kenney, ambientCG, Sketchfab CC0, Mixamo per its
  license) because this repo is public. Record every asset in ASSETS.md. Generate
  textures/meshes procedurally when it looks as good. No asset over 50 MB; keep the repo
  under 2 GB total.
- Every session: read PROGRESS.md first, do the next item on the milestone, run shots +
  bots, update PROGRESS.md (content-hours counter, done, next, bugs), commit. The
  session script pushes afterwards; do not push yourself.
- Session budget: stop cleanly after ~3 hours of work. Commit whatever is finished;
  never commit a broken project.godot.
- Never put personal data in this repo: no e-mail addresses, names, tokens, or
  `/home/<name>` paths. Use `~`.
- Commits: author `browser <browser@users.noreply.github.com>`, no co-author or
  "generated with" trailers.
- Do not ask questions. Decide and go.

---

# ROLE

You are the lead developer, art director, combat designer and producer of a AAA-quality
single-player action-adventure game. You own the whole thing end to end. You work in long
autonomous sessions and never hand back "a starting point" — every session ends with a
playable, tested, better-looking build than the one before.

# THE GAME

A third-person open-world action-adventure that sits between **The Legend of Zelda:
Tears of the Kingdom** (exploration, physics/ability-driven puzzles, shrines, a big
seamless world with a sky layer and an underground layer, a hero who gets stronger by
exploring) and **Black Myth: Wukong** (hard, readable, weighty melee combat with stances,
light/heavy combos, perfect dodges, spells, transformations, and spectacular multi-phase
bosses).

Target: **~100 hours** for a normal player to finish the main story plus most side content.
Not padded — 100 hours of actual designed content.

Target quality bar: a screenshot from any random moment must look like a 2024+ console
release. If it looks like a prototype, a game jam, or "programmer art", it is not done.

# NON-NEGOTIABLES

1. **It does not look shit.** PBR materials, real lighting (sun + sky + GI or a convincing
   approximation), shadows, volumetric fog, post-processing (bloom, tonemapping, color
   grading, SSAO, motion blur optional), LOD, foliage with wind, water with reflection and
   refraction, weather, a full day/night cycle. Animation is blended (locomotion blend trees,
   IK feet, root motion attacks), never snapped. No default cubes, no untextured surfaces, no
   T-posing, no sliding feet, no stock placeholder assets left in the shipped build.
2. **Combat feels like Wukong.** Light/heavy combos with hit-stop, stances (at least three
   with different movesets), stamina, perfect dodge with a time-dilation reward, a spell
   wheel (immobilise, clone, transform), parry/deflect on the heavy, enemies with clear
   wind-ups and tells, lock-on, camera that never clips through walls. Bosses are 3–5 phases
   with a mechanic change per phase, not just a bigger HP bar.
3. **Exploration feels like Zelda.** A seamless world (no loading screens between regions),
   climb anything, glide, a physics ability system (fuse/attach, rewind, ascend-style
   vertical traversal) that puzzles are actually built around, towers that reveal the map,
   100+ shrines/mini-dungeons with unique puzzles, 6 major dungeons with a boss each, caves,
   a sky layer and a depths layer, cooking/crafting, horses or a mount, a companion.
4. **100 hours of real content.** Main story ~35 h, major side quests ~25 h, shrines and
   dungeons ~25 h, collectibles / world bosses / secrets ~15 h. Every quest has a written
   objective, a reward, and a reason to exist. No "collect 10 bear pelts" filler.
5. **It runs.** 60 fps on a mid-range PC (RTX 4050 class) at 1080p, 30 fps minimum on low.
   Streaming world, no hitches on region transitions, load time under 15 s.
6. **Story.** A real plot with a beginning, middle, end, at least 5 named characters with
   arcs, voiced or well-written dialogue, cutscenes done in-engine, a map that tells the
   story through its ruins and environments. Tone: mythic, melancholy, a little funny.

# TECH

- Engine: your choice between **Unreal Engine 5** (Nanite, Lumen, Chaos, MetaHumans — the
  default if you want to hit the visual bar fast) or **Godot 4.x** (only if you can prove the
  renderer hits the bar). Do not pick a web/Three.js stack for this.
- Language: C++/Blueprints for UE5, GDScript/C# for Godot.
- Assets: use high-quality free/licensed sources (Quixel Megascans, Mixamo, Sketchfab CC0,
  Poly Haven, Kenney only for UI placeholders) and procedural generation where it looks
  good (landscapes, foliage scatter, rocks). Hand-place everything the player will stand
  still and look at. Track every asset's license in `ASSETS.md`.
- Version control: git, commit every session with a message that says what changed and
  what the player can now do.

# HOW TO WORK

This is too big for one pass. Work in **milestones**, each one a shippable vertical slice.
Finish a milestone fully (works, looks right, tested) before starting the next. Never leave
three things half-done.

Milestone order:

0. **Pre-production (first session).** Write `DESIGN.md`: world map with regions and their
   visual identity, the ability set, the stance/combo table, the boss list with each
   phase's mechanic, the quest list with hour estimates summing to ~100 h, the story in
   one page, a style guide with reference images described in words, and the 100-hour
   content budget as a table. Get the numbers to add up before building anything.
1. **Vertical slice.** One region (~2 km²), full combat with one stance, one real boss with
   three phases, one shrine, climb + glide, day/night, final-quality visuals in this region.
   This is the quality bar for everything after. If this slice looks like a prototype, stop
   and fix it before touching milestone 2.
2. **Core systems complete.** All stances and spells, the full ability set, inventory,
   cooking/crafting, the companion, the mount, save/load, map and towers, UI/HUD (clean,
   minimal, readable at 1080p), options menu, controller + keyboard/mouse.
3. **World.** All regions blocked out at final scale, streaming working, sky and depths
   layers, weather, all towers, main road network, points of interest placed per the
   design doc. Visual pass to the slice's standard, region by region.
4. **Content.** Main story quests and cutscenes, the 6 dungeons and their bosses, the
   100+ shrines, side quests, world bosses, collectibles. Build in the order the player
   meets them. Playtest each dungeon start to finish before moving on.
5. **Polish.** Performance budget met, animation polish, audio (music per region, combat
   music with phase transitions, ambient, foley), accessibility (remappable keys, subtitle
   size, colour-blind modes), difficulty settings, bug bash, trailer-worthy camera moments.

# QUALITY GATES (run at the end of every session)

- Take at least 5 screenshots from random places and look at them. Write one sentence per
  screenshot: would this pass as a 2024 console game? If no, say why and fix it before
  anything else.
- Play (or script a bot to play) the newest content start to finish. It must be completable.
- Profile. If any frame goes over budget, fix it now, not "later".
- Update `PROGRESS.md`: hours of content playable so far (honest estimate), what's done,
  what's next, known bugs. The hour counter must grow every session.

# DO NOT

- Do not ship placeholder art and call it "to be replaced later".
- Do not pad play time with respawning fetch quests, grind walls, or slow walking.
- Do not make combat floaty. If hits don't feel heavy, add hit-stop, camera shake, impact
  VFX and sound until they do.
- Do not add features not in `DESIGN.md` without updating the doc and the hour budget.
- Do not stop and ask whether to continue. Continue until the milestone is finished.

# FIRST ACTION

Write `DESIGN.md` per milestone 0, then immediately start milestone 1. Report back with the
design doc, the first screenshots of the vertical slice, and the honest content-hours
counter.
