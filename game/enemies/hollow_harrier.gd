class_name HollowHarrier
extends HollowSoldier
## Hollow Harrier, the flanker: a lean Hollow that was a reiver and fights like one. It never
## walks up the front of a hero; it runs a wide ring round them and comes in from behind.
## Rule changes against the spear soldier:
##  CIRCLE. Inside RING_FAR it runs round the hero at ORBIT_R, faster than a soldier stalks,
##    always toward the hero's back (the short way round, holding its side once chosen).
##  BACK-STAB (the tell). Once it is within BEHIND_DEG of the hero's back -- or after
##    CIRCLE_MAX s of a hero who keeps turning to face it -- it drops into a deep crouch with
##    the spear held low, the chest ember flaring and a glint at the point (TELL_T), then
##    darts across the gap in DART_T and drives the spear in. Turn, roll or parry on the glint.
##  OVERRUN. A dart carries it on past where the hero stood; it stumbles out of it bent over
##    for OVERRUN_T (the punish window) and then hops back out to the ring to circle again.
##  LIGHT. Little health and almost no poise: a hit while it circles knocks it off its line.

const HARRIER_HP := 58.0
const HARRIER_POISE := 14.0
const DART_MOVE := 2
const RING_FAR := 7.5            # m: farther than this it runs straight in
const ORBIT_R := 4.2             # m: the ring it runs round the hero
const RUN_IN := 4.4              # m/s closing in
const CIRCLE_SPEED := 3.7        # m/s round the ring (the hero walks 4.2, runs 6.5)
const BEHIND_DEG := 50.0         # within this of straight behind the hero, it crouches to dart
const CIRCLE_MIN := 0.6          # s it circles at least before a dart
const CIRCLE_MAX := 4.5          # s of circling a hero who keeps facing it: it darts from the flank
const TELL_T := 0.46             # s of crouch before the dart
const DART_T := 0.3
const DART_AT := 0.62            # normalised dart time the point resolves
const DART_MAX := 5.2            # m the dart can carry
const DART_REACH := 2.2          # hero centre within this ahead (body space) when it resolves
const DART_HALF := 0.75
const DART_DAMAGE := 17.0
const OVERRUN_T := 0.62          # s stumbling out of the dart: the punish window
const HOP_T := 0.38              # s of the hop back out toward the ring
const HOP := 2.0                 # m the hop carries it

# spear poses in body space: [yaw°, pitch°, centre, twist°, slide, reach]
# carried low and short in the run, gripped near the middle like a reiver's lance
## (11-10 13:00) re-solved offline (replica of `_place`): the old pose asked a grip past its reach, so
## the clamp bent the shaft 19.8 deg off the pose's direction and every lerp into or out of the guard
## bent through the clamp. New: the shaft on the line the old guard visibly held (<= 0.3 deg),
## the fists moved 7-8 cm, both grips inside reach, axis 0 deg off the pose. VGUARD_OLD=1 env: before.
const LOW_GUARD := [17.0, 12.0, Vector3(0.189, 1.247, 0.49), 4.0, 0.18, 0.5]
const LOW_GUARD_OLD := [8.0, -6.0, Vector3(0.10, 1.02, 0.58), 4.0, 0.18, 0.5]
# the crouch: point low and forward at the hero's middle, butt tucked back past the hip
const CROUCHED := [2.0, 6.0, Vector3(-0.02, 1.08, 0.22), -26.0, 0.1, 0.5]
## (11-10 14:00) the old dart asked the front grip 0.51 m past its reach (shaft 96 deg off the
## dart's line at full stretch) and the overrun 0.33 (48 deg off). Re-solved offline like the
## soldier's THRUST: rear fist at the right hip, the shaft angled 12 / 20 deg across the body,
## both grips inside reach. REACH_OLD=1 env: the before.
const DARTED := [12.0, 2.0, Vector3(-0.04, 1.2, 0.83), -10.0, -0.15, 0.6]
const DART_REC := [20.0, -14.0, Vector3(0.02, 1.06, 0.64), -10.0, 0.0, 0.58]   # bent over the spear, overrunning
const DARTED_OLD := [0.0, 2.0, Vector3(0.0, 1.14, 1.18), 18.0, 0.1, 0.6]
const DART_REC_OLD := [6.0, -14.0, Vector3(0.05, 0.98, 0.9), 10.0, 0.1, 0.55]
var dart_pose: Array = DARTED_OLD if OS.has_environment("REACH_OLD") else DARTED
var dart_rec_pose: Array = DART_REC_OLD if OS.has_environment("REACH_OLD") else DART_REC
const CROUCH_SINK := 0.3
const CROUCH_LEAN := 0.32        # rad forward over the knees

## dropped into the crouch (foley: a scuff of feet and a hiss of cloth)
signal crouched(point: Vector3)
## the dart launched (foley: a fast whoosh); the thrust itself reports through struck
signal darted(point: Vector3)

var darts := 0
var dart_hits := 0
var overruns := 0
var circle_t := 0.0              # s circling since the last dart
var circled := 0.0               # bots: metres run round the ring
var flank_darts := 0             # darts launched on the CIRCLE_MAX timeout, not from behind
var last_behind := 180.0         # deg off the hero's back when the last dart was chosen
var orbit_dir := 0.0             # +1 / -1 round the hero, 0 = not yet chosen
var _dart_len := DART_MAX
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	health_max = HARRIER_HP
	health = HARRIER_HP
	poise_max = HARRIER_POISE
	guard_pose = LOW_GUARD_OLD if OS.has_environment("VGUARD_OLD") else LOW_GUARD
	engage_delay = 0.0
	notice = 13.0
	super._ready()
	name = "HollowHarrier"
	_rng.seed = 5113
	# narrow in the shoulders and chest: a runner, not a spearman
	model.scale = Vector3(0.98, 1.08, 0.95)
	_model_rest = model.transform
	# a cold, dull grey ash (bone-pale read as chalk up close) and a dark peat-brown reiver's coif, so it reads apart at a glance
	_set_skin("ash_light", Color(0.37, 0.365, 0.355))
	rags.set_param("cloth_dark", Color(0.075, 0.06, 0.042))
	rags.set_param("cloth_light", Color(0.31, 0.25, 0.17))
	if not rags.mats.is_empty():
		rags.mats[0].set_shader_parameter("weathered", 0.9)
	_place(guard_pose)

## No cowl and no mantle: a fitted coif with knotted tails and a short kilt-length tabard, so
## its outline at range is a lean, bare-shouldered runner beside the hooded spearmen.
func _cut_rags(r: HollowRags) -> void:
	r.cowl = false
	r.mantle = false
	r.hem = 0.62

func return_to_post() -> void:
	super.return_to_post()
	_pose = guard_pose
	circle_t = 0.0
	orbit_dir = 0.0

func crouching() -> bool:
	return state == WINDUP and move_kind == DART_MOVE

func overrunning() -> bool:
	return state == RECOVER and move_kind == DART_MOVE and t < OVERRUN_T

## Degrees between the hero's back and the line from the hero to the harrier (0 = right behind).
func behind_angle() -> float:
	if _player == null:
		return 180.0
	var rel := global_position - _player.global_position
	rel.y = 0.0
	var back := -_player.body.global_basis.z
	back.y = 0.0
	if rel.length() < 1e-3 or back.length() < 1e-3:
		return 180.0
	return rad_to_deg(rel.normalized().angle_to(back.normalized()))

func _stalk(to: Vector3, dist: float) -> Vector3:
	if force_move >= 0 and force_move != DART_MOVE:
		return super._stalk(to, dist)
	var dt := get_physics_process_delta_time()
	if dist > RING_FAR:
		circle_t = 0.0
		var v := to.normalized() * RUN_IN
		_turn_to(v, dt, 12.0)
		return v
	circle_t += dt
	var behind := behind_angle()
	if circle_t > CIRCLE_MIN and (behind < BEHIND_DEG or circle_t > CIRCLE_MAX or force_move == DART_MOVE):
		if behind >= BEHIND_DEG:
			flank_darts += 1
		last_behind = behind
		_begin_attack(dist)
		return Vector3.ZERO
	# run the ring: tangent toward the hero's back, pulled in or out onto ORBIT_R
	var rel := -to
	var r := maxf(rel.length(), 0.01)
	var back := -_player.body.global_basis.z
	back.y = 0.0
	var diff := wrapf(atan2(back.x, back.z) - atan2(rel.x, rel.z), -PI, PI)
	if orbit_dir == 0.0 or absf(diff) > deg_to_rad(165.0):
		orbit_dir = signf(diff) if absf(diff) > 0.05 else (1.0 if _rng.randf() < 0.5 else -1.0)
	var tangent := Vector3(rel.z, 0.0, -rel.x) / r * orbit_dir
	var v := tangent * CIRCLE_SPEED + rel / r * clampf((ORBIT_R - r) * 2.2, -2.5, 2.5)
	v = v.limit_length(CIRCLE_SPEED * 1.15)
	circled += v.length() * dt
	# it runs where it is going, head turned in to the hero
	_turn_to(v.lerp(to.normalized() * v.length(), 0.25), dt, 14.0)
	return v

func _choose(_dist: float) -> int:
	crouched.emit(global_position + Vector3.UP * 0.3)
	return DART_MOVE

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	super.take_hit(point, dir, power, hitstop)
	if state == STAGGER:
		circle_t = 0.0

## The crouch, the dart and the overrun, through the soldier's WINDUP/STRIKE/RECOVER states.
func _special_tick(delta: float, to: Vector3, dist: float) -> Array:
	match state:
		WINDUP:
			var u := clampf(t / TELL_T, 0.0, 1.0)
			# swings round onto the hero fast, commits for the last third
			_turn_to(to, delta, 16.0 * (1.0 - smoothstep(0.6, 0.9, u)))
			var p := _lerp_pose(_from, CROUCHED, minf(u * 2.2, 1.0))
			p[1] = float(p[1]) + sin(t * 37.0) * 1.0 * smoothstep(0.5, 0.9, u)
			_pose = p
			_update_glint(smoothstep(0.45, 0.75, u) * (1.0 - smoothstep(0.92, 1.0, u)))
			if u >= 1.0:
				_resolved = false
				_aimed = _in_dart_line()
				_dart_len = clampf(dist - 0.6, 1.2, DART_MAX)
				strikes += 1
				darts += 1
				circle_t = 0.0
				_from = _pose
				darted.emit(global_position + Vector3.UP * 1.0)
				_enter(STRIKE)
			var k := smoothstep(0.0, 0.5, u)
			return [Vector3.ZERO, CROUCH_LEAN * k, CROUCH_SINK * k, 1.0 + 3.4 * smoothstep(0.1, 0.85, u)]
		STRIKE:
			var u := clampf(t / DART_T, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(CROUCHED, dart_pose, minf(u * 1.8, 1.0))
			# fast off the mark, easing into the drive: integrates to _dart_len over the dart
			var move := body.global_basis.z * (_dart_len / DART_T) * 1.5 * (1.0 - u * u)
			if not _resolved and u >= DART_AT:
				_resolved = true
				_resolve_dart()
			if u >= 1.0:
				_from = _pose
				_enter(RECOVER)
			return [move, CROUCH_LEAN * (1.0 - 0.4 * u), CROUCH_SINK * (1.0 - 0.5 * u), 4.2 - 1.6 * u]
		RECOVER:
			if t < OVERRUN_T:
				# carried on past the hero, bent over the spear, scrabbling to stop
				var k := t / OVERRUN_T
				_pose = _lerp_pose(dart_pose, dart_rec_pose, minf(k * 3.0, 1.0))
				var drift := body.global_basis.z * 1.6 * (1.0 - k) * (1.0 - k)
				return [drift, 0.26 + 0.04 * sin(t * 19.0), 0.16 * (1.0 - k), 1.6]
			var u := clampf((t - OVERRUN_T) / HOP_T, 0.0, 1.0)
			_turn_to(to, delta, 10.0)
			_pose = _lerp_pose(_from, guard_pose, u)
			var away := -to.normalized() if to.length() > 0.01 else -body.global_basis.z
			# out to the ring, not farther
			var hop := away * (HOP / HOP_T) * 1.5 * (1.0 - u * u) * clampf((ORBIT_R + 0.5 - dist) / 1.0, 0.0, 1.0)
			if u >= 1.0:
				orbit_dir = 0.0
				_enter(STALK)
			return [hop, 0.26 * (1.0 - u), 0.1 * (1.0 - u), 1.4 - 0.4 * u]
	_enter(STALK)
	return [Vector3.ZERO, 0.0, 0.0, 1.0]

func _in_dart_line() -> bool:
	if _player == null:
		return false
	var l := _hero_local()
	return l.z > 0.0 and l.z < DART_REACH + 0.3 and absf(l.x) < DART_HALF and absf(l.y) < 1.3

## The point drives in; a hero in the line as the dart launched gets receive_attack's
## dodge verdict. A miss overruns.
func _resolve_dart() -> void:
	var r := "miss"
	if _player != null and (_in_dart_line() or (_aimed and _hero_local().z > -0.6 and _hero_local().length() < DART_REACH + 0.6)):
		r = _player.receive_attack(self, DART_DAMAGE * damage_mul, false, unblockable)
		if r == "hit":
			dart_hits += 1
			_player.add_shake(0.25)
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.05, body.global_basis.z, "stone", 0.6)
	if r != "hit":
		overruns += 1
	last_result = r
	struck.emit(r)

## The harrier's wield leans and sinks with the body like the hewer's, so the crouch keeps
## both hands on the shaft instead of clamping them at the shoulders.
func _lean(rad: float, sink: float) -> void:
	super._lean(rad, sink)
	if _wield != null and state != DEAD:
		_wield.transform = model.transform * _model_rest.affine_inverse()
