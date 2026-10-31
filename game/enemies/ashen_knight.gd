class_name AshenKnight
extends HollowSoldier
## The Ashen Knight, the vale's slice boss: a Hollow that kept its armour and its wits. A head
## taller than the soldiers, its ash skin baked dark as iron, the ember in its chest burning
## hotter with every phase. It fights with the soldiers' glaive moves (thrust + sweep, the same
## tells) but changes the rules twice:
##  1. GUARDED. While it stalks, it turns the hero's light strikes aside on the shaft with a
##     clang of sparks: only a heavy (power >= GUARD_BREAK) gets through, or a light string into
##     its recovery after a missed or dodged blow. Its blows can be parried like a soldier's.
##  2. UNBLOCKABLE. At two thirds health it drops to a knee and the ember bursts (SURGE: a
##     ring of fire that throws down anyone close; roll through it). It rises faster, its glint
##     burns red and nothing it swings can be deflected: dodge or be hit.
##  3. ALIGHT. At one third a second surge sets the ground burning: every FLAME_EVERY s the
##     turf under the hero smoulders, then erupts (AshFlame), so the hero has to keep moving
##     while the knight presses at its fastest.
## Between phases it cannot be hurt while it surges. A dead hero resets it to phase 1.

const KNIGHT_HP := 540.0
const KNIGHT_POISE := 62.0
const PHASE_AT := [0.66, 0.33]   # health fraction that starts phase 2, phase 3
const GUARD_BREAK := 1.5         # a hit this strong breaks the guard (the heavies; not the string)
const SURGE_T := 2.2             # s on its knee, burning (brain time)
const SURGE_BLAST := 0.95        # s into the surge the ring of fire bursts
const SURGE_R := 4.2
const SURGE_DAMAGE := 20.0
const FLAME_EVERY := 4.2
const TEMPO := [1.0, 1.2, 1.3]
const NAME := "The Ashen Knight"

signal phase_changed(phase: int)

var phase := 1
var guarded := 0                 # light strikes turned aside (bots)
var surges := 0
var blasts := 0
var blast_result := ""
var flames: Array[AshFlame] = []
var flames_spawned := 0
var flame_results: Array[String] = []
var _surge := -1.0
var _blasted := false
var _flame_t := 0.0

func _ready() -> void:
	health_max = KNIGHT_HP
	health = KNIGHT_HP
	poise_max = KNIGHT_POISE
	super._ready()
	name = "AshenKnight"
	model.scale = Vector3(1.14, 1.16, 1.16)
	_model_rest = model.transform
	# iron-dark ash, a hotter ember
	_set_skin("ash_dark", Color(0.06, 0.055, 0.052))
	_set_skin("ash_light", Color(0.30, 0.28, 0.26))
	_set_skin("ember_col", Color(1.0, 0.32, 0.06))
	_ember_light.omni_range = 3.4
	add_to_group("boss")

## The hero woke at the rest point: the knight stands whole again, in its first form.
func return_to_post() -> void:
	super.return_to_post()
	if state == DEAD:
		return
	_set_phase(1)
	_surge = -1.0
	_flame_t = 0.0
	for f in flames:
		if is_instance_valid(f):
			f.queue_free()
	flames.clear()

func health_fraction() -> float:
	return clampf(health / health_max, 0.0, 1.0)

func surging() -> bool:
	return _surge >= 0.0

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	if _surge >= 0.0:
		# the burst of the ember throws the blow off: a dull spark, no harm done
		ImpactFX.spawn(get_parent(), point, dir, "stone", 0.4)
		return
	if phase == 1 and power < GUARD_BREAK and (state == IDLE or state == STALK) and _hero_in_front():
		guarded += 1
		_freeze = hitstop * 0.6
		_flash = 0.15
		ImpactFX.spawn(get_parent(), point, dir, "metal", 1.2)
		if _player != null:
			_player.add_shake(0.25)
		# the turned blow opens the hero up: it answers quickly
		if state == STALK:
			t = maxf(t, 0.25)
		return
	super.take_hit(point, dir, power, hitstop)
	if state != DEAD and phase < 3 and health <= health_max * PHASE_AT[phase - 1]:
		_begin_surge()

func _hero_in_front() -> bool:
	if _player == null:
		return true
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.length() < 1e-3 or body.global_basis.z.dot(to.normalized()) > 0.3

func _set_phase(n: int) -> void:
	phase = n
	tempo = TEMPO[n - 1]
	unblockable = n >= 2
	damage_mul = 1.0 + 0.15 * (n - 1)
	glint_col = Color(1.0, 0.82, 0.6) if n == 1 else Color(1.0, 0.22, 0.1)
	_set_skin("ember_col", Color(1.0, 0.32, 0.06) if n == 1 else Color(1.0, 0.16, 0.04))

func _begin_surge() -> void:
	_set_phase(phase + 1)
	surges += 1
	_surge = 0.0
	_blasted = false
	_flame_t = 0.0
	poise = 0.0
	_update_glint(0.0)
	_from = _pose
	_knock = Vector3.ZERO
	_stagger_len = SURGE_T
	_recoil = 1.5
	state = STAGGER
	t = 0.0
	phase_changed.emit(phase)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == DEAD or _freeze > 0.0:
		return
	if _surge >= 0.0:
		_surge += delta * tempo
		var u := clampf(_surge / SURGE_T, 0.0, 1.0)
		var e := 2.0 + 5.0 * smoothstep(0.0, SURGE_BLAST / SURGE_T, u) * (1.0 - smoothstep(0.6, 1.0, u))
		_set_skin("ember", e + 0.4 * sin(_surge * 40.0))
		_ember_light.light_energy = 0.45 * e
		# down on one knee, head bowed into the burst
		var k := sin(PI * u)
		_lean(0.32 * k, 0.42 * k)
		if not _blasted and _surge >= SURGE_BLAST:
			_blasted = true
			_blast()
		if _surge >= SURGE_T or state != STAGGER:
			_surge = -1.0
		return
	if phase == 3 and state != IDLE and _player != null and not _player.is_dead():
		_flame_t += delta
		if _flame_t >= FLAME_EVERY:
			_flame_t = 0.0
			spawn_flame(_player.global_position)
	for i in range(flames.size() - 1, -1, -1):
		var f := flames[i]
		if not is_instance_valid(f):
			flames.remove_at(i)
		elif f.result != "" and not f.has_meta("counted"):
			f.set_meta("counted", true)
			flame_results.append(f.result)

## The ember bursts: a ring of fire round the kneeling knight, hurling down whoever stands in
## it (unblockable; a dodge passes through). The second surge leaves the ground smouldering.
func _blast() -> void:
	blasts += 1
	blast_result = "miss"
	var c := global_position
	ImpactFX.spawn(get_parent(), c + Vector3.UP * 1.1, body.global_basis.z, "stone", 2.4)
	for i in 7:
		var a := TAU * i / 7.0 + body.rotation.y
		var f := _flame_at(c + Vector3(sin(a), 0, cos(a)) * 2.6, false)
		f.t = AshFlame.WARN - 0.02   # bursts at once: the ring itself is the blast's fire
	if _player == null or _player.is_dead():
		return
	var d := _player.global_position - c
	_player.add_shake(0.6)
	if Vector2(d.x, d.z).length() < SURGE_R and absf(d.y) < 2.0:
		blast_result = _player.receive_attack(self, SURGE_DAMAGE, true, true)

func spawn_flame(at: Vector3) -> AshFlame:
	flames_spawned += 1
	return _flame_at(at, true)

func _flame_at(at: Vector3, harms: bool) -> AshFlame:
	var f := AshFlame.new()
	f.source = self
	f.player = _player if harms else null
	get_parent().add_child(f)
	f.global_position = at
	if harms:
		flames.append(f)
	return f
