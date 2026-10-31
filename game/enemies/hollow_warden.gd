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
##  BASH. A hero who crowds inside its ward (closer than BASH_CLOSE for BASH_CROWD s) gets the
##    targe driven into them: the shield arm coils back with the chest turned away (BASH_WINDUP_T,
##    a short scrape of wood as the tell), then a lunging shove. It cannot be parried (the
##    staff deflects a point, not a board) but it can be dodged; it does little harm and
##    staggers the hero. The recovery after it is open, so a dodged bash is a punish window.

const WARDEN_HP := 110.0
const WARDEN_POISE := 36.0
const GUARD_BREAK := 1.75        # a hit this strong goes through the targe (the heavies)
const GUARD_MAX := 3.5           # blocked power that breaks the ward (a full three-blow string)
const GUARD_DRAIN := 0.5         # meter per second
const BROKEN_T := 1.5            # s the warden reels after the ward breaks
const WARD_DOWN := 2.6           # s the targe hangs low after a break
const WARD_HOLD := 1.5          # s it holds its ward in reach before it winds up
const FRONT := 0.25              # cos of the half-angle the targe covers
const BASH_MOVE := 2
const BASH_CLOSE := 1.55         # hero closer than this (and in front) is crowding the ward
const BASH_CROWD := 0.3          # s of crowding before it bashes
const BASH_WINDUP_T := 0.5
const BASH_T := 0.2
const BASH_AT := 0.45            # normalised strike time the shove resolves
const BASH_RECOVER_T := 0.7
const BASH_REACH := 1.9          # hero centre within this, in front, when the board lands
const BASH_LUNGE := 0.75         # metres the shove carries the body
const BASH_DAMAGE := 8.0
# the bash: spear hauled back and up on the right, chest turned away so the targe coils
# behind the left shoulder; then the chest whips round and the forearm (the board) drives out
const BASH_COIL := [55.0, 14.0, Vector3(-0.12, 1.30, 0.22), -38.0]
const BASH_DRIVE := [8.0, 4.0, Vector3(0.24, 1.26, 0.78), 34.0]
# the warden's guard: spear drawn in and up, the left forearm (and the targe) across the chest
const WARD := [20.0, 8.0, Vector3(0.14, 1.22, 0.62), 10.0]

## a blow turned on the targe (foley: a wooden thunk with iron in it)
signal shield_blocked(point: Vector3)
## the targe knocked aside (foley: a heavier crack and a body thump)
signal shield_broken(point: Vector3)
## the bash coils (foley: a scrape of wood and a grunt of leather)
signal bash_windup(point: Vector3)
## the bash lands or misses: result is receive_attack's ("hit", "dodged", "perfect", "miss")
signal shield_bashed(point: Vector3, result: String)

var guard := 0.0
var blocks := 0
var guard_breaks := 0
var targe: HollowTarge
var _ward_down := 0.0
var _targe_flash := 0.0
var bashes := 0
var bash_hits := 0
var _crowd := 0.0
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
	_watch_crowding(delta)
	super._physics_process(delta)

## A hero standing inside the ward, in front, gets the board: count how long they have crowded
## it and start the bash once that passes BASH_CROWD.
func _watch_crowding(delta: float) -> void:
	if state != STALK or _freeze > 0.0 or _player == null or _player.is_dead():
		_crowd = 0.0
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() < BASH_CLOSE and _hero_in_front():
		_crowd += delta * tempo
	else:
		_crowd = maxf(_crowd - delta * 2.0, 0.0)
	if _crowd >= BASH_CROWD or (force_move == BASH_MOVE and to.length() < BASH_CLOSE):
		_crowd = 0.0
		windups += 1
		_from = _pose
		move_kind = BASH_MOVE
		_aimed = false
		_enter(WINDUP)
		bash_windup.emit(targe.global_position if targe != null else global_position)

## The bash, run through the soldier's WINDUP/STRIKE/RECOVER states.
func _special_tick(delta: float, to: Vector3, dist: float) -> Array:
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var u := clampf(t / BASH_WINDUP_T, 0.0, 1.0)
			_turn_to(to, delta, 6.0 * (1.0 - u * u))     # squares up to the hero, then commits
			_pose = _lerp_pose(_from, BASH_COIL, minf(u * 1.8, 1.0))
			lean = -0.08 * smoothstep(0.0, 0.7, u)
			sink = 0.1 * smoothstep(0.0, 0.7, u)
			ember = 1.0 + 2.6 * smoothstep(0.2, 0.9, u)
			# a hero in reach late in the coil is "caught": a dodge from there earns the dodge
			# verdict (perfect dodges included) even once it has carried them out of reach
			if u > 0.6 and _bash_in_reach():
				_aimed = true
			if u >= 1.0:
				_resolved = false
				strikes += 1
				bashes += 1
				_from = _pose
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / BASH_T, 0.0, 1.0)
			_pose = _lerp_pose(BASH_COIL, BASH_DRIVE, minf(u * 2.4, 1.0))
			lean = 0.2 * smoothstep(0.0, 0.4, u)
			sink = 0.1
			ember = 3.6 - 1.2 * u
			# the shove carries the body on, but it stops short of walking through the hero
			move = body.global_basis.z * (BASH_LUNGE / BASH_T) * 2.0 * (1.0 - u) * clampf((dist - 0.75) / 0.4, 0.0, 1.0)
			if not _resolved and u >= BASH_AT:
				_resolved = true
				_resolve_bash()
			if u >= 1.0:
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / BASH_RECOVER_T, 0.0, 1.0)
			_pose = _lerp_pose(BASH_DRIVE, guard_pose, smoothstep(0.3, 1.0, u))
			lean = 0.2 * (1.0 - smoothstep(0.15, 0.85, u))
			sink = 0.1 * (1.0 - u)
			ember = 1.3 - 0.3 * u
			if u >= 1.0:
				_enter(STALK)
	return [move, lean, sink, ember]

func _bash_in_reach() -> bool:
	if _player == null:
		return false
	var l := _hero_local()
	return l.z > -0.1 and Vector2(l.x, l.z).length() < BASH_REACH and absf(l.x) < 0.95 and absf(l.y) < 1.2

## The board lands on a hero in front within reach. It cannot be parried; a hero who was in
## reach as it launched and is mid-dodge gets the dodge verdict (perfect dodges count).
func _resolve_bash() -> void:
	var r := "miss"
	if _player != null and (_aimed or _bash_in_reach()):
		r = _player.receive_attack(self, BASH_DAMAGE * damage_mul, false, true)
		if r == "hit":
			bash_hits += 1
			_player.add_shake(0.25)
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 1.1, body.global_basis.z, "wood", 0.6)
	last_result = r
	shield_bashed.emit(targe.global_position if targe != null else global_position, r)
	struck.emit(r)

## Whether a blow from the hero would land on the targe now.
func warding() -> bool:
	# the bash's coil keeps the board between them: a string cannot cut the bash off, a heavy can
	var coiling := state == WINDUP and move_kind == BASH_MOVE
	if state != IDLE and state != STALK and not coiling:
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
		# the turned blow opens the hero up: it answers quickly (a bash already coiling goes on)
		if state == WINDUP:
			pass
		elif state == STALK:
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
	_crowd = 0.0

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
