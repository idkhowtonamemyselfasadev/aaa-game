class_name HeroGarb
extends HollowRags
## The hero's travelling garb over the old armour: an indigo wool hood under a wide woven
## straw hat, a dark shoulder mantle, long madder-dyed robe panels to the shins front and back,
## an ochre sash and undyed linen bindings on the legs and forearms. Built and animated like the
## Hollow rags (body space, hung on bones, panels pushed by the thighs, hems trailing motion),
## but clean dyed cloth: no ash, no burns, no ember.

const INDIGO := [Color(0.030, 0.034, 0.048), Color(0.15, 0.16, 0.21), 0.25]
const MANTLE := [Color(0.045, 0.036, 0.030), Color(0.24, 0.20, 0.16), 0.3]
const MADDER := [Color(0.085, 0.032, 0.022), Color(0.40, 0.17, 0.10), 0.35]
const OCHRE := [Color(0.16, 0.10, 0.035), Color(0.58, 0.40, 0.17), 0.2]
const LINEN := [Color(0.17, 0.15, 0.12), Color(0.60, 0.55, 0.46), 0.3]
const STRAW := [Color(0.20, 0.15, 0.075), Color(0.66, 0.53, 0.31), 0.15]

var hat: MeshInstance3D
var veil: MeshInstance3D
var face: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var fill: OmniLight3D

## Eye centres (x, y) in garb space, the depth the eyeballs' fronts sit at, and their radius.
const EYE_X := 0.031
const EYE_Y := 1.968
const EYE_R := 0.0125

func build(skel: Skeleton3D, body: Node3D) -> void:
	_skel = skel
	_body = body
	layer = 1
	# the long robe hangs clear of the hero's relaxed stance (idle front leg ~0.45 rad); only a
	# real stride pushes it
	swing_slack = 0.45
	var head := _attach_sized(BONE_HEAD)
	var chest := _attach_sized(BONE_CHEST)
	var hips := _attach_sized(BONE_HIPS)
	_hips = skel.find_bone(BONE_HIPS)
	_hips_rest = _rest_in_body(_hips)
	for side in ["Left", "Right"]:
		_legs.append(PackedInt32Array([skel.find_bone("mixamorig_%sUpLeg" % side),
				skel.find_bone("mixamorig_%sLeg" % side)]))
	tint = INDIGO
	# the hero's hood is sewn, not torn like the Hollow's cowl: a straight turned and stitched
	# hem where it falls over the mantle
	var hood := _piece(_hood(), 0.0, 0.0, 0.0, 1.2)
	var hdm := hood.material_override as ShaderMaterial
	hdm.set_shader_parameter("wool", 1.0)
	hdm.set_shader_parameter("hem_band", 1.0)
	head.add_child(hood)
	veil = _piece(_veil(), 0.0, 0.0, 6.0, 0.5)
	var vm := veil.material_override as ShaderMaterial
	vm.set_shader_parameter("wool", 1.0)
	vm.set_shader_parameter("fold_ao", 1.0)
	head.add_child(veil)
	_add_face(head)
	tint = STRAW
	hat = _piece(_hat(), 0.0, 0.0, 4.0, 1.0)
	var hm := hat.material_override as ShaderMaterial
	hm.set_shader_parameter("rigid", 1.0)
	hm.set_shader_parameter("weave_scale", 150.0)
	hm.set_shader_parameter("aspect", 0.35)
	# worn pushed back a little on the hood, so the eye line shows under the front brim even
	# with the idle stance's head bowed
	var crown := Vector3(0.0, 2.10, -0.03)
	hat.transform = Transform3D(Basis(Vector3.RIGHT, -0.17), Vector3.ZERO).translated_local(-crown).translated(crown + Vector3.UP * 0.02)
	head.add_child(hat)
	tint = MANTLE
	var mantle := _piece(_drape(), 0.0, 0.012, 0.35, 1.0)
	var mm := mantle.material_override as ShaderMaterial
	mm.set_shader_parameter("fold_ao", 1.0)
	mm.set_shader_parameter("hem_band", 1.0)
	mm.set_shader_parameter("tongues", 3.0)
	# wider than the Hollow's so it covers the Vanguard's shoulder plates
	mantle.transform = Transform3D(Basis.from_scale(Vector3(1.16, 1.0, 1.12)), Vector3(0, 0.03, -0.005))
	chest.add_child(mantle)
	tint = MADDER
	_front = _panel(hips, Vector3(0, 1.20, 0.215), 0.30, 0.44, 0.90, 0.9, 1.0)
	_back = _panel(hips, Vector3(0, 1.21, -0.205), 0.34, 0.48, 0.96, -0.9, 2.0)
	tint = OCHRE
	hips.add_child(_piece(_sash(), 0.0, 0.0, 0.0, 0.25))
	tint = LINEN
	for side in ["Left", "Right"]:
		_wrap("mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, 0.14, 0.93, 0.01, 8.0)
		_wrap("mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side, 0.22, 0.97, 0.008, 6.0)
		_wrap("mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, 0.16, 0.90, 0.012, 9.0)
		_wrap("mixamorig_%sFoot" % side, "mixamorig_%sToeBase" % side, 0.0, 0.92, 0.008, 4.0)
	tint = []
	_last_pos = body.global_position

## The Hollow's pieces are shaped for its model scaled 1.06 x 1.08 x 1.06; the hero's model is
## at 1, so the shaped pieces hang under this scale (the wraps fit the mesh and need none).
const SIZE := Vector3(1.0 / 1.06, 1.0 / 1.08, 1.0 / 1.06)

func _attach_sized(bone: String) -> Node3D:
	var off := _attach(bone)
	off.transform = off.transform * Transform3D(Basis.from_scale(SIZE), Vector3.ZERO)
	return off

## The hero's hood: the Hollow's cowl, drawn a little forward round the face, with an oval
## face opening (an arch from the brow down past the eyes, then wide round the face cloth and
## closing at the throat) finished in a thick, slightly uneven rolled hem instead of a raw
## straight-edged cut. UV.x runs round the hood (the outer 12 % either side is the roll),
## UV.y from the crown to the throat.
const HOOD_ROLL := 0.12
const HOOD_YC := 1.952   # the arch's centre height, near the eye line
const HOOD_H := 0.088    # the arch's half height: its top sits under the hat at 2.04
const HOOD_W := 0.09     # the opening's half width from the eyes down

func _hood() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var gap := _hood_gap(v)
		if u > HOOD_ROLL and u < 1.0 - HOOD_ROLL:
			return _hood_at(lerpf(gap, TAU - gap, (u - HOOD_ROLL) / (1.0 - 2.0 * HOOD_ROLL)), v)
		var left := u <= HOOD_ROLL
		var ae := gap if left else TAU - gap
		var into := 1.0 if left else -1.0
		var phi := ((HOOD_ROLL - u) if left else (u - 1.0 + HOOD_ROLL)) / HOOD_ROLL * 1.45 * PI
		var p := _hood_at(ae, v)
		# the edge's tangent back into the hood and the outward normal off the cloth
		var t := (_hood_at(ae + into * 0.02, v) - p).normalized()
		var n := Vector3(p.x, 0.0, p.z + 0.06)
		n = (n - t * n.dot(t)).normalized()
		# the hem rolls out over the edge and lies back on the outside; thin at the arch's top,
		# where it runs into the crown seam, and a little uneven along its length
		var top_v := (2.09 - HOOD_YC - HOOD_H) / 0.43
		var rr := 0.0105 * (1.0 + 0.25 * sin(v * 31.0 + 1.3) + 0.12 * sin(v * 77.0)) \
				* smoothstep(top_v - 0.02, top_v + 0.07, v)
		return p + n * rr * (1.0 - cos(phi)) - t * rr * sin(phi), 64, 40)

## The hood surface at angle `a` round the head (0 = the front) and `v` from crown to throat.
func _hood_at(a: float, v: float) -> Vector3:
	var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.34, 1.0), 2.0), 0.0, 1.0))
	var r := dome * (1.0 + 0.45 * smoothstep(0.7, 1.0, v))
	r *= 1.0 + 0.03 * sin(a * 7.0) * v
	var cz := -0.045 - 0.06 * pow(1.0 - v, 3.0)
	# the cowl is drawn forward round the face, so its rim stands proud of the brow and cheeks
	var fwd := 0.045 * pow(cos(a) * 0.5 + 0.5, 4.0) * smoothstep(0.03, 0.12, v) \
			* (1.0 - smoothstep(0.5, 0.78, v))
	return Vector3(sin(a) * 0.168 * r, 2.09 - v * 0.43, cz + cos(a) * (0.192 * r + fwd))

## Half-angle of the face opening at `v`: an elliptic arch over the eyes, straight sides
## down the cheeks, then the Hollow cowl's wide gap round the face cloth closing at the throat.
func _hood_gap(v: float) -> float:
	var y := 2.09 - v * 0.43
	var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.34, 1.0), 2.0), 0.0, 1.0))
	var dy := maxf(y - HOOD_YC, 0.0) / HOOD_H
	var half := HOOD_W * sqrt(maxf(1.0 - dy * dy, 0.0)) * (1.0 + 0.05 * sin(v * 19.0 + 0.7))
	var arch := asin(clampf(half / (0.168 * maxf(dome, 0.05)), 0.0, 0.99))
	var low := 0.22 + 0.42 * smoothstep(0.12, 0.4, v) - 0.5 * smoothstep(0.72, 1.0, v)
	return lerpf(arch, low, smoothstep(0.42, 0.56, v))

## A conical woven straw hat (douli): a shallow cone from the crown point out to a wide brim
## that turns down a little at the rim, sitting low over the hood so the face is in its shade.
## UV.x runs round the hat, UV.y from the crown to the rim (the weave then reads as rings).
func _hat() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var r := 0.37 * v
		# a straight cone, a slightly fuller crown and a soft downturn over the last 15 %
		var y := 2.155 - 0.14 * v - 0.012 * sin(v * PI) - 0.03 * smoothstep(0.85, 1.0, v)
		# the plaited rim is a touch uneven
		r *= 1.0 + 0.006 * sin(a * 11.0) * v
		return Vector3(sin(a) * r, y, -0.03 + cos(a) * r), 48, 12)

## A face cloth of the same indigo wool wound across the face from the bridge of the nose to
## under the chin, hanging a little slack at the front; with the hat's shade only the eye line
## shows between it and the hood.
func _veil() -> ArrayMesh:
	var nu := 40
	var nv := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			# wound round past the ears and down over the throat, its lower edge tucked inside
			# the mantle's collar (1.72) all the way round, so no pale armour neck shows between
			# the cloth and the cape
			var a := lerpf(-1.65, 1.65, u)
			var front := cos(a)
			# soft folds hang from the nose bridge, deepening toward the chin and splitting a
			# little where the cloth bunches at the sides under the hood
			var phi := a * 7.0 + 0.8 * sin(a * 2.7 + 0.4) + 0.4 * sin(a * 6.3 + 1.1)
			var ridge := sin(phi)
			ridge = signf(ridge) * pow(absf(ridge), 0.7)
			var fine := sin(a * 17.0 + 0.6 + v * 3.0) * smoothstep(0.4, 1.0, v)
			var depth := smoothstep(0.1, 1.0, v)
			# the lower edge sags into a soft point under the chin
			var y := 1.935 - v * (0.235 + 0.06 * maxf(front, 0.0) * front) - 0.01 * ridge * depth
			# the top edge rides up over the bridge of the nose and sags into a soft dip under
			# each cheekbone before running back flat under the hood, instead of a ruled line
			var top := 1.0 - smoothstep(0.0, 0.35, v)
			y += top * (0.004 * pow(maxf(front, 0.0), 14.0) \
					- 0.008 * exp(-pow((absf(a) - 0.5) / 0.22, 2.0)) \
					+ 0.002 * sin(a * 5.0 + 0.9))
			var r := 1.0 + 0.06 * v * front + depth * (0.05 * ridge + 0.012 * fine)
			var cav := mix_cav(ridge, fine, depth)
			st.set_color(Color(cav, cav, cav))
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(sin(a) * 0.128 * r, y, -0.035 + front * 0.175 * r))
	for j in nv:
		for i in nu:
			var p0 := j * (nu + 1) + i
			var p1 := p0 + 1
			var p2 := p0 + nu + 1
			var p3 := p2 + 1
			st.add_index(p0); st.add_index(p1); st.add_index(p2)
			st.add_index(p1); st.add_index(p3); st.add_index(p2)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

## The face in the gap between the hood and the face cloth: a band of sun-browned skin from
## the brow to the bridge of the nose, with the brow ridge, the nose bridge and two shallow eye
## sockets shaped in, almond lid openings cut by skin.gdshader, and two wet eyeballs behind
## them. The band's sides tuck back under the hood and its lower edge under the face cloth.
func _add_face(head: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/skin.gdshader")
	mat.set_shader_parameter("eyes", Vector4(-EYE_X, EYE_Y, EYE_X, EYE_Y))
	face = MeshInstance3D.new()
	face.name = "Face"
	face.mesh = _grid(_face_point, 40, 14)
	face.material_override = mat
	face.layers = layer
	head.add_child(face)
	var emat := ShaderMaterial.new()
	emat.shader = preload("res://shaders/eye.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = EYE_R
	sphere.height = EYE_R * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "Eye"
		eye.mesh = sphere
		eye.material_override = emat
		eye.layers = layer
		# the cornea sits just under the lids, inside the socket (it used to stand 8 mm proud of
		# the socket floor, so the whole ball bulged through the skin round the opening: goggle
		# eyes); both eyes look a touch down the road, the upper lid over the top of the iris
		var front := _face_point_xy(side * EYE_X, EYE_Y, true).z
		eye.transform = Transform3D(Basis.from_euler(Vector3(0.12, -side * 0.04, 0.0)),
				Vector3(side * EYE_X, EYE_Y, front - EYE_R + 0.0008))
		head.add_child(eye)
		eye.set_instance_shader_parameter("side", side)
		eyes.append(eye)
	# a soft character fill under the brim, like a game's face light: the hat and hood put the
	# face in deep shade that the scene's ambient barely reaches, so without it the face reads
	# as a black hole at any range. Lights only the hero's layer, casts no shadow.
	fill = OmniLight3D.new()
	fill.name = "FaceFill"
	fill.light_color = Color(1.0, 0.86, 0.72)
	fill.light_energy = FILL_NOON
	fill.omni_range = 0.7
	fill.omni_attenuation = 1.6
	fill.shadow_enabled = false
	fill.light_cull_mask = layer
	# a fill this close drew a hot white dot on each wet eye; it should model the face, not
	# put a ring light in the eyes
	fill.light_specular = 0.12
	fill.position = Vector3(0.05, 1.93, 0.42)
	head.add_child(fill)

## Midday shade light (see `light_face`): the fill's noon energy was tuned against it.
const NOON_SHADE := 1.16
## The fill at noon: 0.26 lit the face like a bright orange doll under the brim; the hat's
## shade should still read as shade.
const FILL_NOON := 0.17

## Keep the face fill in step with the light the scene throws into the shade under the brim:
## a constant warm lamp glowed orange under a blue moonlit hat at night and went flat against
## the gold of a low sun. Energy follows the shade light (exposure lifts the dark hours), the
## colour is the shade light's own hue, kept a little warm by the skin it bounces off.
func light_face(shade: Color) -> void:
	if fill == null:
		return
	var lum := shade.r * 0.3 + shade.g * 0.59 + shade.b * 0.11
	var k := clampf(lum / NOON_SHADE, 0.0, 1.4)
	fill.light_energy = FILL_NOON * clampf(pow(k, 0.7), 0.12, 1.3)
	var hue := shade / maxf(maxf(shade.r, shade.g), maxf(shade.b, 1e-4))
	# at night the moonlit shade is blue-grey and the face went grey-lavender: keep more of the
	# skin's own warmth as the light falls
	fill.light_color = hue.lerp(Color(1.0, 0.86, 0.74), lerpf(0.62, 0.4, clampf(k, 0.0, 1.0)))

## A point of the face band: UV.x across the face, UV.y from the brow down to the nose bridge.
func _face_point(u: float, v: float) -> Vector3:
	var a := lerpf(-1.0, 1.0, u)
	return _face_point_xy(sin(a) * 0.09, lerpf(2.016, 1.926, v), true)

## The face surface at (x, y): a rounded front (0.19 m deep, 0.09 m wide) with the brow ridge,
## the nose bridge, the sockets and the cheekbones; `sockets` false gives the surface the
## eyeballs sit under (no socket dip).
func _face_point_xy(x: float, y: float, sockets: bool) -> Vector3:
	var s := clampf(x / 0.09, -1.0, 1.0)
	var a := asin(s)
	var z := -0.035 + cos(a) * 0.19
	# brow ridge over the eyes, the bridge of the nose running down the middle
	z += 0.006 * exp(-pow((y - 1.992) / 0.008, 2.0)) * (1.0 - smoothstep(0.05, 0.075, absf(x)))
	z += 0.007 * exp(-pow(x / 0.009, 2.0)) * smoothstep(1.995, 1.95, y)
	if sockets:
		for c in [-EYE_X, EYE_X]:
			var d := pow((x - c) / 0.019, 2.0) + pow((y - EYE_Y) / 0.011, 2.0)
			z -= 0.004 * exp(-d)
	# cheekbones forward under the outer eye corners, then the lower edge tucks back under the
	# face cloth and the sides under the hood
	z += 0.003 * exp(-pow((absf(x) - 0.045) / 0.015, 2.0)) * smoothstep(1.965, 1.945, y)
	z -= 0.02 * smoothstep(1.942, 1.926, y)
	z -= 0.03 * smoothstep(0.06, 0.09, absf(x))
	return Vector3(x, y, z)

## The shoulder mantle: a cape of heavy wool gathered at the neck that falls into deep,
## irregular folds over the shoulders and back. The folds start at the collar and deepen
## toward the hem; ridges hang a little lower than the valleys, so the hem scallops softly
## instead of ending on a straight cut. COLOR.r carries the fold cavity (1 on a ridge, dark in
## the valleys), read by rag.gdshader as AO when `fold_ao` is on.
func _drape() -> ArrayMesh:
	var nu := 84
	var nv := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var gap := 0.42
			var a := lerpf(gap, TAU - gap, u)
			var k := pow(v, 0.42)
			var rx := lerpf(0.135, 0.38, k)
			var rz := lerpf(0.135, 0.315, k)
			# fold phase: ~8 folds round the cape, unevenly spaced, a few splitting near the hem
			var phi := a * 8.0 + 0.9 * sin(a * 2.3 + 0.7) + 0.5 * sin(a * 5.1 + 2.0)
			var ridge := sin(phi)
			ridge = signf(ridge) * pow(absf(ridge), 0.65)
			var fine := sin(a * 19.0 + 1.3 + v * 2.0) * smoothstep(0.5, 1.0, v)
			var depth := smoothstep(0.05, 1.0, v)
			var fold := 1.0 + depth * (0.085 * ridge + 0.022 * fine)
			# the hem hangs lower at the back; ridges carry it a little lower than the valleys
			var hem := lerpf(1.44, 1.29, (1.0 - cos(a)) * 0.5) - 0.022 * ridge - 0.008 * fine
			# a slight roll at the collar where the cloth gathers round the neck
			var collar := 1.0 + 0.10 * (1.0 - smoothstep(0.0, 0.12, v))
			var y := lerpf(1.72, hem, v)
			var cav := mix_cav(ridge, fine, depth)
			st.set_color(Color(cav, cav, cav))
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(sin(a) * rx * fold * collar, y, -0.045 + cos(a) * rz * fold * collar))
	for j in nv:
		for i in nu:
			var p0 := j * (nu + 1) + i
			var p1 := p0 + 1
			var p2 := p0 + nu + 1
			var p3 := p2 + 1
			st.add_index(p0); st.add_index(p1); st.add_index(p2)
			st.add_index(p1); st.add_index(p3); st.add_index(p2)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func mix_cav(ridge: float, fine: float, depth: float) -> float:
	var c := 0.5 + 0.5 * ridge
	c = lerpf(1.0, 0.45 + 0.55 * c, depth) * (1.0 - 0.08 * maxf(-fine, 0.0) * depth)
	return c
