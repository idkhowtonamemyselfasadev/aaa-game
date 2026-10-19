class_name HenFeed
extends Node3D
## Edda feeding the hens over the garth wall: she stands outside the east wall with a linen
## grain bag hung at her right hip, dips her hand into it, draws it up to her chest and casts
## the handful out over the wall in a low forward sweep. The grain flies in a fan and patters
## down inside the yard (Hens.scatter), where the hens come running for it. Six casts, then she
## stands and watches them at it. Drives her right arm through `weight` (0 arm free .. 1 in the
## cast), `arm` and `elbow` (Crumple.flick_arm / flick_elbow).

signal scattered(at: Vector3)

const CAST_T := 2.6              # s per handful: dip, draw up, cast, back
const CASTS := 6
const RELEASE := 0.56            # point in the cycle the hand opens
## Where the handfuls land, in the stone cottage's frame: the open garth inside the east wall,
## clear of the hen house (west) and the gateway's swing.
const LAND := Vector2(2.0, -8.0)
const LAND_R := Vector2(0.8, 0.9)
## The arm through a cast: [cycle point, upper arm forward, elbow bend]
const KEYS := [
	[0.0, 0.18, 0.75],    # hand in the bag at the hip
	[0.28, 0.2, 0.8],
	[0.46, 0.25, 1.5],    # drawn up, fist to the chest
	[0.6, 1.35, 0.12],    # cast out over the wall
	[0.72, 1.1, 0.25],
	[1.0, 0.18, 0.75],
]

var villager: Villager
var hens: Hens
var bag: MeshInstance3D
var casts := 0                   # handfuls thrown (bots)
var weight := 0.0
var arm := 0.18
var elbow := 0.75
var lean := 0.0                  # a little into the cast

var _t := -1.0                   # time into this feed (negative: not at it)
var _grain: CPUParticles3D
var _rng := RandomNumberGenerator.new()

func setup(v: Villager, h: Hens) -> void:
	villager = v
	hens = h
	_rng.seed = 909
	top_level = true
	global_transform = Transform3D.IDENTITY
	bag = MeshInstance3D.new()
	bag.name = "GrainBag"
	bag.mesh = build_bag()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.50, 0.45, 0.36)
	m.roughness = 0.95
	m.vertex_color_use_as_albedo = true
	bag.material_override = m
	# hung from her girdle at the right hip (the body faces +z, her right is -x)
	bag.position = Vector3(-0.2, 0.84, 0.07)
	bag.rotation = Vector3(0.12, 0.3, -0.08)
	bag.visible = false
	v.body.add_child(bag)
	_grain = CPUParticles3D.new()
	_grain.name = "Grain"
	_grain.emitting = false
	_grain.one_shot = true
	_grain.amount = 40
	_grain.lifetime = 0.9
	_grain.explosiveness = 0.85
	_grain.spread = 16.0
	_grain.flatness = 0.55
	_grain.initial_velocity_min = 3.0
	_grain.initial_velocity_max = 4.6
	_grain.gravity = Vector3(0, -9.8, 0)
	_grain.damping_min = 0.4
	_grain.damping_max = 1.2
	_grain.angular_velocity_min = -720.0
	_grain.angular_velocity_max = 720.0
	_grain.particle_flag_rotate_y = true
	_grain.mesh = Hens.grain_mesh()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Hens.GRAIN_COL
	gm.roughness = 0.6
	_grain.material_override = gm
	add_child(_grain)

## A small linen bag gathered at the neck by a cord, slumped and full: a lathe of rings
## pulled by lumps of grain inside, the cloth creased in toward the neck. Vertex colour
## shades the creases and the cord.
static func build_bag() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 14
	var segs := 16
	# profile: [height, radius] from the bottom up to the frill above the cord
	var prof := [[0.0, 0.0], [0.012, 0.05], [0.04, 0.085], [0.08, 0.098], [0.12, 0.094], [0.155, 0.08],
		[0.185, 0.055], [0.205, 0.03], [0.215, 0.02], [0.222, 0.019], [0.232, 0.024], [0.245, 0.034],
		[0.255, 0.038], [0.26, 0.03]]
	var lump := FastNoiseLite.new()
	lump.seed = 31
	lump.frequency = 2.2
	var pts: Array = []
	for i in rings:
		var row: Array = []
		var h: float = prof[i][0]
		var r: float = prof[i][1]
		for j in segs + 1:
			var a := TAU * j / segs
			var crease := 0.0
			if h > 0.15:
				crease = 0.25 * smoothstep(0.15, 0.21, h) * absf(sin(a * 4.0 + h * 9.0))
			var rr := r * (1.0 + 0.12 * lump.get_noise_3d(cos(a), h * 4.0, sin(a)) - crease)
			# the full bag slumps toward its front-bottom
			var sag := 0.02 * (1.0 - smoothstep(0.0, 0.12, h))
			row.append(Vector3(cos(a) * rr, h - 0.26, sin(a) * rr + sag))
		pts.append(row)
	for i in rings - 1:
		for j in segs:
			var q := [pts[i][j], pts[i][j + 1], pts[i + 1][j + 1], pts[i + 1][j]]
			var hh: float = prof[i][0]
			var shade := 0.45 if hh > 0.2 and hh < 0.235 else 1.0     # the cord
			var a := TAU * (j + 0.5) / segs
			var cr := 1.0 - 0.3 * smoothstep(0.15, 0.2, hh) * absf(sin(a * 4.0 + hh * 9.0))
			st.set_color(Color(shade * cr, shade * cr, shade * cr * 0.97))
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[k])
	st.generate_normals()
	return st.commit()

## Runs the casts while she stands at the wall (`working`); eases the arm free otherwise.
func update(delta: float, working: bool, carrying_bag: bool) -> void:
	if bag != null:
		bag.visible = carrying_bag
	if not working:
		_t = -1.0
		weight = move_toward(weight, 0.0, delta / 0.5)
		lean = move_toward(lean, 0.0, delta)
		return
	if _t < 0.0:
		_t = 0.0
	var t0 := _t
	_t += delta
	var n := floori(_t / CAST_T)
	var busy := n < CASTS
	weight = move_toward(weight, 1.0 if busy else 0.0, delta / 0.5)
	if not busy:
		lean = move_toward(lean, 0.0, delta)
		return
	var u := fmod(_t, CAST_T) / CAST_T
	var u0 := fmod(t0, CAST_T) / CAST_T
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if u >= a[0] and u <= b[0]:
			var e := smoothstep(0.0, 1.0, (u - a[0]) / (b[0] - a[0]))
			arm = lerpf(a[1], b[1], e)
			elbow = lerpf(a[2], b[2], e)
			break
	lean = 0.12 * smoothstep(0.4, 0.6, u) * (1.0 - smoothstep(0.7, 1.0, u))
	if u0 < RELEASE and u >= RELEASE and floori(t0 / CAST_T) == n:
		_cast()

func _cast() -> void:
	casts += 1
	var hand := villager.hand_mark.global_position
	var lw := LAND + Vector2(_rng.randf_range(-LAND_R.x, LAND_R.x), _rng.randf_range(-LAND_R.y, LAND_R.y))
	var to := hens.cottage.to_global(Vector3(lw.x, 0, lw.y))
	var flat := Vector3(to.x - hand.x, 0, to.z - hand.z)
	_grain.global_position = hand
	# a little above the flat line, so the fan arcs over the wall's copes
	_grain.direction = (flat.normalized() + Vector3.UP * 0.55).normalized()
	_grain.restart()
	hens.scatter(to, flat.length(), hand)
	scattered.emit(hand)
