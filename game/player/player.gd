class_name Player
extends CharacterBody3D
## Third-person controller: walk/run/sprint, jump, stamina, orbit camera with collision.
## Combat, climbing and gliding land in milestone 1.

const WALK_SPEED := 4.2
const RUN_SPEED := 6.5
const CHARGE_SPEED := 1.1       # shuffle while the heavy is raised
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

# Hit reaction: a blow that gets through rocks the hero back from the hip, shoves them away
# from the attacker and breaks off any swing or charge. Attacks are locked out for the whole
# stagger; a dodge can break it once the worst of the blow has passed. The released heavy's
# downswing is the one armoured moment: it takes the damage and keeps coming.
const FLINCH_TIME := 0.5
const FLINCH_PUSH := 0.65             # metres the blow shoves the hero
const FLINCH_DODGE_AT := 0.24         # a dodge may break the stagger this far in
const FLINCH_LEAN := 17.0             # degrees the upper body rocks away from the blow

# Death: the last blow rocks the hero back, the knees go and the body pitches face-down into
# the grass. The screen sinks to black over the still body, then the hero wakes at the last
# rest point at full vitality; the Hollows they were fighting return to their posts.
const DEATH_FADE_AT := 1.9            # seconds after the blow the screen starts to darken
const DEATH_FADE := 1.0               # seconds to full black
const DEATH_RESPAWN_AT := 3.4         # wake at the rest point (under full black)
const RESPAWN_FADE := 1.2             # seconds the black lifts over after waking

signal died
signal respawned
signal dodged(perfect: bool)
signal hurt(amount: float)
signal lock_changed(target: Node3D)

# Lock-on: the camera swings to frame the hero and the target, swings open toward it, and the
# hero squares up to it when standing. Enemies win over practice targets; a target that dies
# hands the lock to the next enemy in range, or releases it. A sharp mouse flick switches.
const LOCK_RANGE := 16.0
const LOCK_BREAK := 24.0
const LOCK_FLICK_PX := 90.0
const CAM_SIDE := 0.5                 # camera's shoulder offset, free and locked
const CAM_SIDE_LOCKED := 1.05
var lock_target: Node3D = null
var _flick := 0.0
var _flick_t := 0.0

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
var flinch_t := -1.0                  # seconds into the current stagger, -1 when not reeling
var flinches := 0                     # blows that staggered the hero (bots read this)
var armoured_hits := 0                # blows taken through the heavy's armour (bots read this)
var _flinch_dir := Vector3.ZERO       # world direction the blow shoves the hero
var dead_t := -1.0                    # seconds since the killing blow, -1 while alive
var deaths := 0
var woke_t := -1.0                    # seconds since the last respawn (the black lifting)
var respawn_point := Vector3.ZERO     # set by the world: the last rest point
var respawn_yaw := 0.0
var crumple: Crumple                  # bone-level bends of the death fall (knees, spine, arms)
var _shin := 0.45                     # knee height at rest, measured from the skeleton
var bot_dodge := false
var bot_input := Vector2.ZERO           # bots drive this instead of Input
var bot_sprint := false
var bot_jump := false
var bot_attack := false
var bot_lock := false
var bot_heavy := false                  # heavy button held (bots)
var _heavy_was := false
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
	_setup_crumple()
	_skin()
	_dress()
	soak = Soak.new()
	soak.name = "Soak"
	add_child(soak)
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)

## The model's imported materials become hero.gdshader (same maps), which can take the rain.
var soak: Soak

func _skin() -> void:
	var shader := preload("res://shaders/hero.gdshader")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("albedo_col", src.albedo_color)
			mat.set_shader_parameter("roughness", src.roughness)
			mat.set_shader_parameter("restyle", 1.0)
			if src.normal_enabled and src.normal_texture != null:
				mat.set_shader_parameter("normal_tex", src.normal_texture)
				mat.set_shader_parameter("normal_depth", src.normal_scale)
			m.set_surface_override_material(s, mat)

## Travelling garb over the old armour: hood + straw hat, mantle, robe panels, sash, bindings.
var garb: HeroGarb

func _dress() -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	garb = HeroGarb.new()
	garb.name = "Garb"
	add_child(garb)
	garb.build(skel, body)

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

func _setup_crumple() -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	crumple = Crumple.new()
	crumple.name = "Crumple"
	skel.add_child(crumple)                    # last modifier: runs after the arm IK
	crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
	crumple.active = false
	var knee := skel.find_bone("mixamorig_LeftLeg")
	if knee >= 0:
		var kp := skel.global_transform * skel.get_bone_global_rest(knee).origin
		_shin = clampf(kp.y - global_position.y, 0.3, 0.7)

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
		if lock_target != null:
			# locked: the mouse no longer steers the camera; a sharp sideways flick switches target
			_flick = _flick + event.relative.x if signf(event.relative.x) == signf(_flick) else event.relative.x
			_flick_t = 0.25
			if absf(_flick) > LOCK_FLICK_PX:
				switch_lock(signf(_flick))
				_flick = 0.0
			return
		_yaw -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, -1.2, 0.6)

# --- lock-on ---

## The point the camera and reticle aim at: upper chest of the target's hurt capsule.
static func lock_point(t: Node3D) -> Vector3:
	var cap: Array = t.hurt_capsule()
	return (cap[0] as Vector3).lerp(cap[1], 0.72)

func _lockable(t: Node) -> bool:
	return is_instance_valid(t) and t.is_inside_tree() and t.is_in_group("hittable") and t.has_method("hurt_capsule")

## Best target for a fresh lock: in range, nearest the camera's line of sight. Enemies are
## preferred; practice targets only when no enemy is in range. `exclude` is skipped;
## `side` != 0 limits the pick to targets on that side of the screen (switching).
func pick_lock_target(exclude: Node = null, side := 0.0) -> Node3D:
	var fwd := -cam_pivot.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var best: Node3D = null
	var best_score := INF
	for t in get_tree().get_nodes_in_group("hittable"):
		if t == exclude or not _lockable(t):
			continue
		var to: Vector3 = lock_point(t) - global_position
		to.y = 0.0
		var d := to.length()
		if d > LOCK_RANGE or d < 0.05:
			continue
		var ang := fwd.angle_to(to)
		if side != 0.0 and signf(to.dot(right)) != signf(side):
			continue
		if side == 0.0 and ang > 1.4 and d > 4.0:
			continue                          # behind the camera and not close: not what was meant
		var score := ang * 6.0 + d * 0.35 + (0.0 if t.is_in_group("enemy") else 100.0)
		if side != 0.0:
			score = absf(to.dot(right)) / d   # nearest neighbour on that side of the screen
		if score < best_score:
			best_score = score
			best = t
	return best

func toggle_lock() -> void:
	if lock_target != null:
		_set_lock(null)
		return
	var t := pick_lock_target()
	if t == null:
		# nothing to lock: recentre the camera behind the hero (a souls-like convention)
		_yaw = body.rotation.y + PI
		_pitch = -0.25
	_set_lock(t)

func switch_lock(side: float) -> void:
	if lock_target == null:
		return
	var t := pick_lock_target(lock_target, side)
	if t != null:
		_set_lock(t)

func _set_lock(t: Node3D) -> void:
	if t == lock_target:
		return
	lock_target = t
	lock_changed.emit(t)

## Called each physics tick: drops a dead or distant target (handing over to the next enemy in
## range), then swings the camera so the target sits ahead and a little below centre.
func _update_lock(delta: float) -> void:
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick = 0.0
	if lock_target == null:
		spring.spring_length = move_toward(spring.spring_length, 4.5, delta * 2.0)
		camera.position.x = move_toward(camera.position.x, CAM_SIDE, delta * 1.5)
		return
	if not _lockable(lock_target) or global_position.distance_to(lock_target.global_position) > LOCK_BREAK:
		var lost := lock_target
		lock_target = null
		var next := pick_lock_target(lost)
		if next != null and not next.is_in_group("enemy"):
			next = null
		lock_target = next
		lock_changed.emit(next)
		if next == null:
			return
	# over-the-shoulder: the camera slides further right so the hero stands left of frame and
	# the target is not hidden behind them; aim is solved from the camera's real position
	spring.spring_length = move_toward(spring.spring_length, 5.0, delta * 2.0)
	camera.position.x = move_toward(camera.position.x, CAM_SIDE_LOCKED, delta * 1.5)
	var aim := lock_point(lock_target)
	var pivot := global_position + cam_pivot.position
	var reach := spring.get_hit_length()
	if reach < 0.05:
		reach = spring.spring_length              # arm not yet resolved this frame
	var arm := Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3(camera.position.x, camera.position.y, reach)
	var to := aim - (pivot + arm)
	var flat := Vector2(to.x, to.z).length()
	var want_yaw := atan2(-to.x, -to.z)
	# look down past the hero at the target; closer targets need a steeper angle to fit both
	var want_pitch := clampf(atan2(to.y, maxf(flat, 0.5)) - 0.1 - 0.25 / maxf(flat, 1.0), -0.45, 0.12)
	var k := 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, want_yaw, k)
	_pitch = lerpf(_pitch, want_pitch, k)

func _physics_process(delta: float) -> void:
	if woke_t >= 0.0:
		woke_t += delta
		if woke_t > RESPAWN_FADE:
			woke_t = -1.0
	if dead_t >= 0.0:
		_dead_tick(delta)
		return
	var dir2 := bot_input if use_bot_input else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := (bot_sprint if use_bot_input else Input.is_action_pressed("sprint")) and stamina > 0.0
	var want_jump := bot_jump if use_bot_input else Input.is_action_just_pressed("jump")
	bot_jump = false
	var want_attack := bot_attack if use_bot_input else Input.is_action_just_pressed("attack_light")
	bot_attack = false
	var want_dodge := bot_dodge if use_bot_input else Input.is_action_just_pressed("dodge")
	bot_dodge = false
	var heavy_down := bot_heavy if use_bot_input else Input.is_action_pressed("attack_heavy")
	var want_heavy := heavy_down and not _heavy_was
	_heavy_was = heavy_down
	var want_lock := bot_lock if use_bot_input else Input.is_action_just_pressed("lock_on")
	bot_lock = false
	if want_lock:
		toggle_lock()
	_update_lock(delta)
	_update_slowmo(delta)
	var reeling := flinch_t >= 0.0
	if want_dodge and (not reeling or flinch_t >= FLINCH_DODGE_AT):
		_try_dodge(dir2)
		reeling = flinch_t >= 0.0
	if combat != null and want_attack and dodge_t < 0.0 and not reeling:
		combat.light()
	if combat != null:
		combat.heavy_held = heavy_down and not reeling
		if want_heavy and dodge_t < 0.0 and not reeling:
			combat.heavy()
	var attacking := combat != null and combat.is_attacking()
	var charging := combat != null and combat.is_charging()

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
	if reeling:
		flinch_t += delta
		var fu := flinch_t / FLINCH_TIME
		if fu >= 1.0:
			flinch_t = -1.0
			reeling = false
			model.transform = _model_rest
		else:
			# the shove decays as (1-u)^2 so it integrates to exactly FLINCH_PUSH
			var v := _flinch_dir * (FLINCH_PUSH * 3.0 / FLINCH_TIME) * (1.0 - fu) * (1.0 - fu)
			velocity.x = v.x
			velocity.z = v.z
			_pose_flinch(fu)
	if dodging:
		sprinting = false
	elif reeling:
		sprinting = false
	elif attacking:
		# committed to the swing: lunge along the facing, steering is only a nudge
		var face := body.global_transform.basis.z
		speed = 0.0
		var atk: Dictionary = combat.current_attack()
		var u: float = combat.t / float(atk["dur"])
		var hw: Array = atk["hit"]
		if u > float(atk.get("lunge_at", float(hw[0]) - 0.1)) and u < float(hw[1]) and not combat.target_in_reach(0.95):
			wish = face
			speed = atk["lunge"]
		sprinting = false
	elif charging:
		# planted under the raised staff: a slow shuffle to line it up
		speed = minf(speed, CHARGE_SPEED)
		sprinting = false
	elif combat != null and combat.is_drawn():
		speed = minf(speed, RUN_SPEED)   # weapon out: no sprint
	var target := wish * speed
	var accel := ACCEL
	if attacking and combat.current_attack().has("lunge_at"):
		accel = ACCEL * 4.0                    # the heavy's step-in is one decisive stride
	if not dodging and not reeling:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

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
	elif attacking or dodging or charging or reeling:
		pass                                   # no recovery mid-swing, mid-dodge, charging or reeling
	else:
		stamina = minf(stamina + 12.0 * delta, STAMINA_MAX)

	if reeling:
		pass                                   # rocked back: the facing holds
	elif dodging:
		if not _dodge_back:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(_dodge_dir.x, _dodge_dir.z), 1.0 - exp(-35.0 * delta))
	elif attacking:
		body.rotation.y += combat.spin_delta
		if lock_target != null and combat.t < 0.12 and combat.spin_delta == 0.0:
			# locked: every swing opens toward the target, whatever the stick says
			var lt := lock_target.global_position - global_position
			body.rotation.y = lerp_angle(body.rotation.y, atan2(lt.x, lt.z), 1.0 - exp(-30.0 * delta))
		elif combat.t < 0.08 and dir2.length() > 0.1:
			# a hit snaps toward the stick direction at its very start
			var cw := (right * dir2.x + fwd * -dir2.y)
			body.rotation.y = lerp_angle(body.rotation.y, atan2(cw.x, cw.z), 0.5)
		elif combat.t < 0.12 and combat.spin_delta == 0.0:
			# no stick: the swing's opening tracks the nearest target ahead (soft lock)
			var tgt := combat.magnet_target(3.4, 1.3)
			if tgt != Vector3.INF:
				var to := tgt - global_position
				body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-30.0 * delta))
	elif charging and lock_target != null:
		var lt := lock_target.global_position - global_position
		body.rotation.y = lerp_angle(body.rotation.y, atan2(lt.x, lt.z), 1.0 - exp(-10.0 * delta))
	elif charging and wish.length() < 0.1:
		var tgt := combat.magnet_target(4.0, 1.3)
		if tgt != Vector3.INF:
			var to := tgt - global_position
			body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
	elif wish.length() > 0.1:
		var yaw := atan2(wish.x, wish.z)
		body.rotation.y = lerp_angle(body.rotation.y, yaw, TURN_SPEED * delta)
	elif lock_target != null:
		# standing while locked: square up to the target
		var lt := lock_target.global_position - global_position
		body.rotation.y = lerp_angle(body.rotation.y, atan2(lt.x, lt.z), 1.0 - exp(-8.0 * delta))

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
	if flinch_t >= 0.0:
		flinch_t = -1.0
		model.transform = _model_rest
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

## Enemies call this when a strike would connect. Returns "parried", "perfect", "dodged" or "hit".
func receive_attack(attacker: Node, damage: float) -> String:
	if dead_t >= 0.0:
		return "miss"
	if combat != null and combat.try_parry(attacker):
		return "parried"
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
	hurt.emit(damage)
	if health <= 0.0:
		_die(attacker)
		return "hit"
	if combat != null and combat.has_hyper_armour():
		armoured_hits += 1
		add_shake(0.35)
		return "hit"
	add_shake(0.55)
	_flinch(attacker)
	return "hit"

func _flinch(attacker: Node) -> void:
	if combat != null:
		combat.cancel_to_guard()
	if dodge_t >= 0.0:
		dodge_t = -1.0                         # caught late in a dodge: the dash is lost
	var away := -body.global_basis.z
	if attacker is Node3D:
		away = global_position - (attacker as Node3D).global_position
	away.y = 0.0
	_flinch_dir = away.normalized() if away.length() > 1e-3 else -body.global_basis.z
	flinch_t = 0.0
	flinches += 1

## Snap the upper body away from the blow in ~0.06 s, then let it settle back over the rest
## of the stagger; pivot at the hip and sink a little so the feet stay under the body.
func _pose_flinch(u: float) -> void:
	var env := u / 0.12 if u < 0.12 else 1.0 - smoothstep(0.12, 1.0, u)
	env = sin(env * PI * 0.5)
	var push := body.global_basis.inverse() * _flinch_dir
	var axis := Vector3.UP.cross(push)
	if axis.length() < 1e-3:
		axis = Vector3.RIGHT
	# a little twist off the blow's side, so it does not read as a stiff bow
	var twist := deg_to_rad(9.0) * env * signf(push.x if absf(push.x) > 0.05 else 1.0)
	var hip := Vector3(0, 0.95, 0)
	var b := Basis(axis.normalized(), deg_to_rad(FLINCH_LEAN) * env) * Basis(Vector3.UP, twist)
	var t := Transform3D(Basis(), hip) * Transform3D(b, Vector3.ZERO) * Transform3D(Basis(), -hip)
	model.transform = Transform3D(Basis(), Vector3(0, -0.09 * env, 0)) * t * _model_rest

func is_dead() -> bool:
	return dead_t >= 0.0

func _die(attacker: Node) -> void:
	_flinch(attacker)                      # the blow's direction and the broken-off swing
	flinches -= 1
	flinch_t = -1.0
	_set_lock(null)
	if combat != null:
		combat.drop()                          # the hands let go: a drawn staff falls
	if crumple != null:
		crumple.active = true
	dead_t = 0.0
	deaths += 1
	add_shake(0.8)
	died.emit()

## Black over the screen: 0 alive, 1 at the bottom of a death; lifts again after waking.
func screen_black() -> float:
	if dead_t >= 0.0:
		return clampf((dead_t - DEATH_FADE_AT) / DEATH_FADE, 0.0, 1.0)
	if woke_t >= 0.0:
		var u := clampf(woke_t / RESPAWN_FADE, 0.0, 1.0)
		return 1.0 - u * u * (3.0 - 2.0 * u)
	return 0.0

func _dead_tick(delta: float) -> void:
	dead_t += delta
	_update_slowmo(delta)
	# the last shove carries the body a little, then friction holds it where it fell
	var shove := _flinch_dir * (FLINCH_PUSH * 3.0 / FLINCH_TIME) * maxf(1.0 - dead_t / FLINCH_TIME, 0.0) ** 2
	velocity.x = shove.x
	velocity.z = shove.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_pose_death(dead_t)
	if combat != null:
		combat.physics_step(delta)             # the dropped staff falls into the grass
	if anim_tree != null:
		# the stance runs down as the body gives out and is still once it hits the ground
		anim_tree.set("parameters/move/blend_position", 0.0)
		anim_tree.set("parameters/speed/scale", 1.0 - smoothstep(0.2, 1.0, dead_t))
	if dead_t >= DEATH_RESPAWN_AT:
		_respawn()

## Reel back from the blow, then the knees fold (Crumple bends the legs, so the hips drop by
## the shin's swing instead of the legs sinking into the ground) and the chest curls; then the
## body pitches forward about the knees, accelerating like a falling weight, the shins swinging
## back flat as it goes, the head turning aside, and it settles face-down with one small bounce.
func _pose_death(t: float) -> void:
	var reel := sin(minf(t / 0.1, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.1, 0.45, t))
	var kneel := smoothstep(0.12, 0.55, t)
	var x := clampf((t - 0.5) / 0.5, 0.0, 1.0)
	var fall := x * x
	if t > 1.0:
		fall = 1.0 - 0.06 * sin(clampf((t - 1.0) / 0.25, 0.0, 1.0) * PI)
	var pitch := deg_to_rad(80.0) * fall
	var knee_bend := deg_to_rad(95.0) * kneel
	if crumple != null:
		crumple.knee = maxf(knee_bend - pitch, deg_to_rad(10.0) * kneel)
		crumple.hip = deg_to_rad(18.0) * kneel * (1.0 - 0.7 * fall)
		crumple.spine = deg_to_rad(22.0) * kneel * (1.0 - 0.6 * fall)
		crumple.arm = deg_to_rad(25.0) * kneel * (1.0 - fall) - deg_to_rad(8.0) * fall
		crumple.elbow = deg_to_rad(30.0) * kneel
		crumple.head_turn = deg_to_rad(70.0) * smoothstep(0.6, 1.0, fall)
	var hip := Vector3(0, 0.95, 0)
	var push := body.global_basis.inverse() * _flinch_dir
	var axis := Vector3.UP.cross(push)
	if axis.length() < 1e-3:
		axis = Vector3.RIGHT
	var upper := Transform3D(Basis(), hip) * Transform3D(Basis(axis.normalized(), deg_to_rad(FLINCH_LEAN * 1.3) * reel), Vector3.ZERO) * Transform3D(Basis(), -hip)
	# the hips drop by the shin's swing, until the knee cap rests on the grass
	var sink := minf(_shin * (1.0 - cos(knee_bend)), _shin - 0.07)
	var knee := Vector3(0.0, _shin - sink, 0.06)
	var tip := Transform3D(Basis(), knee) * Transform3D(Basis(Vector3.RIGHT, pitch), Vector3.ZERO) * Transform3D(Basis(), -knee)
	model.transform = tip * Transform3D(Basis(), Vector3(0, -sink, 0)) * upper * _model_rest

func _respawn() -> void:
	dead_t = -1.0
	woke_t = 0.0
	global_position = respawn_point
	velocity = Vector3.ZERO
	health = HEALTH_MAX
	stamina = STAMINA_MAX
	model.transform = _model_rest
	body.rotation.y = respawn_yaw
	_yaw = respawn_yaw + PI                # camera behind the hero (body faces +Z)
	_trauma = 0.0
	if crumple != null:
		crumple.active = false
	if combat != null:
		combat.restore()                       # the staff is back on the back
	respawned.emit()

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
