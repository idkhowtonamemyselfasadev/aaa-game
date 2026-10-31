class_name HollowWarden
extends HollowSoldier
## Hollow Warden, the shield variant: a soldier that kept its targe. The round hide-and-iron
## shield is strapped to its left forearm and it fights with the spear in both hands behind it,
## the guard drawn in closer and higher than a soldier's so the board covers the chest.
## Rule change against the plain soldier:
##  WARD. While it waits or stalks, any blow from in front of it lands on the targe: a dull
##    thunk of wood and iron, splinters, no harm done, and it answers quickly. Each blocked blow
##    adds its power to a guard meter (draining slowly); a heavy (power >= GUARD_BREAK) or a
##    blocked blow that fills the meter knocks the targe aside: the warden reels open for
##    BROKEN_T and the arm hangs low for WARD_DOWN, the window to punish. Its own wind-up,
##    strike and recovery are open like a soldier's (dodge its thrust, then hit), and blows
##    from the side or back always land.
## It holds the ward WARD_HOLD s in reach before it commits (sooner after a blocked blow).
## Same thrust/sweep tells as the soldier; a little slower on its feet, a little more health.

const WARDEN_HP := 110.0
const WARDEN_POISE := 36.0
const GUARD_BREAK := 1.75        # a hit this strong goes through the targe (the heavies)
const GUARD_MAX := 3.5           # blocked power that breaks the ward (a full three-blow string)
const GUARD_DRAIN := 0.5         # meter per second
const BROKEN_T := 1.5            # s the warden reels after the ward breaks
const WARD_DOWN := 2.6           # s the targe hangs low after a break
const WARD_HOLD := 1.5          # s it holds its ward in reach before it winds up
const FRONT := 0.25              # cos of the half-angle the targe covers
# the warden's guard: spear drawn in and up, the left forearm (and the targe) across the chest
const WARD := [20.0, 8.0, Vector3(0.14, 1.22, 0.62), 10.0]

## a blow turned on the targe (foley: a wooden thunk with iron in it)
signal shield_blocked(point: Vector3)
## the targe knocked aside (foley: a heavier crack and a body thump)
signal shield_broken(point: Vector3)

var guard := 0.0
var blocks := 0
var guard_breaks := 0
var targe: HollowTarge
var _ward_down := 0.0
var _targe_flash := 0.0
var _elbow := -1
var _hand := -1

func _ready() -> void:
	health_max = WARDEN_HP
	health = WARDEN_HP
	poise_max = WARDEN_POISE
	guard_pose = WARD
	engage_delay = WARD_HOLD
	super._ready()
	name = "HollowWarden"
	# a rustier, browner ash: an older Hollow, sooted from the fires it stood guard over
	_set_skin("ash_light", Color(0.36, 0.33, 0.30))
	rags.set_param("cloth_dark", Color(0.10, 0.085, 0.06))
	rags.set_param("cloth_light", Color(0.30, 0.25, 0.18))
	targe = HollowTarge.new()
	targe.name = "Targe"
	add_child(targe)
	if skel != null:
		_elbow = skel.find_bone("mixamorig_LeftForeArm")
		_hand = skel.find_bone("mixamorig_LeftHand")
		skel.skeleton_updated.connect(_fit_targe)
	_fit_targe()

## Strap the targe to the left forearm as posed this frame: the board's face square to the
## warden's front (tilted a little outward to its left), centred a little below mid-forearm.
func _fit_targe() -> void:
	if targe == null or not is_instance_valid(targe):
		return
	if skel == null or _elbow < 0 or _hand < 0:
		targe.global_transform = body.global_transform * Transform3D(Basis(), Vector3(0.25, 1.15, 0.45))
		return
	var e := skel.global_transform * skel.get_bone_global_pose(_elbow).origin
	var h := skel.global_transform * skel.get_bone_global_pose(_hand).origin
	var a := h - e
	if a.length() < 1e-3:
		return
	a = a.normalized()
	var fwd := body.global_basis.z
	var left := body.global_basis.x
	var n := (fwd + left * 0.3)
	n = (n - a * n.dot(a))
	if n.length() < 1e-3:
		n = left
	n = n.normalized()
	var x := a.cross(n).normalized()
	var c := e.lerp(h, 0.42)
	# hanging low after a break: the board swings down and out off the arm
	var droop := clampf(_ward_down / WARD_DOWN, 0.0, 1.0)
	var b := Basis(x, a, n)
	if droop > 0.0:
		b = Basis(x, -0.7 * droop) * b
	targe.global_transform = Transform3D(b, c + n * 0.055)

func _physics_process(delta: float) -> void:
	guard = maxf(guard - GUARD_DRAIN * delta, 0.0)
	if _ward_down > 0.0:
		_ward_down = maxf(_ward_down - delta * tempo, 0.0)
	if _targe_flash > 0.0:
		_targe_flash = maxf(_targe_flash - delta * 4.0, 0.0)
		targe.set_param("hit_flash", _targe_flash)
	super._physics_process(delta)

## Whether a blow from the hero would land on the targe now.
func warding() -> bool:
	if state != IDLE and state != STALK:
		return false
	return _ward_down <= 0.0 and _hero_in_front()

func _hero_in_front() -> bool:
	if _player == null:
		return true
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.length() < 1e-3 or body.global_basis.z.dot(to.normalized()) > FRONT

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	if warding():
		impact_kind = "wood"
		_targe_flash = 1.0
		if power >= GUARD_BREAK or guard + power >= GUARD_MAX:
			_break_ward(point, dir, power, hitstop)
			return
		guard += power
		blocks += 1
		_freeze = hitstop * 0.5
		lean_kick = 0.05 + 0.03 * power
		shield_blocked.emit(point)
		if _player != null:
			_player.add_shake(0.2)
		# the turned blow opens the hero up: it answers quickly
		if state == STALK:
			t = maxf(t, WARD_HOLD - 0.35)
		elif state == IDLE:
			_enter(STALK)
		return
	impact_kind = "stone"
	super.take_hit(point, dir, power, hitstop)

## The targe is knocked aside: half the blow still tells, the warden reels wide open and its
## shield arm hangs low for a while after.
func _break_ward(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	guard = 0.0
	guard_breaks += 1
	hits_taken += 1
	_ward_down = WARD_DOWN
	shield_broken.emit(point)
	if _player != null:
		_player.add_shake(0.35)
	health -= DMG_PER_POWER * power * 0.5
	_flash = 0.6
	_set_skin("hit_flash", _flash)
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 1e-3:
		d = -body.global_basis.z
	if health <= 0.0:
		_die(d.normalized())
		return
	_freeze = hitstop
	poise = 0.0
	staggers += 1
	_knock = d.normalized() * 2.2
	_from = _pose
	_stagger_len = BROKEN_T
	_recoil = 1.7
	state = STAGGER
	t = 0.0

## The hero woke at the rest point: the warden takes up its ward again.
func return_to_post() -> void:
	super.return_to_post()
	guard = 0.0
	_ward_down = 0.0

func _die(dir: Vector3) -> void:
	super._die(dir)
	# the strap burns through with the body: the targe drops and lies where it fell
	if targe != null and is_instance_valid(targe) and skel != null and skel.skeleton_updated.is_connected(_fit_targe):
		skel.skeleton_updated.disconnect(_fit_targe)
		_drop_targe()

func _drop_targe() -> void:
	var tr := targe.global_transform
	var ground := tr.origin.y - 1.0
	var terr := get_parent().get_node_or_null("Terrain")
	if terr != null and terr.has_method("height_at"):
		ground = terr.height_at(tr.origin.x, tr.origin.z)
	targe.reparent(get_parent())
	var to := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, body.rotation.y + 0.6),
			Vector3(tr.origin.x, ground + 0.03, tr.origin.z) + body.global_basis.x * 0.35)
	var tw := targe.create_tween()
	tw.tween_property(targe, "global_transform", to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
