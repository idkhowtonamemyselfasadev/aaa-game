class_name Ruins
extends Node3D
## The ruined watchtower on the knoll above Harrowmere (Flora.ruin_site), all generated here:
##  - cut stone blocks: rounded boxes with chipped arrises (noise eaten into the bevels and
##    corners), a dozen size variants, instanced through MultiMesh with a per-block tint;
##  - the tower: a round keep of three-leaf ashlar walls (outer face, rubble core, inner
##    face) on rough courses, broken down to a jagged crown with a breach toward the
##    village, slumped top stones, fallen blocks downslope and flagstones/rubble inside;
##  - a curtain wall ring 12.5 m out, mostly robbed down to stepped stubs with gaps.
## Every block that stands above ground gets a box collider.

@export var terrain_path: NodePath
@export var flora_path: NodePath
@export var material: ShaderMaterial
@export var seed: int = 777

const VARIANTS := 12
const BEVEL := 0.045

var site := Vector3.ZERO
var block_count := 0
var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _dims: Array[Vector3] = []          # per variant: full size of the block mesh
var _per: Array = []                    # per variant: [Transform3D, Color]
var _body: StaticBody3D

func _ready() -> void:
	_terrain = get_node(terrain_path)
	var flora: Flora = get_node(flora_path)
	site = flora.ruin_site
	# the keep's sunlit inner face lights its floor and rubble (see bounce.gdshaderinc)
	RenderingServer.global_shader_parameter_set("bounce_zone", Vector4(site.x, site.z, 3.4, 5.0))
	_rng.seed = seed
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		var d := Vector3(_rng.randf_range(0.75, 1.1), _rng.randf_range(0.4, 0.5), _rng.randf_range(0.5, 0.65))
		_dims.append(d)
		meshes.append(_block_mesh(d, v))
		_per.append([])
	_body = StaticBody3D.new()
	_body.name = "RuinCollision"
	add_child(_body)
	_tower()
	_curtain()
	_fallen()
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)

## Wall crown height (m above the site floor) at angle a round the tower.
func _crown(n: FastNoiseLite, a: float, breach: float, lo: float, hi: float) -> float:
	# broad: one or two tall stretches round the ring; fine: a ragged step-down crest
	var broad := n.get_noise_2d(cos(a) * 14.0, sin(a) * 14.0)
	var fine := n.get_noise_2d(cos(a) * 70.0 + 300.0, sin(a) * 70.0) * 0.18
	var h := lerpf(lo, hi, smoothstep(-0.4, 0.45, broad + fine))
	var off := absf(wrapf(a - breach, -PI, PI))
	return lerpf(-0.6, h, smoothstep(0.2, 0.7, off))

func _tower() -> void:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.02
	n.fractal_octaves = 3
	var breach := atan2(-site.z, -site.x)         # toward the village
	var floor_y := site.y
	var base := INF
	for k in 24:
		var a := TAU * k / 24.0
		base = minf(base, _terrain.height_at(site.x + cos(a) * 4.8, site.z + sin(a) * 4.8))
	base -= 0.35
	# three leaves: outer face, core (one course lower at the crown), inner face
	var leaves := [[4.3, 0.62, 0.0], [3.75, 0.5, -0.45], [3.2, 0.6, 0.0]]
	var y := base
	var c := 0
	while y < floor_y + 8.0:
		var ch := _rng.randf_range(0.38, 0.48)
		for lf in leaves:
			var r: float = lf[0]
			var depth: float = lf[1]
			var count := int(round(TAU * r / 0.9))
			var shift := (0.5 if c % 2 == 1 else 0.0) + (0.25 if r < 4.0 else 0.0)
			for i in count:
				var a := TAU * (i + shift) / count
				var p := site + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var gy := _terrain.height_at(p.x, p.z)
				var top := gy + _crown(n, a, breach, 2.2, 7.4) + float(lf[2]) + _rng.randf_range(-0.25, 0.25)
				if y + ch > top:
					continue
				p.y = y + ch * 0.5
				if p.y + ch * 0.5 < gy - 0.05:
					continue                         # buried footing
				var crest := y + ch * 2.0 > top     # top course: loose, slumped, some gone
				if crest and _rng.randf() < 0.15:
					continue
				var tilt := Vector3.ZERO
				if crest:
					tilt = Vector3(_rng.randfn() * 0.06, _rng.randfn() * 0.08, _rng.randfn() * 0.06)
					p += Vector3(cos(a), 0, sin(a)) * _rng.randf_range(-0.05, 0.12)
				var bl := TAU * r / count - 0.03
				_place_ring(p, a, Vector3(bl, ch - 0.02, depth), tilt, maxf(0.0, y - gy))
		y += ch
		c += 1
	# flagstones and rubble on the floor inside
	for i in 70:
		var a := _rng.randf() * TAU
		var rr := sqrt(_rng.randf()) * 2.8
		var p := site + Vector3(cos(a) * rr, 0, sin(a) * rr)
		p.y = _terrain.height_at(p.x, p.z)
		if i < 26:
			var s := Vector3(_rng.randf_range(0.6, 0.9), 0.14, _rng.randf_range(0.45, 0.7))
			p.y -= 0.04
			_place(p, Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.04), s, 0.0, false)
		else:
			_rubble(p, _rng.randf_range(0.35, 0.8))

func _curtain() -> void:
	var n := FastNoiseLite.new()
	n.seed = seed + 9
	n.frequency = 0.03
	n.fractal_octaves = 2
	var gate := atan2(-site.z, -site.x)
	var r := 12.5
	var count := int(round(TAU * r / 0.95))
	for i in count:
		var a := TAU * i / count
		var h := lerpf(-0.6, 1.9, smoothstep(-0.45, 0.45, n.get_noise_2d(cos(a) * 22.0, sin(a) * 22.0) + n.get_noise_2d(cos(a) * 90.0, sin(a) * 90.0) * 0.25))
		if absf(wrapf(a - gate, -PI, PI)) < 0.2:
			continue                                 # the gateway
		var p := site + Vector3(cos(a) * r, 0, sin(a) * r)
		var g := _terrain.height_at(p.x, p.z)
		var y := g - 0.2
		var c := 0
		while y < g + h:
			var ch := _rng.randf_range(0.36, 0.46)
			var aa := a + (0.5 if c % 2 == 1 else 0.0) * TAU / count
			var q := site + Vector3(cos(aa), 0, sin(aa)) * (r + _rng.randf_range(-0.04, 0.04))
			q.y = y + ch * 0.5
			var crest := y + ch * 2.0 > g + h
			var tilt := Vector3(_rng.randfn() * 0.05, _rng.randfn() * 0.07, _rng.randfn() * 0.05) if crest else Vector3.ZERO
			_place_ring(q, aa, Vector3(TAU * r / count - 0.04, ch - 0.02, 0.7), tilt, y - g)
			y += ch
			c += 1
		if h < 0.2 and _rng.randf() < 0.5:
			_rubble(p + Vector3(_rng.randfn(), 0, _rng.randfn()) * 0.8, _rng.randf_range(0.4, 0.9))

## Blocks that fell from the crown: thrown out round the tower, most through the breach
## and down the slope, half sunk in the turf at all angles.
func _fallen() -> void:
	var breach := atan2(-site.z, -site.x)
	for i in 64:
		var a := breach + _rng.randfn() * 0.5 if i < 34 else _rng.randf() * TAU
		var d := _rng.randf_range(4.8, 11.5) if i < 54 else _rng.randf_range(13.5, 22.0)
		var p := site + Vector3(cos(a) * d, 0, sin(a) * d)
		var off := p - site
		var bd := Vector3(cos(breach), 0, sin(breach))
		if absf(off.dot(bd.cross(Vector3.UP))) < 1.3 and off.dot(bd) > 0.0:
			continue                                 # the trodden way in stays clear
		var g := _terrain.height_at(p.x, p.z)
		var v := _rng.randi() % VARIANTS
		var s := _dims[v] * _rng.randf_range(0.85, 1.1)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.5) * Basis(Vector3(0, 0, 1), _rng.randfn() * 0.35)
		p.y = g + s.y * 0.15
		_place(p, b, s, 0.0, true, v)

func _rubble(p: Vector3, s: float) -> void:
	var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.9, 0.9)) * Basis(Vector3(0, 0, 1), _rng.randf_range(-0.6, 0.6))
	p.y = _terrain.height_at(p.x, p.z)
	_place(p, b, Vector3(s, s * 0.55, s * 0.7), 0.0, false)

## A block in a ring wall at angle a: long axis along the circle.
func _place_ring(p: Vector3, a: float, size: Vector3, tilt: Vector3, above: float) -> void:
	var t := Vector3(-sin(a), 0, cos(a))
	var rad := Vector3(cos(a), 0, sin(a))
	var b := Basis(t, Vector3.UP, -rad) * Basis.from_euler(tilt)
	_place(p, b, size, above, true)

func _place(p: Vector3, b: Basis, size: Vector3, above: float, collide: bool, v: int = -1) -> void:
	if v < 0:
		v = _rng.randi() % VARIANTS
	var d: Vector3 = _dims[v]
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	# random flips so the same chips do not line up block after block
	if _rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), p)
	_per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), _rng.randf(), 0, 0)])
	block_count += 1
	if collide and size.x > 0.4:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size.abs() * 0.96
		cs.shape = box
		cs.transform = Transform3D(b.orthonormalized(), p)
		_body.add_child(cs)

## A cut stone of size d: a subdivided box rounded off by BEVEL, its arrises and corners
## chipped with noise, faces slightly dished/bulged.
func _block_mesh(d: Vector3, v: int) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = seed + 50 + v
	n.frequency = 4.0
	n.fractal_octaves = 3
	var h := d * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var u_ax := (axis + 1) % 3
			var v_ax := (axis + 2) % 3
			var us := _ticks(h[u_ax])
			var vs := _ticks(h[v_ax])
			var grid := []
			for iu in us.size():
				var row := []
				for iv in vs.size():
					var p := Vector3.ZERO
					p[axis] = h[axis] * sgn
					p[u_ax] = us[iu]
					p[v_ax] = vs[iv]
					row.append(_shape(p, h, n))
				grid.append(row)
			var fn := Vector3.ZERO
			fn[axis] = sgn
			for iu in us.size() - 1:
				for iv in vs.size() - 1:
					var a: Vector3 = grid[iu][iv]
					var b: Vector3 = grid[iu + 1][iv]
					var c: Vector3 = grid[iu + 1][iv + 1]
					var e: Vector3 = grid[iu][iv + 1]
					# Godot front faces wind clockwise seen from outside
					if (b - a).cross(c - a).dot(fn) > 0.0:
						for q in [a, c, b, a, e, c]:
							st.add_vertex(q)
					else:
						for q in [a, b, c, a, c, e]:
							st.add_vertex(q)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	if material:
		mesh.surface_set_material(0, material)
	return mesh

func _ticks(hh: float) -> PackedFloat32Array:
	var r := BEVEL
	var inner := hh - r
	return PackedFloat32Array([-hh, -hh + r * 0.4, -inner, -inner / 3.0, inner / 3.0, inner, hh - r * 0.4, hh])

func _shape(p: Vector3, h: Vector3, n: FastNoiseLite) -> Vector3:
	var inner := h - Vector3.ONE * BEVEL
	var q := p.clamp(-inner, inner)
	var dd := p - q
	var nrm: Vector3
	var edge := 0.0
	if dd.length() > 0.0001:
		nrm = dd.normalized()
		# on an arris or corner: two or three axes out of the inner box
		var outs := int(absf(dd.x) > 0.001) + int(absf(dd.y) > 0.001) + int(absf(dd.z) > 0.001)
		edge = 0.0 if outs < 2 else 1.0
		p = q + nrm * BEVEL
	else:
		nrm = p.normalized()
	# chips: ragged bites out of the arrises, a gentle bulge/dish over the faces
	var k := n.get_noise_3dv(p)
	# (low-frequency term: faces are hand-dressed, not machined flat)
	var bite := maxf(0.0, k + 0.1) * (0.075 * edge + 0.015) + n.get_noise_3dv(p * 2.3 + Vector3(7, 3, 1)) * 0.012 \
		+ n.get_noise_3dv(p * 0.35 + Vector3(2, 9, 4)) * 0.03
	return p - nrm * bite

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
