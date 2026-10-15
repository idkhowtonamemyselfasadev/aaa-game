class_name Soundscape
extends Node3D
## The vale's layered soundscape, synthesised at load (no sample files): a wind bed that
## swells with the weather, a rain hiss with drop patter, a dawn/dusk-weighted birdsong of
## whistles, trills and two-note calls from the oak groves, crickets in the night grass,
## rook caws + wing clatter when a flock scatters, and thunder after each lightning stroke
## (crack up close, long rolling rumble far off). Layer levels follow the world clock and
## the Weather; bots read `levels`, `calls` and `claps`.

const RATE := 22050
const LOW_RATE := 11025   # wind/thunder: nothing above ~4 kHz

var world: Node3D
var weather: Weather
var birds: Node
var levels := {}          # layer name -> linear gain this frame (bots)
var calls := 0            # bird calls started (bots)
var claps := 0            # thunder claps played (bots)
var caws := 0             # rook scatter calls played (bots)
var build_ms := 0         # synthesis time at load (bots)

var _rng := RandomNumberGenerator.new()
var _beds := {}           # name -> AudioStreamPlayer
var _songs: Array[AudioStreamWAV] = []
var _thunder_near: AudioStreamWAV
var _thunder_far: AudioStreamWAV
var _caw: AudioStreamWAV
var _pool: Array[AudioStreamPlayer3D] = []
var _next_call := 2.0
var _t := 0.0
var _last_scatter := 0

func _ready() -> void:
	_rng.seed = 7741
	var t0 := Time.get_ticks_msec()
	_bed("wind", _make_wind(), -6.0)
	_bed("leaves", _make_leaves(), -10.0)
	_bed("rain", _make_rain(), -4.0)
	_bed("crickets", _make_crickets(), -14.0)
	for k in 6:
		_songs.append(_make_song(k))
	_thunder_near = _make_thunder(true)
	_thunder_far = _make_thunder(false)
	_caw = _make_caws()
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 160.0
		p.attenuation_filter_cutoff_hz = 6000.0   # far calls lose their top
		p.attenuation_filter_db = -18.0
		p.bus = &"Wildlife"
		add_child(p)
		_pool.append(p)
	build_ms = Time.get_ticks_msec() - t0
	if world and world.has_node("Weather"):
		var lt: Lightning = world.get_node("Weather").lightning
		if lt:
			lt.thunder.connect(_on_thunder)

# ---------------------------------------------------------------- mixing

func _process(delta: float) -> void:
	_t += delta
	if world == null:
		return
	var h: float = world.time_of_day
	var rain := weather.rain if weather else 0.0
	var wind := weather.wind if weather else 0.0
	# birds: a dawn chorus, a quieter midday, an evening song, silent from dusk; rain hushes them
	var song := _band(h, 4.6, 6.0, 8.5, 11.0) + 0.45 * _band(h, 8.5, 11.0, 15.0, 17.0) \
		+ 0.8 * _band(h, 15.5, 17.0, 19.4, 20.4)
	song *= 1.0 - 0.85 * smoothstep(0.1, 0.5, rain)
	# crickets sing from dusk to the small hours, fewer in the cold before dawn, none in rain
	var crick := maxf(_band(h, 19.2, 20.6, 24.0, 24.1), _band(h, -0.1, 0.0, 2.5, 5.0))
	crick *= 1.0 - smoothstep(0.05, 0.3, rain)
	# a slow gust envelope on top of the weather's wind
	var gust := 0.5 + 0.5 * sin(_t * 0.37) * sin(_t * 0.11 + 1.3)
	var w := clampf(0.28 + 0.55 * wind + 0.17 * gust + 0.25 * rain, 0.0, 1.0)
	levels = {
		"wind": w,
		"leaves": clampf(0.35 + 0.65 * wind, 0.0, 1.0) * (0.5 + 0.5 * gust),
		"rain": smoothstep(0.02, 0.8, rain),
		"crickets": crick,
		"birds": song,
	}
	for k: String in _beds:
		var p: AudioStreamPlayer = _beds[k]
		var g: float = levels[k]
		p.volume_db = p.get_meta("base") + linear_to_db(maxf(g, 0.0001))
		p.pitch_scale = 1.0 + (0.12 * (w - 0.4) if k == "wind" else 0.0)
	_next_call -= delta
	if _next_call <= 0.0:
		_next_call = lerpf(9.0, 2.0, song) * _rng.randf_range(0.6, 1.4)
		if song > 0.05:
			_bird_call(song)
	if birds and "scatter_events" in birds and birds.scatter_events != _last_scatter:
		_last_scatter = birds.scatter_events
		_rook_scatter()

func _band(h: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, h) * (1.0 - smoothstep(c, d, h))

func _free_voice() -> AudioStreamPlayer3D:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[_rng.randi() % _pool.size()]

func _listener() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO

## A song from somewhere in the trees round the listener.
func _bird_call(song: float) -> void:
	var at := _listener()
	var trees: Array = []
	if world.has_node("Flora"):
		trees = world.get_node("Flora").tree_positions
	var best := Vector3.INF
	for i in 6:   # pick a nearby oak if one is in reach, else a bush-height spot in the open
		var cand: Vector3 = trees[_rng.randi() % trees.size()] if trees.size() > 0 else at
		if cand.distance_to(at) < best.distance_to(at) and cand.distance_to(at) > 6.0:
			best = cand
	if best == Vector3.INF or best.distance_to(at) > 90.0:
		var a := _rng.randf() * TAU
		best = at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(15.0, 45.0)
		best.y = at.y - 1.0
	else:
		best.y += _rng.randf_range(5.0, 9.0)   # up in the crown
	var p := _free_voice()
	p.stream = _songs[_rng.randi() % _songs.size()]
	p.global_position = best
	p.pitch_scale = _rng.randf_range(0.93, 1.08)
	p.volume_db = -9.0 + linear_to_db(clampf(song, 0.2, 1.0)) + _rng.randf_range(-4.0, 1.0)
	p.play()
	calls += 1

func _rook_scatter() -> void:
	var at := _listener() + Vector3(0, 6, 0)
	if birds.has_method("bird_positions"):
		var bp: Array = birds.bird_positions()
		var best := INF
		for b: Vector3 in bp:
			var d := b.distance_to(at)
			if d < best:
				best = d
				at = b
	var p := _free_voice()
	p.stream = _caw
	p.global_position = at
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.volume_db = -2.0
	p.play()
	caws += 1

func _on_thunder(strength: float, dist: float) -> void:
	var near := dist < 900.0
	var p := AudioStreamPlayer.new()   # non-positional: thunder fills the whole valley
	p.stream = _thunder_near if near else _thunder_far
	p.volume_db = linear_to_db(clampf(strength, 0.15, 1.0)) - clampf(dist / 400.0, 0.0, 12.0) + 2.0
	p.pitch_scale = _rng.randf_range(0.85, 1.1)
	p.bus = &"Ambience"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	claps += 1

# ---------------------------------------------------------------- synthesis helpers

func _bed(nm: String, s: AudioStreamWAV, base_db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.name = nm.capitalize() + "Bed"
	p.stream = s
	p.set_meta("base", base_db)
	p.volume_db = -80.0
	p.autoplay = true
	p.bus = &"Ambience"
	add_child(p)
	_beds[nm] = p

## Pack mono float samples (-1..1) as a 16-bit WAV; `fade` > 0 makes a seamless loop by
## cross-fading that many tail samples into the head (the tail is dropped).
func _wav(x: PackedFloat32Array, rate: int, fade := 0) -> AudioStreamWAV:
	var n := x.size() - fade
	if fade > 0:
		for i in fade:
			var k := float(i) / fade
			x[i] = x[i] * k + x[n + i] * (1.0 - k)
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(x[i]))
	var g := 0.89 / peak
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(clampf(x[i] * g, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = b
	if fade > 0:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s

func _noise(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = _rng.randf() * 2.0 - 1.0
	return x

## Wind: brown noise through a lowpass whose cutoff wanders, under a slow swell, with a
## faint whistle band on the gusts.
func _make_wind() -> AudioStreamWAV:
	var n := LOW_RATE * 9
	var fade := LOW_RATE
	var x := PackedFloat32Array()
	x.resize(n + fade)
	var br := 0.0
	var lp := 0.0
	var bp1 := 0.0
	var bp2 := 0.0
	for i in n + fade:
		var t := float(i) / LOW_RATE
		var w := _rng.randf() * 2.0 - 1.0
		br = br * 0.995 + w * 0.06
		var swell := 0.55 + 0.45 * sin(t * 0.9 + sin(t * 0.31) * 2.0)
		var cut := 0.02 + 0.05 * swell
		lp += cut * (br - lp)
		# resonant-ish band round ~500 Hz for the gust whistle
		bp1 += 0.25 * (w - bp1)
		bp2 += 0.25 * (bp1 - bp2)
		x[i] = lp * 2.2 * swell + (bp1 - bp2) * 0.05 * swell * swell
	return _wav(x, LOW_RATE, fade)

## Leaves: high hiss in short rustling bursts (the oaks and grass stirring).
func _make_leaves() -> AudioStreamWAV:
	var n := RATE * 6
	var fade := RATE / 2
	var x := _noise(n + fade)
	var lp := 0.0
	var env := 0.0
	var tgt := 0.3
	for i in n + fade:
		if i % 1200 == 0:
			tgt = pow(_rng.randf(), 2.0)
		env += 0.0006 * (tgt - env)
		lp += 0.35 * (x[i] - lp)
		x[i] = (x[i] - lp) * env   # highpass
	return _wav(x, RATE, fade)

## Rain: a soft pink-ish hiss plus a patter of tiny drop ticks.
func _make_rain() -> AudioStreamWAV:
	var n := RATE * 5
	var fade := RATE / 2
	var x := _noise(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + fade:
		lp += 0.18 * (x[i] - lp)
		lp2 += 0.6 * (x[i] - lp2)
		x[i] = lp * 0.5 + (x[i] - lp2) * 0.35
	for d in 900:   # drop ticks: short decaying blips at random pitches
		var at := _rng.randi() % (n + fade - 400)
		var f := _rng.randf_range(1800.0, 5200.0)
		var a := _rng.randf_range(0.15, 0.6)
		for j in 300:
			x[at + j] += a * sin(TAU * f * j / RATE) * exp(-j / 40.0)
	return _wav(x, RATE, fade)

## Crickets: a few field-cricket voices, each a ~4.3 kHz tone gated into 3-4 pulse chirps,
## each voice at its own rate and pitch.
func _make_crickets() -> AudioStreamWAV:
	var n := RATE * 6
	var x := PackedFloat32Array()
	x.resize(n)
	for v in 5:
		var f := _rng.randf_range(3900.0, 4700.0)
		var period := 6.0 / roundf(6.0 / _rng.randf_range(0.42, 0.7))   # whole chirps per loop
		var pulses := 3 + _rng.randi() % 2
		var amp := _rng.randf_range(0.25, 1.0)
		var off := _rng.randf() * period
		for i in n:
			var t := fmod(float(i) / RATE + off, period)
			var pi_ := int(t / 0.032)
			if pi_ >= pulses:
				continue
			var pt := t - pi_ * 0.032
			var e := sin(PI * clampf(pt / 0.02, 0.0, 1.0))
			x[i] += amp * e * e * sin(TAU * f * float(i) / RATE)
	return _loop_wav(x)

func _loop_wav(x: PackedFloat32Array) -> AudioStreamWAV:
	var s := _wav(x, RATE, 0)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = x.size()
	return s

## One bird phrase. Kinds: falling whistle (blackbird-ish), rapid trill (wren-ish), two-note
## call (chiffchaff), rising "tsee" series, warble, and a cuckoo-like pair far off.
func _make_song(kind: int) -> AudioStreamWAV:
	var notes: Array = []   # [start s, dur s, f0, f1, vibrato Hz, amp]
	match kind:
		0:
			notes = [[0.0, 0.28, 2100.0, 1500.0, 0.0, 1.0], [0.32, 0.18, 2400.0, 2600.0, 28.0, 0.8],
				[0.55, 0.35, 1900.0, 1300.0, 0.0, 0.9], [0.95, 0.12, 3100.0, 2800.0, 0.0, 0.5]]
		1:
			for i in 22:
				notes.append([i * 0.055, 0.04, 4200.0 + (i % 3) * 300.0, 3700.0, 0.0, 0.6 + 0.4 * sin(i * 0.4)])
		2:
			for i in 7:
				var hi := i % 2 == 0
				notes.append([i * 0.33, 0.11, 5200.0 if hi else 4300.0, 4700.0 if hi else 4000.0, 0.0, 0.8])
		3:
			for i in 4:
				notes.append([i * 0.42, 0.22, 6400.0, 7100.0, 0.0, 0.5 - i * 0.08])
		4:
			for i in 12:
				var f := _rng.randf_range(2200.0, 3800.0)
				notes.append([i * 0.13, 0.1, f, f * _rng.randf_range(0.8, 1.25), 40.0, _rng.randf_range(0.5, 1.0)])
		_:
			notes = [[0.0, 0.32, 760.0, 700.0, 0.0, 1.0], [0.45, 0.42, 620.0, 580.0, 0.0, 0.9]]
	var dur: float = notes[-1][0] + notes[-1][1] + 0.3
	var n := int(dur * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	for nt: Array in notes:
		var i0 := int(nt[0] * RATE)
		var m := int(nt[1] * RATE)
		var ph := 0.0
		for j in m:
			if i0 + j >= n:
				break
			var k := float(j) / m
			var f: float = lerpf(nt[2], nt[3], k) + sin(TAU * nt[4] * j / RATE) * 120.0
			ph += TAU * f / RATE
			var e := sin(PI * k)
			x[i0 + j] += nt[5] * e * sqrt(e) * (sin(ph) + 0.15 * sin(2.0 * ph))
	return _wav(x, RATE, 0)

## Thunder: near = a tearing crack then a heavy roll; far = a low grumble that rolls and
## re-swells for seconds. Brown noise shaped by a lumpy envelope.
func _make_thunder(near: bool) -> AudioStreamWAV:
	var dur := 6.5 if near else 8.0
	var n := int(dur * LOW_RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var bumps: Array = []
	for b in 7:
		bumps.append(Vector3(_rng.randf_range(0.3, dur * 0.7), _rng.randf_range(0.3, 1.2), _rng.randf_range(0.3, 1.0)))
	var br := 0.0
	var lp := 0.0
	var crack := 0.0
	for i in n:
		var t := float(i) / LOW_RATE
		var w := _rng.randf() * 2.0 - 1.0
		br = br * 0.996 + w * 0.08
		var env := 0.0
		for bp: Vector3 in bumps:
			var d := (t - bp.x) / bp.y
			env += bp.z * exp(-d * d)
		var onset := smoothstep(0.0, 0.05 if near else 0.6, t)
		env = env * onset * exp(-t / (dur * 0.45))
		lp += (0.08 if near else 0.04) * (br - lp)
		var s := lp * env * 3.0
		if near:   # the crack: bright noise in the first ~0.4 s, then a rip-tear of pulses
			crack = w * exp(-t / 0.12) * 0.9
			if t < 1.2 and _rng.randf() < 0.004:
				crack += _rng.randf_range(-1.0, 1.0)
			s += crack * smoothstep(0.0, 0.004, t)
		x[i] = s
	return _wav(x, LOW_RATE, 0)

## Rooks lifting off: a burst of wing clatter under a handful of harsh "kaah" caws.
func _make_caws() -> AudioStreamWAV:
	var dur := 2.6
	var n := int(dur * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var lp := 0.0
	for i in n:   # wing flaps: noise pulses ~9 Hz fading out
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += 0.2 * (w - lp)
		var flap := pow(maxf(sin(TAU * (9.0 + sin(t * 3.0)) * t), 0.0), 3.0)
		x[i] = lp * flap * exp(-t / 0.9) * 0.9
	for c in 6:
		var i0 := int(_rng.randf_range(0.0, 1.8) * RATE)
		var m := int(_rng.randf_range(0.22, 0.36) * RATE)
		var f0 := _rng.randf_range(380.0, 520.0)
		var ph := 0.0
		for j in m:
			if i0 + j >= n:
				break
			var k := float(j) / m
			ph += TAU * f0 * (1.0 - 0.18 * k) / RATE
			var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
			var e := sin(PI * minf(k * 3.0, 1.0)) if k < 0.33 else 1.0 - (k - 0.33) / 0.67
			var nz := _rng.randf() * 2.0 - 1.0
			x[i0 + j] += 0.5 * e * (saw * 0.7 + nz * 0.3 * absf(saw))
	return _wav(x, RATE, 0)
