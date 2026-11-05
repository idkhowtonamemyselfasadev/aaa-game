class_name SentinelPlinth
extends Node3D
## The Stone Sentinel's post: a square two-step plinth of dressed granite the statue was set up
## on long ago, so at range it reads as a monument and not a man standing in a field. A broad
## lower course, a narrower upper course and a chamfered capstone the statue's feet stand on;
## one corner of the lower course has cracked off and lies tipped in the turf beside it, with a
## few spalls. The stones are the ruins' dressed blocks under the same weathered masonry
## material (lichen, moss, a dark crust), instanced; each course collides as one box, so the
## statue steps down off its post when it wakes and back up onto it (StepUp) to go still
## again, and the hero climbs it course by course.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 6262

const LOW_HALF := 1.2        # half-width of the lower course (m)
const LOW_DEPTH := 0.46      # how far the lower course's blocks run in from its face
const UP_HALF := 0.82        # half-width of the upper course
const CAP_HALF := 0.72       # half-width of the capstone
const STEP := 0.24           # rise of each course
const CAP := 0.12            # capstone thickness

var centre := Vector3.ZERO
var top_y := 0.0             # the capstone's top: where the statue stands (bots)
var block_count := 0
var risers: Array = []       # bots: the lower course's riser over the turf all round
var spalls := 0
var _per: Array = []
var _cut := {}          # size -> dressed block mesh cut to it
var _cut_per := {}      # size -> instances
var _terrain: Terrain
var sentinel: StoneSentinel  # world.gd: the inscription kindles with its chest rune
var rune_glow := 0.0         # 0 dark .. 1 kindled (bots)
var rune_face: MeshInstance3D
var _rune_mat: StandardMaterial3D
var _rune_light: OmniLight3D

const RUNE_W := 0.66          # the inscription band on the upper course's front face
const RUNE_H := 0.16
const RUNE_ENERGY := 2.4      # emission at full kindle (the statue's chest burns 1.6+)
## Plan of the plinth for the grass mask: centre xz, yaw; INF until built.
static var plan_centre := Vector2.INF
static var plan_yaw := 0.0
## The footing blocks' footprints in the plan's frame: [centre, half extents] (grass).
static var foot_plan: Array = []

## Lay the plinth round `c` (world), square to `yaw` (the statue's facing). Returns top_y.
func build(c: Vector3, yaw: float) -> float:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	centre = Vector3(c.x, _terrain.height_at(c.x, c.z), c.z)
	plan_centre = Vector2(c.x, c.z)
	plan_yaw = yaw
	var b := Basis(Vector3.UP, yaw)
	var meshes: Array[ArrayMesh] = ruins.block_meshes
	var dims: Array[Vector3] = ruins.block_dims
	for v in meshes.size():
		_per.append([])
	# the ground under the footprint: the base goes in below its lowest point
	var lo := INF
	var hi := -INF
	for k in 16:
		var a := TAU * k / 16.0
		for rr in [0.0, LOW_HALF, LOW_HALF * 1.42]:
			var g := _terrain.height_at(c.x + cos(a) * rr, c.z + sin(a) * rr)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	var base := lo - 0.14
	# set into the slope: the uphill edge of the lower course stands only a lip proud
	var t1 := maxf(centre.y + STEP, hi + 0.07)
	var t2 := t1 + STEP
	top_y = t2 + CAP
	# lower course: four long blocks round the square (each side split in two where the run
	# is long), run in LOW_DEPTH from the face; the corner on the statue's right-rear has
	# cracked off and lies in the turf
	var broken_side := 1
	for side in 4:
		var yaw_s := yaw + side * PI * 0.5
		var bs := Basis(Vector3.UP, yaw_s)
		var out := bs.z          # the face looks out along local +z of this side
		var along := bs.x
		var length := LOW_HALF * 2.0 - LOW_DEPTH      # corners lap: each side owns one corner
		var pieces := 2
		var y := base
		var course := 0
		while y < t1 - 0.02:
			var h := minf(0.3, t1 - y)
			var crest := y + h >= t1 - 0.02
			for i in pieces:
				var seg := length / pieces
				var s0 := -LOW_HALF + seg * (i + 0.5)
				var p := centre + out * (LOW_HALF - LOW_DEPTH * 0.5) + along * s0
				p.y = y + h * 0.5
				var tilt := Vector3.ZERO
				if crest:
					tilt = Vector3(rng.randfn() * 0.012, 0.0, rng.randfn() * 0.012)
					p.y -= absf(rng.randfn()) * 0.012     # settled treads
				var size := Vector3(seg - 0.022, h - 0.014, LOW_DEPTH)
				if crest and side == broken_side and i == pieces - 1:
					# the cracked-off corner: the block left in place is short, its piece lies below
					size.x *= 0.62
					p -= along * seg * 0.19
					_fallen_corner(centre + out * (LOW_HALF + 0.55) + along * (LOW_HALF + 0.1), yaw_s, Vector3(seg * 0.4, h, LOW_DEPTH), rng)
				_put(meshes, dims, p, bs * Basis.from_euler(tilt), size, y - centre.y, rng)
			y += h
			course += 1
	_footing(meshes, dims, base, t1, yaw)
	# the lower course's core under the upper course (hidden but keeps the tread from reading hollow)
	_put(meshes, dims, Vector3(centre.x, (base + t1) * 0.5 - 0.01, centre.z), b,
			Vector3(LOW_HALF * 2.0 - LOW_DEPTH * 2.0 + 0.02, t1 - base - 0.03, LOW_HALF * 2.0 - LOW_DEPTH * 2.0 + 0.02), 0.0, rng)
	# upper course: four blocks, one per side, lapped at the corners
	for side in 4:
		var bs := Basis(Vector3.UP, yaw + side * PI * 0.5 + rng.randfn() * 0.006)
		var p := centre + bs.z * (UP_HALF - 0.2) + bs.x * (-0.2)
		p.y = t1 + STEP * 0.5
		_put(meshes, dims, p, bs, Vector3(UP_HALF * 2.0 - 0.4 - 0.02, STEP - 0.014, 0.4), t1 - centre.y, rng)
	_put(meshes, dims, Vector3(centre.x, t1 + STEP * 0.5, centre.z), b,
			Vector3(UP_HALF * 2.0 - 0.8, STEP - 0.02, UP_HALF * 2.0 - 0.8), t1 - centre.y, rng)
	# capstone: one broad slab, a hair askew, its edge proud of the upper course
	_put(meshes, dims, Vector3(centre.x, t2 + CAP * 0.5, centre.z), b.rotated(Vector3.UP, 0.015),
			Vector3(CAP_HALF * 2.0, CAP, CAP_HALF * 2.0), t2 - centre.y, rng)
	# spalls off the broken corner and the treads' edges, half sunk in the turf
	for k in 5:
		var a := yaw + rng.randf_range(0.2, 1.5)
		var r := rng.randf_range(LOW_HALF + 0.25, LOW_HALF + 1.1)
		var q := Vector3(centre.x + sin(a) * r, 0, centre.z + cos(a) * r)
		q.y = _terrain.height_at(q.x, q.z) + 0.02
		var s := rng.randf_range(0.12, 0.26)
		_put(meshes, dims, q, Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)),
				Vector3(s, s * 0.55, s * 0.8), 0.0, rng, false)
		spalls += 1
	for v in meshes.size():
		_multimesh(meshes[v], _per[v], "Spalls_%d" % v)
	var ci := 0
	for key in _cut:
		_multimesh(_cut[key], _cut_per[key], "Plinth_%d" % ci)
		ci += 1
	_collider(base, t1, t2, yaw)
	_inscription(b, t1)
	return top_y

## Three angular runes cut into the front face of the upper course, the side the statue
## looks out over: dark grooves while it sleeps, kindling the pale blue of its chest rune
## as it wakes and going dark again when it stands still on its post once more.
func _inscription(b: Basis, t1: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(RUNE_W, RUNE_H)
	_rune_mat = StandardMaterial3D.new()
	var tex := rune_texture()
	_rune_mat.albedo_texture = tex
	_rune_mat.albedo_color = Color(0.09, 0.085, 0.08, 0.82)   # the groove's shadow
	_rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rune_mat.roughness = 1.0
	_rune_mat.emission_enabled = true
	_rune_mat.emission = StoneSentinel.RUNE
	_rune_mat.emission_texture = tex
	_rune_mat.emission_energy_multiplier = 0.0
	q.material = _rune_mat
	rune_face = MeshInstance3D.new()
	rune_face.name = "Inscription"
	rune_face.mesh = q
	rune_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var at := Vector3(centre.x, t1 + STEP * 0.5, centre.z) + b.z * (UP_HALF + 0.007)
	rune_face.transform = Transform3D(b, at - global_position)
	add_child(rune_face)
	_rune_light = OmniLight3D.new()
	_rune_light.light_color = StoneSentinel.RUNE
	_rune_light.omni_range = 1.3
	_rune_light.light_energy = 0.0
	_rune_light.shadow_enabled = false
	_rune_light.position = Vector3(0, 0, 0.22)
	rune_face.add_child(_rune_light)

func _process(delta: float) -> void:
	if sentinel == null or rune_face == null:
		return
	var want := 0.0
	if not sentinel.dormant:
		want = 0.75 + 0.1 * sin(Time.get_ticks_msec() * 0.0021)
		if sentinel.waking >= 0.0:
			# lags the chest a beat: the light runs down out of the statue into its stone
			want *= smoothstep(0.3, 1.0, sentinel.waking / StoneSentinel.WAKE_T)
	# kindles fast with the wake, cools slowly once it is stone again
	var rate := 3.0 if want > rune_glow else 0.6
	rune_glow = move_toward(rune_glow, want, rate * delta)
	_rune_mat.emission_energy_multiplier = RUNE_ENERGY * rune_glow
	_rune_light.light_energy = 0.35 * rune_glow
	_rune_light.visible = rune_glow > 0.01

static var _rune_tex: ImageTexture

## Three glyphs side by side: staves, chevrons and a ring, cut as grooves with soft
## (worn) edges. White where the groove is; alpha is the cut.
static func rune_texture() -> ImageTexture:
	if _rune_tex != null:
		return _rune_tex
	var w := 384
	var h := 96
	var segs: Array = []
	# each glyph lives in a 1 x 1 cell (u right, v down), placed at x offsets 0, 1, 2
	var glyphs := [
		[[0.5, 0.1, 0.5, 0.9], [0.5, 0.35, 0.22, 0.12], [0.5, 0.35, 0.78, 0.12], [0.5, 0.62, 0.25, 0.85]],
		[[0.3, 0.1, 0.3, 0.9], [0.7, 0.1, 0.7, 0.9], [0.3, 0.5, 0.7, 0.3], [0.3, 0.7, 0.7, 0.5]],
		[[0.5, 0.1, 0.5, 0.9], [0.2, 0.55, 0.5, 0.25], [0.8, 0.55, 0.5, 0.25], [0.5, 0.9, 0.78, 0.68]],
	]
	for g in 3:
		for sg in glyphs[g]:
			# three cells across the RUNE_W x RUNE_H band
			segs.append([Vector2(g + sg[0], sg[1]), Vector2(g + sg[2], sg[3])])
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for y in h:
		for x in w:
			var p := Vector2((x + 0.5) / w * 3.0, (y + 0.5) / h)
			var d := 10.0
			for sg in segs:
				var a: Vector2 = sg[0]
				var bb: Vector2 = sg[1]
				var ab := bb - a
				var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				d = minf(d, p.distance_to(a + ab * t))
			# a dot over the middle glyph's arms
			d = minf(d, absf(p.distance_to(Vector2(1.5, 0.12)) - 0.045))
			# worn: the groove's width wanders a little
			var wid := 0.055 + 0.012 * sin(p.x * 23.0 + p.y * 17.0)
			var cut := 1.0 - smoothstep(wid * 0.55, wid, d)
			cut *= 0.85 + 0.15 * rng.randf()
			img.set_pixel(x, y, Color(1, 1, 1, cut))
	img.generate_mipmaps()
	_rune_tex = ImageTexture.create_from_image(img)
	return _rune_tex

## The corner piece that split away: tipped on its edge, half sunk in the turf.
func _fallen_corner(at: Vector3, yaw_s: float, size: Vector3, rng: RandomNumberGenerator) -> void:
	var ruins: Ruins = get_node(ruins_path)
	var g := _terrain.height_at(at.x, at.z)
	var bb := Basis(Vector3.UP, yaw_s + 0.7) * Basis.from_euler(Vector3(0.35, 0.0, -0.22))
	_put(ruins.block_meshes, ruins.block_dims, Vector3(at.x, g + size.y * 0.22, at.z), bb, size, 0.0, rng, false)

## Dressed blocks are cut to size (a mesh per size, crisp arrises, light chipping) so the
## plinth reads as squared, tooled granite; spalls and the broken corner use the ruins' rubble.
func _put(meshes: Array[ArrayMesh], dims: Array[Vector3], p: Vector3, bas: Basis, size: Vector3, above: float, rng: RandomNumberGenerator, dressed := true) -> void:
	var v := rng.randi() % meshes.size()
	var d: Vector3 = dims[v]
	if dressed:
		var key := size.snapped(Vector3.ONE * 0.04)
		if not _cut.has(key):
			var ruins: Ruins = get_node(ruins_path)
			var bev := minf(0.028, key.y * 0.25)
			_cut[key] = ruins._block_mesh(key, 40 + _cut.size() % 8, bev, 0.55)
			_cut_per[key] = []
		d = key
		var scd := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
		var xfd := Transform3D(bas.orthonormalized() * Basis.from_scale(scd), p - global_position)
		_cut_per[key].append([xfd, Color(clampf(above / 8.0, 0.0, 1.0), rng.randf(), 1.0, 1.0)])
		block_count += 1
		return
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	if rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(bas.orthonormalized() * Basis.from_scale(sc), p - global_position)
	# masonry custom data: r = height above ground / 8 m, g = random, b = 1 laid course,
	# a = 1 long out in the weather (crust, moss, lichen)
	_per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), rng.randf(), 1.0, 1.0)])
	block_count += 1

## Where the turf falls away the lower course stands proud by more than a stride can step
## (~0.6 m on the downhill side): there footing blocks are laid round it, each a step below
## the course inside it, three to a side, each side owning its +along corner. They collide
## (boxes, `_foot_boxes`, built into the plinth's body). `risers` (bots): the tallest riser met
## walking in from the turf in each of 16 directions.
const FOOT_STEP := 0.3
const FOOT_DEPTH := 0.44
var footing_count := 0
var _foot_boxes: Array = []      # [Transform3D world, size]
func _footing(meshes: Array[ArrayMesh], dims: Array[Vector3], base: float, t1: float, yaw: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 17
	foot_plan = []
	for side in 4:
		var bs := Basis(Vector3.UP, yaw + side * PI * 0.5)
		var out := bs.z
		var along := bs.x
		for c in range(1, 3):
			var half := LOW_HALF + FOOT_DEPTH * (c - 1)
			var span := half * 2.0 + FOOT_DEPTH
			for i in 3:
				var seg := span / 3.0
				var s0 := -half + seg * (i + 0.5)
				var mid := centre + out * (half + FOOT_DEPTH * 0.5) + along * s0
				var g := INF
				for o in [-0.45, 0.0, 0.45]:
					for d in [0.0, FOOT_DEPTH * 0.5, FOOT_DEPTH, FOOT_DEPTH * 2.0]:
						var q: Vector3 = centre + out * (LOW_HALF + float(d)) + along * (s0 + seg * float(o))
						g = minf(g, _terrain.height_at(q.x, q.z))
				var riser := t1 - g
				if riser <= FOOT_STEP:
					continue
				var n := int(ceil(riser / FOOT_STEP)) - 1
				if c > n:
					continue
				var top := t1 - riser * float(c) / float(n + 1)
				var bottom := minf(base, g - 0.14)
				var p := Vector3(mid.x, (bottom + top) * 0.5, mid.z)
				p.y -= absf(rng.randfn()) * 0.01
				var size := Vector3(seg - 0.022, top - bottom - 0.014, FOOT_DEPTH)
				_put(meshes, dims, p, bs * Basis.from_euler(Vector3(rng.randfn() * 0.01, 0.0, rng.randfn() * 0.01)), size, bottom - centre.y, rng)
				_foot_boxes.append([Transform3D(bs, p), Vector3(seg, top - bottom, FOOT_DEPTH)])
				var lc := Vector2(p.x - centre.x, p.z - centre.z).rotated(yaw)
				foot_plan.append([lc, Vector2(seg, FOOT_DEPTH) * 0.5 if side % 2 == 0 else Vector2(FOOT_DEPTH, seg) * 0.5])
				footing_count += 1
	var b := Basis(Vector3.UP, yaw)
	risers = []
	for k in 16:
		var a := TAU * k / 16.0
		var dv := b * Vector3(cos(a), 0.0, sin(a))
		var sq := 1.0 / maxf(absf(cos(a)), absf(sin(a)))
		var chain := [t1]
		for c in range(1, 3):
			var q := centre + dv * (LOW_HALF + FOOT_DEPTH * (c - 0.5)) * sq
			var tp := _box_top(q)
			if tp > -INF and tp < chain[-1] - 0.02:
				chain.append(tp)
		var qg := centre + dv * (LOW_HALF + FOOT_DEPTH * (chain.size() - 1) + 0.15) * sq
		chain.append(_terrain.height_at(qg.x, qg.z))
		var m := 0.0
		for j in chain.size() - 1:
			m = maxf(m, float(chain[j]) - float(chain[j + 1]))
		risers.append(m)

func _box_top(q: Vector3) -> float:
	var best := -INF
	for fb in _foot_boxes:
		var xf: Transform3D = fb[0]
		var hs: Vector3 = fb[1] * 0.5
		var l := xf.affine_inverse() * q
		if absf(l.x) < hs.x and absf(l.z) < hs.z:
			best = maxf(best, (xf * Vector3(l.x, hs.y, l.z)).y)
	return best

## One box per course (lower course, upper course, capstone), square to the statue, so feet
## meet real risers and the walkers' step-up (StepUp) climbs them course by course.
func _collider(base: float, t1: float, t2: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for fb in _foot_boxes:
		var fbox := BoxShape3D.new()
		fbox.size = fb[1] * Vector3(0.98, 1.0, 0.98)
		var fcs := CollisionShape3D.new()
		fcs.name = "PlinthFooting"
		fcs.shape = fbox
		body.add_child(fcs)
		fcs.global_transform = fb[0]
	for d in [[LOW_HALF, t1], [UP_HALF, t2], [CAP_HALF, top_y]]:
		var box := BoxShape3D.new()
		box.size = Vector3(float(d[0]) * 2.0, float(d[1]) - base, float(d[0]) * 2.0)
		var cs := CollisionShape3D.new()
		cs.name = "PlinthCourse"
		cs.shape = box
		body.add_child(cs)
		cs.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(centre.x, (base + float(d[1])) * 0.5, centre.z))

## Whether (x, z) lies under the plinth's footprint grown by `margin` (grass, flowers).
static func under(x: float, z: float, margin: float) -> bool:
	if plan_centre == Vector2.INF:
		return false
	var d := Vector2(x, z) - plan_centre
	var l := d.rotated(plan_yaw)
	if absf(l.x) < LOW_HALF + margin and absf(l.y) < LOW_HALF + margin:
		return true
	for r in foot_plan:
		var fl: Vector2 = l - (r[0] as Vector2)
		if absf(fl.x) < r[1].x + margin and absf(fl.y) < r[1].y + margin:
			return true
	return false

func _exit_tree() -> void:
	if plan_centre == Vector2(centre.x, centre.z):
		plan_centre = Vector2.INF

func _multimesh(mesh: Mesh, items: Array, nm: String) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
