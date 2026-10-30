class_name FellBell
extends Node3D
## The Last of the Flock (Quests.FLOCK): the bell Osric's bellwether wore, hanging by its
## rotten collar from the last post of his old fold, under the great grey stone up the fell
## behind his cottage. The post is silvered oak (timber.gdshader) leaning out of the turf; the
## collar is wrapped twice round it under the split top; the bell is a small cast bronze
## sheep bell (lathe-turned here, with its canon loop and an iron clapper) on a short drop of
## strap, swinging as a damped pendulum pushed by the wind and knocking at the ends of its
## swing, so the hero hears it from down the slope before seeing it. While the quest is at its
## first step the HUD offers "Take" beside the post; taken, the bell and collar go with the hero.
## Round the post lie the bones of the fold itself (`_fold`): a ring of dry-stone wall butted
## against the great stone, tumbled to one to four courses with breaches and its fallen stones
## spilt in the turf, the post standing as the broken gateway's jamb.
## Bots read `rings`, `taken`, `max_swing` and `fold_stones`.

const ROCK := Vector3(-113.49, 0.0, 101.33)   # the great stone (Flora's boulder at (x, size, z))
const ROCK_SIZE := 3.14
const TOWARD := Vector2(-33.8, 34.1)          # Osric's spot on the fell side: the post stands on the stone's near side
const POST_H := 1.05
const POST_R := 0.07
const DROP := 0.13                            # m of strap from the wrap to the bell's canon
const BELL_SCALE := 1.15                      # the lathe profile is a small ewe's bell; a wether's is bigger
const TAKE_R := 1.8
const HEAR_R := 70.0
const RATE := 22050
const FOLD_R := 3.2                           # the fold's ring radius at the wall's centre line (m)
const FOLD_W := 0.6                           # the wall's width
const FOLD_GATE := 0.42                       # half the gateway's angle either side of the post (rad)
const WIND_DIR := Vector2(0.8, 0.6)           # the meadow wind (Weather)

var player: Player
var weather: Weather
var rings := 0                   # knocks of the clapper (bots)
var taken := false
var max_swing := 0.0             # largest swing seen, rad (bots)
var fold_stones := 0             # stones laid or spilt in the fold (bots)
var post_top := Vector3.ZERO     # world: where the collar wraps (shots, bots)
var _pivot: Node3D
var _collar: MeshInstance3D
var _sound: AudioStreamPlayer3D
var _knocks: Array[AudioStreamWAV] = []
var _swing := Vector2.ZERO       # (about the wind's cross axis, about the wind axis) rad
var _swing_v := Vector2.ZERO
var _prev_v := Vector2.ZERO
var _since := 0.0
var _seen_interacts := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()

## The post's foot in world xz (the stone's near side, toward Osric's fell spot).
static func foot_xz() -> Vector2:
	var away := (TOWARD - Vector2(ROCK.x, ROCK.z)).normalized()
	return Vector2(ROCK.x, ROCK.z) + away * (ROCK_SIZE * 0.75 + 1.3)

## The fold's centre: off to the side of the post and a little up toward the stone, so the post
## stands on the ring at its gateway and the path up from the stile comes in clear of the wall.
static func fold_centre() -> Vector2:
	var away := (TOWARD - Vector2(ROCK.x, ROCK.z)).normalized()
	var side := Vector2(away.y, -away.x)
	return foot_xz() + (side * 0.8 - away * 0.6) * FOLD_R

## The post's angle on the fold ring.
static func _gate_angle() -> float:
	var d := foot_xz() - fold_centre()
	return atan2(d.y, d.x)

## How much of the wall still stands at angle `a` on the ring: 0 a breach .. 1 four courses.
static func _standing(a: float) -> float:
	return clampf(0.68 + 0.35 * sin(a * 3.0 + 1.3) + 0.25 * sin(a * 7.0 + 0.4) + 0.12 * sin(a * 13.0 + 2.2), 0.0, 1.0)

## True when (x, z) lies on the fold's tumbled wall plus `margin` (grass and flowers keep off).
static func on_fold(x: float, z: float, margin: float = 0.0) -> bool:
	var c := fold_centre()
	var p := Vector2(x, z)
	if absf(p.distance_to(c) - FOLD_R) > FOLD_W * 0.5 + margin:
		return false
	return absf(angle_difference((p - c).angle(), _gate_angle())) > FOLD_GATE - margin / FOLD_R

## True when a Flora stone of size `s` at (x, z) would stand through the fold's wall: the
## wall was cleared of the fell's stones when it was built (the great stone itself stays).
static func clears_fold(x: float, z: float, s: float) -> bool:
	if Vector2(x - ROCK.x, z - ROCK.z).length() < 0.5:
		return false
	return absf(Vector2(x, z).distance_to(fold_centre()) - FOLD_R) < FOLD_W * 0.5 + s * 0.75

func build(terrain: Terrain, ruins: Ruins = null) -> void:
	_rng.seed = 4417
	var away := (TOWARD - Vector2(ROCK.x, ROCK.z)).normalized()
	var foot2 := foot_xz()
	var foot := Vector3(foot2.x, terrain.height_at(foot2.x, foot2.y), foot2.y)
	global_position = foot
	# the post leans a little downhill, away from the stone, as an old post does
	var lean_axis := Vector3(away.y, 0, -away.x)
	var post := Node3D.new()
	post.name = "Post"
	# its hanging side (+z) turned down the slope, toward whoever comes up from the stile
	post.basis = Basis(lean_axis, 0.17) * Basis(Vector3.UP, atan2(away.x, away.y))
	add_child(post)
	var cm := _post_mesh()
	var tm := ShaderMaterial.new()
	tm.shader = preload("res://shaders/timber.gdshader")
	tm.set_shader_parameter("seed", 13.7)
	# out on the fell for forty years: silvered like the cottage timbers, a little greener (0.36
	# read blue-black in the great stone's noon shade)
	tm.set_shader_parameter("oak_silver", Color(0.47, 0.455, 0.41))
	tm.set_shader_parameter("oak_brown", Color(0.27, 0.225, 0.16))
	tm.set_shader_parameter("oak_dark", Color(0.075, 0.068, 0.055))
	# crottle and moss on its weather side and up from the turf
	tm.set_shader_parameter("lichen", 1.0)
	# warm grey-ochre crust, not the pale blue-white it read as in the stone's shade
	tm.set_shader_parameter("lichen_col", Color(0.52, 0.5, 0.36))
	tm.set_shader_parameter("weather_dir", Vector3(-WIND_DIR.x, 0.0, -WIND_DIR.y))
	tm.set_shader_parameter("foot_y", -(POST_H - 0.25) * 0.5)
	cm.surface_set_material(0, tm)
	var mi := MeshInstance3D.new()
	mi.name = "Oak"
	mi.mesh = cm
	mi.position.y = (POST_H - 0.25) * 0.5   # 0.25 m sunk in the turf
	mi.rotation.y = 0.4
	post.add_child(mi)
	# the split top: a splinter standing proud of one side of the broken head
	var sp := CylinderMesh.new()
	sp.top_radius = 0.012
	sp.bottom_radius = POST_R * 0.4
	sp.height = 0.07
	sp.radial_segments = 5
	sp.rings = 1
	sp.material = tm
	var smi := MeshInstance3D.new()
	smi.mesh = sp
	smi.position = Vector3(POST_R * 0.35, POST_H + 0.02, -POST_R * 0.25)
	smi.rotation = Vector3(0.12, 0.0, -0.1)
	post.add_child(smi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = POST_R
	cy.height = POST_H
	cs.shape = cy
	cs.position.y = POST_H * 0.5
	body.add_child(cs)
	post.add_child(body)
	var bronze := ShaderMaterial.new()
	bronze.shader = preload("res://shaders/fell_bell.gdshader")
	bronze.set_shader_parameter("seed", 2.3)
	var leather := ShaderMaterial.new()
	leather.shader = bronze.shader
	leather.set_shader_parameter("part", 1.0)
	leather.set_shader_parameter("seed", 5.1)
	# the collar: two turns round the post under the split head, buckled tight long ago
	var wrap_y := POST_H - 0.12
	_collar = MeshInstance3D.new()
	_collar.name = "Collar"
	_collar.mesh = _wrap_mesh(wrap_y)
	_collar.material_override = leather
	post.add_child(_collar)
	# the drop and the bell swing from the front of the wrap
	_pivot = Node3D.new()
	_pivot.name = "Swing"
	_pivot.position = Vector3(0, wrap_y - 0.012, POST_R + 0.012)
	post.add_child(_pivot)
	var drop := MeshInstance3D.new()
	drop.name = "Drop"
	drop.mesh = _drop_mesh()
	drop.material_override = leather
	_pivot.add_child(drop)
	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	bell.mesh = _bell_mesh()
	bell.material_override = bronze
	bell.position.y = -DROP - 0.09 * BELL_SCALE
	bell.scale = Vector3.ONE * BELL_SCALE
	_pivot.add_child(bell)
	post_top = post.to_global(_pivot.position)
	_sound = AudioStreamPlayer3D.new()
	_sound.name = "Knock"
	_sound.max_distance = HEAR_R
	_sound.unit_size = 9.0
	_sound.volume_db = -7.0
	_sound.attenuation_filter_cutoff_hz = 6000.0
	_pivot.add_child(_sound)
	for f: float in [742.0, 768.0, 731.0]:
		_knocks.append(_make_knock(f))
	if ruins != null:
		_fold(terrain, ruins)

## The post: an oak quarter hewn eight-sided with an adze, never true -- each face its own
## width and a little off square, the faces wandering as the axe followed the grain, tapering
## to the broken head; a check split opens down the weather face from the head and closes
## two fifths of the way down. Flat-shaded facets, 0.25 m of it below the turf, centred on its
## height like the CylinderMesh it replaced.
func _post_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	const SIDES := 8
	const RINGS := 6
	const SPLIT_FACE := 5            # faces +x side after the post's 0.4 rad turn: the weather side
	var h := POST_H + 0.25
	var ang: Array[float] = []
	var rad: Array[float] = []
	for k in SIDES:
		ang.append((k + rng.randf_range(-0.12, 0.12)) * TAU / SIDES)
		rad.append(POST_R * rng.randf_range(0.93, 1.06))
	# each ring: the octagon's corners plus three split points on SPLIT_FACE (edge, floor, edge)
	var rings: Array = []
	for r in RINGS + 1:
		var t := float(r) / RINGS
		var y := -h * 0.5 + h * t
		var taper := lerpf(1.0, 0.8, t) * (1.0 + rng.randf_range(-0.03, 0.03))
		var twist := sin(t * 2.3 + 0.6) * 0.06
		var off := Vector2(sin(t * 3.1) * 0.006, cos(t * 2.4 + 1.0) * 0.005)
		var depth := smoothstep(0.55, 0.95, t) * 0.03
		var pts: Array[Vector3] = []
		for k in SIDES:
			var a := ang[k] + twist
			var c := Vector2(cos(a), sin(a)) * rad[k] * taper + off
			pts.append(Vector3(c.x, y, c.y))
			if k == SPLIT_FACE:
				var a2 := ang[(k + 1) % SIDES] + twist + (TAU if k + 1 == SIDES else 0.0)
				var c2 := Vector2(cos(a2), sin(a2)) * rad[(k + 1) % SIDES] * taper + off
				# the check gapes ~12% of the face at the head and closes to a hairline
				var gape := 0.004 + smoothstep(0.55, 0.95, t) * 0.058
				var e1 := c.lerp(c2, 0.485 - gape)
				var e2 := c.lerp(c2, 0.485 + gape)
				var mid := c.lerp(c2, 0.485)
				var fl := mid - mid.normalized() * depth
				pts.append(Vector3(e1.x, y, e1.y))
				pts.append(Vector3(fl.x, y, fl.y))
				pts.append(Vector3(e2.x, y, e2.y))
		rings.append(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = (rings[0] as Array).size()
	for r in RINGS:
		var lo: Array = rings[r]
		var hi: Array = rings[r + 1]
		for k in n:
			var k2 := (k + 1) % n
			_flat_tri(st, lo[k], hi[k2], lo[k2])
			_flat_tri(st, lo[k], hi[k], hi[k2])
	# the broken head: a shallow ragged cone, its crown off-centre where the splinter stands
	var top: Array = rings[RINGS]
	var crown := Vector3(POST_R * 0.2, h * 0.5 + 0.012, -POST_R * 0.15)
	for k in n:
		var a: Vector3 = top[k]
		var b: Vector3 = top[(k + 1) % n]
		_flat_tri(st, a, crown, b)
	return st.commit()

static func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# (b - a) x (c - a) points out; Godot's front faces are clockwise from the front, so a, c, b
	var nrm := (b - a).cross(c - a).normalized()
	for v: Vector3 in [a, c, b]:
		st.set_normal(nrm)
		st.add_vertex(v)

## The old fold: field rubble laid round the ring in up to four courses, each stone a single
## through-stone the wall's width, the courses fallen where `_standing` is low and their stones
## lying tilted and half sunk in the turf on either side; a cope stone on edge here and there
## where the wall stands full. Ruins' chipped block meshes at twice size, scaled down, in the
## masonry shader's aged field-stone dress (as DryWall). Box colliders where two or more
## courses stand; a single course is stepped over.
func _fold(terrain: Terrain, ruins: Ruins) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9031
	var dims: Array[Vector3] = []
	var per: Array = []
	var meshes: Array[ArrayMesh] = []
	for v in 6:
		var d := Vector3(lerpf(0.7, 1.15, (v + rng.randf()) / 6.0), rng.randf_range(0.34, 0.48), FOLD_W * 2.0)
		dims.append(d)
		meshes.append(ruins._block_mesh(d, 80 + v, minf(rng.randf_range(0.11, 0.14), d.y * 0.5 - 0.02), rng.randf_range(1.7, 2.1)))
		per.append([])
	var c2 := fold_centre()
	var ga := _gate_angle()
	var body := StaticBody3D.new()
	body.name = "FoldCollision"
	add_child(body)
	var circ := TAU * FOLD_R
	var n := int(circ / 0.5)
	for i in n:
		var a := ga + FOLD_GATE + (TAU - 2.0 * FOLD_GATE) * (float(i) + 0.5) / n
		var radial := Vector2(cos(a), sin(a))
		var tang := Vector2(-radial.y, radial.x)
		var p2 := c2 + radial * FOLD_R
		var gy := terrain.height_at(p2.x, p2.y)
		var stand := _standing(a)
		# the gateway's jambs fall lowest: the stones nearest the post are mostly gone
		var to_gate := minf(absf(angle_difference(a, ga + FOLD_GATE)), absf(angle_difference(a, ga - FOLD_GATE)))
		stand *= clampf(to_gate / 0.35, 0.25, 1.0)
		var courses := int(round(stand * 4.0 + rng.randf_range(-0.3, 0.3)))
		var y := gy - 0.08                 # the foundation course sits in the turf
		var dir := Vector3(tang.x, 0, tang.y)
		var out := Vector3(radial.x, 0, radial.y)
		for k in courses:
			var h := rng.randf_range(0.18, 0.25) * (1.0 - k * 0.06)
			var size := Vector3(rng.randf_range(0.42, 0.56), h, FOLD_W * rng.randf_range(0.85, 1.0) * (1.0 - k * 0.08))
			var b := Basis(out.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, out)
			b = b * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06)) * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
			var cen := Vector3(p2.x, y + h * 0.5, p2.y) + dir * rng.randf_range(-0.05, 0.05) + out * rng.randf_range(-0.04, 0.04)
			_fold_stone(rng, per, dims, cen, b, size, cen.y - gy, 1.0)
			y += h * 0.96
		if courses == 4 and rng.randf() < 0.6:
			# a cope stone on edge, leaning along the wall
			var size := Vector3(0.16, rng.randf_range(0.26, 0.32), FOLD_W * 0.7)
			var b := Basis(out.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, out) * Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
			_fold_stone(rng, per, dims, Vector3(p2.x, y + size.y * 0.45, p2.y), b, size, y - gy, 1.0)
			y += size.y * 0.9
		# the fallen courses lie spilt on either side, tilted, half sunk
		for k in 4 - courses:
			if rng.randf() < 0.3:
				continue
			var side := 1.0 if rng.randf() < 0.6 else -1.0   # more fell outward, down the slope
			var q := p2 + radial * side * rng.randf_range(0.55, 1.4) + tang * rng.randf_range(-0.3, 0.3)
			var size := Vector3(rng.randf_range(0.4, 0.55), rng.randf_range(0.18, 0.24), rng.randf_range(0.35, 0.55))
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.FORWARD, rng.randf_range(-0.4, 0.4))
			var qy := terrain.height_at(q.x, q.y)
			_fold_stone(rng, per, dims, Vector3(q.x, qy + size.y * 0.15, q.y), b, size, 0.0, 0.0)
		if courses >= 2:
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(0.52, y - gy + 0.08, FOLD_W)
			cs.shape = bx
			cs.transform = Transform3D(Basis(out.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, out), Vector3(p2.x, (gy + y) * 0.5, p2.y) - global_position)
			body.add_child(cs)
	for v in meshes.size():
		if per[v].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[v]
		mm.instance_count = per[v].size()
		for j in per[v].size():
			mm.set_instance_transform(j, per[v][j][0])
			mm.set_instance_custom_data(j, per[v][j][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Fold_%d" % v
		mmi.multimesh = mm
		add_child(mmi)

## One rubble stone of `size` (laid m) at world `c`: the nearest-sized variant, scaled down.
func _fold_stone(rng: RandomNumberGenerator, per: Array, dims: Array[Vector3], c: Vector3, b: Basis, size: Vector3, above: float, laid: float) -> void:
	var v := rng.randi() % dims.size()
	for t in 2:
		var o := rng.randi() % dims.size()
		if absf(dims[o].x - size.x * 2.0) < absf(dims[v].x - size.x * 2.0):
			v = o
	var d: Vector3 = dims[v]
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	if rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), c - global_position)
	per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), rng.randf(), laid, 2.0)])
	fold_stones += 1

## A ribbon round the post: two turns, climbing 2 cm a turn, 2.2 cm wide.
func _wrap_mesh(y0: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var w := 0.022
	var r := POST_R * 0.82 + 0.004
	var pts := []
	for i in n + 1:
		var a := TAU * 2.0 * float(i) / n
		var y := y0 + 0.02 * float(i) / n
		var c := Vector3(sin(a) * r, y, cos(a) * r)
		var nr := Vector3(sin(a), 0, cos(a))
		pts.append([c, nr, float(i) / n])
	for i in n:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		_quad(st, p0[0] + Vector3.UP * w * 0.5, p1[0] + Vector3.UP * w * 0.5,
			p1[0] - Vector3.UP * w * 0.5, p0[0] - Vector3.UP * w * 0.5,
			p0[1], p1[1], Vector2(p0[2] * 3.0, 0), Vector2(p1[2] * 3.0, 1))
	return st.commit()

## The drop: the strap folded through the bell's canon loop, two strands side by side down
## from the wrap, a little twisted.
func _drop_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.018
	for side in [-1.0, 1.0]:
		var x0: float = side * 0.006
		var seg := 6
		for i in seg:
			var t0 := float(i) / seg
			var t1 := float(i + 1) / seg
			var y0 := -t0 * (DROP + 0.004)
			var y1 := -t1 * (DROP + 0.004)
			# the strand turns its face a quarter turn on the way down to pass through the loop
			var a0: float = t0 * 1.2 * side
			var a1: float = t1 * 1.2 * side
			var d0 := Vector3(cos(a0), 0, sin(a0)) * w * 0.5
			var d1 := Vector3(cos(a1), 0, sin(a1)) * w * 0.5
			var c0 := Vector3(x0 * (1.0 - t0), y0, 0.004 * side)
			var c1 := Vector3(x0 * (1.0 - t1), y1, 0.004 * side)
			var n0 := Vector3(-sin(a0), 0, cos(a0))
			var n1 := Vector3(-sin(a1), 0, cos(a1))
			_quad(st, c0 - d0, c0 + d0, c1 + d1, c1 - d1, n0, n1, Vector2(t0, 0), Vector2(t1, 1))
	return st.commit()

## One ribbon quad (a, b at the start; c, d at the end), normals per end, UV x along y across.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n0: Vector3, n1: Vector3, uv0: Vector2, uv1: Vector2) -> void:
	st.set_normal(n0); st.set_uv(Vector2(uv0.x, 0)); st.add_vertex(a)
	st.set_normal(n0); st.set_uv(Vector2(uv0.x, 1)); st.add_vertex(b)
	st.set_normal(n1); st.set_uv(Vector2(uv1.x, 1)); st.add_vertex(c)
	st.set_normal(n0); st.set_uv(Vector2(uv0.x, 0)); st.add_vertex(a)
	st.set_normal(n1); st.set_uv(Vector2(uv1.x, 1)); st.add_vertex(c)
	st.set_normal(n1); st.set_uv(Vector2(uv1.x, 0)); st.add_vertex(d)

## The bell, lathe-turned about +y (lip at y 0, crown at 0.081): the outer wall swelling from
## a beaded lip to the shoulder and the flat crown, a 3 mm wall, the canon loop on top and the
## clapper hanging inside. UV.x = 1 on the inside, UV.y = height up the bell.
func _bell_mesh() -> ArrayMesh:
	var outer := [Vector2(0.0365, 0.0), Vector2(0.0372, 0.003), Vector2(0.0345, 0.009), Vector2(0.030, 0.026),
		Vector2(0.0262, 0.047), Vector2(0.0232, 0.063), Vector2(0.0195, 0.073), Vector2(0.012, 0.0795), Vector2(0.0, 0.081)]
	var inner := []
	for p: Vector2 in outer:
		inner.append(Vector2(maxf(p.x - 0.0032, 0.0), p.y - 0.0028 * (p.y / 0.081)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	_lathe(st, outer, seg, 1.0, 0.0)
	_lathe(st, inner, seg, -1.0, 1.0)
	_lathe(st, [inner[0], outer[0]], seg, 1.0, 0.0)   # the lip's flat underside
	# the canon: a ring standing on the crown, in the drop's plane
	var R := 0.0105
	var rr := 0.0034
	var ts := 16
	var cs := 8
	for i in ts:
		for j in cs:
			var q := []
			for k in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var u := TAU * float(i + k[0]) / ts
				var v := TAU * float(j + k[1]) / cs
				var cen := Vector3(cos(u) * R, 0.081 + R * 0.75 + sin(u) * R, 0)
				var nr := (Vector3(cos(u), sin(u), 0) * cos(v) + Vector3(0, 0, sin(v))).normalized()
				q.append([cen + nr * rr, nr])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1])
				st.set_uv(Vector2(0.0, 1.0))
				st.add_vertex(q[idx][0])
	# the clapper: an iron rod from the crown and a ball near the lip, slightly off-centre
	var rod := [Vector2(0.0022, 0.077), Vector2(0.0022, 0.024), Vector2(0.0058, 0.02), Vector2(0.0075, 0.013), Vector2(0.0058, 0.006), Vector2(0.0, 0.004)]
	_lathe(st, rod, 10, 1.0, 1.0)
	return st.commit()

## Spins a profile (r, y) about +y; `side` +1 faces out, -1 faces in.
func _lathe(st: SurfaceTool, prof: Array, seg: int, side: float, inside: float) -> void:
	for k in prof.size() - 1:
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		var d := (p1 - p0).normalized()
		var nn := Vector2(d.y, -d.x) * side * (-1.0 if p1.y < p0.y else 1.0)
		if absf(d.y) < 0.001:
			nn = Vector2(0, -1) * side
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var v := [[a0, p0], [a1, p0], [a1, p1], [a0, p1]]
			for idx in ([0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]):
				var a: float = v[idx][0]
				var p: Vector2 = v[idx][1]
				var dir := Vector3(sin(a), 0, cos(a))
				st.set_normal((dir * nn.x + Vector3.UP * nn.y).normalized())
				st.set_uv(Vector2(inside, p.y / 0.081))
				st.add_vertex(dir * p.x + Vector3.UP * p.y)

## A cast sheep bell's knock: a dry clapper tick, then a short bright inharmonic ring (the
## bronze's partials at about 1, 2.4, 3.9 and 5.4 times the hum, the high ones dying first).
func _make_knock(f: float) -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var b := PackedByteArray()
	b.resize(n * 2)
	var parts := [[1.0, 1.0, 3.2], [2.41, 0.6, 5.5], [3.89, 0.35, 9.0], [5.37, 0.2, 14.0]]
	var x := PackedFloat32Array()
	x.resize(n)
	var peak := 0.0001
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in parts:
			v += sin(TAU * f * p[0] * t + p[0]) * p[1] * exp(-t * p[2])
		v *= 1.0 - exp(-t * 900.0)
		if t < 0.006:
			v += _rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.006) * 0.8
		x[i] = v
		peak = maxf(peak, absf(v))
	for i in n:
		b.encode_s16(i * 2, int(clampf(x[i] / peak * 0.85, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = b
	return s

func _physics_process(delta: float) -> void:
	_t += delta
	_since += delta
	if not taken:
		_update_swing(delta)
	_update_take()

## The wind pushes the bell downwind in gusts; a damped pendulum (~1.6 Hz on its short drop).
## Each time the swing turns at a good lean the clapper knocks the wall.
func _update_swing(delta: float) -> void:
	var w := 0.25 + 0.75 * (weather.wind if weather != null else 0.0)
	var gust := 0.5 + 0.5 * sin(_t * 0.9 + sin(_t * 0.23) * 3.0) * sin(_t * 0.37 + 1.1)
	var push := Vector2(w * gust * 0.35, w * 0.08 * sin(_t * 2.3))
	var k := 100.0
	var acc := -k * _swing - 1.4 * _swing_v + push * k * 0.5 + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * w * 3.0
	_swing_v += acc * delta
	_swing += _swing_v * delta
	max_swing = maxf(max_swing, _swing.length())
	# the post's frame: lean the drop about the wind's cross axis
	var wd := WIND_DIR.normalized()
	var to_local := (get_child(0) as Node3D).global_transform.basis.inverse()
	var ax := to_local * Vector3(-wd.y, 0, wd.x)
	var az := to_local * Vector3(wd.x, 0, wd.y)
	_pivot.basis = Basis(ax.normalized(), _swing.x) * Basis(az.normalized(), _swing.y)
	# a knock when the swing turns hard
	if _prev_v.dot(_swing_v) < 0.0 and _swing_v.length() + _prev_v.length() > 0.0 and _swing.length() > 0.05 and _since > 0.22:
		_knock(_swing.length())
	_prev_v = _swing_v

func _knock(lean: float) -> void:
	_since = 0.0
	rings += 1
	if player == null or player.global_position.distance_to(post_top) > HEAR_R:
		return
	_sound.stream = _knocks[_rng.randi() % _knocks.size()]
	_sound.volume_db = -14.0 + clampf(lean / 0.25, 0.0, 1.0) * 9.0
	_sound.pitch_scale = _rng.randf_range(0.98, 1.02)
	_sound.play()

func _update_take() -> void:
	if player == null:
		return
	var quests: Quests = player.get_node_or_null("Quests")
	var presses: int = player.interacts
	var d := Vector2(player.global_position.x - post_top.x, player.global_position.z - post_top.z).length()
	var want := not taken and quests != null and quests.stage_of(Quests.FLOCK) == 1
	if not want or d > TAKE_R or player.is_dead():
		_seen_interacts = presses
		return
	var hud = player.get_node_or_null("Hud")
	if hud != null:
		hud.prompt("E", "Take")
	if presses == _seen_interacts:
		return
	_seen_interacts = presses
	var line := quests.line_for(Quests.BELL)
	if line == "":
		return
	taken = true
	_collar.visible = false
	_pivot.visible = false
	if hud != null:
		hud.say("", line, 2.4 + 0.055 * line.length())
