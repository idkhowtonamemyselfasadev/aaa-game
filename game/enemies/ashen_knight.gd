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
const LEAP_HEAVE := [-6.0, 148.0, Vector3(0.0, 2.3, -0.4), -6.0, 0.1, 0.66]
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
## how far right (body -X, unscaled m) the hands carry the glaive down the follow-through, so
## the shaft comes down beside the helm instead of standing upright in front of the face
const FOLLOW_RIGHT := 0.32
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
var tuck: LegTuck                # bends the knees in the crouch and tucks them up in the air
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
var _head_bow := 0.0
var _head_roll := 0.0
var intro_heave := 0.0           # bots: how far the roar beat raised the glaive (0..1)
var _heave_now := 0.0
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
	_lean(0.27 * down + 0.06 * hit + 0.04 * sin(u * TAU * 1.5) * hold, sink)
	# the glaive: falls a little behind the head (the hands give way), comes up with the knees
	var gp: Array = _lerp_pose(_from, CROWN_SLUMP, minf(u / 0.26, 1.0)) if u < 0.5 \
		else _lerp_pose(CROWN_SLUMP, guard_pose, smoothstep(0.58, 0.96, u))
	_place(gp)
	var e := 0.55 + 0.25 * sin(u * 60.0) * hold if u < 0.55 else lerpf(0.6, 1.8, smoothstep(0.55, 0.8, u)) - 0.6 * smoothstep(0.85, 1.0, u)
	_set_skin("ember", e)
	_ember_light.light_energy = 0.3 * e
	crown_bow_peak = maxf(crown_bow_peak, _head_bow)
	crown_sink_peak = maxf(crown_sink_peak, sink)
	crown_lift_back = minf(crown_lift_back, _head_bow)

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
	# the coil shudders harder toward the burst; the roar shakes through the arms and head
	var shud := smoothstep(0.4, SURGE_BLAST, s) * (1.0 - burst)
	var p1 := _lerp_pose(_from, SURGE_LEAN, smoothstep(0.1, 0.7, s))
	var p2 := _lerp_pose(p1, INTRO_ROAR, burst)
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
			_pose = _lerp_pose(_from, CROUCHED, smoothstep(0.0, 0.7, u))
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
				_pose = _lerp_pose(_from, LEAP_HEAVE, clampf(u / LEAP_HEAVED_U, 0.0, 1.0))
			else:
				_pose = _lerp_pose(LEAP_HEAVE, StoneSentinel.SLAMMED, smoothstep(0.0, 1.0, (u - 0.6) / 0.4))
			# knees drive up off the crouch, tucked through the top, legs reach down to land
			var k := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.72, 0.97, u))
			var c := 1.0 - smoothstep(0.0, 0.18, u)
			_set_tuck(lerpf(0.85 * c, TUCK_HIP, k), lerpf(1.6 * c, TUCK_KNEE, k) + 0.5 * smoothstep(0.9, 1.0, u))
			# pitched into the leap, then over onto the blade
			lean = lerpf(0.12, 0.34, smoothstep(0.55, 1.0, u))
			sink = -leap_lift / size_scale + 0.22 * smoothstep(0.85, 1.0, u)   # model space (scaled)
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
	intro_heave = maxf(intro_heave, up)
	# the glaive: planted point-down and leaned on (the surge's lean) while dormant, drawn low
	# and back in the gather, heaved to the sky, then down past the guard and back up into it
	var base := _lerp_pose(_from, guard_pose, smoothstep(0.0, 0.4, it))
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
	var rest := _lerp_pose(_lerp_pose(base, INTRO_REST, dormant), INTRO_COIL, 0.85 * coil)
	rest = _lerp_pose(rest, CROUCHED, 0.35 * follow)
	_pose = _lerp_pose(rest, INTRO_ROAR, up)
	# (06:00 11-07) the straight lerp coil -> roar cut the late heave across the chest (shaft 0.39
	# toward the front at up ~0.6): bow the path out round the right side while it rises, the
	# shaft held further round (yaw) and the hands carried out to the right, gone again at the top
	if it < BossIntro.ROAR_END and not skip:
		var bulge := sin(PI * clampf(up, 0.0, 1.0)) * smoothstep(0.2, 0.6, up)
		_pose[0] = float(_pose[0]) - HEAVE_ROUND_YAW * bulge
		_pose[2] = (_pose[2] as Vector3) + Vector3(-HEAVE_ROUND_OUT * bulge, 0.0, 0.0)
		if OS.get_environment("HEAVE_NOLIFT") == "":   # env: the before
			var lift := sin(PI * clampf(up, 0.0, 1.0))
			_pose[1] = float(_pose[1]) + HEAVE_LIFT * lift
			# the stood-up shaft put the butt (right) fist back behind the hip where the arm lagged
			# off the haft (grip gap 0.106 at up ~0.4): the hold point comes forward while it stands
			_pose[2] = (_pose[2] as Vector3) + Vector3(0.0, 0.0, HEAVE_FWD * lift)
			_pose[5] = float(_pose[5]) - HEAVE_REACH_IN * lift
	# the follow-through brings the glaive down on the right, beside the helm, not past the visor
	var down_side := sin(PI * clampf((it - (BossIntro.ROAR_END - 0.3)) / (BossIntro.T - BossIntro.ROAR_END + 0.1), 0.0, 1.0))
	_pose[2] = (_pose[2] as Vector3) + Vector3(-FOLLOW_RIGHT * down_side, 0.0, -0.08 * down_side)
	_pose[0] = float(_pose[0]) - 22.0 * down_side
	_pose[1] += sin(it * 38.0) * 2.0 * roar + sin(it * 7.0) * 1.5 * dormant
	# head: bowed asleep, lifts onto the hero (a slight overshoot back as it locks on), dips in the
	# gather, flung back in the roar with a shaking roll, comes down onto the hero first
	var bow := 0.62 * dormant - 0.08 * sin(PI * clampf((it - 1.6) / 0.9, 0.0, 1.0)) + 0.16 * gather \
		- 0.62 * roar + 0.14 * follow
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
	for i in 5:
		var a := TAU * i / 5.0 + body.rotation.y + 0.3
		var f := _flame_at(b + Vector3(sin(a), 0, cos(a)) * 1.5 * _reach_k(), false)
		f.t = AshFlame.WARN - 0.02
	last_result = r
	leap_results.append(r)
	leap_landed.emit(b, r)
	struck.emit(r)
