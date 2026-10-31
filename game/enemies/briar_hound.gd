class_name BriarHound
extends CharacterBody3D
## A Briar Hound: one of a pair of gaunt, ash-grey hounds that run the meadow's east side
## (DESIGN.md enemy roster: "fast lunges, packs of 2"). They notice the hero at NOTICE m,
## lope in and circle him at CIRCLE_R on opposite sides, head low; then one at a time a hound
## drops into a crouch (eyes flaring ember-red, a gruff snarl: the tell), and launches a
## flying lunge a few metres long at where he stands. A dodge through the lunge (perfect on
## the launch) leaves it sprawled in RECOVER behind him, open; a heavy timed into it deflects
## the jaws and knocks it rolling (PARRIED_T). Any blow knocks a hound out of its crouch or
## out of the air: they are fast and light, never armoured. While one lunges, the other keeps
## circling, so the hero has to keep turning. Procedural mesh on the collie's rig
## (Dog.build_mesh, dog.gdshader) scaled up to a big lurcher-sized hound, coat greyed to char.
## Bots read `state`, `lunges`, `bites`, `staggers`, `parried_count`, `health`, `last_result`.

enum { IDLE, STALK, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }   # IDLE == 0, as music.gd expects

const SCALE := 1.55          # on the collie rig: ~0.75 m at the shoulder
const HEALTH_MAX := 42.0
const DMG_PER_POWER := 13.0
const NOTICE := 14.0
const GIVE_UP := 26.0
const RUN := 6.2             # m/s loping in
const CIRCLE_R := 4.4        # circling distance
const CIRCLE_SPEED := 3.0    # m/s round him
const LUNGE_MIN := 3.0       # it launches from between these distances
const LUNGE_MAX := 5.6
const WINDUP_T := 0.55       # the crouch: the tell
const STRIKE_T := 0.44       # the flight
const BITE_R := 1.25         # jaws within this of the hero's centre connect
const LEAP_H := 0.5          # top of the leap arc
const RECOVER_T := 0.95      # sprawled after a lunge: the punish window
const STAGGER_T := 0.5
const PARRIED_T := 1.3
const DAMAGE := 14.0
const PACK_GAP := 1.25       # s between one hound's lunge and its mate's crouch (0.9 gave the hero no breath)
const COOLDOWN := 2.3        # s a hound circles before it may lunge again (+ up to COOL_JITTER)
const COOL_JITTER := 0.7    # so the pair never falls into a metronome rhythm (1.6 s flat was relentless)
const PRESS := 0.2           # trail age of the bed it holds pressed under itself (full lay)
const LANE := 2.4            # m of run between the lane segments it combs into the meadow
const LANE_AGE := 16.0       # a lane segment starts this old: already standing back up, gone in ~14 s

signal struck(result: String)
signal snarled(at: Vector3)  # the crouch before a lunge
signal leapt(at: Vector3)
signal yelped(at: Vector3)   # knocked down or killed
signal died

var state := IDLE
var t := 0.0
var health := HEALTH_MAX
var health_max := HEALTH_MAX
var mate: BriarHound
var orbit := 1.0             # circling direction (+1 / -1): mates circle opposite ways
var lunges := 0
var bites := 0
var staggers := 0
var hits_taken := 0
var parried_count := 0
var last_result := ""
var impact_kind := "body"
var low_target := true       # the hero's swings tip down to meet it (Combat.dip)
var terrain: Terrain
var _player: Player
var _home := Vector3.ZERO
var _cool := 0.0
var _freeze := 0.0
var _flash := 0.0
var _resolved := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _knock := Vector3.ZERO
var _stagger_len := STAGGER_T
var _yaw := 0.0
var _phase := 0.0
var _speed := 0.0
var _graze := 0.0
var _eyes := 0.0
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _trample: Trample
var _lane_at := Vector3.INF
var _press_at := Vector3.INF
var pressed := 0             # grass points it has laid (bots)

func _ready() -> void:
	add_to_group("hittable")
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.9
	col.shape = cap
	col.position.y = 0.5
	add_child(col)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/dog.gdshader")
	# a smoke-grey coat grizzled with ash-pale guard hairs (it reads against the dark meadow,
	# not as a black hole in it), a sooty saddle, pale points, rust-brown brows, an ember tapetum
	_mat.set_shader_parameter("coat", Color(0.2, 0.185, 0.165))
	_mat.set_shader_parameter("coat_dark", Color(0.075, 0.068, 0.06))
	_mat.set_shader_parameter("pale", Color(0.44, 0.41, 0.37))
	_mat.set_shader_parameter("stocking", Color(0.24, 0.13, 0.07))
	_mat.set_shader_parameter("grizzle", 0.75)
	_mat.set_shader_parameter("grizzle_col", Color(0.5, 0.47, 0.42))
	_mat.set_shader_parameter("sheen", 1.0)
	_mat.set_shader_parameter("patchy", 0.0)
	_mat.set_shader_parameter("eye_col", Color(1.0, 0.32, 0.08))
	_mi = MeshInstance3D.new()
	_mi.name = "Body"
	_mi.mesh = Dog.build_mesh()
	_mi.material_override = _mat
	_mi.scale = Vector3.ONE * SCALE
	add_child(_mi)
	_home = global_position

func plant(t_: Terrain) -> void:
	terrain = t_
	_trample = get_parent().get_node_or_null("Trample") as Trample
	global_position = _ground(global_position)
	_home = global_position

func face(point: Vector3) -> void:
	var d := point - global_position
	_yaw = atan2(-d.x, -d.z)
	rotation = Vector3(0, _yaw, 0)

func is_dead() -> bool:
	return state == DEAD

func hurt_capsule() -> Array:
	# haunch to raised head: the staff's level swings pass at the hero's waist, so the
	# capsule runs up the neck to the skull (a hound is low; it must still be hittable)
	var f := -global_basis.z
	var c := global_position + Vector3.UP * 0.6
	return [c - f * 0.4, c + f * 0.55 + Vector3.UP * 0.3, 0.38]

## The hero died and woke at a rest point: the pack is back on its ground, whole.
func return_to_post() -> void:
	health = HEALTH_MAX
	state = IDLE
	t = 0.0
	_cool = 0.0
	if not is_in_group("hittable"):
		add_to_group("hittable")
	global_position = _home
	_mi.rotation = Vector3.ZERO
	_mi.position = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_INHERIT

func take_hit(_point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	hits_taken += 1
	_freeze = hitstop
	health -= DMG_PER_POWER * power
	_flash = 1.0
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 1e-3:
		d = global_basis.z
	d = d.normalized()
	if health <= 0.0:
		_die(d)
		return
	# light and quick: every blow knocks it out of its crouch or out of the air
	staggers += 1
	_knock = d * (2.2 + 1.6 * power)
	_stagger_len = STAGGER_T + (0.25 if state == STRIKE else 0.0)
	_enter(STAGGER)
	yelped.emit(global_position + Vector3.UP * 0.6)

## The hero's heavy met the jaws: the hound is batted aside and rolls, open for PARRIED_T.
func parried(dir: Vector3, hitstop: float) -> void:
	if state == DEAD:
		return
	parried_count += 1
	staggers += 1
	_freeze = hitstop
	_knock = Vector3(dir.x, 0, dir.z).normalized() * 3.0
	_stagger_len = PARRIED_T
	_enter(STAGGER)
	yelped.emit(global_position + Vector3.UP * 0.6)

func _enter(s: int) -> void:
	state = s
	t = 0.0
	_resolved = false

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, (terrain.height_at(p.x, p.z) if terrain else p.y), p.z)

func _busy(h: BriarHound) -> bool:
	return h != null and is_instance_valid(h) and (h.state == WINDUP or h.state == STRIKE or (h.state == RECOVER and h.t < PACK_GAP))

func _turn(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length_squared() < 1e-4:
		return
	var want := atan2(-dir.x, -dir.z)
	_yaw += clampf(wrapf(want - _yaw, -PI, PI), -rate * delta, rate * delta)

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			_player = get_parent().get_node_or_null("Player") as Player
	_flash = maxf(0.0, _flash - delta * 5.0)
	if _freeze > 0.0:
		_freeze -= delta
		return
	t += delta
	_cool = maxf(0.0, _cool - delta)
	if state == DEAD:
		_die_tick(delta)
		return
	var hp := _player.global_position if _player else global_position + Vector3(0, 0, 100)
	var to := Vector3(hp.x - global_position.x, 0, hp.z - global_position.z)
	var dist := to.length()
	var hero_down := _player == null or _player.is_dead()
	var want := Vector3.ZERO         # desired horizontal velocity
	var graze := 0.0
	var eyes := 0.25
	var sink := 0.0
	var pitch := 0.0
	var lift := 0.0
	match state:
		IDLE:
			# nosing about its ground, drifting back toward home
			var back := Vector3(_home.x - global_position.x, 0, _home.z - global_position.z)
			if back.length() > 1.5:
				want = back.normalized() * 1.2
			graze = 0.8
			eyes = 0.1
			if not hero_down and dist < NOTICE:
				_enter(STALK)
				if mate and is_instance_valid(mate) and mate.state == IDLE:
					mate._enter(STALK)        # one sees him, both come
		STALK:
			graze = 0.35
			if hero_down or dist > GIVE_UP or global_position.distance_to(_home) > GIVE_UP + 8.0:
				_enter(IDLE)
			else:
				var tn := to / maxf(dist, 0.01)
				var side := tn.cross(Vector3.UP) * orbit
				var radial := clampf((dist - CIRCLE_R) * 1.4, -RUN, RUN)
				want = tn * radial + side * CIRCLE_SPEED
				if want.length() > RUN:
					want = want.normalized() * RUN
				if _cool <= 0.0 and dist > LUNGE_MIN and dist < LUNGE_MAX and not _busy(mate) and t > 0.6:
					_enter(WINDUP)
					snarled.emit(global_position + Vector3.UP * 0.6)
		WINDUP:
			# the tell: it stops dead, sinks on its haunches, head low and eyes flaring
			_turn(to, delta, 10.0)
			var k := clampf(t / WINDUP_T, 0.0, 1.0)
			sink = 0.09 * k
			pitch = -0.12 * k
			graze = 0.45
			eyes = 0.25 + 1.6 * k
			if t >= WINDUP_T:
				_from = global_position
				var reach := clampf(dist + 0.7, LUNGE_MIN, LUNGE_MAX + 0.6)
				_to = global_position + to / maxf(dist, 0.01) * reach
				lunges += 1
				_enter(STRIKE)
				leapt.emit(global_position + Vector3.UP * 0.6)
		STRIKE:
			var u := clampf(t / STRIKE_T, 0.0, 1.0)
			var p := _from.lerp(_to, u)
			global_position = Vector3(p.x, global_position.y, p.z)
			lift = LEAP_H * 4.0 * u * (1.0 - u)
			pitch = 0.22 * (1.0 - 2.0 * u)
			eyes = 1.6
			if not _resolved and u > 0.25:
				var jaws := global_position - global_basis.z * 0.6 * SCALE + Vector3.UP * 0.6
				var hc := hp + Vector3.UP * 0.9
				if jaws.distance_to(hc) < BITE_R or u >= 0.85:
					_resolved = true
					_bite(jaws.distance_to(hc) < BITE_R + 0.3)
					if state != STRIKE:
						return            # parried: already rolling
			if t >= STRIKE_T:
				_cool = COOLDOWN + randf() * COOL_JITTER
				_enter(RECOVER)
		RECOVER:
			# sprawled, scrabbling round to face him again: open
			var k := clampf(t / RECOVER_T, 0.0, 1.0)
			sink = 0.12 * (1.0 - k)
			pitch = -0.08 * (1.0 - k)
			_turn(to, delta, 2.5 * k)
			if t >= RECOVER_T:
				_enter(STALK)
		STAGGER:
			var k := clampf(t / _stagger_len, 0.0, 1.0)
			want = _knock * (1.0 - k) * 2.0
			sink = 0.1 * (1.0 - k)
			_mi.rotation.z = (0.9 if _stagger_len >= PARRIED_T else 0.45) * sin(k * PI)
			if t >= _stagger_len:
				_mi.rotation.z = 0.0
				_cool = maxf(_cool, 0.6)
				_enter(STALK)
	if state != STRIKE:
		velocity = Vector3(want.x, 0, want.z)
		move_and_slide()
		if state == STALK and velocity.length() > 0.3:
			_turn(velocity if dist > CIRCLE_R + 2.0 else to, delta, 7.0)
		elif state == IDLE and velocity.length() > 0.3:
			_turn(velocity, delta, 4.0)
	var g := _ground(global_position)
	global_position = Vector3(global_position.x, g.y + lift, global_position.z)
	rotation = Vector3(0, _yaw, 0)
	_mi.position = Vector3(0, -sink, 0)
	_mi.rotation.x = pitch
	var spd := (_from.distance_to(_to) / STRIKE_T) if state == STRIKE else Vector2(velocity.x, velocity.z).length()
	if state == WINDUP or state == RECOVER:
		spd = 0.0
	_speed = lerpf(_speed, spd, 1.0 - exp(-10.0 * delta))
	_graze = lerpf(_graze, graze, 1.0 - exp(-6.0 * delta))
	_eyes = lerpf(_eyes, eyes, 1.0 - exp(-8.0 * delta))
	if state != STRIKE:
		press_grass()
	_pose(delta)

func _pose(delta: float) -> void:
	_phase = fposmod(_phase + delta * (_speed / (0.95 * SCALE) if _speed < 3.0 else _speed / (1.6 * SCALE)), 1.0)
	_mi.set_instance_shader_parameter("phase", _phase)
	_mi.set_instance_shader_parameter("speed", _speed / SCALE)
	_mi.set_instance_shader_parameter("graze", _graze)
	_mi.set_instance_shader_parameter("eyeshine", _eyes + _flash)

## The meadow shows where it runs (a lane of combed-over grass, one long segment per LANE m,
## laid already half-risen so a fight does not spend the herd trail's 64 points) and lies
## flat in a bed round it where it crouches, sprawls, noses about or lies dead.
func press_grass() -> void:
	if _trample == null:
		return
	var p := global_position
	var sp := _speed
	if sp > 1.0:
		if _lane_at == Vector3.INF:
			_lane_at = p
		var run := Vector2(p.x - _lane_at.x, p.z - _lane_at.z)
		if run.length() >= LANE:
			_trample.add_herd_point(Vector2(p.x, p.z), run, 1.0, LANE_AGE, 0.3, run.length())
			_lane_at = p
			pressed += 1
		_press_at = Vector3.INF
		return
	_lane_at = p
	var fwd := Vector2(-sin(_yaw), -cos(_yaw))
	# the bed: from the haunches to the chest, as long as the body (a body point each end)
	var c := Vector2(p.x, p.z) + fwd * 0.45 * SCALE * 0.5
	_trample.add_herd_point(c, fwd, 1.0, PRESS, 0.35, 0.55 * SCALE)
	if _press_at == Vector3.INF or p.distance_to(_press_at) > 0.3:
		pressed += 1
	_press_at = p

func _bite(close: bool) -> void:
	var r := "miss"
	if close and _player:
		r = _player.receive_attack(self, DAMAGE, false, false)
		if r == "hit":
			bites += 1
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.0, -global_basis.z, "stone", 0.5)
	last_result = r
	struck.emit(r)

var _fall := 0.0
func _die(dir: Vector3) -> void:
	state = DEAD
	t = 0.0
	_knock = dir * 3.0
	_fall = 1.0 if dir.dot(global_basis.x) > 0.0 else -1.0
	remove_from_group("hittable")
	yelped.emit(global_position + Vector3.UP * 0.6)
	died.emit()

func _die_tick(delta: float) -> void:
	# thrown, it rolls onto its side and lies still in the grass
	var k := clampf(t / 0.6, 0.0, 1.0)
	if k < 1.0:
		velocity = _knock * (1.0 - k)
		move_and_slide()
	global_position = _ground(global_position)
	_mi.rotation.z = -_fall * 1.45 * smoothstep(0.0, 1.0, k)
	_mi.position = Vector3(0, 0.3 * SCALE * 0.5 * smoothstep(0.0, 1.0, k) - 0.05, 0)
	_speed = lerpf(_speed, 0.0, 1.0 - exp(-8.0 * delta))
	_eyes = lerpf(_eyes, 0.0, 1.0 - exp(-2.0 * delta))
	press_grass()
	_pose(delta)
	if t > 2.0:
		set_physics_process(false)
