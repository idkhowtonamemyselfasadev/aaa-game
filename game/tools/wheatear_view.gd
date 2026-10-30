extends SceneTree
## Model check for the fold's wheatears: cock, hen and youngster perched, plus the cock in flight
## (rump flash), under a plain sun. Usage: godot res://tools/wheatear_view.gd -- out.png [yaw_deg]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "../shots/wheatear_view.png"
	var yaw := deg_to_rad(float(args[1])) if args.size() > 1 else 0.9
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.65)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.55)
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sun.light_energy = 3.0
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.3, 0.18)
	floor.material_override = fm
	root.add_child(floor)
	var maker := Birds.new()
	var mesh: ArrayMesh = maker._build_bird_mesh()
	maker.free()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wheatear.gdshader")
	var hens := [0.0, 1.0, 1.4, 0.0]
	var poses := [Vector4(0, 1, -0.1, 1), Vector4(0, 1, 0.5, 1), Vector4(0, 1, -0.1, 1), Vector4(0.6, 0, 0, 0)]
	for i in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		root.add_child(mi)
		var y := yaw if i < 3 else PI   # the flier seen from behind and above: the white rump
		mi.global_transform = Transform3D(Basis(Vector3.UP, y) * Basis(Vector3.RIGHT, 0.22 if i < 3 else 0.0) * Basis.from_scale(Wheatears.SHAPE * Wheatears.SCALE), Vector3(-0.27 + i * 0.18, 0.0 if i < 3 else 0.08, 0))
		mi.set_instance_shader_parameter("hen", hens[i])
		mi.set_instance_shader_parameter("pose", poses[i])
	var cam := Camera3D.new()
	cam.fov = 30
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.25, 0.75), Vector3(0, 0.06, 0))
	for i in 8:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("WHEATEAR view saved ", out)
	quit()
