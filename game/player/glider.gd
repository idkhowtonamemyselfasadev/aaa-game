class_name Glider
extends Node3D
## Caelum's glider: a swept wing of oiled hemp sailcloth on a bamboo frame, held overhead by a
## cloth-wrapped crossbar. Built procedurally in body space (the body faces +Z, the hands on
## the bar). One mesh; COLOR.r selects the material in glider.gdshader (0 bamboo, 0.5 cord and
## wrap, 1 canvas), COLOR.g is the canvas's billow between ribs (0 at a rib, 1 mid-panel),
## COLOR.b the span position 0..1 (tip to tip). It unfurls from the middle out when opened.

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
var _mesh: MeshInstance3D
var _mat: ShaderMaterial

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = build_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/glider.gdshader")
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)
	visible = false

## Wrist targets on the crossbar (body space), left then right.
static func grips() -> Array:
	return [Vector3(BAR_HALF * 0.8, BAR_Y - 0.03, BAR_Z), Vector3(-BAR_HALF * 0.8, BAR_Y - 0.03, BAR_Z)]

func _process(delta: float) -> void:
	open = move_toward(open, 1.0 if want_open else 0.0, delta / (OPEN_TIME if want_open else FURL_TIME))
	visible = open > 0.01
	if not visible:
		return
	_mat.set_shader_parameter("open", open)
	_mat.set_shader_parameter("gust", gust)
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
	# c in 0..1 from the leading edge back; the cloth billows up between ribs, more aft
	var p := _lead(s)
	var ch := _chord(s)
	var rib := (s * 0.5 + 0.5) * (RIBS - 1)
	var panel := sin(PI * fposmod(rib, 1.0))
	var camber := sin(PI * minf(c * 1.25, 1.0)) * 0.07 * ch
	var billow := panel * 0.065 * sin(PI * clampf(c * 1.1, 0.0, 1.0))
	p.z -= c * ch
	p.y += camber + billow - c * 0.05
	# the trailing edge scallops between the ribs
	if c > 0.999:
		p.z += panel * 0.07
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
				st.set_normal(n)
				st.add_vertex(p + n * r)
