class_name Staff
extends MeshInstance3D
## The hero's staff, built procedurally as a lathe: worn bronze end caps with machined ridges,
## a red-brown lacquered shaft and a cloth-wrapped grip. One surface; COLOR.r selects the
## material in staff.gdshader (0 wood, 0.5 metal, 1 cloth), UV = (around, metres along).

const LENGTH := 1.86
const SEGMENTS := 28
const WOOD := 0.0
const METAL := 0.5
const CLOTH := 1.0

func _ready() -> void:
	mesh = build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/staff.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

## Profile from the butt (v = 0) to the tip: [v, radius, material]. Mirrored for the top end.
static func _profile() -> Array:
	var cap := [
		[0.000, 0.000, METAL], [0.000, 0.017, METAL], [0.004, 0.022, METAL],
		[0.010, 0.0245, METAL], [0.030, 0.0245, METAL], [0.034, 0.0265, METAL],
		[0.040, 0.0265, METAL], [0.044, 0.0240, METAL], [0.080, 0.0236, METAL],
		[0.084, 0.0258, METAL], [0.090, 0.0258, METAL], [0.094, 0.0236, METAL],
		[0.140, 0.0230, METAL], [0.146, 0.0250, METAL], [0.156, 0.0250, METAL],
		[0.162, 0.0212, METAL], [0.162, 0.0205, WOOD],
	]
	var p: Array = []
	for c in cap:
		p.append(c)
	# shaft swells slightly toward the middle; cloth grip wraps the balance point
	var grip0 := LENGTH * 0.40
	var grip1 := LENGTH * 0.60
	p.append([grip0 - 0.004, 0.0210, WOOD])
	p.append([grip0 - 0.004, 0.0210, CLOTH])
	p.append([grip0, 0.0228, CLOTH])
	p.append([grip1, 0.0228, CLOTH])
	p.append([grip1 + 0.004, 0.0210, CLOTH])
	p.append([grip1 + 0.004, 0.0210, WOOD])
	for i in range(cap.size() - 1, -1, -1):
		var c: Array = cap[i]
		p.append([LENGTH - c[0], c[1], c[2]])
	return p

static func build_mesh() -> ArrayMesh:
	var prof := _profile()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		if a[2] != b[2]:
			continue              # material seam: zero-length band
		var dv: float = b[0] - a[0]
		var dr: float = b[1] - a[1]
		if absf(dv) < 1e-6 and absf(dr) < 1e-6:
			continue
		var col := Color(a[2], 0, 0)
		for s in SEGMENTS:
			var t0 := float(s) / SEGMENTS
			var t1 := float(s + 1) / SEGMENTS
			var quad := [[t0, a], [t1, a], [t1, b], [t0, a], [t1, b], [t0, b]]
			for q in quad:
				var t: float = q[0]
				var pr: Array = q[1]
				var ang := t * TAU
				var radial := Vector3(cos(ang), 0, sin(ang))
				# outward normal of the band's cone, tilted by the profile slope
				var n := (radial * dv - Vector3.UP * dr).normalized()
				st.set_normal(n)
				st.set_color(col)
				st.set_uv(Vector2(t, pr[0]))
				st.add_vertex(radial * float(pr[1]) + Vector3.UP * (float(pr[0]) - LENGTH * 0.5))
	st.generate_tangents()
	return st.commit()
