class_name Foley
extends Node3D
## Close-up sounds of the fight and the body. Recorded CC0 / CC-BY samples (game/audio/sfx,
## listed in ASSETS.md) replace the synthesised stand-ins wherever a set exists (`RECORDED`;
## bots read `recorded`); the rest are still synthesised at load. Staff swishes are timed to
## each strike (a light whip, a deep whoom on the heavy), impacts by what was struck (straw post, the Hollows' ashen stone, wood), a ringing
## clang on a parry, a soil-and-grit thump when the heavy meets the ground, a cloth whoosh
## on a dodge and a low swelling breath on a perfect one, a dull blow when the hero is
## struck, the soldier's spear hissing through its thrust, and footfalls on grass, on the
## keep's gritty floor and splashing in wet ground. During the perfect-dodge slow motion the
## whole mix slows and deepens with time. The red deer's barks, hooves and rut roar and the
## fox's barks and yelp are wired up but silent until real recordings are found (`SILENT`).
## Bots read `played` (sound name -> count).

const RATE := 22050

var world: Node3D
var player: Player
var weather: Weather
var played := {}          # sound name -> times played (bots)
var build_ms := 0
var hero_steps := 0       # footfalls of the hero alone (bots)
var recorded := {}        # sound name -> number of recorded variants loaded (bots)

## Sample group -> the sound names whose recorded variants replace the synthesised ones.
## Voices with no real recording yet stay silent rather than synthesised (owner, 2026-10-30):
## Edda's hen call and humming, and the murmur of two villagers passing a word; and
## (2026-10-31) the red deer and the fox, for which no CC0 / CC-BY recording could be
## reached from the build box. Bots check these have no stream at all.
const SILENT := ["call", "hum", "murmur", "murmur_low",
	"bark", "roar", "gallop", "gallop_wet", "fox_bark", "fox_yelp"]

const RECORDED := {
	"combat": ["swish", "whoom", "spear", "straw", "stone", "wood", "body", "boom", "clang", "slam", "dodge", "perfect"],
	"steps": ["step_grass", "step_grit", "step_wet", "step_stone", "step_stone_wet"],
	"village": ["creak", "chop", "thud", "grain", "grunt"],
	"animals": ["dog_bark", "dog_woof", "cluck", "squawk", "crunch"],
}

var _rng := RandomNumberGenerator.new()
var _s := {}              # sound name -> Array[AudioStreamWAV] variants
var _pool: Array[AudioStreamPlayer3D] = []
var _wild: Array[AudioStreamPlayer3D] = []   # far-carrying wildlife voices and hooves
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
	_s["chop"] = [_make_hit(150.0, 0.08, 0.6, 2600.0, 0.0, 330.0), _make_hit(165.0, 0.07, 0.55, 2900.0, 0.0, 360.0)]
	_s["thud"] = [_make_hit(110.0, 0.09, 0.2, 1200.0, 0.0, 240.0)]
	_s["body"] = [_make_hit(80.0, 0.16, 0.3, 900.0)]
	_s["boom"] = [_make_hit(55.0, 0.35, 0.15, 400.0)]
	_s["clang"] = [_make_clang(610.0), _make_clang(680.0)]
	_s["slam"] = [_make_slam()]
	_s["dodge"] = [_make_swish(0.32, 400.0, 1400.0, 0.9), _make_swish(0.3, 450.0, 1500.0, 0.9)]
	_s["perfect"] = [_make_perfect()]
	_s["step_grass"] = [_make_step(0), _make_step(0), _make_step(0), _make_step(0)]
	_s["step_grit"] = [_make_step(1), _make_step(1), _make_step(1)]
	_s["step_wet"] = [_make_step(2), _make_step(2), _make_step(2)]
	_s["step_stone"] = [_make_step(3), _make_step(3), _make_step(3)]
	_s["step_stone_wet"] = [_make_step(4), _make_step(4), _make_step(4)]
	_s["dog_bark"] = [_make_dog_bark(1.0), _make_dog_bark(0.93), _make_dog_bark(1.07)]
	_s["dog_woof"] = [_make_dog_woof(1.0), _make_dog_woof(0.95)]
	_s["crunch"] = [_make_crunch(), _make_crunch(), _make_crunch()]
	_s["cluck"] = [_make_cluck(1.0, 1), _make_cluck(1.06, 2), _make_cluck(0.94, 3), _make_cluck(1.1, 2)]
	_s["squawk"] = [_make_squawk(1.0), _make_squawk(1.08), _make_squawk(0.93)]
	_s["creak"] = [_make_creak(1.0), _make_creak(0.86), _make_creak(1.12)]
	for g: String in RECORDED:
		for nm: String in RECORDED[g]:
			var vs := Samples.load_set(g, nm)
			if not vs.is_empty():
				_s[nm] = vs
				recorded[nm] = vs.size()
	for i in 7:
		var q := AudioStreamPlayer3D.new()
		q.unit_size = 10.0
		q.max_distance = 260.0
		q.attenuation_filter_cutoff_hz = 4500.0   # distance takes the top off
		q.attenuation_filter_db = -18.0
		q.bus = &"Wildlife"
		add_child(q)
		_wild.append(q)
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0
		p.bus = &"SFX"
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
	if p.has_signal("fell"):
		# the back hitting the ground: the body thud pitched down into a heavy, dull flop
		p.fell.connect(func(at: Vector3) -> void: _play("body", at, 0.0, 0.62))
	for sol: Node in soldiers:
		if sol.has_signal("struck"):
			sol.struck.connect(func(_r: String) -> void:
				if sol is HollowWarden and (sol as HollowWarden).move_kind == HollowWarden.BASH_MOVE:
					return                     # the shield bash has its own sound (hook_warden)
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

## Gives the red deer herd its voice: alarm barks, galloping hooves and the stag's roar.
## The Ashen Knight, from recorded sets only: a turned blow rings off its shaft (the parry
## clang a shade lower, a thump under it), the surge draws in with a deep slowed whoosh, the
## ring of fire lands as a ground slam with a full boom, and each eruption whumps up out of
## the turf (the heavy whoosh pitched down over a soft slam).
func hook_knight(k: Node) -> void:
	if k == null:
		return
	k.guarded_blow.connect(func(at: Vector3) -> void:
		_play("clang", at, -1.0, 0.88)
		_play("boom", at, -14.0))
	k.phase_changed.connect(func(_n: int) -> void:
		_play("whoom", (k as Node3D).global_position + Vector3.UP * 1.2, 2.0, 0.5))
	k.blasted.connect(func(at: Vector3) -> void:
		_play("slam", at + Vector3.UP * 0.3, 2.0, 0.78)
		_play("boom", at + Vector3.UP * 0.5, -2.0, 0.85))
	k.flame_burst.connect(func(at: Vector3) -> void:
		_play("whoom", at + Vector3.UP * 0.6, 0.0, 0.62)
		_play("slam", at, -9.0, 1.15))

## The Hollow Warden's targe, from recorded sets only: a blocked blow is the wood hit pitched
## down with a quiet iron ring over it; the ward knocked aside cracks with the wood hit, the
## clang low under it and a body thump.
## The Briar Hounds, from recorded sets only: the crouch is the terrier's gruff woof slowed
## into a low snarl, the launch a quick whoosh, a bite that lands the crunch over a body
## thump, and a hound knocked down or killed yelps (the bark pitched down).
func hook_hounds(hs: Array) -> void:
	for h: Node in hs:
		if not h.has_signal("snarled"):
			continue
		h.snarled.connect(func(at: Vector3) -> void: _play("dog_woof", at, -2.0, 0.6))
		h.leapt.connect(func(at: Vector3) -> void: _play("whoom", at, -9.0, 1.35))
		h.yelped.connect(func(at: Vector3) -> void: _play("dog_bark", at, -6.0, 0.8))
		h.struck.connect(func(r: String) -> void:
			if r == "hit":
				_play("crunch", (h as Node3D).global_position + Vector3.UP * 0.7, 0.0, 0.7)
				_play("body", (h as Node3D).global_position + Vector3.UP * 0.7, -4.0, 0.85))

func hook_warden(w: Node) -> void:
	if w == null or not w.has_signal("shield_blocked"):
		return
	w.shield_blocked.connect(func(at: Vector3) -> void:
		_play("wood", at, 0.0, 0.72)
		_play("clang", at, -15.0, 0.7))
	w.shield_broken.connect(func(at: Vector3) -> void:
		_play("wood", at, 2.0, 0.6)
		_play("clang", at, -8.0, 0.62)
		_play("body", at, -4.0, 0.8))
	# the bash: the board hauled back is a low, slow whoosh; landing, the wood hit deep with a
	# body thump under it (the hero shoved); missed, a quick whoosh past
	w.bash_windup.connect(func(at: Vector3) -> void:
		_play("whoom", at, -10.0, 0.55))
	w.shield_bashed.connect(func(at: Vector3, r: String) -> void:
		if r == "hit":
			_play("wood", at, 1.0, 0.58)
			_play("body", at, -1.0, 0.85)
			_play("slam", at, -14.0, 1.3)
		else:
			_play("whoom", at, -6.0, 0.8))

func hook_herd(h: Node) -> void:
	if h == null or not h.has_signal("barked"):
		return
	h.barked.connect(func(at: Vector3) -> void: _play_wild("bark", at, -2.0, 14.0, true))
	h.roared.connect(func(at: Vector3) -> void: _play_wild("roar", at, 2.0, 30.0, true))
	h.galloped.connect(func(at: Vector3) -> void:
		var nm := "gallop_wet" if surface_at(at) == "wet" else "gallop"
		_play_wild(nm, at + Vector3.UP * 0.05, -9.0, 8.0, false))

## The fox's night barks from the dark grass and its yelp as it bolts.
func hook_fox(f: Node) -> void:
	if f == null or not f.has_signal("barked"):
		return
	f.barked.connect(func(at: Vector3, alarm: bool) -> void:
		_play_wild("fox_yelp" if alarm else "fox_bark", at, -3.0 if alarm else -1.0, 16.0, true))
	if f.has_signal("crunched"):
		f.crunched.connect(func(at: Vector3) -> void: _play_wild("crunch", at, -14.0, 1.5, false))

## Brack the collie's barks: glad ones as it runs out to meet the hero, guard barks at night.
func hook_dog(d: Node) -> void:
	if d == null or not d.has_signal("barked"):
		return
	d.barked.connect(func(at: Vector3, alarm: bool) -> void:
		_play_wild("dog_bark", at, 0.0 if alarm else -3.0, 14.0, true))
	if d.has_signal("woofed"):
		d.woofed.connect(func(at: Vector3) -> void: _play_wild("dog_woof", at, -1.0, 14.0, true))

## The hens in the garth: soft clucks as they work the yard, a squawk when one is put to flight.
func hook_hens(h: Node) -> void:
	if h == null or not h.has_signal("clucked"):
		return
	h.clucked.connect(func(at: Vector3) -> void: _play_wild("cluck", at, -13.0, 2.5, false))
	h.squawked.connect(func(at: Vector3) -> void: _play_wild("squawk", at, -5.0, 6.0, true))
	var hh = h.get("house")
	if hh != null and hh.has_signal("knocked"):
		# the pop-hole slide: a hollow wooden clap as it drops onto the sill, a knock as it's propped
		hh.knocked.connect(func(at: Vector3, pw: float) -> void: _play("wood", at, lerpf(-16.0, -4.0, pw), lerpf(1.25, 0.9, pw)))

## The bat at the lantern stays silent: a pipistrelle's calls are near-ultrasonic and the
## synthesised chirps sounded fake (owner audio rule), so nothing is played for it.
func hook_bat(_b: Node) -> void:
	pass

## The garth's field gate: a dry creak of iron eyes turning on the crooks, a knock as it shuts.
func hook_gate(g: Node) -> void:
	if g == null or not g.has_signal("creaked"):
		return
	g.creaked.connect(func(at: Vector3) -> void: _play("creak", at, -9.0))
	g.knocked.connect(func(at: Vector3, pw: float) -> void: _play("wood", at, lerpf(-14.0, -3.0, pw), 0.72))

## Edda at the block (her breath driven out in a short "hah" as the axe comes down, the bite and crack of a round splitting, or a dull thud as the bit
## sticks) and at her cottage door (a low, short creak of the strap hinges and the wooden
## latch dropping into its keeper as it shuts behind her), and humming to herself on the
## bench of an evening.
func hook_villager(v: Node) -> void:
	if v == null:
		return
	var c = v.get("chop")
	if c != null:
		c.chopped.connect(func(at: Vector3, split: bool) -> void:
			_play("chop" if split else "thud", at, -4.0 if split else -7.0, _rng.randf_range(0.93, 1.07)))
	var fd = v.get("feed")
	if fd != null:
		fd.scattered.connect(func(at: Vector3) -> void:
			_play("grain", at, -12.0, _rng.randf_range(0.92, 1.08))
			# the fan pattering down on the yard over the wall
			_pending.append([0.5, "grain", at + (v.get("body") as Node3D).global_basis.z * 2.2, -15.0, 1.25]))
		fd.called.connect(func(at: Vector3) -> void: _play("call", at, -6.0, _rng.randf_range(0.97, 1.03)))
	if c != null and c.has_signal("heaved"):
		c.heaved.connect(func(at: Vector3) -> void: _play("grunt", at, -10.0, _rng.randf_range(0.96, 1.04)))
	if v.has_signal("hummed"):
		v.hummed.connect(func(at: Vector3) -> void: _play("hum", at, -14.0))
	if v.has_signal("spoke"):
		v.spoke.connect(func(at: Vector3, low: bool) -> void: _play("murmur_low" if low else "murmur", at, -13.0))
	if v.has_signal("door"):
		v.door.connect(func(at: Vector3) -> void:
			_play("creak", at, -15.0, 0.62)
			_pending.append([0.55, "wood", at, -11.0, 1.5]))

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
	# every blow carries a low thump under the crack (weight); the big ones a full boom
	_play("boom", point, -8.0 + 3.0 * power if power >= 1.5 else -15.0 + 6.0 * (power - 1.0))

func _on_footfall(w: Node3D, at: Vector3, speed: float) -> void:
	var nm := "step_" + surface_at(at)
	var db := lerpf(-20.0, -12.0, clampf(speed / 6.0, 0.0, 1.0))
	if w != player:
		db -= 3.0
	else:
		hero_steps += 1
	_play(nm, at + Vector3.UP * 0.05, db)

## What a foot meets at `at`: "grit" on the keep floor, "stone" (or "stone_wet" in rain) on
## a door slab, "wet" in a pool or soaked ground, else "grass".
func surface_at(at: Vector3) -> String:
	if _ruin != Vector3.INF and Vector2(at.x - _ruin.x, at.z - _ruin.z).length() < 3.6:
		return "grit"
	if DoorStones.under(at.x, at.z, 0.03):
		return "stone_wet" if weather and weather.wet_at(at.x, at.z) > 0.45 else "stone"
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

## A wildlife sound on its own far-carrying pool. Hoofbeats only take a free voice (a whole
## herd at a gallop thins itself out); a bark or a roar steals the oldest one.
func _play_wild(nm: String, at: Vector3, db: float, unit: float, steal: bool) -> void:
	var vs: Array = _s.get(nm, [])
	if vs.is_empty():
		return
	var p: AudioStreamPlayer3D = null
	for q in _wild:
		if not q.playing:
			p = q
			break
	if p == null:
		if not steal:
			return
		p = _wild[_rng.randi() % _wild.size()]
	p.stream = vs[_rng.randi() % vs.size()]
	p.global_position = at
	p.unit_size = unit
	p.volume_db = db + _rng.randf_range(-1.5, 1.0)
	p.pitch_scale = _rng.randf_range(0.94, 1.06)
	p.play()
	played[nm] = int(played.get(nm, 0)) + 1

# ---------------------------------------------------------------- synthesis

## Voiced sound through a vocal tract: a band-limited glottal pulse train (with jitter and
## breath) fed through parallel two-pole formant resonators. `f0s` maps 0..1 -> pitch,
## `env` 0..1 -> amplitude, `rasp` mixes in a period-doubled roughness.
func _voice(dur: float, f0s: Callable, env: Callable, formants: Array, breath: float, rasp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var ph := 0.0
	var jit := 0.0
	var st := []
	for f: Array in formants:
		st.append([0.0, 0.0])
	var odd := false
	for i in n:
		var k := float(i) / n
		if _rng.randf() < 0.01:
			jit = _rng.randfn(0.0, 0.025)
		var f0: float = f0s.call(k) * (1.0 + jit)
		ph += f0 / RATE
		if ph >= 1.0:
			ph -= 1.0
			odd = not odd
		# glottal flow derivative: a sharp closing snap once per period, softened
		var g := -pow(sin(PI * minf(ph / 0.65, 1.0)), 3.0) + 0.55
		if odd:
			g *= 1.0 - rasp * _rng.randf_range(0.4, 0.9)
		var w := _rng.randf() * 2.0 - 1.0
		var src := g + w * breath
		var out := 0.0
		for j in formants.size():
			var fr: float = formants[j][0]
			var q: float = formants[j][1]
			var amp: float = formants[j][2]
			var gg := 2.0 * sin(PI * fr / RATE)
			var lo: float = st[j][0]
			var bp: float = st[j][1]
			lo += gg * bp
			bp += gg * (src - lo - bp / q)
			st[j][0] = lo
			st[j][1] = bp
			out += bp * amp
		x[i] = out * float(env.call(k))
	return x

## A medium dog's single bark: a hard, chesty "rowf" -- a sharp onset, the pitch jumping up
## then falling, through a bigger, darker tract than the fox's, with a rough edge to it.
func _make_dog_bark(pt: float) -> AudioStreamWAV:
	var y := _voice(0.2,
		func(k: float) -> float: return pt * (330.0 + 260.0 * sin(PI * pow(k, 0.45)) - 150.0 * k),
		func(k: float) -> float: return smoothstep(0.0, 0.03, k) * exp(-maxf(k - 0.2, 0.0) * 5.5),
		[[620.0 * pt, 3.0, 1.0], [1250.0 * pt, 4.0, 0.7], [2400.0 * pt, 5.5, 0.3]], 0.75, 0.4)
	var out := PackedFloat32Array()
	out.resize(int(0.4 * RATE))
	for i in y.size():
		if i < out.size():
			out[i] = y[i]
	return _wav(out)

## Its gruff warning at a stranger: "wuff-wuff", two low, short, closed-mouthed barks with
## more growl in them than its glad bark -- a lower, flatter pitch, a dark tract, rough voicing.
func _make_dog_woof(pt: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(0.75 * RATE))
	for c in 2:
		var q := pt * (1.0 if c == 0 else 0.94)
		var y := _voice(0.17 if c == 0 else 0.15,
			func(k: float) -> float: return q * (215.0 + 120.0 * sin(PI * pow(k, 0.5)) - 70.0 * k),
			func(k: float) -> float: return smoothstep(0.0, 0.05, k) * exp(-maxf(k - 0.15, 0.0) * 6.5),
			[[430.0 * q, 3.0, 1.0], [900.0 * q, 4.0, 0.55], [1900.0 * q, 5.5, 0.15]], 0.55, 0.65)
		var at := int((c * 0.27 + _rng.randf_range(0.0, 0.03)) * RATE)
		for i in y.size():
			if at + i < out.size():
				out[at + i] += y[i] * (1.0 if c == 0 else 0.85)
	return _wav(out)

## A hen's cluck to herself: `count` short, low, throaty "buk"s close together, each a
## quick drop in pitch through a small dark tract, the last a touch longer and rising.
func _make_cluck(pt: float, count: int) -> AudioStreamWAV:
	var gap := 0.13
	var out := PackedFloat32Array()
	out.resize(int((gap * count + 0.25) * RATE))
	for c in count:
		var last := c == count - 1 and count > 1
		var d := 0.15 if last else 0.075
		var y := _voice(d,
			func(k: float) -> float: return pt * ((300.0 + 90.0 * k) if last else (360.0 - 110.0 * k)),
			func(k: float) -> float: return smoothstep(0.0, 0.12, k) * exp(-maxf(k - 0.35, 0.0) * 6.0),
			[[780.0 * pt, 3.5, 1.0], [1500.0 * pt, 4.5, 0.45], [2700.0 * pt, 6.0, 0.12]], 0.3, 0.35)
		var at := int((c * gap + _rng.randf_range(0.0, 0.025)) * RATE)
		for i in y.size():
			if at + i < out.size():
				out[at + i] += y[i] * (0.8 if last else 1.0)
	return _wav(out)

## A hen's alarm as she runs: two clipped "buk"s and a loud, ragged, rising "BAAWK".
func _make_squawk(pt: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(0.9 * RATE))
	for c in 2:
		var y := _voice(0.06,
			func(k: float) -> float: return pt * (520.0 - 120.0 * k),
			func(k: float) -> float: return smoothstep(0.0, 0.15, k) * exp(-maxf(k - 0.3, 0.0) * 6.0),
			[[1000.0 * pt, 4.0, 1.0], [2000.0 * pt, 5.0, 0.5]], 0.4, 0.5)
		var at := int(c * 0.09 * RATE)
		for i in y.size():
			out[at + i] += y[i] * 0.7
	var z := _voice(0.48,
		func(k: float) -> float: return pt * (560.0 + 260.0 * sin(PI * minf(k * 1.4, 1.0)) - 80.0 * k),
		func(k: float) -> float: return smoothstep(0.0, 0.06, k) * exp(-maxf(k - 0.45, 0.0) * 4.0),
		[[1250.0 * pt, 3.5, 1.0], [2500.0 * pt, 4.5, 0.6], [3600.0 * pt, 6.0, 0.25]], 0.55, 0.75)
	var at0 := int(0.2 * RATE)
	for i in z.size():
		if at0 + i < out.size():
			out[at0 + i] += z[i]
	return _wav(out)

## A bite through a dry crust in a fox's jaws: a crisp snap, then a short dry crackle of
## crumbs breaking under the teeth -- high-passed noise grains with a soft wet chew under them.
func _make_crunch() -> AudioStreamWAV:
	var dur := 0.26
	var n := int(dur * RATE)
	var x := PackedFloat32Array()
	x.resize(n)
	var hp := 0.0
	var prev := 0.0
	var grain := 0.0
	var chew := 0.0
	for i in n:
		var k := float(i) / n
		var w := _rng.randf() * 2.0 - 1.0
		hp = 0.7 * (hp + w - prev)          # one-pole high-pass: bright, dry
		prev = w
		# crackle: sparse grains, densest at the first snap, thinning out
		if _rng.randf() < lerpf(0.05, 0.004, k):
			grain = _rng.randf_range(0.4, 1.0)
		grain *= 0.93
		chew = lerpf(chew, w, 0.04)          # low muffled body of the bite
		var snap := exp(-k * 60.0)
		x[i] = hp * (grain * 0.8 + snap * 1.2) * smoothstep(0.0, 0.01, k) + chew * 0.6 * sin(PI * k)
	return _wav(x)

## A gate's hinge creak: rusty eyes dragging round their crooks in stick-slip -- a slow,
## uneven train of grinding clicks that runs together into a rising, wavering squeal and
## falls off, thin and bright, with a hollow wooden body under it from the leaf.
func _make_creak(pt: float) -> AudioStreamWAV:
	var dur := 0.75
	var wob := _rng.randf_range(5.0, 9.0)
	var x := _voice(dur,
		func(k: float) -> float: return pt * (lerpf(90.0, 470.0, smoothstep(0.0, 0.45, k)) - 120.0 * smoothstep(0.55, 1.0, k)) * (1.0 + 0.06 * sin(k * dur * TAU * wob)),
		func(k: float) -> float: return smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.7, 1.0, k)) * (0.75 + 0.25 * sin(k * 37.0)),
		[[1250.0 * pt, 9.0, 1.0], [2600.0 * pt, 11.0, 0.6], [4300.0, 8.0, 0.25], [330.0, 3.0, 0.3]], 0.15, 0.7)
	return _wav(x, 0.6)

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
			3, 4:
				# a slab does not give: the thud is shorter and the heel and toe knock dry
				s = thud * 0.55 * exp(-t / 0.012) + (w - lp) * 0.12 * e * exp(-t / 0.05)
				if kind == 4:   # a thin film of water slapped off the top
					s += (w - lp) * 0.3 * exp(-t / 0.02) + lp * 0.5 * exp(-maxf(t - toe, 0.0) / 0.03) * smoothstep(toe - 0.004, toe, t)
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
	if kind >= 3:   # the stone rings for a moment under the heel, then the toe
		var hs := RATE / 1000.0
		for hit in [[0.0, 1.0], [toe, 0.55]]:
			var at := int(hit[0] * RATE)
			for f in [_rng.randf_range(1400.0, 1900.0), _rng.randf_range(2600.0, 3400.0), _rng.randf_range(4200.0, 5200.0)]:
				var amp: float = hit[1] * _rng.randf_range(0.1, 0.18) * (1600.0 / f)
				for j in int(18.0 * hs):
					if at + j < n:
						x[at + j] += amp * sin(TAU * f * j / RATE) * exp(-j / (2.5 * hs))
	return _wav(x, 0.7)
