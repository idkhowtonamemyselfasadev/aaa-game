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
	"sunset":   [Vector3(-20, 0, -110), Vector3(10, 0, 150)],   # looks +Z: the evening sun's side
	"player":   [],
}

var _action := Callable()

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
	if spot == "midges":
		# a midge swarm against the low sun: camera on the far side, sun behind the cloud
		await get_tree().process_frame
		var c: Vector3 = world.get_node("Insects").swarm_centres()[0]
		var sd: Vector3 = world.sun.global_transform.basis.z
		sd.y = 0.0
		sd = sd.normalized()
		SPOTS[spot] = [c - sd * 3.2 + sd.cross(Vector3.UP) * 0.6, c + sd * 2.0]
		print("SHOT midge swarm at %s, sun dir %s" % [c, sd])
	if spot == "fireflies":
		# low over the night meadow just beside the hero, looking out across the grass
		var pp := player.global_position
		SPOTS[spot] = [pp + Vector3(-1.5, 0, 2.5), pp + Vector3(6, 0, -14)]
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
	var foe_u := -1.0
	var foe_state := HollowSoldier.WINDUP
	if spot == "soldier" or spot == "soldierface" or spot == "lockon":
		# soldier [u=0.7] [strike|stagger|dead]: the Hollow Soldier 3.4 m from the hero (who
		# has the staff drawn), frozen at u of the chosen state; side-on from the sun side.
		# soldierface: a 3/4 front portrait of the soldier over the hero's shoulder.
		foe_u = 0.7
		for a in args:
			if a.begins_with("u="):
				foe_u = float(a.substr(2))
		if "strike" in args:
			foe_state = HollowSoldier.STRIKE
		elif "stagger" in args:
			foe_state = HollowSoldier.STAGGER
		elif "dead" in args:
			foe_state = HollowSoldier.DEAD
		if "flinch" in args or "fallen" in args:
			# clear of the practice post, which stands at the start
			var at := player.global_position + Vector3(3.0, 0, -6.0)
			player.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.05, at.z)
		var pp := player.global_position
		var foe: HollowSoldier = world.soldier
		var fp := pp + (Vector3(-3.4, 0, 0.6) if spot != "lockon" else Vector3(-1.2, 0, 4.6))
		foe.global_position = Vector3(fp.x, terrain.height_at(fp.x, fp.z) + 0.05, fp.z)
		foe._home = foe.global_position
		foe.face(pp)
		player.body.rotation.y = atan2(fp.x - pp.x, fp.z - pp.z)
		var light: Vector3 = -world.sun.global_transform.basis.z
		var line := Vector3(fp.x - pp.x, 0, fp.z - pp.z).normalized()
		var side := line.cross(Vector3.UP)
		if side.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
			side = -side
		var mid := pp.lerp(fp, 0.5)
		if spot == "soldier":
			var back := 4.8 if "flinch" in args or "fallen" in args else 3.6
			SPOTS[spot] = [mid + side * back - line * 0.4, mid]
			if "fallen" in args:
				# frame the body where it falls (forward along its facing, toward the soldier)
				SPOTS[spot] = [pp + side * 3.0 + line * 0.2, pp + line * 0.8]
		elif spot == "lockon":
			pass                                  # the follow camera, swung by the lock
		elif "lit" in args:
			# soldierface lit: swing the camera round toward the light-travel side (lit side at
			# midday; at a low evening sun the frame can still come out backlit)
			var sunward := Vector3(light.x, 0, light.z).normalized()
			var d := (sunward * 2.0 - line).normalized()
			SPOTS[spot] = [fp + d * 2.3, fp]
		else:
			SPOTS[spot] = [fp - line * 2.4 + side * 1.0, fp]
	if spot != "player" and SPOTS.has(spot):
		var s: Array = SPOTS[spot]
		var pos: Vector3 = s[0]
		var look: Vector3 = s[1]
		pos.y = look.y - 0.35 if spot == "midges" else terrain.height_at(pos.x, pos.z) + (1.2 if spot == "fireflies" else 1.5 if spot in ["hero", "heroback", "staff"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 or foe_u >= 0.0 else 2.5)
		look.y = (s[1] as Vector3).y if spot == "midges" else terrain.height_at(look.x, look.z) + (0.6 if spot == "fireflies" else 1.3 if spot == "staff" else 1.1 if spot in ["hero", "heroback"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 else 1.35 if foe_u >= 0.0 else 1.5)
		var free := Camera3D.new()
		free.fov = 65.0
		free.far = 3000.0
		world.add_child(free)
		free.global_position = pos
		free.look_at(look)
		free.current = true
		cam = free
	if "legs" in args and foe_u >= 0.0 and cam != null:
		# a low close look at the soldier's shins and forearms (wraps over the old armour)
		var fp2: Vector3 = world.soldier.global_position
		var d2 := (cam.global_position - fp2) * Vector3(1, 0, 1)
		cam.global_position = fp2 + d2.normalized() * 1.7 + Vector3.UP * 0.75
		cam.look_at(fp2 + Vector3.UP * 0.6)
	if "nograss" in args and world.has_node("Grass"):
		world.get_node("Grass").visible = false
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
	if foe_u >= 0.0:
		# step the soldier and the hero's draw by hand (awaiting physics frames with the
		# render loop off stalls under Vulkan here), then hold everything still for the shot
		player.use_bot_input = true
		var foe: HollowSoldier = world.soldier
		var dt := 1.0 / 60.0
		foe.set_physics_process(false)
		player.combat._begin_draw()
		for i in 30:
			player.combat.physics_step(dt)
		var sw := "sweep" in args
		if sw:
			foe.move_kind = HollowSoldier.SWEEP_MOVE
		var dur := {HollowSoldier.WINDUP: HollowSoldier.SWEEP_WINDUP_T if sw else HollowSoldier.WINDUP_T, HollowSoldier.STRIKE: HollowSoldier.SWEEP_T if sw else HollowSoldier.STRIKE_T, HollowSoldier.STAGGER: HollowSoldier.STAGGER_T, HollowSoldier.DEAD: 2.4}
		if foe_state == HollowSoldier.STAGGER:
			foe.take_hit(foe.global_position + Vector3.UP, Vector3(1, 0, 0), 1.0, 0.0)
		elif foe_state == HollowSoldier.DEAD:
			foe.take_hit(foe.global_position + Vector3.UP, Vector3(1, 0, 0), 20.0, 0.0)
		else:
			foe.windups += 1
			foe._enter(HollowSoldier.WINDUP)
			if foe_state == HollowSoldier.STRIKE:
				foe.t = float(dur[HollowSoldier.WINDUP])
		for i in 600:
			foe._physics_process(dt)
			if foe.state == foe_state and foe.t >= foe_u * float(dur[foe_state]):
				break
		player.set_physics_process(false)
		if "parry" in args or "smash" in args or "flinch" in args or "fallen" in args:
			_action = func(): await _heavy_action(player, foe, args)
		if spot == "lockon":
			# lock on from a camera looking well off to the side, let the lock swing it round
			player.set_look(player.body.rotation.y + PI + 0.9, -0.15)
			player.cam_pivot.rotation = Vector3(player._pitch, player._yaw, 0.0)
			player.toggle_lock()
			for i in 240:
				player._update_lock(dt)
			player.cam_pivot.rotation = Vector3(player._pitch, player._yaw, 0.0)
			print("SHOT lockon target %s yaw %.2f pitch %.2f" % [player.lock_target, player._yaw, player._pitch])
		print("SHOT soldier state %d t %.3f ember %.2f" % [foe.state, foe.t, foe.max_ember])
	for i in frames:
		await get_tree().process_frame
	if _action.is_valid():
		await _action.call()
		for i in 2:
			await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var abs := ProjectSettings.globalize_path("res://") .path_join(out)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var err := img.save_png(abs)
	print("SHOT %s -> %s (%s) err=%d" % [spot, abs, img.get_size(), err])
	get_tree().quit(0 if err == OK else 1)

## Runs after the warm-up frames so the world keeps updating (pausing the tree froze the
## sky/terrain uniforms and grass streaming); the FX then get only a couple of frames to age.
func _heavy_action(player: Player, foe: HollowSoldier, args: PackedStringArray) -> void:
	var c: StaffCombat = player.combat
	var dt := 1.0 / 60.0
	if "parry" in args:
		# the heavy raised just as the thrust lands: deflect sparks, soldier knocked back
		c._start_charge()
		c.heavy_held = true
		for i in 7:
			c.physics_step(dt)
		c.try_parry(foe)
		for i in 3:
			foe._physics_process(dt)
		print("SHOT parry parries %d tier %d" % [c.parries, c.tier])
	elif "flinch" in args:
		# the thrust gets through: the hero rocks back from it at the peak of the stagger
		player.receive_attack(foe, HollowSoldier.DAMAGE)
		ImpactFX.spawn(player.get_parent(), player.global_position + Vector3.UP * 1.15, foe.body.global_basis.z, "stone", 0.7)
		for i in 6:
			player._physics_process(dt)
		print("SHOT flinch t %.3f flinches %d" % [player.flinch_t, player.flinches])
	elif "fallen" in args:
		# the killing blow: the hero collapses face-down (fallen=<seconds after the blow>)
		var at := 1.5
		for a in args:
			if a.begins_with("fallen="):
				at = float(a.substr(7))
		player.health = 5.0
		player.receive_attack(foe, HollowSoldier.DAMAGE)
		for i in int(at * 60.0):
			player._physics_process(dt)
		# look down on the body from the side, over the grass
		var mid := player.model.global_transform * Vector3(0, 0.9, 0)
		var cam := get_viewport().get_camera_3d()
		var side := player.body.global_basis.x
		cam.global_position = mid + side * 2.4 - player.body.global_basis.z * 0.6 + Vector3.UP * 1.9
		cam.look_at(mid + Vector3.UP * 0.1)
		print("SHOT fallen dead_t %.2f black %.2f" % [player.dead_t, player.screen_black()])
	elif "smash" in args:
		# a full-charge heavy meeting the ground in front of the hero
		c._start_charge()
		c.heavy_held = true
		for i in 75:
			c.physics_step(dt)
		c.heavy_held = false
		for i in 200:
			c.physics_step(dt)
			if c.is_attacking() and c.t / float(StaffCombat.HEAVY["dur"]) >= 0.43:
				break
		print("SHOT smash tier %d u %.2f" % [c.tier, c.t / float(StaffCombat.HEAVY["dur"])])
