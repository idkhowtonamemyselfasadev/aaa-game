extends SceneTree
## Model check for the procedural red deer: four poses (stand, walk, graze, gallop) side by
## side under a plain sun. Usage: godot res://tools/deer_view.gd -- out.png [yaw_deg] [stag] [near]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "../shots/deer_view.png"
	var yaw := deg_to_rad(float(args[1])) if args.size() > 1 else PI * 0.5
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
	sun.light_energy = 2.5
	if "rake" in args:   # low raking light from behind the deer: shows the body relief
		sun.rotation = Vector3(deg_to_rad(-14), deg_to_rad(150), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.3, 0.18)
	floor.material_override = fm
	root.add_child(floor)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Herd.build_mesh("stag" in args)
	mm.instance_count = 4
	var poses := [Color(0, 0, 0, 0), Color(0.3, 0.09, 0, 0.4), Color(0, 0, 1, 0), Color(0.35, 0.95, 0, 0)]
	for i in 4:
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(-3.6 + i * 2.4, 0, 0)))
		mm.set_instance_custom_data(i, poses[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/deer.gdshader")
	mat.set_shader_parameter("stag", 1.0 if "stag" in args else 0.0)
	mmi.material_override = mat
	root.add_child(mmi)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	if "near" in args:   # the standing deer alone, filling the frame
		cam.look_at_from_position(Vector3(-3.6, 1.3, 3.4), Vector3(-3.6, 1.05, 0))
	else:
		cam.look_at_from_position(Vector3(0, 1.3, 7.5), Vector3(0, 0.8, 0))
	for i in 8:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("DEER view saved ", out)
	quit()
