class_name StaffCombat
extends Node
## Ward-stance light string. The staff's path is authored in body space as keyed poses
## (direction yaw/pitch + grip-centre position + spine twist); both hands are solved onto the
## shaft with two-bone IK and the torso twists into each swing, so the arms, chest and staff
## move as one over whatever the legs are doing in the locomotion blend.
## Attack: sweep -> backhand -> overhead slam -> spinning sweep. Idle 5 s -> staff slung back.
## Heavy (hold): the staff rises overhead and charges through three tiers; release brings it
## down in a planted smash. The first PARRY_WINDOW of the raise deflects an incoming blow.

signal swing_started(step: int)
signal hit_landed(target: Node, point: Vector3, power: float)
signal parried(attacker: Node)
signal charge_tier(tier: int)
signal slammed(at: Vector3, power: float)
signal plunged(at: Vector3, power: float, radius: float)

enum { SHEATHED, DRAWING, READY, ATTACKING, SHEATHING, CHARGING, DROPPED, PLUNGING, HELD }

const DRAW_TIME := 0.22
const SHEATHE_AFTER := 5.0
const HAND_R := -0.45        # metres along the staff from its centre (toward the butt)
const HAND_L := -0.10
const SHOULDER := Vector3(0.21, 1.48, -0.06)   # body space, left shoulder (mirror for right)
const REACH := 0.43          # shoulder-to-wrist reach used for the grips (arm is 0.47 m)
const TRAIL_LIFE := 0.14
# per hit of the string: stamina cost, impact power (scales hit-stop, shake, knockback, VFX)
const COST := [9.0, 9.0, 14.0, 12.0]
const POWER := [1.0, 1.0, 1.6, 1.25]
const HITSTOP := 0.065       # seconds of freeze per unit of power

# Heavy: hold time at which each tier is reached, stamina cost and power per tier.
const PARRY_WINDOW := 0.25
const PARRY_HITSTOP := 0.13
const RAISE_TIME := 0.18     # guard -> overhead
const MIN_CHARGE := 0.16     # a tap still raises the staff before it comes down
const CHARGE_TIERS := [0.0, 0.5, 1.1]
const CHARGE_MAX := 2.6      # held this long, it comes down by itself
const HEAVY_COST := [16.0, 22.0, 28.0]
const HEAVY_POWER := [1.8, 2.4, 3.2]
const SLAM_AT := 0.40        # normalised time the smash meets the ground
# Raised overhead, tip back over the shoulders, chest turned a little away.
const RAISED := [3.0, 137.0, Vector3(-0.20, 1.70, -0.04), -15.0]
const HEAVY := { "dur": 0.84, "hit": [0.22, 0.54], "lunge": 4.0, "lunge_at": 0.0, "spin": 0.0, "keys": [
	[0.00, 3.0, 137.0, Vector3(-0.20, 1.70, -0.04), -15.0],
	[0.12, 3.0, 143.0, Vector3(-0.15, 1.70, 0.03), 9.0],
	[0.40, 4.0, -40.0, Vector3(-0.21, 1.23, 0.61), -55.0, -0.26],
	[0.70, 2.0, -38.0, Vector3(-0.14, 1.35, 0.30), -3.0],
	[0.86, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],
	[1.00, 60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03]]}

# Guard: a diagonal mid guard -- rear hand low at the right flank, front hand at the belt,
# tip forward-left and down at knee height (pitch -28: at -12 it read as a level bar across the belly).  [yaw°, pitch°, P, twist°]
const GUARD := [60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03]
# Chest-high pass the arms ease through on the way back down to GUARD, so the shaft swings
# out in front of the body instead of cutting through the chest (tools/pose_check.py).
const CHAMBER := [35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03]

# Each attack: duration (s), strike window (t0, t1 normalised), lunge m/s during the strike,
# body spin (rad over the clip), keys [t, yaw°, pitch°, P, twist°, grip slide m (optional)].
# Body space: +Z forward, +X is the hero's left, so yaw -90 points out to the right.
const STRING := [
	{ "dur": 0.62, "hit": [0.30, 0.55], "lunge": 2.5, "spin": 0.0, "keys": [
		[0.00, 60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03],
		[0.10, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],    # chamber: staff up to the chest
		[0.28, -131.0, 10.0, Vector3(-0.13, 1.57, 0.08), 24.0, 0.11],
		[0.52, 95.0, -6.0, Vector3(0.31, 1.47, 0.24), 37.0],
		[1.00, 41.0, -12.0, Vector3(0.07, 1.28, 0.35), -8.0, -0.03]]},
	{ "dur": 0.58, "hit": [0.25, 0.52], "lunge": 2.0, "spin": 0.0, "keys": [
		[0.00, 41.0, -12.0, Vector3(0.07, 1.28, 0.35), -8.0, -0.03],
		[0.24, 118.0, 8.0, Vector3(0.13, 1.52, 0.14), 37.0],
		[0.50, -100.0, 0.0, Vector3(-0.34, 1.51, 0.07), -46.0],
		[1.00, -16.0, -12.0, Vector3(0.08, 1.34, 0.50), -1.0, 0.03]]},
	{ "dur": 0.80, "hit": [0.42, 0.62], "lunge": 3.5, "spin": 0.0, "keys": [
		[0.00, -16.0, -12.0, Vector3(0.08, 1.34, 0.50), -1.0, 0.03],
		[0.38, -20.0, 106.0, Vector3(0.15, 1.98, 0.09), -14.0],
		[0.60, -4.0, -28.0, Vector3(0.13, 1.28, 0.56), -21.0, -0.05],
		[1.00, 9.0, -23.0, Vector3(0.27, 1.33, 0.52), -15.0, -0.06]]},
	{ "dur": 0.85, "hit": [0.25, 0.75], "lunge": 2.0, "spin": TAU, "keys": [
		[0.00, 9.0, -23.0, Vector3(0.27, 1.33, 0.52), -15.0, -0.06],
		[0.20, -95.0, 2.0, Vector3(-0.32, 1.42, 0.12), -38.0],
		[0.30, -95.0, 2.0, Vector3(-0.62, 1.43, 0.09), -38.0, -0.30],    # staff runs out through the hands
		[0.75, -98.0, 4.0, Vector3(-0.64, 1.57, 0.13), -34.0, -0.30],
		[0.86, -98.0, 4.0, Vector3(-0.30, 1.55, 0.18), -34.0, 0.04],
		[0.94, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],
		[1.00, 60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03]]},
]

# Jump attack (light in the air, once per jump): the overhead arc of string hit 3 brought
# down from the top of the jump. The rise of it holds the hero a beat at the apex so the
# blow reads; the body keeps its momentum and the legs keep their tuck.
const AIR_COST := 10.0
const AIR_POWER := 1.35
const AIR_LIGHT := { "dur": 0.56, "hit": [0.36, 0.66], "lunge": 0.0, "spin": 0.0, "air": true, "keys": [
	[0.00, 60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03],
	[0.10, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],    # chamber: up past the chest
	[0.18, -5.0, 5.0, Vector3(0.10, 1.60, 0.60), -20.0, -0.03],      # tip swung round to the front, rising
	[0.30, -12.0, 142.0, Vector3(-0.07, 2.12, 0.17), -14.0],          # cocked back behind the head with the arch (a drawn bow; the head tips clear, Player.JA_ARCH_TILT); (11-08 11:00) hands 6 cm lower: at 2.18 the left arm ran out of reach and its fist hung 0.13 m off the shaft; (11-08 12:00) (-0.05, 2.10): at (-0.07, 2.12) the right arm was out of reach for the key tick (fist 0.04-0.10 m off), cock 39.1 -> 36.8 deg; (11-08 14:00) back to (-0.07, 2.12), cock 39.1: Crumple's keep now aims the fists onto the shaft (JUMPATK_NOSHAFT), so the out-of-reach tick no longer loses the right fist
	[0.58, -4.0, -28.0, Vector3(0.13, 1.28, 0.56), -21.0, -0.05],    # driven down (tipped by AIR_DIP)
	[1.00, 9.0, -23.0, Vector3(0.27, 1.33, 0.52), -15.0, -0.06]]}
# Plunging attack (heavy in the air): a short hang with the staff hauled overhead (the tell),
# then the hero drives straight down, ferrule first, and the landing bursts out round them.
# Power and radius grow with the height fallen; the landing soaks half the fall damage.
const PLUNGE_HANG := 0.18     # s held at the top: staff up (0.08 s), held, then swung down from 0.11 s
const PLUNGE_SPEED := 21.0    # m/s straight down after the hang
const PLUNGE_COST := 18.0
const PLUNGE_MIN := 0.7       # m of clear air below needed (lower: a plain heavy waits for the ground)
# (11-09 12:00) z 0.17 -> 0.22: the held hang stood the shaft 2.4 cm inside the hat brim at plunge
# 0.083 s; 5 cm further back it clears the brim through the whole hold. PLUNGE_HANGFWD=1 = the old.
const PLUNGE_HANG_KEY := [-12.0, 142.0, Vector3(-0.07, 2.12, 0.22), -14.0]
const PLUNGE_HANG_KEY_FWD := [-12.0, 142.0, Vector3(-0.07, 2.12, 0.17), -14.0]
var PLUNGE_HANGFWD := OS.get_environment("PLUNGE_HANGFWD") == "1"
var PLUNGE_LOWHANG := OS.get_environment("PLUNGE_LOWHANG") == "1"
var _pl_key_env: PackedFloat64Array = OS.get_environment("PL_KEY").split_floats(",") if OS.has_environment("PL_KEY") else PackedFloat64Array()
const PLUNGE_MID_KEY := [0.0, 20.0, Vector3(-0.12, 1.65, 0.55), -25.0]   # tip forward, hands out in front of the brim
const PLUNGE_MID_AT := 0.5
var PL_DIP := float(OS.get_environment("PL_DIP")) if OS.has_environment("PL_DIP") else 0.8
# (11-09 15:00) the dip fades 0.14 -> 0.20 s (was 0.17 -> 0.24): straightening the arc while the
# head was already folded into the dive stood the shaft 2.3 cm inside the hat at plunge 0.200 s;
# fading it out as the swing passes the mid key keeps every swing tick >= +0.03 m off the hat and
# the swing's worst turn drops 57.1 -> 50.3 deg/tick. PLUNGE_LATEDIP=1 = the old window.
var PLUNGE_LATEDIP := OS.get_environment("PLUNGE_LATEDIP") == "1"
var PL_DIP_OUT := OS.get_environment("PL_DIP_OUT").split_floats(",") if OS.has_environment("PL_DIP_OUT") else (PackedFloat64Array([0.17, 0.24]) if OS.get_environment("PLUNGE_LATEDIP") == "1" else PackedFloat64Array([0.14, 0.20]))
var _pl_mid_env: PackedFloat64Array = OS.get_environment("PL_MID").split_floats(",") if OS.has_environment("PL_MID") else PackedFloat64Array()
const PLUNGE_DOWN := [10.0, -70.0, Vector3(-0.20, 1.20, 0.30), -55.0, -0.05]
const PLUNGE_RISE := { "dur": 0.62, "hit": [2.0, 2.0], "lunge": 0.0, "spin": 0.0, "legs": true, "keys": [
	[0.00, 10.0, -70.0, Vector3(-0.20, 1.20, 0.30), -55.0, -0.05],   # ferrule in the turf
	[0.30, 10.0, -66.0, Vector3(-0.20, 1.18, 0.32), -55.0, -0.05],   # held a beat in the crouch
	[0.62, 2.0, -38.0, Vector3(-0.14, 1.35, 0.30), -3.0],
	[0.84, 35.0, -7.0, Vector3(-0.06, 1.46, 0.41), -24.0, -0.03],
	[1.00, 60.0, -28.0, Vector3(0.12, 1.10, 0.30), -24.0, -0.03]]}
static func plunge_power(drop: float) -> float:
	return 1.6 + clampf(drop / 4.0, 0.0, 1.6)
static func plunge_radius(drop: float) -> float:
	return 2.2 + minf(drop * 0.3, 2.3)
var plunge_t := 0.0          # s into the plunge
var _air_draw_t := -1.0      # s into a draw blended under an air move (-1: none)
var plunges := 0             # plunges landed (bots read this)
var air_attacks := 0         # jump attacks started (bots read this)
var last_plunge_hits := 0    # foes the last landing struck (bots read this)
## A plunge that lands on a boss's head or shoulders (the hero dropped from a stone onto the
## giant) is a CROWN STRIKE: it hits CROWN_K times harder, always rocks the boss back into a
## long stagger (unless it is surging), and the hero vaults off its shoulders to the ground.
const CROWN_K := 1.6
const CROWN_TOP := 0.62      # the hero touched down above this fraction of the boss's height
var crown_strikes := 0       # (bots)
var last_crown: Node = null  # (bots) the boss the last crown strike landed on

var player: Player
var staff: Staff
var skel: Skeleton3D
var state := SHEATHED
var step := -1
var t := 0.0                 # seconds into the current attack / transition
var idle_t := 0.0
var queued := false
var hit_active := false
var dip := 0.0                 # rad the swing plane tips forward-down onto a low foe (a hound)
const LOW_DIP := 0.55          # full tip toward a low target in front
## (11-08) JUMPATK_NOCOCK=1 = the old arc (the staff only upright beside the hat at the arch's peak)
var JUMPATK_NOCOCK := OS.get_environment("JUMPATK_NOCOCK") == "1"
static func _air_old() -> Dictionary:
	var d: Dictionary = AIR_LIGHT.duplicate(true)
	d["keys"][3] = [0.36, -20.0, 106.0, Vector3(0.15, 1.98, 0.09), -14.0]
	return d
## (11-08 11:00) a staff snatched off the back by a jump attack is in both fists by the end of
## the chamber (u 0.21), eased; at DRAW_TIME it was still 0.3-0.6 m from the fists at the
## arch's peak, the arms posed round nothing beside a staff lagging on the back (env
## JUMPATK_SLOWSNATCH=1 = the old 0.22 s linear snatch and slow grip roll)
const AIR_DRAW_TIME := 0.12
const AIR_ROLL_RATE := 16.0
var JUMPATK_SLOWSNATCH := OS.get_environment("JUMPATK_SLOWSNATCH") == "1"
## (11-08 12:00) in the snatch's last half the grip roll's feed already takes the fists onto the
## shaft (they rode 0.09-0.15 m off it for ~5 ticks after the snatch: the gate waited on the
## fingers closing, eased at HAND_RATE, and on the full draw). JUMPATK_LATEFEED=1 = old gate.
var JUMPATK_LATEFEED := OS.get_environment("JUMPATK_LATEFEED") == "1"
## (11-09 04:00) a jump attack that has finished its blow before touch-down holds the struck pose
## until the feet meet the turf (at most AIR_HOLD_MAX s; on a longer fall it lets go back to guard).
## JUMPATK_NOAIRHOLD=1 = the old drop back to guard in the air.
const AIR_HOLD_MAX := 0.45
var JUMPATK_NOAIRHOLD := OS.get_environment("JUMPATK_NOAIRHOLD") == "1"
var air_hold_t := 0.0          # s the current jump attack has held its struck pose in the air
var air_holds := 0             # jump attacks that held their struck pose into the fall (bots)

## (11-09 08:00) a plunge pressed with the staff slung snatches it into both fists by the top of
## the raise (plunge_t 0.08): it used to take the jump attack's 0.12 s snatch with the slow 6/s
## grip roll and closed fingers only past _blend 0.9, so at the hang (plunge_t ~0.07) the staff
## still lay on the back and the hands hung empty at the belt, and the fists only met the shaft
## at ~0.25 s, in the dive. PLUNGE_SLOWSNATCH=1 = old.
const PLUNGE_DRAW_TIME := 0.075
var PLUNGE_SLOWSNATCH := OS.get_environment("PLUNGE_SLOWSNATCH") == "1"
## (11-09 10:00) PLUNGE_SNATCHRAW=1 = the snatch blended straight through the hat (before).
var PLUNGE_SNATCHRAW := OS.get_environment("PLUNGE_SNATCHRAW") == "1"
var _air_draw_dur := AIR_DRAW_TIME
## (11-09 11:00) the 10:00 fix tipped the shaft only once the straight blend reached the hat and
## let go at f = 1, so the snatch whipped (68 deg in one tick). Now the whole snatch bows out
## round the side of the head: the blended staff is turned about the right fist by
## PL_BOW x sin(pi f) about the body's forward axis (zero at both ends, so no jump into or out
## of it); the hat tip stays under it as a net. PLUNGE_SNATCHTIP=1 = the 10:00 tip-only snatch.
var PLUNGE_SNATCHTIP := OS.get_environment("PLUNGE_SNATCHTIP") == "1"
## (11-09 16:00) the snatch's hat clearance used the hat where LAST tick's pose left it; on the
## plunge's first tick the dive folds the head 0.18 m forward and the shaft, cleared against the
## old hat, stood 2 cm inside the brim of the new one. Once the skeleton is posed this tick the
## clearance runs again against the hat where it now is. PLUNGE_PREPOSEHAT=1 = the old.
var PLUNGE_PREPOSEHAT := OS.get_environment("PLUNGE_PREPOSEHAT") == "1"
var snatch_posed_tip := 0.0   # (bots) the largest extra tip the posed re-clear gave (rad)
func _snatch_clear_posed() -> void:
	if PLUNGE_PREPOSEHAT or PLUNGE_SNATCHRAW or state != PLUNGING or _air_draw_t < 0.0 or staff == null:
		return
	var before := staff.global_basis.y.normalized()
	_draw_clear_hat()
	snatch_posed_tip = maxf(snatch_posed_tip, before.angle_to(staff.global_basis.y.normalized()))
var PL_BOW_YAW := deg_to_rad(float(OS.get_environment("PL_BOW_YAW"))) if OS.has_environment("PL_BOW_YAW") else 0.0
var PL_BOW := deg_to_rad(float(OS.get_environment("PL_BOW"))) if OS.has_environment("PL_BOW") else deg_to_rad(-50.0)

## True while a move in the air snatches the staff: a jump attack, or a plunge (unless old).
func _air_snatching_move() -> bool:
	return is_air_attack() or (state == PLUNGING and not PLUNGE_SLOWSNATCH)

## True while a snatch off the back is blended under an air move and has passed its half.
func air_snatch_late() -> bool:
	return not JUMPATK_LATEFEED and not JUMPATK_SLOWSNATCH and _air_snatching_move() and _blend > 0.5
const AIR_DIP := 0.42          # the jump attack's strike tips down from the apex
var spin_delta := 0.0        # body yaw the current attack added this frame
var _spin_applied := 0.0     # last frame's spin_delta, which the body turned by this frame
var swings := 0              # attacks started (bots read this)
var last_grip_error := 0.0   # metres, hand bone to IK target after the last IK pass
var hitstop := 0.0           # remaining freeze after a connecting hit
var hits := 0                # hits landed (bots read this)
var _hit_this_swing: Array = []
var _atk: Dictionary = {}    # the attack in progress (a STRING entry or HEAVY)
var _power := 1.0
var heavy_held := false      # the player sets this every tick from the heavy button
var _heavy_queued := false
var charge_t := 0.0          # seconds into the current charge
var tier := 0                # charge tier reached (0..2)
var heavies := 0             # heavy smashes released (bots read this)
var parries := 0             # blows deflected (bots read this)
var last_power := 0.0        # power of the last hit that landed (bots read this)
var _slammed := false
var _raise_from: Array = GUARD
var _prev_u := -1.0          # normalised swing time at the last contact test
const RECOVER_TIME := 0.26
var _recover := 0.0          # remaining blend from a cancelled swing back to guard
var _from_pose: Array = GUARD
var _recover_keys: Array = []  # the path picked by _begin_recover (keys [t] + pose)

var _back_slot: Node3D
var _back_xform: Transform3D
var _wield: Node3D
var SQUARE_INBEND := OS.get_environment("SQUARE_BENDOFF") != "1"
var GUARD_NORIDE := OS.get_environment("GUARD_NORIDE") == "1"
var shoulder_body := [Vector3.ZERO, Vector3.ZERO]   # [R, L] shoulder joints, body space (read-out)
var ride := Vector3.ZERO                            # the Wield frame's carry with the shoulders, m
var SHOULDER_MID_REF := Vector3(0.02, 1.385, 0.014) # shoulder joints' midpoint standing at guard (measured)
const YAW_REF := -0.30          # the shoulder line's heading standing at guard (measured), rad
var chest_yaw := 0.0            # the clip's shoulder-line heading (read-out), rad
var counter_twist := 0.0        # the yaw added to SpineTwist to hold the chest square to the staff
var TWIST_GAIN := float(OS.get_environment("TWIST_GAIN")) if OS.has_environment("TWIST_GAIN") else 0.85
const TWIST_MAX := 0.9
var TWIST_RATE := float(OS.get_environment("TWIST_RATE")) if OS.has_environment("TWIST_RATE") else 4.0     # /s, the square weight eases in and out
var CLAV_HOLD := float(OS.get_environment("CLAV_HOLD")) if OS.has_environment("CLAV_HOLD") else 0.0
var RIDE_GAIN := float(OS.get_environment("RIDE_GAIN")) if OS.has_environment("RIDE_GAIN") else 1.0
const RIDE_MAX := 0.30
const RIDE_RATE := 10.0
var STRIKE_SINK_SHARE := float(OS.get_environment("STRIKE_SINK_SHARE")) if OS.has_environment("STRIKE_SINK_SHARE") else 1.0
var strike_sink := 0.0          # m the staff is carried down with the strike landing this tick
## (11-07) knocked down, the hero keeps the drawn staff in the right fist instead of leaving it
## hanging in the air at guard height in Wield space. Each tick, after the modifiers (the posed
## hand), the shaft is put through the fist: first as it was held, then laid flat on the turf as
## the back hits the ground (`held_lay`), then its butt planted on the turf outside the front knee
## to push up on (`held_plant`). The player drives both weights. Env KNOCK_FLOATSTAFF: the before.
var hold_on := true
var held_lay := 0.0
var held_plant := 0.0
var held_guard := 0.0
var held_reach_l := 0.0   # 0..1 (knock-down rise): the shaft tips in the right fist toward the left arm's reach
var _held_shoulder_l := Vector3.ZERO
var held_ground := 0.0       # world height of the turf under the hero (the player sets it)
var _held_rel := Transform3D()
var _held_rel_ok := false
var _from_xform: Transform3D
var _target_r: Node3D
var _target_l: Node3D
var _ik: TwoBoneIK3D
## (11-06) the fists round the shaft (as the foes'): the arm IK lands the WRIST on the grip
## point, so the staff ran beside the closed fingers; after the modifiers each closed fist's
## centre is measured against the staff's axis and the wrist target moved (Wield space) by a
## share of the gap, so the shaft runs through the curl. Env HERO_WRISTGRIP: the before.
var fist_fit_on := true
var _fist_off: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # right, left: Wield-space wrist shift
var fist_gap: Array[float] = [0.0, 0.0]   # (bots) right, left: fist centre to the staff axis, m
var fist_gain := 0.6           # of the measured gap taken out each tick (bots: env FIST_GAIN)
const FIST_MAX := 0.15
var _twist: SpineTwist
var grip_roll: GripRoll
var _blend := 0.0            # IK/twist influence, eased in on draw
var _spun := 0.0
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []   # [age, tip, mid]

func setup(p: Player, s: Staff, sk: Skeleton3D) -> void:
	player = p
	staff = s
	skel = sk
	_back_slot = staff.get_parent()
	_back_xform = staff.transform
	_wield = Node3D.new()
	_wield.name = "Wield"
	player.body.add_child(_wield)
	hold_on = OS.get_environment("KNOCK_FLOATSTAFF") == ""
	skel.skeleton_updated.connect(_place_held)
	skel.skeleton_updated.connect(_snatch_clear_posed)
	_target_r = _marker("GripR")
	_target_l = _marker("GripL")
	var pole_r := _marker("PoleR")
	var pole_l := _marker("PoleL")
	# elbows bend down and out, away from the shaft
	pole_r.position = Vector3(-0.75, 0.7, -0.35)
	pole_l.position = Vector3(0.75, 0.7, -0.35)

	_twist = SpineTwist.new()
	_twist.name = "SpineTwist"
	skel.add_child(_twist)
	_twist.up = player.body
	_ik = TwoBoneIK3D.new()
	_ik.name = "ArmIK"
	skel.add_child(_ik)
	_ik.setting_count = 2
	var arms := [["Right", _target_r, pole_r], ["Left", _target_l, pole_l]]
	for i in 2:
		var side: String = arms[i][0]
		_ik.set_root_bone_name(i, "mixamorig_%sArm" % side)
		_ik.set_middle_bone_name(i, "mixamorig_%sForeArm" % side)
		_ik.set_end_bone_name(i, "mixamorig_%sHand" % side)
		_ik.set_target_node(i, _ik.get_path_to(arms[i][1]))
		_ik.set_pole_node(i, _ik.get_path_to(arms[i][2]))
	# (11-06) the hands may only roll about the shaft (GripRoll); env HERO_FREEHANDS: the before
	if OS.get_environment("HERO_FREEHANDS") == "":
		grip_roll = GripRoll.new()
		grip_roll.name = "GripRoll"
		grip_roll.staff = staff
		skel.add_child(grip_roll)
		skel.move_child(grip_roll, _ik.get_index() + 1)
	_set_influence(0.0)
	# the modified pose only exists right after the modifiers ran; sample the grip there
	_ik.modification_processed.connect(func(): last_grip_error = _measure_grip())
	if OS.get_environment("HERO_WRISTGRIP") == "":
		skel.skeleton_updated.connect(_fit_fists)
	if OS.has_environment("FIST_GAIN"):
		fist_gain = float(OS.get_environment("FIST_GAIN"))

	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "SwingTrail"
	_trail.top_level = true
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/swing_trail.gdshader")
	_trail.material_override = mat
	player.add_child(_trail)

func _marker(n: String) -> Node3D:
	var m := Node3D.new()
	m.name = n
	_wield.add_child(m)
	return m

func _set_influence(v: float) -> void:
	_blend = v
	_ik.influence = v
	_ik.active = v > 0.001
	_twist.influence = v
	_twist.active = v > 0.001

func is_drawn() -> bool:
	return state != SHEATHED

func is_attacking() -> bool:
	return state == ATTACKING

func is_charging() -> bool:
	return state == CHARGING

func is_plunging() -> bool:
	return state == PLUNGING

## The swing in progress leaves the legs to the jump/landing pose (a jump attack, the plunge's rise).
func legs_free() -> bool:
	return state == ATTACKING and (_atk.get("air", false) or _atk.get("legs", false))

func is_air_attack() -> bool:
	return state == ATTACKING and _atk.get("air", false)

## 0..1 through the jump attack's clip (-1 when no jump attack is swinging).
func air_attack_u() -> float:
	return clampf(t / float(_atk["dur"]), 0.0, 1.0) if is_air_attack() else -1.0

func current_attack() -> Dictionary:
	return _atk

## The released heavy is committed from the moment it starts down until the strike has passed:
## a blow landing then is taken without breaking the swing.
func has_hyper_armour() -> bool:
	if state == PLUNGING or (state == ATTACKING and _atk == PLUNGE_RISE and t < 0.25):
		return true
	return state == ATTACKING and _atk == HEAVY and t / float(_atk["dur"]) < float(_atk["hit"][1])

## Heavy pressed: start raising the staff (drawing it first if slung). During a light swing
## it cuts in once the strike has passed, otherwise it waits for the swing to finish.
func heavy() -> void:
	if state == PLUNGING or (state == ATTACKING and _atk == PLUNGE_RISE):
		return
	if player.plunge_ok() and state in [SHEATHED, SHEATHING, DRAWING, READY, ATTACKING, CHARGING]:
		_start_plunge()
		return
	match state:
		SHEATHED, SHEATHING:
			_begin_draw()
			_heavy_queued = true
			queued = false
		DRAWING:
			_heavy_queued = true
			queued = false
		READY:
			_start_charge()
		ATTACKING:
			if _atk == HEAVY:
				return
			var u := t / float(_atk["dur"])
			if u > float(_atk["hit"][1]):
				_from_pose = _pose_at(_atk["keys"], clampf(u, 0.0, 1.0))
				_start_charge(_from_pose)
			else:
				_heavy_queued = true
				queued = false

func _start_charge(from: Array = []) -> void:
	if player.stamina <= 0.0:
		return
	if from.size() > 0:
		_raise_from = from
	elif _recover > 0.0 and _recover_keys.size() > 1:
		# raise from where the ease back to guard has got to, not from where it began
		_raise_from = _pose_at(_recover_keys, 1.0 - _recover / RECOVER_TIME)
		_raise_from[0] = wrapf(_raise_from[0], -180.0, 180.0)
	else:
		_raise_from = GUARD
	_recover = 0.0
	state = CHARGING
	step = -1
	charge_t = 0.0
	tier = 0
	t = 0.0
	queued = false
	_heavy_queued = false
	hit_active = false
	idle_t = 0.0

## True while a blow landing now would be deflected: the opening of the heavy's raise.
func can_parry() -> bool:
	return state == CHARGING and charge_t <= PARRY_WINDOW and hitstop <= 0.0

## Enemies' blows ask this first. A deflect freezes both fighters, throws sparks off the
## shaft, staggers the attacker and banks a free charge tier.
func try_parry(attacker: Node) -> bool:
	if not can_parry():
		return false
	parries += 1
	hitstop = PARRY_HITSTOP
	var to := player.body.global_basis.z
	if attacker is Node3D:
		to = (attacker as Node3D).global_position - player.global_position
	to.y = 0.0
	to = to.normalized() if to.length() > 1e-3 else player.body.global_basis.z
	var spark := staff.global_transform * Vector3(0, Staff.LENGTH * 0.18, 0)
	spark = spark.lerp(player.global_position + Vector3.UP * 1.5 + to * 0.45, 0.5)
	ImpactFX.spawn(player.get_parent(), spark, to.cross(Vector3.UP), "metal", 1.6)
	player.add_shake(0.42)
	charge_t = maxf(charge_t, float(CHARGE_TIERS[1]))
	_set_tier(1)
	if attacker.has_method("parried"):
		attacker.parried(to, PARRY_HITSTOP)
	parried.emit(attacker)
	return true

func _set_tier(n: int) -> void:
	if n <= tier:
		return
	tier = n
	# a cold glint off the ferrule marks each tier
	ImpactFX.spawn(player.get_parent(), tip_position(), Vector3.UP, "metal", 0.35 + 0.2 * n)
	player.add_shake(0.06 * n)
	charge_tier.emit(n)

func _release() -> void:
	var cost: float = HEAVY_COST[tier]
	player.stamina = maxf(player.stamina - cost, 0.0)
	_atk = HEAVY
	_power = HEAVY_POWER[tier]
	_hit_this_swing.clear()
	_prev_u = -1.0
	_slammed = false
	step = -1
	t = 0.0
	_spun = 0.0
	queued = false
	idle_t = 0.0
	state = ATTACKING
	swings += 1
	heavies += 1
	swing_started.emit(-1)

## Light attack pressed: draw if needed, start or queue the next hit of the string.
func light() -> void:
	if state in [READY, SHEATHED, SHEATHING, DRAWING] and player.air_attack_ok():
		_start_air()
		return
	if state == PLUNGING:
		return
	match state:
		SHEATHED, SHEATHING:
			_begin_draw()
			queued = true
		DRAWING:
			queued = true
		READY:
			_start(0)
		ATTACKING:
			if t / float(_atk["dur"]) > 0.35 and not _heavy_queued:
				queued = true

## A dodge breaks off whatever swing is in progress; the arms ease back to guard from the
## pose they were in instead of snapping.
func cancel_to_guard() -> void:
	_heavy_queued = false
	if state == CHARGING:
		_from_pose = _charge_pose()
	elif state == ATTACKING:
		_from_pose = _pose_at(_atk["keys"], clampf(t / float(_atk["dur"]), 0.0, 1.0))
	else:
		return
	_begin_recover()
	state = READY
	step = -1
	queued = false
	idle_t = 0.0
	hit_active = false
	_prev_u = -1.0

## The hero has fallen: the arms let go and a drawn staff drops and topples flat into the
## grass beside the body (a slung one stays on the back).
var _drop_rest := Basis()
var _drop_v := 0.0

func drop() -> void:
	_air_draw_t = -1.0
	cancel_to_guard()
	_heavy_queued = false
	queued = false
	hitstop = 0.0
	_set_influence(0.0)
	_twist.twist = 0.0
	if staff.get_parent() == _back_slot:
		staff.transform = _back_xform
		state = SHEATHED
		return
	staff.reparent(player.get_parent(), true)
	var flat := Vector3(staff.global_basis.y.x, 0.0, staff.global_basis.y.z)
	if flat.length() < 0.1:
		flat = player.body.global_basis.x
	_drop_rest = Basis(Quaternion(Vector3.UP, flat.normalized()))
	_drop_v = 0.0
	state = DROPPED

## Knocked down: the IK lets go of the arms (the knock-down pose owns them) but the right fist
## keeps the staff, which now rides the posed right hand through the fall and the get-up.
## Returns false (nothing to hold) when the staff is slung on the back.
func hold() -> bool:
	if not hold_on or staff.get_parent() == _back_slot or state == DROPPED:
		return false
	if state == HELD:
		return true
	_air_draw_t = -1.0
	cancel_to_guard()
	_heavy_queued = false
	queued = false
	hitstop = 0.0
	_set_influence(0.0)
	_twist.twist = 0.0
	staff.reparent(player.get_parent(), true)
	_held_rel_ok = false
	_held_prev_ok = false
	_held_dt = 0.0
	held_lay = 0.0
	held_plant = 0.0
	held_guard = 0.0
	held_reach_l = 0.0
	_held_shoulder_l = Vector3.ZERO
	head_clear_min = 9.0
	head_tip_max = 0.0
	draw_tip_max = 0.0
	head_tip_reach = 0.0
	held_hold_max = 0.0
	# which end of the shaft rises: the end on the left hand's side of the guard grips (the reach to
	# the left hand at the end of the rise stands that end up; latching the other one flipped the
	# shaft end for end there). Read in the wield's own frame, independent of the body's fall.
	var gy := _staff_xform(GUARD).basis.y.normalized()
	_lay_top = 1.0 if (_target_l.position - _target_r.position).dot(gy) >= 0.0 else -1.0
	state = HELD
	return true

func _hand_xform() -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand"))

## The shaft through the posed right fist (see `hold`): the axis turns from the held one to the
## laid one to the planted one, and the fist slides along it, so the shaft always runs through the
## fist (blending the two placements' centres let it drift 0.17 m off the hand mid-turn).
var _plant_sign := 0.0
const PLANT_BACK := deg_to_rad(16.0)
const PLANT_OUT := deg_to_rad(15.0)
const LAY_GRIP := 0.36     # laid: the fist this far (x LENGTH) from the centre, near the butt (short end ~0.26 m over the thigh)
const LAY_BACK := 0.7       # laid out to the right and back this much (tan): its rise to the plant stays clear of the head
const LAY_END_H := 0.13     # m over the hero's feet: where the laid shaft's far end rests on the sward
var _lay_top := 0.0
## (04:00 11-08) the shaft's axis never turns faster than this in the fist: the guard turn and the
## reach to the left hand stacked into a ~90 deg whip over two 15 Hz ticks (~650 deg/s) as the hero
## came up. Clamped about the fist, so the fist stays on the shaft; it trails its target by a few
## degrees through the peak and catches up as the turn eases out.
const HELD_MAX_RATE := deg_to_rad(400.0)
var _held_prev := Quaternion.IDENTITY
var _held_prev_ok := false
var _held_dt := 0.0          # game time since the last placement (physics_step adds, _place_held spends)
var _held_base := Quaternion.IDENTITY   # the shaft at the end of the last tick (the limit's reference)
var _held_base_dt := 0.0
func _limit_held_turn(q: Quaternion) -> Quaternion:
	if OS.has_environment("KNOCK_NORATE"):
		return q
	if not _held_prev_ok:
		_held_prev = q
		_held_base = q
		_held_base_dt = 0.0
		_held_prev_ok = true
		_held_dt = 0.0
		return q
	if _held_dt > 0.0 or OS.has_environment("KNOCK_TICKFREEZE"):
		# a new tick: limit against where the shaft ended last tick. (05:00 11-08) A second placement
		# in the same tick (Crumple's fist_l_fn, then skeleton_updated) limits against that same base
		# with the same dt, not against the first placement with dt 0: frozen on the first pass's
		# axis it ignored this pass's posed fist and head, and the hat clearance then had to tip
		# it 13 deg in one go (the 34 deg tick at 1.73)
		_held_base = _held_prev
		_held_base_dt = _held_dt
	var a0 := _held_base * Vector3.UP
	var a1 := q * Vector3.UP
	var ang := a0.angle_to(a1)
	var lim := HELD_MAX_RATE * _held_base_dt
	_held_dt = 0.0
	if ang > lim and ang > 1e-4:
		# swing the target back toward last tick's axis (shortest arc), keeping its roll
		q = Quaternion(a1, a0.slerp(a1, lim / ang).normalized()) * q
	_held_prev = q
	return q

func _place_held() -> void:
	if state != HELD:
		return
	var hand := _hand_xform()
	if not _held_rel_ok:
		_held_rel = hand.affine_inverse() * staff.global_transform
		_held_rel_ok = true
		_plant_sign = 0.0
	var fist := fist_center("Right")           # the closed fist's centre (Crumple's grip has closed it)
	var held := hand * _held_rel
	var q := held.basis.get_rotation_quaternion()
	var ax0 := held.basis.y.normalized()
	var sl := (fist - held.origin).dot(ax0)    # where along the shaft the fist is (from the centre)
	if held_lay > 0.0:
		var ax := Vector3(ax0.x, 0.0, ax0.z)
		ax = ax.normalized() if ax.length() > 0.1 else player.body.global_basis.z
		var lay_sl := -Staff.LENGTH * 0.18
		if not OS.has_environment("KNOCK_LAYHEAD"):
			# (03:00 11-08) flat on the turf out to the right and back, the guard's top end long:
			# laid on its old heading the long end could lie up by the head, and the turn to the
			# plant then swung it up past the face. Laid this way the top rises to the plant in a
			# plane out on the right side, ~0.8 m off the head, and stays the top through the guard
			# turn (choosing the end by the old heading flipped the shaft end for end there).
			var lfw := player.body.global_basis.z
			lfw = Vector3(lfw.x, 0.0, lfw.z).normalized()
			var lrt := -player.body.global_basis.x
			lrt = Vector3(lrt.x, 0.0, lrt.z).normalized()
			var out := (lrt - lfw * LAY_BACK).normalized()
			if _lay_top == 0.0:
				_lay_top = 1.0   # (hold() latches it while still upright; the wield tips with the body as it falls)
			# the far end stays on the grass as the fist rises in the sit-up: the shaft trails down
			# from the fist to the turf instead of being held out level in the air
			var reach := Staff.LENGTH * (0.5 + LAY_GRIP)
			var drop := clampf((fist.y - held_ground - LAY_END_H) / reach, -0.15, 0.7)
			ax = (out * sqrt(1.0 - drop * drop) - Vector3.UP * drop) * _lay_top
			lay_sl = -Staff.LENGTH * LAY_GRIP * _lay_top   # centre = fist - ax * sl = fist + out * LAY_GRIP L
		q = q.slerp(Quaternion(ax0, ax) * q, held_lay)
		# the fist runs down toward the butt ahead of the turn, so the short end is already short
		# while the axis still points up past the head mid-fall
		sl = lerpf(sl, lay_sl, sqrt(held_lay) if not OS.has_environment("KNOCK_LAYHEAD") else held_lay)
	if held_plant > 0.0:
		# planted: the shaft stands up through the fist on the front knee, tipped back and out so its
		# top clears the head outside the right shoulder, and its butt meets the turf a little
		# ahead of and inside the knee (a butt set out to the side tipped the top in through the hat)
		var fw := player.body.global_basis.z
		fw.y = 0.0
		fw = fw.normalized()
		var right := -player.body.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var up := (Vector3.UP - fw * tan(PLANT_BACK) + right * tan(PLANT_OUT)).normalized()
		var butt := fist - up * maxf(fist.y - held_ground - 0.02, 0.05) / up.y
		var cur := q * Vector3.UP
		if _plant_sign == 0.0:
			_plant_sign = 1.0 if cur.dot(up) >= 0.0 else -1.0   # latched: no flip end for end mid-turn
			if _lay_top != 0.0:
				# (03:00 11-08) the end that lay out to the back-right (the guard's top) rises to the top
				_plant_sign = _lay_top
		var ax2 := up * _plant_sign
		q = q.slerp(Quaternion(cur, ax2) * q, held_plant)
		sl = lerpf(sl, _plant_sign * (fist.distance_to(butt) - Staff.LENGTH * 0.5), held_plant)
	if held_guard > 0.0:
		# coming up: the shaft turns in the fist to the guard's line and slides to the guard grip,
		# so the draw back into both hands that follows only has a few cm left to cover
		var g := _wield.global_transform * _staff_xform(GUARD)
		var gq := g.basis.get_rotation_quaternion()
		var grip_r := _wield.global_transform * _target_r.position
		q = q.slerp(gq, held_guard)
		sl = lerpf(sl, (grip_r - g.origin).dot(g.basis.y.normalized()), held_guard)
	if held_reach_l > 0.0 and _held_shoulder_l != Vector3.ZERO and not OS.has_environment("KNOCK_NOREACH"):
		# (11-08) the right fist is still low by the knee as the arms come up, so the guard's line
		# through it passed ~0.4 m off the left shoulder and the left hand could only close on the
		# shaft at the very end: tip the shaft in the fist so it runs through a spot the left arm
		# can take (the guard's left grip, drawn in to REGRIP_AIM of the shoulder)
		var g2 := _wield.global_transform * _staff_xform(GUARD)
		var gax := g2.basis.y.normalized()
		var gl := _wield.global_transform * _target_l.position
		var gr := _wield.global_transform * _target_r.position
		var span := (gl - g2.origin).dot(gax) - (gr - g2.origin).dot(gax)   # right grip -> left grip along the axis
		var to := gl - _held_shoulder_l
		var aim := _held_shoulder_l + to.limit_length(REGRIP_AIM)
		var d := aim - fist
		if d.length() > 0.15 and absf(span) > 0.05:
			var cur3 := q * Vector3.UP
			var want := d.normalized() * signf(span)
			var qt := Quaternion(cur3, want) * q
			if not OS.has_environment("KNOCK_REACHRAW"):
				# (05:00 11-08) the reach's own target is cleared round the hat before the turn, so the
				# slerp runs toward a line already outside the brim and the late clearance no longer has
				# to tip the shaft round the hat in one tick (a 14 deg tip -> a 34 deg tick at 1.73)
				qt = _clear_head(qt, fist, sl, false)
			q = q.slerp(qt, held_reach_l)
	var _dbg_q := q
	q = _limit_held_turn(_clear_head(q, fist, sl))
	if not OS.has_environment("KNOCK_TIPPAST"):
		q = _hold_clear(q, fist, sl)
	q = _clear_head(q, fist, sl)
	_held_prev = q   # (the clearance wins over the rate limit: never through the hat)
	if OS.has_environment("SPIN_DBG") and held_guard > 0.0:
		var gdb := (_wield.global_transform * _staff_xform(GUARD)).basis.y.normalized()
		print("HG t %.3f guard %.2f reach %.2f want-vs-guard %.1f final-vs-guard %.1f" % [player.down_t, held_guard, held_reach_l, rad_to_deg((_dbg_q * Vector3.UP).angle_to(gdb)), rad_to_deg((q * Vector3.UP).angle_to(gdb))])
	var ax3 := q * Vector3.UP
	if held_lay > 0.0 and absf(ax3.y) > 0.12 and not OS.has_environment("KNOCK_LAYHEAD"):
		# (03:00 11-08) as the long end rises off the turf the short end pivots on the ground: the
		# fist slides up the shaft rather than the butt digging into the turf
		var lo_end := minf((fist - ax3 * sl + ax3 * Staff.LENGTH * 0.5).y, (fist - ax3 * sl - ax3 * Staff.LENGTH * 0.5).y)
		var floor_y := held_ground - 0.02
		if lo_end < floor_y:
			sl -= (floor_y - lo_end) / ax3.y   # centre = fist - a * sl: raising it by d takes sl -= d / a.y
	staff.global_transform = Transform3D(Basis(q).scaled(held.basis.get_scale()), fist - ax3 * sl)

## (11-08) The held shaft never runs through the hero's head and hat: the laid -> planted turn
## swung its top straight through the hat's crown (1.20..1.33 s into the knock-down) and the
## reach toward the left arm put it 0.10 m into the brim (1.67..1.73). If the shaft line passes
## within HEAD_CLEAR of the hat's centre on the part of the shaft past the fist, it is tipped
## about the fist just far enough out to clear it. The hat's centre comes off this tick's posed
## head bone (the hat's attachment can lag a tick inside the pose).
const HEAD_CLEAR := 0.34    # m: shaft axis to the hat's centre (brim 0.29 + the shaft's radius + a hair)
var _hat_rel := Transform3D()
var _hat_rel_ok := false
var head_clear_min := 9.0    # (bots) least shaft-to-hat-centre distance after the clearance, this knock-down
var head_tip_reach := 0.0    # (bots) the same during the tip toward the left hand
var held_hold_max := 0.0     # (bots) the largest share of a tick's turn held back at the brim's edge
var head_tip_max := 0.0      # (bots, 03:00 11-08) the largest tip `_clear_head` had to give (rad): the raw path into the face
func hat_centre() -> Vector3:
	var hat: MeshInstance3D = player.garb.hat if player.garb != null else null
	if hat == null or hat.mesh == null:
		return Vector3.INF
	var hb := skel.find_bone("mixamorig_Head")
	if hb < 0:
		return Vector3.INF
	if not _hat_rel_ok:
		var att: Node = hat.get_parent()
		while att != null and not att is BoneAttachment3D:
			att = att.get_parent()
		if att == null:
			return Vector3.INF
		_hat_rel = (att as Node3D).global_transform.affine_inverse() * hat.global_transform
		_hat_rel_ok = true
	return skel.global_transform * skel.get_bone_global_pose(hb) * _hat_rel * hat.mesh.get_aabb().get_center()

func _clear_head(q: Quaternion, fist: Vector3, sl: float, track := true) -> Quaternion:
	if OS.has_environment("KNOCK_NOCLEAR"):
		return q
	var h := hat_centre()
	if not h.is_finite():
		return q
	var a := q * Vector3.UP
	var hf := h - fist
	var along := hf.dot(a)
	# only the stretch of shaft that is there: from the fist, (LENGTH/2 - sl) one way, (LENGTH/2 + sl) the other
	var ext := Staff.LENGTH * 0.5 - sl if along >= 0.0 else Staff.LENGTH * 0.5 + sl
	var d := (hf - a * along).length()
	if absf(along) > ext + HEAD_CLEAR:
		if track:
			head_clear_min = minf(head_clear_min, hf.length())
		return q
	var r := hf.length()
	if r <= HEAD_CLEAR + 0.01:
		return q     # the fist itself at the hat: nothing a tip can fix
	var want := asin(HEAD_CLEAR / r)            # the least angle between the shaft and the fist->hat line
	var dir := a if along >= 0.0 else -a          # the half of the shaft that points toward the hat
	var now := dir.angle_to(hf)
	if now >= want:
		if track:
			head_clear_min = minf(head_clear_min, d)
		return q
	var spin := hf.cross(dir)
	if spin.length() < 1e-4:
		spin = player.body.global_basis.x.cross(hf)   # dead on the hat: tip it out to the right
	spin = spin.normalized()
	var fix := Quaternion(spin, want - now)
	if not track:
		return fix * q
	if held_reach_l > 0.0:
		head_tip_reach = maxf(head_tip_reach, want - now)   # the reach to the left hand (11-08 item o), tracked apart
	else:
		head_tip_max = maxf(head_tip_max, want - now)
	if OS.has_environment("TIP_DBG"):
		print("TIP t %.3f tip %.1f deg along %.2f lay %.2f plant %.2f guard %.2f reach %.2f" % [player.down_t, rad_to_deg(want - now), along, held_lay, held_plant, held_guard, held_reach_l])
	head_clear_min = minf(head_clear_min, HEAD_CLEAR)
	return fix * q

## (05:00 11-08) The rate-limited turn takes the shortest arc from last tick's shaft, and in the
## reach to the left hand that arc ran through the hat: the clearance then tipped it ~13 deg out
## on top of the full 400 deg/s step (a 34 deg tick at 1.73). Instead, go only as far along the
## arc as stays clear of the hat (and within the rate): the shaft waits at the brim's edge for a
## tick and comes round it, never swinging out past it in one jerk.
func _tip_needed(q: Quaternion, fist: Vector3, sl: float) -> float:
	return (q * Vector3.UP).angle_to(_clear_head(q, fist, sl, false) * Vector3.UP)

func _hold_clear(q: Quaternion, fist: Vector3, sl: float) -> Quaternion:
	if not _held_prev_ok or _held_base_dt <= 0.0:
		return q
	if _tip_needed(q, fist, sl) < deg_to_rad(0.5):
		return q
	if _tip_needed(_held_base, fist, sl) > deg_to_rad(0.5):
		return q       # last tick's shaft is itself in the way now (the head moved): the clearance must win
	if not OS.has_environment("KNOCK_HOLDWAIT"):
		# (11-08) waiting at the brim never came round when the target lay on the hat's far side
		# (the planted shaft -> the guard): the shaft stood still at the brim for the whole rise
		# and the draw then had ~116 deg to cover, through the hat. Now each tick steps round
		# the brim: the step is tipped clear of the hat, then held to the turn rate from last
		# tick's shaft (the last clearance pass fixes the hair it may cut back in).
		var cq := _clear_head(q, fist, sl, false)
		var b0 := _held_base * Vector3.UP
		var c1 := cq * Vector3.UP
		var ang := b0.angle_to(c1)
		var lim := HELD_MAX_RATE * _held_base_dt
		if ang > lim and ang > 1e-4:
			cq = Quaternion(c1, b0.slerp(c1, lim / ang).normalized()) * cq
		held_hold_max = maxf(held_hold_max, (cq * Vector3.UP).angle_to(q * Vector3.UP))
		return cq
	var best := _held_base
	var t := 0.0
	for i in range(1, 21):
		var u := float(i) / 20.0
		var c := _held_base.slerp(q, u)
		if _tip_needed(c, fist, sl) > deg_to_rad(0.5):
			break
		best = c
		t = u
	held_hold_max = maxf(held_hold_max, 1.0 - t)
	return best

func _axis_xform(ax: Vector3, centre: Vector3) -> Transform3D:
	var ref := Vector3.UP if absf(ax.y) < 0.9 else Vector3.FORWARD
	var x := ref.cross(ax).normalized()
	return Transform3D(Basis(x, ax, x.cross(ax)), centre)

## Blend two shaft placements: the axis turns, the centre slides (no flip if the axis reverses).
func _xform_between(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	var bb := b.basis
	if a.basis.y.dot(bb.y) < 0.0:
		bb = Basis(-bb.x, -bb.y, bb.z)
	var q := a.basis.get_rotation_quaternion().slerp(bb.get_rotation_quaternion(), w)
	return Transform3D(Basis(q), a.origin.lerp(b.origin, w))

## (bots, Player) where the left fist closes on the shaft as the hero comes up: the guard's left
## grip, slid along the staff as it is held now (the right fist still holds it alone).
func held_grip_l() -> Vector3:
	var g := _wield.global_transform * _staff_xform(GUARD)
	var gl := _wield.global_transform * _target_l.position
	var sl := (gl - g.origin).dot(g.basis.y.normalized())
	return staff.global_position + staff.global_basis.y.normalized() * sl

## The same from inside the pose (Crumple, after the right hand is posed): the staff is placed in
## the right fist as it now stands first, so the left fist's target is on this tick's shaft.
var _unhold_draw := false
const UNHOLD_ROLL_RATE := 20.0  # 1/s
const UNHOLD_DRAW := 0.36    # s: the draw back to the guard after a knock-down (eased)  (11-08: 0.50 -> 0.36 once the held shaft came round the hat)
const UNHOLD_TAKE := 0.06    # s: the arm IK takes the hands from the knock-down pose (already on the shaft)
const REGRIP_REACH := 0.38   # m: shoulder to the fist's centre the arm can take without locking straight
const REGRIP_AIM := 0.30     # m: the shaft is tipped through a spot this far from the left shoulder
func held_grip_l_now(shoulder: Vector3) -> Vector3:
	if shoulder.is_finite():
		_held_shoulder_l = shoulder
	_place_held()
	var at := held_grip_l()
	if shoulder == Vector3.ZERO or not shoulder.is_finite():
		return at
	# out of the arm's reach (the staff not yet at its guard line): slide along the shaft toward
	# the shoulder until it is within reach, so the hand closes on the shaft, not on the air beside it
	var o := staff.global_position
	var ax := staff.global_basis.y.normalized()
	var near := o + ax * ax.dot(shoulder - o)
	var d_near := shoulder.distance_to(near)
	if shoulder.distance_to(at) <= REGRIP_REACH or d_near >= REGRIP_REACH:
		return at if d_near < REGRIP_REACH else near
	var half := sqrt(REGRIP_REACH * REGRIP_REACH - d_near * d_near)
	var sl := ax.dot(at - near)
	return near + ax * clampf(sl, -half, half)

## (11-08) The draw back to the guard after a knock-down eased the staff from the held line to
## the guard on the shortest turn, and that turn swept the shaft 0.18 m through the hat (the
## held shaft waits outside the brim; the guard lies on its far side). Tipped about the right
## fist each tick by the least angle that clears the hat, the draw brings the shaft round the
## brim instead. The fists ride the staff (the draw's grip shift), so they stay on it.
var draw_tip_max := 0.0   # (bots) the largest tip the draw needed (rad)
func _draw_clear_hat() -> void:
	var gt := staff.global_transform
	var ax := gt.basis.y.normalized()
	var fist := fist_center("Right")
	var pivot := gt.origin + ax * ax.dot(fist - gt.origin)
	var sl := (pivot - gt.origin).dot(ax)
	var q := gt.basis.get_rotation_quaternion()
	var q2 := _clear_head(q, pivot, sl, false)
	var tip := (q * Vector3.UP).angle_to(q2 * Vector3.UP)
	if tip < 1e-4:
		return
	draw_tip_max = maxf(draw_tip_max, tip)
	var ax2 := q2 * Vector3.UP
	staff.global_transform = Transform3D(Basis(q2).scaled(gt.basis.get_scale()), pivot - ax2 * sl)

## (11-09 11:00) the plunge snatch's bow: turn the staff about the right fist by PL_BOW sin(pi f)
## about the body's forward axis, so the path off the back swings out beside the head.
func _snatch_bow(f: float) -> void:
	var a := PL_BOW * sin(PI * f)
	if absf(a) < 1e-4:
		return
	var gt := staff.global_transform
	var ax := gt.basis.y.normalized()
	var fist := fist_center("Right")
	var pivot := gt.origin + ax * ax.dot(fist - gt.origin)
	var fwd: Vector3 = player.body.global_basis.z.normalized()
	if PL_BOW_YAW != 0.0:
		fwd = fwd.rotated(Vector3.UP, PL_BOW_YAW)
	var r := Basis(fwd, a)
	staff.global_transform = Transform3D(r * gt.basis, pivot + r * (gt.origin - pivot))

## Up again: the staff comes back from the right fist into both hands at guard, eased like a
## draw from wherever the fist holds it.
func unhold() -> void:
	if state != HELD:
		return
	if OS.has_environment("SPIN_DBG"):
		var gw := _wield.global_transform * _staff_xform(GUARD)
		print("UNHOLD axis vs guard %.1f deg (fist y over ground %.2f)" % [rad_to_deg(staff.global_basis.y.normalized().angle_to(gw.basis.y.normalized())), fist_center("Right").y - held_ground])
	staff.reparent(_wield, true)
	_from_xform = staff.transform
	_unhold_draw = not OS.has_environment("KNOCK_NOREGRIP")
	state = DRAWING
	t = 0.0

## Back on the hero's back after a rest.
func restore() -> void:
	_air_draw_t = -1.0
	staff.reparent(_back_slot, false)
	staff.transform = _back_xform
	_set_influence(0.0)
	_twist.twist = 0.0
	state = SHEATHED
	step = -1
	queued = false
	_heavy_queued = false
	hitstop = 0.0
	_recover = 0.0

func _begin_draw() -> void:
	staff.reparent(_wield, true)
	_from_xform = staff.transform
	state = DRAWING
	t = 0.0

func _start(i: int) -> void:
	if player.stamina <= 0.0:
		# winded: the string breaks off, back to guard
		state = READY
		step = -1
		queued = false
		idle_t = 0.0
		return
	player.stamina = maxf(player.stamina - float(COST[i]), 0.0)
	_atk = STRING[i]
	if i == 0 and _recover > 0.0 and _recover_keys.size() > 1:
		# a fresh string pressed mid-ease starts from where the arms have got to, not a snap to GUARD
		_atk = string_open_from(_recover_keys, 1.0 - _recover / RECOVER_TIME)
	_recover = 0.0
	_power = POWER[i]
	_hit_this_swing.clear()
	_prev_u = -1.0
	step = i
	t = 0.0
	_spun = 0.0
	queued = false
	idle_t = 0.0
	state = ATTACKING
	swings += 1
	swing_started.emit(i)

## Light in the air: the overhead arc brought down from the top of the jump.
func _start_air() -> void:
	if player.stamina <= 0.0:
		return
	player.stamina = maxf(player.stamina - AIR_COST, 0.0)
	player.note_air_attack()
	_snatch_draw()
	_atk = _air_old() if JUMPATK_NOCOCK else AIR_LIGHT
	if player.JUMPATK_NOTILT and not JUMPATK_NOCOCK:
		# (11-08 10:00) the 09:00 cock (26 deg back), drawn with the head upright
		_atk = AIR_LIGHT.duplicate(true)
		_atk["keys"][3] = [0.30, -10.0, 137.0, Vector3(-0.03, 2.10, 0.25), -14.0]
	if OS.has_environment("JUMPATK_HIGHKEY"):
		# (11-08 10:00) the cocked key with the hands 6 cm higher (the left fist out of reach of the shaft)
		_atk = AIR_LIGHT.duplicate(true)
		_atk["keys"][3] = [0.30, -10.0, 140.0, Vector3(-0.06, 2.18, 0.17), -14.0]
	if OS.has_environment("JA_KEY"):
		# tuning: JA_KEY="yaw,pitch,x,y,z" replaces the cocked key
		var f := OS.get_environment("JA_KEY").split_floats(",")
		_atk = AIR_LIGHT.duplicate(true)
		_atk["keys"][3] = [0.30, f[0], f[1], Vector3(f[2], f[3], f[4]), -14.0]
	_recover = 0.0
	air_hold_t = 0.0
	_power = AIR_POWER
	_hit_this_swing.clear()
	_prev_u = -1.0
	step = -1
	t = 0.0
	_spun = 0.0
	queued = false
	_heavy_queued = false
	idle_t = 0.0
	state = ATTACKING
	swings += 1
	air_attacks += 1
	swing_started.emit(-2)

## Heavy in the air: from any pose (a slung staff is drawn straight into the hands), the staff
## goes up overhead for the hang, then the hero drops on the spot below.
func _start_plunge() -> void:
	if player.stamina <= 0.0:
		return
	player.stamina = maxf(player.stamina - PLUNGE_COST, 0.0)
	if _snatch_draw():
		_raise_from = GUARD
		if not PLUNGE_SLOWSNATCH:
			_air_draw_dur = PLUNGE_DRAW_TIME
	elif state == CHARGING:
		_raise_from = _charge_pose()
	elif state == ATTACKING:
		_raise_from = _pose_at(_atk["keys"], clampf(t / float(_atk["dur"]), 0.0, 1.0))
	elif _recover > 0.0 and _recover_keys.size() > 1:
		_raise_from = _pose_at(_recover_keys, 1.0 - _recover / RECOVER_TIME)
		_raise_from[0] = wrapf(_raise_from[0], -180.0, 180.0)
	else:
		_raise_from = GUARD
	_recover = 0.0
	state = PLUNGING
	plunge_t = 0.0
	step = -1
	t = 0.0
	queued = false
	_heavy_queued = false
	hit_active = false
	idle_t = 0.0
	swings += 1
	swing_started.emit(-3)

## In the air there is no time for a separate draw: a slung staff is pulled off the back and
## blended into the hands over DRAW_TIME while the move itself runs. True if it was slung.
func _snatch_draw() -> bool:
	_air_draw_t = -1.0
	if state != SHEATHED and state != SHEATHING and state != DRAWING:
		return false
	if staff.get_parent() != _wield:
		staff.reparent(_wield, true)
	_from_xform = staff.transform
	_air_draw_t = 0.0
	_air_draw_dur = AIR_DRAW_TIME
	_set_influence(0.0)
	return true

func _plunge_pose() -> Array:
	var hang: Array = _plunge_hang_key()
	var up := smoothstep(0.0, 0.08, plunge_t)
	var pose := _pose_at([[0.0] + _raise_from, [1.0] + hang], up)
	var down := smoothstep(0.11, 0.21, plunge_t)
	if down > 0.0:
		if PLUNGE_LOWHANG:
			pose = _pose_at([[0.0] + hang, [1.0] + PLUNGE_DOWN], down)
		else:
			# (11-09 09:00) over the top through a mid key out in front of the brim: straight from
			# the hang to PLUNGE_DOWN the shaft swept through the hat (0.25 m deep)
			var mid: Array = PLUNGE_MID_KEY
			if _pl_mid_env.size() == 5:
				mid = [_pl_mid_env[0], _pl_mid_env[1], Vector3(_pl_mid_env[2], _pl_mid_env[3], _pl_mid_env[4]), PLUNGE_MID_KEY[3]]
			pose = _pose_at([[0.0] + hang, [PLUNGE_MID_AT] + mid, [1.0] + PLUNGE_DOWN], down)
	return pose

## The staff at the top of the plunge's hang. (11-09 09:00) it was the ground heavy's RAISED
## (fists at the chin, 0.33-0.52 m under the hat's crown): from the side the hang read as a
## shouldered staff. Now the arms go up over the hat, the shaft cocked back behind the head.
## PLUNGE_LOWHANG=1 = the old; PL_KEY="yaw,pitch,x,y,z" for tuning.
func _plunge_hang_key() -> Array:
	if PLUNGE_LOWHANG:
		return RAISED
	if _pl_key_env.size() == 5:
		return [_pl_key_env[0], _pl_key_env[1], Vector3(_pl_key_env[2], _pl_key_env[3], _pl_key_env[4]), PLUNGE_HANG_KEY[3]]
	if PLUNGE_HANGFWD:
		return PLUNGE_HANG_KEY_FWD
	return PLUNGE_HANG_KEY

var last_plunge_crack: GroundCrack   # the turf the last plunge split (bots read this)
var last_plunge_fx := ""             # the ImpactFX kind the last plunge threw (bots read this)

## The burst at the ferrule matches what it went into: grey stone chips and stone dust only on
## the door stones, rut stones or the sentinel's plinth; on the meadow dark moist soil and a low
## shaded haze. The pale "stone" grey (0.55) blew out to a white hot spot under the noon sun in
## the front-lens frames of the plunge (11-09). PLUNGE_STONEFX=1 = old (always stone).
static var PLUNGE_STONEFX := OS.get_environment("PLUNGE_STONEFX") == "1"
func plunge_fx_kind(at: Vector3) -> String:
	if PLUNGE_STONEFX:
		return "stone"
	if DoorStones.under(at.x, at.z, 0.05) or RutStones.under(at.x, at.z, 0.05) \
			or SentinelPlinth.under(at.x, at.z, 0.05):
		return "stone"
	return "turf"

## Where the ferrule went in, the turf splits in a crack star sized to the burst, the sward is
## laid flat outward and a low ring of dust runs out to the burst's edge: the same marks the
## Stone Sentinel's glaive leaves, without its shock (the burst already did the striking).
func _plunge_marks(at: Vector3, radius: float) -> void:
	var c := GroundCrack.new()
	c.harmless = true
	c.ring_r = radius
	c.size_k = clampf(radius / GroundCrack.RING_R * 1.15, 0.55, 1.1)
	player.get_parent().add_child(c)
	c.global_position = at - Vector3.UP * 0.05
	c.rotation.y = player.body.global_rotation.y
	last_plunge_crack = c

## The plunge meets the ground (the player calls this on touchdown): every foe inside the
## burst is struck outward, the turf bursts, the camera takes it, then the hero rises.
func plunge_land(drop: float) -> void:
	if state != PLUNGING:
		return
	var power := plunge_power(drop)
	var radius := plunge_radius(drop)
	var at := player.global_position + Vector3.UP * 0.05
	var front := at + player.body.global_basis.z * 0.55
	plunges += 1
	last_plunge_hits = 0
	_power = power
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if not target.has_method("hurt_capsule") or not target.has_method("take_hit"):
			continue
		var cap: Array = target.hurt_capsule()
		var a: Vector3 = cap[0]
		var b: Vector3 = cap[1]
		var lo := a if a.y < b.y else b
		if lo.y > at.y + 2.5 or maxf(a.y, b.y) < at.y - 1.0:
			continue
		var out := Vector3(lo.x - at.x, 0.0, lo.z - at.z)
		if out.length() > radius + float(cap[2]):
			continue
		var dir := out.normalized() if out.length() > 0.05 else player.body.global_basis.z
		var point := Vector3(lo.x, at.y + 0.6, lo.z) - dir * float(cap[2])
		var hi := a if a.y >= b.y else b
		var crown: bool = target.is_in_group("boss") and out.length() < float(cap[2]) + 0.9 \
			and at.y >= lo.y + (hi.y + float(cap[2]) - lo.y) * CROWN_TOP
		last_plunge_hits += 1
		if crown:
			# struck down through the helm: the blow lands at the crown, not at the hero's feet
			point = Vector3(at.x, at.y - 0.25, at.z)
			dir = Vector3.DOWN.lerp(player.body.global_basis.z, 0.35).normalized()
			_power = power * CROWN_K
			_land_hit(target, point, dir)
			_power = power
			_crown(target, point, out)
		else:
			_land_hit(target, point, dir)
	hitstop = HITSTOP * power * (1.0 if last_plunge_hits > 0 else 0.5)
	if last_crown_frame == Engine.get_physics_frames():
		hitstop *= 1.5
	last_plunge_fx = plunge_fx_kind(front)
	ImpactFX.spawn(player.get_parent(), front, Vector3.DOWN, last_plunge_fx, 1.0 + 0.5 * power)
	_plunge_marks(at, radius)
	player.add_shake(0.25 + 0.15 * power)
	slammed.emit(front, 0.8 + 0.4 * power)
	plunged.emit(at, power, radius)
	# the impact pose now, whatever the swing had reached: the hit-stop freezes on it
	staff.transform = _place_hands(PLUNGE_DOWN)
	_twist.twist = deg_to_rad(PLUNGE_DOWN[3])
	_atk = PLUNGE_RISE
	_hit_this_swing.clear()
	_prev_u = -1.0
	_slammed = true
	t = 0.0
	state = ATTACKING

var last_crown_frame := -1

## The crown strike's extra: the boss reels (its own `crowned`), metal rings off the helm, a
## second heavier shake, and the hero is handed a leap off the shoulders, away from the head.
func _crown(target: Node, point: Vector3, out: Vector3) -> void:
	crown_strikes += 1
	last_crown = target
	last_crown_frame = Engine.get_physics_frames()
	if target.has_method("crowned"):
		target.crowned(point)
	ImpactFX.spawn(player.get_parent(), point, Vector3.UP, "metal", 2.2)
	player.add_shake(0.35)
	var away := -out if out.length() > 0.05 else -player.body.global_basis.z
	player.vault_off(Vector3(away.x, 0.0, away.z).normalized(), true)

## The vault off a crown strike cuts the plunge's rise short: the hero leaves in the air pose.
func end_plunge_rise() -> void:
	if state == ATTACKING and _atk == PLUNGE_RISE:
		_from_pose = _pose_at(_atk["keys"], 0.62)
		_begin_recover()
		state = READY
		idle_t = 0.0
		step = -1

## STRING[0] opened from part-way (`u`) through a recovery `path` (from best_recover_path):
## the arms run on along the rest of that path up to its chamber key -- squeezed into the
## opener's first 0.10 -- then into the wind-up as usual. A straight cut from an early ease
## pose to the chamber swung the shaft through the chest (bot dodge 2c: clearance 0.05).
static func string_open_from(path: Array, u: float) -> Dictionary:
	const CH_T := 0.62     # the chamber key's time in best_recover_path
	var open_t: float = STRING[0]["keys"][1][0]
	var ch_yaw := float(CHAMBER[0])
	for k in path:
		if absf(float(k[0]) - CH_T) < 1e-4:
			ch_yaw = float(k[1])
	var off := ch_yaw - float(CHAMBER[0])   # the +-360 the path wrapped through
	var cur: Array = _pose_at_static(path, u)
	if cur.size() < 5:
		cur.append(0.0)
	cur[0] = float(cur[0]) - off
	var keys: Array = [[0.0] + cur]
	if u < CH_T:
		for k in path:
			var kt := float(k[0])
			if kt > u + 1e-4 and kt < CH_T - 1e-4:
				var nk: Array = (k as Array).duplicate()
				nk[0] = open_t * (kt - u) / (CH_T - u)
				nk[1] = float(nk[1]) - off
				keys.append(nk)
	var src: Array = STRING[0]["keys"]
	for i in range(1, src.size()):
		keys.append(src[i])
	var atk: Dictionary = STRING[0].duplicate()
	atk["keys"] = keys
	return atk

## Body-space pose of the current attack at normalised time u.
func _pose_at(keys: Array, u: float) -> Array:
	return _pose_at_static(keys, u)

static func dir_of(yaw_deg: float, pitch_deg: float) -> Vector3:
	var y := deg_to_rad(yaw_deg)
	var p := deg_to_rad(pitch_deg)
	return Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p))

func physics_step(delta: float) -> void:
	if state == HELD:
		_held_dt += delta
	if grip_roll != null:
		var hr: HandRest = player.get("hand_rest")
		var held := hr != null and hr.weight > 0.5 and hr.hold > 0.5 and _blend > 0.9 \
			and (state in [READY, ATTACKING, CHARGING, PLUNGING] or (state == DRAWING and _unhold_draw))
		if not held and air_snatch_late() and hr != null and hr.weight > 0.5:
			held = true                        # the fists close round the shaft as it arrives
		# (11-08) back from a knock-down the fists are already round the shaft: the roll comes in
		# quickly with the draw instead of easing in after it (the fists rode 0.1 m off for 3 ticks)
		var rate := UNHOLD_ROLL_RATE if _unhold_draw else 6.0
		if held and _air_snatching_move() and not JUMPATK_SLOWSNATCH:
			rate = AIR_ROLL_RATE               # snatched in the air: the fists close round it at once
		grip_roll.weight = move_toward(grip_roll.weight, 1.0 if held else 0.0, delta * rate)
	_spin_applied = spin_delta
	spin_delta = 0.0
	if hitstop > 0.0:
		# frozen in the contact: pose, IK and twist hold; only the trail keeps fading
		hitstop -= delta
		_age_trail(delta)
		return
	hit_active = false
	var pose: Array = GUARD
	match state:
		SHEATHED:
			_age_trail(delta)
			return
		HELD:
			_age_trail(delta)
			return
		DROPPED:
			# falls under gravity to rest on the ground, tipping flat as it goes
			var ground := player.global_position.y + 0.03
			_drop_v += 9.8 * delta
			staff.global_position.y = maxf(staff.global_position.y - _drop_v * delta, ground)
			staff.global_basis = staff.global_basis.slerp(_drop_rest, minf(delta * 4.0, 1.0))
			_age_trail(delta)
			return
		DRAWING:
			t += delta
			var f := clampf(t / DRAW_TIME, 0.0, 1.0)
			var g := _place_hands(GUARD)
			var fe := f
			if _unhold_draw and not OS.has_environment("KNOCK_FASTDRAW"):
				# (05:00 11-08) back from a knock-down the shaft may have ~100 deg to turn from the reach
				# toward the left hand to the guard: drawn linearly in DRAW_TIME that was a constant
				# 35 deg per 15 Hz tick, starting and stopping dead. Eased in and out over UNHOLD_DRAW
				# (peak ~26 deg per tick) it carries on from the held turn and settles into the guard.
				f = clampf(t / UNHOLD_DRAW, 0.0, 1.0)
				fe = smoothstep(0.0, 1.0, f)
			staff.transform = _from_xform.interpolate_with(g, fe)
			if _unhold_draw and not OS.has_environment("KNOCK_DRAWRAW"):
				_draw_clear_hat()
			if _unhold_draw:
				# back from a knock-down: both fists are already on the shaft, so the grips ride the
				# staff as it eases to the guard (aiming them at the guard's grips while the staff
				# was still where the fist held it put both hands 0.15 m off it for a few ticks)
				var shift := staff.transform * g.affine_inverse()
				_target_r.position = shift * _target_r.position
				_target_l.position = shift * _target_l.position
				_set_influence(minf(t / UNHOLD_TAKE, 1.0))
			else:
				_set_influence(f)
			if f >= 1.0:
				_unhold_draw = false
				state = READY
				idle_t = 0.0
				if _heavy_queued:
					_start_charge()
				elif queued and player.air_attack_ok():
					_start_air()
				elif queued:
					_start(0)
			_age_trail(delta)
			return
		READY:
			if _recover > 0.0:
				_recover = maxf(_recover - delta, 0.0)
				pose = _pose_at(_recover_keys, 1.0 - _recover / RECOVER_TIME)
				if _recover <= 0.0:
					pose = GUARD   # drop any +-360 yaw the path wrapped through
			idle_t += delta
			if idle_t > SHEATHE_AFTER:
				staff.reparent(_back_slot, true)
				_from_xform = staff.transform
				state = SHEATHING
				t = 0.0
		CHARGING:
			charge_t += delta
			idle_t = 0.0
			pose = _charge_pose()
			for n in range(CHARGE_TIERS.size() - 1, 0, -1):
				if charge_t >= float(CHARGE_TIERS[n]):
					_set_tier(n)
					break
			if (not heavy_held and charge_t >= MIN_CHARGE) or charge_t >= CHARGE_MAX:
				_release()
				pose = _pose_at(_atk["keys"], 0.0)
		PLUNGING:
			plunge_t += delta
			idle_t = 0.0
			pose = _plunge_pose()
			hit_active = false
		ATTACKING:
			var atk: Dictionary = _atk
			var dur: float = atk["dur"]
			t += delta
			var u := clampf(t / dur, 0.0, 1.0)
			pose = _pose_at(atk["keys"], u)
			var hw: Array = atk["hit"]
			hit_active = u >= float(hw[0]) and u <= float(hw[1])
			var spin: float = atk["spin"]
			if spin != 0.0:
				var target := spin * smoothstep(0.15, 0.8, u)
				spin_delta = target - _spun
				_spun = target
			if atk == HEAVY and not _slammed and u >= SLAM_AT:
				_slammed = true
				_ground_slam()
			if u >= 1.0 and atk.get("air", false) and not JUMPATK_NOAIRHOLD and air_hold_t < AIR_HOLD_MAX \
					and player._air_t >= 0.0 and not player.gliding and not player.climbing:
				# (11-09 04:00) the blow is done but the feet are still off the turf: hold the struck
				# pose (staff driven down, body folded) until touch-down, so the landing always comes
				# down out of the strike and sinks through the knees (it used to drop back to guard
				# in the air and land like a plain hop when pressed early in the jump)
				t = dur
				air_hold_t += delta
				air_holds += 1 if air_hold_t <= delta + 0.0001 else 0
			elif u >= 1.0:
				if atk.get("air", false) and (queued or _heavy_queued) and player.strike_landing_hold():
					pass   # (11-09) still sunk in the jump attack's landing: the next swing waits for the rise
				elif _heavy_queued:
					_start_charge(pose)
				elif queued:
					_start((step + 1) % STRING.size())
				else:
					# the string ends: settle from the follow-through down into the low guard
					_from_pose = _pose_at(_atk["keys"], 1.0)
					_begin_recover()
					state = READY
					idle_t = 0.0
					step = -1
		SHEATHING:
			t += delta
			var f := clampf(t / DRAW_TIME, 0.0, 1.0)
			staff.transform = _from_xform.interpolate_with(_back_xform, f)
			_set_influence(1.0 - f)
			_place_hands(GUARD)
			if f >= 1.0:
				staff.transform = _back_xform
				_set_influence(0.0)
				state = SHEATHED
			_age_trail(delta)
			return
	var want_dip := LOW_DIP if is_attacking() and _low_target_ahead() else 0.0
	if is_air_attack() and t / float(_atk["dur"]) > 0.4:
		want_dip = AIR_DIP                     # from above, the whole arc tips down onto the foe
	dip = lerpf(dip, want_dip, 1.0 - exp(-12.0 * delta))
	if state == PLUNGING and not PLUNGE_LOWHANG:
		# (11-09 09:00) the dive folds the chest and hat forward over the staff while it swings
		# over the top; the swing tips forward with the fold (as the jump attack's arc does) so
		# the shaft passes in front of the brim, and is back square by the drive (PLUNGE_DOWN)
		dip = PL_DIP * float(player.get("pl_dive")) * (1.0 - smoothstep(PL_DIP_OUT[0], PL_DIP_OUT[1], plunge_t))
	_ride_chest(delta)
	staff.transform = _place_hands(pose)
	if _air_draw_t >= 0.0:
		_air_draw_t += delta
		var f := clampf(_air_draw_t / (DRAW_TIME if JUMPATK_SLOWSNATCH else _air_draw_dur), 0.0, 1.0)
		if not JUMPATK_SLOWSNATCH:
			f = smoothstep(0.0, 1.0, f)
		staff.transform = _from_xform.interpolate_with(staff.transform, f)
		if state == PLUNGING and f < 1.0 and not PLUNGE_SNATCHRAW:
			# (11-09 10:00) the straight transform blend from the back slot to the overhead hang
			# carried the shaft THROUGH the hat (0.25 m deep at plunge 0.05 s): tip it about the
			# right fist so it passes beside the brim, as the knock-down redraw does
			if not PLUNGE_SNATCHTIP:
				_snatch_bow(f)
			_draw_clear_hat()
		_set_influence(f)
		if f >= 1.0:
			_air_draw_t = -1.0
	_twist.twist = deg_to_rad(pose[3])
	if hit_active:
		_detect_hits(t / float(_atk["dur"]))
	else:
		_prev_u = -1.0
	_update_trail(delta)

# --- contact: the whole shaft is swept between ticks against each hittable's capsule ---

func _detect_hits(u: float) -> void:
	var atk: Dictionary = _atk
	var u0 := _prev_u if _prev_u >= 0.0 else u
	_prev_u = u
	# re-evaluate the authored arc at ~4 ms sub-steps: at low frame rates one tick can sweep
	# the staff through 90°+, and a straight line between the two poses would cut inside it.
	# A spinning attack also turns the body (by last frame's spin_delta, applied before this
	# step), so the sub-steps turn it back too, or the shaft tunnels past a target.
	var n := clampi(int(ceil((u - u0) * float(atk["dur"]) / 0.004)), 1, 24)
	if _spin_applied != 0.0:
		n = maxi(n, clampi(int(ceil(absf(_spin_applied) / 0.05)), 1, 24))
	var segs: Array = []
	var bx := player.body.global_transform
	for k in n + 1:
		var f := float(k) / n
		var bk := Transform3D(bx.basis.rotated(Vector3.UP, -_spin_applied * (1.0 - f)), bx.origin)
		var xf := bk * _staff_xform(_pose_at(atk["keys"], lerpf(u0, u, f)))
		segs.append([xf * Vector3(0, -Staff.LENGTH * 0.5, 0), xf * Vector3(0, Staff.LENGTH * 0.5, 0)])
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if target in _hit_this_swing or not target.has_method("hurt_capsule"):
			continue
		var cap: Array = target.hurt_capsule()
		if (cap[0] as Vector3).distance_to(player.global_position) > 4.0 + float(cap[2]) * 2.0:
			continue
		for k in segs.size():
			var a: Vector3 = segs[k][0]
			var b: Vector3 = segs[k][1]
			var pts := Geometry3D.get_closest_points_between_segments(a, b, cap[0], cap[1])
			if pts[0].distance_to(pts[1]) <= float(cap[2]) + 0.03:
				var prev_tip: Vector3 = segs[maxi(k - 1, 0)][1]
				var swing := b - prev_tip
				if swing.length() < 1e-4:
					swing = (b - a).cross(Vector3.UP)
				var out := pts[0] - pts[1]
				out.y = 0.0
				var point := pts[1] + (out.normalized() * float(cap[2]) if out.length() > 1e-4 else Vector3.ZERO)
				_land_hit(target, point, swing.normalized())
				break

## Nearest hittable's centre within `dist` and `half_angle` (rad) of the facing, or INF.
func magnet_target(dist: float, half_angle: float) -> Vector3:
	var face := player.body.global_basis.z
	var best := Vector3.INF
	var best_d := dist
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if not target.has_method("hurt_capsule"):
			continue
		var c: Vector3 = target.hurt_capsule()[0]
		var to := c - player.global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and d > 0.05 and face.angle_to(to) < half_angle:
			best = c
			best_d = d
	return best

## True when a hittable stands within lunge-stopping range ahead of the hero.
func target_in_reach(dist: float) -> bool:
	var bx := player.body.global_transform
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if not target.has_method("hurt_capsule"):
			continue
		var c: Vector3 = target.hurt_capsule()[0]
		var l := bx.affine_inverse() * c
		if l.z > 0.0 and Vector2(l.x, l.z).length() < dist + float(target.hurt_capsule()[2]):
			return true
	return false

func _land_hit(target: Node, point: Vector3, swing: Vector3) -> void:
	var power: float = _power
	_hit_this_swing.append(target)
	hits += 1
	last_power = power
	hitstop = HITSTOP * power
	target.take_hit(point, swing, power, hitstop)
	var kind: String = target.get("impact_kind") if target.get("impact_kind") != null else "wood"
	ImpactFX.spawn(player.get_parent(), point, swing, kind, power)
	player.add_shake(0.32 * power)
	hit_landed.emit(target, point, power)

## Staff overhead, easing up from wherever the arms were; a tremble grows with the charge.
func _charge_pose() -> Array:
	var f := clampf(charge_t / RAISE_TIME, 0.0, 1.0)
	var k: Array = [[0.0] + _raise_from, [1.0] + RAISED]
	var pose := _pose_at(k, f)
	var shake := 0.6 + 1.2 * float(tier)
	pose[0] += sin(charge_t * 47.0) * shake * f
	pose[1] += sin(charge_t * 39.0 + 1.3) * shake * 0.6 * f + 4.0 * float(tier) * f
	return pose

## The smash meets the ground ahead: a burst of soil and grit, and the camera feels it.
func _ground_slam() -> void:
	var tip := tip_position()
	var at := Vector3(tip.x, player.global_position.y + 0.05, tip.z)
	ImpactFX.spawn(player.get_parent(), at, Vector3.DOWN, "stone", 0.8 + 0.35 * float(tier))
	player.add_shake(0.18 + 0.1 * float(tier))
	slammed.emit(at, 0.8 + 0.35 * float(tier))

## Puts both grips on the authored staff line, pulls each into its shoulder's reach (the
## shoulders turn with the spine twist), then lays the staff through the two grips.
## Returns the staff's body-space transform.
## (16:30 11-08) The guard staff rides with the shoulders. GUARD is authored in body (Wield)
## space against a standing hero; the run clip leans the trunk ~0.2 m forward and swings the
## right shoulder onto the staff, so its right grip ended 4-10 cm from the shoulder joint (an
## arm can't fold that tight; the fist slid 0.12 m off the shaft). While the staff is held at
## guard (READY), the Wield frame is carried by the shoulders' offset from where they stand
## at the guard (each shoulder measured from the last skeleton update, the nearer-to-staff
## one weighted in), eased; in the attacks, charge and plunge it eases back to zero so their
## authored arcs and hit sweeps are unchanged. `GUARD_NORIDE=1` = old.
func _ride_chest(delta: float) -> void:
	var want := Vector3.ZERO
	if skel != null:
		var inv := player.body.global_transform.affine_inverse() * skel.global_transform
		for i in 2:
			var b := skel.find_bone(["mixamorig_RightArm", "mixamorig_LeftArm"][i])
			if b >= 0:
				shoulder_body[i] = inv * skel.get_bone_global_pose(b).origin
	var want_sq := 0.0
	var cr = player.get("crumple")
	if state == READY and not GUARD_NORIDE and skel != null:
		if cr == null or not cr.active or SQUARE_INBEND:
			want_sq = TWIST_GAIN
		var mid: Vector3 = (shoulder_body[0] + shoulder_body[1]) * 0.5
		var off: Vector3 = mid - SHOULDER_MID_REF
		# forward/back and down only (never lift the guard above where it stands; sideways the
		# shoulders swap each stride and the staff would wag)
		want = Vector3(0.0, minf(off.y, 0.0), maxf(off.z, 0.0)) * RIDE_GAIN
		want = want.limit_length(RIDE_MAX)
	_twist.square = move_toward(_twist.square, want_sq, delta * TWIST_RATE)
	_twist.clav_hold = _twist.square * CLAV_HOLD
	_twist.square_ref = YAW_REF
	_twist.square_max = TWIST_MAX
	chest_yaw = _twist.last_yaw
	counter_twist = _twist.last_counter
	ride = ride.lerp(want, 1.0 - exp(-RIDE_RATE * delta))
	# (11-09) down in a jump attack's landing the staff sinks with the body the same tick (it
	# stayed at standing height and the arms could not reach it: grip error 0.09 m)
	# (11-09 04:00) and keeps sinking with it once the strike has ended and the arms ease back to
	# guard (READY / a swing pressed then): it used to pop back up by the whole dip (~0.3 m) in
	# one tick the moment the attack ended mid-landing. JUMPATK_NOAIRHOLD=1 = the old.
	strike_sink = 0.0
	var sink_on: bool = state == ATTACKING and _atk.get("air", false)
	if not JUMPATK_NOAIRHOLD:
		sink_on = state in [ATTACKING, READY, CHARGING]
	if sink_on and player.strike_landing_hold():
		strike_sink = player._pose_dip * STRIKE_SINK_SHARE
	_wield.position = ride + Vector3(0.0, -strike_sink, 0.0)

func _place_hands(pose: Array) -> Transform3D:
	var r := _solve(pose)
	_target_r.position = r[1] + _fist_off[0]
	_target_l.position = r[2] + _fist_off[1]
	return r[0]

## The closed fist's centre (world), for bots and the shot lens.
func fist_center(side: String) -> Vector3:
	return HandRest.fist_center(skel, side)

## After every modifier: each fist's centre to the staff's axis, and the wrist target moved by a
## share of that gap for the next tick (the IK keeps the hand's turn, so the gap closes in a
## few ticks and follows the poses as the hands roll round the shaft). Only with the staff in
## both hands (not on the back, not in the draw's carry, not dropped); frozen in a hit-stop,
## where the targets are not re-placed.
func _fit_fists() -> void:
	if staff == null or _wield == null or hitstop > 0.0:
		return
	var hr: HandRest = player.get("hand_rest")
	var on := fist_fit_on and hr != null and hr.weight > 0.5 and hr.hold > 0.5 and _blend > 0.9 \
		and state in [READY, ATTACKING, CHARGING, PLUNGING]
	# (11-06) GripRoll's feed-forward puts the fists on the axis the same tick (as far as the
	# wrist allows); this one-tick-late fit then only fought it (it ran up to FIST_MAX while
	# the feed pulled back), so it runs only without the feed (env HERO_GRIPLAG)
	if grip_roll != null and grip_roll.feed_on:
		on = false
	var o := staff.global_position
	var ax := staff.global_basis.y.normalized()
	var inv := _wield.global_basis.inverse()
	for i in 2:
		var f := fist_center(["Right", "Left"][i])
		var p := o + ax * ax.dot(f - o)
		fist_gap[i] = f.distance_to(p)
		if on:
			_fist_off[i] = (_fist_off[i] - inv * (f - p) * fist_gain).limit_length(FIST_MAX)
		else:
			_fist_off[i] = _fist_off[i].lerp(Vector3.ZERO, 0.1)

func _staff_xform(pose: Array) -> Transform3D:
	return _solve(pose)[0]

## [staff body-space transform, right grip, left grip] for a pose.
func _solve(pose: Array) -> Array:
	var d := dir_of(pose[0], pose[1])
	var p: Vector3 = pose[2]
	if dip > 0.001:
		# tip the whole swing forward and down about the chest so it meets a low foe
		var rb := Basis(Vector3.RIGHT, dip)
		var piv := Vector3(0, 1.3, 0)
		d = rb * d
		p = piv + rb * (p - piv)
	var tw := deg_to_rad(pose[3])
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	# optional 5th element slides both grips along the shaft (negative = toward the butt,
	# the long grip of an overhead strike; P stays the staff's centre)
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var hr := _clamp_reach(p + d * (HAND_R + slide), sr)
	var hl := _clamp_reach(p + d * (HAND_L + slide), sl)
	var axis := hl - hr
	if axis.length() < 0.12:
		axis = d * 0.12
	var d2 := axis.normalized()
	var b := Basis(Quaternion(Vector3.UP, d2)) if d2.y > -0.99 else Basis(Vector3.RIGHT, PI)
	return [Transform3D(b, hr - d2 * (HAND_R + slide)), hr, hl]

## Starts the ease from `_from_pose` back down to GUARD. A straight blend from a pose with the
## shaft out to the side swings the butt through the chest (a dodge out of string swing 2
## did), so it scores a few candidate paths -- turning the shaft either way round, with or
## without dipping/lifting the tip or pushing the hands out first -- by their worst torso
## clearance and takes the clearest (tools/pose_check.py's model; checked offline: worst
## clearance over every cancel point 0.63 torso radii, was 0.01).
func _begin_recover() -> void:
	_recover = RECOVER_TIME
	_recover_keys = best_recover_path(_from_pose)

static func best_recover_path(from: Array) -> Array:
	var f: Array = from.duplicate()
	if f.size() < 5:
		f.append(0.0)
	var best: Array = []
	var best_gap := -1.0
	for wrap in [0.0, -360.0, 360.0]:
		var ch: Array = CHAMBER.duplicate()
		ch[0] += wrap
		var gu: Array = GUARD.duplicate()
		gu[0] += wrap
		for via in ["", "fwd", -55.0, -30.0, 30.0, 55.0]:
			var keys: Array = [[0.0] + f]
			var fp: Vector3 = f[2]
			if via is String and via == "fwd":
				keys.append([0.3, f[0], f[1], Vector3(fp.x * 0.5, fp.y, maxf(fp.z, 0.55)), f[3], 0.0])
			elif not via is String:
				keys.append([0.3, lerpf(f[0], ch[0], 0.4), via, Vector3(fp.x * 0.5, 1.35, maxf(fp.z, 0.45)), f[3], 0.0])
			keys.append([0.62] + ch)
			keys.append([1.0] + gu)
			var g := path_clearance(keys)
			if g > best_gap + 0.01:   # ties keep the earlier (plainer) path
				best_gap = g
				best = keys
	return best

## Worst torso clearance (torso radii, 1.0 = touching) along a key path. 24 samples missed
## narrow dips where the shaft sweeps past the chest fast (a 0.05 graze between two samples).
const CLEAR_SAMPLES := 120
static func path_clearance(keys: Array) -> float:
	var worst := 9.0
	for j in range(1, CLEAR_SAMPLES + 1):
		var pz: Array = _pose_at_static(keys, j / float(CLEAR_SAMPLES))
		worst = minf(worst, torso_clearance(pz))
	return worst

static func _pose_at_static(keys: Array, u: float) -> Array:
	var k := 0
	while k < keys.size() - 2 and u > float(keys[k + 1][0]):
		k += 1
	var a: Array = keys[k]
	var b: Array = keys[k + 1]
	var f := clampf((u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var sa: float = a[5] if a.size() > 5 else 0.0
	var sb: float = b[5] if b.size() > 5 else 0.0
	return [lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), (a[3] as Vector3).lerp(b[3], f), lerpf(a[4], b[4], f), lerpf(sa, sb, f)]

## The staff's clearance from the chest/head for one pose, body space, no dip (same model
## as tools/pose_check.py: chest ellipse 0.17 x 0.12 m for y 0.9-1.5, head ellipsoid above).
static func torso_clearance(pose: Array) -> float:
	var d := dir_of(pose[0], pose[1])
	var p: Vector3 = pose[2]
	var tw := deg_to_rad(pose[3])
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var sr := Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z).rotated(Vector3.UP, tw)
	var hr := _clamp_reach(p + d * (HAND_R + slide), sr)
	var hl := _clamp_reach(p + d * (HAND_L + slide), sl)
	var ax := hl - hr
	var a := ax.normalized() if ax.length() > 1e-4 else d
	var c := hr - a * (HAND_R + slide)
	var e0 := c - a * 0.93
	var e1 := c + a * 0.93
	var best := 9.0
	for i in 41:
		var x := e0.lerp(e1, i / 40.0)
		if x.y >= 0.9 and x.y <= 1.5:
			best = minf(best, Vector2(x.x / 0.17, (x.z + 0.02) / 0.12).length())
		elif x.y > 1.5 and x.y <= 1.8:
			best = minf(best, Vector3(x.x / 0.11, (x.z - 0.01) / 0.12, (x.y - 1.66) / 0.14).length())
	return best

static func _clamp_reach(h: Vector3, shoulder: Vector3) -> Vector3:
	var v := h - shoulder
	return shoulder + v.limit_length(REACH)

## Grip error in metres (hand bone origin to its IK target), for bots.
func grip_error() -> float:
	return last_grip_error

func _measure_grip() -> float:
	var e := 0.0
	for side in [["Right", _target_r], ["Left", _target_l]]:
		var b := skel.find_bone("mixamorig_%sHand" % side[0])
		var hp := skel.global_transform * skel.get_bone_global_pose(b).origin
		e = maxf(e, hp.distance_to((side[1] as Node3D).global_position))
	return e

## A living low foe (one that sets `low_target`, e.g. a Briar Hound) close in front.
func _low_target_ahead() -> bool:
	var face := player.body.global_basis.z
	for target in player.get_tree().get_nodes_in_group("hittable"):
		if target.get("low_target") != true:
			continue
		var to: Vector3 = (target as Node3D).global_position - player.global_position
		to.y = 0.0
		if to.length() < 3.4 and face.angle_to(to) < 1.3:
			return true
	return false

func tip_position() -> Vector3:
	return staff.global_transform * Vector3(0, Staff.LENGTH * 0.5, 0)

# --- swing trail: a ribbon between the tip and the upper shaft, fading with age ---

func _update_trail(delta: float) -> void:
	if hit_active:
		var mid := staff.global_transform * Vector3(0, Staff.LENGTH * 0.12, 0)
		_trail_pts.push_front([0.0, tip_position(), mid])
	_age_trail(delta)

func _age_trail(delta: float) -> void:
	for p in _trail_pts:
		p[0] += delta
	while _trail_pts.size() > 0 and float(_trail_pts.back()[0]) > TRAIL_LIFE:
		_trail_pts.pop_back()
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _trail_pts:
		var a := 1.0 - float(p[0]) / TRAIL_LIFE
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_set_uv(Vector2(1.0 - a, 0.0))
		_trail_mesh.surface_add_vertex(p[1])
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_set_uv(Vector2(1.0 - a, 1.0))
		_trail_mesh.surface_add_vertex(p[2])
	_trail_mesh.surface_end()
