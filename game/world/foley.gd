class_name Foley
extends Node3D
## Close-up sounds of the fight and the body, synthesised at load like the Soundscape (no
## sample files): staff swishes timed to each strike (a light whip, a deep whoom on the
## heavy), impacts by what was struck (straw post, the Hollows' ashen stone, wood), a ringing
## clang on a parry, a soil-and-grit thump when the heavy meets the ground, a cloth whoosh
## on a dodge and a low swelling breath on a perfect one, a dull blow when the hero is
## struck, the soldier's spear hissing through its thrust, and footfalls on grass, on the
## keep's gritty floor and splashing in wet ground. During the perfect-dodge slow motion the
## whole mix slows and deepens with time. Bots read `played` (sound name -> count).

const RATE := 22050

var world: Node3D
var player: Player
var weather: Weather
var played := {}          # sound name -> times played (bots)
var build_ms := 0
var hero_steps := 0       # footfalls of the hero alone (bots)

var _rng := RandomNumberGenerator.new()
var _s := {}              # sound name -> Array[AudioStreamWAV] variants
var _pool: Array[AudioStreamPlayer3D] = []
var _pending: Array = []  # [seconds left, name, position node or Vector3, db, pitch]
var _ruin := Vector3.INF

func _ready() -> void:
	_rng.seed = 9113
	var t0 := Time.get_ticks_msec()
	_s["swish"] = [_make_swish(0.26, 900.0, 2600.0), _make_swish(0.24, 1100.0, 3000.0), _make_swish(0.3, 800.0, 2300.0)]
	_s["whoom"] = [_make_swish(0.5, 260.0, 1100.0, 0.6)]
	_s["spear"] = [_make_swish(0.2, 1500.0, 4200.0)]
	_s["straw"] = [_make_hit(140.0, 0.09, 0.55, 1800.0), _make_hit(120.0, 0.1, 0.6, 1500.0)]
	_s["stone"] = [_make_hit(95.0, 0.14, 0.45, 3200.0, 0.5), _make_hit(110.0, 0.12, 0.4, 3600.0, 0.5)]
	_s["wood"] = [_make_hit(220.0, 0.07, 0.25, 2500.0, 0.0, 640.0)]
	_s["body"] = [_make_hit(80.0, 0.16, 0.3, 900.0)]
	_s["boom"] = [_make_hit(55.0, 0.35, 0.15, 400.0)]
	_s["clang"] = [_make_clang(610.0), _make_clang(680.0)]
	_s["slam"] = [_make_slam()]
	_s["dodge"] = [_make_swish(0.32, 400.0, 1400.0, 0.9), _make_swish(0.3, 450.0, 1500.0, 0.9)]
	_s["perfect"] = [_make_perfect()]
	_s["step_grass"] = [_make_step(0), _make_step(0), _make_step(0), _make_step(0)]
	_s["step_grit"] = [_make_step(1), _make_step(1), _make_step(1)]
	_s["step_wet"] = [_make_step(2), _make_step(2), _make_step(2)]
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0
		add_child(p)
		_pool.append(p)
	build_ms = Time.get_ticks_msec() - t0
	if world and world.has_node("Flora"):
		_ruin = world.get_node("Flora").ruin_site

## Wires the hero's fight and body, the soldiers' spears and every walker's footfalls.
func hook(p: Player, soldiers: Array, trample: Node) -> void:
	player = p
	if p.combat:
		p.combat.swing_started.connect(_on_swing)
		p.combat.hit_landed.connect(_on_hit)
		p.combat.parried.connect(func(_a: Node) -> void: _play("clang", p.global_position + Vector3.UP * 1.4, 0.0))
		p.combat.charge_tier.connect(func(n: int) -> void: _play("clang", p.combat.tip_position(), -20.0 + 3.0 * n, 1.6 + 0.15 * n))
		p.combat.slammed.connect(func(at: Vector3, power: float) -> void: _play("slam", at, -2.0 + 2.0 * power))
	p.dash_started.connect(func() -> void: _play("dodge", p.global_position + Vector3.UP, -8.0))
	p.dodged.connect(func(perfect: bool) -> void:
		if perfect:
			_play("perfect", p.global_position + Vector3.UP, -3.0))
	p.hurt.connect(func(_amt: float) -> void: _play("body", p.global_position + Vector3.UP * 1.1, -1.0))
	for sol: Node in soldiers:
		if sol.has_signal("struck"):
			sol.struck.connect(func(_r: String) -> void:
				_play("spear", (sol as Node3D).global_position + Vector3.UP * 1.3, -6.0))
	if trample and trample.has_signal("footfall"):
		trample.footfall.connect(_on_footfall)

func _process(delta: float) -> void:
	# the perfect-dodge slow motion slows and deepens every sound with it
	AudioServer.playback_speed_scale = clampf(Engine.time_scale, 0.2, 1.0)
	for i in range(_pending.size() - 1, -1, -1):
		var e: Array = _pending[i]
		e[0] -= delta
		if e[0] <= 0.0:
			_pending.remove_at(i)
			var at: Vector3 = e[2].call() if e[2] is Callable else e[2]
			_play(e[1], at, e[3], e[4])

# ---------------------------------------------------------------- events

## The staff's swish starts just before the strike window so its peak meets the blow.
func _on_swing(step: int) -> void:
	var c := player.combat
	var atk: Dictionary = StaffCombat.HEAVY if step < 0 else StaffCombat.STRING[step]
	var lead := float(atk.dur) * float(atk.hit[0]) * 0.8
	var heavy := step < 0
	var nm := "whoom" if heavy else "swish"
	var db := -4.0 if heavy else -7.0 + 2.0 * (float(StaffCombat.POWER[step]) - 1.0)
	_pending.append([lead, nm, func() -> Vector3: return c.tip_position(), db, _rng.randf_range(0.92, 1.08)])

func _on_hit(target: Node, point: Vector3, power: float) -> void:
	var kind = target.get("impact_kind")
	var nm: String = kind if kind in ["straw", "stone", "wood"] else "wood"
	_play(nm, point, -3.0 + 4.0 * (power - 1.0), lerpf(1.08, 0.85, clampf((power - 1.0) / 2.0, 0.0, 1.0)))
	if power >= 1.5:   # the big blows carry a low boom under the crack
		_play("boom", point, -8.0 + 3.0 * power)

func _on_footfall(w: Node3D, at: Vector3, speed: float) -> void:
	var nm := "step_" + surface_at(at)
	var db := lerpf(-20.0, -12.0, clampf(speed / 6.0, 0.0, 1.0))
	if w != player:
		db -= 3.0
	else:
		hero_steps += 1
	_play(nm, at + Vector3.UP * 0.05, db)

## What a foot meets at `at`: "grit" on the keep floor, "wet" in a pool or soaked ground,
## else "grass".
func surface_at(at: Vector3) -> String:
	if _ruin != Vector3.INF and Vector2(at.x - _ruin.x, at.z - _ruin.z).length() < 3.6:
		return "grit"
	if weather and (weather.pool_at(at.x, at.z) or weather.wet_at(at.x, at.z) > 0.45):
		return "wet"
	return "grass"

func _play(nm: String, at: Vector3, db: float, pitch := 1.0) -> void:
	var vs: Array = _s.get(nm, [])
	if vs.is_empty():
		return
	var p: AudioStreamPlayer3D = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[_rng.randi() % _pool.size()]
	p.stream = vs[_rng.randi() % vs.size()]
	p.global_position = at
	p.volume_db = db + _rng.randf_range(-1.5, 1.0)
	p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	p.play()
	played[nm] = int(played.get(nm, 0)) + 1

# ---------------------------------------------------------------- synthesis

func _wav(x: PackedFloat32Array, gain := 0.89) -> AudioStreamWAV:
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var g := gain / peak
	var b := PackedByteArray()
	b.resize(x.size() * 2)
	for i in x.size():
		b.encode_s16(i * 2, int(clampf(x[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = b
	return s

## A swish: noise through a two-pole band filter whose centre sweeps up to `f1` at the
## peak (the staff at full speed) and back down, under a fast-in slow-out envelope. `body`
## adds a low rumble for heavy or cloth-like passes.
func _make_swish(dur: float, f0: float, f1: float, body := 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var lo := 0.0
	var bp := 0.0
	var v := 0.0
	var br := 0.0
	for i in n:
		var k := float(i) / n
		var e := pow(sin(PI * pow(k, 0.7)), 2.0)
		var f := lerpf(f0, f1, sin(PI * pow(k, 0.7)))
		var w := _rng.randf() * 2.0 - 1.0
		# state-variable band-pass, q ~ 1.4
		var g := 2.0 * sin(PI * f / RATE)
		lo += g * bp
		var hi := w - lo - 0.7 * bp
		bp += g * hi
		br = br * 0.97 + w * 0.1
		v = bp * e + body * br * e * e * 2.0
		x[i] = v
	return _wav(x, 0.8)

## An impact: a pitched body thump (sine dropping from f0*1.8 to f0) for `tdur`, a noise
## crack of `crack` amount low-passed at `cut`, an optional grit tail of scattered ticks
## and an optional wooden knock resonance at `knock` Hz.
func _make_hit(f0: float, tdur: float, crack: float, cut: float, grit := 0.0, knock := 0.0) -> AudioStreamWAV:
	var n := int((tdur * 3.0 + 0.15) * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var ph := 0.0
	var lp := 0.0
	var a := clampf(2.0 * PI * cut / RATE, 0.0, 1.0)
	for i in n:
		var t := float(i) / RATE
		var f := f0 * (1.0 + 0.8 * exp(-t / 0.02))
		ph += TAU * f / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += a * (w - lp)
		var s := sin(ph) * exp(-t / tdur) * smoothstep(0.0, 0.002, t)
		s += crack * lp * exp(-t / 0.025) * 2.5
		if knock > 0.0:
			s += 0.5 * sin(TAU * knock * t) * exp(-t / 0.05) + 0.25 * sin(TAU * knock * 2.7 * t) * exp(-t / 0.03)
		x[i] = s
	if grit > 0.0:   # crumbs of ash and stone pattering off
		for d in 40:
			var at := int(_rng.randf_range(0.01, tdur * 2.5) * RATE)
			var ff := _rng.randf_range(2500.0, 6000.0)
			var amp := grit * _rng.randf_range(0.05, 0.3) * exp(-float(at) / RATE / tdur)
			for j in 120:
				if at + j < n:
					x[at + j] += amp * sin(TAU * ff * j / RATE) * exp(-j / 18.0)
	return _wav(x)

## Iron on iron: inharmonic bar partials with long, staggered decays over a scraped burst.
func _make_clang(f0: float) -> AudioStreamWAV:
	var n := int(1.4 * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var parts := [[1.0, 1.0, 0.5], [2.76, 0.7, 0.35], [5.40, 0.45, 0.22], [8.93, 0.3, 0.12], [1.51, 0.35, 0.6]]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p: Array in parts:
			s += float(p[1]) * sin(TAU * f0 * float(p[0]) * t * (1.0 + 0.003 * sin(t * 31.0))) * exp(-t / float(p[2]))
		var w := _rng.randf() * 2.0 - 1.0
		s += w * 0.9 * exp(-t / 0.012) + w * 0.12 * exp(-t / 0.15)
		x[i] = s * smoothstep(0.0, 0.0015, t)
	return _wav(x, 0.8)

## The heavy's slam: a deep thud with soil thrown up, clods pattering down after.
func _make_slam() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var ph := 0.0
	var br := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * 48.0 * (1.0 + 1.2 * exp(-t / 0.03)) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		br = br * 0.99 + w * 0.1
		lp += 0.15 * (w - lp)
		x[i] = sin(ph) * exp(-t / 0.18) + br * 1.5 * exp(-t / 0.3) + lp * 1.2 * exp(-t / 0.04)
	for d in 50:
		var at := int(_rng.randf_range(0.08, 0.8) * RATE)
		var amp := _rng.randf_range(0.03, 0.15)
		var ff := _rng.randf_range(300.0, 1200.0)
		for j in 400:
			if at + j < n:
				x[at + j] += amp * sin(TAU * ff * j / RATE) * exp(-j / 70.0) * (_rng.randf() * 0.6 + 0.4)
	return _wav(x)

## Perfect dodge: a low swell that rises into a breathy whoosh and hangs, like air folding
## round the hero as time slows.
func _make_perfect() -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var lo := 0.0
	var bp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var e := smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.45, 1.0, k))
		var f := lerpf(300.0, 1600.0, smoothstep(0.0, 0.3, k)) * lerpf(1.0, 0.6, k)
		var g := 2.0 * sin(PI * f / RATE)
		var w := _rng.randf() * 2.0 - 1.0
		lo += g * bp
		bp += g * (w - lo - 0.25 * bp)
		ph += TAU * lerpf(70.0, 45.0, k) / RATE
		x[i] = bp * e * 0.6 + sin(ph) * e * 0.5
	return _wav(x, 0.8)

## A footfall. kind 0 grass: a soft heel thud with a dry crunch of stems; 1 grit: a short
## gravel scuff of many tiny ticks; 2 wet: a muffled splat with a sucking slosh.
func _make_step(kind: int) -> AudioStreamWAV:
	var n := int(0.22 * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var ph := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var toe := _rng.randf_range(0.045, 0.07)   # heel then toe
	var sf := _rng.randf_range(70.0, 90.0)
	for i in n:
		var t := float(i) / RATE
		ph += TAU * sf / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += 0.3 * (w - lp)
		lp2 += 0.06 * (w - lp2)
		var thud := sin(ph) * exp(-t / 0.025) * 0.7
		var e := exp(-t / 0.03) + 0.6 * exp(-maxf(t - toe, 0.0) / 0.035) * smoothstep(toe - 0.004, toe, t)
		var s := thud
		match kind:
			0:
				s += (w - lp) * 0.35 * e * (0.5 + 0.5 * _rng.randf())   # stem crunch
			1:
				s += (w - lp) * 0.25 * e
			_:
				s += lp2 * 3.0 * e + lp * 0.4 * exp(-maxf(t - toe, 0.0) / 0.07) * smoothstep(toe - 0.01, toe, t)
		x[i] = s
	if kind == 1:   # gravel ticks
		for d in 30:
			var at := int(_rng.randf_range(0.0, 0.12) * RATE)
			var ff := _rng.randf_range(2000.0, 5500.0)
			var amp := _rng.randf_range(0.08, 0.35)
			for j in 90:
				if at + j < n:
					x[at + j] += amp * sin(TAU * ff * j / RATE) * exp(-j / 12.0)
	return _wav(x, 0.7)
