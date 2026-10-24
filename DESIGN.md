# EMBERFALL — Design Document (milestone 0)

Working title: **Emberfall**. Third-person open-world action-adventure. Exploration and
physics-ability puzzles in the spirit of *Tears of the Kingdom*; heavy, readable stance-based
melee in the spirit of *Black Myth: Wukong*. Target length ~30 h (owner's direction, 2026-10-10: quality over quantity). Engine: Godot 4.7
(Forward+). Look: realistic, Black Myth: Wukong-grade; the world must feel alive (§8).

---

## 1. Story (one page)

**Premise.** The continent of Aurel was lit by the Ember, a sun-shard the first kings chained
beneath the capital so night would never fall. Three centuries later the chain broke. The Ember
fell through the world and lodged in the Depths, and the sky it once held up cracked into
drifting islands. Now the surface endures a slow "Long Dusk": a sun that never fully rises,
cold creeping in from the west, and the Hollow — beings grown from the Ember's grief — wearing
the shapes of the dead.

**The hero: Wren**, a lamplighter's apprentice from the dusk-town of Harrowmere. Wren carries
the last working **Lantern of the Ember**, a relic that drinks light and lets its bearer bend
the world (the ability set, §3). Wren is quiet, dryly funny, and not chosen by anyone — just
the only person who picked the lantern up.

**Companion: Pell**, a small fox-shaped Hollow who remembers being a court scribe. Pell is the
tutorial voice, the map's historian, and the game's conscience. Pell is slowly forgetting
himself; whether he fades or is remembered is a side-arc the player resolves.

**Antagonist: The Warden Ashka**, last of the Ember's chained guardians, who believes the only
way to stop the Long Dusk is to re-chain the Ember by force — using Wren's lantern and Wren's
life as the new chain. She is right about the stakes and wrong about the price.

**Other named characters.**
- **Idris Vane**, exiled general of the sky-fleet, now a bandit king in the Shale Barrens.
  Arc: redemption through the player's choice to trust him or not (side quest chain).
- **Mother Oru**, the river-folk matriarch of the Vellmarsh, who knows the Depths route.
  Arc: grief for a daughter who went down and became a Hollow; the player can bring that
  Hollow back as an ally or lay it to rest.
- **The Cartographer (Sefi Ode)**, who built the towers and lost her sight doing it. Arc:
  each tower restored returns a memory; the last one returns her sight and she chooses to
  leave it unrestored.
- **Hesper**, the last keeper of the Shrine of Binding, an old pilgrim living rough in the
  ruined watchtower keep above Harrowmere. Keeps the sealed lid swept and watches the vale at
  dawn and dusk. Arc (Act I side thread): she has guarded a door she cannot open for forty
  years; when Wren opens it she must decide whether her life's watch was worth anything.
- **Edda**, a cottager in the limewashed house on Harrowmere's green: draws water, splits
  and stacks the wood, eats on the bench by her door and lights the green's lantern at dusk
  with a taper. Arc (Act I side thread): she lit that lantern every night for a husband who
  went up to the keep and never came back down; Wren's Kindle can light it for her the night
  she cannot.
- **Osric**, Edda's neighbour in the stone cottage, an old shepherd gone stiff in the knees:
  keeps the hens she feeds for him, takes the eggs, leans on the garth wall looking out over
  the field where his fold used to be. Arc (Act I side thread): he still counts a flock that
  is gone; the player can bring him word of the last of it from the high fell.
- **Wat Pennock**, a pedlar on the fell road (the first ambient road event): a creel of dyed
  cloth, salt and needles on his back and an ash staff, through the village at 09:00 and back
  at 14:30, a word called to Edda across the green and to Osric over his wall. Later: a trade
  window (salt, thread, a whetstone) and news of the keep that changes with the story.
- **Caelum**, the sky-island boy king, twelve years old and ruling a court of automatons. Arc:
  learns to come down.

**Structure.**
- *Act I (~3 h):* Harrowmere burns. Wren takes the lantern, meets Pell, learns the
  four abilities across the Greywold and Harrowmere Vale, lights the first tower, defeats the
  Ashen Knight (first dungeon). Learns the Ember is in the Depths and Ashka is hunting it.
- *Act II (~6 h):* Two regions, two dungeons, two Ember-keys. Each region's
  dungeon boss is one of Ashka's former guardians. Wren gains the glider (Caelum's envoy) and the
  Depths route (Oru's). Pell starts forgetting. Idris's betrayal / redemption. Midpoint:
  Ashka takes the lantern and Wren falls into the Depths without it — a 90-minute segment
  with no abilities, learning the Depths' own light-rules.
- *Act III (~3 h):* Wren reclaims the lantern from Ashka's citadel in the capital,
  descends the shaft under the capital with every ally, fights Ashka (5 phases) at the Ember,
  then chooses: re-chain it (the sun returns, the sky islands fall, the Hollow — Pell included —
  die) or let it burn free (dusk remains but the world learns to live in it; Pell stays).
  Both endings are complete; the game's tone favours the second without punishing the first.

**Tone.** Mythic and melancholy, lit by small jokes. Nobody monologues. Ruins tell most of the
story: every region's architecture is from a different century of the chained-sun era.

---

## 2. World

One seamless map, ~16 km² surface (4 × 4 km), four regions with distinct biomes, plus a small
Depths layer (caverns under the capital, streamed with the surface) for the midpoint. Travel: on
foot, climbing, gliding, the mount (an elk-like **Stag**), fast travel between lit towers and
completed shrines. Real places first: every region has a reason people live (or lived) there.

| # | Region | Size | Biome / visual identity | Ruin style | Weather bias | Dungeon |
|---|--------|------|-------------------------|------------|--------------|---------|
| 1 | **Harrowmere Vale** (start) | 3.5 km² | Temperate pastoral at low sun: dry amber grass, black oaks, hedgerows, slate-roofed stone-and-timber village, lantern posts, sheep and deer | Late era: timber + whitewash, lamplighter shrines | Clear, dawn mist, passing showers | — (tutorial cave "Lanternroot") |
| 2 | **The Greywold** | 4.5 km² | Old-growth mountain forest: moss, ferns, wet rock, mist, canopy light shafts, fallen giant trunks, temple steps in the cliffs (Wukong's Black Wind Mountain is the mood reference) | Early era: moss-swallowed stone temples | Rain, fog, storms | **D1: The Ashen Priory** |
| 3 | **Vellmarsh** | 4 km² | Flooded delta: reed seas, stilt villages, mangrove-like roots, herons, teal/ochre | Middle era: brick aqueducts | Rain, lightning storms | **D2: The Drowned Cistern** |
| 4 | **Aurel, the Ember Capital** | 4 km² | Vast ruined white-stone city half sunk into a gorge, broken chain-pylons, ash-fall, gold/ivory/soot; the Depths open beneath it | First era: colossal | Ash-fall, wind | **D3: The Chain Shaft** (final) |
| U | **The Depths** (under Aurel) | ~1 km² | Lightless caverns, giant fungus, Emberglow veins as the only light | Natural | Dark; spore drifts | Midpoint segment |

**Landmarks per region:** 1 tower (Sefi's cartography towers, 4), 6–9 shrines (30 total), 1
stable, 1–2 settlements with daily life, 1 world boss, 2–3 caves. Main road network connects
the settlements; side roads are broken by ruins to force traversal.

**Streaming:** 512 m chunks, 3 LOD rings; the Depths as a separate chunk set. No loading
screens except initial load and fast travel.

---

## 3. Abilities (the Lantern)

Each ability is taught by Act I and used in every subsequent shrine/dungeon.

| Ability | What it does | Puzzle role | Combat role | Taught |
|---------|--------------|-------------|-------------|--------|
| **Bind** | Attach any two physics objects (glue). Build bridges, rafts, levers, siege-things from parts. Max 20 parts. | Primary builder | Fuse a weapon head to the staff for +dmg/element | Lanternroot cave |
| **Recall** | Rewind one object's motion up to 15 s. | Ride platforms back up; reverse boulders | Return thrown enemy projectiles | Harrowmere Vale |
| **Rise** | Swim upward through any ceiling (≤ 20 m). | Vertical shortcuts; cave exits | Escape from surrounded | Greywold entrance |
| **Kindle** | Light/extinguish lanterns and braziers at range; heats metal. | Light-path puzzles; melt ice; power machines | Set oil pools alight | Harrowmere Vale |
| *Fuse (Bind variant)* | Attach object to weapon/shield/arrow | Element arrows | Core to combat variety | with Bind |

Traversal: climb any surface (stamina-limited, rain slows), glide (Caelum's glider, Act II
start; stamina; rides the weather's wind and the thermals that rise off sun-warmed rock by day,
marked by rising chaff and circling kites, dead at night and under a front), swim, Stag mount (whistle; fast on roads).

---

## 4. Combat

Stamina-gated, lock-on, hit-stop on every connected hit (60 ms light / 120 ms heavy), camera
shake scaled to damage, impact VFX + layered foley. Enemies telegraph: wind-up ≥ 0.5 s with a
colour flash (white = dodge, red = unblockable, gold = parryable). A blow that gets through
staggers the hero 0.5 s (shoved back, attacks locked out, dodge-cancellable after 0.24 s).
Death: the hero collapses face-down, the screen sinks to black ("Fallen"), and they wake at the
last rest point (lamplighter shrines; the start until the first is lit) at full vitality; the
Hollows still standing return to their posts at full health. No currency or XP is lost.

### Stances (the staff — a lamplighter's hooked pole)

| Stance | Fantasy | Light string (L×4) | Heavy (hold) | Special |
|--------|---------|--------------------|--------------|---------|
| **Ward** (default) | Balanced, mobile | thrust, sweep, overhead, spin | Rising overhead smash, hold to charge 3 tiers (stamina 16/22/28, power 1.8/2.4/3.2); **parry** window on the raise (0.25 s): a deflect staggers the attacker 1.3 s and banks tier 1; a blow on the charge breaks it, only the released downswing is armoured | Perfect dodge → 1.5 s time-dilation |
| **Pillar** | Heavy, grounded | slow arcs, each with hyper-armour | Ground slam, AoE knockdown; charges through hits (hyper-armour while charging) | Charging while being hit builds Focus faster |
| **Crane** | Fast, aerial | quick 2-hit flurries, launches | Dive strike from mid-air, long reach | Air-dodge; light attacks keep you airborne |

Focus (builds on hits/perfect dodges, 4 pips) spends on **Varied Combos**: a heavy inserted
mid-string that changes animation by stance. Spells (cooldown + mana):

| Spell | Effect | Source |
|-------|--------|--------|
| **Still** | Immobilise one target 4 s (bosses 1.5 s) | Act I |
| **Many** | 3 lantern-clones, 8 s, each does 30 % dmg | D1 |
| **Become** | Transform into last-defeated elite's form, own moveset, 20 s | D2 |
| **Cloak of Embers** | 6 s damage shield that detonates | Greywold world boss |

### Enemy roster (surface)
Hollow Wisps (fodder), Hollow Soldiers (shield/spear/axe variants), Briar Hounds, Ashen
Archers, Stone Sentinels (shrine guards), Marsh Drowned, Elites (one per archetype, grant
**Become** forms), 4 world bosses. Wildlife (§8) is not an enemy class but predators will
fight anything nearby, including Hollow.

Spear Soldier moveset (each move has one right answer that the others punish): **thrust**
(at spear length; narrow line — strafe, sidestep, dodge on the glint or parry) and **sweep**
(when crowded inside the point or after two thrusts; low wide right-to-left arc with a long
stride, tracks until the release — strafing does not escape it; dodge on the glint, parry, or
leave early). Both share the ember + blade-glint tell; the sweep's tell is a low coil with the
spear wound back to the right.

### Bosses (3–5 phases, mechanic change per phase)

| Boss | Where | P1 | P2 | P3 | P4 | P5 |
|------|-------|----|----|----|----|----|
| **Ashen Knight** (D1) | Ashen Priory | Shield + sword, parryable | Drops shield, two-hander, unblockables | Sets arena alight; Kindle to clear safe lanes | — | — |
| **The Drowned Choir** (D2) | Cistern | 3 singers, each a shield for the others | Arena floods; fight on Bind-rafts | One giant singer; Recall its tidal waves | — | — |
| **Warden Ashka** (final) | Ember | Duel, Ward stance tutorial-mirror | Takes lantern; no abilities | Pell returns it; all abilities | Ember itself fights; arena collapses | Chain-ascent chase, QTE-free climb duel |
| **Warden Ashka** fights at the end of **D3 Chain Shaft**. | | | | | | |
| World bosses ×4 | one per region | 3 phases each | | | | |

---

## 5. Content budget (~30 h)

| Bucket | Items | Hours |
|--------|-------|-------|
| Main story | 12 quests incl. 3 dungeons and cutscenes | **12** |
| Side quests | 4 arcs, 14 quests | **8** |
| Dungeons' optional wings + shrines | 30 shrines × ~10 min, + 1 h dungeon side wings | **6** |
| Exploration / secrets / world bosses | 4 world bosses (0.4 h), 4 towers, caves, Pell's memories (40), hidden ruins | **4** |
| **Total** | | **30** |

### Main quest list (12 h)
| # | Quest | Hours | Objective → Reward | Why it exists |
|---|-------|-------|-------------------|---------------|
| M1 | The Last Lamp | 0.5 | Escape Harrowmere's burning → Lantern | Hook, establishes stakes |
| M2 | Lanternroot | 0.75 | Tutorial cave; learn Bind, Kindle → Pell joins | Teach abilities |
| M3 | A Light on the Hill | 0.75 | First tower; learn Recall → map | Open the world |
| M4 | The Greywold Road | 1.0 | Reach the Priory through the forest; learn Rise, Ward stance | First combat gate |
| M5 | **D1 Ashen Priory** | 1.5 | Boss: Ashen Knight → Still + Many, Ember-key 1 | Act I climax |
| M6 | What Ashka Wants | 0.75 | Cutscene + chase back through the Vale; Caelum's envoy → glider | Reveal antagonist |
| M7 | River Mother | 1.0 | Vellmarsh: earn Oru's trust (3 tasks); Idris's raiders | Introduce Oru, Idris |
| M8 | **D2 Drowned Cistern** | 1.5 | Boss: Drowned Choir → Become, Pillar stance, key 2 | |
| M9 | The Taking | 0.75 | Ashka ambush at Aurel's gate; lantern lost; fall into the Depths | Midpoint |
| M10 | Lightless | 1.0 | Depths with no abilities; Oru's daughter; Pell returns the lantern | Low point, companion payoff |
| M11 | **D3 Chain Shaft** | 1.5 | Gathered allies; descent dungeon, Crane stance; boss: Ashka, 5 phases | Climax |
| M12 | Dusk or Dawn | 0.25 | Choice + epilogue | Ending |
| | **Total** | **12** | | |

### Side arcs (8 h)
- **Idris's Debt** (4 quests, 2.5 h): the bandit general's raiders in Vellmarsh; trust/betrayal choice.
- **Oru's Daughter** (3 quests, 2 h): track the Hollow daughter through the marsh and Depths.
- **Sefi's Towers** (4 quests, 1.5 h): one memory per tower; ending choice.
- **Pell Remembers** (3 quests, 2 h): recover memory-shards; determines epilogue line.
(Caelum appears in M6/M11 only; his court is cut with the sky layer.)

### Shrine design rules
Each shrine: one ability focus, one twist, 8–15 min. Four families: Bind-construction,
Recall-timing, Rise-vertical, Kindle-light-path; plus combat trials (Stone Sentinel duels)
and "blessing" shrines found by solving an overworld riddle. Reward: Ember shard (3 = +heart
or +stamina wheel). 30 shrines: Vale 6, Greywold 9, Vellmarsh 8, Aurel 7. No two shrines share a layout.

---

## 6. Style guide

**Overall: realistic, Black Myth: Wukong is the visual reference** (Zelda only for
exploration). Photoreal PBR surfaces (2K+ Poly Haven / ambientCG), physically plausible light,
dense foliage, rocks, moss, ruins. Colour-graded toward a warm low sun with desaturated,
slightly green-gold shadows and film grain, like Wukong. No cartoon, no cel shading, no
low-poly, no flat colours, never a capsule, cube or blocky stand-in on screen. The sun sits
low in the Long Dusk (8–25° over the day/night cycle; nights are real and dark-blue).
Volumetric fog in valleys, god-rays through canopy, DOF only in cinematic moments.

**Reference images in words.**
1. *Harrowmere at dusk:* a slate-roofed stone village on a hill, windows lit, smoke from
   chimneys, lantern posts along a rutted dirt road, amber grass bending in wind, sheep
   drifting across a slope, the broken sky-chain pylon a kilometre away catching the light.
2. *Greywold interior:* trunks 3 m wide, moss carpets, wet rock, temple steps climbing into
   fog, light shafts, a Hollow Soldier standing still with an ember-glow in its chest.
3. *Vellmarsh storm:* reed sea flattened by wind, lightning lighting stilt-huts, herons
   lifting off, rain streaks on the camera.
4. *Aurel:* white-stone colossi half buried in a gorge, ash falling like snow, the chain
   pylons rising out of haze.
5. *Combat frame:* Wren mid-slam with the staff, dust ring, hit-stop freeze, camera shake,
   sparks from the staff head, enemy stagger with ember particles.

**Materials:** everything PBR (albedo/normal/roughness/AO; height for terrain). Terrain uses
triplanar blended layers (grass, dirt, rock, moss, snow, sand) from CC0 sources (ambientCG /
Poly Haven). Foliage: wind shader with trunk sway + leaf flutter; grass as GPU-instanced
multimesh with distance fade. Water: planar reflection + screen-space refraction, depth fog,
foam at edges, shoreline waves. Weather: rain/snow particles in camera-follow volume, wet-ness
(roughness drop) on surfaces, lightning flashes drive directional light.

**Post:** ACES tonemap, bloom (soft, threshold 1.0), SSAO, SSIL, SSR, SDFGI (or baked VoxelGI
per region), slight vignette, colour grade per region, DOF in cinematic moments, film grain
like Wukong. Performance: Forward+ at max presets; 60 fps on RTX 4070-class at 1440p, 30+ fps
on RTX 4050 at 1080p with FSR 2; a quality slider instead of cutting visuals.

**Characters:** realistic human proportions, a detailed rigged humanoid with a face and eyes,
subsurface skin, moving cloth and hair, real blended animations (Mixamo is the floor; prefer
better CC0/CC-BY realistic models); root-motion attacks; foot IK; look-at IK. Weapon: a staff
with real geometry and PBR (worn metal, lacquered wood, cloth wrap), swing trails, impact VFX.
Hollow: grey, cracked, ember-glow in chest; silhouettes readable at 50 m.

**UI:** minimal. Health bar top-left (segmented hearts → bar on wheel), stamina wheel near the
player on use, focus pips under health, spell wheel on hold, no minimap (compass strip top).
Font: a clean humanist sans (CC0/OFL). All text readable at 1080p from a couch.

**Audio direction (for milestone 5):** strings + woodwind + processed lantern-glass textures;
region themes, combat layers that add a percussion stem per boss phase.

---

## 7. Milestone plan mapped to this doc

1. **Vertical slice = Harrowmere Vale** (2 km² sub-area around the village and the first
   tower): Ward stance full, Ashen Knight brought forward as a slice boss in a Priory
   antechamber, one Bind shrine (the *Shrine of Binding*, sealed under a carved lid in the
   floor of the watchtower keep on the western spur; it opens once Bind is learned in
   Lanternroot), climb + glide, day/night, weather, wildlife and villagers,
   final visuals.
2. Core systems (all §3, §4, inventory, cooking, Pell, Stag, save, map, UI, options, input).
3. World blockout for all §2 regions + Depths, streaming, weather, towers, roads.
4. Content per §5 in player order: M1→M12, side arcs, shrines region by region.
5. Polish.

Hour budget changes require editing §5 and the matching PROGRESS.md counter.

---

## 8. The living world (as important as the look)

- **Time and weather:** full day/night cycle with changing light; weather fronts that roll in
  (rain, fog, storms) with wind that drives grass and tree sway; wet surfaces in rain; on hot still
  afternoons thermals rise off sun-warmed rock and dust devils wander over the dry meadow.
- **Wildlife:** herds (sheep, deer) that graze, drift and flee as a group; predators (wolves)
  that hunt them at dusk; birds that scatter when the player approaches; insects and moths
  in lamplight; campfires draw wildlife at night.
- **People:** NPCs with daily schedules (wake, work, eat, sleep), who shelter from rain, react
  to the player and to the time of day; villages with sound and movement (smoke, laundry,
  doors, animals in pens, a farm dog -- Edda's collie Brack -- that potters on the green,
  runs out barking to meet the player and keeps her door at night and in rain).
- **Roads:** ambient events — travellers, merchants with carts, Hollow ambushes, animals
  crossing.
- **Reactive world:** grass flattens under feet, footprints in mud/snow, water ripples,
  foliage brushes aside, ember particles from fires.
- **Soundscape:** region ambience, weather, wildlife, distance-attenuated village noise.

Screenshot gate asks two questions every session: could this be a Wukong screenshot, and
does a 10-second clip here look like a living place?
