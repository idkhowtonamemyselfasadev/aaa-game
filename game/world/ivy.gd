class_name Ivy
extends Node3D
## Common ivy (Hedera helix) climbing the ruined keep, all generated here:
##  - woody stems that climb from the wall foot in a wandering line, pressed to the stone,
##    throwing side shoots that run off diagonally, a few runners creeping along the foot;
##  - along every stem, alternate leaves on short petioles: dark glossy three-to-five lobed
##    blades (pale veins painted by ivy.gdshader) held out from the wall, tips hanging down
##    so they overlap like shingles; small light-green young leaves at the growing tips;
##  - patches favour the shaded north side and the stretches seen from the approach and from
##    the keep floor, and stop short of the broken crown.
## Leaves are MultiMesh instances of three blade shapes; stems are one tube mesh.

const STEP := 0.05

var leaf_count := 0
var _rng := RandomNumberGenerator.new()
var _ruins: Ruins
var _terrain: Terrain
var leaves: Array = [[], [], []]       # per blade shape: [Transform3D, Color]
var _st := SurfaceTool.new()

func build(ruins: Ruins, terrain: Terrain, seed: int) -> void:
	_ruins = ruins
	_terrain = terrain
	_rng.seed = seed
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var site := ruins.site
	var breach := atan2(-site.z, -site.x)
	var north := -PI * 0.5                    # -Z
	# outer face: both shoulders of the breach (seen on the approach), the north flank
	var outer := [breach + 0.75, breach - 0.8, breach + 1.5, north, north + 0.55, north - 0.6,
			breach + PI + 0.3]
	# the faces either side of the breach that the approach (`ruin`) camera looks at
	outer.append_array([breach + 1.1, breach - 1.15, breach - 1.5])
	for a in outer:
		_patch(a + _rng.randfn() * 0.08, 4.635, 1.0, _rng.randi_range(7, 10))
	# inner face: across the floor from the breach (behind the shrine lid) and the north side
	var inner := [breach + PI - 0.35, breach + PI + 0.5, north + 0.2]
	for a in inner:
		_patch(a + _rng.randfn() * 0.08, 2.9, -1.0, _rng.randi_range(5, 8))
	var stems := MeshInstance3D.new()
	stems.name = "IvyStems"
	_st.generate_normals()
	stems.mesh = _st.commit()
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.vertex_color_is_srgb = true
	smat.roughness = 0.88
	stems.material_override = smat
	add_child(stems)
	var lmat := ShaderMaterial.new()
	lmat.shader = preload("res://shaders/ivy.gdshader")
	for k in 3:
		var items: Array = leaves[k]
		if items.is_empty():
			continue
		# LOD: every second leaf drops out past ~60 m (the mats still read as mats)
		var blade := _blade(k)
		for half in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = blade
			mm.instance_count = (items.size() + 1 - half) / 2
			var j := 0
			for i in range(half, items.size(), 2):
				mm.set_instance_transform(j, items[i][0])
				mm.set_instance_custom_data(j, items[i][1])
				j += 1
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "IvyLeaves_%d_%d" % [k, half]
			mmi.multimesh = mm
			mmi.material_override = lmat
			if half == 1:
				mmi.visibility_range_end = 60.0
				mmi.visibility_range_end_margin = 4.0
			add_child(mmi)
		leaf_count += items.size()

## One clump: `n` stems rooted round angle a0 on the face of radius r; side = +1 for the
## outer face (normal out), -1 for the inner face (normal in toward the keep floor).
func _patch(a0: float, r: float, side: float, n: int) -> void:
	var top := _ruins.wall_top(a0, r) - 0.35
	var gy := _terrain.height_at(_ruins.site.x + cos(a0) * (r + side * 0.3), _ruins.site.z + sin(a0) * (r + side * 0.3))
	if top - gy < 1.0:
		return
	for s in n:
		var a := a0 + _rng.randfn() * 0.55 / r
		var reach := lerpf(0.45, 1.0, pow(_rng.randf(), 0.6)) * minf(top - gy, 5.5)
		_stem(a, gy - 0.08, r, side, 0.0, reach, 0.016, true)
		if side > 0.0 and _rng.randf() < 0.6:
			# a runner along the wall foot
			_stem(a, gy + 0.05, r, side, (1.0 if _rng.randf() < 0.5 else -1.0) * 1.45, _rng.randf_range(0.6, 1.6), 0.009, false)

## Grow one stem over the face from (a, y): heading dir is the angle from straight up
## (+ = toward increasing a); it wanders, main stems pull back toward vertical, side shoots
## hold a slant. Leaves at every node.
func _stem(a: float, y: float, r: float, side: float, dir: float, length: float, rad: float, main: bool) -> void:
	var pts: Array[Vector3] = []
	var hold := dir
	var dist := 0.0
	var y0 := y
	while dist < length:
		var p := _at(a, y, r, side)
		pts.append(p)
		var top := _ruins.wall_top(a, r) - 0.3
		if y > top:
			break
		var g := _terrain.height_at(p.x, p.z)
		# never dives into the ground
		if y < g - 0.1 and dist > 0.3:
			y = g - 0.05
		dir += _rng.randfn() * 0.16
		dir = lerpf(dir, hold, 0.08)
		y += cos(dir) * STEP
		a += sin(dir) * STEP / r
		dist += STEP
		if main and dist > 0.25 and _rng.randf() < 0.08:
			var sd := (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.5, 1.2)
			_stem(a, y, r, side, sd, minf(length - dist, _rng.randf_range(0.35, 1.3)), rad * 0.6, false)
	if pts.size() < 3:
		return
	var nrm_at := func(q: Vector3) -> Vector3:
		return Vector3(q.x - _ruins.site.x, 0, q.z - _ruins.site.z).normalized() * side
	_tube(pts, rad, nrm_at)
	# leaves: alternate, one per node, bigger and darker low on old wood
	var flip := 1.0
	for i in range(1, pts.size()):
		var p: Vector3 = pts[i]
		var n: Vector3 = nrm_at.call(p)
		var along: Vector3 = (pts[i] - pts[i - 1]).normalized()
		var lat := n.cross(along).normalized() * flip
		flip = -flip
		var tip := float(pts.size() - 1 - i) * STEP
		var young := 1.0 - smoothstep(0.08, 0.3, tip)
		var old := clampf((p.y - y0) / 3.0, 0.0, 1.0)
		var count := (3 if _rng.randf() < 0.4 else 2) if young < 0.5 else 1
		for c in count:
			var size := lerpf(0.11, 0.075, old * 0.6) * _rng.randf_range(0.75, 1.25) * lerpf(1.0, 0.45, young)
			# petioles short and laid along the stone, shortest on the old wood low down, so
			# the blades lie pressed to the wall in overlapping shingles
			var pet := _rng.randf_range(0.015, 0.065) * lerpf(0.55, 1.0, old) * lerpf(1.0, 0.5, young)
			var pd := (n * 0.35 + lat * _rng.randf_range(0.4, 0.9) + Vector3.UP * 0.3).normalized()
			var base := p + pd * pet
			# blade faces out and a little up; tip hangs down and to the side (shingled)
			var face := (n + Vector3.UP * _rng.randf_range(0.05, 0.3) + lat * _rng.randfn() * 0.18).normalized()
			var mid := (-Vector3.UP + lat * _rng.randf_range(0.0, 0.9) + n * 0.2)
			mid = (mid - face * mid.dot(face)).normalized()
			var xb := mid.cross(face).normalized()
			var b := Basis(xb, mid, face) * Basis.from_scale(Vector3.ONE * size)
			var shape := 2 if young > 0.5 else (_rng.randi() % 2)
			leaves[shape].append([Transform3D(b, base), Color(young, _rng.randf(), old, _rng.randf())])
			lat = -lat

func _at(a: float, y: float, r: float, side: float) -> Vector3:
	# pressed to the stone, wavering a few mm in and out over the block faces
	var rr := r + side * (0.012 + _rng.randf() * 0.01)
	return Vector3(_ruins.site.x + cos(a) * rr, y, _ruins.site.z + sin(a) * rr)

func _tube(pts: Array[Vector3], rad: float, nrm_at: Callable) -> void:
	var sides := 5
	var m := pts.size()
	var rings := []
	for i in m:
		var p: Vector3 = pts[i]
		var t: Vector3 = (pts[mini(i + 1, m - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n: Vector3 = nrm_at.call(p)
		var u := t.cross(n).normalized()
		var v := u.cross(t).normalized()
		var rr := rad * lerpf(1.0, 0.3, float(i) / (m - 1))
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			ring.append(p + (u * cos(ang) + v * sin(ang)) * rr)
		rings.append(ring)
	var bark := Color(0.16, 0.12, 0.08).lerp(Color(0.23, 0.2, 0.15), _rng.randf())
	for i in m - 1:
		var c0 := bark.lerp(Color(0.2, 0.25, 0.1), float(i) / m * 0.6)
		for k in sides:
			var k1 := (k + 1) % sides
			var q := [rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]]
			for idx in [0, 2, 1, 0, 3, 2]:
				_st.set_color(c0)
				_st.add_vertex(q[idx])

## A blade in leaf space: base at the origin, midrib along +Y (length 1), face +Z. Shape 0 the
## deep-lobed juvenile leaf, 1 shallow lobes, 2 a small young leaf. UV = (x + 0.5, y).
func _blade(shape: int) -> ArrayMesh:
	var deep: float = [1.0, 0.55, 0.75][shape]
	# half outline from the petiole notch round to the apex (x >= 0)
	var half := [Vector2(0.0, 0.07), Vector2(0.2, -0.03), Vector2(0.4, 0.08), Vector2(0.44, 0.15),
			Vector2(0.36, 0.3), Vector2(0.5, 0.48), Vector2(0.47, 0.55), Vector2(0.24, 0.66),
			Vector2(0.1, 0.86), Vector2(0.0, 1.0)]
	var sinus := [4, 7]                    # pulled in by `deep`
	var outline: Array[Vector2] = []
	for i in half.size():
		var q: Vector2 = half[i]
		if i in sinus:
			q = q.lerp(Vector2(0.0, 0.42), 0.38 * deep)
		else:
			q.x *= lerpf(0.82, 1.0, deep)
		outline.append(q)
	for i in range(half.size() - 2, 0, -1):
		var q: Vector2 = outline[i]
		outline.append(Vector2(-q.x, q.y))
	var c := Vector2(0.0, 0.4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := func(q: Vector2) -> Vector3:
		# V fold along the midrib and the rim curling back a touch
		var z := absf(q.x) * 0.28 - q.distance_to(c) * q.distance_to(c) * 0.16
		return Vector3(q.x, q.y, z)
	var n := outline.size()
	for i in n:
		var o0 := outline[i]
		var o1 := outline[(i + 1) % n]
		var i0 := c.lerp(o0, 0.5)
		var i1 := c.lerp(o1, 0.5)
		for tri in [[c, i1, i0], [i0, i1, o1], [i0, o1, o0]]:
			for q in tri:
				st.set_uv(Vector2(q.x + 0.5, q.y))
				st.add_vertex(lift.call(q))
	st.generate_normals()
	return st.commit()
