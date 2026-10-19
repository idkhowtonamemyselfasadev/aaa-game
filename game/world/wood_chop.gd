class_name WoodChop
extends Node3D
## Edda's work at the chopping block by the lean-to: she stoops to gather the last halves and
## set a fresh round on the block, settles, heaves the axe up over her head and brings it
## down. The round splits and the halves jump off to either side with a spray of chips, or
## (one swing in four) the bit sticks with a dull thud and she swings again. Drives her pose
## through `bend` (the stoop) and `lift` (0 axe low, 1 overhead, -1 struck through), and
## holds the axe in her hands while she is at the block.

signal chopped(at: Vector3, split: bool)

const ROUND_R := 0.12
const ROUND_LEN := 0.34
const SEED := 70
# the cycle (s): stoop and set a round, settle, heave, hold, strike, follow through, recover
const T_SET := 1.2
const T_UP := 2.4
const T_RAISE := 2.9
const T_TOP := 3.9
const T_STRIKE := 4.15
const T_HIT := 4.33
const T_HOLD := 4.7
const T_DONE := 5.6
const TH_READY := 2.0            # the helve's angle from up toward forward with the axe low
const TH_TOP := -2.3             # laid back over the shoulders
const STICK := 0.25              # chance the bit sticks and she swings again

var villager: Villager
var axe: Axe
var block_axe: Node3D
var splits := 0                  # rounds split (bots)
var swings := 0                  # blows struck (bots)
var holding := false             # the axe in her hands (else bitten into the block)
var bend := 0.0                  # 0 upright .. 1 stooped to the logs
var lift := 0.0                  # the swing pose, see the class note
var theta := TH_READY            # the helve's angle in her swing plane
var reach := 0.66                # palm to the bit edge at the blow (bots)
var pin := -1.0                  # >= 0: the cycle stops at this time (shots)

var _t := 0.0                    # time into the cycle (negative: resting before it)
var _round_on := false
var _halves_on := false
var _fall := 1.0                 # 0..1 the halves' tumble off the block
var _top := Vector3.ZERO         # the block's top centre
var _side := Vector3.RIGHT
var _fwd := Vector3.FORWARD
var _rmm: MultiMesh
var _chips: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _half_yaw := 0.0
var _half_spin := Vector2.ZERO
var _home: WhiteCottage

func setup(v: Villager, home: WhiteCottage) -> void:
	villager = v
	_home = home
	_rng.seed = 777
	top_level = true
	global_transform = Transform3D.IDENTITY
	var bk := WhiteCottage.BLOCK_AT
	var g := home.to_global(Vector3(bk.x, 0, bk.y))
	_top = Vector3(g.x, home.global_position.y, g.z)
	_top.y = (v.terrain.height_at(g.x, g.z) if v.terrain != null else g.y) + 0.44
	block_axe = home.get_node_or_null("BlockAxe")
	axe = Axe.new()
	axe.name = "HandAxe"
	axe.visible = false
	axe.top_level = true
	add_child(axe)
	# a fresh round on the block and the two halves it splits into
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/firewood.gdshader")
	mat.set_shader_parameter("exposed", 1.0)
	var round_mesh := home._log_mesh(ROUND_R, ROUND_LEN, 1.0, SEED)
	round_mesh.surface_set_material(0, mat)
	var half_mesh := home._log_mesh(ROUND_R, ROUND_LEN, 0.5, SEED)
	half_mesh.surface_set_material(0, mat)
	var rr := RandomNumberGenerator.new()
	rr.seed = 9000 + SEED
	var a0 := rr.randf_range(0.0, TAU)
	# the half's bulk lies at a0 + PI/2 in its mesh: turn it to face the side it falls to
	_half_yaw = a0 + PI * 0.5
	for i in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = round_mesh if i == 0 else half_mesh
		mm.instance_count = 1
		mm.set_instance_custom_data(0, Color(0.35, 0.3, 0.0, 1.0))
		mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), _top))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Round", "HalfA", "HalfB"][i]
		mmi.multimesh = mm
		add_child(mmi)
		if i == 0:
			_rmm = mm
	_chips = CPUParticles3D.new()
	_chips.name = "Chips"
	_chips.emitting = false
	_chips.one_shot = true
	_chips.amount = 18
	_chips.lifetime = 1.1
	_chips.explosiveness = 1.0
	_chips.direction = Vector3.UP
	_chips.spread = 75.0
	_chips.initial_velocity_min = 1.2
	_chips.initial_velocity_max = 3.2
	_chips.angular_velocity_min = -720.0
	_chips.angular_velocity_max = 720.0
	_chips.gravity = Vector3(0, -9.8, 0)
	_chips.damping_min = 0.5
	_chips.damping_max = 1.5
	var cm := BoxMesh.new()
	cm.size = Vector3(0.028, 0.005, 0.014)
	var chip_mat := StandardMaterial3D.new()
	chip_mat.albedo_color = Color(0.62, 0.5, 0.33)
	chip_mat.roughness = 0.9
	cm.material = chip_mat
	_chips.mesh = cm
	_chips.scale_amount_min = 0.6
	_chips.scale_amount_max = 1.4
	add_child(_chips)

## True while she stands at the block (the axe comes out of it into her hands).
func at_block() -> bool:
	var p := villager.global_position
	return villager.activity == "wood" and villager.state != Villager.WALK and Vector2(p.x - _top.x, p.z - _top.z).length() < 1.3

func update(delta: float, working: bool) -> void:
	holding = at_block()
	if block_axe != null:
		block_axe.visible = not holding
	axe.visible = holding
	if not holding:
		_round_on = false
		_t = -1.0
	_fwd = villager.body.global_basis.z.normalized()
	_side = Vector3.UP.cross(_fwd).normalized()
	if not working or not holding:
		# break off: straighten up, the axe back down; pick up again from settling
		bend = move_toward(bend, 0.0, delta / 1.0)
		lift = move_toward(lift, 0.0, delta / 0.8)
		theta = move_toward(theta, TH_READY, delta * 3.0)
		if _t > T_UP:
			_t = T_UP if _round_on else 0.0
		elif _t > 0.0:
			_t = 0.0
	else:
		_step(delta)
	_place_wood(delta)
	_place_axe()

func _step(delta: float) -> void:
	if pin >= 0.0 and _t >= pin:
		_t = pin - delta
	var t0 := _t
	_t += delta
	var t := _t
	if t < 0.0:
		bend = move_toward(bend, 0.0, delta)
		lift = move_toward(lift, 0.0, delta)
		theta = TH_READY
		return
	if t < T_UP:
		# stoop to the chips and the pile: gather the halves, set a round on the block
		bend = _ease(clampf(t / 0.9, 0.0, 1.0)) if t < T_SET + 0.3 else 1.0 - _ease(clampf((t - T_SET - 0.3) / 0.9, 0.0, 1.0))
		lift = 0.0
		theta = lerpf(TH_READY, 1.5, bend)
		if t0 < T_SET and t >= T_SET:
			_halves_on = false
			_round_on = true
		return
	bend = 0.0
	if t < T_RAISE:
		lift = 0.0
		theta = TH_READY
	elif t < T_TOP:
		var u := _ease((t - T_RAISE) / (T_TOP - T_RAISE))
		lift = u
		theta = lerpf(TH_READY, TH_TOP, u)
	elif t < T_STRIKE:
		lift = 1.0
		theta = TH_TOP
	elif t < T_HIT:
		var u := (t - T_STRIKE) / (T_HIT - T_STRIKE)
		lift = 1.0 - 2.0 * u * u
		theta = lerpf(TH_TOP, _aim_theta(), u * u)
	elif t < T_HOLD:
		lift = -1.0
		theta = _aim_theta()
		if t0 < T_HIT:
			_strike()
	elif t < T_DONE:
		var u := _ease((t - T_HOLD) / (T_DONE - T_HOLD))
		lift = -1.0 + u
		theta = lerpf(_aim_theta(), TH_READY, u)
	else:
		lift = 0.0
		theta = TH_READY
		if _round_on:
			_t = T_RAISE - _rng.randf_range(0.3, 0.9)     # it stuck: heave again
		else:
			_t = -_rng.randf_range(1.0, 2.5)

func _strike() -> void:
	swings += 1
	var split := _round_on and (_rng.randf() > STICK or swings % 3 == 0)
	var at := _top + Vector3.UP * (ROUND_LEN if _round_on else 0.0)
	if split:
		splits += 1
		_round_on = false
		_halves_on = true
		_fall = 0.0
		_half_spin = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6))
		_chips.global_position = at
		_chips.restart()
	chopped.emit(at, split)

## The helve's angle that lays the bit edge on the round's top (or the bare block).
func _aim_theta() -> float:
	var palm := _palm()
	var target := _top + Vector3.UP * (ROUND_LEN - 0.02 if _round_on or _halves_on and _fall < 0.2 else -0.02)
	var v := target - palm
	reach = v.length()
	var off := atan2(Axe.EDGE_Z, Axe.HEAD_Y - 0.06)
	return atan2(v.dot(_fwd), v.dot(Vector3.UP)) - off

func _palm() -> Vector3:
	var hm := villager.hand_mark
	if hm == null:
		return villager.global_position + Vector3.UP
	var lh := villager.left_hand_pos()
	var rh := hm.global_position + hm.global_basis.y.normalized() * 0.07
	return rh.lerp(lh, 0.35)

func _place_axe() -> void:
	if not holding:
		return
	var d := Vector3.UP * cos(theta) + _fwd * sin(theta)
	var b := -Vector3.UP * sin(theta) + _fwd * cos(theta)
	var palm := _palm()
	# at the blow the hands slide up the helve (or down to the knob) so the bit meets the wood
	var nominal := Vector2(Axe.EDGE_Z, Axe.HEAD_Y - 0.06).length()
	var slide := clampf(nominal - reach, -0.05, 0.2) * maxf(-lift, 0.0)
	axe.global_transform = Transform3D(Basis(b.cross(d).normalized(), d, b), palm - d * (0.06 + slide))

func _place_wood(delta: float) -> void:
	var tiny := Basis().scaled(Vector3.ONE * 0.0001)
	_rmm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, 0.4), _top + Vector3.UP * ROUND_LEN * 0.5) if _round_on else Transform3D(tiny, _top))
	_fall = minf(_fall + delta / 0.45, 1.0)
	for i in 2:
		var mm := (get_child(2 + i) as MultiMeshInstance3D).multimesh
		if not _halves_on:
			mm.set_instance_transform(0, Transform3D(tiny, _top))
			continue
		var s := 1.0 if i == 0 else -1.0
		var rd := _side * s
		# the half's bulk turned toward the side it falls to, then tipped over onto it
		var yaw := _half_yaw - atan2(rd.z, rd.x)
		var base := Basis(Vector3.UP, yaw)
		var e := _fall * _fall
		var tip := Basis(Vector3.UP.cross(rd).normalized(), PI * 0.5 * e)
		var spin := Basis(Vector3.UP, _half_spin[i] * e)
		var c0 := _top + Vector3.UP * ROUND_LEN * 0.5 + rd * 0.04
		var gnd := _top.y - 0.44
		if villager.terrain != null:
			var q := c0 + rd * 0.42
			gnd = villager.terrain.height_at(q.x, q.z)
		var c1 := Vector3(c0.x, gnd + 0.06, c0.z) + rd * 0.42 + _fwd * 0.08 * s
		var c := c0.lerp(c1, e) + Vector3.UP * 0.12 * sin(PI * _fall)
		mm.set_instance_transform(0, Transform3D(spin * tip * base, c))

static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)
