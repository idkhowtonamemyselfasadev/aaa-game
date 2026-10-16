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
## Per-piece colour overrides for another wearer (an NPC): keys hood, hat, mantle, robe, sash,
## wraps -> [dark, light, soot] like the constants below. Empty: the hero's own dyes.
var palette := {}
## Cut options for another wearer, set before build(): no straw hat (the hood alone), the robe
## panels' length as a factor of the hero's shin-length ones, and a wicker gathering basket
## worn on the back with deadwood standing out of it. The hero: hat, 1.0, no basket.
## robe_wide widens the panels; their hip wrap then curls them round the sides.
var hatless := false
var robe_len := 1.0
var robe_wide := 1.0     # panel width factor: wider panels curl round the hips into a skirt
var basket := false
var basket_node: Node3D
## Side gores: a wedge of the robe cloth sewn in under each side of the panels, from the sash
## to the hem, so a long robe closes into a skirt and the side view shows no legs or armour.
var skirt := false
var gores: Array[MeshInstance3D] = []

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
	tint = palette.get("hood", INDIGO)
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
	if not hatless:
		tint = palette.get("hat", STRAW)
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
	tint = palette.get("mantle", MANTLE)
	var mantle := _piece(_drape(), 0.0, 0.012, 0.35, 1.0)
	var mm := mantle.material_override as ShaderMaterial
	mm.set_shader_parameter("fold_ao", 1.0)
	mm.set_shader_parameter("hem_band", 1.0)
	mm.set_shader_parameter("tongues", 3.0)
	# wider than the Hollow's so it covers the Vanguard's shoulder plates
	mantle.transform = Transform3D(Basis.from_scale(Vector3(1.16, 1.0, 1.12)), Vector3(0, 0.03, -0.005))
	chest.add_child(mantle)
	tint = palette.get("robe", MADDER)
	_front = _panel(hips, Vector3(0, 1.20, 0.215), 0.30 * robe_wide, lerpf(0.44, 0.52, robe_len - 1.0) * robe_wide, 0.90 * robe_len, 0.9, 1.0)
	_back = _panel(hips, Vector3(0, 1.21, -0.205), 0.34 * robe_wide, lerpf(0.48, 0.56, robe_len - 1.0) * robe_wide, 0.96 * robe_len, -0.9, 2.0)
	if skirt:
		for sx in [-1.0, 1.0]:
			var g := _piece(_gore(sx), 0.06, 0.14, 40.0 + sx, GORE_LEN * robe_len / 0.42)
			(g.material_override as ShaderMaterial).set_shader_parameter("fold_ao", 1.0)
			hips.add_child(g)
			gores.append(g)
	tint = palette.get("sash", OCHRE)
	hips.add_child(_piece(_sash(), 0.0, 0.0, 0.0, 0.25))
	tint = palette.get("wraps", LINEN)
	for side in ["Left", "Right"]:
		_wrap("mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, 0.14, 0.93, 0.01, 8.0)
		_wrap("mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side, 0.22, 0.97, 0.008, 6.0)
		_wrap("mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, 0.16, 0.90, 0.012, 9.0)
		_wrap("mixamorig_%sFoot" % side, "mixamorig_%sToeBase" % side, 0.0, 0.92, 0.008, 4.0)
	if basket:
		_basket()
	tint = []
	_last_pos = body.global_position

func _physics_process(delta: float) -> void:
	super(delta)
	for g in gores:
		(g.material_override as ShaderMaterial).set_shader_parameter("gore_swing", Vector2(_swing_f, _swing_b))

## A side gore: an arc of cloth round the hip from 32 deg to 148 deg off the front, hung just
## inside the panels' curled edges (so they lie over its ends at the top and the hem) and just
## under the sash, flaring a little to the hem and falling in soft vertical folds that deepen
## toward the hem. COLOR.r is the fold cavity for the rag shader's fold_ao.
const GORE_LEN := 0.93
func _gore(sx: float) -> ArrayMesh:
	var mesh := _grid(func(u: float, v: float) -> Vector3:
		var a := lerpf(0.55, PI - 0.55, u)
		var rx := lerpf(0.245, 0.30, v)
		# a bell: deep fore and aft at the hem, so her idle stance's feet (+-0.29 m) stay inside
		var rz := lerpf(0.205, 0.34, pow(v, 1.2))
		var fold := 1.0 + (0.025 + 0.04 * v) * sin(u * PI * 7.0 + sx * 1.3 + 0.6 * sin(v * 3.0))
		return Vector3(sx * sin(a) * rx * fold, 1.21 - v * GORE_LEN * robe_len, cos(a) * rz * fold), 18, 18)
	# fold cavities: dark where the folds sink in
	var arr := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var cols := PackedColorArray()
	for t in uvs:
		var f := sin(t.x * PI * 7.0 + sx * 1.3 + 0.6 * sin(t.y * 3.0))
		cols.append(Color(clampf(0.5 + 0.5 * f, 0.0, 1.0) * t.y + (1.0 - t.y), 0, 0))
	arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

## A back basket of woven willow, oval and tapering to a narrow foot, its open mouth finished
## in a thick wrapped rim, worn high between the shoulder blades over the mantle and hung on
## the chest bone (plain body space, no Hollow sizing). Deadwood she gathered under the oaks
## stands out of the mouth, leaning back. Shoulder straps of plaited bast run up over the
## shoulders from its upper corners.
const BASKET_TOP := 1.50
const BASKET_FOOT := 0.98
const BASKET_Z := -0.35

func _basket() -> void:
	var chest := _attach(BONE_CHEST)
	basket_node = Node3D.new()
	basket_node.name = "Basket"
	# leans back off the shoulders a little, like a loaded pack
	basket_node.transform = Transform3D(Basis(Vector3.RIGHT, -0.10), Vector3.ZERO) \
			.translated_local(-Vector3(0, BASKET_TOP, -0.2)).translated(Vector3(0, BASKET_TOP, -0.2))
	chest.add_child(basket_node)
	tint = palette.get("basket", [Color(0.10, 0.065, 0.032), Color(0.46, 0.34, 0.19), 0.45])
	var h := BASKET_TOP - BASKET_FOOT
	var wall := _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		# slightly bellied, flattened against the back, taper to the foot; the stakes show as
		# shallow vertical ribs every 1/24 of the way round
		var t := 1.0 - v
		var rx := lerpf(0.15, 0.215, t) + 0.012 * sin(t * PI)
		var rz := lerpf(0.11, 0.16, t) + 0.010 * sin(t * PI)
		var rib := 1.0 + 0.018 * pow(absf(cos(a * 12.0)), 6.0)
		var sag := 0.006 * sin(a * 3.0 + 1.7) * t
		return Vector3(sin(a) * rx * rib, BASKET_TOP - v * h + sag, BASKET_Z + cos(a) * rz * rib), 48, 14)
	var wm := _piece(wall, 0.0, 0.0, 9.0, 1.0)
	var m := wm.material_override as ShaderMaterial
	m.set_shader_parameter("rigid", 1.0)
	m.set_shader_parameter("weave_scale", 34.0)
	m.set_shader_parameter("aspect", h / 1.15)
	basket_node.add_child(wm)
	# the foot: a woven base dished up a little
	var foot := _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		return Vector3(sin(a) * 0.15 * v, BASKET_FOOT + 0.015 * (1.0 - v), BASKET_Z + cos(a) * 0.11 * v), 24, 4)
	var fm := _piece(foot, 0.0, 0.0, 10.0, 1.0)
	(fm.material_override as ShaderMaterial).set_shader_parameter("rigid", 1.0)
	(fm.material_override as ShaderMaterial).set_shader_parameter("weave_scale", 20.0)
	basket_node.add_child(fm)
	# the wrapped rim and two hoops lower down
	for hoop in [[0.0, 0.02], [0.45, 0.011], [0.93, 0.012]]:
		var t: float = 1.0 - hoop[0]
		var rx := lerpf(0.15, 0.215, t) + 0.012 * sin(t * PI)
		var rz := lerpf(0.11, 0.16, t) + 0.010 * sin(t * PI)
		var y: float = BASKET_TOP - hoop[0] * h
		var rr: float = hoop[1]
		var ring := _grid(func(u: float, v: float) -> Vector3:
			var a := u * TAU
			var b := v * TAU
			var c := Vector3(sin(a) * rx, y, BASKET_Z + cos(a) * rz)
			var out := Vector3(sin(a), 0, cos(a))
			# a wrapped rod: the binding spirals round it
			var wr := rr * (1.0 + 0.12 * absf(sin(a * 70.0 + b)))
			return c + out * cos(b) * wr + Vector3.UP * sin(b) * wr, 72, 6)
		var rm := _piece(ring, 0.0, 0.0, 11.0 + hoop[0], 1.0)
		(rm.material_override as ShaderMaterial).set_shader_parameter("rigid", 1.0)
		(rm.material_override as ShaderMaterial).set_shader_parameter("weave_scale", 90.0)
		basket_node.add_child(rm)
	# deadwood: crooked oak sticks standing in the mouth, leaning back and splaying
	tint = palette.get("deadwood", [Color(0.055, 0.045, 0.036), Color(0.36, 0.32, 0.27), 0.5])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for k in 9:
		var base := Vector3(rng.randf_range(-0.12, 0.12), BASKET_TOP - 0.25, BASKET_Z + rng.randf_range(-0.08, 0.06))
		var ln := rng.randf_range(0.42, 0.78)
		var lean := Vector3(base.x * 1.2 + rng.randf_range(-0.08, 0.08), 1.0, -0.22 + rng.randf_range(-0.1, 0.06)).normalized()
		var r0 := rng.randf_range(0.011, 0.02)
		var kink := rng.randf_range(0.0, TAU)
		var stick := _grid(func(u: float, v: float) -> Vector3:
			var a := u * TAU
			# crooked: two soft kinks off the lean, tapering to a snapped tip
			var off := Vector3(cos(kink), 0, sin(kink)) * 0.035 * sin(v * PI * 1.6) * ln
			var c := base + lean * v * ln + off
			var side := lean.cross(Vector3.FORWARD).normalized()
			var up2 := side.cross(lean).normalized()
			var r := r0 * (1.0 - 0.45 * v) * (1.0 + 0.1 * sin(v * 23.0 + a * 2.0))
			return c + (side * cos(a) + up2 * sin(a)) * r, 7, 6)
		var sm := _piece(stick, 0.0, 0.0, 20.0 + k, 1.0)
		var sh := sm.material_override as ShaderMaterial
		sh.set_shader_parameter("rigid", 1.0)
		sh.set_shader_parameter("weave_scale", 12.0)
		sh.set_shader_parameter("aspect", ln / (r0 * TAU) * 0.15)
		basket_node.add_child(sm)
	# plaited bast straps from the rim's upper corners over the shoulders to under the arms
	tint = palette.get("strap", [Color(0.07, 0.05, 0.03), Color(0.40, 0.31, 0.19), 0.4])
	for sx in [-1.0, 1.0]:
		var pts := [Vector3(0.10 * sx, BASKET_TOP - 0.03, BASKET_Z + 0.15), Vector3(0.12 * sx, 1.585, -0.12),
				Vector3(0.14 * sx, 1.60, 0.02), Vector3(0.155 * sx, 1.52, 0.135), Vector3(0.17 * sx, 1.34, 0.12)]
		var strap := _grid(func(u: float, v: float) -> Vector3:
			var f := v * (pts.size() - 1)
			var i := mini(int(f), pts.size() - 2)
			var p: Vector3 = (pts[i] as Vector3).lerp(pts[i + 1], f - i)
			var dir: Vector3 = ((pts[i + 1] as Vector3) - pts[i]).normalized()
			var n := Vector3(p.x * 0.6, 0.0, p.z).normalized() if i > 0 else Vector3(0, 0, 1)
			n = (n - dir * n.dot(dir)).normalized()
			var w := dir.cross(n).normalized()
			# a flat band 3.5 cm wide, 6 mm thick, laid on the cloth
			var a := u * TAU
			return p + n * (0.012 + 0.003 * sin(a)) + w * 0.0175 * cos(a), 6, 16)
		var stm := _piece(strap, 0.0, 0.0, 30.0 + sx, 1.0)
		(stm.material_override as ShaderMaterial).set_shader_parameter("rigid", 1.0)
		(stm.material_override as ShaderMaterial).set_shader_parameter("weave_scale", 60.0)
		chest.add_child(stm)

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
	# toward the front the cape's lower edge sweeps up in one curve under the chin and flares
	# less, so the face opening closes in a rounded U instead of hanging two lappet points
	var w := pow(cos(a) * 0.5 + 0.5, 2.0)
	# over the shoulders the cape lies close and ends higher, a short collar on the mantle
	# instead of a long tongue hanging down the side; the back keeps its full flare
	var side := sin(a) * sin(a) * (1.0 - w)
	var r := dome * (1.0 + 0.45 * (1.0 - 0.55 * w - 0.4 * side) * smoothstep(0.7, 1.0, v))
	r *= 1.0 + 0.03 * sin(a * 7.0) * v
	# (up to 8.6 cm at the front, ~4 cm at the sides; the edge still falls with v everywhere,
	# so no fold-over)
	var lift := (0.086 * w + 0.03 * side) * pow(maxf(v - 0.6, 0.0) / 0.4, 1.6)
	var cz := -0.045 - 0.06 * pow(1.0 - v, 3.0)
	# the cowl is drawn forward round the face, so its rim stands proud of the brow and cheeks
	var fwd := 0.045 * pow(cos(a) * 0.5 + 0.5, 4.0) * smoothstep(0.03, 0.12, v) \
			* (1.0 - smoothstep(0.5, 0.78, v))
	# over the cheeks the cowl stands a little off the face cloth it now wraps further round
	var cheek := 0.012 * exp(-pow((absf(wrapf(a, -PI, PI)) - 0.6) / 0.3, 2.0)) \
			* smoothstep(0.3, 0.5, v) * (1.0 - smoothstep(0.8, 1.0, v))
	return Vector3(sin(a) * (0.168 * r + cheek), 2.09 - v * 0.43 + lift,
			cz + cos(a) * (0.192 * r + fwd + cheek))

## Half-angle of the face opening at `v`: an elliptic arch over the eyes, straight sides
## down the cheeks, then a gap round the face cloth closing at the throat -- narrower than the
## Hollow cowl's, so the hood wraps the cloth's sides instead of standing as a strip beside it.
func _hood_gap(v: float) -> float:
	var y := 2.09 - v * 0.43
	var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.34, 1.0), 2.0), 0.0, 1.0))
	var dy := maxf(y - HOOD_YC, 0.0) / HOOD_H
	var half := HOOD_W * sqrt(maxf(1.0 - dy * dy, 0.0)) * (1.0 + 0.05 * sin(v * 19.0 + 0.7))
	var arch := asin(clampf(half / (0.168 * maxf(dome, 0.05)), 0.0, 0.99))
	var low := 0.22 + 0.32 * smoothstep(0.12, 0.4, v) - 0.5 * smoothstep(0.72, 1.0, v)
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
			# the lower edge sags only a little under the chin, so it stays tucked behind the
			# hood's front edge (1.746) instead of hanging a point below it
			var y := 1.935 - v * (0.235 + 0.015 * maxf(front, 0.0) * front) - 0.01 * ridge * depth
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
