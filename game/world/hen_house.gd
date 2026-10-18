class_name HenHouse
extends Node3D
## The hens' house in the garth (Hens): a small feather-boarded oak house stood on four posts
## against the west wall near the back, with a pent roof of tarred lapped boards falling to
## the wall, a nest box hung off its south end under a lift-up lid, and a pop-hole in the
## yard face with a slatted ladder down to the dust. At dusk the hens queue at the ladder's
## foot and go up it one at a time into the house; at first light they come down again one
## after another. Child of the stone cottage; all coordinates are in the cottage's frame
## (x along its length, -z behind it into the garth).

const CENTRE := Vector2(-3.65, -8.55)   # house centre (cottage-local xz)
const SIZE := Vector2(0.95, 1.15)       # body, x across (the yard face at +x) by z long
const FLOOR := 0.48                     # floor height above the ground
const WALL_FRONT := 0.82                # eaves height above the floor at the yard face
const WALL_BACK := 0.6                  # and at the wall side (the roof falls west)
const HOLE := Vector2(0.24, 0.3)        # pop-hole width (z) by height
const LADDER := 0.95                    # ladder run out from the yard face (x)

var terrain: Terrain
var base_y := 0.0                       # floor's foot level, world y, at the house
var boards := 0                         # pieces of oak built (bots)
var _timber: Shader
var _iron: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

func setup(t: Terrain) -> void:
	terrain = t
	_rng.seed = 4419
	_timber = preload("res://shaders/timber.gdshader")
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.17, 0.12, 0.09)
	_iron.metallic = 0.55
	_iron.roughness = 0.82
	name = "HenHouse"
	_build()

## The ground under the ladder's foot, where they queue (cottage-local).
static func foot() -> Vector2:
	return Vector2(CENTRE.x + SIZE.x * 0.5 + LADDER + 0.12, CENTRE.y)

## The pop-hole sill (cottage-local) and a step inside it.
static func sill() -> Vector2:
	return Vector2(CENTRE.x + SIZE.x * 0.5, CENTRE.y)

static func inside() -> Vector2:
	return Vector2(CENTRE.x + SIZE.x * 0.5 - 0.25, CENTRE.y)

## True when a local point lies under the house or its ladder (hens potter round it).
static func covers(l: Vector2, pad := 0.0) -> bool:
	return l.x > CENTRE.x - SIZE.x * 0.5 - pad and l.x < CENTRE.x + SIZE.x * 0.5 + LADDER + pad \
		and absf(l.y - CENTRE.y) < SIZE.y * 0.5 + 0.35 + pad

## World y of the sill (the ladder's top).
func sill_y() -> float:
	return base_y + FLOOR + 0.03

func _ground(l: Vector2) -> float:
	var g := get_parent().to_global(Vector3(l.x, 0, l.y)) as Vector3
	return terrain.height_at(g.x, g.z)

func _build() -> void:
	var hx := SIZE.x * 0.5
	var hz := SIZE.y * 0.5
	var corners := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	# stand it level on the highest of its four corners
	base_y = -INF
	for c: Vector2 in corners:
		base_y = maxf(base_y, _ground(CENTRE + c))
	var par := get_parent() as Node3D
	position = par.to_local(Vector3(0, base_y, 0) + par.to_global(Vector3(CENTRE.x, 0, CENTRE.y)) * Vector3(1, 0, 1))
	var fl := FLOOR
	# posts: 7 cm oak, down into the ground at each corner, a hair splayed
	for c: Vector2 in corners:
		var g := _ground(CENTRE + c) - base_y
		var p := Vector3(c.x * 0.92, 0, c.y * 0.92)
		_oak(p + Vector3(0, g - 0.1, 0), p + Vector3(0, fl + 0.05, 0), 0.07, 0.07, Vector3.BACK)
	# floor: sole plates along the long sides, boards across them
	for s in [-1.0, 1.0]:
		_oak(Vector3(s * (hx - 0.04), fl - 0.04, -hz), Vector3(s * (hx - 0.04), fl - 0.04, hz), 0.06, 0.07, Vector3.RIGHT)
	_oak(Vector3(-hx, fl, 0), Vector3(hx, fl, 0), SIZE.y, 0.025, Vector3.UP)
	# walls: feather-edge boards set upright, each a touch different in width and lean
	var hf := WALL_FRONT
	var hb := WALL_BACK
	var x := -hx
	while x < hx - 0.01:
		var w := minf(_rng.randf_range(0.1, 0.135), hx - x)
		var xm := x + w * 0.5
		var top := lerpf(hb, hf, (xm + hx) / SIZE.x)
		for s in [-1.0, 1.0]:
			_board(Vector3(xm, fl - 0.06, s * (hz + 0.012)), top + 0.06, w + 0.012, Vector3(0, 0, s))
		x += w
	var z := -hz
	while z < hz - 0.01:
		var w := minf(_rng.randf_range(0.1, 0.135), hz - z)
		var zm := z + w * 0.5
		# the yard face: the pop-hole cut out of the boards round the middle
		if absf(zm) < HOLE.x * 0.5 + 0.02:
			_board(Vector3(hx + 0.012, fl + HOLE.y + 0.02, zm), hf - HOLE.y - 0.02, w + 0.012, Vector3.RIGHT)
			_board(Vector3(hx + 0.012, fl - 0.06, zm), 0.08, w + 0.012, Vector3.RIGHT)
		else:
			_board(Vector3(hx + 0.012, fl - 0.06, zm), hf + 0.06, w + 0.012, Vector3.RIGHT)
		_board(Vector3(-hx - 0.012, fl - 0.06, zm), hb + 0.06, w + 0.012, Vector3.LEFT)
		z += w
	# corner battens and a top plate under the eaves
	for c: Vector2 in corners:
		var top := hf if c.x > 0 else hb
		_oak(Vector3(c.x * 1.02, fl - 0.06, c.y * 1.02), Vector3(c.x * 1.02, fl + top, c.y * 1.02), 0.045, 0.045, Vector3.BACK)
	# pop-hole: a frame, and the slide shutter propped up in its guides above it
	var hz2 := HOLE.x * 0.5
	for s in [-1.0, 1.0]:
		_oak(Vector3(hx + 0.03, fl, s * (hz2 + 0.02)), Vector3(hx + 0.03, fl + HOLE.y + 0.32, s * (hz2 + 0.02)), 0.03, 0.025, Vector3.RIGHT)
	_oak(Vector3(hx + 0.035, fl + 0.005, -hz2 - 0.03), Vector3(hx + 0.035, fl + 0.005, hz2 + 0.03), 0.03, 0.03, Vector3.UP)
	_oak(Vector3(hx + 0.05, fl + HOLE.y + 0.15, -hz2), Vector3(hx + 0.05, fl + HOLE.y + 0.15, hz2), HOLE.y * 0.9, 0.02, Vector3.RIGHT, 0.5)
	_ironbox(Vector3(hx + 0.065, fl + HOLE.y + 0.31, 0), Vector3(0.012, 0.012, 0.06))
	# a dark inside behind the hole (the floor's far side and back boards are lit otherwise)
	var shade := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(SIZE.x - 0.06, hb - 0.02, SIZE.y - 0.06)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.025, 0.02, 0.015)
	dm.roughness = 1.0
	dm.cull_mode = BaseMaterial3D.CULL_FRONT
	sm.material = dm
	shade.mesh = sm
	shade.position = Vector3(0, fl + (hb - 0.02) * 0.5 + 0.01, 0)
	add_child(shade)
	# pent roof: rafters falling west, then tarred boards lapped down the slope, overhanging
	var over := 0.14
	var y_f := fl + hf + 0.03
	var y_b := fl + hb + 0.03
	var drop := (y_f - y_b) / SIZE.x
	for s in [-1.0, 0.0, 1.0]:
		var zz: float = s * (hz - 0.03)
		_oak(Vector3(hx + over, y_f + over * drop - 0.04, zz), Vector3(-hx - over, y_b - over * drop - 0.04, zz), 0.045, 0.06, Vector3.BACK)
	# boards laid across the slope from the eaves up, each lapping over the one below it
	var run := SIZE.x + over * 2.0
	var slope := Vector3(-1.0, -drop, 0).normalized()
	var rn := Vector3(-drop, 1.0, 0).normalized()
	var top_e := Vector3(hx + over, y_f + over * drop + 0.012, 0)
	var n := 5
	var bw := run * Vector3(1, drop, 0).length() / n
	for i in n:
		var c := top_e + slope * (bw * (i + 0.5)) + rn * (0.012 * (n - i) * 0.6)
		var zl := hz + over * 0.8
		_oak(c + Vector3(0, 0, -zl - _rng.randf_range(0.0, 0.02)), c + Vector3(0, 0, zl + _rng.randf_range(0.0, 0.02)), bw + 0.04, 0.02, rn, 0.8)
	# nest box off the south end: a little lean-to with a hinged lid
	var nz := hz + 0.012
	var nb := Vector3(0.18, fl + 0.05, nz + 0.17)
	for s in [-1.0, 1.0]:
		_board(Vector3(nb.x + s * 0.2, fl + 0.05, nz + 0.17), 0.27, 0.34, Vector3(s, 0, 0))
	_board(Vector3(nb.x, fl + 0.05, nz + 0.34), 0.24, 0.42, Vector3.BACK)
	_oak(Vector3(nb.x - 0.21, fl + 0.06, nz + 0.17), Vector3(nb.x + 0.21, fl + 0.06, nz + 0.17), 0.34, 0.025, Vector3.UP)
	_oak(Vector3(nb.x - 0.23, fl + 0.355, nz + 0.02), Vector3(nb.x + 0.23, fl + 0.355, nz + 0.02), 0.025, 0.05, Vector3.UP)
	var lid_a := Vector3(nb.x, fl + 0.36, nz + 0.0)
	var lid_b := Vector3(nb.x, fl + 0.305, nz + 0.38)
	_oak(lid_a, lid_b, 0.46, 0.022, Vector3.UP, 0.8)
	for s in [-1.0, 1.0]:
		_ironbox(Vector3(nb.x + s * 0.13, fl + 0.37, nz + 0.04), Vector3(0.03, 0.01, 0.1))
	# ladder: one wide plank from the sill down to the dust, slats nailed across it
	var top_p := Vector3(hx + 0.03, fl + 0.01, 0)
	var foot_l := foot() - Vector2(0.12, 0)
	var foot_p := Vector3(hx + LADDER, _ground(foot_l) - base_y + 0.01, 0)
	_oak(top_p, foot_p, 0.24, 0.022, Vector3.UP, 0.0)
	var ln := top_p.distance_to(foot_p)
	var dir := (foot_p - top_p).normalized()
	var up := Vector3(-dir.y, dir.x, 0).normalized()
	if up.y < 0.0:
		up = -up
	var t := 0.08
	while t < ln - 0.04:
		var c := top_p + dir * t + up * 0.022
		_oak(c + Vector3(0, 0, -0.12), c + Vector3(0, 0, 0.12), 0.025, 0.018, up)
		t += 0.13
	# the hero walks round it, not through it
	var body := StaticBody3D.new()
	body.name = "HenHouseCollision"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SIZE.x + 0.1, fl + hf + 0.1, SIZE.y + 0.5)
	cs.shape = bx
	cs.position = Vector3(0, (fl + hf + 0.1) * 0.5 - 0.05, 0.12)
	body.add_child(cs)
	add_child(body)

## Oak in its own unscaled mesh with the grain along the run a -> b; `n` is the way its
## broad face looks (section w across, d through along n).
func _oak(a: Vector3, b: Vector3, w: float, d: float, n: Vector3, tar := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, maxf(a.distance_to(b), 0.005), d)
	var m := ShaderMaterial.new()
	m.shader = _timber
	m.set_shader_parameter("seed", float(boards) * 1.37 + 20.0)
	m.set_shader_parameter("tar", tar)
	bm.material = m
	mi.mesh = bm
	var y := (b - a).normalized()
	var xx := y.cross(n)
	if xx.length() < 0.01:
		xx = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.BACK)
	xx = xx.normalized()
	mi.basis = Basis(xx, y, xx.cross(y).normalized())
	mi.position = (a + b) * 0.5
	add_child(mi)
	boards += 1

## An upright feather-edge board standing at its foot `p`, `h` tall, facing out along `n`;
## the tops lean a hair, the thickness alternates so the laps read.
func _board(p: Vector3, h: float, w: float, n: Vector3) -> void:
	var lean := Vector3(_rng.randf_range(-0.006, 0.006), 0, _rng.randf_range(-0.006, 0.006))
	var off := n * (0.006 if boards % 2 == 0 else 0.0)
	_oak(p + off, p + off + Vector3(0, h, 0) + lean, w, 0.018, n, 0.25 + _rng.randf() * 0.15)

func _ironbox(c: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _iron
	mi.mesh = bm
	mi.position = c
	add_child(mi)
