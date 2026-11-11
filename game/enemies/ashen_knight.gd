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
## GROWTH (owner rule 2026-11-03, BossGrowth): it stands ~2.5x the hero in phase 1 and every
## surge is a growth moment: invulnerable, the arena shaking, dust thrown up, the body heaving
## up to its next size over 2 s. Phase 3 ends ~2.1x the starting size (~5.3x the hero).
## Reach, hurt capsule, stride, the blast ring, the leap and its bite all scale with it; each
## size is a little slower to stride, hits harder and covers more ground.
## EMBER LEAP (its own move, phases 2 and 3): a hero who backs off out of glaive reach (to
## run the eruptions, or to heal) does not get to wait it out. The knight drops into a deep
## crouch with the ember flaring and the glint on the blade, locks onto where the hero stands,
## and springs: a long arc through the air with the glaive heaved overhead, coming down blade
## first so the edge bites the turf where the hero was. The landing throws down anyone in the
## blade's line or inside LEAP_R of the bite (unblockable: roll as it lands, not before) and a
## ring of fire flares up round the impact. Then it is bent double over the bitten glaive for
## a long recovery: the punish window for a hero who rolled through.

const KNIGHT_HP := 540.0
const KNIGHT_POISE := 62.0
const PHASE_AT := [0.66, 0.33]   # health fraction that starts phase 2, phase 3
const GUARD_BREAK := 1.5         # a hit this strong breaks the guard (the heavies; not the string)
const SURGE_T := 2.4             # s on its knee, burning and growing (brain time)
const SURGE_BLAST := 0.95        # s into the surge the ring of fire bursts
const SURGE_R := 4.2
const SURGE_DAMAGE := 20.0
const FLAME_EVERY := 4.2
const TEMPO := [1.0, 0.95, 0.9]   # bigger = heavier: longer wind-ups and recoveries  # (= PHASES[i].tempo; music.gd reads this)
## The phases as data (BossGrowth). scale: body size (1 = a soldier, the hero ~0.92).
const PHASES := [
	{"scale": 2.2, "tempo": 1.0, "damage": 1.0, "attacks": ["thrust", "sweep"],
		"mechanic": "ember guard: light strikes are turned aside while it stalks"},
	{"scale": 3.2, "tempo": 0.95, "damage": 1.35, "attacks": ["thrust", "sweep", "ember leap", "stomp"],
		"mechanic": "unblockable red glint; a hero hanging back gets the leap"},
	{"scale": 4.6, "tempo": 0.9, "damage": 1.7, "attacks": ["thrust", "sweep", "ember leap", "stomp", "burning ground", "eruptions"],
		"mechanic": "the turf under the hero smoulders and erupts every 4 s"},
]
const NAME := "The Ashen Knight"
const LEAP_MOVE := 2
const INTRO_MOVE := 3            # the reveal (BossIntro): it stands, turns, heaves and roars
const LEAP_MIN := 5.0            # hero farther than this (and nearer than LEAP_MAX) gets the leap
const LEAP_MAX := 11.0
const LEAP_COOL := 5.5           # brain-time s between leaps
const LEAP_SQUARE := 0.35        # s it squares up to a hero hanging back before it crouches
const LEAP_CROUCH_T := 0.8       # brain-time s coiling down (the tell)
const LEAP_LOCK := 0.8           # fraction of the crouch at which it fixes the landing
const LEAP_T := 0.62             # brain-time s in the air
const LEAP_H := 1.7              # m the arc rises at its top
const LEAP_RECOVER_T := 1.5
const LEAP_R := 2.0              # m round the bite that the landing throws down
const LEAP_DAMAGE := 28.0
const LEAP_BITE := 1.75          # m ahead of its feet where the blade comes down (the slam's)
# glaive poses borrowed from the Stone Sentinel's slam (same glaive, same build of body)
const CROUCHED := [-14.0, 62.0, Vector3(0.05, 1.9, -0.1), -10.0, 0.1, 0.62]
## leap heave: both hands up over the helm, the blade laid back behind the head
const LEAP_HEAVE_OLD := [-6.0, 148.0, Vector3(0.0, 2.3, -0.4), -6.0, 0.1, 0.66]
## (23:00 11-10) the leap's heave re-solved offline (python replica of `_place`): the old heave asked
## the left grip 0.74 m from its shoulder (reach 0.66, the shaft 9 deg off the pose), and the
## straight lerps up from CROUCHED and down to SLAMMED dragged the right fist through the helm
## (3-6 cm from the head) with the arm crushed shut (bone shoulder-wrist 0.042 m/size in flight,
## bot `foefold`). Now the glaive is heaved up in an arc out to the right and in front of the
## helm (LEAP_UP_ARC) to a heave both hands reach (the same shaft line), and brought down in an
## arc out in front (LEAP_DOWN_ARC): offline every grip >= 0.34 m from its shoulder, both fists
## >= 0.23 m clear of the helm. Env LEAPFOLD_OLD=1: the before.
const LEAP_HEAVE_NEW := [-6.0, 148.0, Vector3(0.049, 2.283, -0.362), 7.9, -0.094, 0.66]
const LEAP_UP_ARC := [9.9, 86.7, Vector3(0.235, 2.286, 0.05), -12.8, -0.012, 0.64]
const LEAP_DOWN_ARC_OLD := [-19.1, 119.4, Vector3(0.095, 2.388, 0.992), -7.4, -0.131, 0.65]
## (13:00 11-11) the heave re-solved against the knight's REAL great helm. LEAP_HEAVE_NEW laid the
## glaive back straight over the head, but the helm is tall (crown 2.00 in the Wield's space, the
## shoulders 1.59, the arms 0.52 of reach): the reach slide pulled the whole line down into it and
## the haft sank 0.17 m/size into the crown for the whole hang (bot `foefold` `haft sunk`). Solved
## offline against the helm and both pauldrons' meshes and the real shoulders as dumped by the bot
## (env HELM_DUMP): the glaive is heaved up over the LEFT shoulder instead, laid back 45 deg, blade
## high behind the left pauldron (tip ~0.3 m higher than before), passing in the gap between the
## helm and the left pauldron; the chest turns a little the other way (-8.1) so the right hand comes
## across. The hang now clears the helm by 0.056 m/size. The slam's mid-arc follows it out in front
## and to the knight's left (the old one swung the haft across the helm's crown on the way down,
## +0.08). env LEAPHELM_OLD=1: the before (LEAP_HEAVE_NEW + LEAP_DOWN_ARC_OLD).
const LEAP_HEAVE_LEFT := [-17.6, 134.6, Vector3(0.389, 2.356, -0.313), -8.1, -0.094, 0.66]
const LEAP_DOWN_LEFT := [-46.3, 62.5, Vector3(0.131, 2.735, 1.007), -3.9, 0.120, 0.65]
static var LEAPHELM_OLD := OS.get_environment("LEAPHELM_OLD") == "1"
static var LEAP_DOWN_ARC: Array = LEAP_DOWN_ARC_OLD if LEAPHELM_OLD else LEAP_DOWN_LEFT
static var LEAPFOLD_OLD := OS.get_environment("LEAPFOLD_OLD") == "1"
static var LEAP_HEAVE: Array = _env_pose("LEAP_HEAVE_TRY", LEAP_HEAVE_OLD if LEAPFOLD_OLD else (LEAP_HEAVE_NEW if LEAPHELM_OLD else LEAP_HEAVE_LEFT))
static var LEAP_UP: Array = _env_pose("LEAP_UP_TRY", LEAP_UP_ARC)
static var LEAP_DOWN: Array = _env_pose("LEAP_DOWN_TRY", LEAP_DOWN_ARC)
## (14:00 11-11) the knight's own leap crouch. CROUCHED (borrowed from the sentinel) held the
## glaive up over the crown (1.9 m, hold just behind the helm's axis), so the guard -> crouch
## wind-up drew the haft 0.11 m/size through the great helm (bot `foefold` W). Searched against
## the bot's helm read-out (30 random + 3 hill-climbs of 6 x 19 s runs): the knight now coils by
## raising the glaive near-upright out in FRONT of the helm (hold 0.74 ahead), blade high, both
## fists on the haft, the left elbow bent (shoulder-wrist 0.25 m/size, gate 0.18), the chest
## turned a little to its right; from there the heave goes up the left side. Wind-up clear of
## the helm by 0.058 m/size, the take-off ticks by 0.008. env CROUCH_OLD=1: the before.
const KNIGHT_CROUCH_FRONT := [25.7, 80.8, Vector3(0.035, 2.012, 0.737), -8.0, 0.002, 0.604]
static var CROUCH_OLD := OS.get_environment("CROUCH_OLD") == "1"
static var LEAP_CROUCH: Array = _env_pose("CROUCH_TRY", CROUCHED if CROUCH_OLD else KNIGHT_CROUCH_FRONT)
## env <name>="yaw,pitch,x,y,z,chest,slide,reach" replaces a pose (tuning loops); else `base`
static func _env_pose(name: String, base: Array) -> Array:
	var e := OS.get_environment(name)
	if e == "":
		return base
	var f := e.split_floats(",")
	return [f[0], f[1], Vector3(f[2], f[3], f[4]), f[5], f[6] if f.size() > 6 else base[4], f[7] if f.size() > 7 else base[5]]
## the surge's coil: the glaive planted point-down beside the right knee, both hands on the
## shaft, leaned on (a shorter crown-reel slump, the blade into the turf)
const SURGE_LEAN := [20.0, -58.0, Vector3(0.12, 1.02, 0.46), 10.0, 0.1, 0.62]
## the surge burst: the knight flung up off its knee roaring (foley: the recorded giant roar)
signal surge_roared(at: Vector3)
## the stomp's boot hit the ground (foley: a ground slam with the boom under it)
signal stomped(at: Vector3)
## the reveal's roar: the glaive brandished skyward on its right, blade up, both hands high
## the reveal's dormant stance: the glaive's point driven a hand's depth into the turf ahead of
## the right boot, both hands low on the haft, leaned on (SURGE_LEAN is set for a kneeling
## body: standing, its point hovered ~0.15 m over the ground at the first size)
const INTRO_REST := [20.0, -58.0, Vector3(0.12, 0.94, 0.46), 10.0, 0.1, 0.62]
## (05:00 11-07) was [-35, 68, (-0.42, 1.85, 0.3), -14]: the left fist sat right in front of the
## visor (y 1.61, arm at full reach across the chest) and the right one at the chest (1.22), so
## the roar read cramped, the hands hugging the helm. Re-solved offline against `_place` (both
## hands unclamped, both fists >= 0.3 m off the helm): the left fist goes up above the helm on
## its right (~1.88), the right fist up to the right shoulder (~1.50), the glaive standing at its
## right side. The chest turns only a little further (-20): at -38 the reveal lens saw its back
const INTRO_ROAR := [-10.0, 65.0, Vector3(-0.27, 2.12, 0.24), -20.0, 0.1, 0.66]
## (08:00 11-10) the surge's roar: INTRO_ROAR puts the right fist ~0.1 m from its shoulder (the arm
## folded shut), so the forearm GripRoll squares the hand to has no clear line and the one-handed
## brandish rolled the fist off the haft (bot surgegrip: 0.14 m per size). Here the fist is held out
## 0.37 m forward-right of the shoulder at chest height with the forearm square to a near-upright
## glaive (found offline: fist-shoulder line . shaft ~0.01, left fist within reach until it lets
## go). Env SURGE_OLDROAR: the before.
const SURGE_ROAR := [-20.0, 75.0, Vector3(-0.25, 2.05, 0.4), -20.0, 0.1, 0.66]
## env INTRO_ROAR_TRY="yaw,pitch,x,y,z,chest" replaces the reveal's roar pose (tuning loops)
func _intro_roar_pose() -> Array:
	var e := OS.get_environment("INTRO_ROAR_TRY")
	if e == "":
		return INTRO_ROAR
	var v := e.split_floats(",")
	return [v[0], v[1], Vector3(v[2], v[3], v[4]), v[5], INTRO_ROAR[4], INTRO_ROAR[5]]
## (09:00 11-07) at the top of the reveal's heave the left hand lets go of the haft and is flung
## up and out to the knight's left, a clenched fist (body frame, unscaled, from the shoulder's
## unit direction x reach): in profile the raised left arm sat in front of / over the flung-back
## helm (kside frame at 08:30), so the roar read as a hunch with a fist up. The glaive stays
## brandished skyward in the right hand alone, the shaft along the pose's own direction
const ROAR_FLING_DIR := Vector3(0.4, 0.91, 0.1)
const ROAR_FLING_REACH := 0.58
## how far the head is flung back at the roar's peak (rad; was 0.62, hidden under the hood)
const ROAR_HEAD_BACK := 0.85
## the reveal's gather (the coil before the heave): the glaive drawn down and back on its right,
## both hands low at the right hip, the blade trailing behind the right boot, so the heave is an
## upward sweep round the right side instead of a lift from a raised crouch (01:00 11-07: the
## gather borrowed the leap's CROUCHED, which RAISED the glaive to 1.9 m before the heave)
## (03:10 11-07) the hands sit along the shaft from the hold point, so a blade trailing low behind
## put them up at the chest (y 1.10-1.34, butt 1.55 m by the face) once the shoulder reach clamp
## bit. Re-solved offline against `_place`: the shaft near level pointing back-right (-150, -8),
## the hold point back by the right hip, the chest twisted well round (-65) so the left hand
## reaches; fists now ~0.95 m up on its right, butt ~1.0 m, grip gap 0.029 (bot `knight`)
const INTRO_COIL := [-150.0, -8.0, Vector3(-0.5, 0.97, -0.25), -65.0, 0.1, 0.64]
const INTRO_COIL_REAL := [-150.0, -8.0, Vector3(-0.56, 0.97, -0.25), -65.0, 0.1, 0.64]
## env INTRO_COIL_TRY="yaw,pitch,x,y,z,chest" replaces the reveal's coil pose (tuning loops)
static func _intro_coil_pose() -> Array:
	var e := OS.get_environment("INTRO_COIL_TRY")
	if e == "":
		return INTRO_COIL_REAL if SHOULDER_MODEL_REAL else INTRO_COIL
	var v := e.split_floats(",")
	return [v[0], v[1], Vector3(v[2], v[3], v[4]), v[5], INTRO_COIL[4], INTRO_COIL[5]]
## (11-11) the coil against the REAL shoulders (with the reach slide): measured from the arm bones
## the right shoulder sits 0.14 m higher than the old model (1.61-1.63 in the twist), so the hands
## at the right hip were asked 0.12-0.39 m past reach through the coil and the early heave and the
## clamp bent the glaive 50-61 deg off its line, swinging the butt to the left hip (0.29). With the
## slide the grips rise ~0.13-0.37 along the line instead, which drew the coil's left fist to the
## belly (x -0.01); the hold point 0.06 m further right keeps it at the right hip (-0.04)
## how far right (body -X, unscaled m) the hands carry the glaive down the follow-through, so
## the shaft comes down beside the helm instead of standing upright in front of the face
## (11:00 11-10) was 0.32: carried that far right the left grip ran 0.07-0.15 m past its reach as
## the glaive came down, so the two-hand axis drifted up to 19 deg off the pose and the shaft
## stalled for a tick (5.7 -> 3.5 -> 5.9 deg/tick) at the roar's end. Solved offline against
## `_place` and tried in the bot (0.10/0, 0.18/0.05, 0.25/0.10): 0.25 right plus 0.10 more reach
## keeps the haft furthest off the visor (0.36 m) and the fists closest (0.020); the shaft now
## speeds up every tick from the top of the roar into the swing. Env FOLLOW_WIDE: the before.
const FOLLOW_RIGHT := 0.25
const FOLLOW_REACH := 0.10
## (11-10 12:00) from this intro time the reveal eases off the old guard onto the re-solved one
const REVEAL_GUARD_FROM := 4.35
## (09:00 11-10) the follow-through carries the hold point forward (was 0.08 back): drawn back, the
## right fist came down ~0.2 m from its shoulder (the arm folded shut), the IK flipped the hand as the
## glaive swept past and the fist popped 0.24 m per size off the haft for a tick (bot knight:
## follow-through 0.132 -> 0.019 right, haft still 0.33 m off the visor). Env FOLLOW_BACK: the before.
const FOLLOW_FWD := 0.15
## (11-10) the heave's round-the-side terms are gone this long before ROAR_END
const HEAVE_FADE := 0.15
## how far the heave's path bows out round the right side mid-rise (deg of shaft yaw, unscaled m
## of hands out to the right), so the blade sweeps up beside the body, never across the chest
const HEAVE_ROUND_YAW := 35.0
const HEAVE_ROUND_OUT := 0.12
## (07:00 11-07) the pitch leads the yaw in the heave: out of the coil the shaft came round to
## point right near level (pitch ~20 at up 0.4), so the butt swung low across to the left hip.
## Lifting the blade first stands the shaft up beside the right side before it swings round
const HEAVE_LIFT := 50.0
const HEAVE_FWD := 0.15
const HEAVE_REACH_IN := 0.06
## how much of the reveal's spine arch the glaive pose is swung back with (about SPINE_BASE)
const ROAR_CARRY := 0.9
const SPINE_BASE := Vector3(0.0, 1.02, 0.0)   # body space, unscaled: where the arch bends from
const LEAP_HEAVED_U := 0.35       # fraction of the airtime by which the glaive is fully overhead
const TUCK_HIP := 1.15            # rad the thighs come up at the top of the leap
## (11-11) THE LEAP'S LANDING TAKES THE WEIGHT: the old touch-down came in with straight legs and the
## torso at the flight's lean, so the blade bit with no give. Now the knees give and the body
## pitches over the blade as the boots touch (the end of the airtime), bottoms out a beat into the
## recovery (a damped give, not a hold) and settles to a held crouch over the bitten glaive; the
## grips ride the extra pitch about the hips (`_grip_lean`), so the arms keep their shape. The
## knee hint carries on from the flight into the recovery with no jump. Env LEAPLAND_OLD=1: the before.
const LAND_LEAN := 0.2            # rad of extra pitch from the hips at the bottom of the give
const LAND_SINK := 0.14           # model m of extra drop at the bottom of the give
const LAND_TOUCH_U := 0.86        # airtime fraction from which the knees start to give
const LAND_HOLD := 0.55           # share of the give held while bent over the bitten glaive
static var LEAPLAND_OLD := OS.get_environment("LEAPLAND_OLD") == "1"
## (11-11) the bottom of the give drives the boots into the sward: a low kick of soil and torn turf
## thrown out round each boot (scaled with the giant), and the grass pressed flat where it stands.
## Env LEAPKICK_OFF=1: the before.
const KICK_U := 0.09              # recovery fraction: the bottom of the give
var boot_kicks := 0               # (bots) boot kicks thrown, all leaps
var boot_kick_at: Array = []      # (bots) where the last landing's kicks were thrown (world)
var _kicked := false
const TUCK_KNEE := 1.75           # rad the shins fold back
## STOMP (phases 2 and 3, its answer to a hero crowding its shins): the weight goes onto the
## left leg, the right knee comes up high to the chest and hangs there shuddering (the tell),
## then the boot comes down and a shockwave of torn turf races out across the ground. Roll
## through the front as it reaches you. In phase 3 the stamped ground stays on fire.
const STOMP_MOVE := 4
const STOMP_RAISE_T := 0.55       # brain-time s to lift the knee
const STOMP_HOLD_T := 0.5         # held up, shuddering
const STOMP_T := 0.14             # the boot coming down
const STOMP_RECOVER_T := 1.0
const STOMP_HIP := 1.45           # rad the right thigh comes up
const STOMP_KNEE := 1.55          # rad the shin folds under it
const STOMP_CLOSE := 2.6          # m (x size): a hero this close in phase 2+ gets the stomp
const STOMP_COOL := 6.0           # brain-time s between stomps
const STOMP_R := 4.0              # m (x size): how far the wave runs
const STOMP_SPEED := 4.2          # m/s (x sqrt size): how fast the front travels
const STOMP_DAMAGE := 22.0
const STOMP_FOOT := Vector3(-0.13, 0.0, 0.12)   # body-local: where the right boot lands
const HAZARD_T := 6.0             # s the phase-3 stomp's ground stays burning

signal phase_changed(phase: int)
## a light blow turned aside by the ember guard (foley: a ringing clang on the shaft)
signal guarded_blow(point: Vector3)
## the surge's ring of fire bursting round the kneeling knight
signal blasted(at: Vector3)
## one phase-3 eruption bursting under the hero
signal flame_burst(at: Vector3)
## the ember leap: springing off (foley: a heavy whoosh, a grunt of armour)
signal leapt(at: Vector3)
## the ember leap came down: where the blade bit, and the verdict on the hero
signal leap_landed(at: Vector3, result: String)
## the reveal's roar: the glaive heaved overhead, the ember blazing (foley: a deep boom)
signal roared(at: Vector3)

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
var armour: KnightArmour
var leaps := 0
var leap_results: Array[String] = []
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO      # where its feet land (the bite is LEAP_BITE beyond)
var leap_lift := 0.0             # current height of the arc (hurt capsule and model ride it)
var _leap_cool := 0.0
var last_scorch: Scorch          # the burn the last leap left in the turf (bots)
var last_ring: Array = []        # (bots) the ember ring the last leap's bite flared up
var tuck: LegTuck                # bends the knees in the crouch and tucks them up in the air
var land_give := 0.0             # (bots) the landing's give this tick, 0..1
var land_give_peak := 0.0        # (bots) the deepest give of the last leap
var _land_lean := 0.0            # this tick's extra landing pitch (the grips ride it)
var _terrain_ref: Terrain
var growth := BossGrowth.new(PHASES)
## INTRO (BossIntro): the first time the hero walks in it does not just start: the camera cranes
## up the giant, it squares up and heaves the glaive overhead with the ember roaring, then the
## fight begins. Once per run; a hero coming back after a death goes straight to the fight.
var intro_enabled := true
var intro_seen := false
var intro: BossIntro
var intros := 0                  # bots
var crowned_count := 0           # bots: crown strikes that rocked it
const CROWN_STAGGER := 1.3       # s the giant reels after a plunge through its helm
const CROWN_IMPACT_U := 0.07     # the reel starts here: the head is already knocked down in the hit-stop
## The crown reel's glaive: the hands lose it and it droops, blade into the turf, leaned on.
const CROWN_SLUMP := [24.0, -44.0, Vector3(0.14, 0.94, 0.52), 12.0]
var head: HeadBow                # bows the head onto the chest in the crown reel and the surge
var glare: HeadGlare             # the neck turns the helm back onto the hero in the reveal's coil
var intro_glare_err := 0.0       # bots: worst yaw (rad) left between the helm and the hero in the coil
var _crown_reel := false

## The crown reel and the growth surge choreograph the whole body themselves: the plain hit
## reaction at the joints stands aside for them.
func _reel_owned() -> bool:
	return _crown_reel or _surge >= 0.0
var crown_bow_peak := 0.0        # bots: deepest head bow of the last crown reel (rad)
var crown_sink_peak := 0.0       # bots: deepest buckle of the knees in it
var crown_lift_back := 0.0       # bots: how far the head was thrown back as it shook the blow off
var crown_hits_kept := 0         # bots: blows landed in the reel that did not cut it short
## (11-10 03:00) the crown reel's left hand: lets go of the haft and cups the left side of the
## helm through the daze, back on the haft before the glaive comes up to guard
var clutch := 0.0                # 0..1: the left hand off the haft and on the helm
var clutch_peak := 0.0           # bots: highest clutch of the last reel
var clutch_gap := 9.0            # bots: closest the left palm came to the helm's side point (m per size)
## u window the hand leaves the helm in: back on the haft before the glaive starts up at 0.58 (a
## later regrip, 0.54-0.7, overlapped the rise and threw the right fist 0.3 m per size off the haft)
const CLUTCH_REL := [0.46, 0.62]
const CLUTCH_AT := Vector3(0.15, 0.06, 0.07)  # body space, unscaled: off the head bone, the helm's left temple
## (11-10 04:00) the hand's flight to the helm: it reaches quickly and lands a touch past the temple
## (along its path, up the side of the helm), then settles back onto it on a damped spring
var clutch_flight := 0.0         # 0..~1.07: how far along the haft-to-helm path the hand is
var clutch_flight_peak := 0.0    # bots: highest flight of the last reel (the overshoot)
var clutch_settled_gap := 0.0    # bots: worst palm to temple point once it has settled (u 0.32-0.44)
const CLUTCH_OVER := 0.2         # amplitude of the landing overshoot (fraction of the path)
const CLUTCH_HEAD_KICK := 0.07   # rad: the head knocked away from the landing hand
const CLUTCH_LAND := [0.2, 0.31] # u window of the landing and settle
var _head_bow := 0.0
var _head_roll := 0.0
var intro_heave := 0.0           # bots: how far the roar beat raised the glaive (0..1)
var _heave_now := 0.0
## 0..1: the left hand off the haft, flung out (the reveal's roar)
var free_l := 0.0
var _intro_it := 0.0
var _intro_dorm := 1.0
var _intro_arch := 0.0           # the reveal's spine bend at the joints (Crumple.spine: + hunched, - arched back)
var _intro_arched := false
var intro_arch_peak := 0.0       # bots: deepest back arch of the roar (rad, negative)
var intro_hunch_peak := 0.0      # bots: deepest hunch while dormant / coiled (rad)
var intro_bow_peak := 0.0        # bots: head bowed asleep in the reveal (rad)
var intro_lift_back := 0.0       # bots: head flung back in the reveal's roar (rad, negative)
var intro_gather_peak := 0.0     # bots: how deep the knees set before the heave (m)
var grow_peak_shake := 0.0       # bots
var surge_kneel_peak := 0.0      # bots: deepest kneel of the surges (0..1)
var surge_heave_peak := 0.0      # bots: how far the burst heaved the glaive up (0..1)
var surge_bow_peak := 0.0        # bots: head bowed into the coil (rad)
var surge_lift_back := 0.0       # bots: head flung back in the roar (rad, negative)
var stomps := 0                  # bots
var stomp_results: Array[String] = []
var last_wave: Shockwave         # bots
var last_hazard: Scorch          # bots: the phase-3 stomp's burning ground
var _stomp_cool := 0.0

func _ready() -> void:
	health_max = KNIGHT_HP
	health = KNIGHT_HP
	poise_max = KNIGHT_POISE
	super._ready()
	name = "AshenKnight"
	model.scale = Vector3(1.14, 1.16, 1.16)
	_model_rest = model.transform
	if not OS.has_environment("KGUARD_OLD"):
		guard_pose = KNIGHT_GUARD
	# iron-dark ash, a hotter ember
	_set_skin("ash_dark", Color(0.06, 0.055, 0.052))
	_set_skin("ash_light", Color(0.30, 0.28, 0.26))
	_set_skin("ember_col", Color(1.0, 0.32, 0.06))
	_ember_range = 3.4
	_dress()
	if skel != null:
		tuck = LegTuck.new()
		tuck.name = "LegTuck"
		tuck.side = body
		tuck.floor_fn = _ground
		tuck.floor_of = self
		skel.add_child(tuck)
		# right after the stride/ground IK: the stomp's weight shift moves the hips, and the
		# arm IK after it keeps the fists on the glaive
		if stride_warp != null and stride_warp.get_parent() == skel:
			skel.move_child(tuck, stride_warp.get_index() + 1)
		head = HeadBow.new()
		head.name = "HeadBow"
		head.side = body
		skel.add_child(head)
		# (11-10 06:00) the bow bends Spine2, the shoulders' parent: after the arm IK it carried the
		# fists off the glaive (3.5 cm per size through the crown daze, a 0.35 runaway as the head
		# lifted in the rise, which neither the same-tick pass nor the fit could see). Before the
		# arm IK the arms are solved from the bowed chest. env HEADBOW_LATE: the before
		if OS.get_environment("HEADBOW_LATE") == "" and _ik != null and _ik.get_parent() == skel:
			skel.move_child(head, _ik.get_index())
			head.record_hand = false
			skel.skeleton_updated.connect(_record_left_hand)
		if skel != null and SHOULDER_MODEL_REAL:
			skel.skeleton_updated.connect(_record_shoulders)
		# after the bow: the helm stays on the hero while the chest twists away in the coil
		glare = HeadGlare.new()
		glare.name = "HeadGlare"
		glare.side = body
		skel.add_child(glare)
	add_to_group("boss")
	set_size_scale(growth.scale_of(1))

## Armour over the ash body: the soldier's hood comes off for a closed helm, pauldrons and a
## gorget go on, the grey rags turn to a burnt oxblood surcoat and the leaf blade becomes a
## broad glaive head.
func _dress() -> void:
	for att in skel.get_children():
		if att is BoneAttachment3D and (att as BoneAttachment3D).bone_name == HollowRags.BONE_HEAD:
			att.visible = false
	rags.set_param("cloth_dark", Color(0.10, 0.025, 0.02))
	rags.set_param("cloth_light", Color(0.27, 0.07, 0.045))
	rags.set_param("soot_amt", 0.55)
	armour = KnightArmour.new()
	armour.name = "Armour"
	add_child(armour)
	armour.build(skel, body)
	armour.fit_glaive(spear, HollowSpear.LENGTH * 0.5 - HollowSpear.BLADE)
	_mats.append_array(armour.mats)
	growth.seam_fn = armour.seam_at
	growth.seam_n = armour.seams.size()
	_set_skin("heat", 0.0)

## The lean and sink tilt the whole model from the hips; the leg tuck can put the boots back
## where they stood upright (the stomp's planted boots).
func _lean(rad: float, sink: float) -> void:
	super._lean(rad, sink)
	if tuck != null:
		tuck.model = model
		# in the leap's flight the upright model keeps its height off the turf (only the lean is undone)
		tuck.model_up = Transform3D(Basis(Vector3.UP, _reel_yaw), Vector3.UP * _up_lift) * _model_rest

var _up_lift := 0.0   # model-space height the leap's arc carries the model (LegTuck's upright reference)

func _legs_still() -> bool:
	return (move_kind == LEAP_MOVE and state in [WINDUP, STRIKE, RECOVER]) or (_crown_reel and state == STAGGER)

func _feet_planted() -> bool:
	return tuck != null and tuck.pin > 0.5

## The hero woke at the rest point: the knight stands whole again, in its first form.
func return_to_post() -> void:
	super.return_to_post()
	if state == DEAD:
		return
	_set_phase(1)
	growth.stop()
	set_size_scale(growth.scale_of(1))
	_surge = -1.0
	_leap_cool = 0.0
	_stomp_cool = 0.0
	leap_lift = 0.0
	if rags != null:
		rags.stream = 0.0
		rags.flap = 0.0
		rags.air_y = 0.0
	_flame_t = 0.0
	for f in flames:
		if is_instance_valid(f):
			f.queue_free()
	flames.clear()

func plant(terrain: Terrain) -> void:
	_terrain_ref = terrain
	super.plant(terrain)

func hurt_capsule() -> Array:
	var c := super.hurt_capsule()
	c[0] += Vector3.UP * leap_lift
	c[1] += Vector3.UP * leap_lift
	return c

func health_fraction() -> float:
	return clampf(health / health_max, 0.0, 1.0)

func surging() -> bool:
	return _surge >= 0.0

## A giant reaches farther in every direction: world distances tuned for the original
## knight (size 1) scale by this.
func _reach_k() -> float:
	return size_scale

func set_size_scale(s: float) -> void:
	super.set_size_scale(s)
	give_up = GIVE_UP * sqrt(s)
	notice = NOTICE * sqrt(s)

func intro_playing() -> bool:
	return intro != null and is_instance_valid(intro) and intro.is_playing()

## Waking at the hero for the first time starts the reveal instead of the stalk.
func _enter(s: int) -> void:
	if s == STALK and state == IDLE and intro_enabled and not intro_seen and _player != null \
			and not _player.is_dead() and move_kind != INTRO_MOVE:
		_begin_intro()
		return
	super._enter(s)

func _begin_intro() -> void:
	intros += 1
	_from = _pose
	move_kind = INTRO_MOVE
	super._enter(WINDUP)
	intro = BossIntro.play(self, _player)
	intro.finished.connect(_end_intro)

func _end_intro(_skipped: bool) -> void:
	intro_seen = true
	intro = null
	if state == WINDUP and move_kind == INTRO_MOVE:
		_from = _pose
		move_kind = THRUST_MOVE
		super._enter(STALK)

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	if intro_playing():
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
		guarded_blow.emit(point)
		if _player != null:
			_player.add_shake(0.25)
		# the turned blow opens the hero up: it answers quickly
		if state == STALK:
			t = maxf(t, 0.25)
		return
	if _crown_reel and state == STAGGER:
		# the reel is the punish window: blows land in full but do not restart it as a plain flinch
		var keep_t := t
		var keep_from: Array = _from
		super.take_hit(point, dir, power, hitstop)
		if state != DEAD:
			crown_hits_kept += 1
			state = STAGGER
			t = keep_t
			_from = keep_from
			_stagger_len = CROWN_STAGGER
			_knock = Vector3.ZERO
	else:
		super.take_hit(point, dir, power, hitstop)
	if state != DEAD and phase < 3 and health <= health_max * PHASE_AT[phase - 1]:
		_begin_surge()

## The hero dropped onto its helm with a plunge (StaffCombat crown strike): unless it is
## surging, waking or in the air, the giant reels a long beat, head bowed, whatever its poise.
func crowned(_point: Vector3) -> void:
	if state == DEAD or _surge >= 0.0 or intro_playing():
		return
	if move_kind == LEAP_MOVE and state == STRIKE:
		return
	crowned_count += 1
	staggers += 1
	poise = 0.0
	_update_glint(0.0)
	_set_tuck(0.0, 0.0)
	_from = _pose
	_knock = Vector3.ZERO
	_stagger_len = CROWN_STAGGER
	_recoil = 1.4
	_flash = 1.0
	state = STAGGER
	_crown_reel = true
	crown_bow_peak = 0.0
	crown_sink_peak = 0.0
	crown_lift_back = 0.0
	clutch_peak = 0.0
	clutch_gap = 9.0
	clutch_flight_peak = 0.0
	clutch_settled_gap = 0.0
	# start a beat in, already knocked down: the hit-stop freezes the head on the chest
	t = CROWN_IMPACT_U * CROWN_STAGGER
	_crown_tick(0.0, true)

## The crown reel, frame by frame (u = 0..1 over CROWN_STAGGER). Knocked down: the head snaps
## onto the chest, the knees buckle, the chest folds over them and the hands let the glaive
## droop blade-first into the turf. Dazed: the helm lolls side to side, the ember gutters.
## Shaking it off: the head jerks side to side, throws back past upright and settles, the
## knees drive straight, the glaive comes back up to the guard.
func _crown_tick(delta: float, snap := false) -> void:
	var u := clampf(t / CROWN_STAGGER, 0.0, 1.0)
	var down := smoothstep(0.0, CROWN_IMPACT_U, u) * (1.0 - smoothstep(0.52, 0.92, u))
	var hold := smoothstep(0.0, CROWN_IMPACT_U, u) * (1.0 - smoothstep(0.42, 0.62, u))
	var shake := smoothstep(0.5, 0.6, u) * (1.0 - smoothstep(0.78, 0.9, u))
	var back := sin(PI * clampf((u - 0.66) / 0.3, 0.0, 1.0))
	# the blow drives the head lower than it rests in the daze: an overshoot at the impact
	var hit := 1.0 - smoothstep(CROWN_IMPACT_U, 0.24, u)
	var bow := 0.78 * down + 0.22 * hit - 0.24 * back
	var roll := 0.2 * sin((u - CROWN_IMPACT_U) * TAU * 1.5) * hold * smoothstep(0.1, 0.22, u) \
		+ 0.13 * sin(u * TAU * 7.5) * shake
	# (11-10 04:00) the gauntlet landing on the helm's left side knocks the head a little to its
	# right (+roll drops it toward the body's +X, the hand's side), then it settles back
	var land := _clutch_spring(u)
	if OS.get_environment("CROWN_NOCLUTCH") == "" and OS.get_environment("CLUTCH_LINEAR") == "":
		roll -= CLUTCH_HEAD_KICK * land
	if snap:
		_head_bow = bow
		_head_roll = roll
	else:
		# the head carries its own weight: a little lag on top of the curve, never a jump
		var k := 1.0 - exp(-30.0 * delta)
		_head_bow = lerpf(_head_bow, bow, k)
		_head_roll = lerpf(_head_roll, roll, k)
	if head != null:
		head.bow = _head_bow
		head.roll = _head_roll
	var sink := 0.21 * down + 0.05 * hit
	_set_tuck(0.62 * down + 0.1 * hit, 1.22 * down + 0.2 * hit)
	# the knees buckle over boots that stay where they stood (latched: a reel that caught it
	# mid-stride holds that stride); as it shakes it off and straightens, a settle step each
	_plant(1.0 - smoothstep(0.66, 0.96, u))
	if tuck != null:
		tuck.latch = true
	_lean(_crown_lean(u), sink)
	# (11-10) the left hand goes to the helm a beat after the blow (the head is already down), holds
	# it through the daze, and leaves it as the shake starts, back on the haft before the glaive rises
	clutch = 0.0 if OS.get_environment("CROWN_NOCLUTCH") != "" else \
		smoothstep(0.1, 0.26, u) * (1.0 - smoothstep(CLUTCH_REL[0], CLUTCH_REL[1], u))
	free_l = clutch
	clutch_peak = maxf(clutch_peak, clutch)
	clutch_flight = clutch
	if OS.get_environment("CLUTCH_LINEAR") == "" and u < 0.4 and clutch > 0.0:
		# reach: the hand is off the haft as GripRoll lets it go (the slow smoothstep start) and
		# decelerates into the helm; the landing overshoots and settles (a damped spring)
		var reach := smoothstep(0.1, 0.23, u)
		clutch_flight = reach + CLUTCH_OVER * land
	clutch_flight_peak = maxf(clutch_flight_peak, clutch_flight)
	# the glaive: falls a little behind the head (the hands give way), comes up with the knees
	var gp: Array = _lerp_pose(_from, CROWN_SLUMP, minf(u / 0.26, 1.0)) if u < 0.5 \
		else _lerp_pose(CROWN_SLUMP, guard_pose, smoothstep(0.58, 0.96, u))
	if u >= 0.5 and OS.get_environment("CROWN_FIXEDGLAIVE") == "":
		# (11-10 06:00) the model leans from the hips but the glaive lives in the Wield's (unleaned)
		# space: as the knight straightened, the shoulders swept past the slumped grip and the right
		# arm folded through a singular pose (the fist thrown 0.28 m per size off the haft at u 0.67).
		# From the daze on the glaive is carried in the leaned frame: the slump as it stood at the
		# daze's lean, the guard upright, so both ends are unchanged and the arms keep their shape.
		var lean_now := _crown_lean(u)
		var l0 := _crown_lean(0.5)
		gp = _lean_pose(_lerp_pose(_lean_pose(CROWN_SLUMP, -l0), guard_pose, smoothstep(0.58, 0.96, u)), lean_now)
	_place(gp)
	if OS.has_environment("CROWN_DBG"):
		var sp := spear.global_position if spear != null else Vector3.ZERO
		print("CRD u %.3f free_l %.3f gapR %.3f gapL %.3f offR %.3f offL %.3f aimR %.2f aimL %.2f gr %.2f spear %s" % [u, free_l, fist_gap[0], fist_gap[1], (_fist_off[0] as Vector3).length(), (_fist_off[1] as Vector3).length(), _aim_ik[0].influence if _aim_ik[0] else -1.0, _aim_ik[1].influence if _aim_ik[1] else -1.0, grip_roll.weight if grip_roll else -1.0, str(sp / size_scale)])
	var e := 0.55 + 0.25 * sin(u * 60.0) * hold if u < 0.55 else lerpf(0.6, 1.8, smoothstep(0.55, 0.8, u)) - 0.6 * smoothstep(0.85, 1.0, u)
	_set_skin("ember", e)
	_ember_light.light_energy = 0.3 * e
	crown_bow_peak = maxf(crown_bow_peak, _head_bow)
	crown_sink_peak = maxf(crown_sink_peak, sink)
	crown_lift_back = minf(crown_lift_back, _head_bow)

## the crown reel's lean from the hips (rad, forward +) at reel time u
func _crown_lean(u: float) -> float:
	var down := smoothstep(0.0, CROWN_IMPACT_U, u) * (1.0 - smoothstep(0.52, 0.92, u))
	var hold := smoothstep(0.0, CROWN_IMPACT_U, u) * (1.0 - smoothstep(0.42, 0.62, u))
	var hit := 1.0 - smoothstep(CROWN_IMPACT_U, 0.24, u)
	return 0.27 * down + 0.06 * hit + 0.04 * sin(u * TAU * 1.5) * hold

## A glaive pose leaned with the model by `a` rad (forward +) about the hips (`_lean`'s pivot)
func _lean_pose(pose: Array, a: float) -> Array:
	if absf(a) < 0.0005:
		return pose
	var hip := Vector3(0, 0.95, 0)
	var b := Basis(Vector3.RIGHT.rotated(Vector3.UP, _reel_yaw), a)
	var d := b * StaffCombat.dir_of(pose[0], pose[1])
	var out := pose.duplicate()
	out[2] = hip + b * ((pose[2] as Vector3) - hip)
	out[0] = rad_to_deg(atan2(d.x, d.z))
	out[1] = rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
	return out

## the landing's damped spring over CLUTCH_LAND: up to ~0.6 a beat after contact, a small dip
## back under, 0 by the end of the window
func _clutch_spring(u: float) -> float:
	var s := clampf((u - CLUTCH_LAND[0]) / (CLUTCH_LAND[1] - CLUTCH_LAND[0]), 0.0, 1.0)
	return exp(-3.5 * s) * sin(PI * 1.6 * s) * (1.0 - smoothstep(0.75, 1.0, s))

func _hero_in_front() -> bool:
	if _player == null:
		return true
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.length() < 1e-3 or body.global_basis.z.dot(to.normalized()) > 0.3

func _set_phase(n: int) -> void:
	phase = n
	var pd: Dictionary = growth.phase_data(n)
	tempo = pd["tempo"]
	unblockable = n >= 2
	damage_mul = pd["damage"]
	glint_col = Color(1.0, 0.82, 0.6) if n == 1 else Color(1.0, 0.22, 0.1)
	_set_skin("ember_col", Color(1.0, 0.32, 0.06) if n == 1 else Color(1.0, 0.16, 0.04))
	_set_skin("heat", (n - 1) * 0.5)
	if n >= 2:
		Scorch.burn_texture()   # build the burn now, in the surge, not at the first landing

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
	# the growth moment: a white flash and a short hit-stop on the hero, then the heave
	growth.grit_from = StoneRing.crowns
	growth.start(size_scale, phase)
	_flash = 1.0
	if _player != null:
		_player.add_shake(0.7)
		if _player.combat != null:
			_player.combat.hitstop = maxf(_player.combat.hitstop, 0.12)
	# the body bursts its plate: a dark breath of ash and charred flakes round the chest (capped
	# speed, it hangs round the giant), and a hot spit of embers up out of the gorget
	var chest := global_position + Vector3.UP * 1.25 * size_scale
	ImpactFX.spawn(get_parent(), chest, body.global_basis.z.normalized(), "ash", 1.2 + size_scale * 0.35)
	EmberBurst.spawn(get_parent(), chest + Vector3.UP * 0.35 * size_scale, (body.global_basis.z.normalized() + Vector3.UP).normalized(), size_scale * 0.9)
	phase_changed.emit(phase)

func _physics_process(delta: float) -> void:
	# in the air the giant clears the ring stones (its collision stays on the ground): fly
	# free of them, held to the turf height, and take back its collision as it lands
	var flying := move_kind == LEAP_MOVE and state == STRIKE and _surge < 0.0
	collision_mask = 0 if flying else (1 | 2)
	if not flying:
		_up_lift = 0.0
	super._physics_process(delta)
	if flying and state == STRIKE:
		global_position.y = _ground(global_position) + 0.05
		velocity.y = 0.0
	if tuck != null and not (move_kind == STOMP_MOVE and state in [WINDUP, STRIKE, RECOVER]):
		tuck.lift_hip = 0.0
		tuck.lift_knee = 0.0
		tuck.shift = 0.0
		# the leap's crouch and landing and the crown reel plant the boots too (their own ticks set it)
		# (the reveal and the surge plant them in theirs: the surge's tick runs after this one)
		if not ((move_kind == LEAP_MOVE and state in [WINDUP, STRIKE, RECOVER]) or (_crown_reel and state == STAGGER) \
				or (move_kind == INTRO_MOVE and state == WINDUP)) or _surge >= 0.0:
			tuck.pin = 0.0
	if not (move_kind in [LEAP_MOVE, STOMP_MOVE, INTRO_MOVE] and state in [WINDUP, STRIKE, RECOVER]) and _surge < 0.0:
		_set_tuck(0.0, 0.0)
		if _wield != null:
			_wield.position.y = 0.0
	if _intro_arched and not (move_kind == INTRO_MOVE and state == WINDUP):
		_intro_arch = move_toward(_intro_arch, 0.0, delta * 1.5)
		_pose_arch(_intro_arch)
	if _crown_reel and (state != STAGGER or _surge >= 0.0):
		_crown_reel = false
		if _surge < 0.0:
			clutch = 0.0
			free_l = 0.0
	if _crown_reel and state != DEAD:
		_crown_tick(0.0 if _freeze > 0.0 else delta)
	elif head != null and _surge < 0.0 and not (move_kind == INTRO_MOVE and state == WINDUP):
		# out of the reel the head eases back to the animation's carriage
		var k := 1.0 - exp(-10.0 * delta)
		_head_bow = lerpf(_head_bow, 0.0, k)
		_head_roll = lerpf(_head_roll, 0.0, k)
		head.bow = _head_bow
		head.roll = _head_roll
	if state == DEAD or _freeze > 0.0:
		return
	if _surge >= 0.0:
		_surge += delta * tempo
		if growth.growing():
			set_size_scale(growth.tick(delta, self, _player, 0.6 * size_scale))
		var u := clampf(_surge / SURGE_T, 0.0, 1.0)
		var e := 2.0 + 5.0 * smoothstep(0.0, SURGE_BLAST / SURGE_T, u) * (1.0 - smoothstep(0.6, 1.0, u))
		_set_skin("ember", e + 0.4 * sin(_surge * 40.0))
		# the hairline cracks in the plate split wide and blaze while the body swells under it
		_set_skin("heat", (phase - 1) * 0.5 + 0.9 * sin(PI * u))
		_ember_light.light_energy = 0.45 * e
		_surge_body(delta)
		if not _blasted and _surge >= SURGE_BLAST:
			_blasted = true
			_blast()
		if _surge >= SURGE_T or state != STAGGER:
			_surge = -1.0
			free_l = 0.0
			_set_skin("heat", (phase - 1) * 0.5)
			if growth.growing():
				growth.stop()
				set_size_scale(growth.to_scale)
		return
	_leap_cool = maxf(_leap_cool - delta * tempo, 0.0)
	_stomp_cool = maxf(_stomp_cool - delta * tempo, 0.0)
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

## The surge's body, in beats (brain s): the blow that broke it rocks it back (0-0.3); it
## folds down onto its right knee, hunched over the glaive planted point-down to lean on, the
## head bowed and the shudder building with the ember (the coil, to SURGE_BLAST); the burst
## throws it up and back: chest out, head flung back roaring, the glaive heaved skyward while
## the body swells to its new size and it rises off the knee (to ~1.8); then the head comes
## down onto the hero, the glaive back into guard and the weight settles (to SURGE_T).
func _surge_body(delta: float) -> void:
	var s := _surge
	var recoil := sin(PI * clampf(s / 0.3, 0.0, 1.0))
	var coil := smoothstep(0.1, 0.85, s)
	var burst := smoothstep(SURGE_BLAST - 0.05, SURGE_BLAST + 0.2, s)
	var rise := smoothstep(SURGE_BLAST + 0.05, 1.7, s)
	var settle := smoothstep(1.75, SURGE_T - 0.05, s)
	var kneel := coil * (1.0 - rise)
	var roar := burst * (1.0 - settle)
	# (09:00 11-07) the left hand lets go and is thrust up as it rises roaring, back on the haft
	# before the settle brings the glaive down into guard (as in the reveal)
	free_l = 0.0 if OS.get_environment("ROAR_NOFLING") != "" else \
		smoothstep(SURGE_BLAST + 0.1, SURGE_BLAST + 0.35, s) * (1.0 - smoothstep(1.5, 1.78, s))
	_intro_it = s
	# the coil shudders harder toward the burst; the roar shakes through the arms and head
	var shud := smoothstep(0.4, SURGE_BLAST, s) * (1.0 - burst)
	var p1 := _lerp_pose(_from, SURGE_LEAN, smoothstep(0.1, 0.7, s))
	var roar_pose: Array = INTRO_ROAR if OS.get_environment("SURGE_OLDROAR") != "" else SURGE_ROAR
	var p2 := _lerp_pose(p1, roar_pose, burst)
	_pose = _lerp_pose(p2, guard_pose, settle)
	_pose[1] += sin(s * 38.0) * 2.0 * roar + sin(s * 53.0) * 1.2 * shud
	_place(_pose)
	var lean := -0.12 * recoil * (1.0 - coil) + 0.36 * kneel - 0.24 * roar + 0.01 * sin(s * 47.0) * shud
	# a weight settle as it straightens: the body overshoots a touch low, then stands
	var sink := 0.42 * kneel + 0.05 * sin(PI * settle)
	_lean(lean, sink)
	if _wield != null:
		_wield.position.y = -sink
	# down onto the right knee: both legs fold, the right thigh drops back under the hip so the
	# knee goes to the turf while the left shin stays upright over its planted foot
	_set_tuck(1.0 * kneel, 1.55 * kneel)
	if tuck != null:
		# the left boot stays where it stood while the body folds, pitches and is flung back over
		# it (the pin holds the upright clip's spot, so the growth carries it out with the body);
		# the right leg is bent down onto its knee after the pin, so only the left boot stands
		# latched where it really stood in the body's frame (so the growth carries it out), it
		# lets go in a settle step as the weight settles at the end
		_plant(1.0 - smoothstep(SURGE_T - 0.5, SURGE_T - 0.08, s))
		tuck.latch = true
		tuck.latch_body = true
		tuck.lift_leg = 1
		tuck.lift_hip = -0.8 * kneel
		tuck.lift_knee = 0.3 * kneel
	surge_kneel_peak = maxf(surge_kneel_peak, kneel)
	surge_heave_peak = maxf(surge_heave_peak, burst * (1.0 - settle))
	if head != null:
		var goal := 0.55 * coil * (1.0 - burst) - 0.55 * roar
		var rl := 0.06 * sin(s * 31.0) * roar
		var k := 1.0 - exp(-14.0 * delta)
		_head_bow = lerpf(_head_bow, goal, k)
		_head_roll = lerpf(_head_roll, rl, k)
		head.bow = _head_bow
		head.roll = _head_roll
		surge_bow_peak = maxf(surge_bow_peak, _head_bow)
		surge_lift_back = minf(surge_lift_back, _head_bow)
	if not has_meta("surge_roar_%d" % surges) and s >= SURGE_BLAST + 0.03:
		set_meta("surge_roar_%d" % surges, true)
		surge_roared.emit(global_position + Vector3.UP * 1.6 * size_scale)

## The ember bursts: a ring of fire round the kneeling knight, hurling down whoever stands in
## it (unblockable; a dodge passes through). The second surge leaves the ground smouldering.
func _blast() -> void:
	blasts += 1
	blast_result = "miss"
	var c := global_position
	var k := _reach_k()
	ImpactFX.spawn(get_parent(), c + Vector3.UP * 1.1 * k, body.global_basis.z.normalized(), "stone", 2.4 + k * 0.4)
	blasted.emit(c)
	var ring_n := 7 + int(round((k - 1.0) * 3.0))
	for i in ring_n:
		var a := TAU * i / ring_n + body.rotation.y
		var f := _flame_at(c + Vector3(sin(a), 0, cos(a)) * 2.6 * k, false)
		f.t = AshFlame.WARN - 0.02   # bursts at once: the ring itself is the blast's fire
	if _player == null or _player.is_dead():
		return
	var d := _player.global_position - c
	_player.add_shake(0.6)
	if Vector2(d.x, d.z).length() < SURGE_R * k and absf(d.y) < 2.0 * k:
		blast_result = _player.receive_attack(self, SURGE_DAMAGE, true, true)

func spawn_flame(at: Vector3) -> AshFlame:
	flames_spawned += 1
	return _flame_at(at, true)

func _flame_at(at: Vector3, harms: bool) -> AshFlame:
	var f := AshFlame.new()
	f.radius = AshFlame.RADIUS * sqrt(size_scale / growth.scale_of(1))
	f.source = self
	f.player = _player if harms else null
	get_parent().add_child(f)
	f.global_position = at
	if harms:
		flames.append(f)
		f.burst.connect(func(p: Vector3) -> void: flame_burst.emit(p))
	return f

# --- the ember leap ---

## A hero hanging back past glaive reach in phase 2 or 3 gets the leap once it has squared up.
func _stalk(to: Vector3, dist: float) -> Vector3:
	# hard but fair: a hero it threw down gets back up before the next blow is wound up
	if _player != null and _player.is_down():
		_turn_to(to, get_physics_process_delta_time(), 3.0)
		t = 0.0
		return Vector3.ZERO
	if can_leap(dist) and (force_move < 0 or force_move == LEAP_MOVE):
		_turn_to(to, get_physics_process_delta_time(), 6.0)
		if t > LEAP_SQUARE and _facing(to) > 0.9:
			windups += 1
			_from = _pose
			move_kind = LEAP_MOVE
			_aimed = false
			_enter(WINDUP)
			return Vector3.ZERO
		return to.normalized() * STALK_SPEED * 0.35
	return super._stalk(to, dist)

## A hero crowding its shins in phase 2+ gets the stomp (when it is ready).
func _choose(dist: float) -> int:
	if force_move == STOMP_MOVE or (force_move < 0 and phase >= 2 and _stomp_cool <= 0.0 \
			and dist < STOMP_CLOSE * size_scale):
		return STOMP_MOVE
	return super._choose(dist)

## the landing's give over the last of the airtime: the boots touch and the knees start to go
static func _land_give_strike(u: float) -> float:
	return 0.35 * smoothstep(LAND_TOUCH_U, 1.0, u)

## ... and on into the recovery: it bottoms out a beat after the bite, comes back up a little
## and holds the crouch over the glaive (the recovery's wrench eases it out with the rest)
static func _land_give_recover(u: float) -> float:
	if u < 0.09:
		return lerpf(0.35, 1.0, sin(0.5 * PI * u / 0.09))
	return lerpf(1.0, LAND_HOLD, smoothstep(0.09, 0.32, u))

## the leap's landing pitch rides the grips (the rest of the leap's lean was tuned unleaned)
func _grip_lean(lean: float) -> float:
	if move_kind == LEAP_MOVE and state in [STRIKE, RECOVER] and not LEAPLAND_OLD:
		return _land_lean
	return super._grip_lean(lean)

func leaps_landed() -> int:
	return leap_results.size()

func can_leap(dist: float) -> bool:
	var k := _reach_k()
	return phase >= 2 and _leap_cool <= 0.0 and dist > LEAP_MIN * k and dist < LEAP_MAX * k and _surge < 0.0

func _ground(p: Vector3) -> float:
	return _terrain_ref.height_at(p.x, p.z) if _terrain_ref != null else p.y

## Where the blade bites on landing.
func leap_bite() -> Vector3:
	var b := leap_to + body.global_basis.z * LEAP_BITE
	b.y = _ground(b)
	return b

func _special_tick(delta: float, to: Vector3, dist: float) -> Array:
	# the surcoat and tabards only take the air in the leap's flight
	if rags != null and not (move_kind == LEAP_MOVE and state == STRIKE):
		rags.stream = 0.0
		rags.flap = 0.0
		rags.air_y = 0.0
	if glare != null:
		glare.weight = 0.0
	if move_kind == INTRO_MOVE:
		return _intro_tick(delta, to)
	if move_kind == STOMP_MOVE:
		return _stomp_tick(delta, to)
	if move_kind != LEAP_MOVE:
		return super._special_tick(delta, to, dist)
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var u := clampf(t / LEAP_CROUCH_T, 0.0, 1.0)
			# tracks the hero through the crouch, then the landing is fixed
			if u < LEAP_LOCK:
				_turn_to(to, delta, 7.0)
				var tgt := _player.global_position if _player != null else global_position
				var off := tgt - global_position
				off.y = 0.0
				var lk := _reach_k()
				var reach := clampf(off.length() - LEAP_BITE * lk, 0.5, (LEAP_MAX - LEAP_BITE) * lk)
				leap_to = global_position + off.normalized() * reach if off.length() > 1e-3 else global_position
			_pose = _lerp_pose(_from, LEAP_CROUCH, smoothstep(0.0, 0.7, u))
			_pose[1] += sin(t * 44.0) * 1.0 * smoothstep(0.6, 0.9, u)
			lean = 0.26 * smoothstep(0.0, 0.7, u)
			sink = 0.34 * smoothstep(0.0, 0.7, u)
			_set_tuck(0.85 * smoothstep(0.0, 0.7, u), 1.6 * smoothstep(0.0, 0.7, u))
			# the boots stay where they stand as it coils down and pitches forward over them
			_plant(1.0)
			ember = 1.0 + 4.0 * smoothstep(0.2, 0.9, u)
			_update_glint(smoothstep(0.55, 0.8, u) * (1.0 - smoothstep(0.92, 1.0, u)))
			if u >= 1.0:
				_plant(0.0)
				_resolved = false
				strikes += 1
				leaps += 1
				leap_from = global_position
				_leap_cool = LEAP_COOL
				_from = _pose
				leapt.emit(global_position + Vector3.UP * 1.0)
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / LEAP_T, 0.0, 1.0)
			var span := leap_to - leap_from
			span.y = 0.0
			# a steady carry over the ground (brain-time T, so divide by the real airtime)
			var rest := leap_to - global_position
			rest.y = 0.0
			var left := maxf((LEAP_T - t) / tempo, get_physics_process_delta_time())
			move = (rest / left) if u < 1.0 else Vector3.ZERO
			move = move.limit_length(span.length() / LEAP_T * tempo * 1.6)
			leap_lift = LEAP_H * size_scale * sin(PI * u)
			# the air tears past: the tabards stream back on the way up and flare up off the
			# legs on the way down (rags reads the rise and fall off the model), then slap down
			if rags != null:
				rags.stream = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.9, 1.0, u))
				rags.flap = rags.stream * (0.6 + 0.4 * rags.fall)
				rags.air_y = LEAP_H * size_scale * PI * cos(PI * u) * tempo / LEAP_T if u < 1.0 else 0.0   # world m/s (rags divides by the body scale)
			# up with the glaive heaved overhead, then down blade first
			if u < 0.6:
				var r := clampf(u / LEAP_HEAVED_U, 0.0, 1.0)
				_pose = _lerp_pose(_from, LEAP_HEAVE, r) if LEAPFOLD_OLD else _arc_pose(_from, LEAP_UP, LEAP_HEAVE, r)
			else:
				var r := smoothstep(0.0, 1.0, (u - 0.6) / 0.4)
				_pose = _lerp_pose(LEAP_HEAVE, StoneSentinel.SLAMMED, r) if LEAPFOLD_OLD else _arc_pose(LEAP_HEAVE, LEAP_DOWN, StoneSentinel.SLAMMED, r)
			# knees drive up off the crouch, tucked through the top, legs reach down to land
			var k := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.72, 0.97, u))
			var c := 1.0 - smoothstep(0.0, 0.18, u)
			var g := 0.0 if LEAPLAND_OLD else _land_give_strike(u)
			var th := lerpf(0.85 * c, TUCK_HIP, k)
			var tk := lerpf(1.6 * c, TUCK_KNEE, k) + 0.5 * smoothstep(0.9, 1.0, u)
			if not LEAPLAND_OLD:
				# the knee hint runs on into the recovery's crouch (0.55, 1.1) as the legs take the weight
				var w := smoothstep(LAND_TOUCH_U, 1.0, u)
				th = lerpf(th, 0.55, w)
				tk = lerpf(tk, 1.1, w)
			_set_tuck(th, tk)
			# pitched into the leap, then over onto the blade
			lean = lerpf(0.12, 0.34, smoothstep(0.55, 1.0, u)) + LAND_LEAN * g
			sink = -leap_lift / size_scale + 0.22 * smoothstep(0.85, 1.0, u) + LAND_SINK * g   # model space (scaled)
			_land_lean = LAND_LEAN * g
			land_give = g
			if u < 0.5:
				land_give_peak = 0.0
			land_give_peak = maxf(land_give_peak, g)
			# the legs reach down under the pitched body for the landing: the boots are planted
			# over the last of the fall (the held height only comes down, so they track it to
			# the turf) and touch down where they then stay through the recovery
			_up_lift = leap_lift / size_scale
			_plant(smoothstep(0.78, 0.95, u))
			ember = 5.0 - 1.0 * u
			_update_glint(smoothstep(0.35, 0.55, u) * (1.0 - smoothstep(0.75, 0.88, u)))
			if u >= 1.0:
				leap_lift = 0.0
				_up_lift = 0.0
				# the blade bites ahead of where the feet actually came down
				leap_to = Vector3(global_position.x, leap_to.y, global_position.z)
				if not _resolved:
					_resolved = true
					_resolve_leap()
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / LEAP_RECOVER_T, 0.0, 1.0)
			# bent over the bitten glaive, then wrenches it free
			var f := smoothstep(0.55, 1.0, u)
			_pose = _lerp_pose(StoneSentinel.SLAMMED, guard_pose, f)
			lean = 0.34 * (1.0 - f) - 0.08 * sin(PI * f)
			sink = 0.24 * (1.0 - f)
			_set_tuck(0.55 * (1.0 - f), 1.1 * (1.0 - f))
			# the give is spent before the boots let go to the clip (pin 1 -> 0 over u 0.85-1): a
			# pitch or drop still on at the release swings the boots across the turf as they go
			var g := 0.0 if LEAPLAND_OLD else _land_give_recover(u) * (1.0 - smoothstep(0.5, 0.82, u))
			lean += LAND_LEAN * g
			sink += LAND_SINK * g
			_land_lean = LAND_LEAN * g
			land_give = g
			land_give_peak = maxf(land_give_peak, g)
			if u < KICK_U * 0.5:
				_kicked = false
			if not _kicked and u >= KICK_U and not LEAPLAND_OLD:
				_kicked = true
				_boot_kick()
			# the boots stay where they came down while it is bent over the blade; they let go to
			# the clip once the lean and the crouch have nearly run out
			_plant(1.0 - smoothstep(0.85, 1.0, u))
			ember = 2.2 - 1.0 * u
			if u >= 1.0:
				_plant(0.0)
				_set_tuck(0.0, 0.0)
				_enter(STALK)
	# the glaive's wield frame lives on the body, the model rides the sink: carry the grips
	# with it so the hands stay on the haft through the crouch and the whole arc
	if _wield != null:
		_wield.position.y = -sink
	return [move, lean, sink, ember]

## The reveal's beat in body beats, timed off the intro camera (it = intro s):
##  DORMANT (0 .. ~1.0): it stands slumped over its grounded glaive, head bowed on its chest,
##    the ember barely alight, while the camera starts low at its boots.
##  WAKE (~1.0 .. 2.3): the head lifts slowly onto the hero, the chest straightens, the ember
##    gathers (the camera is craning up the body).
##  GATHER (2.3 .. 2.95): the anticipation: it sets its feet wide, knees bending, the head dips
##    and the glaive is drawn down and back low, coiling for the heave.
##  HEAVE + ROAR (2.95 .. 3.9): knees drive straight, the glaive is thrown up skyward, the chest
##    out and the head flung back roaring; the roar shakes through the arms and the helm.
##  FOLLOW-THROUGH (3.9 .. T): the head comes down onto the hero first, the glaive follows past
##    the guard a touch low and rises back into it, the weight settles with a small dip.
func _intro_tick(delta: float, to: Vector3) -> Array:
	var it := intro.t if intro != null and is_instance_valid(intro) else BossIntro.T
	var skip := intro != null and is_instance_valid(intro) and intro.skipped
	# it only squares up once it has woken
	_turn_to(to, delta, 2.5 * smoothstep(0.8, 1.8, it))
	var r0 := BossIntro.CRANE_T + 0.15
	var wake := smoothstep(0.9, 2.3, it)
	var gather := smoothstep(2.25, r0, it) * (1.0 - smoothstep(r0 - 0.05, r0 + 0.2, it))
	var up := smoothstep(r0 - 0.05, r0 + 0.35, it) * (1.0 - smoothstep(BossIntro.ROAR_END - 0.15, BossIntro.T - 0.25, it))
	var roar := smoothstep(r0 + 0.15, r0 + 0.35, it) * (1.0 - smoothstep(BossIntro.ROAR_END - 0.25, BossIntro.ROAR_END + 0.05, it))
	var down_u := clampf((it - (BossIntro.ROAR_END - 0.15)) / (BossIntro.T - BossIntro.ROAR_END - 0.1), 0.0, 1.0)
	var follow := sin(PI * down_u)          # the overshoot past the guard on the way down
	var settle := sin(PI * clampf((it - BossIntro.ROAR_END - 0.2) / 0.55, 0.0, 1.0))
	# it slumps into the dormant stance over the first beat (no snap from whatever it was doing)
	var dormant := (1.0 - wake) * smoothstep(0.0, 0.4, it)
	if skip:
		# a skip lets it straight down into the guard: no beats, eased from where it was
		up = move_toward(_heave_now, 0.0, delta * 2.5)
		wake = 1.0
		dormant = move_toward(_intro_dorm, 0.0, delta * 2.5)
		gather = 0.0
		roar = 0.0
		follow = 0.0
		settle = 0.0
	_heave_now = up
	_intro_dorm = dormant
	_intro_it = it
	# the left hand lets go once the glaive is up, and is back on the haft before it comes down
	free_l = 0.0 if skip or OS.get_environment("ROAR_NOFLING") != "" else \
		smoothstep(r0 + 0.22, r0 + 0.45, it) * (1.0 - smoothstep(BossIntro.ROAR_END - 0.45, BossIntro.ROAR_END - 0.03, it))
	intro_heave = maxf(intro_heave, up)
	# the glaive: planted point-down and leaned on (the surge's lean) while dormant, drawn low
	# and back in the gather, heaved to the sky, then down past the guard and back up into it
	# (11-10 12:00) the reveal's beats were tuned against the old guard pose (the left grip past its
	# reach, see HollowSoldier.GUARD): it keeps that one as its rest until the downswing is past and
	# eases onto the re-solved guard in the settle (offline: the shaft moves <= 3 deg, the left fist
	# slides 0.09 m up the haft). REVEAL_NEWGUARD=1 env: the new guard throughout (fails the coil gate).
	var rg: Array = guard_pose
	if (guard_pose == HollowSoldier.GUARD or guard_pose == KNIGHT_GUARD) and not OS.has_environment("REVEAL_NEWGUARD"):
		rg = _lerp_pose(HollowSoldier.GUARD_OLD, guard_pose, smoothstep(REVEAL_GUARD_FROM, BossIntro.T, it))
	var base := _lerp_pose(_from, rg, smoothstep(0.0, 0.4, it))
	# the glaive holds the coil until the heave owns it (02:45 11-07: on `gather` it let go of the
	# coil before `up` took over, so the rest pose sprang back to the guard mid-heave and the
	# blade swung up through the front of the body instead of out and up round the right side)
	var coil := smoothstep(2.25, r0, it) * (1.0 - smoothstep(r0 + 0.25, r0 + 0.45, it))
	if skip:
		coil = 0.0
	# (04:00 11-07) the chest's -65 deg coil twist carried the helm round to its right with it, so
	# it looked away from the hero just as it gathered: the neck takes the twist back out
	if glare != null and _player != null:
		glare.weight = coil if OS.get_environment("KNIGHT_NOGLARE") == "" else 0.0   # env: the before
		glare.target = _player.global_position + Vector3.UP * 1.5
	var rest := _lerp_pose(_lerp_pose(base, INTRO_REST, dormant), _intro_coil_pose(), 0.85 * coil)
	rest = _lerp_pose(rest, CROUCHED, 0.35 * follow)
	_pose = _lerp_pose(rest, _intro_roar_pose(), up)
	# (06:00 11-07) the straight lerp coil -> roar cut the late heave across the chest (shaft 0.39
	# toward the front at up ~0.6): bow the path out round the right side while it rises, the
	# shaft held further round (yaw) and the hands carried out to the right, gone again at the top
	# (10:00 11-10) the round-the-side terms belong to the rise: they faded back in as `up` began to
	# fall and were then cut at ROAR_END, a ~9 deg one-tick jump of the shaft; they now fade out
	# before the glaive starts down (HEAVE_CUT=1 = the old hard cut)
	var rise_w := 1.0 - smoothstep(BossIntro.ROAR_END - HEAVE_FADE - 0.2, BossIntro.ROAR_END - HEAVE_FADE, it)
	if OS.has_environment("HEAVE_CUT"):   # env: the before
		rise_w = 1.0 if it < BossIntro.ROAR_END else 0.0
	if rise_w > 0.0 and not skip:
		var bulge := sin(PI * clampf(up, 0.0, 1.0)) * smoothstep(0.2, 0.6, up) * rise_w
		_pose[0] = float(_pose[0]) - HEAVE_ROUND_YAW * bulge
		_pose[2] = (_pose[2] as Vector3) + Vector3(-HEAVE_ROUND_OUT * bulge, 0.0, 0.0)
		if OS.get_environment("HEAVE_NOLIFT") == "":   # env: the before
			var lift := sin(PI * clampf(up, 0.0, 1.0)) * rise_w
			_pose[1] = float(_pose[1]) + HEAVE_LIFT * lift
			# the stood-up shaft put the butt (right) fist back behind the hip where the arm lagged
			# off the haft (grip gap 0.106 at up ~0.4): the hold point comes forward while it stands
			_pose[2] = (_pose[2] as Vector3) + Vector3(0.0, 0.0, HEAVE_FWD * lift)
			_pose[5] = float(_pose[5]) - HEAVE_REACH_IN * lift
	# the follow-through brings the glaive down on the right, beside the helm, not past the visor
	var down_side := sin(PI * clampf((it - (BossIntro.ROAR_END - 0.3)) / (BossIntro.T - BossIntro.ROAR_END + 0.1), 0.0, 1.0))
	var ffwd := -0.08 if OS.has_environment("FOLLOW_BACK") else FOLLOW_FWD   # env: the before
	var fright := FOLLOW_RIGHT
	var freach := FOLLOW_REACH
	if OS.has_environment("FOLLOW_WIDE"):   # env: the before (left grip past its reach, the glaive stalled)
		fright = 0.32
		freach = 0.0
	if OS.has_environment("FOLLOW_TRY"):    # env: "right,reach" tuning
		var ft := OS.get_environment("FOLLOW_TRY").split_floats(",")
		fright = ft[0]
		freach = ft[1]
	_pose[2] = (_pose[2] as Vector3) + Vector3(-fright * down_side, 0.0, ffwd * down_side)
	_pose[5] = float(_pose[5]) + freach * down_side
	_pose[0] = float(_pose[0]) - 22.0 * down_side
	_pose[1] += sin(it * 38.0) * 2.0 * roar + sin(it * 7.0) * 1.5 * dormant
	# head: bowed asleep, lifts onto the hero (a slight overshoot back as it locks on), dips in the
	# gather, flung back in the roar with a shaking roll, comes down onto the hero first
	var bow := 0.62 * dormant - 0.08 * sin(PI * clampf((it - 1.6) / 0.9, 0.0, 1.0)) + 0.16 * gather \
		- (0.62 if OS.get_environment("ROAR_NOFLING") != "" else ROAR_HEAD_BACK) * roar + 0.14 * follow
	var roll := 0.07 * sin(it * 29.0) * roar + 0.05 * sin(it * 1.7) * dormant
	if head != null:
		# the head leads the body: a quicker follow in the roar than in the wake
		var kh := 1.0 - exp(-(9.0 + 9.0 * roar) * delta)
		_head_bow = lerpf(_head_bow, bow, kh)
		_head_roll = lerpf(_head_roll, roll, kh)
		head.bow = _head_bow
		head.roll = _head_roll
	intro_bow_peak = maxf(intro_bow_peak, _head_bow)
	intro_lift_back = minf(intro_lift_back, _head_bow)
	# chest: hunched asleep, coiled forward in the gather, thrown back in the roar. The bend is
	# mostly in the spine (the back arches, the shoulders go back over planted hips and legs);
	# only a little is the whole-body tilt about the feet, which tipped the legs with it
	var lean := 0.1 * dormant + 0.08 * gather - 0.07 * up - 0.03 * roar + 0.06 * follow \
		+ 0.012 * sin(it * 47.0) * roar
	var arch := 0.14 * dormant + 0.2 * gather - 0.44 * up - 0.14 * roar + 0.1 * follow \
		+ 0.02 * sin(it * 41.0) * roar
	_intro_arch = lerpf(_intro_arch, arch, 1.0 - exp(-14.0 * delta))
	_pose_arch(_intro_arch)
	# the glaive goes back with the chest in the heave and the roar (the hands would otherwise
	# be left reaching for a haft the arched shoulders have pulled away from); asleep and in the
	# gather it stays where it is, the point in the turf / drawn low
	_pose = _arch_pose(_pose, _intro_arch * ROAR_CARRY * up)
	if OS.has_environment("INTRO_DBG") and it > 3.8:
		print("KI t %.3f up %.2f ds %.2f fol %.2f arch %.3f pose %s gap %s" % [it, up, down_side, follow, _intro_arch, str(_pose), str(fist_gap)])
	intro_arch_peak = minf(intro_arch_peak, _intro_arch)
	intro_hunch_peak = maxf(intro_hunch_peak, _intro_arch)
	# legs: knees soft asleep, deep in the gather, straight in the heave, a settle dip after
	var sink := 0.06 * dormant + 0.2 * gather + 0.07 * settle
	_set_tuck(0.12 * dormant + 0.42 * gather + 0.14 * settle, 0.24 * dormant + 0.84 * gather + 0.28 * settle)
	intro_gather_peak = maxf(intro_gather_peak, sink)
	# both boots stay where they stand through the hunch, the gather's crouch and the heave back
	# (the lean tips the model about its root and the knees bend: without the pin the boots
	# swept ~0.2 m per size across the turf); a skip eases the crouch out over planted boots too.
	# Latched: the slump from the stance it stood in and the squaring-up turn keep the boots on
	# the spot; in the hand-off they let go in two settle steps onto the guard stance
	_plant(1.0 - smoothstep(BossIntro.T - 0.55, BossIntro.T - 0.1, it))
	if tuck != null:
		tuck.latch = true
	var ember := 0.35 + 0.9 * wake + 5.0 * up + 0.6 * sin(it * 23.0) * up
	_update_glint(0.0)
	if not has_meta("roared") and it >= r0 + 0.3:
		set_meta("roared", true)
		roared.emit(global_position + Vector3.UP * 1.6 * size_scale)
		ImpactFX.spawn(get_parent(), global_position + Vector3.UP * 0.1, Vector3.UP, "dirt", 1.4 + 0.3 * size_scale)
		if _player != null:
			_player.add_shake(0.5)
	if _wield != null:
		_wield.position.y = -sink
	return [Vector3.ZERO, lean, sink, ember]

## (11-10 01:00) the freed left hand is nowhere near the haft: the same-tick fist pass lets it go.
func _fist_aim_weight(side: int) -> float:
	return 1.0 - smoothstep(0.0, 0.15, free_l) if side == 1 else 1.0

## The glaive placed from its pose; with `free_l` the left hand lets go and is flung up and out
## to the left (the glaive then rides the right hand alone, the shaft along the pose's direction)
func _place(pose: Array) -> void:
	# the fist-on-haft fit chases a shaft the free hand is nowhere near: it starts clean on the regrip
	if free_l > 0.02 and _fist_off.size() > 1:
		_fist_off[1] = Vector3.ZERO
	# (11-07) the freed left hand clenches into a real fist (the haft grip left a hollow in it, the
	# fingers half open against the sky); it opens back to the grip before it closes on the haft
	if hand_rest != null:
		hand_rest.clench_l = 0.0 if OS.get_environment("ROAR_OPENFIST") != "" else smoothstep(0.25, 0.8, free_l)
		# the hand on the helm stays cupped (the grip's curl), not a fist
		if _crown_reel:
			hand_rest.clench_l = 0.0
	# (11-10) the freed hand leaves the haft: GripRoll lets it go (it would roll it back round the shaft)
	if grip_roll != null:
		grip_roll.side_weight[1] = 1.0 - smoothstep(0.0, 0.15, free_l)
	super._place(_arm_bent(pose))
	if KPLACE_DBG and intro_playing():
		print("KPLACE t %.3f up %.3f pose %s shR %s shL %s over %.3f %.3f off %.1f slid %s" % [_intro_it, _heave_now, str(pose), str(_sh_real[1]), str(_sh_real[0]), clamp_over[0], clamp_over[1], axis_off, str(slid)])
	if free_l <= 0.001 or spear == null or _grip_l == null:
		return
	var f := free_l * free_l * (3.0 - 2.0 * free_l)
	var slide: float = pose[4] if pose.size() > 4 else 0.0
	var d := StaffCombat.dir_of(pose[0], pose[1])
	var d2 := spear.transform.basis.y.normalized().slerp(d, f).normalized()
	var hr := _grip_r.position - fist_shift[0]
	spear.transform = Transform3D(Basis(Quaternion(Vector3.UP, d2)), hr - d2 * (HAND_R + slide))
	# (11-10) the fist fit's wrist shift lives in the spear's frame: turn it with the re-aimed glaive
	if _roll_frame:
		fist_shift[0] = spear.basis * _fist_off[0]
		_grip_r.position = hr + fist_shift[0]
	var tw := deg_to_rad(pose[3])
	if _crown_reel:
		var helm := _helm_point()
		if helm != Vector3.INF:
			# out round the pauldron and up the side of the helm, never across the visor; on the way
			# in the eased flight (overshoot + settle), on the way back the release's smoothstep
			var g := clutch_flight if clutch_flight != clutch else f
			_grip_l.position = _grip_l.position.lerp(helm, g) + Vector3(0.14, 0.04, 0.06) * sin(PI * clampf(g, 0.0, 1.0))
			if OS.has_environment("CLUTCH_FLY_DBG"):
				print("FLY u %.3f g %.3f target %s palm-helm %.3f" % [t / CROWN_STAGGER, g, str(_grip_l.position), _palm_gap(helm)])
			if f > 0.95:
				clutch_gap = minf(clutch_gap, _palm_gap(helm))
				var u := t / CROWN_STAGGER
				if u > 0.32 and u < 0.44:
					clutch_settled_gap = maxf(clutch_settled_gap, _palm_gap(helm))
			return
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	# the arched chest carries the shoulder back with it; the arm is thrown up from there (the
	# direction is not arched with it, or the fist ends level with the helm, lost behind the hood)
	var b := Basis(Vector3.RIGHT, _intro_arch * ROAR_CARRY)
	var fling := SPINE_BASE + b * (sl - SPINE_BASE) \
		+ ROAR_FLING_DIR.normalized().rotated(Vector3.UP, tw) * ROAR_FLING_REACH
	# the shaking roar runs through the free arm too
	fling += Vector3(0.0, 0.025 * sin(_intro_it * 31.0), 0.0) * f
	# the fist travels from the haft (on its right) over to its left: bowed up and back over the
	# helm on the way, never across the front of the visor
	_grip_l.position = _grip_l.position.lerp(fling, f) + Vector3(0.0, 0.12, -0.2) * sin(PI * f)

## (11-10 03:00) the helm's left temple in the Wield's space (body space, unscaled), off the head
## bone as last posed (bowed and rolled by HeadBow), INF without a skeleton
func _helm_point() -> Vector3:
	if head == null or _wield == null or head.head_world == Vector3.INF:
		return Vector3.INF
	return _wield.to_local(head.head_world) + CLUTCH_AT

## (05:00 11-11) the knight's reach clamp measures from its REAL shoulders. The shared body
## model (SHOULDER (+-0.21, 1.48, -0.06) turned by the chest twist, tipped with the lean) is the
## hero's: the knight's shoulder joints sit ~0.1 higher (y 1.50-1.61 in the Wield's space), move
## with the clip, the hip lean and the head bow, and its chest's yaw runs the other way to `tw`
## (bot `foefold`, env FOEFOLD_TICKS_L). Every knight pose's clamp was measured from points up to
## ~0.2 m off. The arm-IK shoulders as last posed (skeleton_updated, after every modifier; one
## tick behind, which the clip's slow sway does not feel) are read back here into the Wield's
## space. NOT LIVE YET: the knight's poses were solved against the old model, so with the real
## shoulders the clamp bites where it never did (thrust 11.6, stomp 13.7, sweep 10.1 deg off the
## pose) and the leap's arms still lock straight (0.98-0.996 of the chain). The poses must be
## re-solved against these shoulders first (PROGRESS.md Next). env SHOULDER_MODEL_REAL=1 opts in.
## (11-11 06:00) the knight's own guard, re-solved against its REAL shoulders (bot `knightguard`,
## mean over the idle's sway R (-0.205, 1.578, -0.033), L (0.248, 1.583, 0.062) in the Wield's
## space): the shared GUARD put the right grip 0.52-0.54 m from it (reach 0.45), so the clamp bent
## the glaive 11.7 deg off the pose. The same shaft line (yaw 43.2, pitch 32.8) moved 0.047 m toward
## the right shoulder (right grip 0.48, left 0.37 m) with a reach of 0.58 (the elbows keep a bend:
## the chain is 0.547 and the grip sits ~0.05 past the wrist). env KGUARD_OLD=1: the shared guard.
const KNIGHT_GUARD := [43.2, 32.8, Vector3(0.326, 1.534, 0.522), 6.0, 0.0, 0.58]
## (11-11 08:00) LIVE: GL frames of the reveal coil/heave looked at with and without (both fists
## on the haft, no fist through the helm); env SHOULDER_MODEL_OLD=1 = the old SHOULDER model
static var SHOULDER_MODEL_REAL := OS.get_environment("SHOULDER_MODEL_OLD") == ""
static var KPLACE_DBG := OS.has_environment("KPLACE_DBG")   # env: per-tick reveal pose + clamp (tuning)
var _sh_real := [Vector3.INF, Vector3.INF]
var _sh_bones := [-1, -1]
func _record_shoulders() -> void:
	if _wield == null or not is_instance_valid(_wield):
		return
	if _sh_bones[0] < 0:
		_sh_bones = [skel.find_bone("mixamorig_LeftArm"), skel.find_bone("mixamorig_RightArm")]
		if _sh_bones[0] < 0 or _sh_bones[1] < 0:
			return
	var gt := skel.global_transform
	var wi := _wield.global_transform.affine_inverse()
	for i in 2:
		_sh_real[i] = wi * (gt * skel.get_bone_global_pose(_sh_bones[i]).origin)

## (11-11) with the real shoulders the knight slides its grips back inside reach along the pose's
## line instead of letting the clamp bend the glaive (env REACH_SLIDE_OFF=1: the clamp alone)
static var REACH_SLIDE_OFF := OS.has_environment("REACH_SLIDE_OFF")
func _reach_slide_on() -> bool:
	return SHOULDER_MODEL_REAL and not REACH_SLIDE_OFF and _sh_real[0] != Vector3.INF

## (11-11 09:00) the ember leap (and the sweep) kept the soldiers' / sentinel's reach (0.60-0.66),
## so with the real shoulders the reach slide held the grips 0.58-0.64 m out and the arm chain
## (0.547, the grip ~0.05 past the wrist) locked straight: sweep L 0.991 (S t=0.08), leap L 0.996
## (bot `foefold`). In the leap's flight and landing the knight's reach is capped at KNIGHT_ARM_BEND, so the slide
## draws both grips in along the pose's line and the elbows keep a bend; the glaive keeps its
## direction. The leap's crouch is capped softer (0.58): it draws the grips in already, and at
## 0.52-0.56 the slide shoved them onto the left shoulder (arm folded to 0.139-0.171 m/size).
## Result: leap R 0.958 -> 0.901, L 0.996 -> 0.922. NOT the sweep (live: L 0.991): capped at
## 0.52 its left arm bends (0.958) but the forearm then passes along the haft and GripRoll flips
## the hand round it twice (0.6 rad a tick, `foegrip` 2.19 rad); 0.54: 0.961 / 0.74 rad reversing
## roll (old 0.08); 0.55+: the arm locks again (0.974+). The sweep needs sweep_pose re-solved
## against the real shoulders instead (PROGRESS.md Next). env ARMBEND_SWEEP=x opts the sweep in.
## env ARMBEND_OLD=1: the before; env ARMBEND_REACH / ARMBEND_CROUCH=x: tuning.
const KNIGHT_ARM_BEND := 0.52
static var ARMBEND_OLD := OS.has_environment("ARMBEND_OLD")
static var ARMBEND_REACH := float(OS.get_environment("ARMBEND_REACH")) if OS.has_environment("ARMBEND_REACH") else KNIGHT_ARM_BEND
static var ARMBEND_SWEEP := float(OS.get_environment("ARMBEND_SWEEP")) if OS.has_environment("ARMBEND_SWEEP") else 0.0
const KNIGHT_ARM_BEND_CROUCH := 0.58
static var ARMBEND_CROUCH := float(OS.get_environment("ARMBEND_CROUCH")) if OS.has_environment("ARMBEND_CROUCH") else KNIGHT_ARM_BEND_CROUCH
## (11-11 10:00) The knight's own sweep, re-solved against its real shoulders: the shared pose's
## reach (SWEEP_ARM 0.6) let the reach slide park the left grip 0.55 m from the left shoulder through
## the whole coil and the first tenth of the cut, on an arm of 0.547 (straightness 0.98-0.99, locked
## like a rod across the chest). The reach is now KNIGHT_SWEEP_REACH 0.46 while the blade is on the
## knight's right (bearing < -20 deg), eased back to 0.6 by +40 deg, so the slide draws both grips in
## along the glaive's own line and the left elbow keeps a bend: L 0.991 -> 0.923, hand roll chatter
## unchanged (no reversals). 0.50 leaves the cut's first ticks locked (the shoulders unwind faster
## than the one-tick-old reading) and flips the left hand off the haft (0.075 m); 0.44 crushes the
## right arm toward FOEFOLD_MIN (0.184). env KSWEEP_OLD=1: the
## shared HollowSoldier.sweep_pose; env KSWEEP_TRY="twistk,cap,dx,dy,dz,w0,w1" for tuning (offset in
## Wield space, weighted in over blade bearings w0..w1 degrees).
const KNIGHT_SWEEP_REACH := 0.46
static var KSWEEP_OLD := OS.has_environment("KSWEEP_OLD")
static var KSWEEP_P: PackedFloat64Array = PackedFloat64Array(Array(OS.get_environment("KSWEEP_TRY").split(",")).map(func(x): return float(x))) if OS.has_environment("KSWEEP_TRY") else PackedFloat64Array([0.3, KNIGHT_SWEEP_REACH, 0.0, 0.0, 0.0, -20.0, 40.0])
func _sweep_pose(a: float) -> Array:
	var p := HollowSoldier.sweep_pose(a)
	if KSWEEP_OLD or not _reach_slide_on():
		return p
	var k := KSWEEP_P
	p[3] = a * k[0]
	var w := 1.0 - smoothstep(k[5], k[6], a) if k[5] < k[6] else 1.0
	p[2] = (p[2] as Vector3) + Vector3(k[2], k[3], k[4]) * w
	if k[1] > 0.0:
		p[5] = lerpf(p[5], minf(p[5], k[1]), w)
	return p

func _arm_bent(pose: Array) -> Array:
	if ARMBEND_OLD or not _reach_slide_on() or pose.size() < 6:
		return pose
	var cap := ARMBEND_REACH
	if move_kind == LEAP_MOVE and state == WINDUP:
		# the crouch draws the grips in already: capped as hard as the rest it folds the left arm
		# shut (0.139 m/size, the slide shoves both grips onto the left shoulder)
		cap = ARMBEND_CROUCH
	elif move_kind == SWEEP_MOVE and state in [WINDUP, STRIKE, RECOVER] and ARMBEND_SWEEP > 0.0:
		cap = ARMBEND_SWEEP
	elif not (move_kind == LEAP_MOVE and state in [STRIKE, RECOVER]):
		return pose
	if pose[5] <= cap:
		return pose
	var p := pose.duplicate()
	p[5] = cap
	return p

func _shoulders(tw: float) -> Array:
	if not SHOULDER_MODEL_REAL or _sh_real[0] == Vector3.INF:
		return super._shoulders(tw)
	return [_sh_real[0], _sh_real[1], true]

## (11-10 06:00) HeadBow now runs before the arm IK: the left hand as finally posed is read here
## (skeleton_updated runs inside the pass, after every modifier)
func _record_left_hand() -> void:
	if head == null:
		return
	var b := skel.find_bone("mixamorig_LeftHand")
	if b >= 0:
		head.hand_l_world = skel.global_transform * skel.get_bone_global_pose(b).origin

## (bots) the left wrist's distance from the helm point, in the Wield's space (m per size)
func _palm_gap(helm: Vector3) -> float:
	if head == null or head.hand_l_world == Vector3.INF:
		return 9.0
	return _wield.to_local(head.hand_l_world).distance_to(helm)

## (11-10) one-handed (the roar's freed left): GripRoll eases out, the old fit holds the right.
## The reveal keeps the old fit throughout: switching mid-roar left the old fit overshooting
## every tick (right fist 0.16-0.22 m per size off the haft); see PROGRESS.md Next.
## (11-10 07:00) The surge keeps GripRoll through its roar (it lets the freed left go on its own,
## side_weight): the switch to the old fit as the left let go threw the right fist 0.31 m per size
## off the glaive for a tick and 0.12-0.29 for ten more, and the left came back onto the haft
## 0.11 off as GripRoll took over again in the settle (bot surgegrip; env SURGE_ROLLOFF: before).
func _grip_roll_wanted() -> bool:
	if _surge >= 0.0 and OS.get_environment("SURGE_ROLLOFF") == "":
		return true
	return free_l < 0.02 and not intro_playing()

## Swing a glaive pose about the spine's base by `a` rad about the body's right (back = negative),
## as the arched chest carries the hands: both the hold point and the shaft's direction turn.
static func _arch_pose(pose: Array, a: float) -> Array:
	if absf(a) < 0.0005:
		return pose
	var b := Basis(Vector3.RIGHT, a)
	var c: Vector3 = pose[2]
	var d := b * StaffCombat.dir_of(pose[0], pose[1])
	var out := pose.duplicate()
	out[2] = SPINE_BASE + b * (c - SPINE_BASE)
	out[0] = rad_to_deg(atan2(d.x, d.z))
	out[1] = rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
	return out

## The reveal's spine bend through the joint layer (the soldier's stagger Crumple, idle outside a
## stagger). It runs before the arm IK, so the hands stay closed on the glaive as the chest moves.
func _pose_arch(a: float) -> void:
	if crumple == null or (state == STAGGER and _reel_layer_on()):
		return
	if absf(a) < 0.002 and not (move_kind == INTRO_MOVE and state == WINDUP):
		if _intro_arched:
			crumple.spine = 0.0
			crumple.active = false
			_intro_arched = false
		return
	crumple.active = true
	crumple.spine = a
	_intro_arched = true

## The stomp: weight over onto the left leg as the right knee comes up to the chest, held
## there shuddering with the ember flaring (the tell), the boot driven down, the ground wave.
func _stomp_tick(delta: float, to: Vector3) -> Array:
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	var lift := 0.0
	var shift := 0.0
	var pin := 1.0
	match state:
		WINDUP:
			var hold := STOMP_RAISE_T + STOMP_HOLD_T
			# it keeps turning onto the hero while the knee comes up, not once it hangs there
			if t < STOMP_RAISE_T:
				_turn_to(to, delta, 4.0)
			var u := smoothstep(0.0, STOMP_RAISE_T, t)
			# the weight goes over onto the standing boot first, the knee follows it up
			shift = smoothstep(0.0, STOMP_RAISE_T * 0.6, t)
			lift = smoothstep(STOMP_RAISE_T * 0.2, STOMP_RAISE_T, t)
			# up a touch onto the standing leg and back over it, the glaive drawn in
			lean = -0.12 * u
			sink = -0.04 * u
			_pose = _lerp_pose(_from, guard_pose, u)
			var shud := smoothstep(STOMP_RAISE_T * 0.8, STOMP_RAISE_T, t)
			lift += 0.03 * sin(t * 47.0) * shud
			ember = 1.0 + 3.0 * u
			if t >= hold:
				_resolved = false
				strikes += 1
				_from = _pose
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / STOMP_T, 0.0, 1.0)
			# driven down: accelerating, the body following it over and down
			lift = 1.0 - u * u
			# the weight rides over to the falling boot as it comes down (half of it by contact)
			shift = 1.0 - 0.5 * u * u
			lean = lerpf(-0.12, 0.16, u)
			sink = lerpf(-0.04, 0.12, u * u)
			ember = 4.0 + 2.0 * u
			if u >= 1.0:
				if not _resolved:
					_resolved = true
					_stomp_land()
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / STOMP_RECOVER_T, 0.0, 1.0)
			var f := smoothstep(0.3, 1.0, u)
			# the jolt comes up through it (a small bounce off the stamped leg), then it settles
			lean = 0.16 * (1.0 - f)
			sink = 0.12 * (1.0 - f) + 0.03 * sin(PI * clampf(u / 0.3, 0.0, 1.0))
			ember = 6.0 - 5.0 * f
			# the rest of the weight settles back between the boots in the first third
			shift = 0.5 * (1.0 - smoothstep(0.0, 0.35, u))
			# the boots let go to the clip as the lean and sink run out
			pin = 1.0 - smoothstep(0.7, 1.0, u)
			if u >= 1.0:
				_enter(STALK)
	if tuck != null:
		tuck.lift_leg = 1
		tuck.lift_hip = STOMP_HIP * lift
		tuck.lift_knee = STOMP_KNEE * lift
		tuck.shift = 0.0 if OS.get_environment("STOMP_NOSHIFT") != "" else shift
		tuck.pin = 0.0 if OS.get_environment("STOMP_NOPIN") != "" else pin
		tuck.latch = false
		tuck.latch_body = false
	if _wield != null:
		_wield.position.y = -sink
	return [Vector3.ZERO, lean, sink, ember]

func stomp_foot() -> Vector3:
	var p := body.to_global(STOMP_FOOT)
	p.y = _ground(p)
	return p

## The boot hits the ground: the shockwave runs out from it; in phase 3 the ground it stamped
## stays on fire.
func _stomp_land() -> void:
	stomps += 1
	_stomp_cool = STOMP_COOL
	var at := stomp_foot()
	var k := size_scale / growth.scale_of(1)
	stomped.emit(at)
	ImpactFX.spawn(get_parent(), at + Vector3.UP * 0.1, Vector3.UP, "dirt", 2.0 + 0.3 * size_scale)
	if _player != null:
		_player.add_shake(0.5 + 0.08 * size_scale)
	var w := Shockwave.new()
	w.source = self
	w.player = _player
	w.terrain = _terrain_ref
	w.max_r = STOMP_R * size_scale
	w.speed = STOMP_SPEED * sqrt(size_scale) * tempo
	w.damage = STOMP_DAMAGE * damage_mul
	w.ember = phase >= 3
	get_parent().add_child(w)
	w.global_position = at
	w.passed.connect(func(r: String) -> void:
		stomp_results.append(r)
		last_result = r
		struck.emit(r))
	last_wave = w
	if phase >= 3:
		var sc := Scorch.new()
		sc.size_k = k
		sc.hazard_t = HAZARD_T
		sc.player = _player
		sc.source = self
		get_parent().add_child(sc)
		sc.global_position = at
		last_hazard = sc

## Plant both boots (LegTuck.pin) through a move that leans or sinks the model from the hips.
## Env PLANT_NOPIN=1 = the before (bots compare).
func _plant(w: float) -> void:
	if tuck != null:
		tuck.lift_hip = 0.0
		tuck.lift_knee = 0.0
		tuck.shift = 0.0
		tuck.pin = 0.0 if OS.get_environment("PLANT_NOPIN") != "" else w
		tuck.latch = false
		tuck.latch_body = false

func _set_tuck(h: float, k: float) -> void:
	if tuck != null:
		tuck.hip = h
		tuck.knee = k

## The landing's weight bottoms out in the boots: soil and torn turf kicked out low round each one
## (away from the body, along the turf), and the stems pressed flat under and round them.
func _boot_kick() -> void:
	if OS.get_environment("LEAPKICK_OFF") == "1" or tuck == null:
		return
	boot_kick_at = []
	var tr := get_parent().get_node_or_null("Trample")
	var k := size_scale / growth.scale_of(1)
	for i in 2:
		var a: Variant = tuck.ankle(i)
		var p := global_position + body.global_basis * Vector3(0.16 * (1.0 if i == 0 else -1.0), 0.0, 0.0)
		# the ankles as last posed; a stale spot (no skeleton update since it moved) falls back
		# to under the hips, a boot's width to each side
		if a != null and Vector2((a as Vector3).x - global_position.x, (a as Vector3).z - global_position.z).length() < 1.0 * size_scale:
			p = a as Vector3
		var ground := Vector3(p.x, global_position.y, p.z)
		var out := ground - global_position
		out.y = 0.0
		out = out.normalized() if out.length() > 1e-3 else -body.global_transform.basis.z
		# thrown out low along the turf, a little forward with the lunge
		var dir := (out + Vector3.UP * 0.15).normalized()
		ImpactFX.spawn(get_parent(), ground + Vector3.UP * 0.05, dir, "turf", 0.9 * k)
		# the dust rolls out over the grass tops, not inside the sward
		ImpactFX.spawn(get_parent(), ground + Vector3.UP * 0.45, dir, "stamp", 1.4 * k)
		boot_kick_at.append(ground)
		boot_kicks += 1
		if tr != null and tr.has_method("add_herd_point"):
			var d2 := Vector2(out.x, out.z)
			tr.add_herd_point(Vector2(ground.x, ground.z), d2, 1.0, 0.0, 0.2, 0.0)
			tr.add_herd_point(Vector2(ground.x, ground.z) + d2 * 0.35 * size_scale, d2, 1.0, 0.0, 0.2, 0.0)
	if _player != null:
		_player.add_shake(0.12 + 0.03 * size_scale)

## The hero stands in the blade's line ahead of the landing, or inside LEAP_R of the bite.
func _in_leap_reach() -> bool:
	if _player == null:
		return false
	var b := leap_bite()
	var d := _player.global_position - b
	if Vector2(d.x, d.z).length() < LEAP_R * _reach_k() and absf(d.y) < 1.6 * _reach_k():
		return true
	var l := _hero_local()
	return l.z > 0.3 and l.z < LEAP_BITE + 0.75 and absf(l.x) < 0.8 and absf(l.y) < 1.4

func _resolve_leap() -> void:
	var r := "miss"
	var b := leap_bite()
	if _player != null and not _player.is_dead() and (_aimed or _in_leap_reach()):
		r = _player.receive_attack(self, LEAP_DAMAGE * damage_mul, true, true)
		if r == "hit":
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 0.9, Vector3.DOWN, "stone", 1.2)
	if _player != null:
		_player.add_shake(0.55 + 0.08 * size_scale)
	ImpactFX.spawn(get_parent(), b + Vector3.UP * 0.1, Vector3.DOWN, "dirt", 1.8 + 0.3 * size_scale)
	# the ember-hot edge scorches the turf where it bit: a burnt star with glowing cracks
	var sc := Scorch.new()
	sc.size_k = size_scale / growth.scale_of(1)
	get_parent().add_child(sc)
	sc.global_position = b
	last_scorch = sc
	# the ember shakes loose as the blade bites: a ring of fire flares up round the impact
	# (11-11) the ring is phased so the gap between two flames faces back at the knight: the old
	# phase (+0.3 rad) stood one flame ~1 m off its own boots (inside the flame's radius), so the
	# giant landed in its own fire and the flame hid the boots' dust kick
	last_ring = []
	var back := body.rotation.y + PI
	if OS.get_environment("RING_OLD") == "1":
		back = body.rotation.y + 0.3 - TAU * 0.5 / 5.0
	for i in 5:
		var a := back + TAU * (i + 0.5) / 5.0
		var f := _flame_at(b + Vector3(sin(a), 0, cos(a)) * 1.5 * _reach_k(), false)
		f.t = AshFlame.WARN - 0.02
		last_ring.append(f)
	last_result = r
	leap_results.append(r)
	leap_landed.emit(b, r)
	struck.emit(r)
