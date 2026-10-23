class_name HandLantern
extends Node3D
## A small iron hand lantern carried by its ring: the lantern post's lantern (same frame, horn
## panes, tallow stub and flame, built from LanternPost's meshes) scaled down to a carrying
## size. It hangs plumb from the hand whatever the arm does, and swings on its ring as a
## damped pendulum pushed by the hand's own motion, so its pool of light and the frame's
## shadows rock along the road with the walker's stride. `lit` (0..1) is set by the carrier.

const SCALE := 0.8          # of the post lantern
const LAMP := Color(1.0, 0.64, 0.36)   # candle through horn: 0.56/0.27 painted stones 3 m off a red-orange
const HORN_GAIN := 0.5      # the post's horn glow blew out to flat orange at knee height

var lit := 0.0
var want := 0.0             # the carrier's wish: the flame comes up / dies over ~1.5 s
var facing: Node3D          # the carrier's body (+z is the way he faces)
var pivot: Node3D           # the ring: plumb, swinging
var lamp: OmniLight3D
var fill: OmniLight3D       # the glow leaking up through the lid's vents onto the carrier's face
var face_fill := 0.0        # set by the carrier: 1 with the lantern held up at his chin
var fill_rest := Vector3.ZERO  # the glow's place over the vents, in the ring's space
var face_at := Vector3.INF  # set by the carrier: just before his face (world); the glow leans toward it
var max_sway := 0.0         # largest swing seen (bots)
var _horn: ShaderMaterial
var _flame: ShaderMaterial
var _tallow: ShaderMaterial
var _flame_mi: MeshInstance3D
var _sway := Vector2.ZERO   # (pitch, roll) rad
var _sway_v := Vector2.ZERO
var _prev := Vector3.ZERO
var _prev_v := Vector3.ZERO
var _primed := false
var _t := 0.0

func _ready() -> void:
	var src := LanternPost.new()          # only for its mesh builders; never enters the tree
	var body_mesh := src._lantern_mesh()
	var horn_mesh := src._horn_mesh()
	var candle_mesh := src._candle_mesh()
	src.free()
	pivot = Node3D.new()
	pivot.name = "Ring"
	pivot.top_level = true                # oriented in the world, not by the hand bone
	add_child(pivot)
	var sc := Node3D.new()
	sc.scale = Vector3.ONE * SCALE
	# the post lantern's S-hook and links are its carrying bail here: lift it so the hand
	# closes on the top link instead of the hook
	sc.position.y = 0.05
	pivot.add_child(sc)
	var iron := ShaderMaterial.new()
	iron.shader = preload("res://shaders/lantern.gdshader")
	iron.set_shader_parameter("seed", 5.9)
	var mi := MeshInstance3D.new()
	mi.name = "Lantern"
	mi.mesh = body_mesh
	mi.material_override = iron
	sc.add_child(mi)
	_horn = ShaderMaterial.new()
	_horn.shader = preload("res://shaders/lantern_horn.gdshader")
	var horn := MeshInstance3D.new()
	horn.name = "Horn"
	horn.mesh = horn_mesh
	horn.material_override = _horn
	horn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sc.add_child(horn)
	var base_y := -LanternPost.DROP - LanternPost.LH
	_tallow = ShaderMaterial.new()
	_tallow.shader = iron.shader
	_tallow.set_shader_parameter("part", 1.0)
	_tallow.set_shader_parameter("seed", 7.1)
	var candle := MeshInstance3D.new()
	candle.name = "Candle"
	candle.mesh = candle_mesh
	candle.material_override = _tallow
	candle.position = Vector3(0, base_y + 0.026, 0)
	sc.add_child(candle)
	var fp := Node3D.new()
	fp.name = "FlamePos"
	fp.position = Vector3(0, base_y + 0.026 + 0.085 + 0.024, 0)
	sc.add_child(fp)
	_flame = ShaderMaterial.new()
	_flame.shader = preload("res://shaders/flame.gdshader")
	_flame_mi = MeshInstance3D.new()
	_flame_mi.name = "Flame"
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.06)
	_flame_mi.mesh = q
	_flame_mi.material_override = _flame
	_flame_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fp.add_child(_flame_mi)
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = LAMP
	# a candle falls off fast: at 0.9 / 8 m the yard wall 2-4 m off took nearly the light his
	# coat did and its stones' near faces read as orange-red paint patches (lightdbg shot)
	lamp.omni_range = 6.0
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.03
	lamp.light_size = 0.03
	lamp.position = Vector3(0, 0.01, 0)
	fp.add_child(lamp)
	# the shadowed lamp leaves the face above the lid black (the lid and bail shade it, and
	# the hat brim the rest): a soft unshadowed warm glow just over the vents lights the chin,
	# cheeks and eyes from below the way a held-up lantern does
	fill = OmniLight3D.new()
	fill.name = "VentGlow"
	fill.light_color = LAMP.lerp(Color(1.0, 0.75, 0.5), 0.3)
	fill.omni_range = 1.7       # it leans in toward the face now (face_at): at 2.0 / 1.2 it washed his chest
	fill.omni_attenuation = 1.6
	fill.shadow_enabled = false
	fill.light_specular = 0.0     # 0.2 lit a bright specular band along the hat brim's front edge
	fill.position = Vector3(0, 0.28, 0)    # up nearer the face: from 0.16 it barely reached past the brim
	pivot.add_child(fill)
	fill_rest = fill.position
	_apply()

## Where the flame burns (world), for lenses and bots.
func flame_center() -> Vector3:
	return lamp.global_position

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	lit = move_toward(lit, want, delta / 1.5)
	var p := global_position
	if not _primed:
		_prev = p
		_prev_v = Vector3.ZERO
		_primed = true
	var v := (p - _prev) / delta
	var acc := (v - _prev_v) / delta
	_prev = p
	_prev_v = v
	if acc.length() > 60.0:
		acc = acc.normalized() * 60.0      # a teleport or a first frame: not a real shove
	# the ring is shoved opposite the hand's acceleration; facing the walker's way so pitch
	# is fore-aft and roll is side to side
	var fwd := facing.global_basis.z if facing != null else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var push := Vector2(-acc.dot(fwd), acc.dot(right)) * 0.09
	var k := 50.0                          # ~0.9 s period on its short ring
	var steps := maxi(1, ceili(delta * 60.0))
	var dt := delta / steps
	for i in steps:
		_sway_v += (push - _sway * k - _sway_v * 2.2) * dt
		_sway += _sway_v * dt
	_sway = _sway.clampf(-0.45, 0.45)
	max_sway = maxf(max_sway, _sway.length())
	var yaw := atan2(fwd.x, fwd.z)
	pivot.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(_sway.x, 0.0, _sway.y)), p)
	_apply()

func _apply() -> void:
	var fl := 0.82 + 0.1 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0) + 0.08 * sin(_t * 23.0 + 0.5)
	_flame.set_shader_parameter("lit", lit)
	_horn.set_shader_parameter("lit", lit * fl * HORN_GAIN)
	_tallow.set_shader_parameter("lit", lit * fl)
	lamp.light_energy = lit * 0.9 * fl
	lamp.visible = lit > 0.01 and is_visible_in_tree()
	fill.light_energy = lit * face_fill * (0.8 - 0.1 * face_fill) * fl   # a touch softer at full lean, right under the brim
	# the vents' glow spills up over the lid toward the face: from the lantern it fell off before
	# it reached under the brim, so lean it partway there as the lantern comes up
	var vent := pivot.global_transform * fill_rest
	if face_at.is_finite() and face_fill > 0.0:
		fill.global_position = vent.lerp(face_at, 0.5 * face_fill)
	else:
		fill.global_position = vent
	fill.visible = lamp.visible and face_fill > 0.01
	_flame_mi.visible = lit > 0.01
