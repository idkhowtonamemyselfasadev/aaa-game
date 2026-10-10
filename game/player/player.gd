class_name Player
extends CharacterBody3D
## Third-person controller: walk/run/sprint, jump, stamina, orbit camera with collision.
## Combat, climbing and gliding land in milestone 1.

const WALK_SPEED := 4.2
const RUN_SPEED := 6.5
const SPRINT_SPEED := 9.0
const ACCEL := 14.0
const JUMP_VEL := 7.5
const GRAVITY := 22.0
const TURN_SPEED := 12.0
const STAMINA_MAX := 100.0
const HEALTH_MAX := 100.0

# Dodge: a low, leaning dash-step. Input direction (camera-relative) or, with no input, a
# hop back. I-frames cover most of it; an attack that lands in the first PERFECT_WINDOW
# seconds is a perfect dodge: the world drops into slow motion and stamina flows back.
const DODGE_TIME := 0.42
const DODGE_DIST := 3.6
const BACKSTEP_DIST := 2.4
const DODGE_COST := 16.0
const DODGE_IFRAMES := Vector2(0.02, 0.32)
const PERFECT_WINDOW := 0.17
const DODGE_CHAIN := 0.34            # a second dodge may start this far into the first
const SLOWMO_SCALE := 0.25
const SLOWMO_HOLD := 0.45           # unscaled seconds at full slow-down
const SLOWMO_EASE := 0.25           # unscaled seconds back to normal speed
const PERFECT_REFUND := 25.0

signal dodged(perfect: bool)
signal hurt(amount: float)

var stamina := STAMINA_MAX
var health := HEALTH_MAX
var dodge_t := -1.0                   # seconds into the current dodge, -1 when not dodging
var dodges := 0
var perfect_dodges := 0
var _dodge_dir := Vector3.ZERO
var _dodge_back := false
var _dodge_dist := DODGE_DIST
var _dodge_rewarded := false
var _slow_t := -1.0                   # unscaled seconds into a perfect-dodge slow-down
var _slow_base := 1.0
var _model_rest: Transform3D
var bot_dodge := false
var bot_input := Vector2.ZERO           # bots drive this instead of Input
var bot_sprint := false
var bot_jump := false
var bot_attack := false
var use_bot_input := false

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring: SpringArm3D = $CamPivot/SpringArm3D
@onready var camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
@onready var body: Node3D = $Body
@onready var model: Node3D = $Body/Model

# Locomotion: 1D blend idle -> walk -> run on horizontal speed, played faster when sprinting.
const ANIM_WALK_SPEED := 1.9            # m/s the Walk clip's stride covers at 1x
const ANIM_RUN_SPEED := 6.0             # m/s the Run clip's stride covers at 1x
var anim_tree: AnimationTree
var _blend := 0.0

var _yaw := 0.0
var _pitch := -0.25

func _ready() -> void:
	if not use_bot_input and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_model_rest = model.transform
	_setup_animation()
	_attach_staff()
	add_child(Hud.new())

## Out of combat the staff rides diagonally across the back (right shoulder to left hip),
## bound to the upper spine so it follows the torso's sway in every clip.
const STAFF_ON_BACK := Vector3(0.0, 1.28, -0.19)   # body space; body faces +Z
var staff: Staff
var combat: StaffCombat

func _attach_staff() -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var bone := skel.find_bone("mixamorig_Spine2")
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "BackSlot"
	skel.add_child(att)
	att.bone_name = "mixamorig_Spine2"
	staff = Staff.new()
	staff.name = "Staff"
	att.add_child(staff)
	# desired pose in body space: axis tilted ~38° off vertical toward the right shoulder,
	# twisted so the cloth grip sits mid-back
	var axis := Vector3(-0.62, 1.0, 0.0).normalized()
	var b := Basis(Quaternion(Vector3.UP, axis))
	var want := body.global_transform * Transform3D(b, STAFF_ON_BACK)
	# solve the attachment-local offset at the rest pose (skeleton may carry a 0.01 scale)
	var bone_rest := skel.global_transform * skel.get_bone_global_rest(bone)
	staff.transform = bone_rest.affine_inverse() * want
	combat = StaffCombat.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self, staff, skel)

func _setup_animation() -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for a in ["Idle", "Walk", "Run"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = ANIM_RUN_SPEED
	for pt in [["Idle", 0.0], ["Walk", ANIM_WALK_SPEED], ["Run", ANIM_RUN_SPEED]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = pt[0]
		space.add_blend_point(clip, pt[1])
	var root := AnimationNodeBlendTree.new()
	root.add_node("move", space, Vector2(0, 0))
	root.add_node("speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	root.connect_node("speed", 0, "move")
	root.connect_node("output", 0, "speed")
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(ap)
	anim_tree.tree_root = root
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true

func _update_animation(delta: float) -> void:
	if anim_tree == null:
		return
	if dodge_t >= 0.0:
		# dash-step: the run stride at a high cadence; the hop back plays the walk in reverse
		_blend = lerpf(_blend, ANIM_WALK_SPEED if _dodge_back else ANIM_RUN_SPEED, 1.0 - exp(-30.0 * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		anim_tree.set("parameters/speed/scale", -1.7 if _dodge_back else 1.9)
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		hspeed = minf(hspeed, ANIM_WALK_SPEED)   # no jump clip yet: hold a stride
	_blend = lerpf(_blend, minf(hspeed, ANIM_RUN_SPEED), 1.0 - exp(-10.0 * delta))
	anim_tree.set("parameters/move/blend_position", _blend)
	# Between blend points cadence follows speed/blend, so feet don't skate.
	var ts := 1.0
	if hspeed > ANIM_RUN_SPEED:
		ts = hspeed / ANIM_RUN_SPEED
	elif hspeed > 0.2 and hspeed < ANIM_WALK_SPEED:
		ts = maxf(hspeed / ANIM_WALK_SPEED, 0.6)
	if combat != null and combat.hitstop > 0.0:
		ts = 0.0                               # hit-stop: the whole body freezes in the contact
	anim_tree.set("parameters/speed/scale", ts)

# --- camera shake: trauma decays; offset ~ trauma^2 on two incommensurate sines per axis ---
var _trauma := 0.0
var _shake_t := 0.0

func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_trauma = maxf(_trauma - 2.2 * delta, 0.0)
	_shake_t += delta
	var s := _trauma * _trauma * 0.11
	camera.h_offset = s * (sin(_shake_t * 61.0) * 0.6 + sin(_shake_t * 97.0 + 1.7) * 0.4)
	camera.v_offset = s * (sin(_shake_t * 73.0 + 0.6) * 0.6 + sin(_shake_t * 113.0 + 2.9) * 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, -1.2, 0.6)

func _physics_process(delta: float) -> void:
	var dir2 := bot_input if use_bot_input else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := (bot_sprint if use_bot_input else Input.is_action_pressed("sprint")) and stamina > 0.0
	var want_jump := bot_jump if use_bot_input else Input.is_action_just_pressed("jump")
	bot_jump = false
	var want_attack := bot_attack if use_bot_input else Input.is_action_just_pressed("attack_light")
	bot_attack = false
	var want_dodge := bot_dodge if use_bot_input else Input.is_action_just_pressed("dodge")
	bot_dodge = false
	_update_slowmo(delta)
	if want_dodge:
		_try_dodge(dir2)
	if combat != null and want_attack and dodge_t < 0.0:
		combat.light()
	var attacking := combat != null and combat.is_attacking()

	cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	var fwd := -cam_pivot.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam_pivot.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var wish := (right * dir2.x + fwd * -dir2.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var speed := SPRINT_SPEED if sprinting else (RUN_SPEED if dir2.length() > 0.6 else WALK_SPEED)
	var dodging := dodge_t >= 0.0
	if dodging:
		dodge_t += delta
		var u := dodge_t / DODGE_TIME
		if u >= 1.0:
			dodge_t = -1.0
			dodging = false
			model.transform = _model_rest
		else:
			# speed falls off as 1-u^2 so the dash bites hard and settles into the next step;
			# the distance integrates to exactly _dodge_dist
			var peak := _dodge_dist / (DODGE_TIME * 2.0 / 3.0)
			var v := _dodge_dir * peak * (1.0 - u * u)
			velocity.x = v.x
			velocity.z = v.z
			_pose_dodge(u)
	if dodging:
		sprinting = false
	elif attacking:
		# committed to the swing: lunge along the facing, steering is only a nudge
		var face := body.global_transform.basis.z
		speed = 0.0
		var atk: Dictionary = combat.STRING[combat.step]
		var u: float = combat.t / float(atk["dur"])
		var hw: Array = atk["hit"]
		if u > float(hw[0]) - 0.1 and u < float(hw[1]) and not combat.target_in_reach(0.95):
			wish = face
			speed = atk["lunge"]
		sprinting = false
	elif combat != null and combat.is_drawn():
		speed = minf(speed, RUN_SPEED)   # weapon out: no sprint
	var target := wish * speed
	if not dodging:
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if combat != null and combat.hitstop > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0

	if is_on_floor():
		if want_jump and stamina >= 8.0:
			velocity.y = JUMP_VEL
			stamina -= 8.0
	else:
		velocity.y -= GRAVITY * delta

	if sprinting and wish.length() > 0.1:
		stamina = maxf(stamina - 18.0 * delta, 0.0)
	elif attacking or dodging:
		pass                                   # no recovery mid-swing or mid-dodge
	else:
		stamina = minf(stamina + 12.0 * delta, STAMINA_MAX)

	if dodging:
		if not _dodge_back:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(_dodge_dir.x, _dodge_dir.z), 1.0 - exp(-35.0 * delta))
	elif attacking:
		body.rotation.y += combat.spin_delta
		if combat.t < 0.08 and dir2.length() > 0.1:
			# a hit snaps toward the stick direction at its very start
			var cw := (right * dir2.x + fwd * -dir2.y)
			body.rotation.y = lerp_angle(body.rotation.y, atan2(cw.x, cw.z), 0.5)
		elif combat.t < 0.12 and combat.spin_delta == 0.0:
			# no stick: the swing's opening tracks the nearest target ahead (soft lock)
			var tgt := combat.magnet_target(3.4, 1.3)
			if tgt != Vector3.INF:
				var to := tgt - global_position
				body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-30.0 * delta))
	elif wish.length() > 0.1:
		var yaw := atan2(wish.x, wish.z)
		body.rotation.y = lerp_angle(body.rotation.y, yaw, TURN_SPEED * delta)

	move_and_slide()
	_update_animation(delta)
	if combat != null:
		combat.physics_step(delta)

func is_invulnerable() -> bool:
	return dodge_t >= DODGE_IFRAMES.x and dodge_t <= DODGE_IFRAMES.y

func _try_dodge(dir2: Vector2) -> void:
	if stamina <= 0.0 or not is_on_floor():
		return
	if dodge_t >= 0.0 and dodge_t < DODGE_CHAIN:
		return
	if combat != null:
		if combat.hitstop > 0.0:
			return
		combat.cancel_to_guard()
	stamina = maxf(stamina - DODGE_COST, 0.0)
	_dodge_back = dir2.length() < 0.2
	if _dodge_back:
		_dodge_dir = -body.global_transform.basis.z
		_dodge_dist = BACKSTEP_DIST
	else:
		var fwd := -cam_pivot.global_transform.basis.z
		var right := cam_pivot.global_transform.basis.x
		_dodge_dir = right * dir2.x + fwd * -dir2.y
		_dodge_dist = DODGE_DIST
	_dodge_dir.y = 0.0
	_dodge_dir = _dodge_dir.normalized()
	dodge_t = 0.0
	_dodge_rewarded = false
	dodges += 1

## Lean into the dash from the hips and sink low; the hop back leans away. Pivot at the hip
## so the feet stay planted under the body instead of swinging out.
func _pose_dodge(u: float) -> void:
	var env := sin(PI * clampf(u * 1.15, 0.0, 1.0))
	var lean := deg_to_rad(-12.0 if _dodge_back else 24.0) * env
	var hip := Vector3(0, 0.95, 0)
	var t := Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO)
	t = Transform3D(Basis(), hip) * t * Transform3D(Basis(), -hip)
	model.transform = Transform3D(Basis(), Vector3(0, -0.17 * env, 0)) * t * _model_rest

## Enemies call this when a strike would connect. Returns "perfect", "dodged" or "hit".
func receive_attack(attacker: Node, damage: float) -> String:
	if is_invulnerable() or (dodge_t >= 0.0 and dodge_t <= PERFECT_WINDOW):
		if dodge_t <= PERFECT_WINDOW and not _dodge_rewarded:
			_dodge_rewarded = true
			perfect_dodges += 1
			stamina = minf(stamina + PERFECT_REFUND, STAMINA_MAX)
			_start_slowmo()
			DodgeFX.spawn(get_parent(), global_position + Vector3.UP * 1.0, _dodge_dir)
			dodged.emit(true)
			return "perfect"
		dodged.emit(false)
		return "dodged"
	health = maxf(health - damage, 0.0)
	add_shake(0.55)
	hurt.emit(damage)
	return "hit"

func _start_slowmo() -> void:
	if _slow_t < 0.0:
		_slow_base = Engine.time_scale
	_slow_t = 0.0
	Engine.time_scale = _slow_base * SLOWMO_SCALE

## Advances in unscaled time (physics delta divided back out by the current slow-down).
func _update_slowmo(delta: float) -> void:
	if _slow_t < 0.0:
		return
	_slow_t += delta * _slow_base / maxf(Engine.time_scale, 1e-4)
	var k := SLOWMO_SCALE
	if _slow_t > SLOWMO_HOLD:
		var f := clampf((_slow_t - SLOWMO_HOLD) / SLOWMO_EASE, 0.0, 1.0)
		k = lerpf(SLOWMO_SCALE, 1.0, f * f * (3.0 - 2.0 * f))
	Engine.time_scale = _slow_base * k
	if _slow_t >= SLOWMO_HOLD + SLOWMO_EASE:
		Engine.time_scale = _slow_base
		_slow_t = -1.0

func is_slowmo() -> bool:
	return _slow_t >= 0.0

func _exit_tree() -> void:
	if _slow_t >= 0.0:
		Engine.time_scale = _slow_base

func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
