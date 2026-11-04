class_name BossGrowth
extends RefCounted
## The reusable part of every boss: its phases as data, and the GROWTH MOMENT between them.
## Owner rule (2026-11-03): a boss starts well above human size (~2.5x the hero), grows at each
## phase change and ends around 2-2.5x its starting size. A phase change is never a pop: the
## boss is invulnerable, roars, the arena shakes (camera shake, dust thrown up round it, a
## short hit-stop flash) and the body scales up smoothly over ~2 s while embers burst out.
##
## A phase is a Dictionary:
##   scale     body size (1 = a soldier, the hero is ~0.92 of that)
##   tempo     brain time scale (wind-ups shorten a little; bigger bodies still stride slower)
##   damage    multiplier on every blow
##   attacks   Array[String] of the moves in its pool this phase (bots, DESIGN.md)
##   mechanic  one line: what changes this phase
## The boss owns the state machine (Idle -> Stalk -> Telegraph/WINDUP -> Attack/STRIKE ->
## Recover, + Grow); it calls start() when it enters Grow, then tick() each frame and applies
## the returned size until growing() is false.

const GROW_T := 2.0      # real seconds the body takes to reach its new size
const DUST_EVERY := 0.16 # s between dust bursts thrown up round its feet
const EMBER_EVERY := 0.09   # s between seams splitting open (EmberBurst), busiest mid-growth
const GRIT_EVERY := 0.22    # s between stones shedding grit from their crowns (GritFall)
const GRIT_REACH := 34.0    # m: stones farther from the boss than this stay still

var phases: Array = []
var from_scale := 1.0
var to_scale := 1.0
var t := -1.0            # s into the growth, -1 when not growing
var dust_puffs := 0      # bots: bursts spawned during growths
var samples: Array[float] = []   # bots: the size at each tick of the last growth
var ember_bursts := 0   # bots: seams that spat fire during growths
var grit_falls := 0     # bots: stones that shed grit during growths
## The boss sets these: seam_fn(i) -> [world pos, outward dir] of armour seam i (seam_n of
## them); grit_from: [[top, width, height], ...] of the arena's standing stones.
var seam_fn := Callable()
var seam_n := 0
var grit_from: Array = []
var _dust_t := 0.0
var _ember_t := 0.0
var _grit_t := 0.0
var _grit_used: Dictionary = {}

func _init(p: Array) -> void:
	phases = p

func phase_data(n: int) -> Dictionary:
	return phases[clampi(n - 1, 0, phases.size() - 1)]

func scale_of(n: int) -> float:
	return float(phase_data(n)["scale"])

func start(cur: float, n: int) -> void:
	from_scale = cur
	to_scale = scale_of(n)
	t = 0.0
	_dust_t = 0.0
	_ember_t = 0.0
	_grit_t = 0.1
	_grit_used.clear()
	samples.clear()

func growing() -> bool:
	return t >= 0.0

func stop() -> void:
	t = -1.0

## Fraction of the growth done, eased (slow start, a heave through the middle, settle).
func progress() -> float:
	if t < 0.0:
		return 1.0
	var u := clampf(t / GROW_T, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)

## Advances the growth and does the arena's part (shake, dust); returns the size to apply.
func tick(delta: float, boss: Node3D, player: Player, foot_r: float) -> float:
	if t < 0.0:
		return to_scale
	t += delta
	var s := lerpf(from_scale, to_scale, progress())
	samples.append(s)
	if player != null:
		# keep the trauma up through the heave (it decays 2.2/s), strongest mid-growth
		player.add_shake(delta * (2.2 + 1.6 * sin(PI * clampf(t / GROW_T, 0.0, 1.0))))
	_dust_t -= delta
	if _dust_t <= 0.0 and boss.get_parent() != null:
		_dust_t = DUST_EVERY
		dust_puffs += 1
		var a := randf() * TAU
		var r := foot_r * randf_range(0.9, 2.2)
		var at := boss.global_position + Vector3(cos(a), 0.05, sin(a)) * r
		ImpactFX.spawn(boss.get_parent(), at, Vector3.UP, "dirt", 1.4 + s * 0.2)
	var heave := sin(PI * clampf(t / GROW_T, 0.0, 1.0))
	# the plate can't hold the body swelling under it: seams split and spit fire
	_ember_t -= delta * (0.5 + heave)
	if _ember_t <= 0.0 and seam_fn.is_valid() and seam_n > 0 and boss.get_parent() != null:
		_ember_t = EMBER_EVERY
		ember_bursts += 1
		var sm: Array = seam_fn.call(randi() % seam_n)
		EmberBurst.spawn(boss.get_parent(), sm[0], sm[1], s)
	# the ground heaves under the standing stones: grit and dust shaken off their crowns
	_grit_t -= delta
	if _grit_t <= 0.0 and not grit_from.is_empty() and boss.get_parent() != null:
		_grit_t = GRIT_EVERY
		var pick := -1
		var best := INF
		for k in 4:
			var j := randi() % grit_from.size()
			var top: Vector3 = grit_from[j][0]
			var d := Vector2(top.x - boss.global_position.x, top.z - boss.global_position.z).length()
			var score := d + (40.0 if _grit_used.has(j) else 0.0) + randf() * 6.0
			if d < GRIT_REACH and score < best:
				best = score
				pick = j
		if pick >= 0:
			_grit_used[pick] = true
			grit_falls += 1
			var c: Array = grit_from[pick]
			GritFall.spawn(boss.get_parent(), c[0], float(c[1]), float(c[2]))
	if t >= GROW_T:
		t = -1.0
		return to_scale
	return s
