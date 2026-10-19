class_name WhiteCottage
extends StoneCottage
## Harrowmere's third house: a smaller limewashed cottage on the south-west of the green,
## beside the timber-framed house, its door toward the start. Built by StoneCottage's
## builder (rubble walls, quoins, oak lintels, slates, a gable stack, lit windows) with its
## own shape, and every wall stone under coats of white lime (masonry a = 4: flaked low
## down, rain runs from the eaves, algae and splash grime at the foot).

const HOME := Vector2(-20.0, -2.0)
const W_LEN := 7.2
const W_DEP := 5.0
const W_EAVES := 2.35
## [wall, centre along the wall, sill above floor, width, height] as StoneCottage.OPENINGS
const W_OPENINGS := [
	[0, -0.3, 0.0, 0.95, 1.85],    # door
	[0, -2.2, 0.9, 0.7, 0.8],
	[0, 1.9, 0.9, 0.8, 0.85],
	[1, 1.0, 1.0, 0.6, 0.65],
	[2, 0.0, 1.05, 0.55, 0.55],
]

## World yaw: local +z (the door side) faces the village centre.
static func facing() -> float:
	return atan2(-HOME.x, -HOME.y)

## True when (x, z) lies under the house (walls, stack, eaves) plus `margin`.
static func covers(x: float, z: float, margin: float = 0.0) -> bool:
	var y := facing()
	var d := Vector2(x - HOME.x, z - HOME.y)
	var lx := d.x * cos(y) - d.y * sin(y)
	var lz := d.x * sin(y) + d.y * cos(y)
	if absf(lx) < W_LEN * 0.5 + OVER_V + margin and absf(lz) < W_DEP * 0.5 + OVER_E + margin:
		return true
	# the lean-to off the east gable, and the chopping block out at its open end
	if lx > 0.0 and lx < W_LEN * 0.5 + LEAN_D + LEAN_OVER + margin and absf(lz) < LEAN_Z + LEAN_VERGE + margin:
		return true
	return Vector2(lx - BLOCK_AT.x, lz - BLOCK_AT.y).length() < 0.45 + margin

func _init() -> void:
	wlen = W_LEN
	wdep = W_DEP
	eaves = W_EAVES
	openings = W_OPENINGS
	limewash = true
	seed = 5151

## The lean-to (outshut) against the east gable: a woodshed under a pent slate roof that
## falls away from the gable onto a rubble outer wall, a rubble end wall at the back, its
## front end (toward the green) open between the gable and the outer wall.
const LEAN_D := 2.3        # outer depth out from the gable face (local +x)
const LEAN_Z := 1.6        # half its length along the gable (local z)
const LEAN_HI := 2.7       # rafter tops at the gable face, above the floor
const LEAN_P := 0.42       # roof pitch (rad, 24 degrees)
const LEAN_OVER := 0.3     # eaves overhang past the outer wall
const LEAN_VERGE := 0.2    # verge overhang at both ends
const RAFTER := 0.1        # rafter depth under the boards
const BLOCK_AT := Vector2(W_LEN * 0.5 + 1.2, LEAN_Z + 1.0)   # chopping block, out front

## Under the eaves drip by the east corner of the door wall (cottage-local, on the ground).
const BUTT_AT := Vector2(3.05, 2.5 + 0.4)
## The bench against the door wall, left of the door under the window.
const BENCH_X := -1.75
const BENCH_LEN := 1.45

var butt: WaterButt
var logs := 0                    # split logs stacked and lying about (bots)
var lean_floor := 0.0            # local ground height in the lean-to's middle
var lean_stones := 0
var bench_seat := Vector3.ZERO   # world centre of the bench's seat (bots)

func _ready() -> void:
	super()
	_yard_things()

func _ground(lx: float, lz: float) -> float:
	var p := to_global(Vector3(lx, 0, lz))
	return _terrain.height_at(p.x, p.z) - global_position.y

## The water butt on two stones and an oak bench on two stone legs by the door.
func _yard_things() -> void:
	var legs: Array = []
	var bx := BUTT_AT.x
	var bz := BUTT_AT.y
	# two flat dressed stones the cask stands on, bedded a little into the ground
	var g := _ground(bx, bz)
	for side in [-1.0, 1.0]:
		var c: Vector3 = Vector3(bx + side * 0.17, g + 0.04, bz)
		legs.append([Transform3D(Basis.from_euler(Vector3(0, side * 0.06, 0)) * Basis.from_scale(Vector3(0.2, 0.18, 0.62) / _dims[0]), c), Color(0.05, 0.62, 1.0, 1.0)])
	butt = WaterButt.new()
	butt.name = "WaterButt"
	add_child(butt)
	butt.position = Vector3(bx, g + 0.13, bz)
	butt.rotation.y = 0.4
	butt.weather = _world.get("weather")
	var tr = _world.get_node_or_null("Terrain")
	if tr:
		butt.terrain_mat = tr.material as ShaderMaterial
	_box(Vector3(bx, g + 0.13 + WaterButt.H * 0.5, bz), Vector3(0.66, WaterButt.H + 0.1, 0.66))
	# the bench: a thick oak plank, silvered on top, on two upright stones
	var hd := wdep * 0.5
	var sz := hd + 0.2
	var sg := maxf(_ground(BENCH_X, sz), floor_y - 0.15)
	var seat_y := sg + 0.45
	for side in [-1.0, 1.0]:
		var lx: float = BENCH_X + side * (BENCH_LEN * 0.5 - 0.22)
		var lg := _ground(lx, sz)
		var hgt := seat_y - 0.035 - lg + 0.08
		legs.append([Transform3D(Basis.from_scale(Vector3(0.14, hgt, 0.3) / _dims[0]), Vector3(lx, lg - 0.08 + hgt * 0.5, sz)), Color(0.05, 0.55, 1.0, 1.0)])
	_beam(Vector3(BENCH_X, seat_y, sz), Vector3.RIGHT, BENCH_LEN, Vector3(0.07, 0.34, 0.0), 6.1)
	_box(Vector3(BENCH_X, (sg + seat_y) * 0.5, sz), Vector3(BENCH_LEN, seat_y - sg + 0.05, 0.36))
	bench_seat = to_global(Vector3(BENCH_X, seat_y + 0.035, sz))
	_multimesh(_ruins._block_mesh(_dims[0], 20), legs, "YardStones")

## Rafter-top height (above the floor) of the lean-to's roof at local x.
func lean_top(x: float) -> float:
	return LEAN_HI - (x - wlen * 0.5) * tan(LEAN_P)

## Walls 4 (the lean-to's outer wall, run along z) and 5 (its back end wall, run along x).
func _wall_at(w: int, along: float, cy: float) -> Array:
	if w == 4:
		return [Vector3.BACK, Vector3(wlen * 0.5 + LEAN_D - T * 0.5, cy, along)]
	if w == 5:
		return [Vector3.RIGHT, Vector3(along, cy, -LEAN_Z + T * 0.5)]
	return super(w, along, cy)

func _extras() -> void:
	var gx := wlen * 0.5
	var ox := gx + LEAN_D
	var lo := INF
	for ix in 4:
		for iz in 4:
			lo = minf(lo, _ground(lerpf(gx, ox, ix / 3.0), lerpf(-LEAN_Z, LEAN_Z, iz / 3.0)))
	lean_floor = _ground((gx + ox - T) * 0.5, 0.0)
	var n0 := stone_count
	# rubble walls in courses from below the lowest ground: the outer wall up under its
	# wall plate, the back end wall raked under the roof line
	var y := lo - 0.3
	var wall_top := floor_y + lean_top(ox) - RAFTER - 0.12
	while y < wall_top - 0.06:
		var h := minf(_course_h(), wall_top - y)
		_course(4, -LEAN_Z, LEAN_Z, y, h, true, true)
		y += h
	y = lo - 0.3
	while true:
		var h := _course_h()
		var x1 := minf(ox - T, gx + (floor_y + LEAN_HI - RAFTER - (y + h)) / tan(LEAN_P))
		if x1 < gx + 0.3:
			break
		_course(5, gx, x1, y, h, false, false)
		y += h
	lean_stones = stone_count - n0
	_lean_roof(gx, ox)
	_woodpile(gx, ox)
	# colliders: both walls and the roof slope
	var wh := wall_top - (lo - 0.3)
	_box(Vector3(ox - T * 0.5, lo - 0.3 + wh * 0.5, 0), Vector3(T, wh, LEAN_Z * 2.0))
	var eh := floor_y + LEAN_HI - (lo - 0.3)
	_box(Vector3((gx + ox - T) * 0.5, lo - 0.3 + eh * 0.5, -LEAN_Z + T * 0.5), Vector3(ox - T - gx, eh, T))
	var down := Vector3(cos(LEAN_P), -sin(LEAN_P), 0)
	var nrm := Vector3(sin(LEAN_P), cos(LEAN_P), 0)
	var run := (LEAN_D + LEAN_OVER) / cos(LEAN_P)
	var top := Vector3(gx, floor_y + LEAN_HI, 0)
	_box(top + down * run * 0.5 + nrm * 0.05, Vector3(run, 0.1, (LEAN_Z + LEAN_VERGE) * 2.0), Basis(down, nrm, down.cross(nrm)).orthonormalized())

## Plates, rafters, boards and graded slates on the pent roof, a lime fillet where it
## meets the gable, barge boards up both verges.
func _lean_roof(gx: float, ox: float) -> void:
	var down := Vector3(cos(LEAN_P), -sin(LEAN_P), 0)
	var nrm := Vector3(sin(LEAN_P), cos(LEAN_P), 0)
	var hz := LEAN_Z + LEAN_VERGE
	var run := (LEAN_D + LEAN_OVER) / cos(LEAN_P)
	var top := Vector3(gx, floor_y + LEAN_HI, 0)
	# a plate along the gable on stone corbels, and the wall plate on the outer wall
	_beam(Vector3(gx + 0.08, floor_y + LEAN_HI - RAFTER - 0.08, 0), Vector3.BACK, LEAN_Z * 2.0, Vector3(0.15, 0.16, 1), 301.0, 0.0, Vector3.RIGHT)
	for zc in [-LEAN_Z + T + 0.25, 0.0, LEAN_Z - 0.25]:
		_place(Vector3(gx + 0.1, floor_y + LEAN_HI - RAFTER - 0.22, zc), Basis.IDENTITY, Vector3(0.22, 0.12, 0.2), 0.55, 4.0)
	var wy := floor_y + lean_top(ox) - RAFTER - 0.12
	_beam(Vector3(ox - T * 0.5 - 0.05, wy + 0.07, 0), Vector3.BACK, LEAN_Z * 2.0 + 0.1, Vector3(0.18, 0.14, 1), 302.0, 0.0, Vector3.UP)
	# rafters, 0.07 x RAFTER, from the gable plate over the wall plate out to the eaves
	var nr := 7
	for i in nr:
		var z := lerpf(-LEAN_Z + 0.05, LEAN_Z - 0.05, float(i) / (nr - 1))
		var a := top + Vector3(0.02, 0, z) - nrm * RAFTER * 0.5
		var ln := run - 0.04
		_beam(a + down * ln * 0.5, down, ln, Vector3(0.07, RAFTER, 1), 310.0 + i, 0.0, nrm)
	# boards on the rafters, then the slates from the eaves up
	var deck := _beam(top + down * run * 0.5 + nrm * 0.015, Vector3.BACK, hz * 2.0, Vector3(run, 0.03, 1), 320.0, 0.0, nrm)
	deck.name = "LeanDeck"
	var st := top + nrm * 0.03
	var s := run + 0.04
	var k := 0
	while s > 0.1:
		var u := clampf(s / run, 0.0, 1.0)
		var ln := lerpf(0.3, 0.42, u)
		var margin := (ln - 0.08) * 0.5
		var x := -hz - (_rng.randf_range(0.0, 0.14) if k % 2 == 0 else _rng.randf_range(0.12, 0.22))
		while x < hz:
			var wdt := _rng.randf_range(0.2, 0.3)
			var cz := clampf(x + wdt * 0.5, -hz + 0.1, hz - 0.1)
			var tail := st + down * s + Vector3(0, 0, cz)
			var head := tail - down * ln
			var c := (tail + head) * 0.5 + nrm * (0.014 + _rng.randf_range(0.0, 0.006))
			var b := Basis(nrm.cross(down), nrm, down).orthonormalized()
			b = b * Basis.from_euler(Vector3(-0.03, _rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.012, 0.012)))
			var xf := Transform3D(b * Basis.from_scale(Vector3(wdt / 0.25, 1.0, ln / 0.4)), c)
			_slates[_rng.randi() % 4].append([xf, Color(u, _rng.randf(), 0.0, 1.0)])
			slate_count += 1
			x += wdt + 0.004
		s -= margin
		k += 1
	# lime flaunching along the gable where the slates tuck under
	var fc := st + nrm * 0.05 + Vector3(0.05, 0.03, 0)
	_mortar.append(Transform3D(Basis.from_euler(Vector3(0, 0, -0.6)) * Basis.from_scale(Vector3(0.12, 0.1, hz * 2.0)), fc))
	# barge boards up both verges and a fascia along the eaves
	for sg in [-1.0, 1.0]:
		_beam(top + down * run * 0.5 - nrm * 0.015 + Vector3(0, 0, sg * (hz + 0.012)), down, run, Vector3(0.16, 0.025, 1), 330.0 + sg, 0.35, Vector3(0, 0, sg))
	var ee := top + down * run - nrm * 0.02 + Vector3(0.012, 0, 0)
	_beam(ee, Vector3.BACK, hz * 2.0 + 0.05, Vector3(0.13, 0.025, 1), 333.0, 0.35, down)

## A split-log mesh: the log's axis along Y through the origin, `frac` of the round
## (0.25 quarter, 0.5 half), radius r, length ln, bark faces with radial normals.
func _log_mesh(r: float, ln: float, frac: float, v: int) -> ArrayMesh:
	var rr := RandomNumberGenerator.new()
	rr.seed = 9000 + v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := maxi(4, int(frac * 22.0))
	var a0 := rr.randf_range(0.0, TAU)
	var arc: Array[Vector2] = []
	for i in segs + 1:
		var a := a0 + TAU * frac * float(i) / segs
		arc.append(Vector2(cos(a), sin(a)) * r * rr.randf_range(0.96, 1.03))
	var hl := ln * 0.5
	# a sloping saw cut at each end
	var tilt := Vector2(rr.randf_range(-0.12, 0.12), rr.randf_range(-0.12, 0.12))
	var ytop := func(p: Vector2) -> float: return hl + p.dot(tilt)
	var ybot := func(p: Vector2) -> float: return -hl + p.dot(tilt) * 0.6
	var cen := Vector2.ZERO
	# bark round the arc
	for i in segs:
		var p := arc[i]
		var q := arc[i + 1]
		var np := Vector3(p.x, 0, p.y).normalized()
		var nq := Vector3(q.x, 0, q.y).normalized()
		var q4 := [[Vector3(p.x, ybot.call(p), p.y), np], [Vector3(q.x, ybot.call(q), q.y), nq], [Vector3(q.x, ytop.call(q), q.y), nq], [Vector3(p.x, ytop.call(p), p.y), np]]
		for t in [[0, 2, 1], [0, 3, 2]]:
			var tri := [q4[t[0]], q4[t[1]], q4[t[2]]]
			var fn: Vector3 = (np + nq).normalized()
			if ((tri[1][0] as Vector3) - tri[0][0]).cross((tri[2][0] as Vector3) - tri[0][0]).dot(fn) < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for e in tri:
				st.set_normal(e[1])
				st.add_vertex(e[0])
	# split faces: from the centre out to both arc ends (one plane for a half log)
	for ends in [[cen, arc[0]], [arc[segs], cen]]:
		var p: Vector2 = ends[0]
		var q: Vector2 = ends[1]
		var d := q - p
		if d.length() < 0.001:
			continue
		var fn := Vector3(d.y, 0, -d.x).normalized()
		var mid := (p + q) * 0.5
		if fn.dot(Vector3(mid.x, 0, mid.y) - Vector3(arc[segs / 2].x, 0, arc[segs / 2].y)) < 0.0:
			fn = -fn
		var quad := [Vector3(p.x, ybot.call(p), p.y), Vector3(q.x, ybot.call(q), q.y), Vector3(q.x, ytop.call(q), q.y), Vector3(p.x, ytop.call(p), p.y)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			for e in _wind([quad[t[0]], quad[t[1]], quad[t[2]]], fn):
				st.set_normal(fn)
				st.add_vertex(e)
	# sawn ends: fans round the centre
	for end in [1.0, -1.0]:
		var fn := Vector3(0, end, 0)
		for i in segs:
			var pts: Array[Vector2] = [cen, arc[i], arc[i + 1]]
			var tri := []
			for p in pts:
				tri.append(Vector3(p.x, ytop.call(p) if end > 0.0 else ybot.call(p), p.y))
			for e in _wind(tri, fn):
				st.set_normal(fn)
				st.add_vertex(e)
	var mesh := st.commit()
	return mesh

## Firewood stacked against the back end wall, a chopping block out at the open end with
## the axe in it, split logs and chips round its foot.
func _woodpile(gx: float, ox: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/firewood.gdshader")
	var outm := ShaderMaterial.new()
	outm.shader = mat.shader
	outm.set_shader_parameter("exposed", 1.0)
	var meshes: Array[ArrayMesh] = []
	var kinds := [[0.11, 0.25], [0.1, 0.5], [0.13, 0.25], [0.09, 0.34], [0.12, 0.5], [0.08, 0.25]]
	for v in kinds.size():
		var m := _log_mesh(kinds[v][0], 0.36, kinds[v][1], v)
		m.surface_set_material(0, mat)
		meshes.append(m)
	var items: Array = []
	for v in meshes.size():
		items.append([])
	# the stack: rows along the end wall, two logs deep, ends toward the open front
	var x0 := gx + 0.12
	var x1 := ox - T - 0.08
	var zb := -LEAN_Z + T + 0.2
	var yl := lean_floor + 0.07
	var layer := 0
	while yl < lean_floor + 1.3:
		var x := x0 + (0.06 if layer % 2 == 1 else 0.0)
		while x < x1 - 0.08:
			var w := _rng.randf_range(0.13, 0.19)
			for row in 2:
				var v := _rng.randi() % meshes.size()
				var ang := _rng.randf_range(0.0, TAU)
				var b := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, ang)
				b = Basis.from_euler(Vector3(_rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.08, 0.08), 0)) * b
				var c := Vector3(x + w * 0.5 + _rng.randf_range(-0.02, 0.02), yl + _rng.randf_range(-0.015, 0.015), zb + row * 0.38 + _rng.randf_range(-0.04, 0.05))
				items[v].append([Transform3D(b.scaled(Vector3.ONE * _rng.randf_range(0.9, 1.1)), c), Color(_rng.randf(), _rng.randf_range(0.3, 0.8), float(_rng.randf() < 0.3), 1.0)])
				logs += 1
			x += w
		yl += 0.125
		layer += 1
	# the stack's top row ragged: a few logs lying across on top
	for i in 4:
		var v := _rng.randi() % meshes.size()
		var b := Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, _rng.randf() * TAU)
		b = Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)) * b
		items[v].append([Transform3D(b, Vector3(_rng.randf_range(x0 + 0.2, x1 - 0.2), yl + 0.02, zb + _rng.randf_range(0.0, 0.4))), Color(_rng.randf(), 0.5, 0.0, 1.0)])
		logs += 1
	for v in meshes.size():
		_multimesh(meshes[v], items[v], "Firewood_%d" % v)
	# the stack is solid: the hero stops at its face
	_box(Vector3((x0 + x1) * 0.5, (lean_floor + yl) * 0.5, zb + 0.18), Vector3(x1 - x0, yl - lean_floor + 0.1, 0.78))
	# the chopping block: a short round of elm, axe bitten into its top
	var bx := BLOCK_AT.x
	var bz := BLOCK_AT.y
	var by := _ground(bx, bz)
	var block := _log_mesh(0.27, 0.48, 1.0, 50)
	block.surface_set_material(0, outm)
	_multimesh(block, [[Transform3D(Basis(Vector3.UP, 0.7), Vector3(bx, by + 0.2, bz)), Color(0.4, 0.85, 0.0, 1.0)]], "ChoppingBlock")
	_box(Vector3(bx, by + 0.2, bz), Vector3(0.5, 0.48, 0.5))
	var top_y := by + 0.2 + 0.24
	var helve := _beam(Vector3(bx + 0.28, top_y + 0.22, bz + 0.08), Vector3(0.75, 0.62, 0.2), 0.78, Vector3(0.035, 0.028, 1), 340.0, 0.0)
	helve.name = "AxeHelve"
	var head := MeshInstance3D.new()
	head.name = "AxeHead"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.17, 0.05, 0.03)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.14, 0.13)
	iron.metallic = 0.75
	iron.roughness = 0.55
	hm.material = iron
	head.mesh = hm
	add_child(head)
	var hd := Vector3(0.75, 0.62, 0.2).normalized()
	var bit := (Vector3.DOWN - hd * hd.dot(Vector3.DOWN)).normalized()
	head.basis = Basis(bit, hd, bit.cross(hd).normalized())
	head.position = Vector3(bx + 0.28, top_y + 0.22, bz + 0.08) - hd * 0.38 + bit * 0.03
	# split logs and chips scattered round its foot, a couple of uncut rounds waiting
	var lying: Array = []
	var chips: Array = []
	for i in 7:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.4, 0.95)
		var p := Vector2(bx + cos(a) * d, bz + sin(a) * d)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, _rng.randf() * TAU)
		lying.append([Transform3D(b, Vector3(p.x, _ground(p.x, p.y) + 0.06, p.y)), Color(_rng.randf(), 0.15, 0.0, 1.0)])
		logs += 1
	for i in 40:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 1.1 + 0.25
		var p := Vector2(bx + cos(a) * d, bz + sin(a) * d)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5 + _rng.randf_range(-0.2, 0.2))
		chips.append([Transform3D(b.scaled(Vector3(1, 1, 1) * _rng.randf_range(0.6, 1.2)), Vector3(p.x, _ground(p.x, p.y) + 0.008, p.y)), Color(_rng.randf(), 0.1, 0.0, 1.0)])
	var lm := _log_mesh(0.1, 0.36, 0.25, 60)
	lm.surface_set_material(0, outm)
	_multimesh(lm, lying, "LyingLogs")
	var cm := _log_mesh(0.035, 0.09, 0.2, 61)
	cm.surface_set_material(0, outm)
	_multimesh(cm, chips, "Chips")
	var rounds: Array = []
	for i in 2:
		var p := Vector2(bx + 0.75 + i * 0.32, bz - 0.55 + i * 0.12)
		rounds.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, _ground(p.x, p.y) + 0.17, p.y)), Color(_rng.randf(), 0.2, 0.0, 1.0)])
	var rm := _log_mesh(0.18, 0.36, 1.0, 62)
	rm.surface_set_material(0, outm)
	_multimesh(rm, rounds, "Rounds")

## The house's outline plus the lean-to's, for the herd's steering.
func outline(step: float) -> Array[Vector3]:
	var pts := super(step)
	var gx := wlen * 0.5
	for i in 4:
		for j in 4:
			if i == 3 or j == 0 or j == 3:
				pts.append(to_global(Vector3(gx + (LEAN_D + LEAN_OVER) * i / 3.0, 0, lerpf(-LEAN_Z, LEAN_Z, j / 3.0))))
	pts.append(to_global(Vector3(BLOCK_AT.x, 0, BLOCK_AT.y)))
	return pts
