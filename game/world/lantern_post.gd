class_name LanternPost
extends StaticBody3D
## An oak lantern post at the meeting of the tracks on the green: a chamfered post with a
## weathering cap, an arm braced out toward the village centre, and a black wrought-iron
## lantern hung off it on three chain links. Horn panes round a tallow candle; lit from
## dusk to first light, the flame flickers and the lantern sways on its chain with the
## wind, so its light and the frame's shadows move across the grass.
## lantern.gdshader (iron, tallow), lantern_horn.gdshader (panes), flame.gdshader.

const SITE := Vector2(-10.5, 3.2)
const POST_H := 2.75        # post top above the ground
const SUNK := 0.4           # post foot below the ground
const POST_W := 0.15        # square section
const CHAMFER := 0.022
const ARM_Y := 2.48         # arm centre height
const ARM_L := 0.86         # arm reach from the post axis
const ARM_W := 0.085
const ARM_D := 0.11
const LW := 0.2             # lantern body width
const LH := 0.36            # lantern height (top ring to base plate)
const FRAME_DOWN := 0.13    # top ring to the top frame (chimney and cap between)
const DROP := 0.17          # pivot (hook) to the lantern's top ring
const LAMP := Color(1.0, 0.54, 0.25)   # deep amber: paler read olive on limewash under the night grade

var lit := 0.0              # 0 dark .. 1 burning
var lighter: Node = null    # Edda (Villager): lights it at dusk with her taper (`lantern_lit`)
var weather: Weather
var pivot: Node3D           # the hook the lantern hangs from (swings)
var lamp: OmniLight3D
var flame_pos: Node3D
var _world: Node
var _horn: ShaderMaterial
var _flame: ShaderMaterial
var _tallow: ShaderMaterial
var _sway := Vector2.ZERO   # (pitch, roll) rad
var _sway_v := Vector2.ZERO
var _t := 0.0
var max_sway := 0.0         # largest swing seen (bots)
var _caught := 0.0
var moths: Moths           # moths round the lit lantern (moths.gd)
var bat: Bat               # the pipistrelle that hawks them after dark (bat.gd)

## World yaw: local +z (the arm) reaches toward the village centre.
static func facing() -> float:
	return atan2(-SITE.x, -SITE.y)

## True when (x, z) is within the post's foot plus `margin` (grass and flowers keep off).
static func near(x: float, z: float, margin: float = 0.0) -> bool:
	return Vector2(x - SITE.x, z - SITE.y).length() < POST_W * 0.75 + margin

## 0..1 burning at hour h: lit at dusk, guttering before dawn, out by first light.
static func lit_for(h: float) -> float:
	if h >= 12.0:
		return smoothstep(19.2, 19.5, h)
	return 1.0 - smoothstep(5.2, 5.8, h)

func _ready() -> void:
	_world = get_parent()
	collision_layer = 1
	collision_mask = 0
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://shaders/timber.gdshader")
	wood.set_shader_parameter("seed", 4.3)
	# older, darker oak than the house frames: weathered grey-brown, a dark foot
	wood.set_shader_parameter("oak_silver", Color(0.33, 0.31, 0.28))
	wood.set_shader_parameter("oak_brown", Color(0.22, 0.16, 0.11))
	var iron := ShaderMaterial.new()
	iron.shader = preload("res://shaders/lantern.gdshader")
	iron.set_shader_parameter("seed", 1.7)
	# the post: grain runs up its local Y
	_add("Post", _post_mesh(), wood, Vector3.ZERO)
	# the arm out along +z, grain along it (a Y-mesh turned onto +z)
	var arm := _add("Arm", _beam_mesh(ARM_W, ARM_D, ARM_L + 0.05, 0.6), wood,
		Vector3(0, ARM_Y, -0.04))
	arm.rotation.x = PI * 0.5
	# a diagonal brace from the post face up under the arm
	var b0 := Vector3(0, ARM_Y - 0.5, POST_W * 0.5 - 0.01)
	var b1 := Vector3(0, ARM_Y - ARM_D * 0.5 + 0.01, 0.48)
	var bd := b1 - b0
	var brace := _add("Brace", _beam_mesh(0.07, 0.07, bd.length() + 0.04, 0.0), wood, b0 - bd.normalized() * 0.02)
	brace.rotation.x = atan2(bd.z, bd.y)
	var wm := ShaderMaterial.new()
	wm.shader = wood.shader
	wm.set_shader_parameter("seed", 9.1)
	wm.set_shader_parameter("oak_silver", Color(0.33, 0.31, 0.28))
	wm.set_shader_parameter("oak_brown", Color(0.22, 0.16, 0.11))
	brace.material_override = wm
	# iron: a strap round the arm end, a staple under it, and the hook
	_add("ArmIron", _arm_iron_mesh(), iron, Vector3.ZERO)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(0, ARM_Y - ARM_D * 0.5 - 0.035, ARM_L - 0.08)
	add_child(pivot)
	var lantern := MeshInstance3D.new()
	lantern.name = "Lantern"
	lantern.mesh = _lantern_mesh()
	lantern.material_override = iron
	pivot.add_child(lantern)
	# horn panes on the four sides
	_horn = ShaderMaterial.new()
	_horn.shader = preload("res://shaders/lantern_horn.gdshader")
	var horn := MeshInstance3D.new()
	horn.name = "Horn"
	horn.mesh = _horn_mesh()
	horn.material_override = _horn
	horn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(horn)
	# the candle on its pricket, and its flame
	var base_y := -DROP - LH
	_tallow = ShaderMaterial.new()
	_tallow.shader = iron.shader
	_tallow.set_shader_parameter("part", 1.0)
	_tallow.set_shader_parameter("seed", 3.3)
	var candle := MeshInstance3D.new()
	candle.name = "Candle"
	candle.mesh = _candle_mesh()
	candle.material_override = _tallow
	candle.position = Vector3(0, base_y + 0.026, 0)
	pivot.add_child(candle)
	flame_pos = Node3D.new()
	flame_pos.name = "FlamePos"
	flame_pos.position = Vector3(0, base_y + 0.026 + 0.085 + 0.024, 0)
	pivot.add_child(flame_pos)
	_flame = ShaderMaterial.new()
	_flame.shader = preload("res://shaders/flame.gdshader")
	var fl := MeshInstance3D.new()
	fl.name = "Flame"
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.06)
	fl.mesh = q
	fl.material_override = _flame
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_pos.add_child(fl)
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = LAMP
	# a soft, wide falloff: at 1.4 the pool on the cottage wall had a hard round rim
	lamp.omni_range = 10.0
	lamp.omni_attenuation = 0.85
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.03
	lamp.light_size = 0.03
	flame_pos.add_child(lamp)
	lamp.position = Vector3(0, 0.01, 0)
	# the post stops the hero
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(POST_W + 0.04, POST_H, POST_W + 0.04)
	col.shape = box
	col.position.y = POST_H * 0.5
	add_child(col)
	moths = Moths.new()
	moths.name = "Moths"
	moths.post = self
	moths.weather = weather
	add_child(moths)
	bat = Bat.new()
	bat.name = "Bat"
	bat.post = self
	bat.moths = moths
	bat.weather = weather
	add_child(bat)
	_apply()

func _add(n: String, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	_t += delta
	var h: float = _world.time_of_day if "time_of_day" in _world else 12.0
	lit = lit_for(h)
	if lighter != null and h >= 12.0 and h < 20.0:
		# dusk: dark until her taper reaches the wick, then the flame takes over a second
		var want := 1.0 if lighter.get("lantern_lit") else 0.0
		_caught = move_toward(_caught, want, delta / 1.2)
		lit = _caught
	else:
		_caught = lit
	# sway: a damped pendulum (~0.9 s period on its short drop) pushed by gusts
	var w := weather.wind if weather else 0.0
	var gust := (0.25 + w * 1.6) * (0.55 + 0.45 * sin(_t * 0.7) * sin(_t * 1.9 + 1.3))
	var push := Vector2(sin(_t * 1.3 + 0.4) * 0.6 + 0.8, sin(_t * 0.9 + 2.1) * 0.7) * gust * 1.8
	var k := 45.0
	var steps := maxi(1, ceili(delta * 60.0))
	var dt := delta / steps
	for i in steps:
		_sway_v += (push - _sway * k - _sway_v * 1.6) * dt
		_sway += _sway_v * dt
	_sway = _sway.clampf(-0.35, 0.35)
	max_sway = maxf(max_sway, _sway.length())
	pivot.rotation = Vector3(_sway.x, 0.0, _sway.y)
	_apply()

func _apply() -> void:
	var fl := 0.82 + 0.1 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0) + 0.08 * sin(_t * 23.0 + 0.5)
	_flame.set_shader_parameter("lit", lit)
	_horn.set_shader_parameter("lit", lit * fl)
	_tallow.set_shader_parameter("lit", lit * fl)
	lamp.light_energy = lit * 1.15 * fl
	lamp.visible = lit > 0.01
	flame_pos.get_node("Flame").visible = lit > 0.01

## Where the lantern hangs (world), for lenses and bots.
func lantern_center() -> Vector3:
	return pivot.global_position + pivot.global_basis.y * -(DROP + LH * 0.5)

# ---- meshes ----

## An octagon (square with chamfered corners) of half-width `hw`, chamfer `c`, round Y.
static func _octagon(hw: float, hd: float, c: float) -> Array[Vector2]:
	return [Vector2(hw - c, -hd), Vector2(hw, -hd + c), Vector2(hw, hd - c), Vector2(hw - c, hd),
		Vector2(-hw + c, hd), Vector2(-hw, hd - c), Vector2(-hw, -hd + c), Vector2(-hw + c, -hd)]

## A prism along Y from y0 to y1 over the polygon `ring` (counter-clockwise seen from +Y),
## flat-shaded sides; `cap` > 0 tops it with a weathering pyramid that high, else a flat end.
static func _prism(st: SurfaceTool, ring: Array[Vector2], y0: float, y1: float, cap: float, bottom: bool) -> void:
	var n := ring.size()
	for i in n:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var e := b - a
		var nrm := Vector3(e.y, 0.0, -e.x).normalized()
		var u0 := 0.0
		var u1 := e.length()
		_tri(st, [Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y)], nrm, [Vector2(u0, y0), Vector2(u1, y1), Vector2(u1, y0)])
		_tri(st, [Vector3(a.x, y0, a.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y)], nrm, [Vector2(u0, y0), Vector2(u0, y1), Vector2(u1, y1)])
	var top := Vector3(0, y1 + cap, 0)
	for i in n:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		var pa := Vector3(a.x, y1, a.y)
		var pb := Vector3(b.x, y1, b.y)
		var nrm := (top - pa).cross(pb - pa).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		_tri(st, [pa, top, pb], nrm, [a, Vector2.ZERO, b])
		if bottom:
			_tri(st, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(0, y0, 0)], Vector3.DOWN, [a, b, Vector2.ZERO])

## One triangle, wound so its face points along `nrm`.
static func _tri(st: SurfaceTool, p: Array, nrm: Vector3, uv: Array) -> void:
	var idx := [0, 1, 2]
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot(nrm) > 0.0:
		idx = [0, 2, 1]
	for i in idx:
		st.set_normal(nrm)
		st.set_uv(uv[i])
		st.add_vertex(p[i])

func _post_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := POST_W * 0.5
	_prism(st, _octagon(hw, hw, CHAMFER), -SUNK, POST_H, 0.07, false)
	return st.commit()

## A chamfered beam along Y from 0 to `ln`; `slope` > 0 cuts its far end on a raking
## weathering slope (the arm's end), else a flat end.
func _beam_mesh(w: float, d: float, ln: float, slope: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(st, _octagon(w * 0.5, d * 0.5, 0.012), 0.0, ln, d * 0.5 * slope, true)
	return st.commit()

## Merge a primitive into `st` at transform `x`.
static func _put(st: SurfaceTool, m: PrimitiveMesh, x: Transform3D) -> void:
	st.append_from(m, 0, x)

static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, t: float) -> void:
	var bx := BoxMesh.new()
	var d := b - a
	bx.size = Vector3(t, d.length(), t)
	var y := d.normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	_put(st, bx, Transform3D(Basis(x, y, z), (a + b) * 0.5))

static func _link(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.009
	tm.outer_radius = 0.016
	tm.rings = 10
	tm.ring_segments = 6
	# a torus lies in XZ: stand it up (ring in the YZ or XY plane) and stretch it into a link
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 1.45))
	_put(st, tm, Transform3D(b, at))

func _arm_iron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := ARM_L - 0.08
	var y0 := ARM_Y - ARM_D * 0.5
	# a flat strap wrapped round the arm
	var hw := ARM_W * 0.5 + 0.004
	var hd := ARM_D * 0.5 + 0.004
	var s := BoxMesh.new()
	s.size = Vector3(0.006, ARM_D + 0.01, 0.03)
	_put(st, s, Transform3D(Basis(), Vector3(hw, ARM_Y, z)))
	_put(st, s, Transform3D(Basis(), Vector3(-hw, ARM_Y, z)))
	s = BoxMesh.new()
	s.size = Vector3(ARM_W + 0.014, 0.006, 0.03)
	_put(st, s, Transform3D(Basis(), Vector3(0, ARM_Y + hd, z)))
	_put(st, s, Transform3D(Basis(), Vector3(0, ARM_Y - hd, z)))
	# a staple eye under it
	var tm := TorusMesh.new()
	tm.inner_radius = 0.01
	tm.outer_radius = 0.017
	tm.rings = 10
	tm.ring_segments = 6
	_put(st, tm, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, y0 - 0.016, z)))
	# a bolt head on each side of the strap through the arm
	var c := CylinderMesh.new()
	c.top_radius = 0.009
	c.bottom_radius = 0.009
	c.height = ARM_W + 0.03
	c.radial_segments = 8
	_put(st, c, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, ARM_Y, z + 0.035)))
	return st.commit()

## The lantern frame in the pivot's space: hook and chain down from the origin, the top
## ring, cap and chimney, top frame, corner posts, guard wires and the base tray.
func _lantern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# an S-hook and two links from the staple
	for i in 5:
		_link(st, Vector3(0, -0.012 - i * 0.034, 0), 0.0 if i % 2 == 0 else PI * 0.5)
	var top := -DROP
	var hw := LW * 0.5
	var y_frame := top - FRAME_DOWN       # top frame (the cap sits on it)
	var y_base := top - LH
	# carrying ring over the chimney
	var tm := TorusMesh.new()
	tm.inner_radius = 0.016
	tm.outer_radius = 0.024
	tm.rings = 12
	tm.ring_segments = 6
	_put(st, tm, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, top - 0.004, 0)))
	# chimney: a short pipe with a pierced cone hat
	var c := CylinderMesh.new()
	c.top_radius = 0.026
	c.bottom_radius = 0.03
	c.height = 0.045
	c.radial_segments = 12
	_put(st, c, Transform3D(Basis(), Vector3(0, top - 0.055, 0)))
	var hat := CylinderMesh.new()
	hat.top_radius = 0.004
	hat.bottom_radius = 0.042
	hat.height = 0.028
	hat.radial_segments = 12
	_put(st, hat, Transform3D(Basis(), Vector3(0, top - 0.03, 0)))
	# pyramid cap from the top frame up to the chimney foot (a 4-sided cone)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.045
	cap.bottom_radius = (hw + 0.018) * sqrt(2.0)
	cap.height = (top - 0.075) - (y_frame + 0.006)
	cap.radial_segments = 4
	cap.rings = 1
	_put(st, cap, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, (top - 0.075 + y_frame + 0.006) * 0.5, 0)))
	# top frame and base tray: square rims
	for y in [y_frame, y_base + 0.02]:
		var t := 0.014 if y == y_frame else 0.02
		var r := hw + 0.012
		for sgn in [-1.0, 1.0]:
			var bx := BoxMesh.new()
			bx.size = Vector3(r * 2.0 + 0.014, t, 0.014)
			_put(st, bx, Transform3D(Basis(), Vector3(0, y, sgn * r)))
			bx = BoxMesh.new()
			bx.size = Vector3(0.014, t, r * 2.0)
			_put(st, bx, Transform3D(Basis(), Vector3(sgn * r, y, 0)))
	# base plate under the tray, with four small feet
	var bp := BoxMesh.new()
	bp.size = Vector3(LW + 0.03, 0.008, LW + 0.03)
	_put(st, bp, Transform3D(Basis(), Vector3(0, y_base + 0.01, 0)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var ft := SphereMesh.new()
			ft.radius = 0.011
			ft.height = 0.022
			ft.radial_segments = 8
			ft.rings = 4
			_put(st, ft, Transform3D(Basis(), Vector3(sx * (hw + 0.006), y_base + 0.004, sz * (hw + 0.006))))
			# corner posts, with a knop at the top
			_bar(st, Vector3(sx * (hw + 0.01), y_base + 0.02, sz * (hw + 0.01)), Vector3(sx * (hw + 0.01), y_frame, sz * (hw + 0.01)), 0.011)
			var kn := SphereMesh.new()
			kn.radius = 0.012
			kn.height = 0.024
			kn.radial_segments = 8
			kn.rings = 4
			_put(st, kn, Transform3D(Basis(), Vector3(sx * (hw + 0.012), y_frame + 0.012, sz * (hw + 0.012))))
	# guard wires over the panes: two uprights and a mid rail each side
	for side in 4:
		var yaw := side * PI * 0.5
		var b := Basis(Vector3.UP, yaw)
		var o := hw + 0.014
		for u in [-0.33, 0.33]:
			_bar(st, b * Vector3(u * hw * 2.0 * 0.5, y_base + 0.03, o), b * Vector3(u * hw * 2.0 * 0.5, y_frame - 0.008, o), 0.004)
		_bar(st, b * Vector3(-hw, (y_base + y_frame) * 0.5, o), b * Vector3(hw, (y_base + y_frame) * 0.5, o), 0.005)
	# the door's latch and hinge pins on the front (+z)
	_bar(st, Vector3(hw * 0.7, (y_base + y_frame) * 0.5 - 0.02, hw + 0.02), Vector3(hw * 0.7, (y_base + y_frame) * 0.5 + 0.03, hw + 0.02), 0.008)
	# the candle pricket cup on the tray
	var cup := CylinderMesh.new()
	cup.top_radius = 0.03
	cup.bottom_radius = 0.022
	cup.height = 0.012
	cup.radial_segments = 12
	_put(st, cup, Transform3D(Basis(), Vector3(0, y_base + 0.02, 0)))
	return st.commit()

## Four horn panes set just inside the corner posts, UV v = 0 at the top.
func _horn_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := LW * 0.5 + 0.008
	var y0 := -DROP - LH + 0.03
	var y1 := -DROP - FRAME_DOWN - 0.007
	for side in 4:
		var b := Basis(Vector3.UP, side * PI * 0.5)
		var n := b * Vector3(0, 0, 1)
		var p := [b * Vector3(-hw, y1, hw), b * Vector3(hw, y1, hw), b * Vector3(hw, y0, hw), b * Vector3(-hw, y0, hw)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		_tri(st, [p[0], p[1], p[2]], n, [uv[0], uv[1], uv[2]])
		_tri(st, [p[0], p[2], p[3]], n, [uv[0], uv[2], uv[3]])
	return st.commit()

## A tallow stub burnt down unevenly, a drip run down one side, base at y = 0.
func _candle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := CylinderMesh.new()
	c.top_radius = 0.021
	c.bottom_radius = 0.023
	c.height = 0.085
	c.radial_segments = 14
	c.rings = 3
	_put(st, c, Transform3D(Basis(), Vector3(0, 0.0425, 0)))
	var drip := CapsuleMesh.new()
	drip.radius = 0.006
	drip.height = 0.05
	drip.radial_segments = 6
	drip.rings = 2
	_put(st, drip, Transform3D(Basis(), Vector3(0.019, 0.055, 0.006)))
	# the wick
	var wk := CylinderMesh.new()
	wk.top_radius = 0.0012
	wk.bottom_radius = 0.0016
	wk.height = 0.014
	wk.radial_segments = 4
	_put(st, wk, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.091, 0)))
	return st.commit()
