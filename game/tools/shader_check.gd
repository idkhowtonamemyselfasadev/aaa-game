## Compile check for a shader in ~3 s instead of a 40 min shot: xvfb-run -a .tools/godot --path game
## --rendering-driver vulkan -s res://tools/shader_check.gd 2>&1 | grep -A3 SHADER  (edit the path below)
extends SceneTree
var n := 0
func _init():
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rag.gdshader")
	mi.material_override = m
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	root.add_child(mi)
	root.add_child(cam)
func _process(_d):
	n += 1
	return n > 5
