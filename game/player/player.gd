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

var stamina := STAMINA_MAX
var bot_input := Vector2.ZERO           # bots drive this instead of Input
var bot_sprint := false
var bot_jump := false
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
	_setup_animation()
	_attach_staff()

## Out of combat the staff rides diagonally across the back (right shoulder to left hip),
## bound to the upper spine so it follows the torso's sway in every clip.
const STAFF_ON_BACK := Vector3(0.0, 1.28, -0.19)   # body space; body faces +Z
var staff: Staff

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
	anim_tree.set("parameters/speed/scale", ts)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, -1.2, 0.6)

func _physics_process(delta: float) -> void:
	var dir2 := bot_input if use_bot_input else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := (bot_sprint if use_bot_input else Input.is_action_pressed("sprint")) and stamina > 0.0
	var want_jump := bot_jump if use_bot_input else Input.is_action_just_pressed("jump")
	bot_jump = false

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
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if is_on_floor():
		if want_jump and stamina >= 8.0:
			velocity.y = JUMP_VEL
			stamina -= 8.0
	else:
		velocity.y -= GRAVITY * delta

	if sprinting and wish.length() > 0.1:
		stamina = maxf(stamina - 18.0 * delta, 0.0)
	else:
		stamina = minf(stamina + 12.0 * delta, STAMINA_MAX)

	if wish.length() > 0.1:
		var yaw := atan2(wish.x, wish.z)
		body.rotation.y = lerp_angle(body.rotation.y, yaw, TURN_SPEED * delta)

	move_and_slide()
	_update_animation(delta)

func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
