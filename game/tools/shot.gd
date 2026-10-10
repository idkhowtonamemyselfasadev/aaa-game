extends Node
## Screenshot tool. Usage (after `--`): <spot> <out.png> [frames] [hour]
## Loads world.tscn, puts the camera at a named spot, waits N frames, saves, quits.

var SPOTS := {
	"village":  [Vector3(-30, 0, 40), Vector3(90, 0, -120)],
	"hill":     [Vector3(-150, 0, 110), Vector3(0, 0, 0)],
	"side":     [Vector3(-120, 0, -40), Vector3(60, 0, 100)],
	"valley":   [Vector3(60, 0, -140), Vector3(-60, 0, 60)],
	"ridge":    [Vector3(190, 0, 190), Vector3(0, 0, 0)],
	"ground":   [Vector3(-30, 0, 40), Vector3(-20, 0, 25)],
	"east":     [Vector3(170, 0, 20), Vector3(-80, 0, -30)],
	"player":   [],
}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var spot := args[0] if args.size() > 0 else "player"
	var out := args[1] if args.size() > 1 else "../shots/shot.png"
	var frames := int(args[2]) if args.size() > 2 else 90
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	world.run_clock = false
	if args.size() > 3:
		world.time_of_day = float(args[3])
	await get_tree().process_frame
	var player: Player = world.get_node("Player")
	var terrain: Terrain = world.get_node("Terrain")
	var cam: Camera3D = player.camera
	if spot == "tree" or spot == "rocks":
		# frame the nearest tree / boulder to the village edge, from the village side
		var flora: Flora = world.get_node("Flora")
		var list: Array[Vector3] = flora.tree_positions if spot == "tree" else flora.rock_positions
		var best := list[0]
		for q in list:
			if Vector2(q.x + 20, q.z - 50).length() < Vector2(best.x + 20, best.z - 50).length():
				best = q
		var back := (Vector3(0, 0, 0) - best)
		back.y = 0
		back = back.normalized() * (16.0 if spot == "tree" else 6.0)
		SPOTS[spot] = [best + back, best + Vector3.UP * (3.0 if spot == "tree" else -1.0)]
	if spot == "birds" or spot == "rooks":
		# "birds": camera close enough that the flock bursts up; "rooks": they keep feeding
		var site: Vector3 = world.get_node("Birds").site_positions()[0]
		var d := 9.0 if spot == "birds" else 15.5
		SPOTS[spot] = [site + Vector3(-d * 0.8, 0, d * 0.6), site + Vector3(0, -0.5 if spot == "rooks" else 3.5, 0)]
	if spot == "hero":
		# close three-quarter portrait of the idle player character
		var pp := player.global_position
		var fwd := player.body.global_transform.basis.z
		SPOTS[spot] = [pp + fwd.rotated(Vector3.UP, 0.6) * 3.2, pp]
	if spot == "heroback" or spot == "staff":
		# rear three-quarter of the idle player: the staff slung across the back
		var pp := player.global_position
		var back := -player.body.global_transform.basis.z
		var d := 3.0 if spot == "heroback" else 1.6
		SPOTS[spot] = [pp + back.rotated(Vector3.UP, -0.5) * d, pp + Vector3.UP * (0.0 if spot == "heroback" else 0.25)]
	if spot == "herorun":
		# player runs to the camera's right: side view of the run cycle from the follow camera
		player.use_bot_input = true
		player.bot_input = Vector2(1, 0)
		player.set_look(0.0, -0.12)
		player.spring.spring_length = 3.2
	var swing_step := -1
	var swing_u := 0.5
	if spot.begins_with("swing"):
		# freeze the light string mid-swing: swing<step> [u=0.5]; 3/4 front, 3.8 m
		swing_step = int(spot.substr(5))
		for a in args:
			if a.begins_with("u="):
				swing_u = float(a.substr(2))
		# camera on the sun's side so the hero is front-lit; hero turned 3/4 toward it
		var pp := player.global_position
		var light: Vector3 = -world.sun.global_transform.basis.z
		var to_cam := Vector3(-light.x, 0, -light.z).normalized()
		player.body.rotation.y = atan2(to_cam.x, to_cam.z) - 0.75
		SPOTS[spot] = [pp + to_cam * 3.8, pp]
	var impact_step := -1
	var impact_after := 6
	if spot.begins_with("impact"):
		# impact<step> [after=N]: hero faces the practice post, string runs until hit <step>
		# connects, then N more ticks so chaff and dust are mid-flight; side-on, sun side
		impact_step = int(spot.substr(6))
		for a in args:
			if a.begins_with("after="):
				impact_after = int(a.substr(6))
		var pp := player.global_position
		var post: Vector3 = world.training_post.global_position
		var to_post := Vector3(post.x - pp.x, 0, post.z - pp.z).normalized()
		var light: Vector3 = -world.sun.global_transform.basis.z
		var side := to_post.cross(Vector3.UP)
		if side.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
			side = -side
		var mid := pp.lerp(post, 0.5)
		SPOTS[spot] = [mid + side * 2.7 - to_post * 0.7, mid]
	var dodge_u := -1.0
	if spot == "dodge":
		# dodge [u=0.35]: dash-step to world +X frozen mid-dash, side-on from the sun side
		dodge_u = 0.35
		for a in args:
			if a.begins_with("u="):
				dodge_u = float(a.substr(2))
		var pp := player.global_position
		var light: Vector3 = -world.sun.global_transform.basis.z
		var side := Vector3(0, 0, 1) if -light.z > 0.0 else Vector3(0, 0, -1)
		var mid := pp + Vector3(1.3, 0, 0)
		SPOTS[spot] = [mid + side * 3.6 + Vector3(0.6, 0, 0), mid]
	if spot != "player" and SPOTS.has(spot):
		var s: Array = SPOTS[spot]
		var pos: Vector3 = s[0]
		var look: Vector3 = s[1]
		pos.y = terrain.height_at(pos.x, pos.z) + (1.5 if spot in ["hero", "heroback", "staff"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 else 2.5)
		look.y = terrain.height_at(look.x, look.z) + (1.3 if spot == "staff" else 1.1 if spot in ["hero", "heroback"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 else 1.5)
		var free := Camera3D.new()
		free.fov = 65.0
		free.far = 3000.0
		world.add_child(free)
		free.global_position = pos
		free.look_at(look)
		free.current = true
		cam = free
	if "nofog" in args:
		world.env.environment.fog_enabled = false
		world.env.environment.volumetric_fog_enabled = false
	if "novol" in args:
		world.env.environment.volumetric_fog_enabled = false
	if "nosdfgi" in args:
		world.env.environment.sdfgi_enabled = false
	if "noshadow" in args:
		world.sun.shadow_enabled = false
	if "nogi" in args:
		world.env.environment.sdfgi_enabled = false
		world.env.environment.ssao_enabled = false
		world.env.environment.ssil_enabled = false
	if "noglow" in args:
		world.env.environment.glow_enabled = false
	for a in args:
		if a.begins_with("skyx="):
			world.sky_energy_scale = float(a.substr(5))
		if a.begins_with("ambx="):
			world.ambient_scale = float(a.substr(5))
	if "norefl" in args:
		world.env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if "skyrt" in args:
		world.env.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	if "noupd" in args:
		world.set_process(false)
	if swing_step >= 0:
		Engine.max_physics_steps_per_frame = 1     # one physics tick per frame: exact pose
		player.use_bot_input = true
		var c: StaffCombat = player.combat
		RenderingServer.render_loop_enabled = false   # simulate the string without drawing
		for i in 3000:
			if c.swings < swing_step + 1:
				player.bot_attack = true
			await get_tree().physics_frame
			if c.step == swing_step and c.t / float(c.STRING[swing_step]["dur"]) >= swing_u:
				break
		get_tree().paused = true
		RenderingServer.render_loop_enabled = true
		print("SHOT swing step %d u %.2f" % [c.step, c.t / float(c.STRING[maxi(c.step, 0)]["dur"])])
	if impact_step >= 0:
		Engine.max_physics_steps_per_frame = 1
		player.use_bot_input = true
		var c: StaffCombat = player.combat
		RenderingServer.render_loop_enabled = false
		var after := -1
		var hit_step := [-1]
		c.hit_landed.connect(func(_t, _p, _w): hit_step[0] = c.step)
		for i in 3000:
			if c.swings < impact_step + 1:
				player.bot_attack = true
			await get_tree().physics_frame
			if after < 0 and hit_step[0] == impact_step:
				after = 0
			elif after >= 0:
				after += 1
				if after >= impact_after:
					break
		get_tree().paused = true
		RenderingServer.render_loop_enabled = true
		print("SHOT impact hits %d step %d" % [c.hits, c.step])
	if dodge_u >= 0.0:
		Engine.max_physics_steps_per_frame = 1
		player.use_bot_input = true
		player.set_look(0.0, -0.3)
		RenderingServer.render_loop_enabled = false
		player.receive_attack(self, 12.0)      # bring the HUD up with a dent in the vitality bar
		for i in 60:
			await get_tree().physics_frame
		player.bot_input = Vector2(1, 0)
		player.bot_dodge = true
		for i in 600:
			await get_tree().physics_frame
			if player.dodge_t >= dodge_u * Player.DODGE_TIME:
				break
		get_tree().paused = true
		RenderingServer.render_loop_enabled = true
		print("SHOT dodge t %.3f" % player.dodge_t)
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var abs := ProjectSettings.globalize_path("res://") .path_join(out)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var err := img.save_png(abs)
	print("SHOT %s -> %s (%s) err=%d" % [spot, abs, img.get_size(), err])
	get_tree().quit(0 if err == OK else 1)
