class_name Cottage
extends Node3D
## The first house of Harrowmere, on the west edge of the village floor, its door toward the
## green where the hero wakes. All generated here:
##  - a dry-stone footing (the watchtower's stone meshes, Ruins.block_meshes, laid in two
##    or three courses round the footprint, sunk into the turf where the ground falls);
##  - an adze-hewn oak frame: sill, posts on a 1.5 m bay, mid and head rails, wall plate,
##    corner braces, a king post and struts in each gable, rafters showing under the eaves,
##    barge boards up the verges (chamfered beams with a hewn wobble, grain along them);
##  - wattle-and-daub panels in every bay, limewashed, pillowed a little proud of the joint;
##  - a plank door with iron strap hinges and a mullioned window with its shutter shut;
##  - a steep slate roof: riven slates laid one by one in staggered courses (MultiMesh),
##    tails kicked up off the course below, a stone ridge, sarking boards under the eaves;
##  - a stone chimney stack rising up the west gable through the verge.
## The house gets box colliders. Grass, flowers and the herd keep off it (`inside`).

const SITE := Vector2(-13.0, 10.0)
const LEN := 9.0          # along the ridge (local x)
const WID := 5.4          # across (local z); the door is on the +z side
const WALL_H := 2.35      # footing top to the top of the wall plate
const PITCH := 0.87       # rad (~50 deg)
const EAVE := 0.45        # overhang along the long sides
const VERGE := 0.32       # overhang past the gables
const T := 0.22           # frame member section
const SLATE := Vector3(0.26, 0.012, 0.46)
const GAUGE := 0.19

@export var seed: int = 4242

var base_y := 0.0         # local y of the footing's foot (below ground)
var ridge_y := 0.0
var slate_count := 0
var stone_count := 0
var beam_count := 0
var _rng := RandomNumberGenerator.new()
var _st: SurfaceTool
var _stones: Array = []   # per stone variant: [Transform3D, Color]
var _slates: Array = []   # [Transform3D, Color]
var _ruins: Ruins
var _terrain: Terrain
var glow: StandardMaterial3D      # lamplight behind the shutter
var halo_mat: ShaderMaterial      # its far glow
var lit := 0.0

## World yaw of the house: its local +z (the door side) faces the village centre.
static func yaw() -> float:
	return atan2(-SITE.x, -SITE.y)

## Door-side direction in the world.
static func front() -> Vector3:
	var y := yaw()
	return Vector3(sin(y), 0.0, cos(y))

## (x, z) on the house's own axes (x along the ridge, z out of the door side).
static func to_local_xz(x: float, z: float) -> Vector2:
	var y := yaw()
	var d := Vector2(x - SITE.x, z - SITE.y)
	return Vector2(d.x * cos(y) - d.y * sin(y), d.x * sin(y) + d.y * cos(y))

## True when (x, z) lies under the house (walls, chimney and eaves) plus `margin`.
static func inside(x: float, z: float, margin: float = 0.0) -> bool:
	var l := to_local_xz(x, z)
	return l.x > -LEN * 0.5 - VERGE - 0.9 - margin and l.x < LEN * 0.5 + VERGE + margin \
		and absf(l.y) < WID * 0.5 + EAVE + margin

## Points round the footprint every ~2 m (world), for walkers that steer off points.
static func outline_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var y := yaw()
	for i in 6:
		for j in 3:
			var l := Vector3(-LEN * 0.5 + LEN * i / 5.0, 0.0, -WID * 0.5 + WID * j / 2.0)
			var w := l.rotated(Vector3.UP, y)
			out.append(Vector3(SITE.x + w.x, 0.0, SITE.y + w.z))
	return out

func build(terrain: Terrain, ruins: Ruins) -> void:
	_terrain = terrain
	_ruins = ruins
	_rng.seed = seed
	# the footing top sits a little above the highest turf under the house
	var lo := INF
	var hi := -INF
	for i in 7:
		for j in 5:
			var l := Vector3(-LEN * 0.5 - 0.9 + (LEN + 1.2) * i / 6.0, 0.0, -WID * 0.5 + WID * j / 4.0)
			var w := l.rotated(Vector3.UP, yaw())
			var h := terrain.height_at(SITE.x + w.x, SITE.y + w.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var top := hi + 0.38
	position = Vector3(SITE.x, top, SITE.y)
	rotation.y = yaw()
	base_y = lo - top - 0.3
	ridge_y = WALL_H + 0.16 + (WID * 0.5) * tan(PITCH)
	for v in ruins.block_meshes.size():
		_stones.append([])
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_footing()
	_frame_long(1.0)
	_frame_long(-1.0)
	_frame_gable(1.0)
	_frame_gable(-1.0)
	_roof(1.0)
	_roof(-1.0)
	_ridge()
	_chimney()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cottage.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "Timber"
	mi.mesh = _st.commit()
	mi.material_override = mat
	add_child(mi)
	var smat := ShaderMaterial.new()
	smat.shader = mat.shader
	smat.set_shader_parameter("instanced", true)
	_multimesh(_slate_mesh(), _slates, smat, "Slates")
	for v in _stones.size():
		_multimesh(ruins.block_meshes[v], _stones[v], ruins.material, "Stones_%d" % v)
	_collide()

# --- geometry helpers -----------------------------------------------------------------

## A hewn beam from a to b, section w (across `side`) x h, chamfered arrises, a slight bow
## and wobble along it. COLOR.r = layer (shader), COLOR.g = 1 on the end grain.
## UV = (around the section m, along m) + a per-beam offset; UV2 = (per-beam random, unused).
func _beam(a: Vector3, b: Vector3, w: float, h: float, layer: float, up_hint := Vector3.UP, chamfer := 0.025) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 0.01:
		return
	var fwd := ax / length
	var up := up_hint
	if absf(fwd.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var side := fwd.cross(up).normalized()
	up = side.cross(fwd).normalized()
	var hw := w * 0.5
	var hh := h * 0.5
	var c := minf(chamfer, minf(hw, hh) * 0.6)
	var prof: Array[Vector2] = [Vector2(hw - c, hh), Vector2(-hw + c, hh), Vector2(-hw, hh - c), Vector2(-hw, -hh + c),
		Vector2(-hw + c, -hh), Vector2(hw - c, -hh), Vector2(hw, -hh + c), Vector2(hw, hh - c)]
	var segs := maxi(1, ceili(length / 0.45))
	var rnd := _rng.randf()
	var uoff := _rng.randf() * 10.0
	var bow := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * minf(0.012, length * 0.003)
	var rings: Array = []
	for s in segs + 1:
		var t := float(s) / segs
		var centre := a + ax * t
		var bend := bow * sin(t * PI)
		var ring: Array[Vector3] = []
		for k in 8:
			var p := prof[k]
			var jit := Vector2.ZERO
			if s > 0 and s < segs:
				jit = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.004
			var q := p + bend + jit
			ring.append(centre + side * q.x + up * q.y)
		rings.append(ring)
	var perim := PackedFloat32Array([0.0])
	for k in 8:
		perim.append(perim[k] + prof[k].distance_to(prof[(k + 1) % 8]))
	for s in segs:
		var v0 := length * s / segs
		var v1 := length * (s + 1) / segs
		for k in 8:
			var k2 := (k + 1) % 8
			var r0: Array[Vector3] = rings[s]
			var r1: Array[Vector3] = rings[s + 1]
			var mid := (prof[k] + prof[k2]) * 0.5
			_quad(r0[k], r0[k2], r1[k2], r1[k],
				Vector2(perim[k] + uoff, v0), Vector2(perim[k + 1] + uoff, v0),
				Vector2(perim[k + 1] + uoff, v1), Vector2(perim[k] + uoff, v1), layer, 0.0, rnd, side * mid.x + up * mid.y)
	# end grain caps (UV = section coords, centred off the heart so the rings arc)
	var heart := Vector2(_rng.randf_range(-0.6, 0.6) * hw, _rng.randf_range(-0.6, 0.6) * hh)
	for e in 2:
		var r: Array[Vector3] = rings[0 if e == 0 else segs]
		for k in 6:
			_tri(r[0], r[k + 1], r[k + 2], prof[0] - heart, prof[k + 1] - heart,
				prof[k + 2] - heart, layer, 1.0, rnd, -fwd if e == 0 else fwd)
	beam_count += 1

func _vert(p: Vector3, uv: Vector2, nrm: Vector3, layer: float, endg: float, rnd: float) -> void:
	_st.set_color(Color(layer, endg, 0.0, 1.0))
	_st.set_uv(uv)
	_st.set_uv2(Vector2(rnd, p.y))
	_st.set_normal(nrm)
	_st.add_vertex(p)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
		layer: float, endg: float, rnd: float, out: Vector3) -> void:
	_tri(a, b, c, ua, ub, uc, layer, endg, rnd, out)
	_tri(a, c, d, ua, uc, ud, layer, endg, rnd, out)

## One triangle, wound so it faces `out` (Godot front faces are clockwise seen from the
## front: (b - a) x (c - a) points away from the viewer), with its flat face normal.
func _tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, layer: float, endg: float,
		rnd: float, out: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	var n := cr.normalized()
	if n.dot(out) < 0.0:
		n = -n
		_vert(a, ua, n, layer, endg, rnd)
		_vert(b, ub, n, layer, endg, rnd)
		_vert(c, uc, n, layer, endg, rnd)
	else:
		_vert(a, ua, n, layer, endg, rnd)
		_vert(c, uc, n, layer, endg, rnd)
		_vert(b, ub, n, layer, endg, rnd)

## A pillowed daub panel filling the wall plane rectangle [u0,u1] x [v0,v1] (u along the
## wall, v up), both faces, `out` = outward normal of the wall. Panel origin `o` is the
## point on the wall centre plane at u = 0, v = 0; `along` the wall's u axis.
func _panel(o: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
	var rnd := _rng.randf()
	var n := 5
	for face: float in [1.0, -1.0]:
		var depth: float = T * 0.5 - 0.035
		var grid: Array = []
		for i in n + 1:
			var row: Array[Vector3] = []
			for j in n + 1:
				var su := float(i) / n
				var sv := float(j) / n
				var pillow := sin(su * PI) * sin(sv * PI) * 0.014
				var u := lerpf(u0 - 0.02, u1 + 0.02, su)
				var v := lerpf(v0 - 0.02, v1 + 0.02, sv)
				row.append(o + along * u + Vector3.UP * v + out * face * (depth + pillow))
			grid.append(row)
		for i in n:
			for j in n:
				var r0: Array[Vector3] = grid[i]
				var r1: Array[Vector3] = grid[i + 1]
				var a := r0[j]
				var b := r1[j]
				var c := r1[j + 1]
				var d := r0[j + 1]
				var ua := Vector2(a.dot(along), a.y)
				var ub := Vector2(b.dot(along), b.y)
				var uc := Vector2(c.dot(along), c.y)
				var ud := Vector2(d.dot(along), d.y)
				_quad(a, b, c, d, ua, ub, uc, ud, 0.25, 0.0, rnd, out * face)

## A triangular daub panel in a gable, corners p0 p1 p2 on the centre plane, both faces.
func _panel_tri(p0: Vector3, p1: Vector3, p2: Vector3, out: Vector3) -> void:
	var rnd := _rng.randf()
	var cen := (p0 + p1 + p2) / 3.0
	var pts: Array[Vector3] = []
	for p in [p0, p1, p2]:
		pts.append(cen + (p - cen) * 1.02)
	var n := 6
	for face: float in [1.0, -1.0]:
		var off: Vector3 = out * face * (T * 0.5 - 0.035)
		for i in n:
			for j in n - i:
				var tri_sets := [[Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1)]]
				if j < n - i - 1:
					tri_sets.append([Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)])
				for ts in tri_sets:
					var q: Array[Vector3] = []
					var uv: Array[Vector2] = []
					for g: Vector2i in ts:
						var b1 := float(g.x) / n
						var b2 := float(g.y) / n
						var b0 := 1.0 - b1 - b2
						var pillow := b0 * b1 * b2 * 0.3
						var p := pts[0] * b0 + pts[1] * b1 + pts[2] * b2 + off + out * face * pillow
						q.append(p)
						uv.append(Vector2(p.x + p.z, p.y))
					_tri(q[0], q[1], q[2], uv[0], uv[1], uv[2], 0.25, 0.0, rnd, out * face)

# --- the house ---------------------------------------------------------------------------

func _stone(v: int, xf: Transform3D, above: float) -> void:
	(_stones[v] as Array).append([xf, Color(clampf(above / 8.0, 0.0, 1.0), _rng.randf(), 1.0, 0.35)])
	stone_count += 1

## Lay one course of stones along the segment a -> b (local, at the course's foot), course
## height ch, wall thickness th; stones picked to fill the length, joints ~2 cm.
func _course(a: Vector3, b: Vector3, ch: float, th: float, ground: float) -> void:
	var dims: Array[Vector3] = _ruins.block_dims
	var ax := b - a
	var length := ax.length()
	var dir := ax / length
	var yaw_s := atan2(-dir.z, dir.x)
	var t := 0.0
	while t < length - 0.05:
		var v := _rng.randi_range(0, dims.size() - 1)
		var want := dims[v].x
		var rest := length - t
		if rest - want < 0.35:
			want = rest
		var l := minf(want, rest)
		var d := dims[v]
		var basis := Basis(Vector3.UP, yaw_s) * Basis.from_scale(Vector3((l - 0.02) / d.x, ch / d.y * _rng.randf_range(0.94, 1.02), th / d.z * _rng.randf_range(0.92, 1.05)))
		basis = basis * Basis(Vector3.UP, _rng.randf_range(-0.015, 0.015))
		var c := a + dir * (t + l * 0.5) + Vector3.UP * ch * 0.5
		var lw := Vector3(c.x, 0, c.z).rotated(Vector3.UP, yaw())
		var gy := _terrain.height_at(SITE.x + lw.x, SITE.y + lw.z) - position.y
		if c.y + ch * 0.5 > gy - 0.05:
			_stone(v, Transform3D(basis, c), maxf(0.0, c.y - gy))
		t += l
	return

func _footing() -> void:
	var hx := LEN * 0.5
	var hz := WID * 0.5
	var th := 0.5
	var y := base_y
	var k := 0
	while y < -0.01:
		var ch := clampf(-y, 0.18, _rng.randf_range(0.3, 0.42))
		if -y - ch < 0.18:
			ch = -y
		# the long sides run full length on even courses, the gables on odd (bond at corners)
		var ins := th * 0.5
		if k % 2 == 0:
			_course(Vector3(-hx - 0.05, y, hz), Vector3(hx + 0.05, y, hz), ch, th, 0.0)
			_course(Vector3(hx + 0.05, y, -hz), Vector3(-hx - 0.05, y, -hz), ch, th, 0.0)
			_course(Vector3(hx, y, hz - ins), Vector3(hx, y, -hz + ins), ch, th, 0.0)
			_course(Vector3(-hx, y, -hz + ins), Vector3(-hx, y, hz - ins), ch, th, 0.0)
		else:
			_course(Vector3(hx, y, hz + 0.05), Vector3(hx, y, -hz - 0.05), ch, th, 0.0)
			_course(Vector3(-hx, y, -hz - 0.05), Vector3(-hx, y, hz + 0.05), ch, th, 0.0)
			_course(Vector3(-hx + ins, y, hz), Vector3(hx - ins, y, hz), ch, th, 0.0)
			_course(Vector3(hx - ins, y, -hz), Vector3(-hx + ins, y, -hz), ch, th, 0.0)
		y += ch
		k += 1

## One long wall at z = s * WID/2 (s = 1: the front, with the door and window).
func _frame_long(s: float) -> void:
	var z := s * (WID * 0.5 - T * 0.5)
	var hx := LEN * 0.5
	var top := WALL_H
	_beam(Vector3(-hx, T * 0.5, z), Vector3(hx, T * 0.5, z), T, T, 0.0, Vector3.UP)               # sill
	_beam(Vector3(-hx - 0.12, top - T * 0.5, z), Vector3(hx + 0.12, top - T * 0.5, z), T, T, 0.0)   # wall plate
	var posts := [-hx + T * 0.5, -3.0, -1.5, 0.0, 1.5, 3.0, hx - T * 0.5]
	for px: float in posts:
		_beam(Vector3(px, T, z), Vector3(px, top - T, z), T, T * 0.95, 0.0, Vector3(0, 0, s))
	var out := Vector3(0, 0, s)
	var o := Vector3(0, 0, z)
	var rail := 0.95
	for b in posts.size() - 1:
		var u0: float = posts[b] + T * 0.5
		var u1: float = posts[b + 1] - T * 0.5
		var door := s > 0.0 and b == 3
		var window := s > 0.0 and b == 1
		if door:
			var dh := 1.9
			_beam(Vector3(u0, dh + 0.09, z), Vector3(u1, dh + 0.09, z), T * 0.9, 0.18, 0.0)
			_panel(o, Vector3.RIGHT, out, u0, u1, dh + 0.18, top - T)
			_door(u0, u1, T, dh, z, s)
			continue
		_beam(Vector3(u0, rail + 0.09, z), Vector3(u1, rail + 0.09, z), T * 0.9, 0.18, 0.0)
		_panel(o, Vector3.RIGHT, out, u0, u1, T, rail)
		if window:
			var wh := 1.68
			_beam(Vector3(u0, wh + 0.08, z), Vector3(u1, wh + 0.08, z), T * 0.9, 0.16, 0.0)
			_panel(o, Vector3.RIGHT, out, u0, u1, wh + 0.16, top - T)
			_window(u0, u1, rail + 0.18, wh, z, s)
			continue
		_panel(o, Vector3.RIGHT, out, u0, u1, rail + 0.18, top - T)
		# corner braces in the end bays: from the post foot up to the plate by the corner post
		if b == 0 or b == posts.size() - 2:
			var inner: float = u1 if b == 0 else u0
			var outer: float = u0 if b == 0 else u1
			_beam(Vector3(inner, rail + 0.2, z + s * 0.012), Vector3(outer, top - T - 0.02, z + s * 0.012), 0.16, T * 0.7, 0.0, Vector3(0, 0, s))
	# rafters on this side, showing under the eaves
	var n := int(LEN / 0.5)
	for i in n + 1:
		var x := -hx + LEN * i / n
		x = clampf(x, -hx + 0.08, hx - 0.08)
		var foot := Vector3(x, top + 0.09 - EAVE * tan(PITCH), s * (WID * 0.5 + EAVE))
		var head := Vector3(x, ridge_y - 0.16 + 0.09, 0.0)
		_beam(foot, head, 0.09, 0.14, 0.0, Vector3(0, cos(PITCH), s * sin(PITCH)))

func _door(u0: float, u1: float, sill: float, dh: float, z: float, s: float) -> void:
	# planks set 7 cm in from the wall face, two ledges and a brace behind, iron straps on the face
	var dz := z + s * (T * 0.5 - 0.07)
	var w := u1 - u0
	var n := 6
	for i in n:
		var a := u0 + w * i / n + 0.004
		var b := u0 + w * (i + 1) / n - 0.004
		var c := (a + b) * 0.5
		_beam(Vector3(c, sill, dz), Vector3(c, dh, dz), b - a, 0.04, 0.75, Vector3(0, 0, s), 0.006)
	# ledged back boards: nothing shows through the joints between the planks
	_beam(Vector3((u0 + u1) * 0.5, sill, dz - s * 0.03), Vector3((u0 + u1) * 0.5, dh, dz - s * 0.03), w, 0.02, 0.75, Vector3(0, 0, s), 0.002)
	for hy in [sill + 0.3, dh - 0.32]:
		_beam(Vector3(u0 + 0.02, hy, dz + s * 0.024), Vector3(u1 - 0.12, hy, dz + s * 0.024), 0.05, 0.006, 1.0, Vector3(0, 0, s), 0.002)
		_beam(Vector3(u1 - 0.12, hy, dz + s * 0.024), Vector3(u1 - 0.12, hy - 0.001, dz + s * 0.029), 0.03, 0.012, 1.0, Vector3(0, 1, 0), 0.002)
	# a ring pull
	_beam(Vector3(u1 - 0.2, 1.0, dz + s * 0.03), Vector3(u1 - 0.2, 1.0, dz + s * 0.05), 0.07, 0.07, 1.0, Vector3.UP, 0.02)
	# the threshold stone wear: a doorstep stone in front
	var dims: Array[Vector3] = _ruins.block_dims
	var v := 3
	var d := dims[v]
	var c3 := Vector3((u0 + u1) * 0.5, -0.17, s * (WID * 0.5 + 0.38))
	var basis := Basis.from_scale(Vector3(1.25 / d.x, 0.34 / d.y, 0.5 / d.z)) * Basis(Vector3.UP, 0.02)
	_stone(v, Transform3D(basis, c3), 0.0)

func _window(u0: float, u1: float, v0: float, v1: float, z: float, s: float) -> void:
	# three square mullions set diagonally, a shut plank shutter behind them
	var w := u1 - u0
	for i in 3:
		var x := u0 + w * (i + 1) / 4.0
		_beam(Vector3(x, v0, z + s * 0.03), Vector3(x, v1, z + s * 0.03), 0.06, 0.06, 0.0, Vector3(0, 0, s).rotated(Vector3.UP, 0.785), 0.01)
	var dz := z - s * (T * 0.5 - 0.04)
	var n := 4
	# the shutter hangs a finger short of the frame all round and its planks have shrunk
	# apart: after dusk the lamp inside shows as a thin warm line round it and through the
	# cracks (`_lamp_light`)
	# (18 mm / 7 mm was under 2 px from the green at 12 m and TAA ate it: no rim showed)
	var gap := 0.032
	for i in n:
		var a := u0 + w * i / n + (gap if i == 0 else 0.0)
		var b := u0 + w * (i + 1) / n - (gap if i == n - 1 else 0.016)
		_beam(Vector3((a + b) * 0.5, v0 + gap, dz), Vector3((a + b) * 0.5, v1 - gap, dz), b - a, 0.03, 0.75, Vector3(0, 0, s), 0.004)
	_lamp_light(Vector3((u0 + u1) * 0.5, (v0 + v1) * 0.5, z), Vector2(w, v1 - v0), dz - s * 0.03, s)

## The room's lamplight behind the shut shutter: a warm emissive sheet just inside it (seen
## only through the rim and the plank cracks) and the far halo (window_halo.gdshader) that
## the stone cottages' windows get, dimmer since the shutter holds most of it in.
func _lamp_light(c: Vector3, size: Vector2, back_z: float, s: float) -> void:
	glow = StandardMaterial3D.new()
	# lit, not unshaded: an unshaded material outputs albedo only and drops the emission,
	# so the sheet rendered black behind the cracks (black albedo, no specular: pure glow)
	glow.albedo_color = Color(0.0, 0.0, 0.0)
	glow.roughness = 1.0
	glow.metallic_specular = 0.0
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.58, 0.28)
	glow.emission_energy_multiplier = 0.0
	var sheet := MeshInstance3D.new()
	sheet.name = "LampGlow"
	var q := QuadMesh.new()
	q.size = size + Vector2(0.04, 0.04)
	sheet.mesh = q
	sheet.material_override = glow
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	sheet.position = Vector3(c.x, c.y, back_z)
	if s < 0.0:
		sheet.rotation.y = PI
	halo_mat = ShaderMaterial.new()
	halo_mat.shader = preload("res://shaders/window_halo.gdshader")
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var hq := QuadMesh.new()
	hq.size = Vector2.ONE
	halo.mesh = hq
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 6.0
	add_child(halo)
	halo.position = Vector3(c.x, c.y, c.z + s * 0.25)
	halo.set_instance_shader_parameter("out_dir", Vector3(0, 0, s))

## One gable wall at x = s * LEN/2, framed up to the ridge, its triangle daubed.
func _frame_gable(s: float) -> void:
	var x := s * (LEN * 0.5 - T * 0.5)
	var hz := WID * 0.5 - T
	var top := WALL_H
	_beam(Vector3(x, T * 0.5, -hz), Vector3(x, T * 0.5, hz), T, T, 0.0)
	_beam(Vector3(x, top - T * 0.5, -hz - T), Vector3(x, top - T * 0.5, hz + T), T, T, 0.0)   # tie beam
	var posts := [-hz - T * 0.5, -1.3, 0.0, 1.3, hz + T * 0.5]
	var out := Vector3(s, 0, 0)
	var o := Vector3(x, 0, 0)
	var along := Vector3(0, 0, -s)   # u runs so that along x up = out... _panel picks the winding
	for i in range(1, posts.size() - 1):
		var pz: float = posts[i]
		_beam(Vector3(x, T, pz), Vector3(x, top - T, pz), T, T * 0.95, 0.0, Vector3(s, 0, 0))
	var rail := 0.95
	for b in posts.size() - 1:
		var z0: float = posts[b] + T * 0.5
		var z1: float = posts[b + 1] - T * 0.5
		_beam(Vector3(x, rail + 0.09, z0), Vector3(x, rail + 0.09, z1), T * 0.9, 0.18, 0.0)
		var u0 := minf(z0 * along.z, z1 * along.z)
		var u1 := maxf(z0 * along.z, z1 * along.z)
		_panel(o, along, out, u0, u1, T, rail)
		_panel(o, along, out, u0, u1, rail + 0.18, top - T)
	# the gable: principal rafters along the verge, the king post, two struts
	var ry := ridge_y - 0.16
	var eave := Vector3(x, top + 0.02, 0.0)
	_beam(Vector3(x, top - 0.02, -WID * 0.5 + 0.1), Vector3(x, ry, 0.0), T * 0.9, T, 0.0, Vector3(s, 0, 0))
	_beam(Vector3(x, top - 0.02, WID * 0.5 - 0.1), Vector3(x, ry, 0.0), T * 0.9, T, 0.0, Vector3(s, 0, 0))
	_beam(Vector3(x, top, 0.0), Vector3(x, ry - 0.1, 0.0), T, T * 0.95, 0.0, Vector3(s, 0, 0))
	var midz := (WID * 0.5 - 0.1) * 0.5
	var midy := lerpf(top, ry, 0.5)
	for sz: float in [-1.0, 1.0]:
		_beam(Vector3(x, top + 0.25, sz * 0.08), Vector3(x, midy, sz * midz), 0.15, T * 0.85, 0.0, Vector3(s, 0, 0))
	# daub between them: four triangles
	var k0 := Vector3(x, top, 0.0)
	var kt := Vector3(x, ry, 0.0)
	for sz: float in [-1.0, 1.0]:
		var e0 := Vector3(x, top, sz * (WID * 0.5 - 0.1))
		var m := Vector3(x, midy, sz * midz)
		_panel_tri(k0, e0, m, out)
		_panel_tri(k0, m, kt, out)
	# barge boards up the verge, outside the slates' overhang
	var bx := s * (LEN * 0.5 + VERGE + 0.03)
	for sz: float in [-1.0, 1.0]:
		var foot := Vector3(bx, top - EAVE * tan(PITCH) + 0.12, sz * (WID * 0.5 + EAVE + 0.02))
		var head := Vector3(bx, ridge_y + 0.1, 0.0)
		_beam(foot, head, 0.045, 0.24, 0.75, Vector3(0, cos(PITCH), -sz * sin(PITCH)).rotated(Vector3.UP, 0.0), 0.008)
	eave = eave

## Sarking boards and the slates of one roof slope (s = 1: the front, +z).
func _roof(s: float) -> void:
	var hx := LEN * 0.5 + VERGE
	var down := Vector3(0, -sin(PITCH), s * cos(PITCH))    # ridge -> eave along the slope
	var nrm := Vector3(0, cos(PITCH), s * sin(PITCH))      # out of the roof
	var eave_pt := Vector3(0, WALL_H + 0.16 - EAVE * tan(PITCH), s * (WID * 0.5 + EAVE))
	var ridge_pt := Vector3(0, ridge_y, 0.0)
	var slope := (ridge_pt - eave_pt).length()
	# sarking: boards across the rafters, seen from under the eaves
	var nb := int(slope / 0.2)
	for i in nb:
		var t0 := slope * i / nb
		var c := eave_pt - down * (t0 + slope / nb * 0.5) + nrm * 0.012
		_beam(c - Vector3(hx, 0, 0), c + Vector3(hx, 0, 0), 0.024, slope / nb - 0.006, 0.75, -down, 0.003)
	# slates: courses up from a doubled eave course
	var t := -0.05
	var k := 0
	while t < slope - 0.08:
		var x := -hx - (0.0 if k % 2 == 0 else SLATE.x * 0.5)
		while x < hx:
			var w := _rng.randf_range(0.22, 0.3)
			var x1 := minf(x + w, hx + 0.02)
			var ww := x1 - maxf(x, -hx - 0.02)
			if ww > 0.06:
				var cx := (maxf(x, -hx - 0.02) + x1) * 0.5
				var length := minf(SLATE.z, slope - t + 0.05)
				var lift := 0.03 + 0.012 * (1.0 if k > 0 else 0.0)
				var c := eave_pt - down * (t + length * 0.5) + nrm * lift + Vector3(cx, 0, 0)
				# local slate: x across, z from head (-) to tail (+) along `down`, y out of the roof
				var bz := down
				var by := nrm
				var bx := by.cross(bz).normalized()
				var b := Basis(bx, by, bz)
				b = b * Basis(Vector3.RIGHT, -0.035 + _rng.randf_range(-0.01, 0.01))   # tail kicked up
				b = b * Basis(Vector3.UP, _rng.randf_range(-0.02, 0.02)) * Basis(Vector3.BACK, _rng.randf_range(-0.012, 0.012))
				b = b * Basis.from_scale(Vector3((ww - 0.006) / SLATE.x, _rng.randf_range(0.8, 1.3), length / SLATE.z))
				var course := clampf(t / slope, 0.0, 1.0)
				_slates.append([Transform3D(b, c), Color(_rng.randf(), _rng.randf(), course, 0.5 + 0.5 * s)])
				slate_count += 1
			x += w + 0.004
		t += GAUGE if k > 0 else 0.15
		k += 1

func _ridge() -> void:
	var hx := LEN * 0.5 + VERGE + 0.04
	var x := -hx
	while x < hx - 0.05:
		var l := minf(_rng.randf_range(0.5, 0.62), hx - x)
		var y := ridge_y + 0.05 + _rng.randf_range(-0.008, 0.008)
		for sz: float in [-1.0, 1.0]:
			# two stone saddle plates meeting over the ridge
			var nrm := Vector3(0, cos(PITCH), sz * sin(PITCH))
			var c := Vector3(0, y, 0) + Vector3(0, -sin(PITCH), sz * cos(PITCH)) * 0.12 + nrm * 0.02
			_beam(Vector3(x + 0.01, c.y, c.z), Vector3(x + l - 0.01, c.y, c.z), 0.04, 0.27, 0.5, Vector3(0, -sin(PITCH), sz * cos(PITCH)), 0.01)
		x += l

func _chimney() -> void:
	var cx := -LEN * 0.5 - 0.3
	var cz := 0.65
	var hx := 0.48
	var hz := 0.62
	var y := base_y
	var k := 0
	var top := ridge_y + 0.85
	while y < top - 0.05:
		var ch := minf(_rng.randf_range(0.28, 0.4), top - y)
		# above the eaves the stack steps in to a slimmer flue
		var ax := hx if y < WALL_H + 0.3 else 0.36
		var az := hz if y < WALL_H + 0.3 else 0.42
		var th := 0.3
		var ins := th * 0.5
		if k % 2 == 0:
			_course(Vector3(cx - ax, y, cz + az - ins), Vector3(cx + ax, y, cz + az - ins), ch, th, 0.0)
			_course(Vector3(cx + ax, y, cz - az + ins), Vector3(cx - ax, y, cz - az + ins), ch, th, 0.0)
			_course(Vector3(cx + ax - ins, y, cz + az - th), Vector3(cx + ax - ins, y, cz - az + th), ch, th, 0.0)
			_course(Vector3(cx - ax + ins, y, cz - az + th), Vector3(cx - ax + ins, y, cz + az - th), ch, th, 0.0)
		else:
			_course(Vector3(cx + ax - ins, y, cz + az), Vector3(cx + ax - ins, y, cz - az), ch, th, 0.0)
			_course(Vector3(cx - ax + ins, y, cz - az), Vector3(cx - ax + ins, y, cz + az), ch, th, 0.0)
			_course(Vector3(cx - ax + th, y, cz + az - ins), Vector3(cx + ax - th, y, cz + az - ins), ch, th, 0.0)
			_course(Vector3(cx + ax - th, y, cz - az + ins), Vector3(cx - ax + th, y, cz - az + ins), ch, th, 0.0)
		y += ch
		k += 1
	# a capstone slab with a dark flue mouth
	var dims: Array[Vector3] = _ruins.block_dims
	var v := dims.size() - 4
	var d := dims[v]
	for sz: float in [-1.0, 1.0]:
		var basis := Basis.from_scale(Vector3(0.86 / d.x, 0.12 / d.y, 0.3 / d.z))
		_stone(v, Transform3D(basis, Vector3(cx, top + 0.06, cz + sz * 0.3)), top)

func _slate_mesh() -> ArrayMesh:
	# a riven slate: a thin plate with its tail corners nipped off
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := SLATE.x * 0.5
	var hl := SLATE.z * 0.5
	var hy := SLATE.y * 0.5
	var outline: Array[Vector2] = [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl - 0.03), Vector2(hw - 0.025, hl),
		Vector2(-hw + 0.025, hl), Vector2(-hw, hl - 0.03)]
	var n := outline.size()
	var tris: Array = []   # [a, b, c, outward, edge flag]
	for face: float in [1.0, -1.0]:
		for i in range(1, n - 1):
			var a := outline[0]
			var b := outline[i]
			var c := outline[i + 1]
			tris.append([Vector3(a.x, hy * face, a.y), Vector3(b.x, hy * face, b.y), Vector3(c.x, hy * face, c.y), Vector3(0, face, 0), 0.0])
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var mid := (a + b) * 0.5
		var en := Vector3(mid.x, 0, mid.y).normalized()
		var pa := Vector3(a.x, hy, a.y)
		var pb := Vector3(b.x, hy, b.y)
		var qa := Vector3(a.x, -hy, a.y)
		var qb := Vector3(b.x, -hy, b.y)
		tris.append([pa, pb, qb, en, 1.0])
		tris.append([pa, qb, qa, en, 1.0])
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var o: Vector3 = t[3]
		var cr := (b - a).cross(c - a)
		var nrm := cr.normalized()
		var order := [a, c, b]
		if nrm.dot(o) < 0.0:
			nrm = -nrm
			order = [a, b, c]
		for p: Vector3 in order:
			st.set_color(Color(0.5, t[4], 0.0, 1.0))
			st.set_uv(Vector2(p.x / SLATE.x + 0.5, p.z / SLATE.z + 0.5))
			st.set_normal(nrm)
			st.add_vertex(p)
	return st.commit()

func _multimesh(mesh: Mesh, items: Array, mat: Material, nm: String) -> void:
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
	mmi.material_override = mat
	add_child(mmi)

func _collide() -> void:
	var body := StaticBody3D.new()
	body.name = "CottageCollision"
	add_child(body)
	var boxes := [
		[Vector3(0, (base_y + WALL_H) * 0.5, 0), Vector3(LEN + 0.1, WALL_H - base_y, WID + 0.1)],
		[Vector3(-LEN * 0.5 - 0.3, (base_y + ridge_y + 0.85) * 0.5, 0.65), Vector3(0.96, ridge_y + 0.85 - base_y, 1.24)],
	]
	for bx: Array in boxes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[1]
		cs.shape = sh
		cs.position = bx[0]
		body.add_child(cs)
	# the two roof slopes, so nothing drops through onto the wall tops
	for s: float in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var slope := (WID * 0.5 + EAVE) / cos(PITCH)
		sh.size = Vector3(LEN + VERGE * 2.0, 0.2, slope)
		cs.shape = sh
		var mid := Vector3(0, (ridge_y + WALL_H + 0.16 - EAVE * tan(PITCH)) * 0.5, s * (WID * 0.5 + EAVE) * 0.5)
		cs.transform = Transform3D(Basis(Vector3.RIGHT, -s * PITCH), mid)
		body.add_child(cs)

## The lamp is lit from dusk to bedtime (and a dawn candle), on the same clock as the stone
## cottages' unkept windows; it takes a moment to kindle and to go out.
func _process(delta: float) -> void:
	if glow == null:
		return
	var w := get_parent()
	var h: float = w.time_of_day if w != null and "time_of_day" in w else 12.0
	lit = move_toward(lit, StoneCottage.lit_for(h), delta / 1.5)
	glow.emission_energy_multiplier = lit * 5.0
	halo_mat.set_shader_parameter("lit", lit * 0.5)
