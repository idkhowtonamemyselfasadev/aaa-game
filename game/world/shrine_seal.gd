class_name ShrineSeal
extends Node3D
## The sealed way down to the Shrine of Binding, in the floor of the watchtower keep: a round
## carved lid on a worn two-step plinth (the plinth stones come from Ruins). The lid's sigil
## -- eight binding cords knotted round a centre ring -- glows faintly ember in its grooves,
## breathing slowly, and wakes brighter as the hero comes near; standing at it names the
## place. It stays shut until the hero learns Bind (milestone 1 shrine).

const LID_R := 0.82
const WAKE_R := 7.0             # glow starts to rise inside this
const NAME_R := 2.6             # the caption shows inside this

var top_y := 0.0                # lid top (world y)
var glow := 0.0                 # 0..1, read by bots/shots
var _mat: ShaderMaterial
var _light: OmniLight3D
var _player: Node3D

func build(centre: Vector3, lid_top: float) -> void:
	top_y = lid_top
	global_position = Vector3(centre.x, lid_top - 0.08, centre.z)
	var cyl := CylinderMesh.new()
	cyl.top_radius = LID_R
	cyl.bottom_radius = LID_R + 0.02
	cyl.height = 0.16
	cyl.radial_segments = 96
	cyl.rings = 3
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/seal.gdshader")
	cyl.material = _mat
	var mi := MeshInstance3D.new()
	mi.name = "Lid"
	mi.mesh = cyl
	mi.rotation.y = 0.4
	add_child(mi)
	_light = OmniLight3D.new()
	_light.name = "EmberLight"
	_light.light_color = Color(1.0, 0.5, 0.22)
	_light.omni_range = 4.5
	_light.omni_attenuation = 2.2
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.1, 0)   # high and soft: warms the plinth and the hero, not a hotspot on the lid
	add_child(_light)
	_set_glow(0.0)

func _process(delta: float) -> void:
	if _player == null:
		_player = get_parent().get_parent().get_node_or_null("Player")   # World/Ruins/ShrineSeal
		if _player == null:
			return
	var d := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
	var want := 1.0 - smoothstep(1.2, WAKE_R, d)
	glow = move_toward(glow, want, delta * (0.6 if want > glow else 0.25))
	_set_glow(glow)
	var hud: Hud = _player.get_node_or_null("Hud")
	if hud and d < NAME_R:
		hud.caption("Shrine of Binding", "The seal is cold. Whatever sleeps below waits to be bound.")

func _set_glow(g: float) -> void:
	_mat.set_shader_parameter("wake", g)
	_light.light_energy = 0.015 + g * 0.16
