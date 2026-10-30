class_name HeroGarb
extends HollowRags
## The hero's travelling garb over the old armour: an indigo wool hood under a wide woven
## straw hat, a dark shoulder mantle, long madder-dyed robe panels to the shins front and back,
## an ochre sash and undyed linen bindings on the legs and forearms. Built and animated like the
## Hollow rags (body space, hung on bones, panels pushed by the thighs, hems trailing motion),
## but clean dyed cloth: no ash, no burns, no ember.

const INDIGO := [Color(0.030, 0.034, 0.048), Color(0.15, 0.16, 0.21), 0.25]
## The hero's hood: indigo wool sun-faded and road-worn to a greyed slate blue (the fresh-dyed
## INDIGO read as a flat near-black box round the face at noon; the 0.25/0.26/0.30 slate then
## read as the brightest, bluest thing on him once the armour went dark).
const HOOD_INDIGO := [Color(0.040, 0.042, 0.050), Color(0.19, 0.195, 0.215), 0.3]
## The hero's face cloth: the same wool a shade darker and damper than the hood (breath, sweat
## and road dust): in the hood's value it read as a pale flat blue sheet under the face fill.
const VEIL := [Color(0.028, 0.029, 0.034), Color(0.14, 0.143, 0.158), 0.35]
const MANTLE := [Color(0.045, 0.036, 0.030), Color(0.24, 0.20, 0.16), 0.3]
const MADDER := [Color(0.085, 0.032, 0.022), Color(0.40, 0.17, 0.10), 0.35]
# a dyed-and-worn ochre: the bright 0.58/0.40/0.17 read as a flat yellow belt in full sun
const OCHRE := [Color(0.14, 0.088, 0.034), Color(0.48, 0.33, 0.15), 0.25]
const LINEN := [Color(0.17, 0.15, 0.12), Color(0.60, 0.55, 0.46), 0.3]
## The leg bindings: road-soiled linen on the shins, and a dark faded hemp over the thighs, so
## the legs read as worn cloth in full sun (clean linen lit from above read as a pale smear).
const SHIN_LINEN := [Color(0.10, 0.088, 0.07), Color(0.42, 0.37, 0.29), 0.45]
## The forearm bindings: the same road-soiled linen, a little cleaner than the shins (hands and
## sleeves rub them). Clean LINEN (light 0.60) read as two pale bright cuffs on the torso at noon.
const ARM_LINEN := [Color(0.11, 0.096, 0.077), Color(0.44, 0.39, 0.31), 0.4]
const HEMP := [Color(0.05, 0.045, 0.04), Color(0.26, 0.23, 0.19), 0.4]
# an old, weathered douli: the fresh-straw 0.66/0.53/0.31 read as a bright yellow cone at noon
const STRAW := [Color(0.15, 0.12, 0.072), Color(0.52, 0.43, 0.28), 0.15]

var hat: MeshInstance3D
var veil: MeshInstance3D
var face: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var fill: OmniLight3D
## A bearded wearer's tiny catch fill at eye level (see `_add_face`); null on the hero.
var eye_fill: OmniLight3D
## Per-piece colour overrides for another wearer (an NPC): keys hood, hat, mantle, robe, sash,
## wraps -> [dark, light, soot] like the constants below. Empty: the hero's own dyes.
var palette := {}
## Cut options for another wearer, set before build(): no straw hat (the hood alone), the robe
## panels' length as a factor of the hero's shin-length ones, and a wicker gathering basket
## worn on the back with deadwood standing out of it. The hero: hat, 1.0, no basket.
## robe_wide widens the panels; their hip wrap then curls them round the sides.
var hatless := false
var felt_hat := false            # a battered felt hat (tapered, front-pinched crown, soft snap brim) for the douli
var robe_len := 1.0
var robe_wide := 1.0     # panel width factor: wider panels curl round the hips into a skirt
var basket := false
var basket_node: Node3D
## A pedlar's load instead of deadwood: rolled bolts of dyed cloth laid across the mouth.
var basket_wares := false
## Side gores: a wedge of the robe cloth sewn in under each side of the panels, from the sash
## to the hem, so a long robe closes into a skirt and the side view shows no legs or armour.
var skirt := false
var gores: Array[MeshInstance3D] = []
## An old man's bare face instead of the face cloth: the face runs on down past a nose to the
## upper lip, and a grey beard and moustache (beard.gdshader on the face cloth's shape) cover
## the jaw and the throat down into the mantle's collar.
var beard := false
## A woman's bare face instead of the face cloth: the face runs on down past the nose as the
## bearded one does, and a pale linen wimple (the face cloth's shape, dropped under the nose)
## wraps the chin and the throat down into the mantle's collar.
var bare_face := false
var beard_col := Color(0.36, 0.35, 0.33)
## A bearded face's skin (an old man's: the age path greys it further in skin.gdshader).
var skin_col := Color(0.33, 0.27, 0.24)
## The face fill's strength against the hero's: a deep felt brim and a dark hood over an old
## face shade it far more than the hero's douli does (an NPC copies the hero's fill each frame).
var fill_gain := 1.0
## 0..1: how far the wraps' dark/light tones draw together (villagers: calm, even wool bands)
var wrap_calm := 0.0
## a darned kirtle, not a Hollow's rags: no moth holes or burnt edges in the panels and gores
## (their cut-outs showed the legs as pale grey patches ringed in soot)
var mended := false
## A smock of the robe cloth over the whole torso, from the collar under the mantle down under
## the sash, so another wearer (an NPC without armour) shows wool on the chest, never the
## Vanguard's plates under the mantle's hem and in its open front.
var smock := false
## The mantle in fulled wool (fuzz, pills, soft creases) rather than the hero's smooth cape.
var mantle_wool := false
## The hood in fine bleached linen (a woman's coif) rather than fulled wool: the wool's fuzz,
## pills and crease blotches read as a pale camouflage cowl on a light cloth.
var hood_linen := false
## Each elbow (left, right) in the mantle's mesh space, fed to its shader so the cape lifts
## over a raised arm.
var elbow_in_cape: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _cape: MeshInstance3D
var _elbows: Array[BoneAttachment3D] = []

## Eye centres (x, y) in garb space, the depth the eyeballs' fronts sit at, and their radius.
## The angle off plumb (rad) of the mantle's lines from the collar ring down to the hem at the
## sides; an elbow raised past it lifts the cloth (rag.gdshader's lift_over_arm, 0.5 there).
const CAPE_LINE := 0.5
const EYE_X := 0.031
const EYE_Y := 1.968
const EYE_R := 0.0125
## A wimple's height against the face cloth's: its top edge (1.929) comes down to 1.874.
## how far down its own length the wimple runs (1.0 = the face cloth's full drop)
const WIMPLE_HEM := 0.86
## A bearded face's lower edge (under the nose, behind the moustache).
const FACE_LOW_BEARD := 1.872
## A bare face (the women under their wimples) runs on down past the mouth to under the chin.
const FACE_LOW_BARE := 1.822
## Where the wimple's top edge passes under the chin at the front, and how far it rises at the
## sides of the jaw to frame the cheeks under the hood.
const WIMPLE_CHIN := 1.834
const WIMPLE_RISE := 0.1

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
				skel.find_bone("mixamorig_%sLeg" % side), skel.find_bone("mixamorig_%sFoot" % side)]))
	tint = palette.get("hood", HOOD_INDIGO)
	# the hero's hood is sewn, not torn like the Hollow's cowl: a straight turned and stitched
	# hem where it falls over the mantle
	var hood := _piece(_hood(), 0.0, 0.0, 0.0, 1.2)
	var hdm := hood.material_override as ShaderMaterial
	hdm.set_shader_parameter("wool", 0.3 if hood_linen else 1.0)
	hdm.set_shader_parameter("hem_band", 1.0)
	hdm.set_shader_parameter("fold_ao", 1.0)
	head.add_child(hood)
	if beard:
		veil = _beard()
		# a dark wool scarf wound under the beard (the face cloth's shape, a hair smaller), so
		# where the beard's ragged lower edge rises along the jaw it shows shadowed wool, never
		# the armour plate at the collar
		var scarf := _piece(_veil(), 0.0, 0.0, 6.0, 0.5)
		scarf.name = "Scarf"
		var sm := scarf.material_override as ShaderMaterial
		sm.set_shader_parameter("wool", 1.0)
		sm.set_shader_parameter("fold_ao", 1.0)
		scarf.transform = Transform3D(Basis.from_scale(Vector3(0.97, 1.0, 0.96)), Vector3(0.0, -0.012, -0.0014))
		head.add_child(scarf)
	else:
		tint = palette.get("veil", tint if palette.has("hood") else VEIL)
		veil = _piece(_veil(bare_face), 0.0, 0.0, 6.0, 0.5)
		var vm := veil.material_override as ShaderMaterial
		vm.set_shader_parameter("wool", 0.3 if hood_linen else 1.0)
		vm.set_shader_parameter("fold_ao", 1.0)
		if bare_face:
			# the wimple (shaped in _veil): it passes under the chin and rises up the sides of the
			# jaw into the hood, so mouth and chin show and the linen frames the face
			veil.name = "Wimple"
	head.add_child(veil)
	_add_face(head)
	if not hatless:
		tint = palette.get("hat", STRAW)
		hat = _piece(_felt() if felt_hat else _hat(), 0.0, 0.0, 4.0, 1.0)
		var hm := hat.material_override as ShaderMaterial
		hm.set_shader_parameter("rigid", 1.0)
		if felt_hat:
			hm.set_shader_parameter("wool", 1.0)
			hm.set_shader_parameter("felt", 1.0)
		else:
			hm.set_shader_parameter("weave_scale", 150.0)
			hm.set_shader_parameter("aspect", 0.35)
			hm.set_shader_parameter("straw", 1.0)
		# worn pushed back a little on the hood, so the eye line shows under the front brim even
		# with the idle stance's head bowed
		var crown := Vector3(0.0, 2.10, -0.03)
		# the felt hat sits down on the hood, tipped back a little (at -0.08 its front brim
		# hid the old man's eyes in shade at any range)
		var tip := -0.13 if felt_hat else -0.17
		var up := 0.0 if felt_hat else 0.02
		hat.transform = Transform3D(Basis(Vector3.RIGHT, tip), Vector3.ZERO).translated_local(-crown).translated(crown + Vector3.UP * up)
		head.add_child(hat)
	tint = palette.get("mantle", MANTLE)
	var mantle := _piece(_drape(), 0.0, 0.012, 0.35, 1.0)
	var mm := mantle.material_override as ShaderMaterial
	mm.set_shader_parameter("fold_ao", 1.0)
	mm.set_shader_parameter("hem_band", 1.0)
	mm.set_shader_parameter("tongues", 3.0)
	# below the shoulders the cape falls plumb, so a stoop or a lean no longer cocks its back
	# out behind like a stiff flap
	mm.set_shader_parameter("plumb", 1.0)
	if mantle_wool:
		mm.set_shader_parameter("wool", 1.0)
		# fulled wool has no grain down the hang: near-round fuzz, not wood-grain streaks
		mm.set_shader_parameter("fuzz_ratio", 0.9)
		mm.set_shader_parameter("weave_scale", 180.0)
		mm.set_shader_parameter("weathered", 1.0)
	# wider than the Hollow's so it covers the Vanguard's shoulder plates
	mantle.transform = Transform3D(Basis.from_scale(Vector3(1.16, 1.0, 1.12)), Vector3(0, 0.03, -0.005))
	chest.add_child(mantle)
	_cape = mantle
	# bone attachments, not the skeleton's poses: those are restored after the pose modifiers
	# run, so they would never show an arm the crumple raised
	for side in ["Left", "Right"]:
		var ea := BoneAttachment3D.new()
		ea.bone_name = "mixamorig_%sForeArm" % side
		skel.add_child(ea)
		_elbows.append(ea)
	tint = palette.get("robe", MADDER)
	if smock:
		var sk := _piece(_smock(), 0.0, 0.0, 12.0, 1.4)
		sk.name = "Smock"
		var skm := sk.material_override as ShaderMaterial
		skm.set_shader_parameter("wool", 1.0)
		skm.set_shader_parameter("fold_ao", 1.0)
		skm.set_shader_parameter("hem_band", 1.0)
		skm.set_shader_parameter("weathered", 0.6)
		# no flutter: it sits close over the plates
		skm.set_shader_parameter("rigid", 1.0)
		chest.add_child(sk)
	_front = _panel(hips, Vector3(0, 1.20, 0.215), 0.30 * robe_wide, lerpf(0.44, 0.52, robe_len - 1.0) * robe_wide, 0.90 * robe_len, 0.9, 1.0)
	_back = _panel(hips, Vector3(0, 1.21, -0.205), 0.34 * robe_wide, lerpf(0.48, 0.56, robe_len - 1.0) * robe_wide, 0.96 * robe_len, -0.9, 2.0)
	if skirt:
		for sx in [-1.0, 1.0]:
			var g := _piece(_gore(sx), 0.06, 0.14, 40.0 + sx, GORE_LEN * robe_len / 0.42)
			(g.material_override as ShaderMaterial).set_shader_parameter("fold_ao", 1.0)
			(g.material_override as ShaderMaterial).set_shader_parameter("gore", 1.0)
			hips.add_child(g)
			gores.append(g)
	tint = palette.get("sash", OCHRE)
	_knotted_sash(hips)
	for side in ["Left", "Right"]:
		tint = _calm(palette.get("wraps", SHIN_LINEN))
		_wrap("mixamorig_%sLeg" % side, "mixamorig_%sFoot" % side, 0.06, 0.93, 0.01, 8.0)
		_wrap("mixamorig_%sFoot" % side, "mixamorig_%sToeBase" % side, 0.0, 0.92, 0.008, 4.0)
		# villagers' forearms in their sleeve wool and a mitt over the hand: in the pale shin-wrap
		# grey the forearm wraps and the base body's gloves read as grey plate gauntlets
		tint = palette.get("sleeves", _calm(palette.get("wraps", ARM_LINEN)))
		# a villager's sleeve stands fuller off the arm: at the bandage's 8 mm the base body's
		# bracers and dark undersuit showed through in blotches (12 mm here + no wrap_inset on villagers)
		var sl := palette.has("sleeves")
		_wrap("mixamorig_%sForeArm" % side, "mixamorig_%sHand" % side, 0.22, 0.97, 0.012 if sl else 0.008, 6.0)
		if sl:
			_wrap("mixamorig_%sHand" % side, "mixamorig_%sHandMiddle1" % side, 0.0, 0.85, 0.014, 3.0)
		# under a long kirtle the thigh wraps take its wool: pale grey ones showed as plate
		# patches between the gores
		tint = palette.get("thighs", _calm(palette.get("wraps", HEMP)))
		_wrap("mixamorig_%sUpLeg" % side, "mixamorig_%sLeg" % side, 0.16, 0.97, 0.012, 9.0)
	if basket:
		_basket()
	if mended:
		for rm in mats:
			rm.set_shader_parameter("holes", 0.0)
			# and kept clean: the rust stains and grime streaks broke the kirtle's front panel
			# into dark and rust blocks below the sash
			rm.set_shader_parameter("stain_amt", 0.25)
			rm.set_shader_parameter("soot_amt", 0.35)
	tint = []
	_last_pos = body.global_position

## A wrap's dark and light tones drawn toward their mean by wrap_calm: the full spread mottled
## the villagers' shin and forearm wraps into pale-grey and black blotches like plate greaves.
func _calm(t: Array) -> Array:
	if wrap_calm <= 0.0:
		return t
	var mid: Color = (t[0] as Color).lerp(t[1], 0.5)
	return [(t[0] as Color).lerp(mid, wrap_calm), (t[1] as Color).lerp(mid, wrap_calm), t[2] * (1.0 - wrap_calm)]

func _physics_process(delta: float) -> void:
	super(delta)
	if _cape != null and _elbows.size() == 2:
		var mm := _cape.material_override as ShaderMaterial
		var inv := _cape.global_transform.affine_inverse()
		for i in 2:
			var e := inv * _elbows[i].global_position
			elbow_in_cape[i] = e
			mm.set_shader_parameter("arm_l" if i == 0 else "arm_r", Vector4(e.x, e.y, e.z, 1.0))

## How far (rad) the mantle's radial line at bearing `a` (mesh space, 0 = straight ahead) turns
## up over elbow `i` (0 left, 1 right): rag.gdshader's lift_over_arm, for the bots.
func cape_lift(i: int, a: float) -> float:
	var e := elbow_in_cape[i]
	var eo := Vector2(e.x, e.z + 0.045)
	var ae := atan2(eo.x, eo.y)
	var da := fposmod(a - ae + PI, TAU) - PI
	var wa := exp(-pow(da / 0.55, 2.0))
	var re := eo.length()
	var dv := Vector2(re - 0.1485, 1.72 - e.y)
	var th := atan2(dv.x, dv.y) + atan2(0.07, maxf(dv.length(), 0.1))
	return clampf(th - CAPE_LINE, 0.0, 1.6) * wa

## The elbow's bearing round the collar (mesh space, as cape_lift takes it) and the angle off
## plumb (rad) of the line from the collar ring to it.
func elbow_bearing(i: int) -> Vector2:
	var e := elbow_in_cape[i]
	var eo := Vector2(e.x, e.z + 0.045)
	var re := eo.length()
	return Vector2(atan2(eo.x, eo.y), atan2(re - 0.1485, 1.72 - e.y))
	for g in gores:
		var m := g.material_override as ShaderMaterial
		m.set_shader_parameter("gore_swing", Vector2(_swing_f, _swing_b))
		m.set_shader_parameter("gore_fold_f", fold_front)
		m.set_shader_parameter("gore_fold_f2", fold_front2)
		m.set_shader_parameter("gore_fold_b", fold_back)

## A gore's hem point at `u` (0 front end .. 1 back end) in world space, walked through the
## same swing and folds as rag.gdshader's gore pass (no flutter): for the bots.
func gore_hem(i: int, u: float) -> Vector3:
	var g: MeshInstance3D = gores[i]
	var sx := -1.0 if i == 0 else 1.0
	var a := lerpf(0.55, PI - 0.55, u)
	var drop := GORE_LEN * robe_len
	var wf := (1.0 - u) * (1.0 - u)
	var wb := u * u
	var p := Vector2.ZERO
	var st := drop / 14.0
	for j in 14:
		var d := (j + 0.5) * st
		var tf := _swing_f - fold_front.y * smoothstep(0.0, 0.07, d - fold_front.x) \
				- fold_front2.y * smoothstep(0.0, 0.07, d - fold_front2.x)
		var tb := -_swing_b - fold_back.y * smoothstep(0.0, 0.07, d - fold_back.x)
		var t := tf * wf + tb * wb
		p += st * Vector2(sin(t), -cos(t))
	return g.global_transform * Vector3(sx * sin(a) * 0.30, 1.21 + p.y, cos(a) * 0.34 + p.x)

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

## One crooked oak stick of deadwood from `base` along `lean`: two soft kinks, tapering to a
## snapped tip, in the current tint.
func _stick(base: Vector3, lean: Vector3, ln: float, r0: float, kink: float, k: int) -> MeshInstance3D:
	var stick := _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var off := Vector3(cos(kink), 0, sin(kink)) * 0.035 * sin(v * PI * 1.6) * ln
		var c := base + lean * v * ln + off
		var side := lean.cross(Vector3.FORWARD if absf(lean.z) < 0.9 else Vector3.UP).normalized()
		var up2 := side.cross(lean).normalized()
		var r := r0 * (1.0 - 0.45 * v) * (1.0 + 0.1 * sin(v * 23.0 + a * 2.0))
		return c + (side * cos(a) + up2 * sin(a)) * r, 7, 6)
	var sm := _piece(stick, 0.0, 0.0, 20.0 + k, 1.0)
	var sh := sm.material_override as ShaderMaterial
	sh.set_shader_parameter("rigid", 1.0)
	sh.set_shader_parameter("weave_scale", 12.0)
	sh.set_shader_parameter("aspect", ln / (r0 * TAU) * 0.15)
	return sm

## A short stick of deadwood she has just picked out of the litter, to hold in her hand
## (centred on the origin, lying along +X).
func held_stick() -> MeshInstance3D:
	tint = palette.get("deadwood", [Color(0.055, 0.045, 0.036), Color(0.36, 0.32, 0.27), 0.5])
	return _stick(Vector3(-0.15, 0, 0), Vector3.RIGHT, 0.30, 0.012, 1.3, 31)

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
	if basket_wares:
		_wares()
	# deadwood: crooked oak sticks standing in the mouth, leaning back and splaying
	tint = palette.get("deadwood", [Color(0.055, 0.045, 0.036), Color(0.36, 0.32, 0.27), 0.5])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for k in (0 if basket_wares else 9):
		var base := Vector3(rng.randf_range(-0.12, 0.12), BASKET_TOP - 0.25, BASKET_Z + rng.randf_range(-0.08, 0.06))
		var ln := rng.randf_range(0.42, 0.78)
		var lean := Vector3(base.x * 1.2 + rng.randf_range(-0.08, 0.08), 1.0, -0.22 + rng.randf_range(-0.1, 0.06)).normalized()
		basket_node.add_child(_stick(base, lean, ln, rng.randf_range(0.011, 0.02), rng.randf_range(0.0, TAU), k))
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

## A pedlar's wares in the basket mouth: four bolts of dyed wool rolled tight, lying across
## and stacked a little proud of the rim, each a lumpy roll whose wound layers show as a spiral
## ridge, tied round twice with cord.
func _wares() -> void:
	var dyes := [MADDER, INDIGO, OCHRE, LINEN]
	var at := [Vector3(0.0, BASKET_TOP + 0.01, BASKET_Z + 0.07), Vector3(0.01, BASKET_TOP + 0.02, BASKET_Z - 0.065),
			Vector3(-0.01, BASKET_TOP + 0.105, BASKET_Z + 0.005), Vector3(0.0, BASKET_TOP + 0.185, BASKET_Z - 0.01)]
	var lens := [0.44, 0.40, 0.46, 0.34]
	var rads := [0.062, 0.058, 0.066, 0.05]
	for k in 4:
		tint = dyes[k]
		var c: Vector3 = at[k]
		var ln: float = lens[k]
		var r0: float = rads[k]
		var tilt := 0.08 * (k % 2 * 2 - 1)
		var bolt := _grid(func(u: float, v: float) -> Vector3:
			var a := u * TAU
			var x := (v - 0.5) * ln
			# the roll: a spiral ridge of wound layers, fuller in the middle, the ends cut soft
			var end := clampf(minf(v, 1.0 - v) * 14.0, 0.0, 1.0)
			var r := r0 * (0.9 + 0.1 * end) * (1.0 + 0.035 * sin(a * 3.0 + v * 9.0) + 0.04 * fposmod(a / TAU + v * 2.0, 1.0))
			# the cord ties at a quarter in from each end pinch it
			r *= 1.0 - 0.09 * exp(-pow((absf(v - 0.5) - 0.27) * 40.0, 2.0))
			return c + Vector3(x, x * tilt + sin(a) * r, cos(a) * r), 28, 16)
		var bm := _piece(bolt, 0.0, 0.0, 40.0 + k, 1.0)
		var sh := bm.material_override as ShaderMaterial
		sh.set_shader_parameter("rigid", 1.0)
		sh.set_shader_parameter("weave_scale", 110.0)
		basket_node.add_child(bm)

## A pedlar's walking staff: an ash pole a little taller than its owner, crooked and thinning
## to the foot, lying along -Y from its grip at the origin (held at about chest height).
func walking_staff() -> MeshInstance3D:
	tint = palette.get("staff", [Color(0.06, 0.045, 0.03), Color(0.40, 0.33, 0.24), 0.45])
	return _stick(Vector3(0, 0.32, 0), Vector3.DOWN, 1.55, 0.019, 0.7, 37)

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
const HOOD_H_PEAK := 0.098  # a bearded wearer's peaked arch: its point a centimetre higher

func _hood() -> ArrayMesh:
	return _grid_ao(func(u: float, v: float) -> Vector3:
		var gap_l := _hood_gap(v, 1.0)
		var gap_r := _hood_gap(v, -1.0)
		if u > HOOD_ROLL and u < 1.0 - HOOD_ROLL:
			return _hood_at(lerpf(gap_l, TAU - gap_r, (u - HOOD_ROLL) / (1.0 - 2.0 * HOOD_ROLL)), v)
		var left := u <= HOOD_ROLL
		var ae := gap_l if left else TAU - gap_r
		var into := 1.0 if left else -1.0
		var phi := ((HOOD_ROLL - u) if left else (u - 1.0 + HOOD_ROLL)) / HOOD_ROLL * 1.45 * PI
		var p := _hood_at(ae, v)
		# the edge's tangent back into the hood and the outward normal off the cloth
		var t := (_hood_at(ae + into * 0.02, v) - p).normalized()
		var n := Vector3(p.x, 0.0, p.z + 0.06)
		n = (n - t * n.dot(t)).normalized()
		# the hem rolls out over the edge and lies back on the outside; thin at the arch's top,
		# where it runs into the crown seam, and a little uneven along its length
		var top_v := (2.09 - HOOD_YC - (HOOD_H_PEAK if beard else HOOD_H)) / 0.43
		var rr := 0.0105 * (1.0 + 0.25 * sin(v * 31.0 + 1.3) + 0.12 * sin(v * 77.0)) \
				* smoothstep(top_v - 0.02, top_v + 0.07, v)
		return p + n * rr * (1.0 - cos(phi)) - t * rr * sin(phi),
		func(u: float, v: float) -> float:
			return 1.0 - _hood_fold(_hood_angle(u, v), v) * 0.75, 64, 40)

## The angle round the head of hood grid point (u, v) (the rolls take their edge's angle).
func _hood_angle(u: float, v: float) -> float:
	var gap_l := _hood_gap(v, 1.0)
	var gap_r := _hood_gap(v, -1.0)
	if u <= HOOD_ROLL:
		return gap_l
	if u >= 1.0 - HOOD_ROLL:
		return TAU - gap_r
	return lerpf(gap_l, TAU - gap_r, (u - HOOD_ROLL) / (1.0 - 2.0 * HOOD_ROLL))

## The hero's hood drape at angle `a`, `v` down: a few uneven folds that start round the ears
## and deepen down into the shoulder flare (shallower toward the face opening), with tight
## rumples on the crown where the hat presses the wool down: the ridge signal, + out.
func _hood_fold_ridge(a: float, v: float) -> float:
	var w := pow(cos(a) * 0.5 + 0.5, 2.0)
	var phi := a * 6.0 + 0.9 * sin(a * 2.1 + 0.4) + 0.5 * sin(a * 4.7 + 1.9) + v * 1.2
	var ridge := sin(phi)
	ridge = signf(ridge) * pow(absf(ridge), 0.6)
	var depth := smoothstep(0.42, 0.95, v) * (1.0 - 0.7 * w)
	var crown := sin(a * 9.0 + v * 7.0 + 0.6) * exp(-pow((v - 0.3) / 0.08, 2.0)) * 0.35
	return ridge * depth + crown

## The fold cavity 0..1 at (a, v) (0 on a ridge or open cloth), for the hood's fold AO.
func _hood_fold(a: float, v: float) -> float:
	if beard:
		return 0.0
	var w := pow(cos(a) * 0.5 + 0.5, 2.0)
	var depth := smoothstep(0.42, 0.95, v) * (1.0 - 0.7 * w)
	var r := _hood_fold_ridge(a, v)
	# the valleys between the folds sit in shade; the crown rumples only a little
	return clampf(0.5 * depth * (1.0 - r) + 0.15 * maxf(-r, 0.0) * (1.0 - depth), 0.0, 1.0)

## _grid with a per-vertex cavity term in COLOR.r (1 open, 0 deep in a fold), for fold_ao.
func _grid_ao(f: Callable, g: Callable, nu: int, nv: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var c: float = g.call(u, v)
			st.set_color(Color(c, c, c))
			st.set_uv(Vector2(u, v))
			st.add_vertex(f.call(u, v))
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + nu + 1
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

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
	if beard:
		# an old shepherd's worn cowl is no stiff box round the face: it is drawn in under the
		# jaw so the head's outline rounds before the cloth spreads over the shoulders, the
		# crown slumps a little behind the brim, and the cloth falls in a few soft, uneven
		# drape folds instead of flat walls
		var sd := sin(a) * sin(a)
		r *= 1.0 - 0.09 * sd * exp(-pow((v - 0.62) / 0.13, 2.0))
		r *= 1.0 + 0.035 * sin(a * 5.0 + 1.3 + v * 3.0) * smoothstep(0.3, 0.9, v) \
				+ 0.018 * sin(a * 11.0 + 0.4) * smoothstep(0.5, 1.0, v)
		cz -= 0.025 * (1.0 - smoothstep(0.0, 0.3, v)) * (0.5 - 0.5 * cos(a))
	else:
		# the hero's sewn hood still hangs as wool, not a box: drawn in a little under the
		# jaw at the sides, then breaking into a few uneven drape folds over the shoulders
		var sd := sin(a) * sin(a)
		r *= 1.0 - 0.05 * sd * exp(-pow((v - 0.62) / 0.13, 2.0))
		r *= 1.0 + 0.045 * _hood_fold_ridge(a, v) * (0.6 + 0.4 * smoothstep(0.5, 1.0, v)) \
				* (1.0 - 0.75 * exp(-pow((v - 0.3) / 0.08, 2.0)))
	return Vector3(sin(a) * (0.168 * r + cheek), 2.09 - v * 0.43 + lift,
			cz + cos(a) * (0.192 * r + fwd + cheek))

## Half-angle of the face opening at `v`: an elliptic arch over the eyes, straight sides
## down the cheeks, then a gap round the face cloth closing at the throat -- narrower than the
## Hollow cowl's, so the hood wraps the cloth's sides instead of standing as a strip beside it.
func _hood_gap(v: float, s := 1.0) -> float:
	var y := 2.09 - v * 0.43
	var dome := sqrt(clampf(1.0 - pow(1.0 - minf(v / 0.34, 1.0), 2.0), 0.0, 1.0))
	var dy := maxf(y - HOOD_YC, 0.0) / HOOD_H
	var half := HOOD_W * sqrt(maxf(1.0 - dy * dy, 0.0)) * (1.0 + 0.05 * sin(v * 19.0 + 0.7))
	if beard:
		# an old cowl's opening is no round-topped frame: the cloth over the brow is pulled to a
		# soft peak where the hood's crown seam meets it, and the opening hangs a little askew,
		# one side (s = -1) sagging lower and wider than the other, the way a worn hood sits
		var yk := y + s * 0.006
		var dp := clampf(maxf(yk - HOOD_YC, 0.0) / HOOD_H_PEAK, 0.0, 1.0)
		half = HOOD_W * pow(1.0 - dp, 0.85) * pow(1.0 + dp, 0.35) * (1.0 + 0.05 * sin(v * 19.0 + 0.7))
		half *= 1.0 - 0.05 * s * smoothstep(1.97, 1.88, y)
		# the opening's sides follow the face in toward the chin instead of running straight
		# down the cheeks (a square frame read as a helmet), and its edge wavers a little more
		half *= (1.0 - 0.22 * smoothstep(1.95, 1.84, y)) * (1.0 + 0.04 * sin(v * 31.0 + 2.1))
	var arch := asin(clampf(half / (0.168 * maxf(dome, 0.05)), 0.0, 0.99))
	var low := 0.22 + 0.32 * smoothstep(0.12, 0.4, v) - 0.5 * smoothstep(0.72, 1.0, v)
	return lerpf(arch, low, smoothstep(0.42, 0.56, v))

## A conical woven straw hat (douli): a shallow cone from the crown point out to a wide brim
## that turns down a little at the rim, sitting low over the hood so the face is in its shade.
## UV.x runs round the hat, UV.y from the crown to the rim (the weave then reads as rings).
func _hat() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		# the cone runs to RIM_V; past it the brim's edge is bound in a rolled band of split
		# cane that turns down and back under (a bare cut edge read as a paper cone)
		var t := minf(v / HAT_RIM_V, 1.0)
		var r := 0.37 * t
		# a straight cone, a slightly fuller crown and a soft downturn over the last 15 %
		var y := 2.155 - 0.14 * t - 0.012 * sin(t * PI) - 0.03 * smoothstep(0.85, 1.0, t)
		# a small raised peak at the crown where the plaits are gathered and tied off
		y += 0.022 * pow(1.0 - minf(t / 0.13, 1.0), 2.0)
		# the bamboo frame's 16 spokes stand through the weave as faint ribs
		y += 0.0028 * pow(absf(cos(a * 8.0)), 10.0) * smoothstep(0.1, 0.3, t)
		# the plaited rim is a touch uneven
		var wob := 1.0 + 0.006 * sin(a * 11.0) * t
		r *= wob
		if v > HAT_RIM_V:
			var phi := (v - HAT_RIM_V) / (1.0 - HAT_RIM_V) * 1.25 * PI
			var rr := 0.0065 * (1.0 + 0.15 * sin(a * 23.0))
			# round the edge from the top surface, down past its outer face and back underneath
			r += rr * sin(phi)
			y += rr * (cos(phi) - 1.0)
		return Vector3(sin(a) * r, y, -0.03 + cos(a) * r), 48, 18)

const HAT_RIM_V := 0.84

## An old man's felt hat worn over the hood: a round crown with a crease pinched down its
## top front to back, walls a little out of true, and a narrow soft brim that droops at the
## front and back and has gone wavy with the weather. UV.y runs from the crown's middle down
## the wall and out to the brim's edge.
func _felt() -> ArrayMesh:
	return _grid(func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var ca := cos(a)
		var sa := sin(a)
		# the band sits low round the hood's widest part (about 2.0 m, where the hood is
		# ~0.155 x 0.177 m round its centre, z -0.045), so the crown stands only ~0.13 m
		# above it instead of riding high like a stovepipe
		var rx := 0.172
		var rz := 0.198
		var y := 0.0
		var k := 0.0
		# a front pinch: two thumb dents either side of the front of the crown (where a hand
		# takes the hat off), deepest up at the shoulder and gone by the band
		var off := absf(atan2(sa, ca))
		var pinch := exp(-pow((off - 0.6) / 0.3, 2.0))
		# battered: the crown has slumped a little toward the left rear
		var slump := 0.007 * sin(a + 2.2)
		if v < 0.3:
			# the top: a low dome from the middle out to the crown's rounded shoulder, the
			# crease pinched down along the middle line (its floor still 1 cm over the hood; the
			# crown sat 1 cm higher until 10-23 and stood up off his head like a stovepipe)
			var t := v / 0.3
			k = 0.80 * sin(t * PI * 0.5)
			y = 2.12 - 0.026 * t * t - 0.02 * exp(-pow(sa * k / 0.3, 2.0)) * (1.0 - t * t * 0.8)
			y += slump * t - 0.014 * pinch * t * t
			k *= 1.0 - 0.10 * pinch * t * t
		elif v < 0.62:
			# the wall: down from the shoulder to the band, tapering in hard toward the top with
			# a soft belly through the middle, so it reads as a worn felt crown, not a bucket
			var t := (v - 0.3) / 0.32
			k = lerpf(0.80, 1.0, t) + 0.03 * sin(t * PI)
			y = lerpf(2.094 + slump - 0.014 * pinch, 1.995, t)
			k *= 1.0 - 0.10 * pinch * (1.0 - t) * (1.0 - t)
		else:
			# the brim: out ~6 cm and gone soft, snapped down at the front and back and flatter
			# at the sides (a higher side brim would curl up like a cowboy's), the front left
			# dragged lower than the right where it is always pulled on, wavy at the edge
			var t := (v - 0.62) / 0.38
			k = 1.0 + t * (0.055 + 0.01 * ca * ca) / 0.185
			var droop := 0.032 + 0.016 * ca * ca + 0.004 * sa * sa + 0.006 * maxf(ca, 0.0) * maxf(sa, 0.0)
			droop += 0.006 * sin(a * 5.0 + 0.7) + 0.003 * sin(a * 9.0 + 2.1)
			y = 1.995 - 0.008 * t - droop * t * t
		return Vector3(sa * rx * k, y, -0.045 + ca * rz * k), 48, 16)

## A face cloth of the same indigo wool wound across the face from the bridge of the nose to
## under the chin, hanging a little slack at the front; with the hat's shade only the eye line
## shows between it and the hood.
## `wimple` (bare-faced women): cut off at WIMPLE_HEM down the cloth and with its folds eased out
## toward the hem, so its lower edge is a smooth line tucked under the collar instead of a pale
## ragged lip on the chest, and with no ride-up over the nose (the face shows there, not cloth).
func _veil(wimple := false) -> ArrayMesh:
	var nu := 56
	var nv := 26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv * (WIMPLE_HEM if wimple else 1.0)
			# wound round past the ears and down over the throat, its lower edge tucked inside
			# the mantle's collar (1.72) all the way round, so no pale armour neck shows between
			# the cloth and the cape
			var a := lerpf(-1.65, 1.65, u)
			var front := cos(a)
			# soft folds hang from the nose bridge, deepening toward the chin and splitting a
			# little where the cloth bunches at the sides under the hood (a 6 mm relief read as
			# a flat sheet: the ridges stand ~1.5 cm out now, the valleys sink half that so
			# they never cut into the jaw)
			var phi := a * 7.0 + 0.8 * sin(a * 2.7 + 0.4) + 0.4 * sin(a * 6.3 + 1.1)
			var ridge := sin(phi)
			ridge = signf(ridge) * pow(absf(ridge), 0.7)
			var rr := ridge if ridge > 0.0 else ridge * 0.5
			var fine := sin(a * 17.0 + 0.6 + v * 3.0) * smoothstep(0.4, 1.0, v)
			var depth := smoothstep(0.1, 1.0, v)
			if wimple:
				depth *= 1.0 - 0.7 * smoothstep(0.5, WIMPLE_HEM, v)
			# it is wound twice: the outer turn's upper edge crosses the face on a slant (high
			# under the left cheek, low at the right jaw) and stands a layer proud, with a
			# shadowed crease just above it where the cloth beneath bunches
			var edge := 0.46 + 0.16 * sin(a * 0.9 + 0.3)
			var outer := smoothstep(edge - 0.035, edge + 0.01, v)
			var crease := exp(-pow((v - edge + 0.03) / 0.035, 2.0))
			# the cloth is pulled from the nose bridge back toward the ears: shallow creases
			# run back across the cheeks, slanting down toward the nape
			var pull := sin(v * PI * 6.0 + absf(a) * 2.2) * smoothstep(0.35, 1.1, absf(a)) * (1.0 - 0.6 * depth)
			# the lower edge sags only a little under the chin, so it stays tucked behind the
			# hood's front edge (1.746) instead of hanging a point below it
			var y := 1.929 - v * (0.229 + 0.015 * maxf(front, 0.0) * front) - 0.022 * rr * depth
			# the top edge rides up over the bridge of the nose and sags into a soft dip under
			# each cheekbone before running back flat under the hood, instead of a ruled line
			var top := 1.0 - smoothstep(0.0, 0.35, v)
			if wimple:
				# under the chin at the front, rising up the jaw at the sides; its hem stays in the
				# collar (1.72) where the face cloth's would have hung out over the chest
				var y0 := WIMPLE_CHIN + WIMPLE_RISE * smoothstep(0.9, 0.55, front)
				# (at the front the hem rises behind the hood's front point (1.746): hung to 1.716
				# there, it showed as a pale ragged scrap between the hood and the smock)
				var hem := lerpf(1.716, 1.738, smoothstep(0.3, 0.9, front))
				y = lerpf(y0, hem, v / WIMPLE_HEM) - 0.022 * rr * depth
			y += top * ((0.0 if wimple else 0.004) * pow(maxf(front, 0.0), 14.0) \
					- 0.008 * exp(-pow((absf(a) - 0.5) / 0.22, 2.0)) \
					+ 0.002 * sin(a * 5.0 + 0.9))
			var r := 1.0 + 0.06 * v * front + depth * (0.085 * rr + 0.016 * fine) \
					+ 0.04 * outer - 0.012 * crease + 0.012 * pull
			var cav := mix_cav(ridge, fine, depth)
			cav *= (1.0 - 0.55 * crease) * (1.0 - 0.18 * maxf(-pull, 0.0))
			st.set_color(Color(cav, cav, cav))
			st.set_uv(Vector2(u, v))
			# (the wimple sits closer round the jaw and throat than the face cloth over the nose)
			# (its top flares out at the sides of the jaw to meet the hood, closing the dark
			# gap that showed between the cheek and the hood's inner edge)
			var wx := (0.112 + 0.01 * (1.0 - smoothstep(0.0, 0.3, v)) * (1.0 - maxf(front, 0.0))) if wimple else 0.128
			var wz := 0.165 if wimple else 0.175
			st.add_vertex(Vector3(sin(a) * wx * r, y, -0.035 + front * wz * r))
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

## The beard: the face cloth's shape, a little fuller, drawn as coarse grey hair; its top edge
## is cut by beard.gdshader into a moustache line under the nose rising to the cheekbones.
func _beard() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/beard.gdshader")
	mat.set_shader_parameter("hair_col", beard_col)
	var mi := MeshInstance3D.new()
	mi.name = "Beard"
	mi.mesh = _veil()
	mi.material_override = mat
	mi.layers = layer
	# run on down 2.5 cm past the face cloth's tuck (stretched from the moustache line, so it
	# stays put under the nose): its lower edge sits deep in the mantle's collar and no armour
	# plate shows in a gap under the jaw
	var top := 1.893
	mi.transform = Transform3D(Basis.from_scale(Vector3(1.05, 1.13, 1.07)), Vector3(0.0, top - top * 1.13, 0.0))
	return mi

## The face in the gap between the hood and the face cloth: a band of sun-browned skin from
## the brow to the bridge of the nose, with the brow ridge, the nose bridge and two shallow eye
## sockets shaped in, almond lid openings cut by skin.gdshader, and two wet eyeballs behind
## them. The band's sides tuck back under the hood and its lower edge under the face cloth.
func _add_face(head: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/skin.gdshader")
	mat.set_shader_parameter("eyes", Vector4(-EYE_X, EYE_Y, EYE_X, EYE_Y))
	if beard or bare_face:
		# the nose and upper lip show; only the strip under the moustache tucks into shade
		mat.set_shader_parameter("low_tuck", 0.93 if bare_face else 0.88)
		if bare_face:
			mat.set_shader_parameter("mouth_y", 1.869)
		# an old man's face: paler and greyer than the hero's sun-brown, which read as a flat
		# orange mask under the warm face fill
		mat.set_shader_parameter("age", 1.0 if beard else 0.0)
		mat.set_shader_parameter("skin_col", skin_col)
		mat.set_shader_parameter("lid_col", Color(0.26, 0.19, 0.16))
		# a little more open: the 7 mm slit vanished under the brow at a few metres
		mat.set_shader_parameter("eye_size", Vector2(0.0135, 0.0044))
	face = MeshInstance3D.new()
	face.name = "Face"
	face.mesh = _grid(_face_point, 40, 34 if bare_face else (24 if beard else 14))
	face.material_override = mat
	face.layers = layer
	head.add_child(face)
	var emat := ShaderMaterial.new()
	emat.shader = preload("res://shaders/eye.gdshader")
	if beard or bare_face:
		# deep in the felt brim's shade the grey-buff white went to the skin's value and the
		# eye vanished: a cleaner white keeps it reading as an eye at a few metres
		emat.set_shader_parameter("sclera_gain", 1.27)
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
	if beard or bare_face:
		# the brow and the brim keep the broad fill off the sockets: a tiny light a hand in
		# front of the eyes, out of reach of the beard and the hood, lifts only the eye line
		# (its energy follows the fill's, see villager.gd)
		eye_fill = OmniLight3D.new()
		eye_fill.name = "EyeFill"
		eye_fill.light_color = fill.light_color
		eye_fill.light_energy = 0.0
		eye_fill.omni_range = 0.16
		eye_fill.omni_attenuation = 1.0
		eye_fill.shadow_enabled = false
		eye_fill.light_cull_mask = layer
		eye_fill.light_specular = 0.08
		eye_fill.position = Vector3(0.0, EYE_Y - 0.004, _face_point_xy(0.0, EYE_Y, false).z + 0.11)
		head.add_child(eye_fill)

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
	var low := FACE_LOW_BARE if bare_face else (FACE_LOW_BEARD if beard else 1.914)
	var y := lerpf(2.016, low, v)
	return _face_point_xy(sin(a) * _jaw_w(y), y, true)

## Half-width of the face at height y: 9 cm across the cheekbones, narrowing down a bare face's
## jaw to the chin (to 6.7 cm the face read long and narrow, a horse's face in the hood).
func _jaw_w(y: float) -> float:
	if not bare_face:
		return 0.09
	return 0.09 * lerpf(1.0, 0.8, smoothstep(1.89, 1.83, y))

## The face surface at (x, y): a rounded front (0.19 m deep, 0.09 m wide) with the brow ridge,
## the nose bridge, the sockets and the cheekbones; `sockets` false gives the surface the
## eyeballs sit under (no socket dip).
func _face_point_xy(x: float, y: float, sockets: bool) -> Vector3:
	var jw := _jaw_w(y)
	var s := clampf(x / jw, -1.0, 1.0)
	var a := asin(s)
	var z := -0.035 + cos(a) * 0.19
	# brow ridge over the eyes, the bridge of the nose running down the middle
	z += 0.006 * exp(-pow((y - 1.992) / 0.008, 2.0)) * (1.0 - smoothstep(0.05, 0.075, absf(x)))
	if beard or bare_face:
		# a whole nose: the bridge narrow between the eyes, widening and standing out to a
		# rounded tip over the moustache, with the nostril wings either side of it; under it
		# the lip runs back behind the moustache
		var t := clampf((1.985 - y) / 0.08, 0.0, 1.0)
		var w := 0.0065 + 0.008 * t
		var under := smoothstep(1.889, 1.903, y)
		z += (0.004 + 0.019 * pow(t, 1.4)) * exp(-pow(x / w, 2.0)) * under
		z += 0.007 * exp(-pow((absf(x) - 0.0135) / 0.006, 2.0) - pow((y - 1.904) / 0.007, 2.0))
		if beard:
			z -= 0.03 * smoothstep(1.899, 1.880, y)
		else:
			# a bare face: the upper lip under the nose, the mouth, a fuller lower lip, the groove
			# under it and a rounded chin, the jaw receding a little below the cheekbones; under the
			# chin it tucks back into the wimple
			var mx := exp(-pow(x / 0.024, 2.0))
			z -= 0.008 * smoothstep(1.90, 1.845, y)
			z += 0.003 * exp(-pow((y - 1.877) / 0.005, 2.0)) * mx
			z -= 0.003 * exp(-pow((y - 1.869) / 0.0018, 2.0)) * mx
			z += 0.004 * exp(-pow((y - 1.862) / 0.0045, 2.0)) * mx
			z -= 0.003 * exp(-pow((y - 1.851) / 0.004, 2.0)) * exp(-pow(x / 0.02, 2.0))
			z += 0.005 * exp(-pow((y - 1.840) / 0.007, 2.0)) * exp(-pow(x / 0.022, 2.0))
			z -= 0.04 * smoothstep(1.836, 1.822, y)
			# the flesh of the cheeks, full below the cheekbones and either side of the mouth,
			# and the soft fold from the nostril wing down past the mouth corner: without them
			# the sides fell away flat from the nose and the face read as a carved mask
			z += 0.006 * exp(-pow((absf(x) - 0.04) / 0.02, 2.0) - pow((y - 1.912) / 0.024, 2.0))
			var fold_x := lerpf(0.019, 0.029, clampf((1.900 - y) / 0.036, 0.0, 1.0))
			z -= 0.0018 * exp(-pow((absf(x) - fold_x) / 0.0035, 2.0)) * smoothstep(1.904, 1.895, y) \
					* smoothstep(1.858, 1.868, y)
	else:
		z += 0.007 * exp(-pow(x / 0.009, 2.0)) * smoothstep(1.995, 1.95, y)
	if sockets:
		for c in [-EYE_X, EYE_X]:
			var d := pow((x - c) / 0.019, 2.0) + pow((y - EYE_Y) / 0.011, 2.0)
			z -= 0.004 * exp(-d)
	# cheekbones forward under the outer eye corners, then the lower edge tucks back under the
	# face cloth and the sides under the hood
	z += 0.003 * exp(-pow((absf(x) - 0.045) / 0.015, 2.0)) * smoothstep(1.965, 1.945, y)
	if not beard and not bare_face:
		z -= 0.02 * smoothstep(1.932, 1.914, y)
	# (a bare face rounds off over its whole width: the steep fall in the outer third read as a
	# flat front with sides cut square, a mask's edge)
	if bare_face:
		z -= 0.03 * pow(smoothstep(jw * 0.3, jw, absf(x)), 1.3)
	else:
		z -= 0.03 * smoothstep(jw * 0.67, jw, absf(x))
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
			# out over the shoulders in the top 60 %, then falling near plumb down the upper arms
			# (a cone out to 0.38 at the hem stood off the arms like a stiff lampshade, its side a
			# pointed flap in the `osricclose` shot)
			var k := 1.0 - pow(1.0 - minf(v / 0.6, 1.0), 2.0)
			var drop := smoothstep(0.6, 1.0, v)
			var rx := lerpf(0.135, 0.31, k) + 0.02 * drop
			var rz := lerpf(0.135, 0.29, k) + 0.025 * drop
			# fold phase: ~8 folds round the cape, unevenly spaced, a few splitting near the hem
			var phi := a * 8.0 + 0.9 * sin(a * 2.3 + 0.7) + 0.5 * sin(a * 5.1 + 2.0)
			var ridge := sin(phi)
			ridge = signf(ridge) * pow(absf(ridge), 0.65)
			var fine := sin(a * 19.0 + 1.3 + v * 2.0) * smoothstep(0.5, 1.0, v)
			# deep enough to throw real shade at a few metres: at 0.085 / from 5 % down the cape
			# read as one smooth sheet in the gallery shots
			var depth := smoothstep(0.02, 0.8, v)
			var fold := 1.0 + depth * (0.12 * ridge + 0.03 * fine)
			# the hem hangs lower at the back; ridges carry it a little lower than the valleys
			# the sides, hanging down the arms, a little lower than a straight front-to-back slope,
			# so the side silhouette ends round instead of on a diagonal point
			var hem := lerpf(1.44, 1.29, (1.0 - cos(a)) * 0.5) - 0.035 * sin(a) * sin(a) - 0.03 * ridge - 0.01 * fine
			# a slight roll at the collar where the cloth gathers round the neck
			var collar := 1.0 + 0.10 * (1.0 - smoothstep(0.0, 0.12, v))
			var y := lerpf(1.72, hem, v)
			var cav := pow(mix_cav(ridge, fine, depth), 1.5)
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

## The smock: a closed wool tube round the torso (garb space), gathered at the collar inside
## the mantle (1.70), full over the chest (the Vanguard's plates reach |x| 0.233 and z +0.156 /
## -0.229 there) and falling straight to under the sash (1.21), with soft vertical folds and a
## little blousing over the girdle. A squarish super-ellipse so the plates' corners stay inside.
func _smock() -> ArrayMesh:
	var nu := 72
	var nv := 22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var a := u * TAU
			var y := lerpf(1.70, 1.21, v)
			# full by 1.56: filling out only by 1.50 left the Vanguard's upper chest plate cutting
			# through the cloth at ~1.63 as a pale crescent under the hood
			var full := smoothstep(1.70, 1.56, y)
			var rx := lerpf(0.135, 0.258, full)
			var ca0 := cos(a)
			var rz := lerpf(0.13, 0.222, full) + 0.024 * exp(-pow((y - 1.60) / 0.08, 2.0)) * maxf(ca0, 0.0)
			var zc := lerpf(-0.035, -0.008, smoothstep(1.42, 1.22, y))
			# blousing over the girdle, then drawn in under it
			var blouse := 1.0 + 0.035 * exp(-pow((y - 1.30) / 0.05, 2.0)) - 0.03 * smoothstep(1.26, 1.21, y)
			var phi := a * 7.0 + 0.8 * sin(a * 2.7 + 1.1) + 0.4 * sin(a * 4.3 + v * 3.0)
			var ridge := sin(phi)
			var fine := sin(a * 17.0 + 0.6 + v * 4.0) * 0.5
			var depth := smoothstep(0.1, 0.6, v)
			var fold := 1.0 + depth * (0.022 * ridge + 0.007 * fine)
			var ca := cos(a)
			var sa := sin(a)
			# super-ellipse (exponent 2.6): squarer than an ellipse at the diagonals
			var e := 2.0 / 2.6
			var sx := signf(sa) * pow(absf(sa), e)
			var sz := signf(ca) * pow(absf(ca), e)
			var cav := mix_cav(ridge, fine, depth)
			st.set_color(Color(cav, cav, cav))
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(sx * rx * fold * blouse, y, zc + sz * rz * fold * blouse))
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


## The sash as tied cloth, not a smooth ring: a band wound twice round the waist (the outer
## turn's edge crossing it on a slant, bunched into creases across the band), a lumpy knot at
## the left hip and two tails hanging from it that flutter like the robe's hems.
## COLOR.r is the crease cavity (fold_ao).
const SASH_KNOT_A := -0.95
func _knotted_sash(hips: Node3D) -> void:
	var band := _piece(_cgrid(_sash_band, 56, 8), 0.0, 0.0, 0.0, 0.25)
	var bm := band.material_override as ShaderMaterial
	bm.set_shader_parameter("rigid", 1.0)
	bm.set_shader_parameter("fold_ao", 1.0)
	band.name = "Sash"
	hips.add_child(band)
	var knot := _piece(_cgrid(_sash_knot, 16, 10), 0.0, 0.0, 1.0, 1.0)
	var km := knot.material_override as ShaderMaterial
	km.set_shader_parameter("rigid", 1.0)
	km.set_shader_parameter("fold_ao", 1.0)
	knot.name = "SashKnot"
	hips.add_child(knot)
	for t in [[0.0, 0.34, 0.075], [1.0, 0.27, 0.065]]:
		var tail := _piece(_cgrid(_sash_tail.bind(t[0], t[1], t[2]), 6, 14), 0.0, 0.06, 2.0 + t[0], t[1] / t[2])
		var tm := tail.material_override as ShaderMaterial
		tm.set_shader_parameter("fold_ao", 1.0)
		tm.set_shader_parameter("hem_band", 1.0)
		tail.name = "SashTail"
		hips.add_child(tail)

## A grid whose callable returns [position, cavity]; the cavity goes to COLOR.
func _cgrid(f: Callable, nu: int, nv: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var r: Array = f.call(u, v)
			var c: float = r[1]
			st.set_color(Color(c, c, c))
			st.set_uv(Vector2(u, v))
			st.add_vertex(r[0])
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + nu + 1)
			st.add_index(a + 1); st.add_index(a + nu + 2); st.add_index(a + nu + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

func _sash_ring(a: float, y: float, out: float) -> Vector3:
	return Vector3(sin(a) * (0.258 + out), y + 0.03 * sin(a), 0.005 + cos(a) * (0.222 + out))

func _sash_band(u: float, v: float) -> Array:
	var a := u * TAU
	# the outer turn's lower edge runs on a slant round the waist; above it the cloth stands
	# one layer (7 mm) proud, with a soft rolled lip where it ends
	var edge := 0.42 + 0.22 * sin(a * 0.5 + 0.6)
	var lip := smoothstep(edge - 0.08, edge + 0.02, 1.0 - v)
	var roll := 0.004 * exp(-pow((1.0 - v - edge) / 0.05, 2.0))
	# creases across the band where the cloth bunches as it is pulled tight, uneven in pitch,
	# fanning out from the knot
	var phi := a * 11.0 + 1.4 * sin(a * 2.7 + 0.4) + 0.8 * sin(a * 6.3)
	var crease := sin(phi + (v - 0.5) * 1.6 * cos(a - SASH_KNOT_A))
	crease = signf(crease) * pow(absf(crease), 0.6)
	var near_knot := exp(-pow(wrapf(a - SASH_KNOT_A, -PI, PI) / 0.9, 2.0))
	var depth := 0.0035 + 0.004 * near_knot
	# the band bellies between its edges and tucks in at top and bottom
	var belly := 0.008 * sin(v * PI)
	var out := 0.007 * lip + roll + belly + depth * crease
	var cav := clampf(0.62 + 0.38 * crease, 0.0, 1.0) * lerpf(0.75, 1.0, sin(v * PI)) * lerpf(0.8, 1.0, lip)
	return [_sash_ring(a, 1.245 - v * 0.15, out), cav]

func _knot_centre() -> Vector3:
	return _sash_ring(SASH_KNOT_A, 1.165, 0.03)

func _sash_outward() -> Vector3:
	return Vector3(sin(SASH_KNOT_A) / 0.258, 0.0, cos(SASH_KNOT_A) / 0.222).normalized()

func _sash_knot(u: float, v: float) -> Array:
	# a squashed, lumpy ball pulled tight: wider across the band than tall, flattened against
	# the body, with the turns of the knot as lobes round it
	var th := u * TAU
	var ph := v * PI
	var n := _sash_outward()
	var t := Vector3.UP.cross(n).normalized()
	var lobe := 1.0 + 0.18 * sin(th * 3.0 + 0.5) * sin(ph) + 0.1 * sin(th * 5.0 + ph * 2.0)
	var dir := t * cos(th) * sin(ph) * 0.05 + Vector3.UP * cos(ph) * 0.036 + n * sin(th) * sin(ph) * 0.032
	var p := _knot_centre() + dir * lobe
	# its back half sits into the band, never behind the waist
	if sin(th) < 0.0:
		p -= n * sin(th) * sin(ph) * 0.012
	var cav := clampf(0.55 + 0.45 * (lobe - 0.85) / 0.35, 0.3, 1.0)
	return [p, cav]

func _sash_tail(u: float, v: float, side: float, ln: float, w: float) -> Array:
	# a ribbon of the same cloth from under the knot, hanging down the hip and turning a little
	# as it falls; the two splay apart and the shorter one lies in front
	var n := _sash_outward()
	var t := Vector3.UP.cross(n).normalized()
	var splay := lerpf(-0.35, 0.3, side)
	var twist := (0.5 + 0.4 * side) * v
	var across := (t * cos(twist) + n * sin(twist)) * (u - 0.5) * w * lerpf(1.0, 0.85, v)
	var down := Vector3.DOWN * v * ln + t * sin(splay) * v * ln * 0.45
	# falls clear of the robe: out off the hip, the front tail a hair further out
	var off := n * (0.012 + 0.012 * side + 0.035 * v * (1.0 - v) + 0.01 * v)
	var wave := n * 0.008 * sin(v * 7.0 + side * 2.0) * v
	var p := _knot_centre() + Vector3.DOWN * 0.02 + down + across + off + wave
	var cav := lerpf(0.7, 1.0, 1.0 - absf(u - 0.5) * 1.2) * lerpf(0.75, 1.0, smoothstep(0.0, 0.15, v))
	return [p, cav]
