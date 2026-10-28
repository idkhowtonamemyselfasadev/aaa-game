class_name MothStreaks
extends MultiMeshInstance3D
## Motion smears for the lantern moths (moths.gd, hand_moths.gd): each flying moth trails a
## short warm streak of lit scales, as long as the way it covers in ~1/22 s, so a moth darting
## round the candle shows against the dusk at road distance instead of as a dim speck.

const SHUTTER := 0.045
const BRIGHT := [1.6, 2.6, 1.9]     # per kind: heart and dart, white ermine, yellow underwing

var _mat: ShaderMaterial
var _len: PackedFloat32Array   # bots: MultiMesh transforms read back as zero headless

func setup(count: int) -> void:
	name = "MothStreaks"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = count
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/moth_streak.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 8.0
	_len.resize(count)
	for i in count:
		hide_streak(i)

func set_lamp(pos: Vector3, lit: float) -> void:
	_mat.set_shader_parameter("lamp_pos", pos)
	_mat.set_shader_parameter("lamp_lit", lit)

## `fly` 0 settled .. 1 in flight; a moth crawling or at rest leaves no smear.
func set_streak(i: int, pos: Vector3, vel: Vector3, kind: int, half_span: float, fly := 1.0) -> void:
	# a dash at the glow or a burst after the walker: cap it so it still reads as a moth
	var tail := (-vel * SHUTTER * fly).limit_length(0.11)
	if tail.length() < half_span * 0.6:
		hide_streak(i)
		return
	var b := Basis(Vector3.RIGHT * 0.01, Vector3.UP * 0.01, tail)
	multimesh.set_instance_transform(i, Transform3D(b, pos))
	_len[i] = tail.length()
	multimesh.set_instance_custom_data(i, Color(BRIGHT[kind], 0.0, 0.0, half_span))

func hide_streak(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.DOWN * 500.0))
	_len[i] = 0.0

## Bots: streaks drawn now, and the longest (m).
func shown() -> Vector2:
	var n := 0
	var longest := 0.0
	for l in _len:
		if l > 0.0:
			n += 1
			longest = maxf(longest, l)
	return Vector2(n, longest)
