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
	head.add_child(_piece(_hood(), 0.0, 0.03, 0.0, 1.2))
	veil = _piece(_veil(), 0.0, 0.0, 6.0, 0.5)
	head.add_child(veil)
	tint = STRAW
	hat = _piece(_hat(), 0.0, 0.0, 4.0, 1.0)
	var hm := hat.material_override as ShaderMaterial
	hm.set_shader_parameter("rigid", 1.0)
	hm.set_shader_parameter("weave_scale", 150.0)
	hm.set_shader_parameter("aspect", 0.35)
	head.add_child(hat)
	tint = MANTLE
	var mantle := _piece(_mantle(), 0.0, 0.06, 0.35, 1.0)
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
	return _grid(func(u: float, v: float) -> Vector3:
		var a := lerpf(-1.35, 1.35, u)
		var front := cos(a)
		# the lower edge sags into a soft point under the chin
		var y := 1.935 - v * (0.14 + 0.05 * front * front)
		var r := 1.0 + 0.06 * v * front + 0.015 * sin(a * 8.0 + v * 2.0) * v
		return Vector3(sin(a) * 0.128 * r, y, -0.035 + front * 0.175 * r), 24, 6)
