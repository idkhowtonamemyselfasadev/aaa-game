class_name YardWall
extends Node3D
## Dry-stone walls closing Harrowmere's yard: the timber house (Cottage) turns its back on
## the yard and the stone cottage (StoneCottage) opens its door onto it; two walls run from
## the corners of the one to the corners of the other. All generated here:
##  - rough split field stones (not the ruin's dressed blocks): lumpy rounded boxes sheared
##    by a few fracture planes, so each shows flat split faces and broken edges;
##  - two faces of stones laid end-on into the wall on a batter (0.75 m at the foot, 0.42 m
##    under the copes), big at the foot and smaller up the wall, each tipped a little out
##    so the rain runs off, through-stones at half height sticking out both sides;
##  - a row of cope stones set on edge along the top, leaning this way and that;
##  - a dark hearting core so the joints show shadow, not sky;
##  - a cart gateway with two tall gate stones in the east wall, a squeeze gap in the west.
## The weathered (aged) masonry look: grey crust, lichen, moss in the lower courses.
## Box colliders per 2 m; grass, flowers and the herd keep off it (`near`, `outline`).

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 5151

const W0 := 0.75          # width at the foot
const W1 := 0.42          # width under the copes
const H := 1.0            # foot to the top of the last course (under the copes)
const COPE := 0.34        # cope stone height
const VARIANTS := 8

var stone_count := 0
var cope_count := 0
var through_count := 0
var pin_count := 0
var _wander := FastNoiseLite.new()
var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _per: Array = []           # per variant: [Transform3D, Color]
var _body: StaticBody3D
var _core: Array[Transform3D] = []

## The walls: [from, to, gap centre (0..1 along), gap width, gate stones].
## From each house's own corners, pulled in by half the wall's width so the outer face runs
## on with the gable.
static func runs() -> Array:
	var out := []
	for sgn in [-1.0, 1.0]:
		var a := _corner(Cottage.SITE, Cottage.yaw(), sgn * (Cottage.LEN * 0.5 - W0 * 0.5), -Cottage.WID * 0.5 - 0.12)
		var b := _corner(StoneCottage.SITE, StoneCottage.yaw(), sgn * (StoneCottage.LEN * 0.5 - W0 * 0.5), StoneCottage.DEP * 0.5 + 0.05)
		if sgn < 0.0:
			out.append([a, b, 0.55, 2.6, true])     # the cart gateway, toward the green
		else:
			out.append([a, b, 0.4, 0.9, false])     # a squeeze gap for folk on foot
	return out

static func _corner(site: Vector2, y: float, lx: float, lz: float) -> Vector2:
	return site + Vector2(cos(y), -sin(y)) * lx + Vector2(sin(y), cos(y)) * lz

static var _pieces: Array = []

## The solid lengths of wall as [from, to] pairs (the gaps cut out). Cached: grass asks per blade.
static func pieces() -> Array:
	if not _pieces.is_empty():
		return _pieces
	var out := []
	for r in runs():
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var l := a.distance_to(b)
		var g0: float = r[2] * l - r[3] * 0.5
		var g1: float = r[2] * l + r[3] * 0.5
		var d := (b - a) / l
		out.append([a, a + d * g0])
		out.append([a + d * g1, b])
	_pieces = out
	return out

## Distance from (x, z) to the nearest wall centre line.
static func dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if p.distance_squared_to((Cottage.SITE + StoneCottage.SITE) * 0.5) > 400.0:
		return INF                             # far from the yard: skip the walk over the walls
	var best := INF
	for pc in pieces():
		var a: Vector2 = pc[0]
		var b: Vector2 = pc[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

## True when (x, z) lies on the wall's foot plus `margin`.
static func near(x: float, z: float, margin: float = 0.0) -> bool:
	return dist(x, z) < W0 * 0.5 + margin

## Points along the walls every `step` m (world, y 0), for walkers that steer off points.
static func outline(step: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for pc in pieces():
		var a: Vector2 = pc[0]
		var b: Vector2 = pc[1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for i in n + 1:
			var q := a.lerp(b, float(i) / n)
			pts.append(Vector3(q.x, 0.0, q.y))
	return pts

func _ready() -> void:
	var ruins: Ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	_wander.seed = seed + 11
	_wander.frequency = 0.45
	_body = StaticBody3D.new()
	_body.name = "YardWallCollision"
	add_child(_body)
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		meshes.append(_stone_mesh(v, ruins.material))
		_per.append([])
	for r in runs():
		_run(r)
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)
	_build_core()

func _ground(q: Vector2) -> float:
	return _terrain.height_at(q.x, q.y) - global_position.y

func _half_w(y: float) -> float:
	return lerpf(W0, W1, clampf(y / H, 0.0, 1.0)) * 0.5

## One wall: both faces course by course, throughs, copes, gate stones, colliders.
func _run(r: Array) -> void:
	var a: Vector2 = r[0]
	var b: Vector2 = r[1]
	var l := a.distance_to(b)
	var d := (b - a) / l
	var g0: float = r[2] * l - r[3] * 0.5
	var g1: float = r[2] * l + r[3] * 0.5
	for seg in [[0.0, g0], [g1, l]]:
		var s0: float = seg[0]
		var s1: float = seg[1]
		for side in [-1.0, 1.0]:
			var y := -0.1                      # the footing course sits a little in the ground
			while y < H - 0.08:
				var t := clampf(y / H, 0.0, 1.0)
				var h := minf(_rng.randf_range(lerpf(0.15, 0.08, t), lerpf(0.3, 0.19, t)), H - y)
				if y < 0.0:
					h = _rng.randf_range(0.3, 0.4)  # the footing: big boulders, half bedded in
				if y > 0.42 and y < 0.6 and side > 0.0:
					_throughs(a, d, s0, s1, y, h)
				_course(a, d, s0, s1, y, h, side)
				y += h + 0.012
		_copes(a, d, s0, s1)
		_collide(a, d, s0, s1)
	if r[4]:
		for s in [g0 - 0.12, g1 + 0.12]:
			_gate_stone(a + d * s, d)

## One course of one face: stones laid end-on into the wall, trimmed to the run's ends.
func _course(a: Vector2, d: Vector2, s0: float, s1: float, y: float, h: float, side: float) -> void:
	var t := clampf(y / H, 0.0, 1.0)
	var s := s0 + _rng.randf_range(0.0, 0.2)
	if _rng.randf() < 0.5:
		s = s0                                 # every other course starts flush, so the ends bond
	while s < s1 - 0.08:
		var foot := y < 0.0
		var f := minf(_rng.randf_range(lerpf(0.2, 0.14, t), lerpf(0.6, 0.38, t)), s1 - s)
		if foot:
			f = minf(_rng.randf_range(0.45, 0.85), s1 - s)
		var dep := minf(_rng.randf_range(0.26, 0.4), _half_w(y) * 2.0 * 0.62)
		# stones are never the course's height exactly: some short with a pinning stone
		# packed over them, some standing proud into the course above
		var hh := h * _rng.randf_range(0.66, 1.18)
		if foot:
			hh = h * _rng.randf_range(0.85, 1.25)
		# the courses wander: the whole wall rises and dips along its length (less up top),
		# and each stone sits a little high or low in its bed
		var yy := y + _wander.get_noise_1d(s * 3.0 + side * 0.4) * 0.07 * (1.0 - t * 0.6) + _rng.randf_range(-0.018, 0.018)
		var off := (_half_w(yy + hh * 0.5) - dep * 0.5 + _rng.randf_range(-0.015, 0.035)) * side
		_place(a, d, s + f * 0.5, off, yy, Vector3(f, hh, dep), side, 0.07 if not foot else 0.1)
		if hh < h * 0.86 and not foot:
			_pin(a, d, s + f * 0.5, off, yy + hh, h - hh, f, side)
		elif _rng.randf() < 0.22 and not foot:
			_pin(a, d, s + f + 0.02, off, yy + h * 0.3, h * 0.4, 0.07, side)
		s += f + _rng.randf_range(0.0, 0.045)

## A pinning stone: a thin wedge driven into a gap to bed the stone above (over a short
## stone, or upright into a vertical joint), its face a little proud of the wall.
func _pin(a: Vector2, d: Vector2, s: float, off: float, y: float, gap: float, room: float, side: float) -> void:
	var th := clampf(gap + 0.02, 0.04, 0.09)
	var ln := clampf(room * _rng.randf_range(0.35, 0.7), 0.07, 0.22)
	_place(a, d, s + _rng.randf_range(-0.03, 0.03), off + side * 0.02, y - 0.01, Vector3(ln, th, 0.16), side, 0.18)
	pin_count += 1

## Through-stones: long stones across the whole wall, every ~0.9 m, ends proud of both faces.
func _throughs(a: Vector2, d: Vector2, s0: float, s1: float, y: float, h: float) -> void:
	var s := s0 + _rng.randf_range(0.3, 0.6)
	while s < s1 - 0.3:
		var w := _half_w(y) * 2.0 + _rng.randf_range(0.1, 0.18)
		_place(a, d, s, _rng.randf_range(-0.03, 0.03), y + h * 0.15, Vector3(_rng.randf_range(0.22, 0.32), h * 0.7, w), 0.0, 0.03)
		through_count += 1
		s += _rng.randf_range(0.8, 1.05)

## Copes: flat stones set on edge along the top, across the wall, leaning a little.
func _copes(a: Vector2, d: Vector2, s0: float, s1: float) -> void:
	var s := s0 + 0.04
	while s < s1 - 0.05:
		var th := _rng.randf_range(0.08, 0.17)
		var ch := COPE * _rng.randf_range(0.7, 1.2)
		var xf := _xf(a, d, s + th * 0.5, _rng.randf_range(-0.025, 0.025), H - 0.06, Vector3(th, ch, W1 + _rng.randf_range(0.04, 0.14)), 0.0, 0.0)
		# set on edge leaning one way down a stretch, then the other: the run's lean wanders
		var lean := _wander.get_noise_1d(s * 1.7 + 50.0) * 0.45 + _rng.randf_range(-0.08, 0.08)
		xf.basis = xf.basis.rotated(Vector3(d.x, 0, d.y).cross(Vector3.UP).normalized(), lean)
		_add(xf, H - 0.04)
		cope_count += 1
		s += th / cos(lean) + _rng.randf_range(0.015, 0.05)

## A tall gate stone standing in the ground at the gateway's cheek.
func _gate_stone(q: Vector2, d: Vector2) -> void:
	var g := _ground(q)
	var sz := Vector3(_rng.randf_range(0.3, 0.38), H + COPE + 0.35, _rng.randf_range(0.34, 0.42))
	var yaw := atan2(d.x, d.y)
	var b := Basis(Vector3.UP, yaw + PI * 0.5) * Basis(Vector3.RIGHT, _rng.randf_range(-0.03, 0.03))
	var c := Vector3(q.x, g - 0.25 + sz.y * 0.5, q.y)
	_add(Transform3D(b * Basis.from_scale(sz), c), sz.y * 0.5)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz * 0.9
	cs.shape = box
	cs.transform = Transform3D(b, c)
	_body.add_child(cs)

## Stone at distance s along the run, `off` across it (+ toward the run's right), its bed at
## y over the local ground; size (along, up, across). Face stones tip out by the batter.
func _place(a: Vector2, d: Vector2, s: float, off: float, y: float, sz: Vector3, side: float, jit: float) -> void:
	var xf := _xf(a, d, s, off, y, sz, side, jit)
	_add(xf, y + sz.y * 0.5)

func _xf(a: Vector2, d: Vector2, s: float, off: float, y: float, sz: Vector3, side: float, jit: float) -> Transform3D:
	var right := Vector2(-d.y, d.x)
	var q := a + d * s + right * off
	var g := _ground(a + d * s)
	var along := Vector3(d.x, 0, d.y)
	var across := Vector3(right.x, 0, right.y)
	var b := Basis(along, Vector3.UP, across)
	# the batter: the face leans in; plus the stone's own tilt and twist
	b = b.rotated(along, side * -0.16 + _rng.randf_range(-jit, jit))
	b = b.rotated(Vector3.UP, _rng.randf_range(-jit, jit))
	b = b.rotated(across, _rng.randf_range(-jit, jit) * 1.5)
	var sc := sz
	if _rng.randf() < 0.5:
		sc = Vector3(-sc.x, sc.y, -sc.z)       # flip so the same fractures do not repeat
	return Transform3D(b * Basis.from_scale(sc), Vector3(q.x, g + y + sz.y * 0.5, q.y))

func _add(xf: Transform3D, above: float) -> void:
	_per[_rng.randi() % VARIANTS].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), _rng.randf(), 1.0, 2.0)])
	stone_count += 1

## Box colliders along a solid length, ~2 m each, following the ground.
func _collide(a: Vector2, d: Vector2, s0: float, s1: float) -> void:
	var n := maxi(1, ceili((s1 - s0) / 2.0))
	var step := (s1 - s0) / n
	var hgt := H + COPE
	for i in n:
		var sm := s0 + step * (i + 0.5)
		var q := a + d * sm
		var g := minf(_ground(a + d * (s0 + step * i)), _ground(a + d * (s0 + step * (i + 1))))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(step, hgt + 0.3, W0 * 0.8)
		cs.shape = box
		var b := Basis(Vector3(d.x, 0, d.y), Vector3.UP, Vector3(-d.y, 0, d.x))
		var c := Vector3(q.x, g - 0.3 + (hgt + 0.3) * 0.5, q.y)
		cs.transform = Transform3D(b, c)
		_body.add_child(cs)
		# the hearting behind the faces, the same length
		_core.append(Transform3D(b * Basis.from_scale(Vector3(step, H - 0.05, W1 * 0.7)), Vector3(q.x, _ground(q) + (H - 0.05) * 0.5 - 0.02, q.y)))

func _build_core() -> void:
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.08, 0.065)
	m.roughness = 1.0
	bm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = _core.size()
	for i in _core.size():
		mm.set_instance_transform(i, _core[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Hearting"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## A rough split field stone of unit size: a subdivided box rounded and lumped by noise,
## then cut back by a few fracture planes so it shows flat split faces and broken edges.
func _stone_mesh(v: int, mat: Material) -> ArrayMesh:
	return stone_mesh(seed, v, mat)

## The same, shared: `rad` rounds the arrises (unit space), `lump` the bulge of the faces,
## fracture planes cut in at `cut0`..`cut1` from the centre; with `rel` those are fractions
## of the box's reach along the plane normal, so a slanted cut only nicks a corner
## (StoneCottage's squarer coursed rubble).
static func stone_mesh(sd: int, v: int, mat: Material, rad := 0.16, lump := 0.07, cut0 := 0.36, cut1 := 0.47, rel := false) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = sd + v * 7
	n.frequency = 2.2
	n.fractal_octaves = 4
	var r := RandomNumberGenerator.new()
	r.seed = sd + 300 + v
	var cuts := []
	for i in r.randi_range(3, 5):
		var cn := Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.6), r.randf_range(-1, 1)).normalized()
		var reach := 0.5 * (absf(cn.x) + absf(cn.y) + absf(cn.z)) if rel else 1.0
		cuts.append([cn, r.randf_range(cut0, cut1) * reach])
	var div := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var u_ax := (axis + 1) % 3
			var v_ax := (axis + 2) % 3
			var grid := []
			var cols := []
			for iu in div + 1:
				var row := []
				var crow := []
				for iv in div + 1:
					var p := Vector3.ZERO
					p[axis] = 0.5 * sgn
					p[u_ax] = float(iu) / div - 0.5
					p[v_ax] = float(iv) / div - 0.5
					crow.append(Color(clampf(minf(0.5 - absf(p.x), 0.5 - absf(p.y)) / 0.25, 0.0, 1.0), 0, 0))
					row.append(_shape(p, n, cuts, rad, lump))
				grid.append(row)
				cols.append(crow)
			var fn := Vector3.ZERO
			fn[axis] = sgn
			for iu in div:
				for iv in div:
					var q := [grid[iu][iv], grid[iu + 1][iv], grid[iu + 1][iv + 1], grid[iu][iv + 1]]
					var c := [cols[iu][iv], cols[iu + 1][iv], cols[iu + 1][iv + 1], cols[iu][iv + 1]]
					var order := [0, 2, 1, 0, 3, 2] if ((q[1] - q[0]).cross(q[2] - q[0])).dot(fn) > 0.0 else [0, 1, 2, 0, 2, 3]
					for k in order:
						st.set_color(c[k])
						st.add_vertex(q[k])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	if mat:
		mesh.surface_set_material(0, mat)
	return mesh

static func _shape(p: Vector3, n: FastNoiseLite, cuts: Array, rad: float, lump: float) -> Vector3:
	var inner := Vector3.ONE * (0.5 - rad)
	var q := p.clamp(-inner, inner)
	var dd := p - q
	if dd.length() > 0.0001:
		p = q + dd.normalized() * rad
	# lumps over the whole stone
	p += p.normalized() * n.get_noise_3dv(p * 1.3) * lump
	# fracture planes: shear the stone flat where it split off its neighbour
	for c in cuts:
		var cn: Vector3 = c[0]
		var k: float = p.dot(cn) - c[1]
		if k > 0.0:
			p -= cn * k
	# fine pitting / grain
	p += p.normalized() * n.get_noise_3dv(p * 6.0 + Vector3(3, 7, 1)) * 0.012
	return p

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
