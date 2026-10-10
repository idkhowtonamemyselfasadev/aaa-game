# EMBERFALL — Design Document (milestone 0)

Working title: **Emberfall**. Third-person open-world action-adventure. Exploration and
physics-ability puzzles in the spirit of *Tears of the Kingdom*; heavy, readable stance-based
melee in the spirit of *Black Myth: Wukong*. Target length ~100 h. Engine: Godot 4.7 (Forward+).

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
- **Caelum**, the sky-island boy king, twelve years old and ruling a court of automatons. Arc:
  learns to come down.

**Structure.**
- *Act I (Surface, ~10 h):* Harrowmere burns. Wren takes the lantern, meets Pell, learns the
  four abilities across the Greywold and Harrowmere Vale, lights the first tower, defeats the
  Ashen Knight (first dungeon). Learns the Ember is in the Depths and Ashka is hunting it.
- *Act II (Breadth, ~17 h):* Four regions, four dungeons, four Ember-keys. Each region's
  dungeon boss is one of Ashka's former guardians. Wren gains the sky (Caelum's gliders) and the
  Depths (Oru's route). Pell starts forgetting. Idris's betrayal / redemption. Midpoint:
  Ashka takes the lantern and Wren falls into the Depths without it — a 90-minute segment
  with no abilities, learning the Depths' own light-rules.
- *Act III (Convergence, ~8 h):* Wren reclaims the lantern from Ashka's citadel in the sky,
  descends the shaft under the capital with every ally, fights Ashka (5 phases) at the Ember,
  then chooses: re-chain it (the sun returns, the sky islands fall, the Hollow — Pell included —
  die) or let it burn free (dusk remains but the world learns to live in it; Pell stays).
  Both endings are complete; the game's tone favours the second without punishing the first.

**Tone.** Mythic and melancholy, lit by small jokes. Nobody monologues. Ruins tell most of the
story: every region's architecture is from a different century of the chained-sun era.

---

## 2. World

One seamless map, ~64 km² surface (8 × 8 km), plus a sky layer and a Depths layer streamed
with the surface. Travel: on foot, climbing, gliding, the mount (an elk-like **Stag**),
fast travel between lit towers and completed shrines.

| # | Region | Size | Visual identity | Century / ruin style | Weather bias | Dungeon |
|---|--------|------|-----------------|----------------------|--------------|---------|
| 1 | **Harrowmere Vale** (start) | 6 km² | Temperate dusk pastoral: amber grass, black-oak hedgerows, slate-roofed villages, lantern posts everywhere, long shadows | Late era: timber + whitewash, lamplighter cult shrines | Clear, mist at dawn | — (tutorial cave "Lanternroot") |
| 2 | **The Greywold** | 8 km² | Old-growth forest, moss, grey-green palette, canopy light shafts, giant fallen trunks as bridges | Early era: moss-swallowed stone circles | Rain, fog | **D1: The Ashen Priory** |
| 3 | **Vellmarsh** | 7 km² | Flooded delta: reed seas, stilt villages, bioluminescent water at dusk, teal/ochre | Middle era: brick aqueducts | Rain, lightning storms | **D2: The Drowned Cistern** |
| 4 | **Shale Barrens** | 9 km² | Red badlands, hoodoos, crashed sky-fleet hulls as settlements, dust and sodium-orange light | Sky-fleet wrecks (iron, canvas) | Sandstorms, clear nights | **D3: The Fallen Dreadnought** |
| 5 | **Frostmere Reach** | 8 km² | Glacial fjords, blue ice, black rock, aurora, snow with wind-driven drifts | Chained-sun era watchtowers in ice | Blizzard, aurora | **D4: The Glass Monastery** |
| 6 | **The Ember Capital (Aurel)** | 6 km² | Vast ruined white-stone city, half sunk, the broken chain-pylons as landmarks, gold/ivory/soot | First era: colossal | Ash-fall | **D6: The Chain Shaft** (final) |
| 7 | **Thornhollow** | 6 km² | Cursed heath; black briar, red skies, Hollow concentration; the "hard" region | Mixed, corrupted | Red fog | World bosses only |
| 8 | **Sunward Coast** | 6 km² | Cliffs, sea-stacks, the only place the sun is nearly up: warm light, wildflowers | Fishing villages | Clear | Side content hub |
| S | **The Shelf (sky layer)** | ~40 islands | Floating temple islands, pale stone, chains trailing into cloud, extreme vertical, god-rays | Chained-sun era | Wind, cloud layer | **D5: Caelum's Orrery** |
| U | **The Depths** | mirrors surface | Lightless caverns, giant fungus, Emberglow veins (orange) as the only light, inverted ruins | None (natural) | Dark; spore storms | Act II midpoint segment |

**Landmarks per region:** 1 tower (Sefi's cartography towers, 8 surface + 1 sky = 9), 12–14
shrines, 1 stable, 2–3 settlements, 1 world boss, caves with Depths entrances (chasms). Main
road network connects all stables; side roads are deliberately broken by ruins to force
traversal.

**Streaming:** 512 m chunks, 3 LOD rings; sky and Depths as separate chunk sets at ±400 m.
No loading screens except initial load and fast travel.

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

Traversal: climb any surface (stamina-limited, rain slows), glide (Caelum's paraglider, Act II
start; stamina), swim, Stag mount (whistle; fast on roads).

---

## 4. Combat

Stamina-gated, lock-on, hit-stop on every connected hit (60 ms light / 120 ms heavy), camera
shake scaled to damage, impact VFX + layered foley. Enemies telegraph: wind-up ≥ 0.5 s with a
colour flash (white = dodge, red = unblockable, gold = parryable).

### Stances (the staff — a lamplighter's hooked pole)

| Stance | Fantasy | Light string (L×4) | Heavy (hold) | Special |
|--------|---------|--------------------|--------------|---------|
| **Ward** (default) | Balanced, mobile | thrust, sweep, overhead, spin | Planted thrust; **parry** window on heavy start (0.25 s) | Perfect dodge → 1.5 s time-dilation |
| **Pillar** | Heavy, grounded | slow arcs, each with hyper-armour | Ground slam, AoE knockdown; chargeable 3 tiers | Charging while being hit builds Focus faster |
| **Crane** | Fast, aerial | quick 2-hit flurries, launches | Dive strike from mid-air, long reach | Air-dodge; light attacks keep you airborne |

Focus (builds on hits/perfect dodges, 4 pips) spends on **Varied Combos**: a heavy inserted
mid-string that changes animation by stance. Spells (cooldown + mana):

| Spell | Effect | Source |
|-------|--------|--------|
| **Still** | Immobilise one target 4 s (bosses 1.5 s) | Act I |
| **Many** | 3 lantern-clones, 8 s, each does 30 % dmg | D2 |
| **Become** | Transform into last-defeated elite's form, own moveset, 20 s | D3 |
| **Cloak of Embers** | 6 s damage shield that detonates | D4 |

### Enemy roster (surface)
Hollow Wisps (fodder), Hollow Soldiers (shield/spear/axe variants), Briar Hounds, Ashen
Archers, Stone Sentinels (shrine guards), Sky Automatons, Marsh Drowned, Ice Hewers, Elites
(one per archetype, grant **Become** forms), 8 world bosses.

### Bosses (3–5 phases, mechanic change per phase)

| Boss | Where | P1 | P2 | P3 | P4 | P5 |
|------|-------|----|----|----|----|----|
| **Ashen Knight** (D1) | Ashen Priory | Shield + sword, parryable | Drops shield, two-hander, unblockables | Sets arena alight; Kindle to clear safe lanes | — | — |
| **The Drowned Choir** (D2) | Cistern | 3 singers, each a shield for the others | Arena floods; fight on Bind-rafts | One giant singer; Recall its tidal waves | — | — |
| **Commodore Idris's Engine** (D3) | Dreadnought | Automaton boarding | Engine core, heat vents (Kindle off) | Ship tilts — climbing fight | Idris himself, duel | — |
| **Abbess of Glass** (D4) | Glass Monastery | Mirror clones (Many counters) | Freezes floor, Crane only | Shatters; Rise through ceilings to chase | Glass storm, parry rhythm | — |
| **Caelum's Guardian** (D5) | Orrery | Orbit platforms | Gravity flips | Open sky, glide combat | — | — |
| **Warden Ashka** (final) | Ember | Duel, Ward stance tutorial-mirror | Takes lantern; no abilities | Pell returns it; all abilities | Ember itself fights; arena collapses | Chain-ascent chase, QTE-free climb duel |
| World bosses ×8 | one per region | 3 phases each; Thornhollow's has 4 | | | | |

---

## 5. Content budget (~100 h)

| Bucket | Items | h each | Hours |
|--------|-------|--------|-------|
| Main story quests | 24 quests, 6 dungeons (1.5 h each), cutscenes | — | **35** |
| Major side quests (5 arcs × 4–6 quests) | 26 quests | ~1 | **25** |
| Shrines | 110 shrines (12–14 per region + 10 sky) | 0.18 | **20** |
| Mini-dungeons / caves with a goal | 20 | 0.25 | **5** |
| World bosses | 8 | 0.4 | **3** |
| Collectibles (lanterns 120, Pell's memories 60, armour sets 12) | — | — | **6** |
| Towers (9), stables (8), settlements (18 with jobs/cooking) | — | — | **4** |
| Secrets / hidden endings / Depths exploration | — | — | **2** |
| **Total** | | | **100** |

### Main quest list (35 h)
| # | Quest | Hours | Objective → Reward | Why it exists |
|---|-------|-------|-------------------|---------------|
| M1 | The Last Lamp | 0.5 | Escape Harrowmere's burning → Lantern | Hook, establishes stakes |
| M2 | Lanternroot | 1.0 | Tutorial cave; learn Bind, Kindle → Pell joins | Teach abilities |
| M3 | A Light on the Hill | 1.0 | First tower; learn Recall → map | Open the world |
| M4 | The Greywold Road | 1.5 | Reach Priory; learn Rise, Ward stance | First combat gate |
| M5 | **D1 Ashen Priory** | 1.5 | Boss: Ashen Knight → Still spell, Ember-key 1 | Act I climax |
| M6 | What Ashka Wants | 1.0 | Cutscene + chase through Vale | Reveal antagonist |
| M7 | River Mother | 1.5 | Vellmarsh: earn Oru's trust (3 tasks) | Introduce Oru |
| M8 | **D2 Drowned Cistern** | 1.5 | Boss: Drowned Choir → Many, key 2 | |
| M9 | Dust and Iron | 1.5 | Barrens: Idris's camp, prove yourself | Introduce Idris |
| M10 | **D3 Fallen Dreadnought** | 1.5 | Boss: Idris's Engine → Become, key 3, Pillar stance | |
| M11 | Up | 1.0 | Caelum's envoy; first flight → glider, sky access | Opens sky |
| M12 | The Court of Gears | 1.5 | Sky politics; 3 island trials | Caelum's arc |
| M13 | **D5 Caelum's Orrery** | 1.5 | Boss: Guardian → key 5 (out of order on purpose), Crane stance | |
| M14 | Cold Vigil | 1.5 | Frostmere: find the monastery through blizzard | |
| M15 | **D4 Glass Monastery** | 1.5 | Boss: Abbess → Cloak of Embers, key 4 | |
| M16 | The Taking | 1.0 | Ashka ambush; lantern lost; fall | Midpoint |
| M17 | Lightless | 1.5 | Depths with no abilities; Oru's daughter | Low point |
| M18 | Pell's Light | 1.0 | Pell finds you; partial lantern returns | Companion payoff |
| M19 | Gathering | 2.0 | Recruit allies (Idris, Oru, Caelum, Sefi) — 4 short quests | Convergence |
| M20 | The Citadel in the Sky | 2.0 | Assault Ashka's citadel, reclaim lantern | Act III opening |
| M21 | Aurel | 1.5 | Cross the ruined capital with allies | Spectacle |
| M22 | **D6 Chain Shaft** | 2.0 | Descent dungeon, all abilities tested | |
| M23 | The Ember | 1.5 | Boss: Ashka, 5 phases | Climax |
| M24 | Dusk or Dawn | 0.5 | Choice + epilogue | Ending |
| | cutscenes/travel/dialogue overhead | 2.5 | | |
| | **Total** | **35** | | |

### Side arcs (25 h)
- **Idris's Fleet** (6 quests, 6 h): salvage the sky-fleet; ends with trust/betrayal choice.
- **Oru's Daughter** (5 quests, 5 h): track the Hollow daughter through the marsh and Depths.
- **Sefi's Towers** (5 quests, 4 h): one memory per restored tower cluster; ending choice.
- **Pell Remembers** (6 quests, 5 h): recover memory-shards; determines epilogue line.
- **The Sunward Guild** (4 quests, 5 h): Sunward Coast's lighthouse network; unlocks the
  Stag's armour and the Coast world boss.

### Shrine design rules
Each shrine: one ability focus, one twist, 8–15 min. Four families: Bind-construction,
Recall-timing, Rise-vertical, Kindle-light-path; plus combat trials (Stone Sentinel duels)
and "blessing" shrines found by solving an overworld riddle. Reward: Ember shard (4 = +heart
or +stamina wheel). No two shrines share a layout.

---

## 6. Style guide

**Overall:** painterly realism. Real PBR surfaces, physically plausible light, but colour-graded
toward a warm, low sun — think a 2024 console open world at golden hour that never ends. Long
soft shadows everywhere; the sun sits at 8–15° above the horizon in all surface regions
except the Sunward Coast (25°). Sky: pale apricot near the sun, deep teal overhead, visible
cracked-sky islands as silhouettes. Volumetric fog in valleys, god-rays through canopy.

**Reference images in words.**
1. *Harrowmere at dusk:* a slate-roofed village on a hill, every window lit, lantern posts
   along a dirt road, amber grass bending in wind, the broken sky-chain pylon a kilometre away
   catching the last light.
2. *Greywold interior:* trunks 6 m wide, moss carpets, light shafts through fog, a stone circle
   half swallowed by roots, a Hollow Soldier standing still with an ember-glow in its chest.
3. *Vellmarsh storm:* reed sea flattened by wind, lightning lighting stilt-huts, teal
   bioluminescence under the water line, rain streaks on the camera.
4. *Shale Barrens:* red hoodoos, a dreadnought hull canted in dust, sodium-orange light,
   sandstorm wall on the horizon.
5. *The Shelf:* standing on a floating island edge; cloud sea below; chains trailing off into
   nothing; god-rays; the surface far below in haze.
6. *Combat frame:* Wren in Pillar stance mid-slam, dust ring, hit-stop freeze, camera shake,
   sparks from the staff head, enemy stagger with ember particles.

**Materials:** everything PBR (albedo/normal/roughness/AO; height for terrain). Terrain uses
triplanar blended layers (grass, dirt, rock, moss, snow, sand) from CC0 sources (ambientCG /
Poly Haven). Foliage: wind shader with trunk sway + leaf flutter; grass as GPU-instanced
multimesh with distance fade. Water: planar reflection + screen-space refraction, depth fog,
foam at edges, shoreline waves. Weather: rain/snow particles in camera-follow volume, wet-ness
(roughness drop) on surfaces, lightning flashes drive directional light.

**Post:** ACES tonemap, bloom (soft, threshold 1.0), SSAO, SSIL, SDFGI (or baked VoxelGI per
region if SDFGI costs too much), glow, slight vignette, colour grade LUT per region, DOF only
in cutscenes, film grain very low.

**Characters:** stylised-realistic proportions (7.5 heads), cloth with secondary motion,
Mixamo-licensed humanoid rig + custom blend trees; root-motion attacks; foot IK; look-at IK.
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
   antechamber, one Bind shrine, climb + glide, day/night, final visuals.
2. Core systems (all §3, §4, inventory, cooking, Pell, Stag, save, map, UI, options, input).
3. World blockout for all §2 regions + Shelf + Depths, streaming, weather, towers, roads.
4. Content per §5 in player order: M1→M24, side arcs, shrines region by region.
5. Polish.

Hour budget changes require editing §5 and the matching PROGRESS.md counter.
