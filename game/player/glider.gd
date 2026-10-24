class_name Glider
extends Node3D
## Caelum's glider: a swept wing of oiled hemp sailcloth on a bamboo frame, held overhead by a
## cloth-wrapped crossbar. Built procedurally in body space (the body faces +Z, the hands on
## the bar). One mesh; COLOR.r selects the material in glider.gdshader (0 bamboo, 0.5 cord and
## wrap, 1 canvas), COLOR.g is the canvas's billow between ribs (0 at a rib, 1 mid-panel),
## COLOR.b the span position 0..1 (tip to tip); the canvas's UV2 = (chord 0..1 from the nose,
## span -1..1). It unfurls from the middle out when opened.

const SPAN := 3.3
const ROOT_CHORD := 1.45
const TIP_CHORD := 0.55
const SWEEP := 0.42           # m the tips sit behind the nose
const ARCH := 0.42            # m the tips droop below the centre (a shallow arch, like a canopy)
const CANOPY_Y := 2.44        # body space: the canopy's centre leading edge
const NOSE_Z := 0.62
const BAR_Y := 1.79           # the crossbar the hands hold
const BAR_HALF := 0.3
const BAR_Z := 0.12
const CAMBER := 0.11          # of the chord: how deep the sail bellies
const BILLOW := 0.085         # m the cloth puffs up between two battens
const RIBS := 9               # battens across the span (odd: one on the keel)
const BAMBOO := 0.0
const CORD := 0.5
const CANVAS := 1.0

const OPEN_TIME := 0.28       # seconds to snap the wing out
const FURL_TIME := 0.4
var want_open := false
var open := 0.0               # 0 furled .. 1 spread
var bank := 0.0               # radians the wing rolls into a turn
var gust := 0.0               # 0 still air .. 1 a storm gust working the cloth
var fill := 1.0               # 0 slack .. 1 the air at gliding speed pressing the panels full
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var stowed: MeshInstance3D    # the furled roll on the back, shown while the wing is folded

## Furled, the wing rides across the small of the back on the sash: the battens and the
## folded spar rolled up in the canvas, bound with cord, tucked over the staff and under the
## cape's hem. Body space at rest; the roll's axis runs across the back (X).
const STOW_AT := Vector3(0.0, 1.115, -0.335)   # posed it lands ~5 cm higher, on the sash
const STOW_LEN := 0.64
const STOW_R := 0.05
const STOW_BONE := "mixamorig_Spine2"   # with the staff: the hips and low spine turn ~40° in the idle

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = build_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/glider.gdshader")
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)
	visible = false

## Hangs the furled roll on the upper spine, square with the staff it is tucked over. `body` faces +Z.
func stow_on(skel: Skeleton3D, body: Node3D) -> void:
	var bone := skel.find_bone(STOW_BONE)
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "GliderSlot"
	skel.add_child(att)
	att.bone_name = STOW_BONE
	stowed = MeshInstance3D.new()
	stowed.name = "GliderStowed"
	stowed.mesh = build_stowed_mesh()
	var m := ShaderMaterial.new()
	m.shader = _mat.shader
	m.set_shader_parameter("open", 1.0)
	stowed.material_override = m
	att.add_child(stowed)
	# slung a touch low on the left, where the staff's foot crosses under it
	var b := Basis(Vector3.BACK, -0.06) * Basis(Vector3.RIGHT, 0.08)
	var want := body.global_transform * Transform3D(b, STOW_AT)
	var bone_rest := skel.global_transform * skel.get_bone_global_rest(bone)
	stowed.transform = bone_rest.affine_inverse() * want

## Wrist targets on the crossbar (body space), left then right.
static func grips() -> Array:
	return [Vector3(BAR_HALF * 0.8, BAR_Y - 0.03, BAR_Z), Vector3(-BAR_HALF * 0.8, BAR_Y - 0.03, BAR_Z)]

func _process(delta: float) -> void:
	open = move_toward(open, 1.0 if want_open else 0.0, delta / (OPEN_TIME if want_open else FURL_TIME))
	visible = open > 0.01
	if stowed != null:
		stowed.visible = not visible
	if not visible:
		return
	_mat.set_shader_parameter("open", open)
	_mat.set_shader_parameter("gust", gust)
	_mat.set_shader_parameter("fill", fill)
	_mesh.transform = bar_transform()

## The wing pivots on the bar: it rolls into the turn and pitches a touch nose-up.
func bar_transform() -> Transform3D:
	var pivot := Vector3(0, BAR_Y, BAR_Z)
	var b := Basis(Vector3.BACK, -bank) * Basis(Vector3.RIGHT, -0.06 * open)
	return Transform3D(b, pivot - b * pivot)

static func _lead(s: float) -> Vector3:
	# s in -1..1 across the span
	var a := absf(s)
	return Vector3(s * SPAN * 0.5, CANOPY_Y - ARCH * a * a, NOSE_Z - SWEEP * a)

static func _chord(s: float) -> float:
	return lerpf(ROOT_CHORD, TIP_CHORD, pow(absf(s), 1.3))

static func _canvas_point(s: float, c: float) -> Vector3:
	# c in 0..1 from the leading edge back. The sail is an airfoil, not a card: it bellies up
	# to its deepest a third of the way back, flattens and droops toward the trailing edge,
	# twists nose-down toward the tips (washout), and puffs up between the battens
	var p := _lead(s)
	var ch := _chord(s)
	var a := absf(s)
	var rib := (s * 0.5 + 0.5) * (RIBS - 1)
	var panel := sin(PI * fposmod(rib, 1.0))
	var camber := sin(PI * pow(c, 0.72)) * CAMBER * ch * (1.0 - 0.35 * a)
	var billow := panel * BILLOW * pow(sin(PI * clampf(c * 1.08, 0.0, 1.0)), 0.8)
	var washout := a * a * c * ch * 0.16
	p.z -= c * ch
	p.y += camber + billow + washout - c * c * 0.07
	# the trailing edge scallops between the ribs, the slack cloth there sagging a little
	if c > 0.999:
		p.z += panel * 0.07
		p.y -= panel * 0.015
	return p

static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# canvas: both faces, a fine grid so the billow and scallops read
	var nu := (RIBS - 1) * 6
	var nv := 14
	for side in 2:
		for i in nu:
			for j in nv:
				var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
				if side == 1:
					quad = [[i, j], [i + 1, j + 1], [i + 1, j], [i, j], [i, j + 1], [i + 1, j + 1]]
				for q in quad:
					var s := -1.0 + 2.0 * float(q[0]) / nu
					var c := float(q[1]) / nv
					var p := _canvas_point(s, c)
					var du := _canvas_point(minf(s + 0.01, 1.0), c) - _canvas_point(maxf(s - 0.01, -1.0), c)
					var dv := _canvas_point(s, minf(c + 0.02, 1.0)) - _canvas_point(s, maxf(c - 0.02, 0.0))
					var n := dv.cross(du).normalized()
					if n.y < 0.0:
						n = -n
					if side == 1:
						n = -n
					var rib := (s * 0.5 + 0.5) * (RIBS - 1)
					st.set_color(Color(CANVAS, sin(PI * fposmod(rib, 1.0)), s * 0.5 + 0.5, float(side)))
					st.set_uv(Vector2(p.x, c * _chord(s)))
					st.set_uv2(Vector2(c, s))
					st.set_normal(n)
					st.add_vertex(p)
	# bamboo leading-edge spar, just under the cloth's front hem
	var lead: Array = []
	for k in 25:
		var s := -1.0 + 2.0 * k / 24.0
		lead.append(_lead(s) + Vector3(0, -0.012, 0.01))
	_tube(st, lead, 0.019, BAMBOO)
	# battens under each rib, thinner toward the tips
	for r in RIBS:
		var s := -1.0 + 2.0 * r / (RIBS - 1)
		var pts: Array = []
		for k in 9:
			pts.append(_canvas_point(s, k / 8.0) + Vector3(0, -0.012, 0))
		_tube(st, pts, 0.012 if r == RIBS / 2 else 0.008, BAMBOO)
	# the crossbar, its grips bound in cloth, and two struts up to the keel and spar
	_tube(st, [Vector3(-BAR_HALF, BAR_Y, BAR_Z), Vector3(BAR_HALF, BAR_Y, BAR_Z)], 0.017, BAMBOO)
	for sg: float in [-1.0, 1.0]:
		_tube(st, [Vector3(sg * BAR_HALF * 0.55, BAR_Y, BAR_Z), Vector3(sg * BAR_HALF * 1.0, BAR_Y, BAR_Z)], 0.021, CORD)
		var top := _canvas_point(sg * 0.28, 0.3) + Vector3(0, -0.015, 0)
		_tube(st, [Vector3(sg * (BAR_HALF - 0.01), BAR_Y, BAR_Z), top], 0.013, BAMBOO)
		# rigging cords from the bar's ends out to the spar and back to the trailing ribs
		for c: Vector2 in [Vector2(0.62, 0.02), Vector2(0.62, 0.75), Vector2(0.95, 0.1)]:
			_tube(st, [Vector3(sg * BAR_HALF, BAR_Y, BAR_Z), _canvas_point(sg * c.x, c.y) + Vector3(0, -0.012, 0)], 0.0035, CORD, 4)
	_tube(st, [Vector3(0, BAR_Y, BAR_Z), _canvas_point(0.0, 0.05) + Vector3(0, -0.02, 0)], 0.012, BAMBOO)
	st.generate_tangents()
	return st.commit()

## The furled roll: canvas wound round the bundled battens, lumpy where the cloth bunched,
## cinched in at three cord bindings and gathered closed at the ends, with the bamboo poking
## out of both ends and two cord loops down to the sash. Centred on the origin, axis along X.
## The canvas UV runs in metres (across = round the roll from a sewn-edge offset, back = along)
## so the shader's panels, patches and stains land on it at their true size.
static func build_stowed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := STOW_LEN * 0.5
	var binds: Array[float] = [-0.21, 0.0, 0.21]
	var nx := 40
	var na := 20
	var rad := func(x: float, a: float) -> float:
		var t := x / half
		var cinch := 0.0
		for bx in binds:
			cinch = maxf(cinch, exp(-pow((x - bx) / 0.022, 2.0)))
		var r := STOW_R * (1.0 - 0.16 * cinch)
		# the cloth bunches: a slow spiral bulge and a few creased lumps
		r += 0.006 * sin(a * 3.0 + x * 9.0) + 0.004 * sin(a * 7.0 - x * 23.0)
		r += 0.0035 * sin(a * 2.0 + 1.3) * sin(x * 31.0)
		# gathered toward the ends
		r *= 1.0 - 0.55 * pow(smoothstep(0.82, 1.0, absf(t)), 1.5)
		return r
	var pt := func(x: float, a: float) -> Vector3:
		var r: float = rad.call(x, a)
		return Vector3(x, cos(a) * r, sin(a) * r)
	for i in nx:
		for j in na:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for q in quad:
				var x := -half + STOW_LEN * float(q[0]) / nx
				var a := TAU * float(q[1]) / na
				var p: Vector3 = pt.call(x, a)
				var dx: Vector3 = (pt.call(x + 0.004, a) as Vector3) - (pt.call(x - 0.004, a) as Vector3)
				var da: Vector3 = (pt.call(x, a + 0.05) as Vector3) - (pt.call(x, a - 0.05) as Vector3)
				var n := dx.cross(da).normalized()
				if n.dot(Vector3(0, p.y, p.z)) < 0.0:
					n = -n
				# (alpha 1: the rolled cloth shows its duller back, no pale batten ridges)
				st.set_color(Color(CANVAS, 0.0, 0.5 + x, 1.0))
				# round the roll: one turn is ~0.3 m of cloth; start past the tarred binding
				st.set_uv(Vector2(x + 0.9, 0.35 + a * STOW_R))
				st.set_uv2(Vector2.ZERO)
				st.set_normal(n)
				st.add_vertex(p)
	# end caps: the cloth twisted shut round the bamboo
	for sg: float in [-1.0, 1.0]:
		var c := Vector3(sg * (half + 0.012), 0, 0)
		for j in na:
			var a0 := TAU * float(j) / na
			var a1 := TAU * float(j + 1) / na
			var tri := [c, pt.call(sg * half, a1), pt.call(sg * half, a0)] if sg > 0.0 else [c, pt.call(sg * half, a0), pt.call(sg * half, a1)]
			for v: Vector3 in tri:
				st.set_color(Color(CANVAS, 0.0, 0.5 + v.x, 0.0))
				st.set_uv(Vector2(v.x + 0.9, 0.5 + 0.02 * j))
				st.set_uv2(Vector2.ZERO)
				st.set_normal(Vector3(sg, 0, 0))
				st.add_vertex(v)
	# the bundled bamboo: the folded spar halves and a few battens, ends cut at staggered lengths
	var poles := [[0.0, 0.0, 0.017, 0.11, 0.07], [0.018, 0.012, 0.012, 0.15, 0.04],
			[-0.016, 0.014, 0.009, 0.06, 0.13], [0.006, -0.019, 0.008, 0.09, 0.1]]
	for pl: Array in poles:
		_tube(st, [Vector3(-half - float(pl[4]), pl[1], pl[0]), Vector3(half + float(pl[3]), pl[1], pl[0])], pl[2], BAMBOO, 7)
	# three cord bindings, two turns each, sunk into the cinched cloth
	for bx in binds:
		for turn: float in [-0.007, 0.007]:
			var ring: Array = []
			for k in 17:
				var a := TAU * k / 16.0
				var r: float = rad.call(bx + turn, a) + 0.003
				ring.append(Vector3(bx + turn, cos(a) * r, sin(a) * r))
			_tube(st, ring, 0.0035, CORD, 5)
	# two cord loops from the outer bindings down under the sash (the roll's front-bottom)
	for bx: float in [binds[0], binds[2]]:
		_tube(st, [Vector3(bx, -STOW_R * 0.6, STOW_R * 0.7), Vector3(bx, -STOW_R - 0.02, STOW_R + 0.006),
				Vector3(bx * 0.95, -STOW_R - 0.06, STOW_R + 0.012)], 0.0035, CORD, 5)
	st.generate_tangents()
	return st.commit()

## A round tube along a polyline. UV = (around, metres along); COLOR.b carries the span
## position of each ring so the unfurl gathers the frame with the cloth.
static func _tube(st: SurfaceTool, pts: Array, r: float, mat: float, seg := 8) -> void:
	var along := 0.0
	var rings: Array = []
	for k in pts.size():
		var p: Vector3 = pts[k]
		var t: Vector3 = ((pts[mini(k + 1, pts.size() - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var a := t.cross(Vector3.UP)
		if a.length() < 0.1:
			a = t.cross(Vector3.RIGHT)
		a = a.normalized()
		var b := t.cross(a).normalized()
		if k > 0:
			along += p.distance_to(pts[k - 1])
		rings.append([p, a, b, along])
	for k in rings.size() - 1:
		for i in seg:
			var quad := [[k, i], [k + 1, i], [k + 1, i + 1], [k, i], [k + 1, i + 1], [k, i + 1]]
			for q in quad:
				var rg: Array = rings[q[0]]
				var ang := TAU * float(q[1]) / seg
				var n: Vector3 = (rg[1] as Vector3) * cos(ang) + (rg[2] as Vector3) * sin(ang)
				var p: Vector3 = rg[0]
				st.set_color(Color(mat, 0.0, clampf(p.x / SPAN + 0.5, 0.0, 1.0), 0.0))
				st.set_uv(Vector2(float(q[1]) / seg, rg[3]))
				st.set_uv2(Vector2.ZERO)
				st.set_normal(n)
				st.add_vertex(p + n * r)
