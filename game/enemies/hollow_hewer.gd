class_name HollowHewer
extends HollowSoldier
## Hollow Hewer, the axe variant: a Hollow that was a woodcutter and still carries its long
## felling axe, the helve gripped in both hands. Rule changes against the spear soldier:
##  CHOP. Instead of the thrust it heaves the axe up overhead (the raise), holds it there for a
##    beat that is never the same length (HITCH_MIN..HITCH_MAX, trembling, still turning to
##    follow the hero), and only then does the glint run up the bit: the chop comes down fast
##    on the glint, not on the raise. A roll on the raise is spent before the axe falls. The
##    chop throws the hero down and hits harder than anything a soldier swings; it can be
##    parried (the staff's raise turns the helve) or dodged on the glint.
##  HEAVY HAFT. Nothing short of a poise break stops the raise once it starts: light strikes
##    into it only feed its poise, so a string thrown at the raise eats the chop.
##  BITE. A chop that misses buries the bit in the turf: the hewer stays bent over the stuck
##    axe for STUCK_T while it wrenches it free -- the big punish window.
## Crowded inside the axe's reach (or after two chops) it swings the soldier's low flat cut
## instead, the axe head leading the arc.

const HEWER_HP := 125.0
const HEWER_POISE := 46.0
const CHOP_MOVE := 2
const RAISE_T := 0.62            # s to heave the axe overhead
const HITCH_MIN := 0.12          # s it holds the axe up before the glint (random each chop)
const HITCH_MAX := 0.62
const GLINT_T := 0.28            # s of glint before the axe falls
const CHOP_T := 0.24
const CHOP_AT := 0.55            # normalised strike time the chop resolves
const CHOP_REACH := 2.55         # hero centre this far ahead (body space) when the bit lands
const CHOP_HALF := 0.8           # half-width of the chop's line
const CHOP_LUNGE := 0.75
const CHOP_DAMAGE := 32.0
const STUCK_T := 0.75            # s the bit stays buried after the chop
const FREE_T := 0.7              # s to wrench it free and come back to guard
const AXE_SCALE := 1.35          # the felling axe scaled up to a long two-hand helve (~1 m)
const HEW_SWEEP_REACH := 1.9   # the axe's flat cut reaches ~0.7 m less than the spear's
const AXE_GRIP := HAND_R - 0.08  # the knob 8 cm below the rear hand, on the spear's axis

# axe poses in body space: [yaw°, pitch°, haft centre, twist°, slide, reach]
const HEW_GUARD := [10.0, 22.0, Vector3(0.06, 1.32, 0.62), 4.0, 0.0, 0.48]
const RAISED := [-4.0, 104.0, Vector3(-0.02, 2.24, -0.12), -12.0, 0.0, 0.52]
const CHOPPED := [0.0, -52.0, Vector3(0.0, 0.62, 1.0), 8.0, 0.0, 0.58]

## the axe heaved overhead (foley: a slow heavy whoosh and a grunt of effort)
signal raised(point: Vector3)
## the chop lands or misses: result is receive_attack's ("hit", "dodged", "perfect",
## "parried", "miss"); point is where the bit came down
signal chopped(point: Vector3, result: String)

var axe: Axe
var chops := 0
var chop_hits := 0
var bites := 0                   # chops that buried the bit (missed)
var raise_hits := 0              # blows taken during the raise that did not stop it
var last_hitch := 0.0
var _chops_in_row := 0
var _hitch := 0.3
var _bitten := false
var _bite_at := Vector3.ZERO
var _lead := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	health_max = HEWER_HP
	health = HEWER_HP
	poise_max = HEWER_POISE
	guard_pose = HEW_GUARD
	engage_delay = 0.35
	sweep_reach = HEW_SWEEP_REACH
	super._ready()
	name = "HollowHewer"
	_rng.seed = 7311
	# a paler, wood-ash grey, the rags a faded moss-brown woodsman's smock
	_set_skin("ash_light", Color(0.40, 0.38, 0.35))
	rags.set_param("cloth_dark", Color(0.075, 0.08, 0.05))
	rags.set_param("cloth_light", Color(0.27, 0.27, 0.18))
	# the spear's shaft stays as the invisible rig the hands IK to; the axe rides on it
	spear.visible = true
	spear.mesh = null
	axe = Axe.new()
	axe.name = "Axe"
	spear.add_child(axe)
	_place(guard_pose)

## The hero woke at the rest point: the hewer stands at its post with the axe pulled free.
func return_to_post() -> void:
	super.return_to_post()
	_bitten = false
	_chops_in_row = 0
	_pose = guard_pose

func _choose(dist: float) -> int:
	var k := force_move
	if k < 0:
		# crowded inside the axe's reach, or tired of chopping with the hero close enough for the cut
		k = SWEEP_MOVE if dist < sweep_reach or (_chops_in_row >= 2 and dist < sweep_reach + SWEEP_STEP * 0.5) else CHOP_MOVE
	if k == SWEEP_MOVE:
		_chops_in_row = 0
	else:
		_bitten = false
		_hitch = _rng.randf_range(HITCH_MIN, HITCH_MAX)
		last_hitch = _hitch
		raised.emit(_head())
	return k

func _head() -> Vector3:
	if axe == null:
		return global_position + Vector3.UP * 2.2
	return axe.to_global(Vector3(0, Axe.HEAD_Y, Axe.EDGE_Z))

## True while the axe is buried in the turf after a missed chop (bots, foley).
func stuck() -> bool:
	return state == RECOVER and move_kind == CHOP_MOVE and _bitten and t < STUCK_T

func raising() -> bool:
	return state == WINDUP and move_kind == CHOP_MOVE

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	if raising():
		# HEAVY HAFT: the whole raise is armoured, not just its back two thirds
		var t0 := t
		var st0 := staggers
		t = maxf(t, WINDUP_T)
		super.take_hit(point, dir, power, hitstop)
		if state == WINDUP:
			t = t0
			if staggers == st0:
				raise_hits += 1
		return
	super.take_hit(point, dir, power, hitstop)

## The chop, run through the soldier's WINDUP/STRIKE/RECOVER states.
func _special_tick(delta: float, to: Vector3, dist: float) -> Array:
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var total := RAISE_T + _hitch + GLINT_T
			var r := clampf(t / RAISE_T, 0.0, 1.0)
			# keeps turning to follow the hero through the raise and the hold, commits on the glint
			var g := clampf((t - RAISE_T - _hitch) / GLINT_T, 0.0, 1.0)
			_turn_to(to, delta, 5.0 * (1.0 - g))
			var held := RAISED.duplicate()
			held[1] = RAISED[1] + sin(t * 41.0) * 1.2 * smoothstep(0.8, 1.0, r)
			_pose = _lerp_pose(_from, held, r)
			lean = -0.12 * smoothstep(0.0, 1.0, r)
			sink = 0.04 * r
			ember = 1.0 + 1.2 * r + 2.2 * g
			_update_glint(smoothstep(0.0, 0.4, g) * (1.0 - smoothstep(0.9, 1.0, g)))
			if t >= total:
				_resolved = false
				_aimed = _in_chop_line()
				strikes += 1
				chops += 1
				_chops_in_row += 1
				_from = _pose
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / CHOP_T, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(RAISED, CHOPPED, minf(u * 1.5, 1.0) * minf(u * 1.5, 1.0))
			lean = -0.12 + 0.52 * smoothstep(0.0, 0.6, u)
			sink = 0.04 + 0.2 * smoothstep(0.2, 0.7, u)
			ember = 4.0 - 1.2 * u
			move = body.global_basis.z * (CHOP_LUNGE / CHOP_T) * 2.0 * (1.0 - u) * clampf((dist - 0.9) / 0.4, 0.0, 1.0)
			if not _resolved and u >= CHOP_AT:
				_resolved = true
				_resolve_chop()
			if u >= 1.0:
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var stuck_t := STUCK_T if _bitten else 0.15
			if t < stuck_t:
				# bent over the buried bit, wrenching at the helve
				var w := sin(t * 23.0) * 2.0 * float(_bitten)
				var p := CHOPPED.duplicate()
				p[0] = CHOPPED[0] + w
				p[3] = CHOPPED[3] - w
				_pose = p
				lean = 0.4
				sink = 0.24
				ember = 1.5
			else:
				var u := clampf((t - stuck_t) / FREE_T, 0.0, 1.0)
				_pose = _lerp_pose(CHOPPED, guard_pose, u)
				lean = 0.4 * (1.0 - smoothstep(0.0, 0.9, u))
				sink = 0.24 * (1.0 - u)
				ember = 1.4 - 0.4 * u
				if u >= 1.0:
					_bitten = false
					_enter(STALK)
	return [move, lean, sink, ember]

func _in_chop_line() -> bool:
	if _player == null:
		return false
	var l := _hero_local()
	return l.z > 0.0 and l.z < CHOP_REACH + 0.35 and absf(l.x) < CHOP_HALF and absf(l.y) < 1.4

## The bit comes down on the line ahead; a hero who was in the line on the glint and is
## mid-dodge gets the dodge verdict. A miss (or a dodge) buries the bit in the turf.
func _resolve_chop() -> void:
	var r := "miss"
	if _player != null and (_aimed or _in_chop_line()):
		r = _player.receive_attack(self, CHOP_DAMAGE * damage_mul, true, unblockable)
		if r == "hit":
			chop_hits += 1
			_player.add_shake(0.4)
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.0, -body.global_basis.y + body.global_basis.z * 0.3, "stone", 1.0)
	_bitten = r != "hit" and r != "parried"
	var at := global_position + body.global_basis.z * 1.55
	var terr := get_parent().get_node_or_null("Terrain")
	if terr != null and terr.has_method("height_at"):
		at.y = terr.height_at(at.x, at.z)
	_bite_at = at
	if _bitten:
		bites += 1
		# the bit bites into the turf: clods and dust kicked forward, splinters off the helve
		ImpactFX.spawn(get_parent(), at + Vector3.UP * 0.05, Vector3.UP + body.global_basis.z * 0.5, "dirt", 1.5)
		ImpactFX.spawn(get_parent(), at + Vector3.UP * 0.25, Vector3.DOWN + body.global_basis.z * 0.4, "wood", 0.6)
	last_result = r
	chopped.emit(at, r)
	struck.emit(r)

## The axe rides the invisible shaft: knob below the rear hand, helve along the shaft, the bit
## turned to lead the swing (down and forward in the chop's plane, round the arc in a sweep).
func _place(pose: Array) -> void:
	super._place(pose)
	if axe == null:
		return
	var d := spear.transform.basis.y.normalized()
	var lead := Vector3.UP.cross(d) if (move_kind == SWEEP_MOVE and state in [WINDUP, STRIKE, RECOVER]) else Vector3.RIGHT.cross(d)
	lead = lead - d * lead.dot(d)
	if lead.length() < 1e-3:
		lead = Vector3.FORWARD
	lead = lead.normalized()
	# the bit turns round the helve smoothly when the swing changes plane
	_lead = lead if _lead == Vector3.ZERO else _lead.slerp(lead, 0.3).normalized()
	lead = (_lead - d * _lead.dot(d)).normalized()
	var x := d.cross(lead).normalized()
	var b := Basis(x, d, lead).scaled(Vector3.ONE * AXE_SCALE)
	var w := Transform3D(b, spear.transform * Vector3(0, AXE_GRIP, 0))
	axe.transform = spear.transform.affine_inverse() * w
	if _glint != null and _glint.visible:
		_glint.global_position = _head()

func _update_glint(a: float) -> void:
	super._update_glint(a)
	if _glint != null and axe != null:
		_glint.global_position = _head()
