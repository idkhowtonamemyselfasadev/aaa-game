class_name DryWall
extends Node3D
## The dry-stone garth wall round the yard behind Harrowmere's stone cottage (StoneCottage):
## three runs from the back corners out round a yard, a gateway with two upright gate stoops
## on the east side. Built the way a waller lays it, all generated here:
##  - two battered faces of rough sandstone rubble (no mortar) in irregular courses that
##    follow the ground, each stone a hair off square, the faces leaning in toward the top;
##  - through-stones across the whole width at half height, their ends standing proud;
##  - a dark hearting of small packing between the faces, seen only in the gaps;
##  - a cope of stones set on edge along the top, leaning a little downhill;
##  - curtain-wall weathering (the masonry shader's `aged`): grey crust, lichen, moss tops.
## Stones are Ruins' chipped block meshes built at twice size and scaled down, so their bevel
## and chips are half as round as the cottage's. Box colliders per 1.5 m piece; grass,
## flowers and the herd keep off its footing (`near`).

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 5151

const BASE_W := 0.74     # width at the foot (m)
const TOP_W := 0.46      # width under the cope
const BODY_H := 0.86     # height of the battered body above the ground
const DEPTH := 0.3       # how far a face stone runs into the wall
const VARIANTS := 10
const GATE_W := 1.3      # clear width of the gateway between the stoops
## The runs in the stone cottage's local frame (x along its length, -z behind it): from the
## east gable round the back of the yard to the west gable. The gateway is on run 0.
const RUNS_LOCAL := [
	[Vector2(3.9, -3.25), Vector2(4.7, -10.2)],
	[Vector2(4.7, -10.2), Vector2(-5.3, -10.7)],
	[Vector2(-5.3, -10.7), Vector2(-3.9, -3.25)],
]
const GATE_AT := 0.45    # gateway centre as a fraction along run 0

var stone_count := 0
var cope_count := 0
var through_count := 0
var gate := Vector3.ZERO      # world centre of the gateway (bots)
var _ruins: Ruins
var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _dims: Array[Vector3] = []
var _per: Array = []
var _core: Array[Transform3D] = []
var _body: StaticBody3D

## Cottage-local (x, z) -> world (x, z).
static func _to_world(l: Vector2) -> Vector2:
	var y := StoneCottage.yaw()
	return StoneCottage.SITE + Vector2(l.x * cos(y) + l.y * sin(y), -l.x * sin(y) + l.y * cos(y))

## The built runs in world xz, with the gateway cut out of run 0: [[a, b], ...].
static func segments() -> Array:
	var out := []
	for i in RUNS_LOCAL.size():
		var a := _to_world(RUNS_LOCAL[i][0])
		var b := _to_world(RUNS_LOCAL[i][1])
		if i == 0:
			var ln := a.distance_to(b)
			var d := (b - a) / ln
			var g := a + d * ln * GATE_AT
			out.append([a, g - d * GATE_W * 0.5])
			out.append([g + d * GATE_W * 0.5, b])
		else:
			out.append([a, b])
	return out

## True when (x, z) lies on the wall's footing plus `margin`.
static func near(x: float, z: float, margin: float = 0.0) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(StoneCottage.SITE) > 14.0:
		return false
	for s in segments():
		var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		if p.distance_to(q) < BASE_W * 0.5 + margin:
			return true
	return false

func _ready() -> void:
	_ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	_rng.seed = seed
	_body = StaticBody3D.new()
	_body.name = "DryWallCollision"
	add_child(_body)
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		# twice the laid size: scaled by ~0.5 when placed, so the 6 cm bevel becomes ~3 cm
		var d := Vector3(lerpf(0.5, 1.1, (v + _rng.randf()) / VARIANTS), _rng.randf_range(0.28, 0.42), 0.6)
		_dims.append(d)
		meshes.append(_ruins._block_mesh(d, 60 + v))
		_per.append([])
	var segs := segments()
	for i in segs.size():
		_lay(segs[i][0], segs[i][1], i == 0, i == 1)
	var a0 := _to_world(RUNS_LOCAL[0][0])
	var b0 := _to_world(RUNS_LOCAL[0][1])
	var g := a0.lerp(b0, GATE_AT)
	gate = Vector3(g.x, _terrain.height_at(g.x, g.y), g.y)
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)
	_build_core()

func _ground(p: Vector2) -> float:
	return _terrain.height_at(p.x, p.y) - global_position.y

## Half width of the battered body at height y above the ground.
func _hw(y: float) -> float:
	return lerpf(BASE_W, TOP_W, clampf(y / BODY_H, 0.0, 1.0)) * 0.5

## Lay one run from a to b (world xz). stoop_b / stoop_a: an upright gate stoop ends it.
func _lay(a: Vector2, b: Vector2, stoop_b: bool, stoop_a: bool) -> void:
	var ln := a.distance_to(b)
	var d2 := (b - a) / ln
	var dir := Vector3(d2.x, 0, d2.y)
	var nrm := dir.cross(Vector3.UP)          # face normal of the +1 face
	var batter := atan((BASE_W - TOP_W) * 0.5 / BODY_H)
	# each face: courses that thin toward the top, stones of random length, broken joints
	for face in [-1.0, 1.0]:
		var y := 0.0
		var course := 0
		while y < BODY_H - 0.06:
			var h := _rng.randf_range(0.13, 0.21) * lerpf(1.15, 0.8, y / BODY_H)
			h = minf(h, BODY_H - y)
			var s := _rng.randf_range(0.0, 0.25) if course % 2 == 0 else 0.0
			if s > 0.05:
				_face_stone(a, d2, dir, nrm, face, s * 0.5, y, Vector3(s - 0.02, h, DEPTH), batter)
			while s < ln - 0.02:
				var sl := _rng.randf_range(0.16, 0.56)
				if ln - s - sl < 0.14:
					sl = ln - s
				# rubble, not ashlar: some stones fall short of the course and a thin pinning
				# stone is tucked in over them; others stand a little proud of it
				var sh := h * _rng.randf_range(0.62, 1.08)
				var lift := _rng.randf_range(-0.015, 0.02)
				_face_stone(a, d2, dir, nrm, face, s + sl * 0.5, y + lift, Vector3(sl - 0.03, sh - 0.012, DEPTH * _rng.randf_range(0.85, 1.1)), batter)
				if sh < h * 0.82 and sl > 0.22:
					var ph := h - sh - 0.02
					_face_stone(a, d2, dir, nrm, face, s + sl * _rng.randf_range(0.35, 0.65), y + lift + sh, Vector3(sl * _rng.randf_range(0.45, 0.8), maxf(ph, 0.04), DEPTH * 0.6), batter)
				s += sl
			y += h
			course += 1
	# through-stones at half height, every ~0.9 m, ends proud of both faces
	var t := _rng.randf_range(0.3, 0.6)
	while t < ln - 0.3:
		var p := a + d2 * t
		var yy := 0.42 + _rng.randf_range(-0.04, 0.04)
		var w := _hw(yy) * 2.0 + 0.12
		var c := Vector3(p.x - global_position.x, _ground(p) + yy, p.y - global_position.z)
		var bas := Basis(nrm, Vector3.UP, -dir) * Basis.from_euler(Vector3(_rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.04, 0.04)))
		_place(c, bas, Vector3(w, _rng.randf_range(0.1, 0.14), _rng.randf_range(0.22, 0.32)), yy)
		through_count += 1
		t += _rng.randf_range(0.8, 1.05)
	# the cope: stones on edge across the top, leaning a little downhill
	var lean := clampf((_ground(b) - _ground(a)) / ln * 2.0, -0.15, 0.15)
	var s2 := 0.06
	while s2 < ln - 0.05:
		var th := _rng.randf_range(0.07, 0.15)
		var p := a + d2 * (s2 + th * 0.5)
		var ch := _rng.randf_range(0.2, 0.36)
		var c := Vector3(p.x - global_position.x, _ground(p) + BODY_H + ch * 0.5 - 0.03, p.y - global_position.z)
		var bas := Basis(nrm, Vector3.UP, -dir) * Basis.from_euler(Vector3(lean + _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.14, 0.14), _rng.randf_range(-0.07, 0.07)))
		_place(c, bas, Vector3(TOP_W + _rng.randf_range(-0.02, 0.06), ch, th), BODY_H + ch * 0.5)
		cope_count += 1
		s2 += th + _rng.randf_range(0.0, 0.025)
	if stoop_b:
		_stoop(b, d2)
	if stoop_a:
		_stoop(a, -d2)
	# hearting between the faces, and the colliders, in pieces that follow the ground
	var n := maxi(1, ceili(ln / 1.5))
	for k in n:
		var m := a + d2 * ln * (k + 0.5) / n
		var gy := minf(_ground(a + d2 * ln * k / n), _ground(a + d2 * ln * (k + 1) / n))
		var pl := ln / n
		var bas := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		_core.append(Transform3D(bas * Basis.from_scale(Vector3(pl, BODY_H - 0.04, TOP_W + 0.02)), Vector3(m.x - global_position.x, gy + (BODY_H - 0.04) * 0.5, m.y - global_position.z)))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(pl, BODY_H + 0.6, BASE_W - 0.1)
		cs.shape = box
		cs.transform = Transform3D(bas, Vector3(m.x - global_position.x, gy + (BODY_H + 0.6) * 0.5 - 0.3, m.y - global_position.z))
		_body.add_child(cs)

## One face stone: `along` from a, its bed at y above the ground, on face `face` (+-1).
func _face_stone(a: Vector2, d2: Vector2, dir: Vector3, nrm: Vector3, face: float, along: float, y: float, size: Vector3, batter: float) -> void:
	var p := a + d2 * along
	var cy := y + size.y * 0.5
	var off := _hw(cy) - size.z * 0.5 + _rng.randf_range(-0.02, 0.025)
	var c := Vector3(p.x - global_position.x, _ground(p) + cy, p.y - global_position.z) + nrm * face * off
	# batter: the face leans in toward the top (rotating about dir tips UP toward +nrm)
	var bas := Basis(dir, -batter * face) * Basis(dir, Vector3.UP, nrm)
	bas = bas * Basis.from_euler(Vector3(_rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.11, 0.11)))
	_place(c, bas, size, cy)

## An upright gate stoop at the end p of a run, d pointing out of the wall into the gap.
func _stoop(p: Vector2, d: Vector2) -> void:
	var q := p - d * 0.15     # it takes the last stones of the run: the gap stays clear
	var h := BODY_H + 0.55
	var dir := Vector3(d.x, 0, d.y)
	var c := Vector3(q.x - global_position.x, _ground(q) + h * 0.5 - 0.12, q.y - global_position.z)
	var bas := Basis(dir.cross(Vector3.UP), Vector3.UP, -dir) * Basis.from_euler(Vector3(_rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.03, 0.03)))
	_place(c, bas, Vector3(0.6, h, 0.32), h * 0.5)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, h, 0.32)
	cs.shape = box
	cs.transform = Transform3D(bas.orthonormalized(), c)
	_body.add_child(cs)

func _place(c: Vector3, b: Basis, size: Vector3, above: float) -> void:
	var v := _rng.randi() % VARIANTS
	for t in 2:
		var o := _rng.randi() % VARIANTS
		if absf(_dims[o].x - size.x * 2.0) < absf(_dims[v].x - size.x * 2.0):
			v = o
	var d: Vector3 = _dims[v]
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	if _rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), c)
	_per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), _rng.randf(), 1.0, 1.0)])
	stone_count += 1

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

## The hearting: small packing stones between the faces, read as a dark, rough core in the
## gaps (no mortar in a dry wall).
func _build_core() -> void:
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.12, 0.1)
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

## World points every ~`step` m along the runs, for steering.
func outline(step: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for s in segments():
		var ln: float = (s[0] as Vector2).distance_to(s[1])
		var n := maxi(1, ceili(ln / step))
		for k in n + 1:
			var p: Vector2 = (s[0] as Vector2).lerp(s[1], float(k) / n)
			pts.append(Vector3(p.x, _terrain.height_at(p.x, p.y), p.y))
	return pts
