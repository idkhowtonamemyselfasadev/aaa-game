class_name Player
extends CharacterBody3D
## Third-person controller: walk/run/sprint, jump, stamina, orbit camera with collision.
## Combat, climbing and gliding.

const WALK_SPEED := 4.2
const RUN_SPEED := 6.5
const CHARGE_SPEED := 1.1       # shuffle while the heavy is raised
const SPRINT_SPEED := 9.0
const ACCEL := 14.0
const JUMP_VEL := 7.5
const GRAVITY := 22.0
# Jump: pressed up to JUMP_BUFFER before touchdown it still fires on landing; up to COYOTE
# after running off an edge it still leaves from the ground. Let go early and gravity bites
# harder (tap = a short hop ~0.6 m, hold = the full ~1.3 m). The way down is a little heavier
# than the way up, so the arc never floats. In the air the stick steers, but only gently.
const COYOTE := 0.12
const JUMP_BUFFER := 0.12
const PUSH_CROUCH := 0.05             # s of the take-off drawn sunk in the crouch it pushed from
const PUSH_LINE := 0.15               # s by which the extended push line has gathered into the tuck
const PUSH_DIP := 0.17                # m the hips are drawn low on the take-off frame
const JUMP_CUT_GRAVITY := 2.6        # x GRAVITY while rising with the button released
const FALL_GRAVITY := 1.3            # x GRAVITY on the way down
const AIR_ACCEL := 5.5               # m/s^2 of steering in the air (ACCEL on the ground)
const AIR_DRAG := 1.5                # m/s^2 lost in the air with the stick let go
const SPRINT_JUMP_BOOST := 1.6       # m/s added along the run when a sprint leaves the ground
const LAND_SOFT := 0.2               # s of knee give on an ordinary landing
const LAND_HARD := 0.45              # s crouched after a real drop (slowed, cannot jump)
const HARD_DROP := 2.2               # m fallen that makes a landing hard
const FALL_HURT := 7.0               # m fallen before the ground starts to hurt
const FALL_LETHAL := 22.0            # m fallen that kills outright
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
const KNOCK_LAND := 0.42              # seconds into a knockdown when the back hits the ground
const KNOCK_TIME := 1.85              # a heavy blow's knockdown: thrown, lying, back on the feet
# the get-up pushes off the near (left) hand: it goes to the turf beside the hip as the body
# begins to sit up, stays put while the trunk rises over it, and lets go as the squat takes the weight
const KNOCK_HAND := [0.92, 1.04, 1.30, 1.44]   # down_t: reach starts, planted, lifts, gone
const KNOCK_HAND_OUT := 0.26          # m out from the hip socket to the side
const KNOCK_HAND_BACK := 0.25         # m behind it (the body faces +Z, thrown toward -Z)
const KNOCK_LEAN := 0.32              # rad: the chest turns toward the pushing hand at full weight
const KNOCK_ROLL := 0.30              # rad: the body rolls onto the hand's hip (about the ground line under it)
const KNOCK_SIT := 0.40               # rad: less forward curl in the spine, the trunk leant back onto the arm
const KNOCK_KNEEL := [1.34, 1.54, 1.64, 1.82]   # down_t: the kneel forms, held, eases out in the rise
const KNOCK_KNEE_HAND := [1.44, 1.54, 1.70, 1.80]  # down_t: the right palm comes onto the front knee, braced, pushes, lets go
const KNOCK_SWING := [1.40, 1.56, 1.72, 1.85]  # down_t: the free left arm swings back by the hip as a counterweight, held, eases out
const KNOCK_SWING_ARM := 0.35          # rad (+ = forward, on top of the spine's forward curl): the upper arm hangs ~13 deg behind plumb
const KNOCK_SWING_ELBOW := 0.20        # rad: its forearm, a soft bend, the hand relaxed
const KNOCK_RELAX := [1.36, 1.50, 1.80, 1.85, 0.32]  # down_t in, held, out, gone; left fingers close this much (a relaxed hand, not the clip's open claw)
const KNOCK_KNEE_HAND_AT := Vector3(0.0, 0.07, -0.04) # m from the knee joint: up (over the kneecap), forward (- = back up the thigh)
const KNOCK_KNEEL_FRONT := 1.46       # down_t: the front (right) foot starts forward
const KNOCK_KNEEL_HIP := Vector2(-0.87, 0.52)   # rad on top of hip (left back under the body, right forward)
const KNOCK_KNEEL_KNEE := Vector2(-0.44, -0.52) # rad on top of knee (left shin laid back, right shin plumb)
const KNOCK_PUSH := 1.3               # metres the heavy blow throws the hero
const KNOCK_GUARD := Vector2(0.3, 1.6) # down_t window in which further blows pass over the body

# Death: the last blow rocks the hero back, the knees go and the body pitches face-down into
# the grass. The screen sinks to black over the still body, then the hero wakes at the last
# rest point at full vitality; the Hollows they were fighting return to their posts.
const DEATH_FADE_AT := 1.9            # seconds after the blow the screen starts to darken
const DEATH_FADE := 1.0               # seconds to full black
const DEATH_RESPAWN_AT := 3.4         # wake at the rest point (under full black)
const RESPAWN_FADE := 1.2             # seconds the black lifts over after waking

# Climbing: jump at a steep face (a rock, a ruin wall, a cottage gable) with the stick pushed
# into it and the hands catch hold. The stick then climbs up, down and across the face at a
# slow, stamina-hungry pace; jump heaves up a body length in one lunge, dodge lets go. At the
# top the hero hauls up over the lip onto the ledge. Out of stamina, the grip fails and they
# fall. A jump at a waist-high ledge vaults straight up onto it.
const CLIMB_SPEED := 1.35
const CLIMB_LOOK_UP := Vector2(0.18, 0.22)   # neck lift on the face, + more while a hand reaches
const CLIMB_LOOK_TURN := 0.32              # head turn toward the reaching hand (+ left)
const CLIMB_SURGE := Vector2(1.4, 0.55)   # speed x while every limb holds / while one reaches (`_climb_rhythm`)
const CLIMB_COST := 9.0               # stamina per second while moving on the face
const CLIMB_HOLD_COST := 1.5          # per second hanging still
const SQUARE_IN := 7.0                 # /s: hips and chest turn square to the stones/bar (~0.15 s)
const SQUARE_OUT := 3.5                # /s: back to the guard stance after (~0.3 s)
var _no_square := OS.has_environment("CLIMB_NOSQUARE")
const CLIMB_LUNGE_COST := 20.0
const CLIMB_LUNGE := 0.38             # seconds of the heave up
const CLIMB_LUNGE_SPEED := 4.2
const CLIMB_GAP := 0.38               # body origin off the face while climbing
const CLIMB_HIKE := 0.24              # rad: the stepping foot's hip hikes up (pelvis roll) while it steps
const CLIMB_FROG := 0.9               # pole weight: the stepping knee swings out to its side (frog step) while it steps
const CLIMB_SWAY := 0.10              # m: the hips sway out over the standing foot while the other one steps
const CLIMB_REACH := 0.75             # how far ahead a jump finds a face to catch
const CLIMB_STEEP := 0.5              # |normal.y| below this is a face, not a slope
# Jump off a face: jump with the stick pulled away from the stones (down/back, or hard to a side)
# kicks off it: up, out and toward the stick, the body twisting round to face the way it flies
const WALL_JUMP_UP := 7.0
const WALL_JUMP_OUT := 4.2             # m/s straight off the face at a full pull back
const WALL_JUMP_SIDE := 3.4            # m/s along the face at a full sideways push
const WALL_JUMP_COST := 14.0
const WALL_JUMP_TWIST := 0.32          # s of the turn from facing the stones to facing the flight
# the kick is pushed, not floated: the body first coils in against the stones on the holds
# (knees drawn up, hips sunk to the face, soles flat on their stones) for a few frames, then
# the legs drive straight out of the face while the soles are still on it
const WALL_KICK_COIL := 0.1            # s of the coil on the face before the push
const WALL_KICK_PUSH := 0.11           # s the soles stay on the stones as the legs straighten
const HAND_MOVE := 0.18               # seconds for a hand to reach to its next hold
# where a reaching hand feels for a stone round its reach, nearest first (the wider ring when a
# joint runs deep or a stone is set back further than the arm goes)
const HOLD_FEEL: Array[Vector2] = [Vector2.ZERO, Vector2(0.0, -0.08), Vector2(0.07, 0.0), Vector2(-0.07, 0.0),
	Vector2(0.0, 0.08), Vector2(0.0, -0.16), Vector2(0.14, -0.04), Vector2(-0.14, -0.04), Vector2(0.12, -0.14),
	Vector2(-0.12, -0.14), Vector2(0.0, -0.24), Vector2(0.2, -0.1), Vector2(-0.2, -0.1)]
const HOLD_REACH := 0.62              # m from the shoulder: a stone further off (a proud block, the crown) is no hold
const HAND_STEP := 0.3                # a hold this far from where the hand wants to be is let go
const FOOT_MOVE := 0.2                # seconds for a foot to step to its next hold
const FOOT_STEP := 0.24               # a toe hold this far from where the foot wants to be is left
const MANTLE_TIME := 0.6
var climbing := false
var climb_normal := Vector3.ZERO      # the face's outward normal under the hands
var climbs := 0                       # faces caught (bots read this)
var mantles := 0                      # ledges hauled up onto (bots read this)
var wall_jumps := 0                   # kicks off a face (bots read this)
var _wj_t := -1.0                     # s since the kick off a face (-1: none)
var _wk_coil := -1.0                  # s into the coil before a kick off a face (-1: none)
var _wk_dir := Vector2.ZERO           # the stick the kick was asked with
var kick_coils := 0                   # coils on the face before a kick (bots read this)
var kick_sole_err := 0.0              # (bots) worst m from an ankle to its stone through the coil + push
var false_drops := 0                  # catches that let go at once, the face gone under the hands (bots read this)
var refused_grabs := 0                # catches refused: a loose stone, not a face, met the reach (bots read this)
var _climb_t := 0.0                   # s on the current face
var _wj_yaw := Vector2.ZERO           # (from, to) body yaw of the twist off the face
var climbed := 0.0                    # metres moved on faces (bots read this; drives the reach cycle)
var climb_rate := 0.0                 # m/s moved on the face last tick (bots read this)
var mantle_t := -1.0                  # seconds into a haul-up, -1 when not mantling
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _lunge_t := -1.0
var _hold_missed := false              # the last _find_hold found no stone (it gave the face's plane)
var _lip_felt := false                 # a reaching hand found the top of the face (see _find_hold)
var climb_log := false                 # (bots) record every climb tick into climb_ticks
var climb_ticks: Array[Vector3] = []   # (bots) per climb tick: (rate m/s, neck lift, head turn)
var climb_sway: Array[Vector2] = []    # (bots) per climb tick: (standing foot: +1 right / -1 left / 0 both,
									   # posed hip centre m to the body's right of the origin)
var _no_sway := OS.has_environment("CLIMB_NOSWAY")   # (env) the old centred hips, for before/after
var climb_roll: Array[Vector2] = []    # (bots) per climb tick: (standing foot as climb_sway, posed left hip
									   # socket height minus the right one, m)
var _no_hike := OS.has_environment("CLIMB_NOHIKE")   # (env) the level pelvis, for before/after
var climb_knee: Array[Vector2] = []    # (bots) per climb tick: (standing foot as climb_sway, stepping knee's
									   # outward splay from its hip socket minus the standing knee's, m)
var _no_frog := OS.has_environment("CLIMB_NOFROG")   # (env) the knees kept in line, for before/after
var _frog := [0.0, 0.0]                # eased knee_out per leg
var _hike := 0.0                       # rad pelvis roll, + = the left hip up, eased
var _sway := 0.0                       # m to the body's right, eased
var _climb_surge := 1.0                # eased speed factor of the climb's push-and-reach rhythm
var _climb_even := OS.has_environment("CLIMB_EVEN")
var hand_moves := 0                   # times a hand let go of one hold for the next (bots read this)
var _hold := [Vector3.ZERO, Vector3.ZERO]       # world holds under the left and right hand
var _hold_from := [Vector3.ZERO, Vector3.ZERO]
var _mantle_hands := false
var _hold_t := [1.0, 1.0]             # 0..1 through a hand's move to its next hold, 1 = planted
var foot_moves := 0                   # times a foot stepped from one hold to the next (bots read this)
var _foot := [Vector3.ZERO, Vector3.ZERO]       # world toe holds under the left and right foot
var _foot_from := [Vector3.ZERO, Vector3.ZERO]
var _foot_t := [1.0, 1.0]             # 0..1 through a foot's step to its next hold, 1 = standing on it
var _regrab_t := 0.0                  # after letting go the hands cannot catch again for a moment
var _jumped := false                  # airborne from a jump (only a jump catches a face)

# Gliding: jump again in the air and the hero snaps Caelum's glider open overhead. It sinks
# slowly and flies on along the facing, the stick banking it round; jump or dodge lets go,
# landing or catching a face folds it, and it eats stamina until the arms give out.
const GLIDE_SPEED := 7.6              # m/s airspeed with the stick held
const GLIDE_SINK := 1.7               # m/s settled descent
const GLIDE_TURN := 1.9               # rad/s the most the facing swings round
const GLIDE_ACCEL := 5.0
const GLIDE_COST := 5.5               # stamina per second under the wing
const GLIDE_MIN_STAMINA := 6.0
const GLIDE_WIND_DIR := Vector3(0.8, 0.0, 0.6)   # the meadow wind (weather.gd slants the rain along it)
const GLIDE_DRIFT := Vector2(0.5, 3.7)           # m/s the wind carries the wing: still air .. storm
var gliding := false
var glides := 0                       # times the glider was opened (bots read this)
var glided := 0.0                     # metres flown under it (bots read this)
var glide_landings := 0               # touchdowns under the open wing (bots read this)
var glide_sink := 0.0                 # m/s down last tick (bots read this)
var glide_drift := Vector3.ZERO       # m/s the wind is carrying the wing (bots read this)
var glide_lift := 0.0                 # m/s of thermal air under the wing last tick (bots read this)
var glide_wind := -1.0                # bots/shots: force the wind 0..1 (< 0 reads the weather)
var _glide_t := 0.0
var glider: Glider

signal died
signal respawned
signal dodged(perfect: bool)
signal dash_started
signal hurt(amount: float)
signal fell(at: Vector3)              # a knockdown's back hits the ground (foley thud)
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
var health_max := HEALTH_MAX    # grows with quest rewards (Quests)
var stamina_max := STAMINA_MAX  # grows with quest rewards too
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
var down_t := -1.0                    # seconds into a knockdown, -1 while on the feet
var knockdowns := 0                   # heavy blows that threw the hero (bots read this)
var _knock_hand := Vector3.INF        # world wrist target of the get-up's planted hand (fixed once set)
var dead_t := -1.0                    # seconds since the killing blow, -1 while alive
var deaths := 0
var woke_t := -1.0                    # seconds since the last respawn (the black lifting)
var respawn_point := Vector3.ZERO     # set by the world: the last rest point
var respawn_yaw := 0.0
var crumple: Crumple                  # bone-level bends of the death fall (knees, spine, arms)
var stride_warp: StrideWarp           # lengthens the run clip's stride at pace (no foot skate)
var _shin := 0.45                     # knee height at rest, measured from the skeleton
var bot_dodge := false
var bot_input := Vector2.ZERO           # bots drive this instead of Input
var bot_sprint := false
var bot_jump := false
var bot_jump_hold := false              # bots: the jump button held down (variable height)
var _coyote_t := 99.0                   # s since the feet left the ground (not by a jump)
var _buffer_t := 99.0                   # s since jump was pressed and not yet used
var _air_t := -1.0                      # s airborne (-1 on the ground)
var _air_top := 0.0                     # highest y this time in the air
var _air_last_y := 0.0
var _prev_pos := Vector3.ZERO
var _jump_from_sprint := false
var land_t := -1.0                      # s into a landing (-1 none)
var _land_hard := false
var _land_plunge := false             # the landing was a plunge: deepest crouch, chest over the knees
var _land_dur := LAND_SOFT
var jumps := 0                          # (bots) jumps taken
## A leap off a foe's back, waiting out the hit-stop: a crown strike vaults the hero off the
## boss's shoulders; standing on any foe's head slides the hero off it the same way, smaller.
const VAULT_OUT := 5.5
const VAULT_UP := 6.0
var _vault := Vector3.ZERO
var _vault_big := false
var vaults := 0                         # (bots) leaps off a foe
var foe_slides := 0                     # (bots) times the hero was put off a foe's head
var landings := 0                       # (bots) touchdowns, and the last one's fall
var hard_landings := 0
var last_drop := 0.0
var _air_swung := false                 # a jump attack already thrown this time in the air
var jump_apex := 0.0                    # (bots) height of the last jump's top above its take-off
var _jump_y0 := 0.0
signal landed(at: Vector3, hard: bool)
var bot_attack := false
var bot_lock := false
var bot_heavy := false                  # heavy button held (bots)
var bot_interact := false
var interacts := 0                      # interact presses so far (talkers compare against it)
var _heavy_was := false
var use_bot_input := false
## A cinematic (a boss reveal) holds the camera elsewhere: the hero stands, no input reaches
## the body, and an attack/jump/interact press only asks the cinematic to skip.
var cinematic := false
var _cine_skip := false

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring: SpringArm3D = $CamPivot/SpringArm3D
@onready var camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
@onready var body: Node3D = $Body
@onready var model: Node3D = $Body/Model

# Locomotion: 1D blend idle -> walk -> run on horizontal speed, played faster when sprinting.
const ANIM_WALK_SPEED := 1.9            # m/s the Walk clip's stride covers at 1x
const ANIM_RUN_SPEED := 6.0             # m/s: the Run clip's point on the blend space
# m/s the Run clip's planted foot really travels back at 1x (measured 11-04 on the `stop` bot:
# at 6.5 m/s and 1.08x the flat foot slid forward 1.74 m/s, so the clip covers 4.40 m/s)
const RUN_STRIDE_SPEED := 4.4
const RUN_STRIDE_K := 1.25              # the stride is lengthened this much at a run (StrideWarp)
# Gaits (11-04 21:00, bot `stride`): the Walk and Run clips are not phase-synced, so a mix of the
# two skates (measured 1.5-2.4 m/s of slip at 3.9-5.5 m/s). The walk now holds to WALK_TOP and
# hands over to the run clip across a short band; a slower jog is the run clip with its stride
# SHORTENED (StrideWarp k < 1) and its cadence set from that stride, a faster run lengthens it.
const WALK_STRIDE_SPEED := 1.68         # m/s the Walk clip's planted foot travels back at 1x (measured)
const WALK_TOP := 2.6                   # m/s: the walk clip alone up to here
const JOG_FROM := 3.3                   # m/s: the run clip alone from here
const SPRINT_STRIDE_K := 1.25         # a sprint bounds: the stride lengthens again, the cadence less
const JOG_K := 0.82                     # the run clip's stride x this at JOG_FROM (a short jog)
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
	_setup_turn_lead()
	glider = Glider.new()
	glider.name = "Glider"
	body.add_child(glider)
	var gskel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if gskel != null:
		glider.stow_on(gskel, body)
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

## The head and chest lead a turn (same rig as the Hollow foes): a SpineTwist on the upper
## chest, neck and head, placed before the arm IK so a drawn staff stays in both hands.
const LEAD_BONES := ["mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]
const LEAD_SHARE := [0.10, 0.16, 0.32, 0.42]   # the head turns furthest, the chest a little
const LEAD_K := 0.75             # lead per radian still to turn
const LEAD_MAX := 0.8            # rad (~44 deg at the head, ~13 deg at the chest)
const LEAD_RATE := 20.0          # 1/s: the eyes go first, quicker than the body's TURN_SPEED
const LEAD_SETTLE := 7.0         # 1/s back to square once the body has caught up
var turn_lead := 0.0             # radians, positive toward the hero's left (SpineTwist sign)
var lead_peak := 0.0             # (bots) largest |turn_lead| since reset
var _turn_gap := 0.0             # yaw still to turn this tick (set by the facing code)
var _lead_twist: SpineTwist

func _setup_turn_lead() -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	_lead_twist = SpineTwist.new()
	_lead_twist.name = "TurnLead"
	_lead_twist.up = body
	_lead_twist.bones = LEAD_BONES
	_lead_twist.share = LEAD_SHARE
	skel.add_child(_lead_twist)
	var ik := skel.get_node_or_null("ArmIK")
	if ik != null:
		skel.move_child(_lead_twist, ik.get_index())

## Eases turn_lead toward the yaw still to turn; it settles back square, slower, as the body
## catches up. Off (eases to 0) whenever another pose owns the spine.
func _update_turn_lead(delta: float) -> void:
	var free := dead_t < 0.0 and down_t < 0.0 and not climbing and not gliding and pivot_t < 0.0
	var goal := clampf(_turn_gap * LEAD_K, -LEAD_MAX, LEAD_MAX) if free else 0.0
	var rate := LEAD_RATE if absf(goal) > absf(turn_lead) else LEAD_SETTLE
	turn_lead = lerpf(turn_lead, goal, 1.0 - exp(-rate * delta))
	if absf(turn_lead) < 1e-4:
		turn_lead = 0.0
	lead_peak = maxf(lead_peak, absf(turn_lead))
	if _lead_twist != null:
		_lead_twist.twist = turn_lead

func _setup_crumple() -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	if OS.get_environment("HERO_CLAWHANDS") == "":   # env HERO_CLAWHANDS: the before (the clip's own fingers)
		hand_rest = HandRest.new()
		hand_rest.name = "HandRest"
		skel.add_child(hand_rest)              # before Crumple: its fists and holds go on top
	crumple = Crumple.new()
	crumple.name = "Crumple"
	skel.add_child(crumple)                    # last modifier: runs after the arm IK
	crumple.frame = (body.global_basis.inverse() * skel.global_basis).orthonormalized()
	crumple.active = false
	stride_warp = StrideWarp.new()
	stride_warp.name = "StrideWarp"
	skel.add_child(stride_warp)
	# the modifiers run once per physics tick, right on the AnimationTree's pose (which is
	# advanced on physics too): on idle frames they ran 0 or 2 times a tick, so the contact
	# lock saw a foot that had not moved ("not falling") or missed the strike tick altogether
	if OS.get_environment("HERO_IDLEMOD") == "":
		skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	skel.move_child(stride_warp, 0)            # first modifier: it lengthens the clip's own stride
	stride_warp.frame = crumple.frame
	stride_warp.ground_body = self
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
	root.add_node("seek", AnimationNodeTimeSeek.new(), Vector2(100, 0))
	root.connect_node("seek", 0, "move")
	root.connect_node("speed", 0, "seek")
	root.connect_node("output", 0, "speed")
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(ap)
	anim_tree.tree_root = root
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true

var _warp := 0.0                       # 0..1 how much of the stride warp is on
var foot_lock_on := true               # (bots) the StrideWarp contact lock may be switched off
var foot_lock_lateral := OS.get_environment("HERO_NOLATERAL") == ""   # the lock also holds the boot across the legs' line (env HERO_NOLATERAL: the before)
var foot_strike_ease := OS.get_environment("HERO_NOSTRIKE") == ""   # a falling boot is eased onto its predicted strike point (env HERO_NOSTRIKE: the before)

func _update_warp(delta: float, on: bool) -> void:
	var warp := clampf((_blend - ANIM_WALK_SPEED) / (ANIM_RUN_SPEED - ANIM_WALK_SPEED), 0.0, 1.0) if on else 0.0
	# the contact lock: on while the clip strides on the turf (any gait), off under posed legs
	var lock := 1.0 if foot_lock_on and on and Vector2(velocity.x, velocity.z).length() > 0.5 else 0.0
	if crumple != null and crumple.active:
		warp *= 1.0 - clampf(crumple.leg_aim, 0.0, 1.0)
		lock *= 1.0 - clampf(crumple.leg_aim * 2.0, 0.0, 1.0)
	if not is_on_floor() or climbing or gliding or dodge_t >= 0.0 or pivot_t >= 0.0 or stop_t >= 0.0 or start_t >= 0.0:
		warp = 0.0                             # a posed step owns the legs: let go at its own pace
		lock = 0.0
		_warp = move_toward(_warp, 0.0, delta * 15.0)
	if combat != null and (combat.is_attacking() or combat.is_plunging()):
		lock = 0.0                             # a lunge slides the feet on purpose
	_warp = move_toward(_warp, warp, delta * 6.0)
	if stride_warp != null:
		stride_warp.k = lerpf(1.0, run_stride_k(Vector2(velocity.x, velocity.z).length()), _warp)
		stride_warp.lock = move_toward(stride_warp.lock, lock, delta * 8.0)
		stride_warp.lock_lateral = foot_lock_lateral
		stride_warp.strike_ease = foot_strike_ease
		stride_warp.approach_fast = clampf((Vector2(velocity.x, velocity.z).length() - RUN_SPEED) / (SPRINT_SPEED - RUN_SPEED), 0.0, 1.0)

## Foot IK on uneven ground (StrideWarp ground feet): on while the hero stands or strides on
## the floor; off in the air, on a wall, under the wing, and under posed legs (Crumple).
var foot_ground_on := true              # (bots) the ground feet may be switched off

func _update_ground_feet(delta: float) -> void:
	if stride_warp == null:
		return
	var w := 1.0 if foot_ground_on and is_on_floor() and not climbing and not gliding and dead_t < 0.0 else 0.0
	if crumple != null and crumple.active:
		w *= 1.0 - clampf(crumple.leg_aim, 0.0, 1.0)
	stride_warp.ground_w = move_toward(stride_warp.ground_w, w, delta * (8.0 if w > stride_warp.ground_w else 12.0))

func _update_animation(delta: float) -> void:
	if anim_tree == null:
		return
	_update_ground_feet(delta)
	if gliding or dodge_t >= 0.0:
		_update_warp(delta, false)
	if gliding:
		# hanging under the wing: the legs trail loose, no stride
		_blend = lerpf(_blend, 0.0, 1.0 - exp(-8.0 * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		anim_tree.set("parameters/speed/scale", 0.6)
		return
	if dodge_t >= 0.0:
		# dash-step: the run stride at a high cadence; the hop back plays the walk in reverse
		_blend = lerpf(_blend, ANIM_WALK_SPEED if _dodge_back else ANIM_RUN_SPEED, 1.0 - exp(-30.0 * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		anim_tree.set("parameters/speed/scale", -1.7 if _dodge_back else 1.9)
		return
	if flinch_t >= 0.0 and is_on_floor() and flinch_steps_on:
		# shoved by the blow: the walk played backwards at the shove's own pace, so the feet
		# take stagger steps back under the body instead of skating forward strides
		_update_warp(delta, false)
		var hv := Vector3(velocity.x, 0.0, velocity.z)
		_blend = lerpf(_blend, ANIM_WALK_SPEED, 1.0 - exp(-25.0 * delta))
		anim_tree.set("parameters/move/blend_position", _blend)
		var fs := maxf(hv.length() / clip_stride_speed(), 0.35)
		if hv.dot(body.global_basis.z) > 0.3 * hv.length():
			fs = -fs                           # struck from behind: stumbling forward, the walk runs on
		anim_tree.set("parameters/speed/scale", 0.0 if combat != null and combat.hitstop > 0.0 else -fs)
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() and (_jumped or _air_t > 0.15):
		hspeed = 0.0                             # in the air the jump pose owns the legs: no stride
	# turning on the spot: short steps (the walk at a third of its reach, quick cadence)
	var goal := maxf(gait_blend(hspeed), turn_shuffle * ANIM_WALK_SPEED * 0.45)
	var blend_k := 10.0
	if start_t >= 0.0 and start_t > START_TIME * 0.15:
		goal = ANIM_RUN_SPEED                  # the legs are posed: put the clip on the run alone
		blend_k = 20.0
		if not _start_seeked and start_t >= START_TIME * START_SEEK_U:
			# the stride phase where the driven knee's foot is just coming through ahead
			_start_seeked = true
			var t0 := RUN_RIGHT_CROSS if start_swing > 0.0 else RUN_LEFT_CROSS
			anim_tree.set("parameters/seek/seek_request", fposmod(t0 + START_SEEK_LEAD, RUN_CLIP_LEN))
	if pivot_t >= 0.0 and pivot_t > PIVOT_TIME * PIVOT_RUN_U:
		goal = ANIM_RUN_SPEED                  # the drive is posed: the run alone waits under the legs
		blend_k = 20.0
		if not _pivot_seeked and pivot_t >= PIVOT_TIME * PIVOT_SEEK_U:
			# put the stride where the drive leg's partner (the foot NOT planted) is coming through
			# ahead, so the clip takes over the very step the pose is in, not a scissor of the legs
			_pivot_seeked = true
			var t1 := RUN_LEFT_CROSS if _pivot_turn > 0.0 else RUN_RIGHT_CROSS
			anim_tree.set("parameters/seek/seek_request", fposmod(t1 + PIVOT_SEEK_LEAD, RUN_CLIP_LEN))
	_blend = lerpf(_blend, goal, 1.0 - exp(-blend_k * delta))
	anim_tree.set("parameters/move/blend_position", _blend)
	# Between blend points cadence follows speed/blend, so feet don't skate.
	var ts := 1.0
	# the run: the stride is lengthened (StrideWarp) and the cadence set so the planted foot
	# travels back exactly as fast as the body goes forward; faded out under any posed legs
	_update_warp(delta, true)
	if hspeed > 0.2:
		ts = maxf(hspeed / clip_stride_speed(), 0.6)
	if turn_shuffle > 0.05 and hspeed < 0.6:
		ts = lerpf(ts, 1.25, turn_shuffle)
	if pivot_t >= 0.0:
		# the planted legs are posed: the clip's arms slow; once seeked, the run's cadence picks
		# up over the pose's fade so the stride comes out from under the drive at running pace
		ts = 0.5
		if _pivot_seeked:
			ts = lerpf(0.5, 1.0, smoothstep(0.72, 1.0, pivot_t / PIVOT_TIME))
	elif stop_t >= 0.0:
		ts = 0.6                               # likewise through the planted stop
	elif start_t >= 0.0:
		ts = 1.0                               # the posed step hides the clip until the seek
	if combat != null and combat.hitstop > 0.0:
		ts = 0.0                               # hit-stop: the whole body freezes in the contact
	anim_tree.set("parameters/speed/scale", ts)

## Blend position for a ground speed: walk point held to WALK_TOP, a short band to the run point.
func gait_blend(v: float) -> float:
	if v <= ANIM_WALK_SPEED:
		return v
	if v <= WALK_TOP:
		return ANIM_WALK_SPEED
	return lerpf(ANIM_WALK_SPEED, ANIM_RUN_SPEED, smoothstep(WALK_TOP, JOG_FROM, v))

## The run clip's stride scale (StrideWarp k) at a ground speed: short at a jog, long at a run.
func run_stride_k(v: float) -> float:
	if v > RUN_SPEED:
		return lerpf(RUN_STRIDE_K, SPRINT_STRIDE_K, smoothstep(RUN_SPEED, SPRINT_SPEED, v))
	return lerpf(JOG_K, RUN_STRIDE_K, smoothstep(JOG_FROM, RUN_SPEED, v))

## m/s the stance foot travels back at 1x cadence for the clip mix and the warp as they are now.
func clip_stride_speed() -> float:
	var w := clampf((_blend - ANIM_WALK_SPEED) / (ANIM_RUN_SPEED - ANIM_WALK_SPEED), 0.0, 1.0)
	var under := clampf(_blend / ANIM_WALK_SPEED, 0.05, 1.0)   # idle -> walk: the stride shrinks
	var base := lerpf(WALK_STRIDE_SPEED * under, RUN_STRIDE_SPEED, w)
	var k := stride_warp.k if stride_warp != null else 1.0
	return base * k

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
	if cinematic:
		return
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

## True once if a skip was asked for since the last call (BossIntro reads it).
func cinematic_skip_pressed() -> bool:
	var k := _cine_skip
	_cine_skip = false
	return k

# --- lock-on ---

## The point the camera and reticle aim at: upper chest of the target's hurt capsule.
static func lock_point(t: Node3D) -> Vector3:
	var cap: Array = t.hurt_capsule()
	return (cap[0] as Vector3).lerp(cap[1], 0.72)

## How big a lock target is (1 = human sized); bosses that grow report their size_scale.
static func lock_size(t: Node3D) -> float:
	var s = t.get("size_scale")
	return maxf(float(s), 1.0) if s != null else 1.0

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
	# a giant (a boss that grows) is framed whole: the arm pulls back and the aim drops from
	# its chest toward its middle so the camera lifts to look up at it instead of into it
	var big := lock_size(lock_target)
	spring.spring_length = move_toward(spring.spring_length, 5.0 + 1.7 * (big - 1.0), delta * (2.0 + big))
	camera.position.x = move_toward(camera.position.x, CAM_SIDE_LOCKED, delta * 1.5)
	var aim := lock_point(lock_target)
	if big > 1.2:
		var cap: Array = lock_target.hurt_capsule()
		aim = (cap[0] as Vector3).lerp(cap[1], lerpf(0.72, 0.42, clampf((big - 1.2) / 3.0, 0.0, 1.0)))
	var pivot := global_position + cam_pivot.position
	var reach := spring.get_hit_length()
	if reach < 0.05:
		reach = spring.spring_length              # arm not yet resolved this frame
	var arm := Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3(camera.position.x, camera.position.y, reach)
	var to := aim - (pivot + arm)
	var flat := Vector2(to.x, to.z).length()
	var want_yaw := atan2(-to.x, -to.z)
	# look down past the hero at the target; closer targets need a steeper angle to fit both
	var want_pitch := clampf(atan2(to.y, maxf(flat, 0.5)) - 0.1 - 0.25 / maxf(flat, 1.0), -0.45, 0.12 + 0.08 * (big - 1.0))
	var k := 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, want_yaw, k)
	_pitch = lerpf(_pitch, want_pitch, k)

## The fingers' pose (HandRest): relaxed at rest, closed round the shaft as the staff is drawn, and
## eased off whenever another pose owns the hands (climbing holds, the glider bar, a mantle, a fist).
const HAND_RATE := 10.0           # 1/s
var hand_rest: HandRest

func _update_hand_rest(delta: float) -> void:
	if hand_rest == null:
		return
	var owned := climbing or gliding or mantle_t >= 0.0 \
		or (crumple != null and crumple.active and (crumple.plant > 0.01 or crumple.grip > 0.01))
	var k := 1.0 - exp(-HAND_RATE * delta)
	hand_rest.weight = lerpf(hand_rest.weight, 0.0 if owned else 1.0, k)
	hand_rest.hold = lerpf(hand_rest.hold, combat._blend if combat != null else 0.0, k)

func _physics_process(delta: float) -> void:
	_update_hand_rest(delta)
	if woke_t >= 0.0:
		woke_t += delta
		if woke_t > RESPAWN_FADE:
			woke_t = -1.0
	if dead_t >= 0.0 or down_t >= 0.0 or climbing or mantle_t >= 0.0:
		_turn_gap = 0.0
		_update_turn_lead(delta)             # a turn caught mid-lead eases square
	if dead_t >= 0.0:
		_dead_tick(delta)
		return
	if down_t >= 0.0:
		_down_tick(delta)
		return
	var dir2 := bot_input if use_bot_input else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := (bot_sprint if use_bot_input else Input.is_action_pressed("sprint")) and stamina > 0.0
	var want_jump := bot_jump if use_bot_input else Input.is_action_just_pressed("jump")
	bot_jump = false
	var jump_held := bot_jump_hold if use_bot_input else Input.is_action_pressed("jump")
	var want_attack := bot_attack if use_bot_input else Input.is_action_just_pressed("attack_light")
	bot_attack = false
	var want_dodge := bot_dodge if use_bot_input else Input.is_action_just_pressed("dodge")
	bot_dodge = false
	var heavy_down := bot_heavy if use_bot_input else Input.is_action_pressed("attack_heavy")
	var want_heavy := heavy_down and not _heavy_was
	_heavy_was = heavy_down
	var want_lock := bot_lock if use_bot_input else Input.is_action_just_pressed("lock_on")
	bot_lock = false
	if (bot_interact if use_bot_input else Input.is_action_just_pressed("interact")):
		interacts += 1
	bot_interact = false
	if cinematic:
		_cine_skip = _cine_skip or want_attack or want_jump or want_heavy or want_dodge
		dir2 = Vector2.ZERO
		sprinting = false
		want_jump = false
		want_attack = false
		want_dodge = false
		want_heavy = false
		heavy_down = false
		want_lock = false
	if want_lock and not climbing and mantle_t < 0.0:
		toggle_lock()
	_update_lock(delta)
	_regrab_t -= delta
	_ease_square(delta)
	if climbing or mantle_t >= 0.0:
		cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
		_climb_tick(delta, dir2, want_jump, want_dodge)
		return
	_update_slowmo(delta)
	# a press in the air opens the wing only clear of the ground and past coyote time;
	# nearer the ground it waits as a buffered jump for the touchdown
	if gliding or (want_jump and _coyote_t > COYOTE and _can_glide() and _clear_below(1.6)):
		if not gliding:
			_air_t = -1.0
			land_t = -1.0
			_clear_jump_pose()
		_turn_gap = 0.0
		_update_turn_lead(delta)
		_glide_tick(delta, dir2, want_jump, want_dodge)
		return
	if want_jump:
		_buffer_t = 0.0
	else:
		_buffer_t += delta
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
	var plunging := combat != null and combat.is_plunging()
	var air_move := combat != null and combat.legs_free()

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
	elif plunging:
		speed = 0.0
		sprinting = false
	elif charging:
		# planted under the raised staff: a slow shuffle to line it up
		speed = minf(speed, CHARGE_SPEED)
		sprinting = false
	elif combat != null and combat.is_drawn():
		speed = minf(speed, RUN_SPEED)   # weapon out: no sprint
	var landing := land_t >= 0.0
	if landing and _land_hard:
		speed = minf(speed, WALK_SPEED * 0.6)  # the knees soak a real drop: a slow first step
		sprinting = false
	_pivot_step(delta, wish, attacking or charging or plunging or dodging or reeling or landing)
	_stop_step(delta, wish, attacking or charging or plunging or dodging or reeling or landing)
	_start_step(delta, wish, attacking or charging or plunging or dodging or reeling or landing)
	var target := wish * speed
	var accel := ACCEL
	if start_t >= 0.0 and start_t < START_TIME * 0.8:
		accel = ACCEL * START_BOOST            # the drive leg throws the body into the first stride
	if attacking and combat.current_attack().has("lunge_at"):
		accel = ACCEL * 4.0                    # the heavy's step-in is one decisive stride
	var airborne := not is_on_floor() and not dodging
	if airborne and (not attacking or air_move):
		# carried by the take-off: the stick bends the arc, it does not reverse it; a sprint
		# leap keeps its speed rather than braking to the run's
		var hv := Vector2(velocity.x, velocity.z)
		var cap := maxf(speed, hv.length())
		target = wish * cap
		accel = AIR_ACCEL if wish.length() > 0.1 else AIR_DRAG
		if air_move and combat.is_air_attack() and combat.t < 0.36 and not combat.target_in_reach(0.95) \
				and combat.magnet_target(3.6, 1.0) != Vector3.INF:
			# the jump attack carries the hero in onto a foe ahead, as the staff comes over
			target = body.global_transform.basis.z * maxf(cap, 3.2)
			accel = AIR_ACCEL * 3.0
	if plunging:
		# the hang: drift on, slowing; then straight down on the spot
		var damp := 6.0 if combat.plunge_t < StaffCombat.PLUNGE_HANG else 30.0
		velocity.x = move_toward(velocity.x, 0.0, damp * delta * maxf(absf(velocity.x), 1.0))
		velocity.z = move_toward(velocity.z, 0.0, damp * delta * maxf(absf(velocity.z), 1.0))
	elif pivot_t >= 0.0:
		var pv := _pivot_velocity(wish * speed)
		velocity.x = pv.x
		velocity.z = pv.z
	elif stop_t >= 0.0 and not _stop_cancel:
		var sv := _stop_velocity()
		velocity.x = sv.x
		velocity.z = sv.z
	elif not dodging and not reeling:
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if combat != null and combat.hitstop > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0

	# set down somewhere else (respawn, a bot): the old floor reading is stale, no ledge to leave
	var teleported := global_position.distance_to(_prev_pos) > 4.0
	_prev_pos = global_position
	if teleported:
		_coyote_t = 99.0
		_air_top = global_position.y
	if is_on_floor() and not teleported:
		if _air_t >= 0.0:
			_touch_down()
		_jumped = false
		if _wj_t >= 0.0 and crumple != null:
			crumple.foot_plant = 0.0
		_wj_t = -1.0
		_coyote_t = 0.0
	else:
		if _air_t < 0.0:
			_air_t = 0.0
			_air_top = global_position.y
			_air_last_y = global_position.y
		_air_t += delta
		if absf(global_position.y - _air_last_y) > 4.0:
			_air_top = global_position.y           # teleported (respawn, a bot): not a fall
		_air_top = maxf(_air_top, global_position.y)
		_air_last_y = global_position.y
		if not _jumped:
			_coyote_t += delta
		if _wj_t >= 0.0:
			_wj_t += delta
			_kick_push()
		var g := GRAVITY
		if velocity.y < 0.0:
			g *= FALL_GRAVITY
		elif _jumped and not jump_held:
			g *= JUMP_CUT_GRAVITY                  # let go early: the hop is cut short
		velocity.y -= g * delta
		if plunging:
			if combat.plunge_t < StaffCombat.PLUNGE_HANG:
				velocity.y = move_toward(velocity.y, 0.0, 40.0 * delta)   # held at the top: the tell
			else:
				velocity.y = -StaffCombat.PLUNGE_SPEED
		elif air_move and combat.t < 0.2 and velocity.y < 0.0:
			velocity.y = maxf(velocity.y, -1.2)    # the jump attack hangs a beat over the apex
		if _jumped:
			jump_apex = maxf(jump_apex, global_position.y - _jump_y0)
	var can_leave := ((is_on_floor() and not teleported) or (_coyote_t <= COYOTE and not _jumped)) \
		and not (landing and _land_hard) and not dodging and not reeling and not attacking and not charging and not plunging
	if _buffer_t <= JUMP_BUFFER and can_leave and stamina >= 8.0:
		_buffer_t = 99.0
		velocity.y = JUMP_VEL
		stamina -= 8.0
		_jumped = true
		_coyote_t = 99.0
		jumps += 1
		jump_apex = 0.0
		_jump_y0 = global_position.y
		land_t = -1.0
		_jump_from_sprint = sprinting and wish.length() > 0.3
		if wish.length() > 0.3:
			# the take-off pushes off toward the stick: a standing jump at a wall reaches it
			var hv0 := Vector2(velocity.x, velocity.z)
			var hw := Vector2(wish.x, wish.z) * speed
			if hv0.length() < hw.length():
				hv0 = hv0.lerp(hw, 0.6)
				velocity.x = hv0.x
				velocity.z = hv0.y
		if _jump_from_sprint:
			var hv := Vector3(velocity.x, 0.0, velocity.z)
			var along := hv.normalized() if hv.length() > 0.5 else wish.normalized()
			velocity += along * SPRINT_JUMP_BOOST
		if _air_t < 0.0:
			_air_t = 0.0
			_air_top = global_position.y

	if sprinting and wish.length() > 0.1:
		stamina = maxf(stamina - 18.0 * delta, 0.0)
	elif attacking or dodging or charging or reeling or plunging:
		pass                                   # no recovery mid-swing, mid-dodge, charging or reeling
	else:
		stamina = minf(stamina + 12.0 * delta, stamina_max)

	_turn_gap = 0.0
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
	elif _wj_t >= 0.0 and _wj_t < WALL_JUMP_TWIST:
		# off a face: the body twists round from the stones to the flight, eased in and out
		var tw := smoothstep(0.0, WALL_JUMP_TWIST, _wj_t)
		body.rotation.y = lerp_angle(_wj_yaw.x, _wj_yaw.y, tw)
	elif pivot_t >= 0.0:
		# the plant holds the old facing, then the body spins over the planted foot
		body.rotation.y = _pivot_from + _pivot_turn * smoothstep(PIVOT_SPIN.x, PIVOT_SPIN.y, pivot_t / PIVOT_TIME)
	elif wish.length() > 0.1:
		var yaw := atan2(wish.x, wish.z)
		_turn_gap = angle_difference(body.rotation.y, yaw)
		body.rotation.y = _step_capped(lerp_angle(body.rotation.y, yaw, TURN_SPEED * delta), delta)
	elif not is_nan(bot_square_yaw):
		# (shots) a scripted square-up to a world yaw, stepped like the locked one
		_turn_gap = angle_difference(body.rotation.y, bot_square_yaw)
		body.rotation.y = _step_capped(lerp_angle(body.rotation.y, bot_square_yaw, 1.0 - exp(-8.0 * delta)), delta)
	elif lock_target != null:
		# standing while locked: square up to the target
		var lt := lock_target.global_position - global_position
		_turn_gap = angle_difference(body.rotation.y, atan2(lt.x, lt.z))
		body.rotation.y = _step_capped(lerp_angle(body.rotation.y, atan2(lt.x, lt.z), 1.0 - exp(-8.0 * delta)), delta)

	if _jumped and not is_on_floor() and not dodging and not reeling and not attacking and not charging and not plunging and _regrab_t <= 0.0 and wish.length() > 0.3:
		if _try_grab(wish.normalized()):
			return
	if _vault != Vector3.ZERO and (combat == null or combat.hitstop <= 0.0):
		var k := 1.0 if _vault_big else 0.6
		velocity = _vault * VAULT_OUT * k + Vector3.UP * VAULT_UP * k
		_vault = Vector3.ZERO
		vaults += 1 if _vault_big else 0
		_jumped = true
		_coyote_t = 99.0
		_buffer_t = 99.0
		land_t = -1.0
		_air_t = -1.0                          # off the foe next frame: a fresh flight, no touchdown now
		jump_apex = 0.0
		_jump_y0 = global_position.y
		if combat != null:
			combat.end_plunge_rise()
	var y_pre := global_position.y
	var floor_pre := is_on_floor()
	_step_climb(delta)
	move_and_slide()
	_step_settle(y_pre, floor_pre, delta)
	_put_off_foes()
	_update_animation(delta)
	_jump_pose(delta, (attacking and not air_move) or charging or dodging or reeling, attacking or plunging)
	_pivot_pose()
	_stop_pose()
	_start_pose()
	_flinch_layer()
	_weight_lean(delta, dodging or reeling, attacking or charging or plunging or not is_on_floor())
	_update_turn_lead(delta)
	if combat != null:
		combat.physics_step(delta)

# --- step-up: stair treads, plinth courses, kerbs ---
## Walking into a riser no taller than STEP_H lifts the hero onto the tread (StepUp); the
## visible body and the camera are let down by the lift and ease up through it, so the
## climb reads as a step taken and not a pop. `steps_up` counts them (bots).
const STEP_H := 0.38
var steps_up := 0
var step_rise := 0.0           # bots: the last step's rise
var _step_dip := 0.0           # visible body/camera off the root (m: < 0 below after a step up, > 0 held above after a step down)
var _cam_base_y := NAN

func _step_climb(delta: float) -> void:
	if is_nan(_cam_base_y):
		_cam_base_y = cam_pivot.position.y
	var lift := 0.0
	if not climbing and not gliding:
		lift = StepUp.try(self, delta, STEP_H)
	if lift > 0.0:
		steps_up += 1
		step_rise = lift
	_step_dip = StepUp.ease_dip(_step_dip, Vector2(velocity.x, velocity.z).length(), delta, 1.0)
	body.position.y = _step_dip
	cam_pivot.position.y = _cam_base_y + _step_dip * 0.8

## The lift and the slide's own ride over a lip's corner (the capsule's round bottom) both
## raise the root: a grounded root that rose more in one tick than the slope under it would
## lift it is let down by the excess, which then eases out (StepUp.ease_dip).
func _step_settle(y_pre: float, floor_pre: bool, delta: float) -> void:
	if not floor_pre or velocity.y > 0.5 or climbing or gliding:
		return
	var excess := StepUp.lip_excess(self, global_position.y - y_pre, delta, 1.0)
	# off a tread edge or a kerb: set down on the lower tread (no fall), the hips held and let down
	excess -= StepUp.step_down(self, y_pre, delta, STEP_H, 1.0) if not _jumped else 0.0
	if excess != 0.0:
		_step_dip = clampf(_step_dip - excess, -STEP_H - 0.05, STEP_H + 0.05)
		body.position.y = _step_dip
		cam_pivot.position.y = _cam_base_y + _step_dip * 0.8

# --- locomotion weight: the body leans into what the feet are doing ---
## Pivoting at the soles, the whole figure tips forward into a start (the push of the first
## strides), back against a stop (the heels digging in), and banks into the inside of a turn,
## as much as the speed times the turn rate asks for. Both ride an under-damped spring, so a
## stop rocks back, overshoots forward over the planted feet and settles. Standing and turning
## on the spot, the feet shuffle round with short steps instead of the body pivoting on frozen
## soles.
const LEAN_ACCEL := 0.024              # rad of forward pitch per m/s^2 along the facing
const LEAN_RUN := 0.035                # rad held forward at full sprint (the chest over the stride)
const LEAN_MAX := 0.17                 # ~10 deg either way
const BANK_K := 0.045                  # rad of roll per m/s^2 of sideways (centripetal) push
const BANK_MAX := 0.2                  # ~11 deg
const LEAN_W := 13.0                   # spring stiffness (rad/s): weight shifts in ~0.12 s
const LEAN_ZETA := 0.42                # under-damped: one visible overshoot, then still
var lean := Vector2.ZERO               # x: pitch (+ forward), y: roll (+ toward the body's right)
var _lean_v := Vector2.ZERO
var _lean_hv := Vector2.ZERO           # last tick's ground velocity
var _lean_yaw := 0.0
var _pose_dip := 0.0                   # what the jump/landing pose sank the model this tick
var lean_peak := Vector2.ZERO          # (bots) most forward / most back pitch seen
var _turn_sh := 0.0                    # the shuffle the turn rate wants this tick
var turn_shuffle := 0.0                # 0..1 stepping on the spot while the body turns
const TURN_STEP_RATE := 6.0            # rad/s: on the spot the body comes round only as fast as the feet step it
const TURN_STILL := 0.6                # m/s: below this the hero is turning on the spot, not running a curve
var bot_square_yaw := NAN             # (shots) square up to this yaw standing, as if locked
var turn_rate_peak := 0.0              # (bots) fastest on-the-spot turn seen, rad/s
## On the spot the turn is what the shuffle can step (~345 deg/s, a 180 in ~0.5 s): the head
## lead and the stepping feet get time to read instead of a near-snap. Running curves are free.
func _step_capped(want: float, delta: float) -> float:
	if Vector2(velocity.x, velocity.z).length() >= TURN_STILL or not is_on_floor():
		return want
	var cap := TURN_STEP_RATE * delta
	var d := clampf(angle_difference(body.rotation.y, want), -cap, cap)
	turn_rate_peak = maxf(turn_rate_peak, absf(d) / maxf(delta, 1e-4))
	if stride_warp != null:
		if stride_warp.pivot <= 0.0 and absf(d) > 1e-3:
			stride_warp.pivot_side = 0 if d > 0.0 else 1   # turning left (yaw up): plant the left foot
		if stride_warp.pivot_pin != null and stride_warp.pivot > 0.0:
			# the body comes round over the planted foot, not about its own middle
			# about the pin's sideways offset only (a staggered stance's fore-aft offset turns
			# under the body instead), so a 180 moves the hero ~0.2 m, not a stroll
			var side := body.global_basis.x
			side = Vector3(side.x, 0.0, side.z).normalized()
			var off := clampf((stride_warp.pivot_pin - global_position).dot(side), -PIVOT_REACH, PIVOT_REACH)
			var r := -side * off
			var orbit := (r.rotated(Vector3.UP, d) - r) * stride_warp.pivot
			if orbit.length() > 1e-5 and orbit.length() < 0.2:
				move_and_collide(orbit)
				pivot_orbit += orbit.length()
	return body.rotation.y + d
var pivot_orbit := 0.0                 # (bots) m the body has swung round planted feet
const PIVOT_REACH := 0.11              # m: the most the body's middle orbits off the pivot foot
## The planted pivot foot of a turn on the spot: in while the feet step round, out once square.
func _update_pivot_foot(delta: float, standing: bool) -> void:
	if stride_warp == null:
		return
	var want := stride_warp.pivot_want(1.0 if standing and turn_shuffle > 0.05 else 0.0, standing, delta)
	# squared up (the body no longer turning): the turn step comes down where it is
	if stride_warp.pivot <= 0.0 or (standing and _turn_sh > 0.3):
		stride_warp.pivot_settle = false
	elif standing and _turn_sh <= 0.0:
		stride_warp.pivot_settle = true
	stride_warp.stance_idle = standing and turn_shuffle <= 0.0 and Vector2(velocity.x, velocity.z).length() < 0.05
	stride_warp.pivot = move_toward(stride_warp.pivot, want, delta * (10.0 if want > stride_warp.pivot else 5.0))
func _weight_lean(delta: float, owned: bool, calm: bool) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	var yaw := body.rotation.y
	var yaw_rate := wrapf(yaw - _lean_yaw, -PI, PI) / maxf(delta, 1e-4)
	var acc := (hv - _lean_hv) / maxf(delta, 1e-4)
	_lean_hv = hv
	_lean_yaw = yaw
	var want := Vector2.ZERO
	if not calm and not owned and combat != null and combat.hitstop <= 0.0:
		var face := body.global_transform.basis.z
		var f2 := Vector2(face.x, face.z)
		var a_fwd := acc.dot(f2)
		var spd := hv.length()
		want.x = clampf(a_fwd * LEAN_ACCEL + LEAN_RUN * clampf((spd - RUN_SPEED * 0.6) / (SPRINT_SPEED - RUN_SPEED * 0.6), 0.0, 1.0),
			-LEAN_MAX, LEAN_MAX)
		# centripetal push: speed x turn rate (turning left = yaw up = lean left, toward -roll)
		want.y = clampf(-spd * clampf(yaw_rate, -6.0, 6.0) * BANK_K, -BANK_MAX, BANK_MAX)
		if pivot_t >= 0.0:
			want.y *= 0.25                     # spun over a planted foot, not banked round a curve
	# spring-damper toward the wanted lean, integrated in two half steps for stability
	for i in 2:
		var h := delta * 0.5
		var a := (want - lean) * LEAN_W * LEAN_W - _lean_v * 2.0 * LEAN_ZETA * LEAN_W
		_lean_v += a * h
		lean += _lean_v * h
	lean.x = clampf(lean.x, -LEAN_MAX * 1.2, LEAN_MAX * 1.2)
	lean.y = clampf(lean.y, -BANK_MAX * 1.2, BANK_MAX * 1.2)
	lean_peak = Vector2(maxf(lean_peak.x, lean.x), minf(lean_peak.y, lean.x))
	# standing and turning: shuffle steps (read by _update_animation next tick)
	var standing := is_on_floor() and hv.length() < 0.6 and not owned and not calm
	var sh := clampf((absf(yaw_rate) - 1.2) / 3.0, 0.0, 1.0) if standing else 0.0
	_turn_sh = sh
	turn_shuffle = move_toward(turn_shuffle, sh, delta * (8.0 if sh > turn_shuffle else 3.0))
	_update_pivot_foot(delta, standing)
	if owned:
		return                                 # the dodge / flinch pose writes the model itself
	# through a planted stop the feet stay where they struck: the rock back and forward is taken
	# at the hip joints (the trunk leans over still legs), not by tipping the whole figure
	var pitch := lean.x * (1.0 - _stop_env) * (1.0 - _start_env)
	if crumple != null and _stop_posed:
		crumple.pelvis = lean.x * _stop_env
	elif crumple != null and _start_posed:
		crumple.pelvis = lean.x * _start_env
	# the driving start pushes straight off the toes: the bank comes in after the first stride
	var tip := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, lean.y * (1.0 - _start_env) * (1.0 - _stop_env))
	model.transform = Transform3D(Basis(), Vector3(0, -_pose_dip, 0)) * Transform3D(tip, Vector3.ZERO) * _model_rest

# --- the run pivot: plant, spin, drive ---
## Reversing the stick at a run no longer swings the hero round a wide lerped arc. The foot on
## the outside of the turn is thrown ahead and planted; the hero skids down onto it with the
## knees bent and the chest held up (the lean spring rocks the body back against the brake),
## spins 180 degrees over that foot while still low, and drives off the other leg into the new
## direction with the chest forward. A turn left plants the right foot, and the other way round.
const PIVOT_TIME := 0.44               # s from the plant to the first full stride the other way
const PIVOT_MIN_SPEED := 4.6           # m/s along the facing: a jog or faster
const PIVOT_DOT := -0.55               # the stick at least ~123 deg from the facing
const PIVOT_BRAKE := 0.42              # u at which the skid has bled off the old speed
const PIVOT_SPIN := Vector2(0.22, 0.66) # u over which the body spins round
const PIVOT_DRIVE := 0.5               # u from which the legs drive the other way
const PIVOT_DIP := 0.16                # m the hips sink over the planted foot
var pivot_t := -1.0                    # s into a pivot (-1 none)
var pivots := 0                        # (bots)
var pivot_skid := 0.0                  # (bots) m slid along the old line during the last pivot
var _pivot_from := 0.0
var _pivot_turn := 0.0                 # signed radians the body spins (+: to the hero's left)
var _pivot_v0 := Vector3.ZERO          # ground velocity at the plant
var _pivot_p0 := Vector3.ZERO
var _pivot_seeked := false
var pivot_handoff := 0.0               # (bots) clip_ahead x the free foot's side when the pose let go
const PIVOT_RUN_U := 0.45              # u from which the clip is put on the run alone
const PIVOT_SEEK_U := 0.5              # u at which the run clip is seeked under the posed drive
const PIVOT_SEEK_LEAD := -0.02          # s past the free foot's crossing: furthest ahead mid-fade

func _pivot_step(delta: float, wish: Vector3, busy: bool) -> void:
	if pivot_t >= 0.0:
		pivot_t += delta
		var old := _pivot_v0.normalized()
		pivot_skid = maxf(pivot_skid, (global_position - _pivot_p0).dot(old))
		if pivot_t >= PIVOT_TIME or busy or not is_on_floor() or climbing or gliding:
			_end_pivot()
		return
	if busy or climbing or gliding or lock_target != null or not is_on_floor() or _jp > 0.05 or wish.length() < 0.5:
		return
	var face := body.global_basis.z
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.dot(face) < PIVOT_MIN_SPEED or wish.normalized().dot(face) > PIVOT_DOT:
		return
	pivot_t = 0.0
	pivots += 1
	pivot_skid = 0.0
	pivot_twist_peak = 0.0
	pivot_head_peak = 0.0
	pivot_head_lead = 0.0
	pivot_body_lead = 0.0
	pivot_handoff = 0.0
	pivot_drive_peak = 0.0
	_pivot_seeked = false
	_pivot_v0 = hv
	_pivot_p0 = global_position
	_pivot_from = body.rotation.y
	var turn := wrapf(atan2(wish.x, wish.z) - _pivot_from, -PI, PI)
	if absf(turn) > PI * 0.97:
		turn = PI                              # dead behind: round to the left over the right foot
	_pivot_turn = turn

## Ground velocity through the pivot: the old run bleeds off along its line as the planted foot
## skids, then the drive leg pushes off along the stick.
func _pivot_velocity(goal: Vector3) -> Vector3:
	var u := pivot_t / PIVOT_TIME
	var brake := 1.0 - smoothstep(0.0, PIVOT_BRAKE, u)
	var drive := smoothstep(PIVOT_DRIVE, 1.0, u)
	return _pivot_v0 * brake * brake + goal * drive * 0.85

func _end_pivot() -> void:
	if crumple != null and pivot_t >= PIVOT_TIME:
		pivot_handoff = crumple.clip_ahead * -signf(_pivot_turn)
	pivot_t = -1.0

var _pivot_posed := false
var pivot_twist_peak := 0.0            # (bots) largest signed chest twist of the last pivot
var pivot_head_peak := 0.0             # (bots) largest signed head turn of the last pivot
var pivot_head_lead := 0.0             # (bots) u at which the head turn passed half its peak
var pivot_body_lead := 0.0             # (bots) u at which the body yaw passed half its turn
var pivot_drive_peak := 0.0            # (bots) largest weight of the posed drive (free knee up)

func _pivot_pose() -> void:
	if pivot_t < 0.0 or crumple == null or _jp > 0.0 or dead_t >= 0.0 or down_t >= 0.0:
		if _pivot_posed and crumple != null:
			# hand the upper body back clean to whatever poses next
			crumple.chest_twist = 0.0
			crumple.arm_sweep = 0.0
			crumple.clasp = 0.0
			crumple.head_turn = 0.0
			crumple.hip_lr = Vector2.ZERO
			crumple.knee_lr = Vector2.ZERO
			crumple.ankle_lr = Vector2.ZERO
			_pivot_posed = false
		return
	var u := pivot_t / PIVOT_TIME
	var env := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.72, 1.0, u))
	var sg := signf(_pivot_turn)           # + plants the right leg (stride + carries it forward)
	# the plant leg is thrown ahead into the skid; over the spin the other comes through to drive
	var lead := lerpf(0.42, -0.3, smoothstep(PIVOT_SPIN.x, PIVOT_SPIN.y + 0.1, u))
	var sink := sin(PI * clampf(u / 0.75, 0.0, 1.0)) * (1.0 - 0.4 * smoothstep(0.5, 1.0, u))
	var dip := PIVOT_DIP * sink
	var a := acos(clampf(1.0 - dip / 0.9, -1.0, 1.0))
	# chest held up against the brake, then over the knees on the drive
	var spine := lerpf(-0.06, 0.3, smoothstep(PIVOT_DRIVE - 0.1, 0.9, u))
	crumple.active = true
	crumple.leg_aim = env
	crumple.hip = a * 1.15 * env
	crumple.knee = a * 2.0 * env
	crumple.stride = lead * sg * env
	# the drive: the planted leg (now behind) sweeps back and pushes off its toes, while the free
	# knee is punched up and through, so the fade hands the legs to the (seeked) run clip mid-swing
	# instead of lifting a planted foot 0.3 m in five ticks
	var dv := smoothstep(PIVOT_DRIVE - 0.02, 0.84, u) * env
	var th_p := -0.32 * dv
	var kn_p := 0.08 * dv
	var an_p := 0.85 * dv                  # heel up: off the ball of the foot
	var th_f := 0.62 * dv
	var kn_f := 1.05 * dv
	var an_f := -0.15 * dv                 # toes pulled up under the shin
	var rp := sg > 0.0                     # the right leg planted
	crumple.hip_lr = Vector2(th_f, th_p) if rp else Vector2(th_p, th_f)
	crumple.knee_lr = Vector2(kn_f, kn_p) if rp else Vector2(kn_p, kn_f)
	crumple.ankle_lr = Vector2(an_f, an_p) if rp else Vector2(an_p, an_f)
	pivot_drive_peak = maxf(pivot_drive_peak, dv)
	crumple.spine = spine * env
	crumple.arm = lerpf(0.5, 0.25, smoothstep(0.3, 0.8, u)) * env   # the arms come out for balance
	crumple.elbow = 0.55 * env
	crumple.ankle = 0.0
	crumple.sole_flat = env                # the soles grip flat through the skid
	# the upper body leads the turn: the head snaps round to the new line first, the shoulders
	# wind round ahead of the hips (the arms flung out wide and swept across), then the chest
	# unwinds a touch past square as the hips come through onto the drive leg
	var spin := smoothstep(PIVOT_SPIN.x, PIVOT_SPIN.y, u)
	var head := sg * 0.75 * smoothstep(0.08, 0.3, u) * (1.0 - smoothstep(0.42, 0.78, u))
	var wind := sg * (0.55 * smoothstep(0.12, 0.36, u) * (1.0 - smoothstep(0.4, 0.74, u)) \
		- 0.12 * smoothstep(0.62, 0.78, u) * (1.0 - smoothstep(0.82, 1.0, u)))
	crumple.head_turn = head
	crumple.chest_twist = wind
	# the arms trail behind the turn at the plant, then whip through across the body with it
	crumple.arm_sweep = sg * lerpf(-0.35, 0.55, smoothstep(0.18, 0.5, u)) * env * (1.0 - smoothstep(0.6, 0.95, u))
	crumple.clasp = -0.55 * smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.45, 0.85, u))
	_pivot_posed = true
	if absf(wind) > absf(pivot_twist_peak):
		pivot_twist_peak = wind
	if absf(head) > absf(pivot_head_peak):
		pivot_head_peak = head
	if pivot_head_lead == 0.0 and absf(head) >= 0.375:
		pivot_head_lead = u
	if pivot_body_lead == 0.0 and spin >= 0.5:
		pivot_body_lead = u
	if garb != null:
		garb.posed_legs = true
	_pose_dip = dip * env

# --- the planted stop: one foot thrown ahead, the weight caught over it ---
## Letting go of the stick at a run no longer coasts the hero to a halt on even feet. The foot
## that was already ahead in the stride is thrown further out and struck heel first, the leg
## braced with the knee a little bent; the back knee folds and its heel lifts onto the ball of
## the foot, the hips drop over the gap and the chest is held up against the brake (the lean
## spring rocks the body back), the arm opposite the front leg swings forward for balance.
## Then the weight rolls over the front foot, the back foot steps up beside it and the body
## rises and settles. Pushing the stick again lets go at once: the legs ease back in ~0.15 s.
const STOP_TIME := 0.55                # s from the release to standing square
const STOP_MIN_SPEED := 4.6            # m/s along the facing: a jog or faster
const STOP_BRAKE := 0.45               # u at which the skid has bled off the run
var stop_t := -1.0                     # s into a planted stop (-1 none)
var stops := 0                         # (bots)
var stop_slide := 0.0                  # (bots) m slid along the run line during the last stop
var stop_lead := 0.0                   # +1 the right foot is thrown ahead, -1 the left
var stop_dip_peak := 0.0               # (bots) deepest the hips sank in the last stop
var _stop_v0 := Vector3.ZERO
var _stop_p0 := Vector3.ZERO
var _stop_w := 1.0                     # eases to 0 when the stick comes back mid-stop
var _stop_cancel := false
var _stop_posed := false
var _stop_env := 0.0                   # how much of the lean is taken at the hips, not the soles

func _stop_step(delta: float, wish: Vector3, busy: bool) -> void:
	if stop_t >= 0.0:
		if not _stop_cancel:
			stop_t += delta
			stop_slide = maxf(stop_slide, (global_position - _stop_p0).dot(_stop_v0.normalized()))
			if wish.length() > 0.5:
				_stop_cancel = true
		if _stop_cancel:
			_stop_w = move_toward(_stop_w, 0.0, delta * 7.0)
		if stop_t >= STOP_TIME or _stop_w <= 0.0 or busy or not is_on_floor() or climbing or gliding or pivot_t >= 0.0:
			stop_t = -1.0
		return
	if busy or climbing or gliding or pivot_t >= 0.0 or not is_on_floor() or _jp > 0.05 or wish.length() > 0.2:
		return
	var face := body.global_basis.z
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.dot(face) < STOP_MIN_SPEED:
		return
	stop_t = 0.0
	stops += 1
	stop_slide = 0.0
	stop_dip_peak = 0.0
	_stop_v0 = hv
	_stop_p0 = global_position
	_stop_w = 1.0
	_stop_cancel = false
	stop_lead = -1.0 if OS.has_environment("FORCE_LEFT") else _foot_ahead()

## +1 when the right foot is further forward along the body's facing in the pose as drawn, -1
## for the left: the foot already reaching out in the stride is the one that plants.
func _foot_ahead() -> float:
	var skel := crumple.get_skeleton() if crumple != null else null
	if skel == null:
		return 1.0
	var l := skel.find_bone("mixamorig_LeftFoot")
	var r := skel.find_bone("mixamorig_RightFoot")
	if l < 0 or r < 0:
		return 1.0
	var fwd := (crumple.frame.inverse() * Vector3.BACK).normalized()
	var d := (skel.get_bone_global_pose(r).origin - skel.get_bone_global_pose(l).origin).dot(fwd)
	return 1.0 if d >= 0.0 else -1.0

## The run bleeds off along its line over the first part of the stop (~0.6 m from a run).
func _stop_velocity() -> Vector3:
	var b := 1.0 - smoothstep(0.0, STOP_BRAKE, stop_t / STOP_TIME)
	return _stop_v0 * b * b

func _stop_pose() -> void:
	if stop_t < 0.0 or pivot_t >= 0.0 or crumple == null or _jp > 0.0 or dead_t >= 0.0 or down_t >= 0.0:
		if _stop_posed and crumple != null:
			crumple.hip_lr = Vector2.ZERO
			crumple.knee_lr = Vector2.ZERO
			crumple.ankle_lr = Vector2.ZERO
			crumple.arm_lr = Vector2.ZERO
			crumple.pelvis = 0.0
			crumple.ground = 0.0
			crumple.settle = 0
			_stop_env = 0.0
			_stop_posed = false
			if pivot_t < 0.0 and _jp <= 0.0:
				_clear_jump_pose()
		return
	var u := stop_t / STOP_TIME
	var env := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.62, 1.0, u)) * _stop_w
	# how far the front leg is out: thrown in the first frames, held through the brake, then
	# the back foot steps up beside it
	var reach := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.45, 0.9, u))
	# the knee soaks the strike: a bump peaking a third of the way through
	var absorb := sin(PI * clampf((u - 0.08) / 0.5, 0.0, 1.0))
	var th_f := 0.1 + 0.36 * reach + 0.1 * absorb       # front thigh ahead of plumb
	var kn_f := 0.08 + 0.26 * reach + 0.2 * absorb      # braced, the knee giving a little
	var th_b := 0.1 - 0.38 * reach                      # back thigh behind
	var kn_b := 0.1 + 0.5 * reach                       # folded, the heel up
	# heel strike: the front toes up as it lands, rolling flat by a third of the way in
	var an_f := -0.28 * reach * (1.0 - smoothstep(0.15, 0.4, u))
	var an_b := 0.8 * reach                             # onto the ball of the back foot
	var r := stop_lead > 0.0                            # the right foot is the front one
	crumple.active = true
	crumple.leg_aim = env
	crumple.hip = 0.0
	crumple.knee = 0.0
	crumple.stride = 0.0
	crumple.ankle = 0.0
	crumple.sole_flat = env
	crumple.hip_lr = (Vector2(th_b, th_f) if r else Vector2(th_f, th_b)) * env
	crumple.knee_lr = (Vector2(kn_b, kn_f) if r else Vector2(kn_f, kn_b)) * env
	crumple.ankle_lr = (Vector2(an_b, an_f) if r else Vector2(an_f, an_b)) * env
	# the arm opposite the front leg swings forward, the other back; both lift a touch for balance
	crumple.arm_lr = (Vector2(0.45, -0.25) if r else Vector2(-0.25, 0.45)) * reach * env
	crumple.arm = 0.2 * absorb * env
	crumple.elbow = 0.45 * env
	# chest held up against the brake, then rolling forward over the front foot, then still
	crumple.spine = (-0.1 * smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.25, 0.45, u)) \
		+ 0.12 * smoothstep(0.3, 0.5, u) * (1.0 - smoothstep(0.6, 0.95, u))) * env
	_stop_posed = true
	if garb != null:
		garb.posed_legs = true
	# the legs set the height: the hips are moved so the lower ankle stays on the turf
	crumple.ground = env
	crumple.settle = 1 if r else 2              # the back foot reaches down onto its ball
	_pose_dip = 0.0
	_stop_env = env
	stop_dip_peak = maxf(stop_dip_peak, crumple.ground_drop)

# --- the driving start: off one leg into the first stride ---
## Pushing the stick hard from a standstill no longer slides the hero up to speed on the run
## clip. The hips sink a touch to load, the chest tips over the feet, then one leg drives: it
## straightens behind the body and pushes off its toes (the heel comes up, the toes stay on the
## turf) while the other knee is thrown up and forward and the opposite arm punches through.
## The run clip is hurried round underneath so that when the pose hands the legs back, the clip
## is already striding with that knee's foot ahead: no scissor of the legs at the hand-off.
## Turning off the line, the leg on the outside of the turn drives; straight ahead they alternate.
const START_TIME := 0.45               # s from the push to the clip owning the legs again
const START_MAX_SPEED := 1.2           # m/s: only from (nearly) standing
const START_STICK := 0.75              # stick at least this far: a walk eases off as before
const START_BOOST := 1.35              # x ACCEL over the drive
var start_t := -1.0                    # s into a driving start (-1 none)
var starts := 0                        # (bots)
var start_swing := 1.0                 # +1 the right knee is driven up (the left leg pushes), -1 the left
var start_handoff := 0.0               # (bots) clip_ahead x the swing side when the pose let go
var _start_posed := false
var _start_env := 0.0
var _start_seeked := false
var _start_cool := 0.0                 # s before another start may fire
var starts_enabled := true             # (bots) off where a test's scripted approach predates the start
const START_SEEK_U := 0.5              # u at which the run clip is seeked under the posed legs
const START_SEEK_LEAD := 0.05          # s past the crossing: the foot already a little ahead
# the Run clip (0.70 s): t at which each foot comes through level with the other going ahead
# (measured from the clip; the right foot is furthest ahead at 0.53 s, the left at 0.20 s)
const RUN_CLIP_LEN := 0.7
const RUN_RIGHT_CROSS := 0.35
const RUN_LEFT_CROSS := 0.01

func _start_step(delta: float, wish: Vector3, busy: bool) -> void:
	_start_cool = maxf(_start_cool - delta, 0.0)
	if start_t >= 0.0:
		start_t += delta
		if start_t >= START_TIME or busy or not is_on_floor() or climbing or gliding or pivot_t >= 0.0 \
				or stop_t >= 0.0 or wish.length() < 0.3:
			if crumple != null and start_t >= START_TIME:
				start_handoff = crumple.clip_ahead * start_swing
			start_t = -1.0
			_start_cool = 0.6
		return
	if not starts_enabled or busy or climbing or gliding or pivot_t >= 0.0 or stop_t >= 0.0 or lock_target != null \
			or not is_on_floor() or _jp > 0.05 or wish.length() < START_STICK:
		return
	if Vector2(velocity.x, velocity.z).length() > START_MAX_SPEED or _blend > ANIM_WALK_SPEED * 0.6:
		return
	if is_on_wall() or _start_cool > 0.0:
		return                                 # pressed against a face, or just had one: no new push
	start_t = 0.0
	starts += 1
	start_handoff = 0.0
	_start_seeked = false
	var turn := wrapf(atan2(wish.x, wish.z) - body.rotation.y, -PI, PI)
	if absf(turn) > 0.5:
		start_swing = -1.0 if turn > 0.0 else 1.0   # stepping off left: the right leg pushes, the left knee drives
	else:
		start_swing = 1.0 if starts % 2 == 1 else -1.0

func _start_pose() -> void:
	if start_t < 0.0 or pivot_t >= 0.0 or stop_t >= 0.0 or crumple == null or _jp > 0.0 or dead_t >= 0.0 or down_t >= 0.0:
		if _start_posed and crumple != null and (pivot_t >= 0.0 or stop_t >= 0.0):
			_start_env = 0.0                   # the pivot / stop pose has the legs now: leave its values
			_start_posed = false
			crumple.arm_aim = 0.0
			crumple.ground_toe = 0
		elif _start_posed and crumple != null:
			crumple.arm_aim = 0.0
			crumple.hip_lr = Vector2.ZERO
			crumple.knee_lr = Vector2.ZERO
			crumple.ankle_lr = Vector2.ZERO
			crumple.arm_lr = Vector2.ZERO
			crumple.pelvis = 0.0
			crumple.ground = 0.0
			crumple.ground_toe = 0
			_start_env = 0.0
			_start_posed = false
			if pivot_t < 0.0 and stop_t < 0.0 and _jp <= 0.0 and not climbing and mantle_t < 0.0 \
					and dead_t < 0.0 and down_t < 0.0:
				_clear_jump_pose()
		return
	var u := start_t / START_TIME
	var env := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.58, 1.0, u))
	# a short load (both knees give, the hips drop), then the drive
	var load := sin(PI * clampf(u / 0.32, 0.0, 1.0))
	var d := smoothstep(0.08, 0.5, u)
	var th_d := lerpf(0.06, -0.42, d)                   # drive thigh: swept back behind the hips
	var kn_d := lerpf(0.12, 0.06, d) + 0.22 * load      # loaded, then straight through the push
	var an_d := 1.0 * smoothstep(0.1, 0.42, u)          # off the toes: the heel comes up
	var th_s := lerpf(0.06, 0.95, d)                    # swing thigh: the knee thrown up and ahead
	var kn_s := lerpf(0.12, 1.3, smoothstep(0.05, 0.42, u)) + 0.1 * load
	var an_s := -0.18 * d                               # toes pulled up under the shin
	var r := start_swing > 0.0                          # the right knee drives, the left leg pushes
	crumple.active = true
	crumple.leg_aim = env
	crumple.hip = 0.0
	crumple.knee = 0.0
	crumple.stride = 0.0
	crumple.ankle = 0.0
	crumple.sole_flat = env
	crumple.hip_lr = (Vector2(th_d, th_s) if r else Vector2(th_s, th_d)) * env
	crumple.knee_lr = (Vector2(kn_d, kn_s) if r else Vector2(kn_s, kn_d)) * env
	crumple.ankle_lr = (Vector2(an_d, an_s) if r else Vector2(an_s, an_d)) * env
	# the arm opposite the driven knee punches forward, the other drives back; elbows bent to run
	var pump := smoothstep(0.05, 0.45, u)
	crumple.arm_aim = env                               # the clip's arms are hidden (it is seeked mid-start)
	crumple.arm_lr = (Vector2(0.75, -0.5) if r else Vector2(-0.5, 0.75)) * pump * env
	crumple.arm = 0.0
	crumple.elbow = lerpf(0.5, 1.15, pump) * env
	crumple.spine = (0.06 * load + 0.16 * d) * env      # chest over the feet, curled into the push
	_start_posed = true
	if garb != null:
		garb.posed_legs = true
	# the legs set the height: the drive foot's toes stay on the turf
	crumple.ground = env
	crumple.ground_toe = 1 if r else 2
	crumple.settle = 0
	_pose_dip = 0.0
	_start_env = env

# --- jumping ---

## A light press now throws the jump attack: up off a jump (or falling a while), not winged or on a wall.
func air_attack_ok() -> bool:
	return not is_on_floor() and _air_t >= 0.0 and (_jumped or _air_t > 0.15) and not gliding \
		and not climbing and mantle_t < 0.0 and not _air_swung and dodge_t < 0.0

func note_air_attack() -> void:
	_air_swung = true

func vault_off(away: Vector3, big: bool) -> void:
	if _vault == Vector3.ZERO or big:
		_vault = away
		_vault_big = big

## Nobody stands on a foe: a hero on a soldier's head or a giant's shoulders is put off it
## (unless a crown strike's vault is already waiting).
func _put_off_foes() -> void:
	if _vault != Vector3.ZERO or not is_on_floor() or (combat != null and combat.is_plunging()):
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var o := col.get_collider() as Node3D
		if o != null and o.is_in_group("enemy") and col.get_normal().y > 0.3:
			var away := global_position - o.global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.05 else -body.global_basis.z
			foe_slides += 1
			vault_off(away, false)
			return

## A heavy press now plunges: in the air with clear air under the feet.
func plunge_ok() -> bool:
	return not is_on_floor() and _air_t >= 0.0 and not gliding and not climbing and mantle_t < 0.0 \
		and dodge_t < 0.0 and _clear_below(StaffCombat.PLUNGE_MIN)

## True when nothing solid lies within `h` m below the feet.
func _clear_below(h: float) -> bool:
	return _ray(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * h).is_empty()

func _touch_down() -> void:
	var drop := _air_top - global_position.y
	var was_jump := _jumped or _air_t > 0.15
	_air_t = -1.0
	_air_swung = false
	var plunged := combat != null and combat.is_plunging()
	if plunged:
		combat.plunge_land(drop)
	if not was_jump and drop < 0.35:
		return                                 # a bump on a slope, not a landing
	landings += 1
	last_drop = drop
	_land_hard = drop >= HARD_DROP or plunged   # a plunge always lands in the deep crouch
	_land_plunge = plunged
	_land_dur = LAND_HARD if _land_hard else LAND_SOFT
	land_t = 0.0
	if _land_hard:
		hard_landings += 1
		add_shake(clampf(0.15 + 0.04 * drop, 0.0, 0.6))
	landed.emit(global_position, _land_hard)
	if drop > FALL_HURT and dead_t < 0.0:
		var dmg := health_max * clampf((drop - FALL_HURT) / (FALL_LETHAL - FALL_HURT), 0.0, 1.0)
		if plunged and drop < FALL_LETHAL:
			dmg *= 0.5                         # driven down on purpose: the staff takes half of it
		health = maxf(health - dmg, 0.0)
		hurt.emit(dmg)
		if health <= 0.0:
			_clear_jump_pose()
			_die(self)

## The body in the air and on landing, laid over the clip by the crumple modifier: the legs
## gather up under the hips on the rise (the leading knee higher), hang and reach for the
## ground as the fall gathers speed, then the knees give on touchdown, deeper after a real
## drop, with the chest folding over them and the arms swinging down for balance.
var _jp := 0.0                          # 0..1 how much the jump pose owns the legs
var _tuck := 0.0
func _jump_pose(delta: float, busy: bool, armed := false) -> void:
	if crumple == null or gliding or climbing or mantle_t >= 0.0 or dead_t >= 0.0 or down_t >= 0.0:
		return
	var air := _air_t >= 0.0 and (_jumped or _air_t > 0.15) and not busy
	if land_t >= 0.0:
		land_t += delta
		if land_t >= _land_dur:
			land_t = -1.0
	var landing := land_t >= 0.0 and not busy and not air
	var want := 1.0 if (air or landing) else 0.0
	var push := air and _jumped and _air_t < PUSH_CROUCH
	if push:
		_jp = 1.0                             # the take-off owns the legs from its first frame
	_jp = move_toward(_jp, want, delta * (14.0 if want > _jp else 8.0))
	_pose_dip = 0.0
	if _jp <= 0.0:
		if crumple.leg_aim > 0.0:
			_clear_jump_pose()
		return
	var k := 1.0 - exp(-18.0 * delta)
	var hip := 0.0
	var knee := 0.0
	var spine := 0.0
	var arm := 0.0
	var elbow := 0.0
	var stride := 0.0
	var dip := 0.0
	var ankle := 0.0
	var flat := 0.0
	if air:
		# take-off: the jump leaves at once, but the body shows the push that made it: the
		# first frames are drawn sunk into a crouch (feet still on the turf, hips low, chest
		# over the knees), the legs then drive out straight with the toes pointed and the arms
		# thrown up, and only then gather into the rising tuck
		var t_air := _air_t if _jumped else 1.0
		var crouch := 1.0 - smoothstep(0.0, PUSH_CROUCH, t_air)
		var line := 1.0 - smoothstep(PUSH_CROUCH, PUSH_LINE, t_air)   # the extended push line
		# up: a rising tuck (fast in, held over the apex); down: the legs open to reach
		var t_in := maxf(t_air - PUSH_CROUCH, 0.0) if _jumped else 0.0
		_tuck = lerpf(_tuck, clampf(t_in / 0.2, 0.0, 1.0) if _jumped else 0.25, k)
		var reach := clampf(-velocity.y / 9.0, 0.0, 1.0)
		var tk := _tuck * (1.0 - 0.7 * reach)
		hip = 0.95 * tk + 0.28 * reach
		knee = 1.35 * tk + 0.3 * reach
		spine = 0.12 * tk - 0.05 * reach
		arm = 0.55 * tk + 0.35 * reach          # arms come up and forward, then out for balance
		elbow = 0.6 * tk + 0.4
		stride = 0.22 * tk if _jumped else 0.0  # lead knee higher, the other arm forward
		if _jump_from_sprint:
			stride = 0.42 * tk                  # a running leap: a long split stride
		# toes trail pointed through the rise, then come up level as the legs reach for the ground
		ankle = 0.75 * line * (1.0 - crouch) + 0.25 * tk * (1.0 - reach) - 0.35 * (knee - hip) * reach
		arm = maxf(arm, 1.5 * line * (1.0 - crouch) + 0.2 * crouch)   # thrown up past the shoulders
		elbow = lerpf(elbow, 0.75, line * (1.0 - crouch))   # elbows bent, not reaching like a sleepwalker
		spine -= 0.06 * line * (1.0 - crouch)  # the chest opens up on the drive
		if _wj_t >= 0.0 and _wj_t < 0.24:
			# kicked off a face: the chest arches back away from the stones, the arms fling out
			# off the holds and the legs stay driven straight out of the kick before they gather
			var wk := 1.0 - smoothstep(0.08, 0.24, _wj_t)
			spine = lerpf(spine, -0.32, wk)
			arm = lerpf(arm, 1.9, wk)
			elbow = lerpf(elbow, 0.35, wk)
			hip = lerpf(hip, 0.15, wk)
			knee = lerpf(knee, 0.12, wk)
			ankle = lerpf(ankle, 0.7, wk)
		if crouch > 0.0:
			var a0 := acos(clampf(1.0 - PUSH_DIP * crouch / 0.9, -1.0, 1.0))
			# drawn down by the crouch and by what the capsule has already risen, so the
			# soles are still on the turf they push from
			dip = (PUSH_DIP + clampf(global_position.y - _jump_y0, 0.0, 0.3)) * crouch
			hip = lerpf(hip, a0 * 1.15, crouch)
			knee = lerpf(knee, a0 * 2.0, crouch)
			spine = lerpf(spine, 0.32, crouch)
			arm = lerpf(arm, -0.45, crouch)     # arms swung back behind the hips, ready to throw
			ankle *= 1.0 - crouch
			flat = crouch
	elif landing:
		var u := land_t / _land_dur
		# the knees give fast and come back slowly: a quick sink, then the body rises out of it
		var env := sin(PI * minf(u / 0.3, 1.0) * 0.5) * (1.0 - smoothstep(0.3, 1.0, u))
		var depth := 0.3 if _land_hard else 0.1
		if _land_plunge:
			depth = 0.42                       # driven in: the knees fold deep over the ferrule
		dip = depth * env
		# legs folding so the feet stay put under the lowered hips (2 x 0.45 m segments)
		var a := acos(clampf(1.0 - dip / 0.9, -1.0, 1.0))
		hip = a * 1.15
		knee = a * 2.0
		spine = (0.62 if _land_plunge else 0.45 if _land_hard else 0.18) * env
		arm = (0.5 if _land_hard else 0.2) * env
		elbow = 0.5 * env
		flat = 1.0                             # the soles stay flat on the turf as the knees give
		_tuck = 0.0
	if armed:
		arm = 0.0                              # the staff's IK owns the arms
		elbow = 0.0
		spine *= 0.5
	crumple.active = true
	crumple.leg_aim = _jp
	crumple.hip = lerpf(crumple.hip, hip * _jp, k)
	crumple.knee = lerpf(crumple.knee, knee * _jp, k)
	crumple.spine = lerpf(crumple.spine, spine * _jp, k)
	crumple.arm = lerpf(crumple.arm, arm * _jp, k)
	crumple.elbow = lerpf(crumple.elbow, elbow * _jp, k)
	crumple.stride = lerpf(crumple.stride, stride * _jp, k)
	crumple.ankle = lerpf(crumple.ankle, ankle * _jp, k)
	crumple.sole_flat = lerpf(crumple.sole_flat, flat * _jp, k)
	if push:
		# the push frames are drawn as posed, not eased in: the crouch only lasts a frame or two
		crumple.hip = hip
		crumple.knee = knee
		crumple.spine = spine
		crumple.arm = arm
		crumple.elbow = elbow
		crumple.ankle = ankle
		crumple.sole_flat = flat
	elif landing:
		# on the turf the soles are a contact, not a pose: they meet the ground flat at once
		crumple.ankle = 0.0
		crumple.sole_flat = _jp
	if garb != null:
		garb.posed_legs = true
	if not busy:
		model.transform = Transform3D(Basis(), Vector3(0, -dip, 0)) * _model_rest
		_pose_dip = dip

func _clear_jump_pose() -> void:
	if _jp > 0.0 and model != null:
		model.transform = _model_rest          # the take-off/landing dip goes with the pose
	_jp = 0.0
	_tuck = 0.0
	if crumple == null:
		return
	crumple.leg_aim = 0.0
	crumple.hip = 0.0
	crumple.knee = 0.0
	crumple.spine = 0.0
	crumple.arm = 0.0
	crumple.elbow = 0.0
	crumple.stride = 0.0
	crumple.ankle = 0.0
	crumple.sole_flat = 0.0
	crumple.hip_lr = Vector2.ZERO
	crumple.knee_lr = Vector2.ZERO
	crumple.ankle_lr = Vector2.ZERO
	crumple.arm_lr = Vector2.ZERO
	crumple.pelvis = 0.0
	crumple.ground = 0.0
	crumple.ground_toe = 0
	crumple.settle = 0
	crumple.active = false
	if garb != null:
		garb.posed_legs = false

# --- gliding ---

func _can_glide() -> bool:
	return not is_on_floor() and not climbing and mantle_t < 0.0 and dodge_t < 0.0 \
		and flinch_t < 0.0 and stamina >= GLIDE_MIN_STAMINA and glider != null \
		and not (combat != null and (combat.is_attacking() or combat.is_charging()))

func _glide_tick(delta: float, dir2: Vector2, want_jump: bool, want_dodge: bool) -> void:
	if not gliding:
		gliding = true
		glides += 1
		_glide_t = 0.0
		want_jump = false
		glider.want_open = true
		if combat != null:
			combat.cancel_to_guard()
		add_shake(0.12)                        # the cloth cracks open and takes the weight
	_glide_t += delta
	cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	var fwd := -cam_pivot.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam_pivot.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var wish := right * dir2.x + fwd * -dir2.y
	if wish.length() > 1.0:
		wish = wish.normalized()
	# the stick turns the facing at a glider's pace and the wing banks into the turn
	var turn := 0.0
	if wish.length() > 0.1:
		var dyaw := wrapf(atan2(wish.x, wish.z) - body.rotation.y, -PI, PI)
		turn = clampf(dyaw, -GLIDE_TURN * delta, GLIDE_TURN * delta)
		body.rotation.y += turn
	var facing := body.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var spd := GLIDE_SPEED if wish.length() > 0.1 else GLIDE_SPEED * 0.75
	# the wind carries the wing downwind, harder under a front, and its gusts shove the bar,
	# rock the wing and lift it for a moment
	var w := glide_wind
	if w < 0.0:
		var wx = get_parent().get("weather") if get_parent() else null
		w = wx.wind if wx else 0.0
	var gt := _glide_t + float(glides) * 7.3
	var gust := clampf(0.5 + 0.5 * sin(gt * 1.7) * sin(gt * 0.63 + 0.9) + 0.25 * sin(gt * 4.1), 0.0, 1.0)
	glide_drift = GLIDE_WIND_DIR * lerpf(GLIDE_DRIFT.x, GLIDE_DRIFT.y, w) * (0.7 + 0.6 * gust)
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(facing * spd + glide_drift, GLIDE_ACCEL * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	# rising air off sun-warmed rock: the core lifts the wing, the ring round it sinks, and the
	# edge of a column is rough
	var th = get_parent().get("thermals") if get_parent() else null
	glide_lift = th.lift_at(global_position) if th else 0.0
	var rough := clampf(absf(glide_lift) / Thermals.LIFT, 0.0, 1.0)
	var buffet := (sin(gt * 3.3) * 0.6 + sin(gt * 7.9 + 1.1) * 0.4) * maxf(w * (0.4 + 0.6 * gust), rough * 0.5)
	# bank into the turn, rocked by the buffet and leant a touch against a crosswind
	var bank_to := clampf(turn / maxf(GLIDE_TURN * delta, 1e-4), -1.0, 1.0) * 0.32 + buffet * 0.18 \
		- glide_drift.dot(body.global_basis.x) * 0.015
	glider.bank = lerpf(glider.bank, bank_to, 1.0 - exp(-4.0 * delta))
	glider.gust = maxf(w * gust, rough * 0.6)
	var vy_to := -GLIDE_SINK + 0.7 * w * gust + glide_lift
	if velocity.y > vy_to:
		velocity.y = maxf(velocity.y - GRAVITY * delta, vy_to)   # still rising off the jump
	else:
		# the wing bites hard and arrests the fall; rising air lifts it more gently
		velocity.y = move_toward(velocity.y, vy_to, (30.0 if velocity.y < -GLIDE_SINK else 4.0) * delta)
	glide_sink = -velocity.y
	# riding a core the arms only hold the bar: it tires them less
	stamina = maxf(stamina - GLIDE_COST * delta * (1.0 - 0.6 * clampf(glide_lift / Thermals.LIFT, 0.0, 1.0)), 0.0)
	if stamina <= 0.0 or ((want_jump or want_dodge) and _glide_t > 0.25):
		_end_glide(true)                       # let go: fall free
	elif wish.length() > 0.3 and _regrab_t <= 0.0:
		var cl := crumple.hand_curl if crumple != null else 0.4
		if crumple != null:
			crumple.hand_curl = 0.4
		if _try_grab(wish.normalized()):
			_end_glide(false)                  # flown onto a face: the hands take the stone
			return
		if crumple != null:
			crumple.hand_curl = cl
	var was := global_position
	move_and_slide()
	glided += (global_position - was).length()
	if gliding and is_on_floor():
		glide_landings += 1
		_end_glide(true)
	elif gliding:
		_glide_pose(delta)                     # after the move, so the fists sit on the bar where it is now
	_update_animation(delta)

## Both fists on the crossbar overhead (the wing's bank tips the bar), the legs hanging with
## the knees a little bent, the chest drawn up between the arms.
func _glide_pose(delta: float) -> void:
	if crumple == null:
		return
	crumple.active = true
	crumple.plant = minf(crumple.plant + delta * 7.0, 1.0)
	crumple.hand_curl = 1.0
	crumple.hand_wall = -body.global_basis.z
	var g := Glider.grips()
	for i in 2:
		crumple.hand_target[i] = glider.global_transform * glider.bar_transform() * (g[i] as Vector3)
	# the faster the air goes by, the further the legs trail back with the shins folded, the
	# back arching into it; they swing loose like a pendulum and kick when a gust or the edge of
	# a thermal shakes the wing
	var air := clampf((Vector3(velocity.x, 0.0, velocity.z) - glide_drift).length() / GLIDE_SPEED, 0.0, 1.0)
	var k := 1.0 - exp(-3.0 * delta)
	glider.fill = lerpf(glider.fill, clampf(air * 1.4 - 0.2, 0.0, 1.0), k)
	crumple.leg_aim = minf(crumple.leg_aim + delta * 3.0, 1.0)
	crumple.knee = lerpf(crumple.knee, 0.45 + 0.3 * air, k)
	crumple.hip = lerpf(crumple.hip, 0.12 - 0.44 * air, k)
	crumple.spine = lerpf(crumple.spine, -0.08 - 0.08 * air, k)
	var gt := _glide_t + float(glides) * 2.9
	crumple.stride = 0.07 * sin(gt * 2.1) + 0.03 * sin(gt * 3.7 + 1.1) \
		+ glider.gust * 0.11 * sin(gt * 6.3)
	if garb != null:
		garb.posed_legs = true                 # the robe panels follow the trailing legs
		garb.stream = lerpf(garb.stream, air, k)
		garb.flap = garb.stream * (0.7 + 0.6 * glider.gust)

func _end_glide(clear_pose: bool) -> void:
	gliding = false
	glider.want_open = false
	glider.bank = 0.0
	glider.gust = 0.0
	glider.fill = 0.4                         # the next unfurl starts slack and fills
	glide_drift = Vector3.ZERO
	if garb != null:
		garb.stream = 0.0
		garb.flap = 0.0
		if clear_pose:
			garb.posed_legs = false            # (onto a face the climb keeps them posed)
	if crumple != null:
		crumple.leg_aim = 0.0
	if clear_pose and crumple != null:
		crumple.plant = 0.0
		crumple.hand_curl = 0.4
		crumple.knee = 0.0
		crumple.hip = 0.0
		crumple.spine = 0.0
		crumple.stride = 0.0
		crumple.square = 0.0
		crumple.active = false

# --- climbing ---

## Casts a ray against the world (terrain, buildings, rocks; not the hero or the creatures).
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

## The top of a ledge just beyond a face (outward normal n), if there is a standing surface
## within reach of the hands: casts down from above the lip, a little in from the face.
func _ledge_top(n: Vector3, reach_up: float) -> Variant:
	var flat := Vector3(n.x, 0.0, n.z).normalized()
	var probe := global_position - flat * (CLIMB_GAP + 0.45)
	var hit := _ray(probe + Vector3.UP * reach_up, probe + Vector3.UP * 0.25)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.65:
		return null
	# room to stand: nothing in the way between the lip and head height above it
	var top: Vector3 = hit["position"]
	if not _ray(top + Vector3.UP * 0.1, top + Vector3.UP * 1.7).is_empty():
		return null
	return top

## How many of the climb's hip/chest/shoulder rays meet one steep face along -n from here.
## A loose stone in a scree heap can meet the chest's reach ray on its own; a face that can be
## climbed meets at least two of the three about as far off as each other (a stone with a
## post behind it gives hits at two depths, not one face), so the hands only close on that.
func _face_rays(n: Vector3) -> int:
	var flat := Vector3(n.x, 0.0, n.z).normalized()
	var depths: Array[float] = []
	for h: float in [0.7, 1.1, 1.5]:
		var o := global_position + Vector3.UP * h
		var hit := _ray(o, o - flat * (CLIMB_REACH + 0.45))
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < CLIMB_STEEP + 0.15:
			depths.append((o - (hit["position"] as Vector3)).dot(flat))
	var best := 0
	for a in depths:
		var k := 0
		for b in depths:
			if absf(a - b) < 0.4:
				k += 1
		best = maxi(best, k)
	return best

## In the air with the stick pushed at a steep face: catch hold, or vault a waist-high ledge.
func _try_grab(wish: Vector3) -> bool:
	if stamina < 4.0 or dead_t >= 0.0:
		return false
	var chest := _ray(global_position + Vector3.UP * 1.3, global_position + Vector3.UP * 1.3 + wish * CLIMB_REACH)
	if not chest.is_empty():
		var n: Vector3 = chest["normal"]
		if absf(n.y) < CLIMB_STEEP and wish.dot(-Vector3(n.x, 0, n.z).normalized()) > 0.5:
			var top: Variant = _ledge_top(n, 1.9)
			if top != null:
				_start_mantle(top, n)
				return true
			var cn := (Vector3(n.x, 0.0, n.z).normalized() - wish).normalized()
			if _face_rays(cn) < 2:
				refused_grabs += 1
				return false
			_start_climb(cn)
			return true
		return false
	var knee := _ray(global_position + Vector3.UP * 0.5, global_position + Vector3.UP * 0.5 + wish * CLIMB_REACH)
	if not knee.is_empty():
		var n2: Vector3 = knee["normal"]
		if absf(n2.y) < CLIMB_STEEP and wish.dot(-Vector3(n2.x, 0, n2.z).normalized()) > 0.5:
			var top2: Variant = _ledge_top(n2, 1.3)
			if top2 != null:
				_start_mantle(top2, n2)
				return true
			# no top within reach: a tall face whose foot juts out (a battered wall, a
			# leaning crag) meets the shins before the chest; catch it all the same
			if _jumped:
				var cn2 := (Vector3(n2.x, 0.0, n2.z).normalized() - wish).normalized()
				if _face_rays(cn2) < 2:
					refused_grabs += 1
					return false
				_start_climb(cn2)
				return true
	return false

func _start_climb(n: Vector3) -> void:
	_jumped = false
	_air_t = -1.0
	land_t = -1.0
	_clear_jump_pose()
	if combat != null and combat.is_drawn():
		combat.restore()                       # the staff goes over the back to free the hands
	_set_lock(null)
	climbing = true
	climb_normal = n
	climbs += 1
	_climb_t = 0.0
	_climb_surge = 1.0
	_lip_felt = false
	_lunge_t = -1.0
	velocity = Vector3.ZERO
	for i in 2:
		_hold_t[i] = 1.0
		_hold[i] = _find_hold(i, 0.12 if i == 0 else -0.08)
		_foot_t[i] = 1.0
		_foot[i] = _find_foot_hold(i, -0.06 if i == 0 else 0.1)
	if crumple != null:
		crumple.active = true
	if garb != null:
		garb.posed_legs = true                 # the robe follows the climb pose's legs

func _let_go(push: float, regrab: float) -> void:
	climbing = false
	_wk_coil = -1.0
	_regrab_t = regrab
	velocity = climb_normal * push
	_lunge_t = -1.0
	_clear_climb_pose()

## Kick off the face: the hands let go, the legs drive the body out and up toward the stick
## (straight back off the stones, or a leap along them), the body twisting round in the first
## third of a second to face the way it flies. It is a jump: the glider opens off it, the jump
## attack and the plunge work from it, a release of the button cuts it short, and the hands
## cannot catch the same face for a moment.
func _wall_jump(dir2: Vector2, right: Vector3) -> void:
	var n := Vector3(climb_normal.x, 0.0, climb_normal.z).normalized()
	var away := clampf(dir2.y, 0.0, 1.0)
	var side := clampf(dir2.x, -1.0, 1.0)
	var out := n * WALL_JUMP_OUT * maxf(away, 0.65) + right * WALL_JUMP_SIDE * side
	climbing = false
	_lunge_t = -1.0
	_regrab_t = 0.45
	if crumple != null:
		crumple.neck = 0.0                     # the climb's look up at the holds is over
		crumple.head_turn = 0.0
	stamina -= WALL_JUMP_COST
	velocity = out + Vector3.UP * WALL_JUMP_UP
	global_position += n * 0.1               # clear of the rough stones (a jutting lip would eat the rise)
	# the climb pose is not wiped: the jump pose eases out of it, so the knees that were on
	# the holds are the knees that drive the kick
	if garb != null:
		garb.wall_n = Vector3.ZERO             # (the robe keeps following the legs through the push)
	if crumple != null:
		crumple.plant = 0.0                    # the hands come off the holds as the legs drive
		crumple.foot_plant = 1.0               # the soles stay on their stones: _kick_push lets them go
	_wk_coil = -1.0
	_jumped = true
	_coyote_t = 99.0
	_buffer_t = 99.0
	jumps += 1
	wall_jumps += 1
	jump_apex = 0.0
	_jump_y0 = global_position.y
	_jump_from_sprint = false
	land_t = -1.0
	_air_swung = false
	# no turf to crouch on: the take-off is drawn from the push line, legs driving off the stones
	_air_t = PUSH_CROUCH
	_air_top = global_position.y
	_air_last_y = global_position.y
	var fly := Vector3(out.x, 0.0, out.z)
	_wj_yaw = Vector2(body.rotation.y, atan2(fly.x, fly.z))
	_wj_t = 0.0

## The coil before a kick off a face: the hands keep their holds and pull, the feet stay on
## their stones with the soles flat to the face, and the hips sink in and down toward the
## stones as the knees fold up under the chest, loading the legs for the push.
func _kick_coil(delta: float, n: Vector3, gap: float, right: Vector3) -> void:
	_wk_coil += delta
	var u := clampf(_wk_coil / WALL_KICK_COIL, 0.0, 1.0)
	if crumple != null:
		# the eyes come off the holds onto where the kick will fly
		crumple.neck = lerpf(crumple.neck, 0.0, 1.0 - exp(-25.0 * delta))
		crumple.head_turn = lerpf(crumple.head_turn, 0.0, 1.0 - exp(-25.0 * delta))
	var up_dir := (Vector3.UP - n * n.y).normalized()
	# drawn in to a hand's breadth off the stones and a little down onto the bent legs
	var v := -n * clampf((gap - (CLIMB_GAP - 0.1)) * 10.0, -1.2, 1.2) - up_dir * 0.9 * (1.0 - u)
	velocity = v
	var before := global_position
	motion_mode = MOTION_MODE_FLOATING
	move_and_slide()
	motion_mode = MOTION_MODE_GROUNDED
	stamina -= CLIMB_HOLD_COST * delta
	_hold_still_anim()
	if crumple != null:
		var c := smoothstep(0.0, 1.0, u)
		crumple.arm = 2.45
		crumple.elbow = lerpf(0.75, 1.25, c)   # the arms bend, pulling the chest to the stones
		crumple.hip = lerpf(0.55, 1.15, c)     # the knees come up under the chest
		crumple.knee = lerpf(0.85, 1.75, c)
		crumple.spine = lerpf(0.08, 0.22, c)
		crumple.stride = lerpf(crumple.stride, 0.0, c)
		crumple.ankle = 0.0
		crumple.sole_flat = 0.0
		# the hands hold where they are; the feet stay on their stones (no step in a coil)
		crumple.plant = 1.0
		crumple.foot_plant = 1.0
		for i in 2:
			_hold_t[i] = 1.0
			_foot_t[i] = 1.0
		_place_hands(0.0, global_position - before)
		for i in 2:
			crumple.foot_target[i] = (_foot[i] as Vector3) + n * 0.12 + up_dir * 0.07
		_note_sole_err()
	if _wk_coil >= WALL_KICK_COIL:
		_wall_jump(_wk_dir, right)

## After the kick: the soles stay on their stones while the legs straighten out of the coil,
## then let go of the face as the body flies clear.
func _kick_push() -> void:
	if crumple == null or crumple.foot_plant <= 0.0:
		return
	crumple.foot_plant = 1.0 - smoothstep(WALL_KICK_PUSH * 0.55, WALL_KICK_PUSH, _wj_t)
	if _wj_t < WALL_KICK_PUSH * 0.55:
		_note_sole_err()
	if crumple.foot_plant <= 0.0 and garb != null:
		garb.posed_legs = false

func _note_sole_err() -> void:
	for i in 2:
		kick_sole_err = maxf(kick_sole_err, crumple.foot_err[i])

func _start_mantle(top: Vector3, n: Vector3) -> void:
	_jumped = false
	if combat != null and combat.is_drawn():
		combat.restore()
	_set_lock(null)
	_mantle_hands = climbing                   # hands already on holds press on them as it rises
	climbing = false
	_wk_coil = -1.0
	climb_normal = n
	mantle_t = 0.0
	mantles += 1
	_mantle_from = global_position
	_mantle_to = top + Vector3.UP * 0.02
	velocity = Vector3.ZERO
	body.rotation.y = atan2(-n.x, -n.z)
	if crumple != null:
		crumple.active = true
	if garb != null:
		garb.posed_legs = true
		garb.wall_n = Vector3.ZERO             # rolling over the lip: the face is behind the knees

func _climb_tick(delta: float, dir2: Vector2, want_jump: bool, want_dodge: bool) -> void:
	if mantle_t >= 0.0:
		_mantle_tick(delta)
		return
	# feel the face with three rays at hip, chest and shoulder along the facing; rough
	# masonry turns every stone end a different way, so the face normal is their average,
	# eased in, and the gap is the nearest stone
	_climb_t += delta
	var n := climb_normal
	var sum := Vector3.ZERO
	var gap := INF
	for h: float in [0.7, 1.1, 1.5]:
		var o := global_position + Vector3.UP * h
		var hit := _ray(o, o - n * 1.1)
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= CLIMB_STEEP + 0.15:
			continue
		sum += hit["normal"]
		gap = minf(gap, (o - (hit["position"] as Vector3)).dot(n))
	if sum == Vector3.ZERO:
		# the face runs out under the hands: haul up if there is a ledge, else drop
		var top: Variant = _ledge_top(n, 2.1)
		if top != null:
			_start_mantle(top, n)
		else:
			if _climb_t < 0.2:
				false_drops += 1
			_let_go(0.5, 0.4)
		return
	n = n.slerp(sum.normalized(), 1.0 - exp(-5.0 * delta)).normalized()
	climb_normal = n
	if dir2.y < -0.2 or _lunge_t >= 0.0:
		# climbing up and the face ends below the hands: reach over the lip and haul up
		var head := _ray(global_position + Vector3.UP * 1.85, global_position + Vector3.UP * 1.85 - n * 1.1)
		if head.is_empty() or _lip_felt:
			var lip: Variant = _ledge_top(n, 2.1)
			if lip != null:
				_start_mantle(lip, n)
				return
	_lip_felt = false
	if want_dodge:
		_let_go(2.2, 0.6)
		return
	var up_dir := (Vector3.UP - n * n.y).normalized()
	var face := -Vector3(n.x, 0.0, n.z).normalized()
	var right := face.cross(Vector3.UP).normalized()
	if _wk_coil >= 0.0:
		_kick_coil(delta, n, gap, right)
		return
	if want_jump and _lunge_t < 0.0 and (dir2.y > 0.35 or absf(dir2.x) > 0.7) and stamina >= WALL_JUMP_COST:
		_wk_coil = 0.0
		_wk_dir = dir2
		kick_coils += 1
		_kick_coil(delta, n, gap, right)
		return
	if want_jump and _lunge_t < 0.0 and stamina >= CLIMB_LUNGE_COST:
		_lunge_t = 0.0
		stamina -= CLIMB_LUNGE_COST
	var v := Vector3.ZERO
	if _lunge_t >= 0.0:
		_lunge_t += delta
		var lu := _lunge_t / CLIMB_LUNGE
		v = up_dir * CLIMB_LUNGE_SPEED * sin(PI * clampf(lu, 0.0, 1.0)) * 1.4
		if lu >= 1.0:
			_lunge_t = -1.0
	else:
		var m := Vector2(dir2.x, -dir2.y)
		if m.length() > 1.0:
			m = m.normalized()
		v = (right * m.x + up_dir * m.y) * CLIMB_SPEED * _climb_rhythm(delta)
		stamina -= (CLIMB_COST if m.length() > 0.2 else CLIMB_HOLD_COST) * delta
	# keep the hands on the face: close or open the gap toward CLIMB_GAP
	v += -n * clampf((gap - CLIMB_GAP) * 6.0, -0.8, 0.8)
	velocity = v
	var before := global_position
	motion_mode = MOTION_MODE_FLOATING         # no floor snap or slope slide on the stones
	move_and_slide()
	motion_mode = MOTION_MODE_GROUNDED
	var moved := global_position - before
	climbed += moved.length()
	climb_rate = moved.length() / maxf(delta, 1e-4)
	if climb_log and _climb_t > 0.4 and _lunge_t < 0.0 and crumple != null:
		climb_ticks.append(Vector3(climb_rate, crumple.neck, crumple.head_turn))
		var stand := 0.0
		if _foot_t[0] < 1.0 and _foot_t[1] >= 1.0:
			stand = 1.0
		elif _foot_t[1] < 1.0 and _foot_t[0] >= 1.0:
			stand = -1.0
		var rgt := -Vector3(n.x, 0.0, n.z).normalized().cross(Vector3.UP).normalized()
		var hc: Vector3 = ((crumple.hip_joint[0] as Vector3) + (crumple.hip_joint[1] as Vector3)) * 0.5
		climb_sway.append(Vector2(stand, (hc - global_position).dot(rgt)))
		climb_roll.append(Vector2(stand, (crumple.hip_joint[0] as Vector3).y - (crumple.hip_joint[1] as Vector3).y))
		var spl_l := ((crumple.knee_joint[0] as Vector3) - (crumple.hip_joint[0] as Vector3)).dot(-rgt)
		var spl_r := ((crumple.knee_joint[1] as Vector3) - (crumple.hip_joint[1] as Vector3)).dot(rgt)
		var mid_step := false
		for i in 2:
			mid_step = mid_step or (_foot_t[i] > 0.25 and _foot_t[i] < 0.75)
		if mid_step:
			climb_knee.append(Vector2(stand, (spl_l - spl_r) * stand))
	if garb != null and gap < INF:
		# the front panel swings out over the knees only as far as the stones let it
		garb.wall_n = n
		garb.wall_p = before - n * gap
	body.rotation.y = lerp_angle(body.rotation.y, atan2(face.x, face.z), 1.0 - exp(-14.0 * delta))
	_pose_climb()
	_place_hands(delta, moved)
	_place_feet(delta, moved)
	if stamina <= 0.0:
		stamina = 0.0
		_let_go(0.6, 1.2)                      # the grip gives out
		return
	if is_on_floor() and dir2.y > 0.3:
		_let_go(0.0, 0.3)                      # climbed back down to the ground

## Haul up over the lip: the body rises against the face first, then rolls forward onto the
## ledge, knees coming up under it.
func _mantle_tick(delta: float) -> void:
	mantle_t += delta
	var u := clampf(mantle_t / MANTLE_TIME, 0.0, 1.0)
	var rise := smoothstep(0.0, 0.65, u)
	var over := smoothstep(0.4, 1.0, u)
	var p := _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, rise)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, over)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, over)
	global_position = p
	velocity = Vector3.ZERO
	if crumple != null:
		var k := sin(PI * u)
		crumple.stride = 0.0
		crumple.arm = lerpf(2.5, 0.4, smoothstep(0.1, 0.7, u))
		crumple.elbow = lerpf(0.8, 1.4, smoothstep(0.0, 0.5, u)) * (1.0 - smoothstep(0.6, 1.0, u))
		crumple.hip = 1.3 * k
		crumple.knee = 1.6 * k
		crumple.spine = 0.45 * k
		crumple.plant = (1.0 - smoothstep(0.25, 0.55, u)) if _mantle_hands else 0.0   # the hands press on the lip, then come away
		crumple.foot_plant = (1.0 - smoothstep(0.1, 0.4, u)) if _mantle_hands else 0.0  # the feet push off their holds first
	if crumple != null:
		_sway *= exp(-8.0 * delta)             # the hips come back under the body as it hauls over
		crumple.hip_shift = crumple.hip_shift * exp(-8.0 * delta)
		_hike *= exp(-8.0 * delta)
		crumple.hip_roll = _hike
		for i in 2:
			_frog[i] = float(_frog[i]) * exp(-8.0 * delta)
		crumple.knee_out = [_frog[0], _frog[1]]
	_hold_still_anim()
	if u >= 1.0:
		mantle_t = -1.0
		_clear_climb_pose()

## A climb is not an even glide: the body surges up while all four limbs hold (a foot pushes,
## the hands pull) and nearly stops while a hand or foot is off reaching for its next hold.
## Returns the speed factor for this tick (about 1 on average over a cycle; env CLIMB_EVEN=1
## gives the old even rate, for before/after).
func _climb_rhythm(delta: float) -> float:
	var reach := 0.0
	for i in 2:
		if _hold_t[i] < 1.0:
			reach = maxf(reach, sin(PI * float(_hold_t[i])))
		if _foot_t[i] < 1.0:
			reach = maxf(reach, 0.8 * sin(PI * float(_foot_t[i])))
	var want := lerpf(CLIMB_SURGE.x, CLIMB_SURGE.y, reach)
	if _climb_even:
		want = 1.0
	_climb_surge = lerpf(_climb_surge, want, 1.0 - exp(-14.0 * delta))
	return _climb_surge

## Arms up on the face, knees bent; the reach cycles hand over hand with the distance climbed.
func _pose_climb() -> void:
	_hold_still_anim()
	if crumple == null:
		return
	var ph := climbed * 2.4
	crumple.arm = 2.45
	crumple.elbow = 0.75
	crumple.hip = 0.55
	crumple.knee = 0.85
	crumple.spine = 0.08
	crumple.stride = 0.42 * sin(ph)

## Where a hand wants to hold: a reach above its shoulder, ahead along the way the body is
## going, found on the face by a ray so it sits on a real stone. `lift` staggers the hands.
func _find_hold(i: int, lift: float, ahead := Vector3.ZERO) -> Vector3:
	var n := climb_normal
	var face := -Vector3(n.x, 0.0, n.z).normalized()
	var right := face.cross(Vector3.UP).normalized()
	var sh: Vector3 = crumple.shoulder[i] if crumple != null and crumple.shoulder[i] != Vector3.ZERO else global_position + Vector3.UP * 1.42
	var p := sh + Vector3.UP * (0.26 + lift) + right * (0.07 if i == 1 else -0.07) + ahead
	# rough masonry: a stone end can stand proud of the face or a joint run deep into it, so
	# feel a few spots round the reach and take the first one that is a face
	for off: Vector2 in HOLD_FEEL:
		var o := p + right * off.x + Vector3.UP * off.y + n * 1.0
		var hit := _ray(o, o - n * 1.8)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < CLIMB_STEEP + 0.25 \
				and (hit["position"] as Vector3).distance_to(sh) < HOLD_REACH:
			return hit["position"]
	_hold_missed = true
	# nothing in reach: a stone set back deeper (the arm goes in after it), nearest first
	var deep := Vector3.ZERO
	for off: Vector2 in HOLD_FEEL:
		var o := p + right * off.x + Vector3.UP * off.y + n * 1.0
		var hit := _ray(o, o - n * 2.2)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < CLIMB_STEEP + 0.25 \
				and (deep == Vector3.ZERO or (hit["position"] as Vector3).distance_to(sh) < deep.distance_to(sh)):
			deep = hit["position"]
	if deep != Vector3.ZERO:
		return deep
	_lip_felt = true                           # nothing to hold up here: the face has ended, haul up
	# no stone there (over the lip): hold the face's plane level with the hand
	return p - n * (p - (global_position - n * CLIMB_GAP)).dot(n)

## Hand over hand: each hand stays on its hold while the body moves; when the body has
## climbed past it, the hand lets go and reaches to the next hold, only while the other one
## grips (both together if a hold is out of reach). Drives Crumple's two-bone reach.
func _place_hands(delta: float, moved: Vector3) -> void:
	if crumple == null:
		return
	var n := climb_normal
	var up_dir := (Vector3.UP - n * n.y).normalized()
	var go := moved - n * moved.dot(n)
	var ahead := go.normalized() * 0.1 if go.length() > 1e-4 else Vector3.ZERO
	for i in 2:
		var other := 1 - i
		if _hold_t[i] < 1.0:
			_hold_t[i] = minf(_hold_t[i] + delta / HAND_MOVE, 1.0)
			continue
		var want := _find_hold(i, 0.0)
		var far: float = (_hold[i] as Vector3).distance_to(want)
		var sh: Vector3 = crumple.shoulder[i]
		var out_of_reach: bool = sh != Vector3.ZERO and sh.distance_to(_hold[i]) > 0.46
		if (far > HAND_STEP and _hold_t[other] >= 1.0) or out_of_reach:
			_hold_missed = false
			var next := _find_hold(i, 0.0, ahead)
			if _hold_missed and not out_of_reach:
				continue                       # no stone up there yet (a set-back course): keep this grip
			_hold_from[i] = _hold[i]
			_hold[i] = next
			_hold_t[i] = 0.0
			hand_moves += 1
	crumple.plant = minf(crumple.plant + delta * 6.0, 1.0)
	crumple.hand_wall = n
	for i in 2:
		var u := smoothstep(0.0, 1.0, _hold_t[i])
		var at: Vector3 = (_hold_from[i] as Vector3).lerp(_hold[i], u) + n * 0.12 * sin(PI * u)
		# the wrist sits a hand's length below the fingers' grip and a palm off the stone
		crumple.hand_target[i] = at + n * 0.04 - up_dir * 0.07
	# the eyes go to the hold: the head tips back up the face and turns toward the hand that is
	# reaching, settling back as it takes the stone
	var look := 0.0
	var lift := 0.0
	for i in 2:
		var r := sin(PI * float(_hold_t[i])) if _hold_t[i] < 1.0 else 0.0
		lift = maxf(lift, r)
		look += (CLIMB_LOOK_TURN if i == 0 else -CLIMB_LOOK_TURN) * r
	var kl := 1.0 - exp(-10.0 * delta)
	crumple.neck = lerpf(crumple.neck, CLIMB_LOOK_UP.x + CLIMB_LOOK_UP.y * lift, kl)
	crumple.head_turn = lerpf(crumple.head_turn, look, kl)

## Where a foot wants to stand: on the face below its hip, found by a ray so the toes sit on
## a real stone. `lift` staggers the feet.
func _find_foot_hold(i: int, lift: float, ahead := Vector3.ZERO) -> Vector3:
	var n := climb_normal
	var face := -Vector3(n.x, 0.0, n.z).normalized()
	var right := face.cross(Vector3.UP).normalized()
	var hp: Vector3 = crumple.hip_joint[i] if crumple != null and crumple.hip_joint[i] != Vector3.ZERO else global_position + Vector3.UP * 0.95
	var p := hp + Vector3.UP * (-0.55 + lift) + right * (0.06 if i == 1 else -0.06) + ahead
	for off: Vector2 in [Vector2.ZERO, Vector2(0.0, 0.08), Vector2(0.07, 0.0), Vector2(-0.07, 0.0), Vector2(0.0, -0.08), Vector2(0.0, 0.16)]:
		var o := p + right * off.x + Vector3.UP * off.y + n * 1.0
		var hit := _ray(o, o - n * 1.8)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < CLIMB_STEEP + 0.25:
			return hit["position"]
	return p - n * (p - (global_position - n * CLIMB_GAP)).dot(n)

## Foot over foot, like the hands: each foot stands on its toe hold while the body moves and
## steps up to the next once the body has gone past it, only while the other foot stands.
func _place_feet(delta: float, moved: Vector3) -> void:
	if crumple == null:
		return
	var n := climb_normal
	var up_dir := (Vector3.UP - n * n.y).normalized()
	var go := moved - n * moved.dot(n)
	# a long step: the feet push the body up the face, so each one goes well past where it
	# wants to be and stands there while the body rises over it
	var ahead := go.normalized() * 0.26 if go.length() > 1e-4 else Vector3.ZERO
	for i in 2:
		var other := 1 - i
		if _foot_t[i] < 1.0:
			_foot_t[i] = minf(_foot_t[i] + delta / FOOT_MOVE, 1.0)
			continue
		var want := _find_foot_hold(i, 0.0)
		var far: float = (_foot[i] as Vector3).distance_to(want)
		var hp: Vector3 = crumple.hip_joint[i]
		var out_of_reach: bool = hp != Vector3.ZERO and hp.distance_to(_foot[i]) > 0.86
		if (far > FOOT_STEP and _foot_t[other] >= 1.0) or out_of_reach:
			_foot_from[i] = _foot[i]
			_foot[i] = _find_foot_hold(i, 0.0, ahead)
			_foot_t[i] = 0.0
			foot_moves += 1
	crumple.foot_plant = minf(crumple.foot_plant + delta * 5.0, 1.0)
	for i in 2:
		var u := smoothstep(0.0, 1.0, _foot_t[i])
		var at: Vector3 = (_foot_from[i] as Vector3).lerp(_foot[i], u) + n * 0.15 * sin(PI * u)
		# the ankle sits a foot's length off the stone the toes stand on, a little above them
		crumple.foot_target[i] = at + n * 0.12 + up_dir * 0.07
	# weight over the standing foot: while one foot is off its hold the hips sway out over the
	# other one (to the body's right for the right foot), back to the middle as it lands
	var want := 0.0
	for i in 2:
		if _foot_t[i] < 1.0:
			want += (-1.0 if i == 1 else 1.0) * CLIMB_SWAY * minf(1.6 * sin(PI * float(_foot_t[i])), 1.0)
	if _no_sway:
		want = 0.0
	_sway = lerpf(_sway, want, 1.0 - exp(-12.0 * delta))
	var rgt := -Vector3(n.x, 0.0, n.z).normalized().cross(Vector3.UP).normalized()
	crumple.hip_shift = rgt * _sway
	# and the stepping side's hip hikes: the pelvis rolls up on the side of the foot that is
	# lifting to its next hold, the trunk rolled back above it so the shoulders stay level
	var roll := 0.0
	for i in 2:
		if _foot_t[i] < 1.0:
			roll += (1.0 if i == 0 else -1.0) * CLIMB_HIKE * minf(1.5 * sin(PI * float(_foot_t[i])), 1.0)
	if _no_hike:
		roll = 0.0
	_hike = lerpf(_hike, roll, 1.0 - exp(-12.0 * delta))
	crumple.hip_roll = _hike
	# with the hip hiked the stepping knee swings out to its own side (a frog step) instead of
	# driving straight up into the stones, back in line as the foot lands
	for i in 2:
		var fw := 0.0
		if _foot_t[i] < 1.0 and not _no_frog:
			fw = CLIMB_FROG * minf(1.5 * sin(PI * float(_foot_t[i])), 1.0)
		_frog[i] = lerpf(float(_frog[i]), fw, 1.0 - exp(-(12.0 if fw > float(_frog[i]) else 20.0) * delta))
	crumple.knee_out = [_frog[0], _frog[1]]

## The held idle is the staff guard: pelvis turned ~44 deg and chest ~18 deg off the facing.
## Hanging on the stones, hauling over a lip or swinging under the glider bar the body faces
## square into what it holds, so Crumple turns the hips and chest back to the facing; caught
## fast on the grab, let go slower as a kick-off or a landing hands back to the guard. (The
## knock-down drives `square` itself.)
func _ease_square(delta: float) -> void:
	if crumple == null or down_t >= 0.0 or dead_t >= 0.0:
		return
	var want := 0.0
	if mantle_t >= 0.0:
		want = 1.0 - smoothstep(0.6, 1.0, mantle_t / MANTLE_TIME)   # back to the guard as the feet take the ledge
	elif climbing or gliding:
		want = 1.0
	if _no_square:
		want = 0.0                             # (env CLIMB_NOSQUARE=1: the guard-turned hang, for before/after)
	crumple.square = move_toward(crumple.square, want, delta * (SQUARE_IN if want > crumple.square else SQUARE_OUT))

func _hold_still_anim() -> void:
	if anim_tree != null:
		_blend = 0.0
		anim_tree.set("parameters/move/blend_position", 0.0)
		anim_tree.set("parameters/speed/scale", 0.25)

func _clear_climb_pose() -> void:
	if garb != null:
		garb.posed_legs = false
		garb.wall_n = Vector3.ZERO
	if crumple == null:
		return
	crumple.stride = 0.0
	crumple.arm = 0.0
	crumple.elbow = 0.0
	crumple.hip = 0.0
	crumple.knee = 0.0
	crumple.spine = 0.0
	crumple.plant = 0.0
	crumple.foot_plant = 0.0
	crumple.square = 0.0
	crumple.neck = 0.0
	crumple.head_turn = 0.0
	crumple.hip_shift = Vector3.ZERO
	crumple.hip_roll = 0.0
	crumple.knee_out = [0.0, 0.0]
	_frog = [0.0, 0.0]
	_sway = 0.0
	_hike = 0.0
	crumple.active = false

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
	dash_started.emit()

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
## `heavy`: a blow with the weight to throw the hero off their feet (the soldier's sweep).
func receive_attack(attacker: Node, damage: float, heavy := false, unblockable := false) -> String:
	if dead_t >= 0.0:
		return "miss"
	if down_t >= KNOCK_GUARD.x and down_t <= KNOCK_GUARD.y:
		return "miss"                          # flat in the grass: the swing passes over
	if not unblockable and combat != null and combat.try_parry(attacker):
		return "parried"
	if is_invulnerable() or (dodge_t >= 0.0 and dodge_t <= PERFECT_WINDOW):
		if dodge_t <= PERFECT_WINDOW and not _dodge_rewarded:
			_dodge_rewarded = true
			perfect_dodges += 1
			stamina = minf(stamina + PERFECT_REFUND, stamina_max)
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
	if heavy:
		add_shake(0.75)
		_knockdown(attacker)
		return "hit"
	add_shake(0.55)
	_flinch(attacker)
	return "hit"

func _flinch(attacker: Node) -> void:
	if _jp > 0.0:
		_clear_jump_pose()                     # struck in the air or mid-landing
	land_t = -1.0
	if gliding:
		_end_glide(true)                       # struck out of the air: the wing folds
	if climbing or mantle_t >= 0.0:
		climbing = false                       # knocked off the face
		mantle_t = -1.0
		_clear_climb_pose()
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
	flinch_head_peak = 0.0
	flinch_chest_peak = 0.0
	flinch_twist_peak = 0.0

func _knockdown(attacker: Node) -> void:
	_clear_flinch_layer()
	_flinch(attacker)                      # breaks off glide/climb/swing/dodge, sets the shove
	flinches -= 1
	flinch_t = -1.0
	model.transform = _model_rest
	# turn to face the blow so the body is always thrown onto its back
	body.rotation.y = atan2(-_flinch_dir.x, -_flinch_dir.z)
	if crumple != null:
		crumple.active = true
	down_t = 0.0
	_knock_hand = Vector3.INF
	knockdowns += 1

func _down_tick(delta: float) -> void:
	down_t += delta
	_update_slowmo(delta)
	_update_lock(delta)
	cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	# thrown along the blow while airborne, then the grass holds the body
	var shove := _flinch_dir * (KNOCK_PUSH * 3.0 / 0.5) * maxf(1.0 - down_t / 0.5, 0.0) ** 2
	velocity.x = shove.x
	velocity.z = shove.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if combat != null:
		combat.physics_step(delta)
	if down_t >= KNOCK_LAND and down_t - delta < KNOCK_LAND:
		# the back slaps into the sward a body's length behind the heels: a low puff of dust and grass
		var at := global_position + _flinch_dir * 0.85 + Vector3.UP * 0.12
		ImpactFX.spawn(get_parent(), at, _flinch_dir, "dirt", 0.9)
		var tr := get_parent().get_node_or_null("Trample") as Trample
		if tr != null:
			tr.add_body(global_position, _flinch_dir)
		fell.emit(at)
	if anim_tree != null:
		anim_tree.set("parameters/move/blend_position", 0.0)
		anim_tree.set("parameters/speed/scale", 1.0)
	if down_t >= KNOCK_TIME:
		down_t = -1.0
		model.transform = _model_rest
		if crumple != null:
			for k in ["knee", "hip", "spine", "arm", "elbow", "head_turn", "leg_aim", "square", "arm_aim", "plant", "chest_twist"]:
				crumple.set(k, 0.0)
			crumple.plant_w = [1.0, 1.0]
			crumple.hand_fingers = Vector3.ZERO
			crumple.hip_lr = Vector2.ZERO
			crumple.knee_lr = Vector2.ZERO
			crumple.hand_knee = Vector3.ZERO
			crumple.arm_lr = Vector2.ZERO
			crumple.elbow_lr = Vector2.ZERO
			crumple.arm_aim_lr = Vector2.ZERO
			crumple.grip_l = 0.0
			crumple.active = false
		_knock_hand = Vector3.INF
		return
	if crumple != null:
		# whatever stance the blow caught (a staggered guard, a stride), hang both legs even
		# first, so the feet land side by side on the sward instead of one heel in the ground
		crumple.leg_aim = minf(down_t / 0.12, 1.0) * (1.0 - smoothstep(1.55, KNOCK_TIME, down_t))
		crumple.square = crumple.leg_aim
		crumple.arm_aim = crumple.leg_aim
	_pose_knockdown(down_t)
	_knock_push_hand()
	_knock_knee_hand()

## The rise off one knee: the right palm comes down onto the front knee as the foot is set and
## stays braced on it (its target follows the knee as posed) while the front leg drives the body
## up, so the arm helps push instead of hanging by the shin; it lets go as the body comes upright.
func _knock_knee_hand() -> void:
	if crumple == null:
		return
	var h: Array = KNOCK_KNEE_HAND
	var w := smoothstep(h[0], h[1], down_t) * (1.0 - smoothstep(h[2], h[3], down_t))
	if OS.has_environment("KNOCK_NOKNEEHAND") or OS.has_environment("KNOCK_SQUAT"):
		w = 0.0
	if w <= 0.0:
		crumple.hand_knee = Vector3.ZERO
		return
	var fwd := body.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var at: Vector3 = KNOCK_KNEE_HAND_AT
	crumple.hand_knee = Vector3.UP * at.y + fwd * at.z
	crumple.plant = w
	crumple.plant_w = [0.0, 1.0]
	crumple.hand_wall = Vector3.UP
	crumple.hand_curl = 0.35
	# fingers draped forward and down over the kneecap
	crumple.hand_fingers = (fwd - Vector3.UP * 0.7).normalized()

## The get-up's push off the ground: the left hand reaches for the turf beside the hip and
## holds there (a fixed world point) while the trunk sits up over it, the chest turned a little
## toward it so the weight goes onto that arm; it lets go as the squat comes over the feet.
func _knock_push_hand() -> void:
	if crumple == null:
		return
	var h: Array = KNOCK_HAND
	var w := smoothstep(h[0], h[1], down_t) * (1.0 - smoothstep(h[2], h[3], down_t))
	if OS.has_environment("KNOCK_NOHAND"):
		w = 0.0
	if w <= 0.0:
		crumple.plant = 0.0
		crumple.chest_twist = 0.0
		crumple.plant_w = [1.0, 1.0]
		crumple.hand_fingers = Vector3.ZERO
		if down_t > h[3] and _knock_hand != Vector3.INF:
			_knock_hand = Vector3.INF
			crumple.hand_curl = 0.4
		return
	var fwd := body.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var out: Vector3 = crumple.hip_joint[0] - crumple.hip_joint[1]
	out = (out - Vector3.UP * out.dot(Vector3.UP)).normalized()
	if _knock_hand == Vector3.INF:
		# where the left hip socket lies now, out to its side and a little behind, down on the turf
		var at: Vector3 = crumple.hip_joint[0] + out * KNOCK_HAND_OUT - fwd * KNOCK_HAND_BACK
		var hit := _ray(at + Vector3.UP * 1.0, at - Vector3.UP * 1.5)
		var gy: float = (hit["position"] as Vector3).y if not hit.is_empty() else global_position.y
		_knock_hand = Vector3(at.x, gy + 0.06, at.z)
	crumple.plant = w
	crumple.plant_w = [1.0, 0.0]
	crumple.hand_target[0] = _knock_hand
	crumple.hand_wall = Vector3.UP
	crumple.hand_curl = 0.15
	crumple.hand_fingers = (out - fwd * 0.6).normalized()
	crumple.chest_twist = KNOCK_LEAN * w
	crumple.spine -= KNOCK_SIT * w
	# roll the top toward the left (+X in body space) about the body's forward line on the ground
	model.transform = Transform3D(Basis(Vector3.BACK, -KNOCK_ROLL * w), Vector3.ZERO) * model.transform

# t, then: pitch back (deg), hip, knee, spine, sink (m), arm, elbow -- the body thrown back
# off its feet with the back arched and arms flung forward, landing on its back with the knees
# up, a beat flat in the grass, then a sit-up with the feet drawn in, a squat and the stand.
const KNOCK_KEYS := [
	[0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[0.12, -14.0, 12.0, 22.0, -12.0, 0.04, 40.0, 25.0],
	[0.42, -84.0, 48.0, 105.0, 16.0, 0.17, 28.0, 50.0],
	[0.52, -79.0, 54.0, 116.0, 20.0, 0.13, 16.0, 30.0],
	[0.62, -84.0, 55.0, 120.0, 18.0, 0.17, 8.0, 14.0],
	[1.00, -83.0, 56.0, 120.0, 20.0, 0.17, 6.0, 12.0],
	[1.28, -63.0, 76.0, 128.0, 34.0, 0.20, 30.0, 50.0],
	[1.45, -28.0, 90.0, 130.0, 46.0, 0.24, 48.0, 62.0],
	[1.60, 0.0, 62.0, 120.0, 34.0, 0.44, 30.0, 40.0],
	[1.85, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]

func _knock_pose(t: float) -> Array:
	for i in range(1, KNOCK_KEYS.size()):
		var b: Array = KNOCK_KEYS[i]
		if t <= b[0] or i == KNOCK_KEYS.size() - 1:
			var a: Array = KNOCK_KEYS[i - 1]
			var u := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
			# the fall accelerates like a dropped weight; every other span eases in and out
			u = u * u if i == 2 else u * u * (3.0 - 2.0 * u)
			var out := []
			for j in range(1, a.size()):
				out.append(lerpf(a[j], b[j], u))
			return out
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _pose_knockdown(t: float) -> void:
	var k := _knock_pose(t)
	if crumple != null:
		crumple.hip = deg_to_rad(k[1])
		crumple.knee = deg_to_rad(k[2])
		crumple.spine = deg_to_rad(k[3])
		crumple.arm = deg_to_rad(k[5])
		crumple.elbow = deg_to_rad(k[6])
		crumple.head_turn = deg_to_rad(25.0) * smoothstep(0.4, 0.6, t) * (1.0 - smoothstep(0.95, 1.2, t))
		# the rise comes up off one knee, not a two-footed squat: the right foot is set flat
		# ahead (thigh level, shin plumb) while the left knee goes down to the turf under the
		# hip, then the front leg drives the body up and the back knee leaves the ground
		# (the front foot swings forward only once the trunk has come up off its back, so it
		# skims the turf instead of kicking up into the air)
		var out_w := 1.0 - smoothstep(KNOCK_KNEEL[2], KNOCK_KNEEL[3], t)
		var kl := smoothstep(KNOCK_KNEEL[0], KNOCK_KNEEL[1], t) * out_w
		var kr := smoothstep(KNOCK_KNEEL_FRONT, KNOCK_KNEEL[1] + 0.04, t) * out_w
		if OS.has_environment("KNOCK_SQUAT"):
			kl = 0.0
			kr = 0.0
		crumple.hip_lr = Vector2(KNOCK_KNEEL_HIP.x * kl, KNOCK_KNEEL_HIP.y * kr)
		crumple.knee_lr = Vector2(KNOCK_KNEEL_KNEE.x * kl, KNOCK_KNEEL_KNEE.y * kr)
		# once the push hand has left the turf the free left arm does not fling out in front of
		# the chest: it swings back and down by the hip, elbow soft, a counterweight to the
		# trunk coming forward over the front foot
		var sw: Array = KNOCK_SWING
		var aw := smoothstep(sw[0], sw[1], t) * (1.0 - smoothstep(sw[2], sw[3], t))
		if OS.has_environment("KNOCK_NOSWING"):
			aw = 0.0
		crumple.arm_aim_lr = Vector2((1.0 - crumple.arm_aim) * aw, 0.0)
		crumple.arm_lr = Vector2((KNOCK_SWING_ARM - crumple.arm) * aw, 0.0)
		crumple.elbow_lr = Vector2((KNOCK_SWING_ELBOW - crumple.elbow) * aw, 0.0)
		# the free hand hangs loose: the fingers fall into a soft half-curl, the thumb in by
		# the index, through the swing and the hand-off back to the guard
		var rl: Array = KNOCK_RELAX
		crumple.grip_l = rl[4] * smoothstep(rl[0], rl[1], t) * (1.0 - smoothstep(rl[2], rl[3], t))
		if OS.has_environment("KNOCK_NORELAX"):
			crumple.grip_l = 0.0001 if crumple.grip_l > 0.0 else 0.0  # (the before: measured, not curled)
	# tip back about the heels (the body faces +Z in body space)
	var heel := Vector3(0.0, 0.0, -0.12)
	var tip := Transform3D(Basis(), heel) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(k[0])), Vector3.ZERO) * Transform3D(Basis(), -heel)
	model.transform = Transform3D(Basis(), Vector3(0.0, -k[4], 0.0)) * tip * _model_rest

func is_down() -> bool:
	return down_t >= 0.0

## The stagger's whole-figure part: only a sink into the knees. The upper body's reaction is
## taken at the joints (`_flinch_layer`), so the feet stay where the stagger steps put them.
func _pose_flinch(u: float) -> void:
	model.transform = Transform3D(Basis(), Vector3(0, -0.07 * _flinch_hit(u), 0)) * _model_rest

## Impact envelope of a stagger (u = flinch_t / FLINCH_TIME): snaps to 1 in ~0.05 s, then
## gives back over the rest of the stagger.
func _flinch_hit(u: float) -> float:
	if u < 0.0:
		return 0.0
	return sin(minf(u / 0.1, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.1, 0.7, u))

var _flinch_posed := false
var flinch_steps_on := true            # (bots) the stagger's backward steps may be switched off

func _clear_flinch_layer() -> void:
	if not _flinch_posed or crumple == null:
		return
	for k in ["pelvis", "spine", "neck", "head_turn", "chest_twist", "arm", "elbow", "knee", "hip", "ground"]:
		crumple.set(k, 0.0)
	crumple.arm_lr = Vector2.ZERO
	_flinch_posed = false
var flinch_head_peak := 0.0            # (bots) largest neck whip (rad, signed: + head back) of the last stagger
var flinch_chest_peak := 0.0           # (bots) largest chest crunch (spine + pelvis, rad, + forward)
var flinch_twist_peak := 0.0           # (bots) largest chest twist off the blow (rad, signed)

## The hit reaction at the joints, layered on the clip (Crumple): the hips are thrown back from
## the blow while the chest rounds over where it landed and the head snaps the other way (the
## whiplash, 0.02 s behind the chest), the arms fly up off the body and the chest twists away
## from a blow on one side; then everything rebounds a little past rest and settles.
func _flinch_layer() -> void:
	if flinch_t < 0.0 or crumple == null or dead_t >= 0.0 or down_t >= 0.0:
		if _flinch_posed and crumple != null:
			_clear_flinch_layer()
			if _jp <= 0.0 and pivot_t < 0.0 and stop_t < 0.0 and start_t < 0.0 and dead_t < 0.0 and down_t < 0.0:
				crumple.active = false
		return
	var u := flinch_t / FLINCH_TIME
	if not _flinch_posed:
		flinch_head_peak = 0.0
		flinch_chest_peak = 0.0
		flinch_twist_peak = 0.0
	_flinch_posed = true
	var a := _flinch_hit(u)
	var h := _flinch_hit(u - 0.04)        # the head lags the chest: whiplash
	var r := sin(PI * clampf((u - 0.4) / 0.5, 0.0, 1.0))   # the rebound past rest
	var e := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.8, 1.0, u))
	var push := body.global_basis.inverse() * _flinch_dir   # body faces +Z, +X is its left
	push.y = 0.0
	if push.length() > 1e-3:
		push = push.normalized()
	var front := maxf(-push.z, 0.0)        # struck from ahead: thrown back
	var rear := maxf(push.z, 0.0)          # struck from behind: thrown forward
	var side := push.x                     # + shoved to the left: the blow came from the right
	crumple.active = true
	# front: hips back, chest rounds over the blow, head snaps forward then whips back on the rebound
	# rear: pitched forward from the hips, the head flung back
	crumple.pelvis = (-0.32 * front + 0.26 * rear) * a + (0.07 * front - 0.05 * rear) * r
	crumple.spine = (0.2 * front + 0.12 * rear) * a - 0.06 * front * r
	crumple.neck = (-0.32 * front + 0.38 * rear) * h + (0.14 * front - 0.1 * rear) * r
	# the chest turns off a blow on one side (its struck shoulder driven back), the head goes further
	crumple.chest_twist = -0.38 * side * a + 0.08 * side * r
	crumple.head_turn = -0.45 * side * h + 0.12 * side * r
	# the arms fly up and out off the body, the struck side's higher; the elbows give
	crumple.arm = (0.55 * front - 0.35 * rear) * a
	crumple.arm_lr = Vector2(0.25 * maxf(-side, 0.0), 0.25 * maxf(side, 0.0)) * a
	crumple.elbow = 0.55 * a + 0.1 * r
	# a give in both knees, the hips kept over the lower foot
	crumple.knee = 0.22 * a
	crumple.hip = 0.12 * a
	crumple.ground = e
	if absf(crumple.neck) > absf(flinch_head_peak):
		flinch_head_peak = crumple.neck
	if absf(crumple.spine + crumple.pelvis) > absf(flinch_chest_peak):
		flinch_chest_peak = crumple.spine + crumple.pelvis
	if absf(crumple.chest_twist) > absf(flinch_twist_peak):
		flinch_twist_peak = crumple.chest_twist

func is_dead() -> bool:
	return dead_t >= 0.0

func _die(attacker: Node) -> void:
	_clear_flinch_layer()
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
	health = health_max
	stamina = stamina_max
	model.transform = _model_rest
	down_t = -1.0
	_air_t = -1.0
	land_t = -1.0
	_clear_jump_pose()
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
