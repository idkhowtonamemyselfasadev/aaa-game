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

## woke: the first shudder (foley: stone grinding)
signal awakened(at: Vector3)
## a blow on its front only chipped the stone
signal chipped(point: Vector3)
## stood still at its post again
signal petrified

var dormant := true
var waking := -1.0               # s into the wake, -1 when not waking
var wakes := 0
var chips := 0
var full_hits := 0
var petrifies := 0
var armour: KnightArmour
var _home_yaw := 0.0
var _grit: CPUParticles3D

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
	awakened.emit(global_position)

func _enter(s: int) -> void:
	if s == STALK and dormant:
		wake()
		return
	super._enter(s)

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
