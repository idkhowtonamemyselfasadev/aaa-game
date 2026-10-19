class_name StoneCottage
extends Node3D
## A stone cottage of Harrowmere village, across the green north of the timber-framed house
## (Cottage), its door toward the start. All generated here:
##  - walls of coursed rubble: split grey field stones (YardWall's stone mesh, squarer) on
##    beds of uneven height, each stone's top a little ragged under the mortar, dressed
##    sandstone (Ruins' chipped blocks, aged) for the long quoins at the corners
##    bonding alternately into the long walls and the gables, jambs cut square at the door
##    and windows, the gables stepped up under the roof line;
##  - oak lintels over the openings, a tarred plank door on ledges, window frames with a
##    mullion, open shutters, stone sills, a threshold slab and a step;
##  - a 42-degree roof of graded riven slates (big at the eaves, small at the ridge) laid
##    in broken bond on an oak board deck with an eaves and verge overhang, a stone ridge;
##  - a gable-end chimney stack with a cap stone and a thin smoke plume;
##  - lit windows from dusk to bedtime (warm panes and a low lamp inside).
## The walls, roof and floor get box colliders; the door stands open on its hinge side.

@export var ruins_path: NodePath
@export var terrain_path: NodePath
@export var seed: int = 4242

const LEN := 8.4          # outer length along local X (m)
const DEP := 5.6          # outer depth along local Z
const T := 0.6            # wall thickness
const EAVES := 2.7        # wall plate above the floor
const PITCH := 0.733      # roof pitch (rad, 42 degrees)
const DECK := 0.2         # rafters + boards between the wall plate and the slates
const OVER_E := 0.38      # eaves overhang beyond the wall face (horizontal)
const OVER_V := 0.32      # verge overhang beyond the gables
const VARIANTS := 10
const SITE := Vector2(-24.0, 22.0)

## World yaw of the house: its local +z (the door side) faces the village centre.
static func yaw() -> float:
	return atan2(-SITE.x, -SITE.y)

## True when (x, z) lies under the house (walls, stack, eaves) plus `margin`.
static func inside(x: float, z: float, margin: float = 0.0) -> bool:
	var y := yaw()
	var d := Vector2(x - SITE.x, z - SITE.y)
	var lx := d.x * cos(y) - d.y * sin(y)
	var lz := d.x * sin(y) + d.y * cos(y)
	return absf(lx) < LEN * 0.5 + OVER_V + margin and absf(lz) < DEP * 0.5 + OVER_E + margin
const STACK_W := 0.9      # chimney stack (x) by 1.0 (z), on the -X gable

## [wall, centre along the wall from its left end (m, local), sill above floor, width, height]
## walls: 0 front (+Z), 1 back (-Z), 2 east gable (+X), 3 west gable (-X)
const OPENINGS := [
	[0, 0.6, 0.0, 1.0, 1.95],      # door
	[0, -2.5, 0.95, 0.8, 0.85],
	[0, 2.75, 0.95, 0.8, 0.85],
	[1, -1.2, 1.0, 0.75, 0.8],
	[2, 0.0, 1.15, 0.6, 0.6],
]

## Per-house shape (defaults: this stone cottage; WhiteCottage sets its own in _init)
var wlen := LEN
var wdep := DEP
var eaves := EAVES
var openings: Array = OPENINGS
var limewash := false        # rubble and quoins under coats of white lime (WhiteCottage)
var floor_y := 0.0
var base_y := 0.0
var stone_count := 0
var slate_count := 0
var rise := 0.0              # ridge height above the eaves (on the deck's underside)
var smoke: CPUParticles3D
var lamp: OmniLight3D
var panes: ShaderMaterial
var lit := 0.0
var door_gap := Vector3.ZERO  # world centre of the open doorway (bots)
var _ruins: Ruins
var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _dims: Array[Vector3] = []
var _per: Array = []
var _rubble: Array = []        # per split-stone variant: [Transform3D, Color]
var _slates: Array = []        # per slate mesh variant: [Transform3D, Color]
var _slate_meshes: Array[ArrayMesh] = []
var _mortar: Array[Transform3D] = []
var _body: StaticBody3D
var _timber_mat: Shader
var _world: Node

func _ready() -> void:
	_ruins = get_node(ruins_path)
	_terrain = get_node(terrain_path)
	_world = get_parent()
	_rng.seed = seed
	rise = wdep * 0.5 * tan(PITCH)
	_timber_mat = preload("res://shaders/timber.gdshader")
	_level()
	_body = StaticBody3D.new()
	_body.name = "StoneCottageCollision"
	add_child(_body)
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		var d := Vector3(lerpf(0.3, 1.0, (v + _rng.randf()) / VARIANTS), _rng.randf_range(0.2, 0.3), 0.6)
		_dims.append(d)
		meshes.append(_ruins._block_mesh(d, 20 + v))
		_per.append([])
	var rubble: Array[ArrayMesh] = []
	for v in VARIANTS:
		# tight arrises and 5-8 fracture planes cut deep enough to take the corners off, so
		# each face outline is a ragged polygon rather than a rounded tile; little lump and crisp
		# normals, so the faces read as flat split planes, not pillows
		rubble.append(YardWall.stone_mesh(seed + 77, v, _ruins.material, 0.022, 0.012, 0.76, 0.95, true, Vector2i(6, 9), true))
		_rubble.append([])
	_walls()
	_chimney()
	_floor()
	_openings()
	_roof()
	_extras()
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)
		_multimesh(rubble[v], _rubble[v], "Rubble_%d" % v)
	for v in _slate_meshes.size():
		_multimesh(_slate_meshes[v], _slates[v], "Slates_%d" % v)
	_build_mortar()
	_colliders()
	_build_smoke()
	_build_lights()

## Per-house additions laid before the stones and slates are committed (WhiteCottage's
## lean-to): may call _course/_place_rubble/_slates/_mortar like the house itself.
func _extras() -> void:
	pass

## Floor level: a little over the highest ground under the footprint; the footings run down
## below the lowest.
func _level() -> void:
	var hi := -INF
	var lo := INF
	for ix in 5:
		for iz in 4:
			var p := to_global(Vector3((ix / 4.0 - 0.5) * wlen, 0, (iz / 3.0 - 0.5) * wdep))
			var h := _terrain.height_at(p.x, p.z)
			hi = maxf(hi, h)
			lo = minf(lo, h)
	floor_y = hi + 0.12 - global_position.y
	base_y = lo - 0.3 - global_position.y

## Mostly mid courses, now and then a thin snecking course or a deep one of big stones.
func _course_h() -> float:
	var r := _rng.randf()
	if r < 0.18:
		return _rng.randf_range(0.13, 0.18)
	if r > 0.85:
		return _rng.randf_range(0.32, 0.4)
	return _rng.randf_range(0.19, 0.29)

## Lay one course of one wall: wall w spans s in [s0, s1] along its run; y is the course
## bottom, h its height. Openings cut the run; stones are trimmed to the jambs.
func _course(w: int, s0: float, s1: float, y: float, h: float, quoin0: bool, quoin1: bool) -> void:
	var cuts := []
	for o in openings:
		if o[0] != w:
			continue
		var sy: float = floor_y + o[2]
		if y + h > sy + 0.02 and y < sy + o[4] + 0.25:     # (+ the lintel's depth)
			cuts.append([o[1] - o[3] * 0.5, o[1] + o[3] * 0.5])
	# chimney: the stack takes the middle of the west gable above the eaves
	if w == 3 and y + h * 0.5 > floor_y + eaves - 0.05:
		cuts.append([-STACK_W * 0.6, STACK_W * 0.6])
	var segs := [[s0, s1, quoin0, quoin1]]
	for c in cuts:
		var nxt := []
		for sg in segs:
			if c[1] <= sg[0] or c[0] >= sg[1]:
				nxt.append(sg)
				continue
			if c[0] > sg[0] + 0.05:
				nxt.append([sg[0], c[0], sg[2], false])
			if c[1] < sg[1] - 0.05:
				nxt.append([c[1], sg[1], false, sg[3]])
		segs = nxt
	for sg in segs:
		_run(w, sg[0], sg[1], y, h, sg[2], sg[3])

func _run(w: int, a: float, b: float, y: float, h: float, q0: bool, q1: bool) -> void:
	var lens := []
	var s := a
	while s < b - 0.01:
		var ln := _rng.randf_range(0.32, 0.8)
		if q0 and lens.is_empty():
			ln = _rng.randf_range(0.8, 1.0)
		if b - s - ln < 0.28:
			ln = b - s
		lens.append(ln)
		s += ln
	if q1 and lens.size() > 1 and lens[-1] < 0.75:
		# lengthen the end quoin at the expense of its neighbour
		var take := minf(0.8 - lens[-1], lens[-2] - 0.3)
		if take > 0.0:
			lens[-1] += take
			lens[-2] -= take
	_mortar_run(w, (a + b) * 0.5, y + h * 0.5, Vector3(b - a, h, T - 0.06))
	s = a
	for i in lens.size():
		var ln: float = lens[i]
		var quoin := (i == 0 and q0) or (i == lens.size() - 1 and q1)
		# rubble sits on its bed; its top falls short by up to 2.5 cm, the mortar showing above
		var hh := h - 0.012 if quoin else h - 0.012 - _rng.randf_range(0.0, 0.025)
		if not quoin and h > 0.22 and ln < 0.55 and _rng.randf() < 0.3:
			# a sneck: two smaller stones stacked to make up the course height
			var lo := hh * _rng.randf_range(0.5, 0.65)
			_stone(w, s + ln * 0.5, y + lo * 0.5 + 0.004, Vector3(ln - 0.015, lo - 0.01, T), false)
			var l2 := ln * _rng.randf_range(0.55, 0.95)
			var off := _rng.randf_range(0.0, ln - l2)
			_stone(w, s + off + l2 * 0.5, y + lo + (hh - lo) * 0.5 + 0.004, Vector3(l2 - 0.015, hh - lo - 0.01, T), false)
		else:
			_stone(w, s + ln * 0.5, y + hh * 0.5 + 0.004, Vector3(ln - 0.015, hh, T), quoin)
		s += ln

## Wall w's run direction and the cottage-local centre of a point `along` it at height cy.
func _wall_at(w: int, along: float, cy: float) -> Array:
	var dir: Vector3
	var c: Vector3
	match w:
		0:
			dir = Vector3.RIGHT
			c = Vector3(along, cy, wdep * 0.5 - T * 0.5)
		1:
			dir = Vector3.RIGHT
			c = Vector3(along, cy, -wdep * 0.5 + T * 0.5)
		2:
			dir = Vector3.BACK
			c = Vector3(wlen * 0.5 - T * 0.5, cy, along)
		_:
			dir = Vector3.BACK
			c = Vector3(-wlen * 0.5 + T * 0.5, cy, along)
	return [dir, c]

## The lime-mortar core behind a course run, recessed 3 cm from both faces (deeper sank the
## joints into black shadow).
func _mortar_run(w: int, along: float, cy: float, size: Vector3) -> void:
	var wa := _wall_at(w, along, cy)
	var dir: Vector3 = wa[0]
	if limewash:
		# coats laid on thick over the rubble: the lime stands ~6 mm proud of the stones' mean
		# face, so most of them sink under it and only the proud crowns show as soft bumps
		size.z = T + 0.012
	_mortar.append(Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)) * Basis.from_scale(size), wa[1]))

## Place one wall stone: wall-local (along, centre height) -> cottage local.
func _stone(w: int, along: float, cy: float, size: Vector3, quoin: bool) -> void:
	var wa := _wall_at(w, along, cy)
	var dir: Vector3 = wa[0]
	var c: Vector3 = wa[1]
	# faces stand a little proud or sunk (rubble more than the dressed quoins), stones sit a
	# hair off square
	var proud := 0.018 if quoin else 0.032
	if limewash:
		proud *= 0.4     # the coats fill the hollows and round the faces into one skin
	c += dir.cross(Vector3.UP) * _rng.randf_range(-proud, proud)
	var b := Basis(dir, Vector3.UP, dir.cross(Vector3.UP)) * Basis.from_euler(Vector3(_rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.025, 0.025), _rng.randf_range(-0.02, 0.02)))
	if quoin:
		_place(c, b, size, _rng.randf_range(0.5, 0.7), 4.0 if limewash else 1.0)
	else:
		_place_rubble(c, b, size)

## A split field stone of the walling (masonry field mode, INSTANCE_CUSTOM.a = 2).
func _place_rubble(c: Vector3, b: Basis, size: Vector3) -> void:
	# the split cuts eat 5-24 % off each outline, so the stone is laid oversize along the wall
	# and up the course: neighbours then nearly touch and the joints stay narrow
	var sc := size * Vector3(1.07, 1.06, 1.0)
	if _rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), c)
	var above := clampf((c.y - floor_y) / 8.0, 0.0, 1.0)
	_rubble[_rng.randi() % VARIANTS].append([xf, Color(above, _rng.randf(), 1.0, 4.0 if limewash else 2.5)])
	stone_count += 1

## A dressed sandstone block (quoins, sills, flags, ridge), weathered (INSTANCE_CUSTOM.a = 1).
## `mode` is INSTANCE_CUSTOM.a (4 = limewashed).
func _place(c: Vector3, b: Basis, size: Vector3, tint: float, mode := 1.0) -> void:
	var v := _rng.randi() % VARIANTS
	for t in 2:
		var o := _rng.randi() % VARIANTS
		if absf(_dims[o].x - size.x) < absf(_dims[v].x - size.x):
			v = o
	var d: Vector3 = _dims[v]
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	if _rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), c)
	var above := clampf((c.y - floor_y) / 8.0, 0.0, 1.0)
	_per[v].append([xf, Color(above, tint, 1.0, mode)])
	stone_count += 1

## Roof line: the deck underside's height above the floor at local z.
func roof_under(z: float) -> float:
	return eaves + (wdep * 0.5 - absf(z)) * tan(PITCH)

func _walls() -> void:
	var y := base_y
	var k := 0
	var hl := wlen * 0.5
	var hd := wdep * 0.5
	while y < floor_y + eaves - 0.1:
		var h := minf(_course_h(), floor_y + eaves - y)
		var long_full := k % 2 == 0
		if long_full:
			_course(0, -hl, hl, y, h, true, true)
			_course(1, -hl, hl, y, h, true, true)
			_course(2, -hd + T, hd - T, y, h, false, false)
			_course(3, -hd + T, hd - T, y, h, false, false)
		else:
			_course(0, -hl + T, hl - T, y, h, false, false)
			_course(1, -hl + T, hl - T, y, h, false, false)
			_course(2, -hd, hd, y, h, true, true)
			_course(3, -hd, hd, y, h, true, true)
		y += h
		k += 1
	# the gables: stepped courses up under the roof line
	while y < floor_y + roof_under(0.0) - 0.05:
		var h := _course_h()
		var top := y + h - floor_y
		# held 8 cm in from the roof line: the split stones are laid 6-7 % oversize and a
		# hair off square, so a step cut to the line pushed its corner up through the verge;
		# the tabling fills the rest under the deck
		var half := wdep * 0.5 - (top - eaves) / tan(PITCH) - 0.08
		if half < 0.2:
			break
		_course(2, -half, half, y, h, false, false)
		_course(3, -half, half, y, h, false, false)
		y += h
	# tabling: a sloped bed of mortar along each gable top under the deck, filling the
	# stepped triangles the courses leave below the roof line
	var run := wdep * 0.5 / cos(PITCH)
	for gx in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var zc: float = side * wdep * 0.25
			var c := Vector3(gx * (wlen * 0.5 - T * 0.5), floor_y + roof_under(zc) - 0.15 / cos(PITCH), zc)
			_mortar.append(Transform3D(Basis(Vector3.RIGHT, PITCH * side) * Basis.from_scale(Vector3(T + 0.012 if limewash else T - 0.03, 0.3, run)), c))

func _chimney() -> void:
	var x0 := -wlen * 0.5
	var y := floor_y + eaves - 0.05
	var top := floor_y + roof_under(0.0) + DECK + 1.0
	var k := 0
	while y < top:
		var h := _course_h()
		# two stones a course, the joint swapping sides each course
		# (limewashed: the lime skin stands a hair proud of the stones, as on the walls)
		var core := Vector3(STACK_W + 0.012, h, 1.012) if limewash else Vector3(STACK_W - 0.07, h, 0.93)
		_mortar.append(Transform3D(Basis.from_scale(core), Vector3(x0 + STACK_W * 0.5, y + h * 0.5, 0.0)))
		var cut := 0.55 if k % 2 == 0 else 0.45
		var zs := [-0.5, -0.5 + cut, 0.5]
		for i in 2:
			var a: float = zs[i]
			var b: float = zs[i + 1]
			_place_rubble(Vector3(x0 + STACK_W * 0.5, y + h * 0.5, (a + b) * 0.5), Basis(Vector3.BACK, Vector3.UP, Vector3.BACK.cross(Vector3.UP)) * Basis.from_euler(Vector3(0, _rng.randf_range(-0.02, 0.02), 0)), Vector3(b - a - 0.015, h - 0.012, STACK_W))
		y += h
		k += 1
	# the cap: a thin oversailing slab
	_place(Vector3(x0 + STACK_W * 0.5, y + 0.06, 0.0), Basis.IDENTITY, Vector3(STACK_W + 0.16, 0.12, 1.16), 0.3)
	smoke_at = Vector3(x0 + STACK_W * 0.5, y + 0.2, 0.0)

var smoke_at := Vector3.ZERO

## Flagstone floor inside, a threshold slab and a step out of the door.
func _floor() -> void:
	var z := -wdep * 0.5 + T
	while z < wdep * 0.5 - T - 0.05:
		var dz := minf(_rng.randf_range(0.45, 0.75), wdep * 0.5 - T - z)
		var x := -wlen * 0.5 + T
		while x < wlen * 0.5 - T - 0.05:
			var dx := minf(_rng.randf_range(0.5, 0.9), wlen * 0.5 - T - x)
			_place(Vector3(x + dx * 0.5, floor_y - 0.07, z + dz * 0.5), Basis.from_euler(Vector3(0, _rng.randf_range(-0.03, 0.03), 0)), Vector3(dx - 0.02, 0.14, dz - 0.02), _rng.randf())
			x += dx
		z += dz
	var door: Array = openings[0]
	_place(Vector3(door[1], floor_y - 0.06, wdep * 0.5 - T * 0.5), Basis.IDENTITY, Vector3(door[3] + 0.1, 0.14, T + 0.02), 0.5)
	var gy := _terrain.height_at(to_global(Vector3(door[1], 0, wdep * 0.5 + 0.35)).x, to_global(Vector3(door[1], 0, wdep * 0.5 + 0.35)).z) - global_position.y
	var sh := clampf(floor_y - gy, 0.12, 0.5)
	_place(Vector3(door[1], floor_y - sh * 0.5 - 0.02, wdep * 0.5 + 0.32), Basis.from_euler(Vector3(0, 0.03, 0)), Vector3(door[3] + 0.5, sh + 0.12, 0.62), 0.4)
	door_gap = to_global(Vector3(door[1], floor_y + 1.0, wdep * 0.5 - T * 0.5))

## Lintels, door, window frames, sills and shutters.
func _openings() -> void:
	panes = ShaderMaterial.new()
	panes.shader = preload("res://shaders/pane.gdshader")
	for i in openings.size():
		var o: Array = openings[i]
		var w: int = o[0]
		var along: float = o[1]
		var sill: float = o[2]
		var ow: float = o[3]
		var oh: float = o[4]
		var dir := Vector3.RIGHT if w < 2 else Vector3.BACK
		var out := Vector3.BACK if w == 0 else (Vector3.FORWARD if w == 1 else (Vector3.RIGHT if w == 2 else Vector3.LEFT))
		var face_c: Vector3
		match w:
			0: face_c = Vector3(along, 0, wdep * 0.5 - T * 0.5)
			1: face_c = Vector3(along, 0, -wdep * 0.5 + T * 0.5)
			2: face_c = Vector3(wlen * 0.5 - T * 0.5, 0, along)
			_: face_c = Vector3(-wlen * 0.5 + T * 0.5, 0, along)
		var top := floor_y + sill + oh
		# lintel: oak, bearing 0.3 m into the wall on each side
		_beam(face_c + Vector3(0, top + 0.12, 0), dir, ow + 0.6, Vector3(0.24, T - 0.04, 0), float(i), 0.0, out)
		var depth_in := out * (T * 0.5 - 0.12)     # frames sit 12 cm back from the face
		if i == 0:
			# door frame posts and the door itself, open 75 degrees inward on its left hinge
			for sgn in [-1.0, 1.0]:
				_beam(face_c + depth_in + dir * sgn * (ow * 0.5 - 0.05) + Vector3(0, floor_y + oh * 0.5, 0), Vector3.UP, oh, Vector3(0.1, 0.12, 1), 10.0 + sgn, 0.0, out)
			var hinge := face_c + depth_in - out * 0.08 + dir * -(ow * 0.5 - 0.1) + Vector3(0, floor_y, 0)
			var leaf := Node3D.new()
			leaf.name = "Door"
			add_child(leaf)
			leaf.position = hinge
			leaf.basis = Basis(Vector3.UP, deg_to_rad(75.0))
			var dw := ow - 0.2
			var boards := 5
			for bi in boards:
				var bw := dw / boards
				_beam_in(leaf, Vector3((bi + 0.5) * bw, (oh - 0.04) * 0.5 + 0.02, 0), Vector3.UP, oh - 0.06, Vector3(bw - 0.006, 0.04, 1), 20.0 + bi, 1.0)
			for ly in [0.3, oh - 0.35]:
				_beam_in(leaf, Vector3(dw * 0.5, ly, -0.045), Vector3.RIGHT, dw - 0.06, Vector3(0.12, 0.05, 1), 30.0 + ly, 1.0)
			continue
		# window: a frame of four sticks and a mullion, a sill stone, the pane, two shutters
		var wc := face_c + depth_in + Vector3(0, floor_y + sill + oh * 0.5, 0)
		for sgn in [-1.0, 1.0]:
			_beam(wc + dir * sgn * (ow * 0.5 - 0.035), Vector3.UP, oh, Vector3(0.07, 0.09, 1), 40.0 + i + sgn, 0.0, out)
			_beam(wc + Vector3(0, sgn * (oh * 0.5 - 0.035), 0), dir, ow - 0.14, Vector3(0.07, 0.09, 1), 50.0 + i + sgn, 0.0, out)
		_beam(wc, Vector3.UP, oh - 0.14, Vector3(0.05, 0.07, 1), 60.0 + i, 0.0, out)
		var pane := MeshInstance3D.new()
		var pq := QuadMesh.new()
		pq.size = Vector2(ow - 0.1, oh - 0.1)
		pane.mesh = pq
		pane.material_override = panes
		add_child(pane)
		pane.position = wc - out * 0.02
		pane.basis = Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		if dir.cross(Vector3.UP).dot(out) < 0.0:
			pane.basis = Basis(Vector3.UP, PI) * pane.basis
		var sb := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		_place(face_c + out * 0.06 + Vector3(0, floor_y + sill - 0.06, 0), sb, Vector3(ow + 0.24, 0.12, T + 0.12), 0.45)
		# shutters, folded back flat against the wall either side
		for sgn in [-1.0, 1.0]:
			var sc: Vector3 = face_c + out * (T * 0.5 + 0.03) + dir * sgn * (ow * 0.5 + ow * 0.25 + 0.04) + Vector3(0, floor_y + sill + oh * 0.5, 0)
			for bi in 3:
				var bw := ow * 0.5 / 3.0
				_beam(sc + dir * (bi - 1) * bw, Vector3.UP, oh, Vector3(bw - 0.005, 0.03, 1), 70.0 + i * 3 + bi + sgn, 1.0, out)

## A squared oak timber: centre c, long axis along `axis`, cross-section (w, d) where w
## lies across in the wall plane and d through the wall (`face` normal).
func _beam(c: Vector3, axis: Vector3, ln: float, wd: Vector3, sd: float, tar := 0.0, face := Vector3.ZERO) -> MeshInstance3D:
	return _beam_in(self, c, axis, ln, wd, sd, tar, face)

func _beam_in(parent: Node3D, c: Vector3, axis: Vector3, ln: float, wd: Vector3, sd: float, tar := 0.0, face := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(wd.x, ln, wd.y)
	var m := ShaderMaterial.new()
	m.shader = _timber_mat
	m.set_shader_parameter("seed", sd)
	m.set_shader_parameter("tar", tar)
	bm.material = m
	mi.mesh = bm
	parent.add_child(mi)
	mi.position = c
	var y := axis.normalized()
	var z := face if face != Vector3.ZERO else (Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT)
	if absf(y.dot(z)) > 0.9:
		z = Vector3.RIGHT
	# wall-plane beams: across the wall is x, through the wall is z
	if face == Vector3.ZERO and parent == self:
		z = Vector3.FORWARD if absf(y.x) > 0.5 or absf(y.y) > 0.5 else Vector3.RIGHT
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	mi.basis = Basis(x, y, z)
	return mi

## The roof: board decks on both slopes and graded slates in broken bond, a stone ridge.
func _roof() -> void:
	for v in 4:
		_slate_meshes.append(_slate_mesh(v))
		_slates.append([])
	var half_len := wlen * 0.5 + OVER_V
	var run := (wdep * 0.5 + OVER_E) / cos(PITCH)       # deck length ridge -> eaves edge
	for side in [-1.0, 1.0]:
		var down := Vector3(0, -sin(PITCH), cos(PITCH) * side)
		var nrm := Vector3(0, cos(PITCH), sin(PITCH) * side)
		var ridge := Vector3(0, floor_y + roof_under(0.0), 0)
		# deck: rafters + boards, its underside on the roof line
		var deck := _beam(ridge + down * run * 0.5 + nrm * DECK * 0.5, Vector3.RIGHT, half_len * 2.0, Vector3(run, DECK, 1), 90.0 + side, 0.0, nrm)
		deck.name = "Deck"
		var top := ridge + nrm * DECK
		# slates from the eaves up: each course's tail `margin` above the one below
		var s := run + 0.04          # tail of the eaves course, just past the boards
		var k := 0
		while s > 0.12:
			var u := clampf(s / run, 0.0, 1.0)
			var ln := lerpf(0.3, 0.46, u)
			var margin := (ln - 0.08) * 0.5
			var x := -half_len - (_rng.randf_range(0.0, 0.14) if k % 2 == 0 else _rng.randf_range(0.12, 0.22))
			while x < half_len:
				var wdt := _rng.randf_range(0.2, 0.3)
				var cx := clampf(x + wdt * 0.5, -half_len + 0.1, half_len - 0.1)
				var tail := top + down * s + Vector3(cx, 0, 0)
				var head := tail - down * ln
				var c := (tail + head) * 0.5 + nrm * (0.014 + _rng.randf_range(0.0, 0.006))
				# kick: the tail rides up on the two slates below
				var b := Basis(nrm.cross(down), nrm, down).orthonormalized()
				b = b * Basis.from_euler(Vector3(-0.03, _rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.012, 0.012)))
				var mv := _rng.randi() % 4
				var xf := Transform3D(b * Basis.from_scale(Vector3(wdt / 0.25, 1.0, ln / 0.4)), c)
				var stack_d := Vector2(c.x - smoke_at.x, c.z - smoke_at.z).length()
				_slates[mv].append([xf, Color(u, _rng.randf(), 0.0, clampf(stack_d / 4.0, 0.0, 1.0))])
				slate_count += 1
				x += wdt + 0.004
			s -= margin
			k += 1
	# ridge: saddle stones along the apex
	var rt := Vector3(0, floor_y + roof_under(0.0) + DECK, 0)
	var x := -wlen * 0.5 - OVER_V
	while x < wlen * 0.5 + OVER_V - 0.1:
		var ln := minf(_rng.randf_range(0.4, 0.55), wlen * 0.5 + OVER_V - x)
		if x + ln * 0.5 > -wlen * 0.5 + STACK_W + 0.05 or x + ln * 0.5 < -wlen * 0.5 - 0.05:
			_place(Vector3(x + ln * 0.5, rt.y + 0.06, 0), Basis.from_euler(Vector3(0, _rng.randf_range(-0.02, 0.02), 0)), Vector3(ln - 0.01, 0.16, 0.36), 0.15)
		x += ln

## One slate: 0.25 m wide (x) by 0.4 m long (z, head at -z, tail at +z), 12 mm thick,
## the tail corners clipped and its edge chipped.
func _slate_mesh(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7 + v
	var pts := PackedVector2Array()
	var hw := 0.125
	pts.append(Vector2(-hw, -0.2))
	pts.append(Vector2(hw, -0.2))
	# right edge down to the tail, the tail edge chipped, back up the left edge
	pts.append(Vector2(hw + r.randf_range(-0.004, 0.0), 0.0))
	var clip := r.randf_range(0.015, 0.04)
	pts.append(Vector2(hw - r.randf_range(0.0, 0.006), 0.2 - clip))
	for i in 5:
		var t := float(i + 1) / 6.0
		pts.append(Vector2(lerpf(hw - clip, -hw + clip, t), 0.2 - r.randf_range(0.0, 0.012)))
	pts.append(Vector2(-hw + r.randf_range(0.0, 0.006), 0.2 - clip * r.randf_range(0.6, 1.2)))
	pts.append(Vector2(-hw + r.randf_range(0.0, 0.004), 0.0))
	var th := 0.006
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= pts.size()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		# top (+y) and bottom faces (fans round the centroid), front faces clockwise from outside
		var ta := Vector3(a.x, th, a.y)
		var tb := Vector3(b.x, th, b.y)
		var tc := Vector3(cen.x, th, cen.y)
		var ba := Vector3(a.x, -th, a.y)
		var bb := Vector3(b.x, -th, b.y)
		var bc := Vector3(cen.x, -th, cen.y)
		for q in _wind([tc, ta, tb], Vector3.UP):
			st.add_vertex(q)
		for q in _wind([bc, ba, bb], Vector3.DOWN):
			st.add_vertex(q)
		var out := Vector3(b.y - a.y, 0, -(b.x - a.x))
		for q in _wind([ta, ba, bb], out):
			st.add_vertex(q)
		for q in _wind([ta, bb, tb], out):
			st.add_vertex(q)
	st.generate_normals()
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/slate.gdshader")
	mesh.surface_set_material(0, m)
	return mesh

func _wind(tri: Array, fn: Vector3) -> Array:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	if (b - a).cross(c - a).dot(fn) > 0.0:
		return [a, c, b]
	return [a, b, c]

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

func _build_mortar() -> void:
	var bm := BoxMesh.new()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/mortar.gdshader")
	m.set_shader_parameter("ground_y", global_position.y + floor_y)
	# pointing weathered back and dirtied toward the gritstone's grey, so the joints read as
	# shadowed gaps between the stones instead of an even pale outline round each one
	m.set_shader_parameter("lime", Color(0.5, 0.47, 0.41))
	m.set_shader_parameter("grime", Color(0.25, 0.23, 0.2))
	if limewash:
		# the lime coats run over the pointing too: only a faint shadow line between stones
		m.set_shader_parameter("wash", 1.0)
	bm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = _mortar.size()
	for i in _mortar.size():
		mm.set_instance_transform(i, _mortar[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Mortar"
	mmi.multimesh = mm
	add_child(mmi)

func _box(c: Vector3, size: Vector3, b := Basis.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(b, c)
	_body.add_child(cs)

func _colliders() -> void:
	var hl := wlen * 0.5
	var hd := wdep * 0.5
	var h := floor_y + eaves - base_y
	var cy := base_y + h * 0.5
	var door: Array = openings[0]
	var dl: float = door[1] - door[3] * 0.5
	var dr: float = door[1] + door[3] * 0.5
	# front wall either side of the door, and over it
	_box(Vector3((-hl + dl) * 0.5, cy, hd - T * 0.5), Vector3(dl + hl, h, T))
	_box(Vector3((dr + hl) * 0.5, cy, hd - T * 0.5), Vector3(hl - dr, h, T))
	var dtop: float = floor_y + door[4]
	_box(Vector3(door[1], (dtop + floor_y + eaves) * 0.5, hd - T * 0.5), Vector3(door[3], floor_y + eaves - dtop, T))
	_box(Vector3(0, cy, -hd + T * 0.5), Vector3(wlen, h, T))
	var gh := floor_y + roof_under(0.0) - base_y
	for sgn in [-1.0, 1.0]:
		_box(Vector3(sgn * (hl - T * 0.5), base_y + gh * 0.5, 0), Vector3(T, gh, wdep))
	# the floor slab
	_box(Vector3(0, (floor_y + base_y) * 0.5, 0), Vector3(wlen - T * 2.0, floor_y - base_y, wdep - T * 2.0))
	# both roof slopes
	var run := (wdep * 0.5 + OVER_E) / cos(PITCH)
	for side in [-1.0, 1.0]:
		var down := Vector3(0, -sin(PITCH), cos(PITCH) * side)
		var nrm := Vector3(0, cos(PITCH), sin(PITCH) * side)
		var c := Vector3(0, floor_y + roof_under(0.0), 0) + down * run * 0.5 + nrm * (DECK * 0.5 + 0.02)
		_box(c, Vector3(wlen + OVER_V * 2.0, DECK + 0.04, run), Basis(nrm.cross(down), nrm, down).orthonormalized())
	# a ramp under the door step, so the threshold can be walked up onto
	var gy := _terrain.height_at(to_global(Vector3(dl, 0, hd + 1.2)).x, to_global(Vector3(dl, 0, hd + 1.2)).z) - global_position.y
	var rise_s := floor_y - gy
	if rise_s > 0.02:
		var ang := atan2(rise_s, 1.2)
		_box(Vector3(door[1], floor_y - rise_s * 0.5 - 0.06, hd + 0.6), Vector3(door[3] + 0.4, 0.12, sqrt(1.44 + rise_s * rise_s)), Basis(Vector3.RIGHT, ang))
	# chimney stack
	var st := floor_y + roof_under(0.0) + DECK + 1.0
	_box(Vector3(-hl + STACK_W * 0.5, (floor_y + eaves + st) * 0.5, 0), Vector3(STACK_W, st - floor_y - eaves, 1.0))

func _puff_tex() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 47
	n.frequency = 0.07
	n.fractal_octaves = 4
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5)
			var a := (1.0 - smoothstep(0.2, 1.0, d)) * clampf(0.55 + n.get_noise_2d(x, y) * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## A thin peat-smoke plume from the stack, leaning off downwind as it climbs.
func _build_smoke() -> void:
	smoke = CPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.amount = 34
	smoke.lifetime = 9.0
	smoke.preprocess = 9.0
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.12
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.22, 0.05, 0.14)
	smoke.damping_min = 0.04
	smoke.damping_max = 0.1
	smoke.angle_max = 360.0
	smoke.angular_velocity_min = -8.0
	smoke.angular_velocity_max = 8.0
	var gc := Curve.new()
	gc.add_point(Vector2(0.0, 0.3))
	gc.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = gc
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 1.8
	var mg := Gradient.new()
	mg.set_color(0, Color(0.45, 0.44, 0.43, 0.0))
	mg.set_color(1, Color(0.55, 0.55, 0.56, 0.0))
	mg.add_point(0.1, Color(0.42, 0.41, 0.4, 0.22))
	mg.add_point(0.6, Color(0.5, 0.5, 0.5, 0.1))
	smoke.color_ramp = mg
	var pq := QuadMesh.new()
	pq.size = Vector2(1.1, 1.1)
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = _puff_tex()
	pm.roughness = 1.0
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pq.material = pm
	smoke.mesh = pq
	add_child(smoke)
	smoke.position = smoke_at

func _build_lights() -> void:
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color(1.0, 0.62, 0.34)
	lamp.omni_range = 7.0
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(1.2, floor_y + 1.4, -0.6)

## World points every ~`step` m round the walls (and along the middle), for steering.
func outline(step: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var nx := ceili(wlen / step)
	var nz := ceili(wdep / step)
	for i in nx + 1:
		for j in nz + 1:
			if i == 0 or j == 0 or i == nx or j == nz or j == nz / 2:
				pts.append(to_global(Vector3((float(i) / nx - 0.5) * wlen, 0, (float(j) / nz - 0.5) * wdep)))
	return pts

## 0..1: how lit the windows are at hour h (lamps from dusk to bedtime, a candle at dawn).
static func lit_for(h: float) -> float:
	if h >= 17.6 and h < 22.5:
		return smoothstep(17.6, 18.4, h) * (1.0 - smoothstep(22.0, 22.5, h))
	if h >= 5.4 and h < 6.6:
		return smoothstep(5.4, 5.6, h) * (1.0 - smoothstep(6.2, 6.6, h)) * 0.6
	return 0.0

func _process(_delta: float) -> void:
	var h: float = _world.time_of_day if "time_of_day" in _world else 12.0
	lit = lit_for(h)
	panes.set_shader_parameter("lit", lit)
	lamp.light_energy = lit * 1.6
	lamp.visible = lit > 0.01
