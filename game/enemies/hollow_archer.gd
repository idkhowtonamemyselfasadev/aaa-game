class_name HollowArcher
extends HollowSoldier
## Ashen Archer: a Hollow that was a bowman and still carries its yew self bow. It sees the hero
## from farther off and keeps its distance. Rule changes against the spear soldier:
##  SHOT. Standing off between BACK_OFF and SHOOT_MAX it turns side-on, raises the bow, nocks
##    and draws to the jaw, then holds the draw for a beat that is never the same length
##    (HOLD_MIN..HOLD_MAX) while it tracks the hero; the ember runs up the arrow and the
##    bodkin glints, the aim freezes, and it looses. The arrow flies straight at where the
##    hero's chest was on the glint: keep moving across the aim on the glint and it goes
##    behind you; stand still or run straight at it and it lands. A roll as it arrives lets it
##    pass, and a heavy timed on its arrival turns it.
##  KEEPS ITS DISTANCE. Closer than BACK_OFF it walks backward while facing the hero (slower
##    than the hero runs: it can be caught), and draws again once it has room.
##  STAVE. Crowded inside SHOVE_IN it swings the bow stave like a club (the soldier's flat
##    sweep, shorter and weaker), then backs off again.
##  RELOAD. After the loose it lowers the bow and reaches for the next arrow: the punish
##    window for a hero who closed in during the draw.

const ARCHER_HP := 70.0
const ARCHER_POISE := 22.0
const SHOT_MOVE := 2
const SHOOT_MAX := 17.0          # farther than this it walks closer
const BACK_OFF := 5.5            # closer than this it walks backward
const SHOVE_IN := 2.2            # closer than this it clubs with the stave
const BACK_SPEED := 1.7          # slower than the hero's run (it can be caught)
const RAISE_T := 0.42            # s to bring the bow up and nock
const DRAW_T := 0.55             # s to draw to the jaw
const HOLD_MIN := 0.2            # s held at full draw before the glint (random each shot)
const HOLD_MAX := 0.75
const GLINT_T := 0.3             # s of glint; the aim freezes when it starts
const LOOSE_T := 0.14
const RELOAD_T := 0.85
const SHOT_DAMAGE := 18.0
const STAVE_REACH := 1.9
const AIM_TWIST := -55.0         # degrees the chest turns side-on to draw (left shoulder to the hero)
const BOW_ARM := 0.62            # m from the left shoulder to the bow hand at full extension
const ANCHOR := Vector3(0.05, 1.58, 0.06)  # the drawing hand's anchor under the jaw (body space)

# shaft-rig poses for the carry (bow held across the body, upper limb up and forward)
const CARRY := [24.0, 62.0, Vector3(0.12, 1.36, 0.42), 6.0, 0.0, 0.5]

## the bow comes up and the arrow is nocked (foley: a creak of the stave, a rustle)
signal drew(point: Vector3)
## the arrow leaves the string (foley: the string's slap and the shaft's hiss)
signal loosed(point: Vector3, arrow: HollowArrow)
## an arrow it loosed ended its flight: "hit", "parried", "dodged", "perfect", "ground"
signal arrow_landed(point: Vector3, result: String)

var bow: HollowBow
var shots := 0
var shot_hits := 0
var last_hold := 0.0
var last_arrow: HollowArrow
var last_arrow_result := ""
var backsteps := 0.0             # metres it has walked backward to keep its distance
var _hold := 0.4
var _aim_k := 0.0                # 0 bow on the carry .. 1 raised at the aim
var _draw := 0.0
var _aim_pitch := 0.0            # degrees above level to the hero's chest
var _aim_point := Vector3.ZERO   # the world point the arrow flies at (frozen on the glint)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	health_max = ARCHER_HP
	health = ARCHER_HP
	poise_max = ARCHER_POISE
	guard_pose = CARRY
	engage_delay = 0.6
	sweep_reach = STAVE_REACH
	notice = 18.0
	give_up = 28.0
	super._ready()
	name = "HollowArcher"
	_rng.seed = 4127
	# lighter, leaner ash; the rags a faded earth-red bowman's jerkin
	_set_skin("ash_light", Color(0.36, 0.35, 0.34))
	rags.set_param("cloth_dark", Color(0.08, 0.045, 0.035))
	rags.set_param("cloth_light", Color(0.30, 0.17, 0.12))
	if not rags.mats.is_empty():
		rags.mats[0].set_shader_parameter("wool", 0.7)
		rags.mats[0].set_shader_parameter("weathered", 0.9)
	model.scale = Vector3(1.0, 1.04, 1.0)    # leaner than the spearmen
	spear.mesh = null
	bow = HollowBow.new()
	bow.name = "Bow"
	_wield.add_child(bow)
	bow.arrow_on = true
	_place(guard_pose)

func return_to_post() -> void:
	super.return_to_post()
	_aim_k = 0.0
	_draw = 0.0
	if bow:
		bow.arrow_on = true

# --- footwork ---

func _stalk(to: Vector3, dist: float) -> Vector3:
	var ready := t > engage_delay and _facing(to) > 0.9
	if dist < SHOVE_IN and ready:
		_begin_attack(dist)
		return Vector3.ZERO
	if dist < BACK_OFF:
		# back away facing the hero; draw anyway if it has been backing a while (pinned)
		if t > 2.4 and ready and dist > SHOVE_IN + 0.6:
			_begin_attack(dist)
			return Vector3.ZERO
		backsteps += BACK_SPEED * get_physics_process_delta_time()
		return -to.normalized() * BACK_SPEED
	if dist > SHOOT_MAX:
		return to.normalized() * STALK_SPEED * 0.8
	if ready:
		_begin_attack(dist)
	return Vector3.ZERO

func _choose(dist: float) -> int:
	var k := force_move
	if k < 0:
		k = SWEEP_MOVE if dist < SHOVE_IN else SHOT_MOVE
	if k == SHOT_MOVE:
		_hold = _rng.randf_range(HOLD_MIN, HOLD_MAX)
		last_hold = _hold
		bow.arrow_on = true
		drew.emit(bow.global_position)
	return k

## True from the raise to the loose (bots, foley, music).
func drawing() -> bool:
	return state == WINDUP and move_kind == SHOT_MOVE

func shot_windup() -> float:
	return RAISE_T + DRAW_T + _hold + GLINT_T

# --- the shot ---

func _chest_target() -> Vector3:
	if _player == null:
		return global_position + body.global_basis.z * 10.0 + Vector3.UP * 1.2
	return _player.global_position + Vector3.UP * 1.15

func _special_tick(delta: float, to: Vector3, _dist: float) -> Array:
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var total := shot_windup()
			var g := clampf((t - RAISE_T - DRAW_T - _hold) / GLINT_T, 0.0, 1.0)
			if g <= 0.0:
				_aim_point = _chest_target()
			# side-on: the body yaws past the hero so the twisted chest (left shoulder) points at it
			var aim_dir := _aim_point - global_position
			aim_dir.y = 0.0
			_turn_to(aim_dir, delta, 7.0 * (1.0 - g))
			var r := clampf(t / RAISE_T, 0.0, 1.0)
			var dr := clampf((t - RAISE_T) / DRAW_T, 0.0, 1.0)
			_aim_k = smoothstep(0.0, 1.0, r)
			_draw = dr * dr * (3.0 - 2.0 * dr)
			# hold tremble at full draw, stronger the longer it holds
			var held := maxf(t - RAISE_T - DRAW_T, 0.0)
			_draw -= 0.02 * sin(t * 37.0) * smoothstep(0.0, 0.3, held)
			_pose = guard_pose
			lean = -0.05 * _aim_k
			sink = 0.05 * _aim_k
			ember = 1.0 + 1.0 * _draw + 2.6 * g
			_update_glint(smoothstep(0.0, 0.35, g) * (1.0 - smoothstep(0.9, 1.0, g)))
			if t >= total:
				_loose()
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / LOOSE_T, 0.0, 1.0)
			_update_glint(0.0)
			_draw = maxf(0.0, 1.0 - u * 6.0)
			_aim_k = 1.0
			_pose = guard_pose
			lean = -0.05 - 0.04 * sin(PI * u)   # the bow arm kicks with the release
			sink = 0.05
			ember = 3.0 - u
			if u >= 1.0:
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / RELOAD_T, 0.0, 1.0)
			_draw = 0.0
			_aim_k = 1.0 - smoothstep(0.0, 0.6, u)
			_pose = guard_pose
			lean = -0.05 * _aim_k
			sink = 0.05 * _aim_k
			ember = 1.4 - 0.4 * u
			if u > 0.55:
				bow.arrow_on = true             # the next arrow drawn from the quiver
			if u >= 1.0:
				_enter(STALK)
	return [move, lean, sink, ember]

func _loose() -> void:
	var from := bow.to_global(bow.nock_local + Vector3(0, 0, 0.0)) if bow else global_position + Vector3.UP * 1.5
	var tip := bow.to_global(Vector3(0.012, 0.02, 0.0)) if bow else from + body.global_basis.z
	# the arrow starts at the bow hand (the shaft's middle there) and flies at the frozen aim
	var start := tip.lerp(from, 0.1)
	var d := (_aim_point - start)
	var flight := d.length() / HollowArrow.SPEED
	# aim a touch high for the drop over the flight
	d.y += 0.5 * HollowArrow.DROP * flight * flight
	var a := HollowArrow.loose(get_parent(), start + d.normalized() * HollowBow.ARROW_LEN * 0.5, d.normalized() * HollowArrow.SPEED, self)
	a.damage = SHOT_DAMAGE * damage_mul
	a.landed.connect(_on_arrow_landed.bind(a))
	last_arrow = a
	last_arrow_result = ""
	bow.arrow_on = false
	strikes += 1
	shots += 1
	_resolved = true
	loosed.emit(start, a)

func _on_arrow_landed(at: Vector3, r: String, a: HollowArrow) -> void:
	if a == last_arrow and last_arrow_result == "":
		last_arrow_result = r
		last_result = r if r != "ground" else "miss"
		if r == "hit":
			shot_hits += 1
		struck.emit(last_result)
	arrow_landed.emit(at, r)

## A blow that staggers or parries it spoils the draw: the arrow is dropped back to the carry.
func _enter(s: int) -> void:
	if s == STAGGER or s == DEAD or (s == STALK and state != RECOVER):
		_aim_k = 0.0
		_draw = 0.0
		if s == STAGGER and bow and move_kind == SHOT_MOVE:
			bow.arrow_on = true
	super._enter(s)

# --- posing ---

## The carry/stave poses come from the soldier's shaft rig (the bow's grip at the left hand,
## the stave along the shaft); the shot blends to an archer's stance: chest side-on, the bow
## arm out along the aim, the string hand drawn back to the anchor under the jaw.
func _place(pose: Array) -> void:
	super._place(pose)
	if bow == null:
		return
	# the bow on the shaft rig
	var d := spear.transform.basis.y.normalized()
	var grip := _grip_l.position          # the bow hand holds the grip wherever the reach clamp put it
	var fwd := Vector3(0, 0, 1) - d * d.z
	if fwd.length() < 1e-3:
		fwd = Vector3.UP
	fwd = fwd.normalized()
	var carry := Transform3D(Basis(d.cross(fwd).normalized(), d, fwd).orthonormalized(), grip)
	var k := _aim_k
	if k <= 0.001:
		bow.transform = carry
		bow.draw = 0.0
		bow.nock_local = Vector3(0, 0, -HollowBow.BRACE)
		return
	# the aim stance, in body space
	var tw := deg_to_rad(lerpf(float(pose[3]), AIM_TWIST, k))
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var target := body.global_transform.affine_inverse() * _aim_point if _aim_point != Vector3.ZERO else Vector3(0, 1.4, 10)
	var ad := (target - ANCHOR)
	ad.x = 0.0                                   # the aim runs straight ahead of the body
	ad = ad.normalized() if ad.length() > 1e-3 else Vector3.BACK
	ad = Vector3(0, ad.y, absf(ad.z)).normalized()
	_aim_pitch = rad_to_deg(asin(clampf(ad.y, -1.0, 1.0)))
	var reach := lerpf(0.36, BOW_ARM, smoothstep(0.3, 1.0, k))
	var bow_hand := sl + ad * reach
	# the bow is canted a little off vertical, its back toward the hero
	var up := Vector3.UP.rotated(ad, deg_to_rad(-12.0))
	up = (up - ad * up.dot(ad)).normalized()
	var aim_xf := Transform3D(Basis(up.cross(ad).normalized(), up, ad).orthonormalized(), bow_hand)
	# the string hand: on the string at brace, then drawn back along the aim to the anchor
	var at_brace := bow_hand - ad * HollowBow.BRACE
	var anchor := ANCHOR.rotated(Vector3.UP, tw - deg_to_rad(AIM_TWIST))
	var line_anchor := bow_hand - ad * (bow_hand - anchor).dot(ad)
	var string_hand := at_brace.lerp(line_anchor, _draw)
	# blend from the carry to the aim
	var bx := carry.interpolate_with(aim_xf, k)
	bow.transform = bx
	bow.draw = clampf(_draw, 0.0, 1.0)
	bow.nock_local = bow.transform.affine_inverse() * string_hand
	_grip_l.position = _grip_l.position.lerp(bow_hand, k)
	_grip_r.position = _grip_r.position.lerp(string_hand, k)
	if _twist != null:
		_twist.twist = tw
	if _glint != null and _glint.visible:
		_glint.global_position = bow.to_global(Vector3(0.012, 0.02, 0.06))

func _update_glint(a: float) -> void:
	super._update_glint(a)
	if _glint != null and bow != null:
		_glint.global_position = bow.to_global(Vector3(0.012, 0.02, 0.06))
