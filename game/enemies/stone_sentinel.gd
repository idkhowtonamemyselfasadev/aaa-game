class_name StoneSentinel
extends HollowSoldier
## Stone Sentinel, a shrine guard: an old guardian statue of a glaive-bearer in a closed helm,
## carved from grey granite, crusted with lichen and moss, with a pale rune set in its chest.
## Rule changes against the spear soldier:
##  STATUE. It stands at its post as a statue does: no breath, no sway, the rune dark. Only
##    when the hero comes inside WAKE_R (much closer than a Hollow notices) or strikes it does
##    it wake: a grinding shudder, grit shaking off its shoulders and the rune kindling over
##    WAKE_T, before it turns and comes on. Walk past at a distance and it never stirs.
##  STONE SKIN. Blows on its front chip the granite (FRONT_MUL of the damage, a dull spark):
##    the hero has to get round it (a dodge past the slow glaive) or catch it in the long
##    recovery after a blow, when the whole body is open.
##  STONE WEIGHT. It is slow (TEMPO) but every blow lands harder (DAMAGE_MUL); a poise break
##    needs a lot of staff.
##  GLAIVE SLAM. Its own move, every third attack or when the hero hangs back out of glaive
##    reach: it heaves the glaive overhead in both hands, holds it there with the rune blazing
##    and grit sifting off the arms (the glint runs up the blade in the hold), then brings it
##    straight down into the turf SLAM_Z ahead. The blade throws down anyone under it (a parry
##    turns it); the ground splits in a star of cracks and a shock runs out as a ring of dust to
##    GroundCrack.RING_R, throwing down a hero standing anywhere in it. Jump the ring, roll
##    through it, or be out of reach. The glaive stays bitten in the turf for a long, open
##    recovery: the best punish the statue ever gives.
##  MENDING. If the hero runs, it walks back to its post, turns to its old facing and stands
##    still again, the cracks closing: back at full strength, a statue once more.

const SENTINEL_HP := 210.0
const SENTINEL_POISE := 58.0
const WAKE_R := 6.0
const WAKE_T := 1.5              # s from the first shudder to the first step
const FRONT_MUL := 0.3           # damage and poise a blow on the front does
const TEMPO := 0.82
const DAMAGE_MUL := 1.35
const MEND_RATE := 60.0          # hp/s while it stands at its post again
const RUNE := Color(0.55, 0.82, 1.0)
const SLAM_MOVE := 2
const SLAM_RAISE_T := 0.8        # brain-time s to heave the glaive overhead (x 1/TEMPO real)
const SLAM_HOLD_T := 0.38        # held overhead, the glint running up the blade
const SLAM_T := 0.26
const SLAM_AT := 0.62            # normalised strike time the blade meets the turf
const SLAM_RECOVER_T := 1.7      # bitten in the turf, then wrenched free
const SLAM_Z := 1.75             # m ahead of the feet where the glaive comes down
const SLAM_HALF := 0.75          # half-width of the blade's line
const SLAM_DAMAGE := 30.0
const SLAM_ENGAGE := 4.6         # a hero hanging back inside this (but past ENGAGE) gets the slam
const SLAM_SQUARE := 0.7        # brain-time s it squares up to a hero hanging back before it heaves
const SLAM_EVERY := 2            # attacks between slams when the hero keeps close
# glaive poses in body space: [yaw°, pitch°, centre, twist°, slide, reach] (solved offline:
# hands inside arm reach, the blade up and back over the helm / its edge in the turf ahead)
const HEAVED := [-10.0, 108.0, Vector3(0.0, 2.5, -0.05), -8.0, 0.1, 0.64]
const SLAMMED := [-7.0, -31.0, Vector3(0.0, 1.05, 0.92), 5.0, 0.12, 0.65]

## woke: the first shudder (foley: stone grinding)
signal awakened(at: Vector3)
## a blow on its front only chipped the stone
signal chipped(point: Vector3)
## stood still at its post again
signal petrified
## the glaive heaved overhead (foley: a slow heavy whoosh, stone grinding)
signal heaved(point: Vector3)
## the glaive came down: point where it bit the turf, result the blade's verdict on the hero
signal slammed(point: Vector3, result: String)
## the shock ring reached (or missed) the hero: hit / perfect / dodged / jumped / miss
signal shock(result: String)

var dormant := true
var waking := -1.0               # s into the wake, -1 when not waking
var wakes := 0
var chips := 0
var full_hits := 0
var petrifies := 0
var armour: KnightArmour
var _home_yaw := 0.0
var _grit: CPUParticles3D
var _terrain: Terrain
var slams := 0
var slam_hits := 0
var last_crack: GroundCrack
var ring_results: Array[String] = []
var _since_slam := 0

func _ready() -> void:
	health_max = SENTINEL_HP
	health = SENTINEL_HP
	poise_max = SENTINEL_POISE
	tempo = TEMPO
	damage_mul = DAMAGE_MUL
	notice = WAKE_R
	give_up = 18.0
	glint_col = Color(0.8, 0.92, 1.0)
	super._ready()
	name = "StoneSentinel"
	impact_kind = "stone"
	model.scale = Vector3(1.12, 1.14, 1.12)
	_model_rest = model.transform
	_set_skin("stone", 1.0)
	_set_skin("ember_col", RUNE)
	_ember_light.light_color = RUNE
	_ember_light.omni_range = 2.2
	_dress()
	_grit = _make_grit()
	body.add_child(_grit)

## Statues wear no cloth: the rags come off; a granite helm and pauldrons go on, and the glaive
## (head and shaft) is stone too.
func _dress() -> void:
	for att in skel.get_children():
		if att is BoneAttachment3D:
			for mi in att.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).material_override in rags.mats:
					mi.visible = false
	rags.set_process(false)
	rags.set_physics_process(false)
	armour = KnightArmour.new()
	armour.name = "Armour"
	add_child(armour)
	armour.build(skel, body)
	armour.fit_glaive(spear, HollowSpear.LENGTH * 0.5 - HollowSpear.BLADE)
	_mats.append_array(armour.mats)
	_set_skin("stone", 1.0)
	_set_skin("heat", 0.0)
	spear.material_override = armour.mats[0]

func _make_grit() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Grit"
	p.emitting = false
	p.one_shot = true
	p.amount = 90
	p.lifetime = 1.6
	p.explosiveness = 0.55
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.32, 0.55, 0.22)
	p.position = Vector3(0, 1.35, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var q := SphereMesh.new()
	q.radius = 0.012
	q.height = 0.02
	q.radial_segments = 6
	q.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.35, 0.32)
	m.roughness = 1.0
	q.material = m
	p.mesh = q
	return p

func plant(terrain: Terrain) -> void:
	super.plant(terrain)
	_terrain = terrain
	_home_yaw = body.rotation.y

func face(point: Vector3) -> void:
	super.face(point)
	_home_yaw = body.rotation.y

func return_to_post() -> void:
	super.return_to_post()
	if state == DEAD:
		return
	body.rotation.y = _home_yaw
	body.position = Vector3.ZERO
	waking = -1.0
	dormant = true

## Begin waking (the hero came close or struck it).
func wake() -> void:
	if not dormant or state == DEAD:
		return
	dormant = false
	waking = 0.0
	wakes += 1
	state = STALK
	t = 0.0
	_grit.restart()
	_grit.emitting = true
	GroundCrack.crack_texture()     # build the crack star now, inside the wake, not at the first slam
	awakened.emit(global_position)

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if state == DEAD:
		return
	var open := state == RECOVER or state == STAGGER
	if dormant or waking >= 0.0 or (not open and _hero_in_front()):
		chips += 1
		ImpactFX.spawn(get_parent(), point, dir, "stone", 0.7)
		chipped.emit(point)
		if dormant:
			wake()
		# a blow on the stone face barely tells; it never staggers a waking statue
		if waking >= 0.0:
			hits_taken += 1
			health = maxf(health - DMG_PER_POWER * power * FRONT_MUL, 1.0)
			_freeze = hitstop * 0.5
			_flash = 0.3
			return
		power *= FRONT_MUL
	else:
		full_hits += 1
	super.take_hit(point, dir, power, hitstop)

# --- the glaive slam ---

## Every SLAM_EVERY-th attack is the slam (the hero cannot read it by distance alone).
func _choose(dist: float) -> int:
	if force_move == SLAM_MOVE or (force_move < 0 and _since_slam >= SLAM_EVERY):
		_since_slam = 0
		return SLAM_MOVE
	_since_slam += 1
	return super._choose(dist)

## A hero hanging back just out of glaive reach does not get to wait it out: once the statue
## has squared up for a moment it heaves the glaive and sends the shock out to them.
func _stalk(to: Vector3, dist: float) -> Vector3:
	if dist > ENGAGE and dist < SLAM_ENGAGE and (force_move < 0 or force_move == SLAM_MOVE):
		# stone does not chase a hero dancing at the edge of its reach: it plants and squares up
		if t > SLAM_SQUARE and _facing(to) > 0.9:
			windups += 1
			_from = _pose
			_since_slam = 0
			move_kind = SLAM_MOVE
			_enter(WINDUP)
		return Vector3.ZERO
	return super._stalk(to, dist)

func _enter(s: int) -> void:
	if s == STALK and dormant:
		wake()
		return
	if s == WINDUP and move_kind == SLAM_MOVE:
		_aimed = false
		heaved.emit(global_position + Vector3.UP * 2.4)
	super._enter(s)

func _special_tick(delta: float, to: Vector3, dist: float) -> Array:
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var hold_at := SLAM_RAISE_T
			var u := clampf(t / hold_at, 0.0, 1.0)
			var h := clampf((t - hold_at) / SLAM_HOLD_T, 0.0, 1.0)
			# squares up while heaving, then commits: the hold no longer turns
			_turn_to(to, delta, 4.0 * (1.0 - u * u))
			var heave := _lerp_pose(_from, HEAVED, u)
			# a straining tremble in the hold
			heave[1] += sin(t * 41.0) * 1.2 * h
			_pose = heave
			lean = -0.12 * smoothstep(0.0, 1.0, u) - 0.03 * h
			sink = 0.06 * u
			ember = 1.0 + 3.6 * smoothstep(0.2, 1.0, u) + 0.6 * h
			_update_glint(smoothstep(0.0, 0.35, h) * (1.0 - smoothstep(0.85, 1.0, h)))
			if h > 0.55 and _in_slam_line():
				_aimed = true
			if h >= 1.0:
				_resolved = false
				strikes += 1
				slams += 1
				_from = _pose
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / SLAM_T, 0.0, 1.0)
			_update_glint(0.0)
			_pose = _lerp_pose(HEAVED, SLAMMED, minf(u / SLAM_AT, 1.0))
			lean = lerpf(-0.15, 0.32, smoothstep(0.0, SLAM_AT, u))
			sink = lerpf(0.06, 0.22, smoothstep(0.0, SLAM_AT, u))
			ember = 4.6 - 1.6 * u
			move = body.global_basis.z * 1.6 * (1.0 - u) * clampf((dist - 1.1) / 0.5, 0.0, 1.0)
			if not _resolved and u >= SLAM_AT:
				_resolved = true
				_resolve_slam()
			if u >= 1.0:
				_from = _pose
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / SLAM_RECOVER_T, 0.0, 1.0)
			# bitten in the turf for half the recovery, then a heave and back to guard
			var f := smoothstep(0.5, 1.0, u)
			_pose = _lerp_pose(SLAMMED, guard_pose, f)
			lean = 0.32 * (1.0 - f) - 0.08 * sin(PI * f)
			sink = 0.22 * (1.0 - f)
			ember = 1.5 - 0.5 * u
			if u >= 1.0:
				_enter(STALK)
	return [move, lean, sink, ember]

## The hero stands in the line the blade comes down on.
func _in_slam_line() -> bool:
	if _player == null:
		return false
	var l := _hero_local()
	return l.z > 0.3 and l.z < SLAM_Z + 0.75 and absf(l.x) < SLAM_HALF and absf(l.y) < 1.3

## Where the glaive bites: SLAM_Z ahead, on the turf.
func slam_point() -> Vector3:
	var p := global_position + body.global_basis.z * SLAM_Z
	if _terrain != null:
		p.y = _terrain.height_at(p.x, p.z)
	return p

## The blade lands on a hero in its line (heavy: thrown down; a parry turns it and there is
## no shock at all); then the ground splits and the shock runs out.
func _resolve_slam() -> void:
	var r := "miss"
	if _player != null and not _player.is_dead() and (_aimed or _in_slam_line()):
		r = _player.receive_attack(self, SLAM_DAMAGE * damage_mul, true, false)
		if r == "hit":
			slam_hits += 1
			ImpactFX.spawn(get_parent(), _player.global_position + Vector3.UP * 0.9, -body.global_basis.y, "stone", 1.1)
	last_result = r
	var at := slam_point()
	if r != "parried":
		ImpactFX.spawn(get_parent(), at + Vector3.UP * 0.1, Vector3.DOWN, "dirt", 1.6)
		var c := GroundCrack.new()
		c.source = self
		c.player = _player
		c.terrain = _terrain
		c.spare_player = r == "hit"
		get_parent().add_child(c)
		c.global_position = at
		c.rotation.y = body.rotation.y
		c.rang.connect(func(res: String) -> void:
			ring_results.append(res)
			shock.emit(res))
		last_crack = c
		if _player != null:
			var d := (_player.global_position - at).length()
			_player.add_shake(0.55 * clampf(1.0 - d / 12.0, 0.0, 1.0))
	slammed.emit(at, r)
	struck.emit(r)

func _hero_in_front() -> bool:
	if _player == null:
		return true
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.length() < 1e-3 or body.global_basis.z.dot(to.normalized()) > 0.2

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as Player
	if state == DEAD:
		super._physics_process(delta)
		return
	if waking >= 0.0:
		_wake_tick(delta)
		return
	super._physics_process(delta)
	if state == DEAD:
		return
	if state == IDLE:
		var back := _home - global_position
		back.y = 0.0
		if back.length() <= 0.6:
			# home: turn back to the old facing, mend, and go still
			body.rotation.y = lerp_angle(body.rotation.y, _home_yaw, 1.0 - exp(-2.5 * delta))
			health = move_toward(health, health_max, MEND_RATE * delta)
			if not dormant and absf(angle_difference(body.rotation.y, _home_yaw)) < 0.05 and health >= health_max:
				dormant = true
				petrifies += 1
				petrified.emit()
		if dormant:
			if anim_tree:
				anim_tree.set("parameters/speed/scale", 0.0)
			_set_skin("ember", 0.0)
			_ember_light.light_energy = 0.0

func _wake_tick(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_set_skin("hit_flash", _flash)
	waking += delta
	var u := clampf(waking / WAKE_T, 0.0, 1.0)
	# a grinding shudder that dies away as the stone comes loose, the rune kindling
	var shake := 0.018 * (1.0 - smoothstep(0.5, 1.0, u))
	body.position = Vector3(sin(waking * 61.0) * shake, 0.0, cos(waking * 47.0) * shake * 0.7)
	if _player != null:
		var to := _player.global_position - global_position
		to.y = 0.0
		_turn_to(to, delta, 2.2 * smoothstep(0.35, 1.0, u))
	_place(guard_pose)
	_lean(0.08 * (1.0 - u), 0.04 * sin(PI * u))
	var rune := 1.6 * smoothstep(0.15, 0.8, u) + 0.8 * sin(PI * u)
	max_ember = maxf(max_ember, rune)
	_set_skin("ember", rune)
	_set_skin("root_pos", global_position)
	_set_skin("root_fwd", body.global_basis.z)
	_ember_light.light_energy = 0.3 * rune
	if anim_tree:
		anim_tree.set("parameters/speed/scale", smoothstep(0.55, 1.0, u))
	if u >= 1.0:
		waking = -1.0
		body.position = Vector3.ZERO
		t = 0.0
