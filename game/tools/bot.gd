extends Node
## Headless scripted player. Usage (after `--`): <route> [max_seconds]
## Routes are lists of world-space XZ waypoints; the bot steers the Player toward each and
## reports PASS/FAIL. Exit code 0 on pass. Run with: godot --headless res://tools/bot.tscn -- walk

const ROUTES := {
	# walk a loop across the vale: proves terrain collision, slopes and stamina work
	"walk": [Vector2(0, 0), Vector2(40, 10), Vector2(60, -40), Vector2(0, -60), Vector2(-50, -10), Vector2(0, 0)],
	# climb the eastern ridge with sprint+jump: proves steep slopes are walkable up to floor_max_angle
	"ridge": [Vector2(0, 0), Vector2(120, 120), Vector2(200, 200)],
	# stand in the meadow and chain the Ward light string, then wait for the staff to be slung
	"combat": [],
}

var _world: Node3D
var _player: Player
var _route: Array = []
var _i := 0
var _t := 0.0
var _max := 120.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _min_y := INF
var _max_y := -INF
var _max_blend := 0.0

func _ready() -> void:
	Engine.time_scale = 4.0   # headless: simulate faster, same fixed physics delta
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "walk"
	if args.size() > 1:
		_max = float(args[1])
	_route = ROUTES.get(name, ROUTES["walk"])
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	_world.run_clock = false
	await get_tree().process_frame
	_player = _world.get_node("Player")
	_player.use_bot_input = true
	_player.set_look(0.0, -0.3)
	_last_pos = _player.global_position
	if name == "combat":
		_combat_test()
		return
	print("BOT route=%s waypoints=%d start=%s" % [name, _route.size(), _player.global_position])

func _physics_process(delta: float) -> void:
	if _player == null or _i >= _route.size():
		return
	_t += delta
	var p := _player.global_position
	_min_y = minf(_min_y, p.y)
	_max_y = maxf(_max_y, p.y)
	_max_blend = maxf(_max_blend, _player._blend)
	var target: Vector2 = _route[_i]
	var to := target - Vector2(p.x, p.z)
	if to.length() < 1.5:
		print("BOT reached %d %s at t=%.1f y=%.1f" % [_i, target, _t, p.y])
		_i += 1
		if _i >= _route.size():
			_finish(true, "all waypoints reached")
		return
	# camera yaw is 0 => forward is -Z; map world dir into input (x right, y back)
	var d := to.normalized()
	_player.bot_input = Vector2(d.x, d.y)
	_player.bot_sprint = true
	# unstick: jump if barely moving
	if (p - _last_pos).length() < 0.02:
		_stuck_t += delta
		if _stuck_t > 0.6:
			_player.bot_jump = true
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = p
	if p.y < -50.0:
		_finish(false, "fell through the world")
	elif _t > _max:
		_finish(false, "timeout at waypoint %d, pos %s" % [_i, p])

func _finish(ok: bool, why: String) -> void:
	_i = _route.size() + 1
	# grass must have streamed in around wherever the bot ended up
	var grass := _world.get_node("Grass")
	print("BOT grass chunks loaded: %d" % grass.loaded_chunks())
	if ok and grass.loaded_chunks() < 10:
		ok = false
		why = "grass did not stream in (%d chunks)" % grass.loaded_chunks()
	var flora := _world.get_node("Flora")
	print("BOT flora: %d trees, %d rocks" % [flora.tree_positions.size(), flora.rock_positions.size()])
	if ok and (flora.tree_positions.size() < 100 or flora.rock_positions.size() < 100):
		ok = false
		why = "flora did not scatter"
	var birds := _world.get_node("Birds")
	print("BOT birds: %d sites, %d scatters, %d landings" % [birds.site_positions().size(), birds.scatter_events, birds.landings])
	if ok and _route == ROUTES["walk"] and birds.scatter_events < 1:
		ok = false
		why = "rooks did not scatter when the player walked through their feeding site"
	# the character must be a skinned, animated model, blending into the run cycle
	var at: AnimationTree = _player.anim_tree
	print("BOT anim: tree=%s active=%s max blend %.2f" % [at != null, at != null and at.active, _max_blend])
	if ok and _route.size() > 0 and (at == null or not at.active or _max_blend < _player.ANIM_RUN_SPEED * 0.8):
		ok = false
		why = "player locomotion animation did not blend into the run"
	# the staff must be slung on the back: behind the torso, at shoulder-to-hip height, ~1.86 m long
	var staff: Staff = _player.staff
	if staff != null:
		var local := _player.body.global_transform.affine_inverse() * staff.global_position
		var aabb := staff.get_aabb()
		var tip := staff.global_transform * Vector3(0, aabb.end.y, 0)
		var butt := staff.global_transform * Vector3(0, aabb.position.y, 0)
		print("BOT staff: centre body-local %s, length %.2f m" % [local, tip.distance_to(butt)])
		if ok and (local.z > -0.05 or local.y < 0.9 or local.y > 1.6 or absf(tip.distance_to(butt) - Staff.LENGTH) > 0.05):
			ok = false
			why = "staff is not slung across the player's back at body scale"
	elif ok:
		ok = false
		why = "player has no staff"
	print("BOT %s: %s (t=%.1fs, y range %.1f..%.1f, stamina %.0f)" % ["PASS" if ok else "FAIL", why, _t, _min_y, _max_y, _player.stamina])
	get_tree().quit(0 if ok else 1)

## Light string: press attack on a rhythm, measure the tip's travel, the hands' grip on the
## shaft (IK), body spin on the 4th hit, then idle until the staff goes back on the back.
func _combat_test() -> void:
	var c: StaffCombat = _player.combat
	if c == null:
		_combat_done(false, "player has no combat node")
		return
	var tip_path := 0.0
	var max_grip := 0.0
	var max_hit_speed := 0.0
	var steps_seen := {}
	var yaw0: float = _player.body.rotation.y
	var spin_total := 0.0
	var last_tip := c.tip_position()
	var frames := 0
	var max_tilt := 0.0
	var max_stop := 0.0
	var min_stamina := INF
	var saw_fx := false
	var hit_steps: Array = []
	var press_t := 0.0
	var t := 0.0
	while t < 4.5:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		press_t += dt
		if press_t > 0.3 and c.swings < 4:
			_player.bot_attack = true
			press_t = 0.0
		var tip := c.tip_position()
		var d := tip.distance_to(last_tip)
		last_tip = tip
		if c.is_attacking():
			steps_seen[c.step] = true
			tip_path += d
			spin_total += c.spin_delta
			if c.hit_active:
				max_hit_speed = maxf(max_hit_speed, d / dt)
		if c.is_drawn() and c.state != StaffCombat.DRAWING and c.state != StaffCombat.SHEATHING:
			max_grip = maxf(max_grip, c.grip_error())
		frames += 1
		max_tilt = maxf(max_tilt, _world.training_post.tilt())
		max_stop = maxf(max_stop, c.hitstop)
		min_stamina = minf(min_stamina, _player.stamina)
		if _world.get_node_or_null("Impact") != null:
			saw_fx = true
		if c.hits > hit_steps.size():
			hit_steps.append(c.step)
	var post: TrainingPost = _world.training_post
	print("BOT combat: hits %d, post hits %d, max post tilt %.3f rad, max hitstop %.3f s, stamina %.0f -> min %.0f, hit on steps %s" % [c.hits, post.hits, max_tilt, max_stop, Player.STAMINA_MAX, min_stamina, hit_steps])
	print("BOT combat: swings %d, steps %s, tip path %.1f m, max tip speed %.1f m/s, max grip err %.3f m, spin %.2f rad" % [c.swings, steps_seen.keys(), tip_path, max_hit_speed, max_grip, spin_total])
	if c.swings < 4 or steps_seen.size() < 4:
		_combat_done(false, "light string did not chain all four hits")
		return
	if tip_path < 8.0 or max_hit_speed < 8.0:
		_combat_done(false, "staff tip barely moved during the swings")
		return
	if max_grip > 0.12:
		_combat_done(false, "hands came off the staff (IK grip error %.2f m)" % max_grip)
		return
	if c.hits < 4 or post.hits < 4:
		_combat_done(false, "the string did not connect with the practice post (%d hits)" % c.hits)
		return
	if max_stop < 0.05 or max_tilt < 0.01 or not saw_fx:
		_combat_done(false, "hits had no weight (hitstop %.3f, tilt %.3f, fx %s)" % [max_stop, max_tilt, saw_fx])
		return
	if min_stamina > Player.STAMINA_MAX - 30.0:
		_combat_done(false, "swings cost no stamina")
		return
	if absf(spin_total) < 5.5:
		_combat_done(false, "spinning sweep did not turn the hero around")
		return
	# idle: the staff must go back on the back
	var w := 0.0
	while w < StaffCombat.SHEATHE_AFTER + 2.0 and c.is_drawn():
		await get_tree().physics_frame
		w += get_physics_process_delta_time()
	if c.is_drawn():
		_combat_done(false, "staff was never slung back after combat")
		return
	_route = []
	_finish(true, "light string chained, staff re-slung after %.1f s idle" % w)

func _combat_done(ok: bool, why: String) -> void:
	print("BOT %s: %s" % ["PASS" if ok else "FAIL", why])
	get_tree().quit(0 if ok else 1)
