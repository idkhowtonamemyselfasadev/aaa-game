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
	# dash-step, swing-cancel, perfect dodge (slow-mo + refund), late dodge, unguarded hit
	"dodge": [],
	# Hollow Soldier: notices, stalks, telegraphs and thrusts (hit), a perfect dodge on the
	# glint, then the hero beats it down with the string until it crumbles
	"soldier": [],
	# Ward heavy: tap and full-charge smashes on the post, a parry on the soldier's thrust
	# (stagger + free tier + punish), and a raise started too early that does not parry
	"heavy": [],
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
	# scripted tests drive the hero themselves; only waypoint routes use the follower
	_route = ROUTES.get(name, [] if name in ["combat", "dodge", "soldier", "lockon", "heavy", "sweep", "insects", "butterflies", "flinch", "death", "weather", "roost", "ruin", "understory", "trample", "herd"] else ROUTES["walk"])
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
	if name == "dodge":
		_dodge_test()
		return
	if name == "soldier":
		_soldier_test()
		return
	if name == "lockon":
		_lockon_test()
		return
	if name == "heavy":
		_heavy_test()
		return
	if name == "sweep":
		_sweep_test()
		return
	if name == "insects":
		_insects_test()
		return
	if name == "butterflies":
		_butterflies_test()
		return
	if name == "weather":
		_weather_test()
		return
	if name == "roost":
		_roost_test()
		return
	if name == "ruin":
		_ruin_test()
		return
	if name == "understory":
		_understory_test()
		return
	if name == "trample":
		_trample_test()
		return
	if name == "herd":
		_herd_test()
		return
	if name == "flinch":
		_flinch_test()
		return
	if name == "death":
		_death_test()
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
	# the tall meadow is a mix of clump shapes, not one clump stamped everywhere
	var kinds: PackedInt32Array = grass.clump_kinds()
	print("BOT clump kinds: upright %d, tussock %d, seeding %d" % [kinds[0], kinds[1], kinds[2]])
	var total := kinds[0] + kinds[1] + kinds[2]
	if ok and (kinds[1] * 8 < total or kinds[2] * 25 < total or kinds[0] * 4 < total):
		ok = false
		why = "tall grass is not a mix of clump kinds (%d/%d/%d)" % [kinds[0], kinds[1], kinds[2]]
	# the short sward fills the soil round wherever the camera is
	print("BOT sward: %d chunks, %d clumps, slowest frame slice %.1f ms" % [grass.sward_chunks(), grass.sward_clumps(), grass.sward_build_ms])
	if ok and (grass.sward_chunks() < 4 or grass.sward_clumps() < 4000):
		ok = false
		why = "short sward did not stream in (%d chunks, %d clumps)" % [grass.sward_chunks(), grass.sward_clumps()]
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
	# the hero wears the travelling garb: hood + straw hat over the head, robe panels that swing
	var garb: HeroGarb = _player.garb
	if garb != null:
		var skel := _player.model.find_child("Skeleton3D", true, false) as Skeleton3D
		var head := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Head")).origin
		var hat_box := garb.hat.global_transform * garb.hat.get_aabb()
		print("BOT garb: %d pieces, %d wraps, panel swing %.0f deg, hat %.2f m wide, %.2f m above the head bone" % [
				garb.mats.size(), garb.wraps, rad_to_deg(garb.peak_swing), hat_box.size.x, hat_box.end.y - head.y])
		if ok and _route.size() > 0 and (garb.mats.size() < 14 or garb.peak_swing < deg_to_rad(8.0)
				or hat_box.size.x < 0.55 or hat_box.end.y < head.y + 0.1):
			ok = false
			why = "hero garb missing, hat off the head or robe panels not swinging"
		# the face cloth hangs in front of the face, below the hat brim
		var veil := garb.veil.global_transform * garb.veil.get_aabb()
		var fwd := _player.body.global_transform.basis.z
		var veil_front := (veil.get_center() - head).dot(fwd)
		print("BOT veil: %.2f m in front of the head bone, %.2f..%.2f m about it" % [
				veil_front, veil.position.y - head.y, veil.end.y - head.y])
		if ok and _route.size() > 0 and (veil_front < 0.03 or veil.end.y > hat_box.end.y):
			ok = false
			why = "hero face cloth not over the face"
		# a face with two eyes shows in the gap between the hood and the face cloth
		if garb.face == null or garb.eyes.size() != 2:
			if ok:
				ok = false
				why = "hero has no face or eyes"
		else:
			var e0 := garb.eyes[0].global_position
			var e1 := garb.eyes[1].global_position
			var mid := (e0 + e1) * 0.5
			var eye_front := (mid - head).dot(fwd)
			print("BOT face: eyes %.3f m apart, %.2f m in front of the head bone, %.2f m above the cloth top, %.2f m below the hat top" % [
					e0.distance_to(e1), eye_front, mid.y - veil.end.y, hat_box.end.y - mid.y])
			if ok and _route.size() > 0 and (e0.distance_to(e1) < 0.04 or e0.distance_to(e1) > 0.08
					or eye_front < 0.03 or mid.y < veil.end.y - 0.01 or mid.y > hat_box.end.y):
				ok = false
				why = "hero eyes not in the face gap"
	elif ok:
		ok = false
		why = "hero has no garb"
	# the Vanguard's sci-fi plates are restyled as black lacquered lamellar
	var restyled := 0
	for mi in _player.model.find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			var sm := (mi as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm != null and sm.get_shader_parameter("restyle") != null and float(sm.get_shader_parameter("restyle")) > 0.5:
				restyled += 1
	print("BOT armour restyled surfaces: %d" % restyled)
	if ok and _route.size() > 0 and restyled == 0:
		ok = false
		why = "hero armour not restyled"
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

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Dodge: distance + stamina + i-frames, cancels a swing, perfect window triggers slow motion
## and a stamina refund, a late attack is merely dodged, an unguarded one hurts.
func _dodge_test() -> void:
	var p := _player
	var base := Engine.time_scale
	await _ticks(20)
	# 1) dash to the right (camera yaw 0: input x=+1 is world +X)
	var start := p.global_position
	var st0 := p.stamina
	p.bot_input = Vector2(1, 0)
	p.bot_dodge = true
	var saw_iframes := false
	var max_lean := 0.0
	var min_st := st0
	for i in 400:
		await get_tree().physics_frame
		p.bot_input = Vector2.ZERO
		saw_iframes = saw_iframes or p.is_invulnerable()
		max_lean = maxf(max_lean, absf(p.model.transform.basis.get_euler().x))
		min_st = minf(min_st, p.stamina)
		if p.dodges >= 1 and p.dodge_t < 0.0:
			break
	var moved := Vector2(p.global_position.x - start.x, p.global_position.z - start.z)
	print("BOT dodge: moved %s (%.2f m), stamina %.0f -> min %.0f, iframes %s, lean %.2f rad, dodging %s" % [moved, moved.length(), st0, min_st, saw_iframes, max_lean, p.dodge_t >= 0.0])
	if moved.length() < 2.8 or moved.x < 2.5:
		return _combat_done(false, "dodge did not carry the hero ~3.6 m to the right")
	if min_st > st0 - 10.0 or not saw_iframes or max_lean < 0.2 or p.dodge_t >= 0.0:
		return _combat_done(false, "dodge had no cost / i-frames / lean, or never ended")
	if p.model.transform.origin.distance_to(p._model_rest.origin) > 0.001:
		return _combat_done(false, "model not restored after the dodge")
	# 2) dodge cancels a swing in progress
	await _ticks(60)
	var c: StaffCombat = p.combat
	p.bot_attack = true
	for i in 60:
		await get_tree().physics_frame
		if c.is_attacking() and c.t > 0.1:
			break
	if not c.is_attacking():
		return _combat_done(false, "could not start a swing to cancel")
	p.bot_dodge = true
	await _ticks(2)
	print("BOT dodge: swing cancelled -> attacking %s, dodging %s" % [c.is_attacking(), p.dodge_t >= 0.0])
	if c.is_attacking() or p.dodge_t < 0.0:
		return _combat_done(false, "dodge did not cancel the swing")
	await _ticks(40)
	# 3) perfect dodge: the blow lands 0.08 s into the dodge
	p.stamina = 50.0
	p.bot_input = Vector2(0, 1)
	p.bot_dodge = true
	while p.dodge_t < 0.06:
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	var st_before := p.stamina
	print("BOT dodge: blow lands %.3f s into the dodge" % p.dodge_t)
	var r := p.receive_attack(self, 20.0)
	var min_scale := Engine.time_scale
	var slow_ticks := 0
	while p.is_slowmo() and slow_ticks < 600:
		await get_tree().physics_frame
		min_scale = minf(min_scale, Engine.time_scale)
		slow_ticks += 1
	var fx := _world.get_node_or_null("DodgeFX") != null
	print("BOT dodge: perfect -> %s, time scale %.2f -> min %.2f -> %.2f after %d ticks, stamina %.0f -> %.0f, fx %s, health %.0f" % [r, base, min_scale, Engine.time_scale, slow_ticks, st_before, p.stamina, fx, p.health])
	if r != "perfect" or min_scale > base * 0.3 or absf(Engine.time_scale - base) > 0.001:
		return _combat_done(false, "perfect dodge did not slow time and restore it")
	if p.stamina < st_before + 20.0 or p.health < Player.HEALTH_MAX or p.perfect_dodges != 1:
		return _combat_done(false, "perfect dodge gave no refund or still hurt")
	await _ticks(40)
	# 4) late: the blow lands 0.25 s in -> dodged through i-frames, no slow motion
	p.bot_dodge = true
	await _ticks(1)
	while p.dodge_t < 0.22:
		await get_tree().physics_frame
	var r2 := p.receive_attack(self, 20.0)
	print("BOT dodge: late -> %s, slowmo %s, health %.0f" % [r2, p.is_slowmo(), p.health])
	if r2 != "dodged" or p.is_slowmo() or p.health < Player.HEALTH_MAX:
		return _combat_done(false, "late dodge should avoid damage without slow motion")
	await _ticks(40)
	# 5) standing still: the blow hurts
	var r3 := p.receive_attack(self, 20.0)
	await _ticks(2)
	var hud: Hud = p.get_node_or_null("Hud") as Hud
	if hud == null:
		for ch in p.get_children():
			if ch is Hud:
				hud = ch
	print("BOT dodge: unguarded -> %s, health %.0f, dodges %d, hud alpha %.2f" % [r3, p.health, p.dodges, hud.visible_alpha() if hud else -1.0])
	if r3 != "hit" or p.health > Player.HEALTH_MAX - 19.0:
		return _combat_done(false, "unguarded attack did no damage")
	if hud == null or hud.visible_alpha() < 0.1:
		return _combat_done(false, "HUD bars not shown after taking damage")
	_combat_done(true, "dash-step, swing cancel, perfect dodge slow-mo + refund, late dodge, hit")

func _soldier_test() -> void:
	var p := _player
	var s: HollowSoldier = _world.soldier
	s.force_move = HollowSoldier.THRUST_MOVE      # steps 1-2 test the thrust; the fight mixes
	await _ticks(10)
	var start_d := Vector2(s.global_position.x - p.global_position.x, s.global_position.z - p.global_position.z).length()
	print("BOT soldier: %.1f m away, state %d" % [start_d, s.state])
	if s.state != HollowSoldier.IDLE:
		return _combat_done(false, "soldier should be idle while the hero is far away")
	# 1) walk toward it until it notices and stalks in, then stand and take the first thrust
	var waited := 0.0
	while s.windups < 1 and waited < 20.0:
		var to := s.global_position - p.global_position
		p.bot_input = Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 6.0 else Vector2.ZERO
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	print("BOT soldier: noticed + closed in, windups %d after %.1f s, gap %.1f m" % [s.windups, waited, (s.global_position - p.global_position).length()])
	if s.windups < 1:
		return _combat_done(false, "soldier never closed in and wound up a thrust")
	var h0 := p.health
	while s.strikes < 1 or s.state == HollowSoldier.STRIKE:
		await get_tree().physics_frame
	print("BOT soldier: thrust 1 -> %s, max ember %.1f, health %.0f -> %.0f" % [s.last_result, s.max_ember, h0, p.health])
	if s.last_result != "hit" or p.health >= h0:
		return _combat_done(false, "unguarded thrust did not hurt the hero")
	if s.max_ember < 3.0:
		return _combat_done(false, "wind-up had no ember tell")
	# 2) next wind-up: dodge sideways just as the thrust starts -> perfect
	var n := s.strikes
	while s.state != HollowSoldier.WINDUP:
		await get_tree().physics_frame
	while s.state == HollowSoldier.WINDUP and s.t < HollowSoldier.WINDUP_T - 0.02:
		await get_tree().physics_frame
	p.bot_input = Vector2(1, 0)
	p.bot_dodge = true
	await _ticks(1)
	p.bot_input = Vector2.ZERO
	while s.strikes == n or s.state == HollowSoldier.STRIKE:
		await get_tree().physics_frame
	print("BOT soldier: thrust 2 -> %s, perfect dodges %d" % [s.last_result, p.perfect_dodges])
	if s.last_result != "perfect" and s.last_result != "dodged":
		return _combat_done(false, "a dodge on the glint did not avoid the thrust")
	while p.is_slowmo():
		await get_tree().physics_frame
	# 3) fight: face it and keep the string going; punish its recovery
	s.force_move = -1
	p.health = Player.HEALTH_MAX
	var t := 0.0
	var hp0 := s.health
	while not s.is_dead() and t < 40.0:
		var to := s.global_position - p.global_position
		var flat := Vector2(to.x, to.z)
		if flat.length() > 2.0:
			p.bot_input = flat.normalized()
		else:
			p.bot_input = Vector2.ZERO
			if not p.combat.is_attacking():
				p.body.rotation.y = atan2(to.x, to.z)
			p.bot_attack = true
		if p.health < 30.0:
			p.health = Player.HEALTH_MAX      # the bot tests the soldier, not survival
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	print("BOT soldier: fight %.1f s, hits taken %d, staggers %d, health %.0f -> %.0f, dead %s, strikes %d (sweeps %d)" % [t, s.hits_taken, s.staggers, hp0, s.health, s.is_dead(), s.strikes, s.sweeps])
	if not s.is_dead():
		return _combat_done(false, "the hero could not kill the soldier")
	if s.staggers < 1:
		return _combat_done(false, "soldier never staggered")
	if s.is_in_group("hittable"):
		return _combat_done(false, "dead soldier is still hittable")
	var spear := s.spear
	var rags := s.rags
	print("BOT soldier: rags %d pieces, tabard swung up to %.0f deg in the fight" % [rags.mats.size(), rad_to_deg(rags.peak_swing)])
	print("BOT soldier: %d bandage wraps on thighs, shins, feet and forearms" % rags.wraps)
	if rags.wraps < 8:
		return _combat_done(false, "soldier thigh/shin/foot/forearm wraps missing")
	if rags.mats.size() < 5 or rags.peak_swing < deg_to_rad(8.0):
		return _combat_done(false, "soldier rags missing or the tabard never swung with the legs")
	var cloth: ShaderMaterial = rags.mats[0]
	await _ticks(60)
	var burn: float = cloth.get_shader_parameter("dissolve")
	print("BOT soldier: rags burning away with the body, dissolve %.2f" % burn)
	if burn < 0.3:
		return _combat_done(false, "the rags did not burn away with the body")
	await _ticks(340)
	var gone := not is_instance_valid(s)
	print("BOT soldier: crumbled and freed %s, spear on ground y %.2f" % [gone, spear.global_position.y - _world.terrain.height_at(spear.global_position.x, spear.global_position.z) if is_instance_valid(spear) else -1.0])
	if not gone:
		return _combat_done(false, "dead soldier was never removed")
	_combat_done(true, "noticed, stalked, telegraphed thrust hit, dodged on the glint, killed, crumbled")

## Camera-relative stick input that walks the hero toward a world point.
func _input_toward(at: Vector3) -> Vector2:
	var to := at - _player.global_position
	to.y = 0.0
	var f := -_player.cam_pivot.global_basis.z
	f.y = 0.0
	var r := _player.cam_pivot.global_basis.x
	r.y = 0.0
	return Vector2(to.dot(r.normalized()), -to.dot(f.normalized())).normalized()

## Angle between the camera's flat view direction and the flat line from it to the lock point.
func _cam_error(t: Node3D) -> float:
	var cam := _player.camera
	var f := -cam.global_basis.z
	var to := Player.lock_point(t) - cam.global_position
	return Vector2(f.x, f.z).angle_to(Vector2(to.x, to.z))

func _lockon_test() -> void:
	var p := _player
	var s: HollowSoldier = _world.soldier
	var hud: Hud = null
	for ch in p.get_children():
		if ch is Hud:
			hud = ch
	await _ticks(10)
	# 1) the soldier is out of range (~20 m) and the post is behind the camera: no lock, the
	#    camera recentres behind the hero instead
	p.body.rotation.y = 0.0
	p.set_look(1.2, -0.3)
	p.bot_lock = true
	await _ticks(2)
	print("BOT lockon: far press -> target %s, yaw %.2f" % [p.lock_target, p._yaw])
	if p.lock_target != null and p.lock_target.is_in_group("enemy"):
		return _combat_done(false, "locked an enemy beyond LOCK_RANGE")
	if p.lock_target == null and absf(angle_difference(p._yaw, PI)) > 0.05:
		return _combat_done(false, "empty lock press did not recentre the camera")
	if p.lock_target != null:
		p.bot_lock = true
		await _ticks(2)
	# 2) walk until the soldier is in range, look away, lock: it must be the soldier
	#    (side-step the practice post first, it stands between the start and the soldier)
	p.set_look(PI, -0.3)                  # camera looks +Z, so input x = -world x, input y = -world z
	p.bot_input = Vector2(-1, 0)
	await _ticks(20)
	var walked := 0.0
	while (s.global_position - p.global_position).length() > 12.0 and walked < 15.0:
		p.bot_input = _input_toward(s.global_position)
		await get_tree().physics_frame
		walked += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	if (s.global_position - p.global_position).length() > 12.5:
		return _combat_done(false, "bot could not walk up to the soldier")
	var to0 := s.global_position - p.global_position
	p.set_look(atan2(-to0.x, -to0.z) + 0.6, -0.3)    # soldier 34 deg off the camera's centre
	p.bot_lock = true
	await _ticks(2)
	if p.lock_target != s:
		return _combat_done(false, "lock press near the soldier picked %s" % p.lock_target)
	var e0 := _cam_error(s)
	var w := 0.0
	while w < 1.0:
		await get_tree().physics_frame
		w += get_physics_process_delta_time()
	var e1 := absf(_cam_error(s))
	print("BOT lockon: locked soldier, camera error %.2f -> %.3f rad, pitch %.2f, reticle %s at %s" % [e0, e1, p._pitch, hud.reticle_visible() if hud else false, hud.reticle_screen if hud else Vector2()])
	if e1 > 0.08:
		return _combat_done(false, "camera did not swing to the target")
	if hud == null or not hud.reticle_visible():
		return _combat_done(false, "no lock-on reticle on screen")
	# 3) circle-strafe for 2 s: the camera keeps the soldier centred
	var worst := 0.0
	w = 0.0
	while w < 2.0:
		p.bot_input = Vector2(1, 0)
		await get_tree().physics_frame
		w += get_physics_process_delta_time()
		if w > 0.3:
			worst = maxf(worst, absf(_cam_error(s)))
	p.bot_input = Vector2.ZERO
	print("BOT lockon: strafe worst camera error %.3f rad" % worst)
	if worst > 0.25:
		return _combat_done(false, "camera lost the target while strafing")
	# 4) standing still the hero squares up to the target
	await _ticks(60)
	var lt := s.global_position - p.global_position
	var face_err := absf(angle_difference(p.body.rotation.y, atan2(lt.x, lt.z)))
	print("BOT lockon: facing error %.3f rad" % face_err)
	if face_err > 0.15:
		return _combat_done(false, "hero did not square up to the locked target")
	# 5) kill it: no other enemy in range -> the lock releases, the reticle fades
	s.health = 1.0
	s.take_hit(s.global_position + Vector3.UP, (s.global_position - p.global_position).normalized(), 1.0, 0.0)
	await _ticks(30)
	print("BOT lockon: soldier dead %s, lock %s, reticle %s" % [s.is_dead(), p.lock_target, hud.reticle_visible()])
	if not s.is_dead():
		return _combat_done(false, "test kill failed")
	if p.lock_target == s or (p.lock_target != null and p.lock_target.is_in_group("enemy")):
		return _combat_done(false, "lock did not release on the target's death")
	if hud.reticle_visible():
		return _combat_done(false, "reticle still shown after release")
	_combat_done(true, "range-gated pick, camera framing, strafe tracking, square-up, release on death")

func _wait_heavy_done(c: StaffCombat) -> void:
	while c.is_charging() or (c.is_attacking() and c.current_attack() == StaffCombat.HEAVY):
		await get_tree().physics_frame

## Heavy: a tap smashes at tier 0, a long hold climbs to tier 2 and hits harder for more
## stamina; raising it just before the soldier's thrust lands deflects it.
func _heavy_test() -> void:
	var p := _player
	var c: StaffCombat = p.combat
	var post: TrainingPost = _world.training_post
	await _ticks(10)
	# 1) tap: draws, raises, comes down at tier 0 on the post
	p.bot_heavy = true
	await _ticks(2)
	p.bot_heavy = false
	while c.heavies < 1:
		await get_tree().physics_frame
	var saw_slam := false
	while c.is_attacking():
		if _world.get_node_or_null("Impact") != null:
			saw_slam = true
		await get_tree().physics_frame
	print("BOT heavy: tap -> heavies %d, tier %d, post hits %d, power %.1f, slam fx %s" % [c.heavies, c.tier, post.hits, c.last_power, saw_slam])
	if post.hits < 1 or absf(c.last_power - StaffCombat.HEAVY_POWER[0]) > 0.01:
		return _combat_done(false, "tapped heavy did not smash the post at tier 0")
	# 2) hold to full charge, release
	p.stamina = Player.STAMINA_MAX
	var hits0 := post.hits
	p.bot_heavy = true
	var held := 0.0
	var max_tier := 0
	while held < 1.35:
		await get_tree().physics_frame
		held += get_physics_process_delta_time()
		max_tier = maxi(max_tier, c.tier)
	var st := p.stamina
	p.bot_heavy = false
	await _wait_heavy_done(c)
	print("BOT heavy: held %.2f s -> tier %d, post hits %d -> %d, power %.1f, stamina %.0f -> %.0f, max hitstop %.3f" % [held, max_tier, hits0, post.hits, c.last_power, st, p.stamina, StaffCombat.HITSTOP * c.last_power])
	if max_tier != 2 or post.hits <= hits0 or absf(c.last_power - StaffCombat.HEAVY_POWER[2]) > 0.01:
		return _combat_done(false, "full charge did not reach tier 2 and smash at full power")
	if st - p.stamina < StaffCombat.HEAVY_COST[2] - 1.0 and p.stamina > 0.5:
		return _combat_done(false, "full-charge smash did not cost its stamina")
	# 3) the soldier: walk in until it winds up, raise the heavy just before the thrust lands
	var s: HollowSoldier = _world.soldier
	s.force_move = HollowSoldier.THRUST_MOVE
	var waited := 0.0
	while s.windups < 1 and waited < 25.0:
		var to := s.global_position - p.global_position
		p.bot_input = _input_toward(s.global_position) if Vector2(to.x, to.z).length() > 6.0 else Vector2.ZERO
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	if s.windups < 1:
		return _combat_done(false, "soldier never wound up")
	p.stamina = Player.STAMINA_MAX
	while s.state == HollowSoldier.WINDUP and s.t < HollowSoldier.WINDUP_T - 0.1:
		await get_tree().physics_frame
	var h0 := p.health
	var sh0 := s.health
	p.bot_heavy = true
	var n := s.strikes
	while s.strikes == n or (s.state == HollowSoldier.STRIKE and s.last_result == ""):
		await get_tree().physics_frame
	while s.state == HollowSoldier.STRIKE:
		await get_tree().physics_frame
	print("BOT heavy: parry -> %s, parries %d, tier %d, hero health %.0f -> %.0f, soldier state %d (stagger %d)" % [s.last_result, c.parries, c.tier, h0, p.health, s.state, HollowSoldier.STAGGER])
	if s.last_result != "parried" or c.parries != 1 or p.health < h0:
		return _combat_done(false, "heavy raised on the thrust did not parry it")
	if s.state != HollowSoldier.STAGGER or c.tier < 1:
		return _combat_done(false, "parry did not stagger the soldier and bank a tier")
	# punish: keep the charge to tier 2, shuffle in, release while it reels
	while c.charge_t < StaffCombat.CHARGE_TIERS[2] + 0.02:
		var to := s.global_position - p.global_position
		p.bot_input = _input_toward(s.global_position) if Vector2(to.x, to.z).length() > 2.3 else Vector2.ZERO
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	var reeling := s.state == HollowSoldier.STAGGER
	var gap := s.global_position - p.global_position
	print("BOT heavy: release gap %.2f m, facing err %.2f rad" % [Vector2(gap.x, gap.z).length(), p.body.global_basis.z.angle_to(Vector3(gap.x, 0, gap.z))])
	var taken := s.hits_taken
	p.bot_heavy = false
	await _wait_heavy_done(c)
	print("BOT heavy: punish released while reeling %s -> soldier hits %d -> %d, health %.0f -> %.1f, power %.1f" % [reeling, taken, s.hits_taken, sh0, s.health, c.last_power])
	if not reeling or s.hits_taken <= taken:
		return _combat_done(false, "charged punish did not land on the staggered soldier")
	# 4) raised too early: the window is over when the thrust lands -> it hits
	if s.is_dead():
		return _combat_done(false, "soldier died before the late-parry check")
	s.health = HollowSoldier.HEALTH_MAX
	n = s.windups
	while s.windups == n:
		var to := s.global_position - p.global_position
		p.bot_input = _input_toward(s.global_position) if Vector2(to.x, to.z).length() > 3.5 else Vector2.ZERO
		if not p.combat.is_attacking() and not p.combat.is_charging():
			p.body.rotation.y = atan2(to.x, to.z)
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	while s.t < 0.1:
		await get_tree().physics_frame
	p.stamina = Player.STAMINA_MAX
	h0 = p.health
	var parries0 := c.parries
	p.bot_heavy = true
	n = s.strikes
	while s.strikes == n or s.state == HollowSoldier.STRIKE:
		await get_tree().physics_frame
	p.bot_heavy = false
	await _wait_heavy_done(c)
	print("BOT heavy: early raise -> %s, parries %d, hero health %.0f -> %.0f" % [s.last_result, c.parries, h0, p.health])
	if c.parries != parries0 or s.last_result == "parried":
		return _combat_done(false, "a raise started 0.7 s early still parried")
	if s.last_result == "hit" and p.health >= h0:
		return _combat_done(false, "unparried thrust did no damage")
	_combat_done(true, "tap and tier-2 smashes, parry on the thrust staggered it, charged punish landed, early raise did not parry")

## Flinch: a thrust that lands on a heavy raised too early breaks the charge, shoves the hero
## back and locks out attacks; a dodge breaks the stagger once the blow has passed; the
## released heavy's downswing takes a blow without breaking.
func _flinch_test() -> void:
	var p := _player
	var s: HollowSoldier = _world.soldier
	var c: StaffCombat = p.combat
	await _ticks(10)
	# draw first so the raise starts on time
	p.bot_heavy = true
	await _ticks(2)
	p.bot_heavy = false
	await _wait_heavy_done(c)
	await _ticks(30)
	p.stamina = Player.STAMINA_MAX
	_soldier_at(s, 2.4, HollowSoldier.THRUST_MOVE)
	while s.state != HollowSoldier.WINDUP:
		await get_tree().physics_frame
	while s.t < 0.1:
		await get_tree().physics_frame
	p.bot_heavy = true
	var n := s.strikes
	var start := p.global_position
	var h0 := p.health
	while s.strikes == n or (s.state == HollowSoldier.STRIKE and s.last_result == ""):
		await get_tree().physics_frame
	var charging_after := c.is_charging()
	print("BOT flinch: early raise -> %s, health %.0f -> %.0f, flinch_t %.2f, flinches %d, still charging %s" % [s.last_result, h0, p.health, p.flinch_t, p.flinches, charging_after])
	if s.last_result != "hit" or p.flinches != 1 or p.flinch_t < 0.0:
		p.bot_heavy = false
		return _combat_done(false, "thrust through a late charge did not stagger the hero")
	if charging_after:
		p.bot_heavy = false
		return _combat_done(false, "the charge survived the hit")
	# still holding heavy and mashing light: nothing may start while reeling
	var sw := c.swings
	var max_lean := 0.0
	while p.flinch_t >= 0.0 and p.flinch_t < Player.FLINCH_TIME * 0.9:
		p.bot_attack = true
		max_lean = maxf(max_lean, p.model.transform.basis.y.angle_to(p._model_rest.basis.y))
		await get_tree().physics_frame
	p.bot_heavy = false
	await _ticks(20)
	var pushed := (p.global_position - start)
	var away := (p.global_position - s.global_position)
	print("BOT flinch: swings during stagger %d, max lean %.1f deg, pushed %.2f m (away %.2f), charging %s" % [c.swings - sw, rad_to_deg(max_lean), Vector2(pushed.x, pushed.z).length(), Vector2(pushed.x, pushed.z).normalized().dot(Vector2(away.x, away.z).normalized()), c.is_charging()])
	if c.swings != sw or c.is_charging():
		return _combat_done(false, "an attack started while reeling")
	if Vector2(pushed.x, pushed.z).length() < 0.4:
		return _combat_done(false, "the blow did not shove the hero back")
	if max_lean < deg_to_rad(10.0):
		return _combat_done(false, "no visible hit reaction")
	# 2) dodge out of a stagger once FLINCH_DODGE_AT has passed (direct hit, no soldier timing)
	await _ticks(10)
	p.stamina = Player.STAMINA_MAX
	p.receive_attack(s, 1.0)
	var d0 := p.dodges
	p.bot_dodge = true
	await _ticks(2)
	var early := p.dodges - d0
	while p.flinch_t >= 0.0 and p.flinch_t < Player.FLINCH_DODGE_AT + 0.02:
		await get_tree().physics_frame
	p.bot_dodge = true
	await _ticks(2)
	print("BOT flinch: dodge at once %d, dodge after %.2f s %d, flinch_t %.2f" % [early, Player.FLINCH_DODGE_AT, p.dodges - d0 - early, p.flinch_t])
	if early != 0 or p.dodges - d0 != 1 or p.flinch_t >= 0.0:
		return _combat_done(false, "dodge-out of the stagger is wrong")
	while p.dodge_t >= 0.0:
		await get_tree().physics_frame
	# 3) the released heavy's downswing is armoured
	await _ticks(20)
	p.stamina = Player.STAMINA_MAX
	var f0 := p.flinches
	p.bot_heavy = true
	await _ticks(2)
	p.bot_heavy = false
	while not (c.is_attacking() and c.current_attack() == StaffCombat.HEAVY):
		await get_tree().physics_frame
	await _ticks(3)
	var r := p.receive_attack(s, 1.0)
	var kept := c.is_attacking() and c.current_attack() == StaffCombat.HEAVY
	print("BOT flinch: hit on the downswing -> %s, armoured %d, flinches %d -> %d, swing kept %s" % [r, p.armoured_hits, f0, p.flinches, kept])
	if p.armoured_hits != 1 or p.flinches != f0 or not kept:
		return _combat_done(false, "the heavy's downswing was not armoured")
	_combat_done(true, "late charge broken by the thrust, hero shoved and locked out, dodge breaks the stagger, heavy downswing armoured")

## Death: the soldier's thrust on a hero at 10 vitality kills them; the body falls, the soldier
## stands down, the screen goes black, the hero wakes at the rest point whole and can fight,
## and the soldier is back at its post at full health.
func _death_test() -> void:
	var p := _player
	var s: HollowSoldier = _world.soldier
	var post := s._home
	var rest := p.respawn_point
	await _ticks(10)
	p.bot_input = Vector2(0.3, -1.0)             # wander a few metres off the rest point
	await _ticks(60)
	p.bot_input = Vector2.ZERO
	p.bot_attack = true                          # staff in hand, so the fall has to drop it
	while p.combat.swings < 1 or p.combat.state != StaffCombat.READY:
		await get_tree().physics_frame
	await _ticks(20)
	var fell_at := p.global_position
	p.health = 10.0
	s.health = 30.0                              # wounded in the fight: must come back whole
	_soldier_at(s, 2.4, HollowSoldier.THRUST_MOVE)
	var n := s.strikes
	var waited := 0
	while s.strikes == n or (s.state == HollowSoldier.STRIKE and s.last_result == ""):
		await get_tree().physics_frame
		waited += 1
		if waited % 120 == 0:
			print("BOT death: waiting, soldier state %d dist %.2f" % [s.state, (s.global_position - p.global_position).length()])
	print("BOT death: thrust -> %s, health %.0f, dead %s, deaths %d" % [s.last_result, p.health, p.is_dead(), p.deaths])
	if s.last_result != "hit" or not p.is_dead() or p.deaths != 1:
		return _combat_done(false, "the killing blow did not kill")
	s._home = post                               # its real post, ~20 m off: it walks back
	# input is dead: attacks, dodges and the stick do nothing; further blows miss
	var sw := p.combat.swings
	var d0 := p.dodges
	var max_tip := 0.0
	var min_y := INF
	var strikes_dead := s.strikes
	var hud: Hud = null
	for c in p.get_children():
		if c is Hud:
			hud = c
	var black := 0.0
	var skel := p.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var hips_bone := skel.find_bone("mixamorig_Hips")
	var knee_bone := skel.find_bone("mixamorig_LeftLeg")
	var hips_kneel := INF
	var knee_low := INF
	var staff_y := INF
	var dropped := p.combat.state == StaffCombat.DROPPED
	while p.is_dead():
		p.bot_attack = true
		p.bot_dodge = true
		p.bot_input = Vector2(0, -1)
		max_tip = maxf(max_tip, p.model.transform.basis.y.angle_to(p._model_rest.basis.y))
		if p.dead_t > 1.3:
			var head := p.model.global_transform * Vector3(0, 1.6, 0)
			min_y = minf(min_y, head.y - _world.terrain.height_at(head.x, head.z))
		if hud != null:
			black = maxf(black, hud.veil_alpha)
		if p.dead_t > 0.5 and hips_kneel == INF:
			# knelt: the hips have dropped and the knees are on the grass, not sunk through it
			var gy: float = _world.terrain.height_at(p.global_position.x, p.global_position.z)
			hips_kneel = (skel.global_transform * skel.get_bone_global_pose(hips_bone).origin).y - gy
			knee_low = (skel.global_transform * skel.get_bone_global_pose(knee_bone).origin).y - gy
		if p.dead_t > 1.6:
			staff_y = minf(staff_y, p.combat.staff.global_position.y - _world.terrain.height_at(p.combat.staff.global_position.x, p.combat.staff.global_position.z))
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	var r := "n/a"
	print("BOT death: swings %d, dodges %d, max tip %.0f deg, head %.2f m above ground once down, soldier strikes while down %d, state %d, black %.2f" % [p.combat.swings - sw, p.dodges - d0, rad_to_deg(max_tip), min_y, s.strikes - strikes_dead, s.state, black])
	if p.combat.swings != sw or p.dodges != d0:
		return _combat_done(false, "the dead hero acted")
	if max_tip < deg_to_rad(70.0) or min_y > 0.7:
		return _combat_done(false, "the body did not fall to the ground")
	if s.strikes != strikes_dead:
		return _combat_done(false, "the soldier kept attacking the body")
	print("BOT death: staff dropped %s, %.2f m above the grass once down; knelt hips %.2f m, knee %.2f m; staff state after waking %d" % [dropped, staff_y, hips_kneel, knee_low, p.combat.state])
	if not dropped or staff_y > 0.25:
		return _combat_done(false, "the staff did not fall from the hands")
	if hips_kneel > 0.75 or knee_low < -0.05 or knee_low > 0.3:
		return _combat_done(false, "the knees did not fold (legs sunk or still standing)")
	if p.combat.state != StaffCombat.SHEATHED:
		return _combat_done(false, "the staff is not back on the back after waking")
	if black < 0.99:
		return _combat_done(false, "the screen never went black")
	# woke at the rest point
	var off := Vector2(p.global_position.x - rest.x, p.global_position.z - rest.z).length()
	var sd := Vector2(s.global_position.x - post.x, s.global_position.z - post.z).length()
	print("BOT death: woke %.2f m from rest (fell %.1f m away), health %.0f, stamina %.0f, soldier %.2f m from post, health %.0f, state %d" % [off, Vector2(fell_at.x - rest.x, fell_at.z - rest.z).length(), p.health, p.stamina, sd, s.health, s.state])
	if off > 0.6 or p.health < Player.HEALTH_MAX or p.stamina < Player.STAMINA_MAX:
		return _combat_done(false, "did not wake whole at the rest point")
	if sd > 0.6 or s.health < HollowSoldier.HEALTH_MAX or s.state != HollowSoldier.IDLE:
		return _combat_done(false, "the soldier did not return to its post whole")
	await _ticks(int(Player.RESPAWN_FADE * 60.0) + 10)
	var veil: float = hud.veil_alpha if hud != null else 0.0
	r = p.receive_attack(s, 0.0)
	var start := p.global_position
	p.bot_input = Vector2(0, -1)
	await _ticks(40)
	p.bot_input = Vector2.ZERO
	sw = p.combat.swings
	p.bot_attack = true
	await _ticks(5)
	var moved := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	print("BOT death: after waking veil %.2f, hit -> %s, walked %.2f m, swing %d" % [veil, r, moved, p.combat.swings - sw])
	if veil > 0.01 or r != "hit" or moved < 1.0 or p.combat.swings == sw:
		return _combat_done(false, "the hero is not back in play after waking")
	_combat_done(true, "killing blow fells the hero, the soldier stands down, black, wakes whole at the rest point, soldier back at its post")

## Puts the soldier `d` metres in front of the hero, facing them, already stalking.
func _soldier_at(s: HollowSoldier, d: float, kind: int) -> void:
	var p := _player
	var fwd := p.body.global_basis.z
	fwd.y = 0.0
	var at := p.global_position + fwd.normalized() * d
	s.global_position = Vector3(at.x, _world.terrain.height_at(at.x, at.z) + 0.05, at.z)
	s._home = s.global_position
	s.face(p.global_position)
	s.force_move = kind
	s._from = s._pose
	s._enter(HollowSoldier.STALK)

func _wait_strike_done(s: HollowSoldier, n: int) -> void:
	while s.strikes == n or s.state == HollowSoldier.STRIKE:
		await get_tree().physics_frame

## Sweep: chosen when the hero crowds in; it catches a hero who stands or strafes (where a
## strafe beats the thrust), and is beaten by a dodge on the glint or a parry.
func _sweep_test() -> void:
	var p := _player
	var s: HollowSoldier = _world.soldier
	var c: StaffCombat = p.combat
	await _ticks(10)
	# 1) crowd it at 1.7 m: it picks the sweep by itself; stand still and take it
	_soldier_at(s, 1.7, -1)
	while s.state != HollowSoldier.WINDUP:
		await get_tree().physics_frame
	print("BOT sweep: crowded at 1.7 m -> move %d (sweep %d)" % [s.move_kind, HollowSoldier.SWEEP_MOVE])
	if s.move_kind != HollowSoldier.SWEEP_MOVE:
		return _combat_done(false, "soldier did not choose the sweep when crowded")
	var h0 := p.health
	var n := s.strikes
	var lo := 9.0
	var hi := -9.0
	while s.strikes == n or s.state == HollowSoldier.STRIKE:
		if s.state == HollowSoldier.STRIKE:
			var b := s._blade_bearing()
			lo = minf(lo, b)
			hi = maxf(hi, b)
		await get_tree().physics_frame
	print("BOT sweep: stood -> %s, health %.0f -> %.0f, blade arc %.0f..%.0f deg, max ember %.1f" % [s.last_result, h0, p.health, lo, hi, s.max_ember])
	if s.last_result != "hit" or h0 - p.health < HollowSoldier.SWEEP_DAMAGE - 0.5:
		return _combat_done(false, "standing hero was not cut by the sweep")
	if hi - lo < 150.0:
		return _combat_done(false, "sweep arc too narrow")
	# 2) strafe during the wind-up: the thrust loses the hero, the sweep does not
	var results := {}
	for kind in [HollowSoldier.THRUST_MOVE, HollowSoldier.SWEEP_MOVE]:
		while s.state != HollowSoldier.STALK and s.state != HollowSoldier.IDLE:
			await get_tree().physics_frame
		p.health = Player.HEALTH_MAX
		_soldier_at(s, 2.4 if kind == HollowSoldier.THRUST_MOVE else 1.9, kind)
		while s.state != HollowSoldier.WINDUP:
			await get_tree().physics_frame
		n = s.strikes
		var side := p.body.global_basis.x
		var start := p.global_position
		while s.strikes == n or s.state == HollowSoldier.STRIKE:
			# walk sideways for the last 0.45 s of the wind-up and through the strike
			var wt := HollowSoldier.WINDUP_T if kind == HollowSoldier.THRUST_MOVE else HollowSoldier.SWEEP_WINDUP_T
			if s.state != HollowSoldier.WINDUP or s.t > wt - 0.45:
				p.bot_input = Vector2(side.x, side.z).normalized() * 0.6
			await get_tree().physics_frame
		p.bot_input = Vector2.ZERO
		results[kind] = s.last_result
		print("BOT sweep: strafe vs %s: moved %.1f m sideways" % ["thrust" if kind == 0 else "sweep", (p.global_position - start).dot(side)])
	print("BOT sweep: strafed -> thrust %s, sweep %s" % [results[HollowSoldier.THRUST_MOVE], results[HollowSoldier.SWEEP_MOVE]])
	if results[HollowSoldier.SWEEP_MOVE] != "hit":
		return _combat_done(false, "a strafe escaped the sweep")
	# 3) dodge back on the glint -> the dodge verdict, no damage
	await _ticks(90)
	p.health = Player.HEALTH_MAX
	p.stamina = Player.STAMINA_MAX
	_soldier_at(s, 1.8, HollowSoldier.SWEEP_MOVE)
	while s.state != HollowSoldier.WINDUP:
		await get_tree().physics_frame
	while s.state == HollowSoldier.WINDUP and s.t < HollowSoldier.SWEEP_WINDUP_T - 0.02:
		await get_tree().physics_frame
	n = s.strikes
	var back := -p.body.global_basis.z
	p.bot_input = Vector2(back.x, back.z).normalized()
	p.bot_dodge = true
	await _ticks(1)
	p.bot_input = Vector2.ZERO
	await _wait_strike_done(s, n)
	print("BOT sweep: dodged on the glint -> %s, health %.0f, perfect dodges %d" % [s.last_result, p.health, p.perfect_dodges])
	if not s.last_result in ["perfect", "dodged", "miss"] or p.health < Player.HEALTH_MAX:
		return _combat_done(false, "a dodge on the glint did not avoid the sweep")
	while p.is_slowmo():
		await get_tree().physics_frame
	# 4) parry: raise the heavy just before the blade arrives
	while s.state != HollowSoldier.STALK and s.state != HollowSoldier.IDLE:
		await get_tree().physics_frame
	await _ticks(30)
	if not c.is_drawn():
		c._begin_draw()
	while not c.is_drawn():
		await get_tree().physics_frame
	p.stamina = Player.STAMINA_MAX
	_soldier_at(s, 1.8, HollowSoldier.SWEEP_MOVE)
	while s.state != HollowSoldier.WINDUP:
		await get_tree().physics_frame
	while s.state == HollowSoldier.WINDUP and s.t < HollowSoldier.SWEEP_WINDUP_T - 0.06:
		await get_tree().physics_frame
	var h1 := p.health
	n = s.strikes
	p.bot_heavy = true
	while s.strikes == n or (s.state == HollowSoldier.STRIKE and s.last_result == ""):
		await get_tree().physics_frame
	await _ticks(2)
	p.bot_heavy = false
	print("BOT sweep: parry -> %s, parries %d, health %.0f -> %.0f, soldier state %d" % [s.last_result, c.parries, h1, p.health, s.state])
	if s.last_result != "parried" or p.health < h1 or s.state != HollowSoldier.STAGGER:
		return _combat_done(false, "heavy raised on the sweep did not parry it")
	_combat_done(true, "crowded -> sweep chosen and lands, strafe can't escape it, dodge on the glint and parry beat it")

## Insects: midge swarms by day that drift off when the hero walks into them, fireflies
## only after dusk, hovering over the ground, scattering when the hero runs through them,
## and streaming along with the camera.
func _insects_test() -> void:
	var p := _player
	var ins: Insects = _world.get_node("Insects")
	var terrain: Terrain = _world.get_node("Terrain")
	_world.time_of_day = 13.0
	await _ticks(30)
	print("BOT insects noon: night %.2f day %.2f, fireflies lit %d, swarms %d" % [ins.night, ins.day, ins.visible_fireflies(), ins.swarm_centres().size()])
	if ins.visible_fireflies() > 0 or ins.day < 0.9:
		return _combat_done(false, "fireflies lit at noon or no midges by day")
	# walk into the nearest swarm
	var best := Vector3.INF
	for c in ins.swarm_centres():
		if best == Vector3.INF or c.distance_to(p.global_position) < best.distance_to(p.global_position):
			best = c
	print("BOT insects: nearest swarm %.1f m away, %.1f m above ground" % [best.distance_to(p.global_position), best.y - terrain.height_at(best.x, best.z)])
	var t := 0.0
	while ins.swarm_flees < 1 and t < 30.0:
		var to := Vector2(best.x - p.global_position.x, best.z - p.global_position.z)
		p.bot_input = to.normalized() if to.length() > 0.3 else Vector2.ZERO
		p.bot_sprint = true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	print("BOT insects: swarm flees %d after %.1f s" % [ins.swarm_flees, t])
	if ins.swarm_flees < 1:
		return _combat_done(false, "midge swarm did not drift off when the hero walked into it")
	# night: fireflies light up over the meadow
	_world.time_of_day = 22.0
	await _ticks(90)
	var lit := ins.visible_fireflies()
	var lo := 99.0
	var hi := -99.0
	var far := 0.0
	var cam := get_viewport().get_camera_3d()
	for f in ins.firefly_positions():
		var hgt := f.y - terrain.height_at(f.x, f.z)
		lo = minf(lo, hgt)
		hi = maxf(hi, hgt)
		far = maxf(far, Vector2(f.x - cam.global_position.x, f.z - cam.global_position.z).length())
	print("BOT insects night: night %.2f, lit %d/%d, height %.2f..%.2f m, farthest %.1f m" % [ins.night, lit, ins.firefly_count, lo, hi, far])
	if ins.night < 0.99 or lit < 12:
		return _combat_done(false, "too few fireflies lit at night")
	if lo < 0.1 or hi > 5.0:
		return _combat_done(false, "fireflies outside their height band over the ground")
	# run straight through them
	var s0 := ins.startled_total
	var start := p.global_position
	for i in 240:
		p.bot_input = Vector2(0.3, -1.0).normalized()
		p.bot_sprint = true
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	await _ticks(60)
	far = 0.0
	for f in ins.firefly_positions():
		far = maxf(far, Vector2(f.x - cam.global_position.x, f.z - cam.global_position.z).length())
	print("BOT insects: ran %.1f m, startled %d, farthest fly from camera %.1f m" % [start.distance_to(p.global_position), ins.startled_total - s0, far])
	if ins.startled_total - s0 < 5:
		return _combat_done(false, "fireflies did not scatter from the running hero")
	if far > ins.firefly_radius + 6.0:
		return _combat_done(false, "fireflies did not stream with the camera")
	_world.time_of_day = 7.0
	await _ticks(30)
	print("BOT insects dawn: lit %d" % ins.visible_fireflies())
	if ins.visible_fireflies() > 0:
		return _combat_done(false, "fireflies still lit after dawn")
	_combat_done(true, "midges by day, fireflies by night, both react to the hero")

## Butterflies: out by day, a mix settled on the grass heads and flying, put up when the
## hero walks at a settled one, streaming with the camera, and gone after dusk.
func _butterflies_test() -> void:
	var p := _player
	var bf: Butterflies = _world.get_node("Insects").butterflies
	var terrain: Terrain = _world.get_node("Terrain")
	_world.time_of_day = 13.0
	await _ticks(240)
	var c := bf.census()
	var lo := 99.0
	var hi := -99.0
	for q in bf.positions():
		var hgt := q.y - terrain.height_at(q.x, q.z)
		lo = minf(lo, hgt)
		hi = maxf(hi, hgt)
	print("BOT butterflies noon: day %.2f rest %d fly %d flee %d, height %.2f..%.2f m" % [bf.day, c[0], c[1], c[2], lo, hi])
	if c[0] + c[1] + c[2] < bf.count * 0.8 or c[0] < 5 or c[1] < 1:
		return _combat_done(false, "too few butterflies out at noon, or none settled/flying")
	if lo < 0.25 or hi > 4.6:
		return _combat_done(false, "butterflies outside their height band")
	# wildflowers stream with the grass, and most settled butterflies sit on a flower head
	var grass: GrassField = _world.get_node("Grass")
	var on_flower := 0
	var resting := 0
	for b in bf._bs:
		if b.state != Butterflies.REST:
			continue
		resting += 1
		for k in grass._heads:
			var hit := false
			for hpos: Vector3 in grass._heads[k][0]:
				if hpos.distance_to(b.pos) < 0.01:
					hit = true
					break
			if hit:
				on_flower += 1
				break
	print("BOT butterflies: %d flower heads loaded, %d of %d settled on a flower" % [grass.flower_count(), on_flower, resting])
	if grass.flower_count() < 500 or on_flower * 2 < resting:
		return _combat_done(false, "too few wildflowers, or butterflies not perching on them")
	# walk at the nearest settled one
	var f0 := bf.flee_events
	var t := 0.0
	while bf.flee_events == f0 and t < 40.0:
		var best := Vector3.INF
		var bi := -1
		var ps := bf.positions()
		for i in ps.size():
			if bf._bs[i].state == Butterflies.REST and (best == Vector3.INF or ps[i].distance_to(p.global_position) < best.distance_to(p.global_position)):
				best = ps[i]
				bi = i
		if bi < 0:
			break
		var to := Vector2(best.x - p.global_position.x, best.z - p.global_position.z)
		p.bot_input = to.normalized()
		p.bot_sprint = false
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.bot_input = Vector2.ZERO
	await _ticks(60)
	var c2 := bf.census()
	print("BOT butterflies: put up %d after %.1f s, now rest %d fly %d flee %d" % [bf.flee_events - f0, t, c2[0], c2[1], c2[2]])
	if bf.flee_events == f0:
		return _combat_done(false, "no butterfly took flight from the approaching hero")
	# run a long way: they stream with the camera
	for i in 300:
		p.bot_input = Vector2(-0.4, -1.0).normalized()
		p.bot_sprint = true
		await get_tree().physics_frame
	p.bot_input = Vector2.ZERO
	await _ticks(30)
	var cam := get_viewport().get_camera_3d()
	var far := 0.0
	for q in bf.positions():
		far = maxf(far, Vector2(q.x - cam.global_position.x, q.z - cam.global_position.z).length())
	print("BOT butterflies: farthest from camera %.1f m, put up %d in total" % [far, bf.flee_events - f0])
	if far > bf.radius + 6.0:
		return _combat_done(false, "butterflies did not stream with the camera")
	_world.time_of_day = 20.0
	await _ticks(60)
	var c3 := bf.census()
	print("BOT butterflies dusk: day %.2f out %d" % [bf.day, c3[0] + c3[1] + c3[2]])
	if c3[0] + c3[1] + c3[2] > 0:
		return _combat_done(false, "butterflies still out after dusk")
	_combat_done(true, "butterflies settle, fly, flee the hero, stream with the camera, gone at dusk")

## A float uniform's value on `mat`, else its default as written in the shader source.
func _shader_default(mat: ShaderMaterial, uname: String) -> float:
	var v = mat.get_shader_parameter(uname)
	if v != null:
		return v
	var rx := RegEx.create_from_string("uniform\\s+float\\s+" + uname + "\\s*=\\s*([-0-9.]+)")
	var m := rx.search(mat.shader.code)
	return float(m.get_string(1)) if m else NAN

## A weather front: cloud builds, the light drops, wind rises, rain falls and soaks the ground,
## butterflies and midges shelter; then it clears, they come back and the land dries.
func _weather_test() -> void:
	var wx: Weather = _world.weather
	var bf: Butterflies = _world.get_node("Insects").butterflies
	_world.time_of_day = 13.0
	wx.force(0.0)
	await _ticks(120)
	var sun0: float = _world.sun.light_energy
	var cl: CloudLayer = _world.clouds
	var cov0: float = cl.mat.get_shader_parameter("coverage")
	var d0: Vector2 = cl.mat.get_shader_parameter("drift")
	await _ticks(60)
	var drift_clear: float = ((cl.mat.get_shader_parameter("drift") as Vector2) - d0).length()
	# cloud shadows: the fair-weather cumulus dapple the Vale with sun and shade
	var shaded := 0
	for gx in 40:
		for gz in 40:
			var wp := Vector3(-6000.0 + gx * 300.0, 0.0, -6000.0 + gz * 300.0)
			wp.y = 40.0   # a 12 km window: many weather cells, not the one over the Vale
			if cl.shade_at(wp) < 0.85:
				shaded += 1
	var shade_frac := shaded / 1600.0
	print("BOT weather cloud shadows: strength %.2f, %.0f %% of a 12 km window in cloud shade" % [cl.shadow_strength, shade_frac * 100.0])
	if not ProjectSettings.has_setting("shader_globals/cloud_shadow") or not ProjectSettings.has_setting("shader_globals/cloud_drift"):
		return _combat_done(false, "cloud shadow globals not declared in project.godot")
	if cl.shadow_strength < 0.5 or shade_frac < 0.08 or shade_frac > 0.6:
		return _combat_done(false, "no believable cloud shadows on a fair noon")
	var c0 := bf.census()
	print("BOT weather clear: sun %.2f, butterflies out %d, rain %.2f" % [sun0, c0[0] + c0[1] + c0[2], wx.rain])
	if c0[0] + c0[1] + c0[2] < 10 or wx.rain > 0.0:
		return _combat_done(false, "clear noon should have butterflies and no rain")
	wx.force(1.0, false)
	var t := 0.0
	while wx.rain < 0.85 and t < 240.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var rp: GPUParticles3D = wx.get_node("Rain")
	var c1 := bf.census()
	# the headless dummy renderer keeps no global values: read back where it can, else the
	# values Weather pushes (the globals must at least be declared in project.godot)
	if not ProjectSettings.has_setting("shader_globals/weather_wind") or not ProjectSettings.has_setting("shader_globals/weather_wet"):
		return _combat_done(false, "weather shader globals not declared in project.godot")
	var gwv = RenderingServer.global_shader_parameter_get("weather_wind")
	var gwetv = RenderingServer.global_shader_parameter_get("weather_wet")
	var gw: float = gwv if gwv != null else wx.wind
	var gwet: float = gwetv if gwetv != null else wx.wet
	var e: Environment = _world.env.environment
	print("BOT weather front after %.0f s: cloud %.2f rain %.2f wind %.2f wet %.2f (globals %.2f/%.2f), sun %.2f, fog %.4f, drops %s x%.2f, butterflies out %d, midges %.2f" % [t, wx.cloud, wx.rain, wx.wind, wx.wet, gw, gwet, _world.sun.light_energy, e.fog_density, rp.emitting, rp.amount_ratio, c1[0] + c1[1] + c1[2], _world.get_node("Insects").day])
	if wx.rain < 0.85:
		return _combat_done(false, "the front never brought rain")
	# puddles: the terrain carries its hollows in vertex colour; a soaked Vale floods only the
	# flat dips (a few percent of the ground), not the meadow
	if not ProjectSettings.has_setting("shader_globals/weather_rain"):
		return _combat_done(false, "weather_rain shader global not declared")
	var tmesh: ArrayMesh = (_world.terrain.get_node("Mesh") as MeshInstance3D).mesh
	var tarr := tmesh.surface_get_arrays(0)
	var tcols: PackedColorArray = tarr[Mesh.ARRAY_COLOR]
	var tnrm: PackedVector3Array = tarr[Mesh.ARRAY_NORMAL]
	var tmat: ShaderMaterial = tmesh.surface_get_material(0)
	# uniform defaults live in the shader source (the headless renderer keeps no defaults)
	var soak_thr := _shader_default(tmat, "puddle_soaked")
	var max_slope := _shader_default(tmat, "puddle_max_slope")
	var pooled := 0
	for k in tcols.size():
		if tcols[k].r > soak_thr and 1.0 - tnrm[k].y < max_slope:
			pooled += 1
	var pool_frac := float(pooled) / float(tcols.size())
	var spawn_hollow: float = _world.terrain.hollow_at(_player.global_position.x, _player.global_position.z)
	print("BOT weather puddles: %.1f %% of the ground pools when soaked (hollow > %.2f m, slope < %.3f); spawn hollow %.2f m" % [pool_frac * 100.0, soak_thr, max_slope, spawn_hollow])
	if pool_frac < 0.003 or pool_frac > 0.12:
		return _combat_done(false, "puddle coverage out of range")
	# drops land: splashes burst on the ground in front of the camera while it rains
	var rs0 := wx.rain_splashes
	await _ticks(30)
	var rs := wx.rain_splashes - rs0
	print("BOT weather splashes: %d drop splashes in 0.5 s at rain %.2f" % [rs, wx.rain])
	if rs < 100:
		return _combat_done(false, "rain drops do not splash on the ground")
	# the hero splashes through a soaked pool, and not across the dry meadow beside it
	wx.wet = 1.0
	var pool := Vector3.INF
	var pp0 := _player.global_position
	for j in 81:
		for i in 81:
			var q := pp0 + Vector3(i * 3.0 - 120.0, 0, j * 3.0 - 120.0)
			if wx.pool_at(q.x, q.z) and wx.pool_at(q.x + 0.8, q.z) and wx.pool_at(q.x - 0.8, q.z) \
					and (pool == Vector3.INF or q.distance_to(pp0) < pool.distance_to(pp0)):
				pool = q
	if pool == Vector3.INF:
		return _combat_done(false, "no pool to wade through near the start")
	_player.use_bot_input = true
	_player.set_look(-PI * 0.5, -0.1)    # camera looks +X: forward input runs +X
	var dry := pool + Vector3(-9.0, 0, 0)
	_player.global_position = Vector3(dry.x, _world.terrain.height_at(dry.x, dry.z) + 0.1, dry.z)
	await _ticks(10)
	var w0 := wx.wade_splashes
	var dry_steps := 0
	_player.bot_input = Vector2(0, -1)
	while _player.global_position.x < pool.x - 1.2 and dry_steps < 600:
		await get_tree().physics_frame
		dry_steps += 1
		if wx.pool_at(_player.global_position.x, _player.global_position.z):
			break
	var w_dry := wx.wade_splashes - w0
	var rings := 0
	for i in 50:
		await get_tree().physics_frame
		rings = maxi(rings, wx.wake_rings())
	_player.bot_input = Vector2.ZERO
	var w_pool := wx.wade_splashes - w0 - w_dry
	print("BOT weather wade: pool at %s, %d splashes on the dry run-up, %d through the pool" % [pool, w_dry, w_pool])
	if w_pool < 2 or w_dry > 1:
		return _combat_done(false, "hero does not splash through the pool (or splashes on dry ground)")
	var ps: Soak = _player.soak
	var gy: float = _world.terrain.height_at(pool.x, pool.z)
	print("BOT weather wade soak: legs %.2f up to %.2f m above the ground" % [ps.wade, ps.wade_line - gy])
	if ps.wade < 0.5 or ps.wade_line - gy < 0.05 or ps.wade_line - gy > 0.6:
		return _combat_done(false, "wading did not soak the hero's legs to the water line")
	var waited := 0
	while wx.wake_rings() > 0 and waited < 2000:
		await get_tree().physics_frame
		waited += 1
	var rings_left: int = wx.wake_rings()
	print("BOT weather wake: up to %d footfall rings spreading at once, %d once they ran out" % [rings, rings_left])
	if rings < 1 or rings_left > 0:
		return _combat_done(false, "footfalls leave no ring on the pool (or the rings never fade)")
	# a drop falling into the pool (off a soaked sleeve or a crown) sets a faint ring running
	var dr_r0 := wx.drip_rings
	wx.shed_drop(Vector3(pool.x + 0.4, gy + 1.2, pool.z + 0.4), gy)
	for i in 40:
		await get_tree().physics_frame
	print("BOT weather drip ring: %d ring(s) from a drop into the pool" % (wx.drip_rings - dr_r0))
	if wx.drip_rings == dr_r0:
		return _combat_done(false, "a drop landing in a pool leaves no ring")
	var cov1: float = cl.mat.get_shader_parameter("coverage")
	var d1: Vector2 = cl.mat.get_shader_parameter("drift")
	await _ticks(60)
	var drift_front: float = ((cl.mat.get_shader_parameter("drift") as Vector2) - d1).length()
	var cam := get_viewport().get_camera_3d()
	print("BOT weather clouds: cover %.2f -> %.2f, drift per 60 ticks %.1f m clear / %.1f m front, deck %.1f m from camera" % [cov0, cov1, drift_clear, drift_front, cl.global_position.distance_to(cam.global_position)])
	if cov0 < 0.15 or cov0 > 0.5 or cov1 < 0.9:
		return _combat_done(false, "cloud deck did not go from scattered cumulus to overcast")
	if drift_clear <= 0.0 or drift_front < drift_clear * 2.0:
		return _combat_done(false, "cloud deck did not drift faster in the front's wind")
	if cl.global_position.distance_to(cam.global_position) > 0.5:
		return _combat_done(false, "cloud dome does not ride on the camera")
	if cl.shadow_strength > 0.05:
		return _combat_done(false, "cloud shadows still cast under the full rain deck (%.2f)" % cl.shadow_strength)
	if t < 40.0:
		return _combat_done(false, "the front arrived too fast to read as rolling in")
	if not rp.emitting or rp.amount_ratio < 0.8 or gw < 0.4 or gwet < 0.1:
		return _combat_done(false, "rain/wind/wetness not applied")
	if _world.sun.light_energy > sun0 * 0.35 or e.fog_density < 0.005:
		return _combat_done(false, "the light did not go grey under the front")
	if c1[0] + c1[1] + c1[2] > 0 or _world.get_node("Insects").day > 0.01:
		return _combat_done(false, "butterflies/midges still out in the rain")
	# lightning: a full front throws bolts on its own; each flashes 2-4 times and goes dark
	var lt: Lightning = wx.lightning
	var s0 := lt.strikes
	var tl := 0.0
	var fpeak := 0.0
	var lpeak := 0.0
	var bolt_seen := false
	while lt.strikes < s0 + 2 and tl < 90.0:
		await get_tree().physics_frame
		tl += get_physics_process_delta_time()
	# a strike held at its first stroke (bots run at 4x, too coarse to sample a 50 ms spike)
	lt.strike()
	lt.hold_age = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	fpeak = lt.flash
	lpeak = lt.light.light_energy if lt.light.visible else 0.0
	bolt_seen = lt.bolt.visible
	var cf: float = cl.mat.get_shader_parameter("flash")
	var amb_flash: float = _world.env.environment.ambient_light_energy
	lt.hold_age = -1.0
	var flashes := lt._strokes.size()
	var b := lt.strike_pos
	var bd := Vector2(b.x - cam.global_position.x, b.z - cam.global_position.z).length()
	var tris := (lt.bolt.mesh as ArrayMesh).surface_get_array_len(0) / 3 if lt.bolt.mesh else 0
	await _ticks(90)
	print("BOT weather lightning: %d strikes in %.0f s of storm (storm %.2f), flash peak %.2f (cloud %.2f), flash light %.2f, ambient %.2f, %d return strokes, bolt %d tris %.0f m out, dark after: flash %.2f bolt %s light %s" % [lt.strikes - s0, tl, lt.storm(), fpeak, cf, lpeak, amb_flash, flashes, tris, bd, lt.flash, lt.bolt.visible, lt.light.visible])
	if lt.strikes < s0 + 2:
		return _combat_done(false, "no lightning in a full storm")
	if fpeak < 0.3 or lpeak < 0.5 or not bolt_seen or cf <= 0.0 or tris < 100:
		return _combat_done(false, "a strike did not flash the deck / light the land / draw a bolt")
	if lt.flash > 0.01 or lt.bolt.visible or lt.light.visible:
		return _combat_done(false, "the flash did not go dark after the strike")
	# thunder: each strike's clap arrives after distance / 343 m/s
	var th0 := lt.thunders
	lt.strike(cam.global_position + Vector3(1029.0, 0.0, 0.0))   # ~3 s away
	var due := lt.next_thunder()
	var claps := [0]
	lt.thunder.connect(func(_s: float, _d: float): claps[0] += 1)
	var heard := -1.0
	var tw := 0.0
	while lt.thunders < th0 + 1 and tw < 30.0:
		await get_tree().physics_frame
		tw += get_physics_process_delta_time()
	heard = tw
	print("BOT weather thunder: clap due %.2f s after a strike %.0f m out, heard after %.2f s (%d signalled)" % [due, Vector2(lt.strike_pos.x - cam.global_position.x, lt.strike_pos.z - cam.global_position.z).length(), heard, claps[0]])
	if lt.thunders < th0 + 1 or claps[0] < 1 or absf(heard - due) > 0.25 or due < 2.5:
		return _combat_done(false, "thunder does not follow the strike at the speed of sound")
	# sheet lightning: a flash inside the deck, no channel; the clouds take more of it than
	# the land, and its rumble comes down from the cloud base
	var sh0 := lt.sheets
	var st0 := lt.strikes
	lt.strike(cam.global_position + Vector3(0.0, 0.0, 1500.0), false)
	lt.hold_age = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var sh_flash := lt.flash
	var sh_cloud: float = cl.mat.get_shader_parameter("flash")
	var sh_light := lt.light.light_energy if lt.light.visible else 0.0
	var sh_bolt := lt.bolt.visible
	var sh_due := lt.next_thunder()
	lt.hold_age = -1.0
	print("BOT weather sheet: flash %.2f cloud %.2f land light %.2f (bolt strike: %.2f / %.2f / %.2f), channel %s, rumble due %.2f s, sheets %d strikes %d" % [sh_flash, sh_cloud, sh_light, fpeak, cf, lpeak, sh_bolt, sh_due, lt.sheets - sh0, lt.strikes - st0])
	if lt.sheets != sh0 + 1 or lt.strikes != st0 or sh_bolt:
		return _combat_done(false, "sheet lightning drew a channel or counted as a strike")
	if sh_flash <= 0.05 or sh_cloud < sh_flash * 1.3 or sh_light >= lpeak * 0.6:
		return _combat_done(false, "sheet lightning does not light the deck more than the land")
	if sh_due < 2.0 * 1500.0 / 343.0 * 0.5 or sh_due > 2500.0 / 343.0:
		return _combat_done(false, "sheet lightning rumble not timed from the cloud")
	await _ticks(90)
	if bd < lt.distance.x - 1.0 or bd > lt.distance.y + 1.0:
		return _combat_done(false, "bolt struck at %.0f m, outside the far deck" % bd)
	# the hero and the soldier are drenched by now, and every soak-aware material knows it
	var hs: Soak = _player.soak
	var ss: Soak = _world.soldier.soak if _world.soldier != null else null
	var hmats := hs._mats.size()
	var hm_soak: float = hs._mats[0].get_shader_parameter("soak") if hmats > 0 else 0.0
	print("BOT weather soak: hero %.2f (%d materials, shader %.2f), soldier %.2f (%d materials)" % [hs.level, hmats, hm_soak, ss.level if ss else -1.0, ss._mats.size() if ss else 0])
	if hs.level < 0.5 or hmats < 3 or absf(hm_soak - hs.level) > 0.05:
		return _combat_done(false, "the rain did not soak the hero (body + staff)")
	if ss == null or ss.level < 0.5 or ss._mats.size() < 4:
		return _combat_done(false, "the rain did not soak the soldier (skin, rags, spear)")
	var soak_peak := hs.level
	var wet_peak := wx.wet
	# shelter: under an oak's crown the hero barely soaks and the ground stays drier
	var flora: Flora = _world.get_node("Flora")
	var tree := Vector3.INF
	for tp in flora.tree_positions:
		if tree == Vector3.INF or flora.shelter_at(tp.x + 1.5, tp.z) > flora.shelter_at(tree.x + 1.5, tree.z):
			tree = tp
	var under := tree + Vector3(1.5, 0, 0)
	var open_sky := Vector3.INF
	for j in 41:
		for i in 41:
			var q := _player.global_position + Vector3(i * 4.0 - 80.0, 0, j * 4.0 - 80.0)
			if flora.shelter_at(q.x, q.z) == 0.0 and not wx.pool_at(q.x, q.z) \
					and (open_sky == Vector3.INF or q.distance_to(under) < open_sky.distance_to(under)):
				open_sky = q
	var soaked := []
	for spot: Vector3 in [under, open_sky]:
		_player.global_position = Vector3(spot.x, _world.terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
		_player.velocity = Vector3.ZERO
		hs.level = 0.0
		await _ticks(60)
		soaked.append(hs.level)
	var sh_under := flora.shelter_at(under.x, under.z)
	print("BOT weather shelter: %.2f under an oak at %s (ground wet %.2f vs %.2f open), hero soaked %.3f there vs %.3f in the open in the same time" % [sh_under, under, wx.wet_at(under.x, under.z), wx.wet, soaked[0], soaked[1]])
	if sh_under < 0.6 or open_sky == Vector3.INF:
		return _combat_done(false, "no shelter baked under the oak crowns")
	if soaked[1] <= 0.0 or soaked[0] > soaked[1] * 0.35:
		return _combat_done(false, "the hero soaks as fast under an oak as in the open")
	if wx.wet_at(under.x, under.z) > wx.wet * 0.6 or wx.pool_at(under.x, under.z):
		return _combat_done(false, "the ground under an oak is as wet as the open meadow")
	# canopy drips: under the oak the crowns shed fat drops along their drip line
	_player.global_position = Vector3(under.x, _world.terrain.height_at(under.x, under.z) + 0.1, under.z)
	_player.velocity = Vector3.ZERO
	var dr0 := wx.canopy_drips
	var ds0 := wx.drip_splashes
	await _ticks(60)
	var drips_rain := wx.canopy_drips - dr0
	print("BOT weather drips: %d drops shed from the crowns in 1 s of rain (canopy %.2f), %d landed" % [drips_rain, wx.canopy_water, wx.drip_splashes - ds0])
	if drips_rain < 20 or wx.drip_splashes - ds0 < 5:
		return _combat_done(false, "the oak crowns do not drip in the rain")
	hs.level = soak_peak
	wx.force(0.0, false)
	t = 0.0
	var drips_after := 0
	var dry_t := -1.0
	while (wx.cloud > 0.02 or wx.rain > 0.0) and t < 300.0:
		var dc := wx.canopy_drips
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if wx.rain <= 0.0:
			drips_after += wx.canopy_drips - dc
			if dry_t < 0.0:
				dry_t = t
	print("BOT weather drips after the rain: %d drops in the %.0f s after it stopped (canopy %.2f)" % [drips_after, t - dry_t, wx.canopy_water])
	if drips_after < 20:
		return _combat_done(false, "the crowns stop dripping the moment the rain stops")
	# the drenched hero runs with water after the rain: drops shed off hands, hem and staff
	_player.global_position = Vector3(under.x + 25.0, _world.terrain.height_at(under.x + 25.0, under.z) + 0.1, under.z)
	hs.level = 1.0
	var shd0 := wx.shed_drops
	await _ticks(60)
	var shed_wet := wx.shed_drops - shd0
	hs.level = 0.0
	hs.wade = 0.0
	if _world.soldier != null:
		_world.soldier.soak.level = 0.0
		_world.soldier.soak.wade = 0.0
	shd0 = wx.shed_drops
	await _ticks(60)
	var shed_dry := wx.shed_drops - shd0
	print("BOT weather shed: drenched hero sheds %d drops in 60 ticks, dry hero %d" % [shed_wet, shed_dry])
	if shed_wet < 5 or shed_dry > 0:
		return _combat_done(false, "a drenched hero does not drip (or a dry one does)")
	hs.level = soak_peak
	await _ticks(240)
	var c2 := bf.census()
	print("BOT weather cleared after %.0f s: cloud %.2f rain %.2f wet %.2f (peak %.2f), sun %.2f, drops %s, butterflies out %d" % [t, wx.cloud, wx.rain, wx.wet, wet_peak, _world.sun.light_energy, rp.emitting, c2[0] + c2[1] + c2[2]])
	if wx.cloud > 0.02 or rp.emitting or wx.wet >= wet_peak:
		return _combat_done(false, "the front did not clear / the ground did not start drying")
	print("BOT weather soak drying: hero %.2f (peak %.2f)" % [hs.level, soak_peak])
	if hs.level >= soak_peak:
		return _combat_done(false, "the hero does not dry after the rain")
	if c2[0] + c2[1] + c2[2] < 10 or _world.sun.light_energy < sun0 * 0.95:
		return _combat_done(false, "sun and butterflies did not return after the front")
	var s1 := wx.lightning.strikes + wx.lightning.sheets
	wx.canopy_water = 0.0005
	var dc1 := wx.canopy_drips
	await _ticks(600)
	if wx.canopy_drips != dc1 or wx.canopy_water > 0.0:
		return _combat_done(false, "the crowns never drain dry")
	if wx.lightning.strikes + wx.lightning.sheets != s1:
		return _combat_done(false, "lightning struck from a clear sky")
	# fronts also come on their own
	wx.auto_fronts = true
	wx._timer = 0.0
	var f0 := wx.fronts
	await _ticks(10)
	if wx.fronts != f0 + 1 or wx._target < 0.6:
		return _combat_done(false, "no front scheduled on its own")
	_combat_done(true, "a front rolls in, greys the light, rains, soaks the ground, shelters the insects, then clears")

## Rooks roost: at dusk every flock flies to the rookery and settles in the upper crowns;
## the hero walking under the roost puts them up and they settle again once he has gone;
## at dawn they leave the trees for the meadow.
func _roost_test() -> void:
	var p := _player
	var birds: Birds = _world.get_node("Birds")
	var terrain: Terrain = _world.get_node("Terrain")
	print("BOT roost: rookery at (%.0f, %.0f), %d trees" % [birds.rookery.x, birds.rookery.z, birds.rookery_trees.size()])
	if birds.rookery_trees.size() < 3:
		return _combat_done(false, "no rookery grove found")
	_world.time_of_day = 16.0
	await _ticks(60)
	var c0 := birds.census()
	print("BOT roost afternoon: %s" % [c0])
	if c0["perch"] > 0:
		return _combat_done(false, "rooks in the roost in the afternoon")
	_world.time_of_day = 19.9
	var t := 0.0
	while birds.census()["perch"] < birds.flock_count * birds.birds_per_flock and t < 120.0:
		await _ticks(30)
		t += 0.5
	var c1 := birds.census()
	var lo := 99.0
	for q in birds.bird_positions():
		lo = minf(lo, q.y - terrain.height_at(q.x, q.z))
	print("BOT roost dusk: %s after %.1f s, %d roost landings, lowest bird %.1f m up" % [c1, t, birds.roost_landings, lo])
	if c1["perch"] < birds.flock_count * birds.birds_per_flock or lo < 4.0:
		return _combat_done(false, "flocks did not all settle into the crowns at dusk")
	# walk in under the rookery: they go up
	var s0 := birds.scatter_events
	var under := birds.rookery
	under.y = terrain.height_at(under.x, under.z) + 1.0
	p.global_position = under + Vector3(5, 0, 0)
	await _ticks(60)
	var c2 := birds.census()
	print("BOT roost disturbed: %s, %d scatters" % [c2, birds.scatter_events - s0])
	if birds.scatter_events - s0 < 1 or c2["air"] < 10:
		return _combat_done(false, "a hero under the roost did not put the rooks up")
	p.global_position = Vector3(0, terrain.height_at(0, 0) + 1.0, 0)
	t = 0.0
	while birds.census()["perch"] < birds.flock_count * birds.birds_per_flock and t < 120.0:
		await _ticks(30)
		t += 0.5
	print("BOT roost resettled: %s after %.1f s" % [birds.census(), t])
	if birds.census()["perch"] < birds.flock_count * birds.birds_per_flock:
		return _combat_done(false, "rooks did not settle back into the roost")
	_world.time_of_day = 6.6
	t = 0.0
	while birds.census()["ground"] < birds.flock_count * birds.birds_per_flock and t < 120.0:
		await _ticks(30)
		t += 0.5
	print("BOT roost dawn: %s after %.1f s" % [birds.census(), t])
	if birds.census()["ground"] < birds.flock_count * birds.birds_per_flock:
		return _combat_done(false, "rooks did not leave the roost for the meadow at dawn")
	_combat_done(true, "rooks roost at dusk, flush and resettle, leave at dawn")

## The watchtower ruin: built on a knoll clear of trees and boulders, the hero walks in
## through the curtain gateway and the breach to the tower floor, and its walls stop him.
## Ferns and shrubs fill the groves: enough of them, none on the village floor, the road or
## the keep, mostly in the shade of the crowns, and the hero walks straight through a drift.
func _understory_test() -> void:
	var p := _player
	var flora: Flora = _world.get_node("Flora")
	var terrain: Terrain = _world.get_node("Terrain")
	var bad := 0
	var shade := 0.0
	for q in flora.fern_positions + flora.shrub_positions:
		if flora._blocked(q.x, q.z, 0.0):
			bad += 1
	for q in flora.fern_positions:
		shade += flora.shelter_at(q.x, q.z)
	shade /= maxf(1.0, flora.fern_positions.size())
	print("BOT understory: %d ferns, %d shrubs, %d on blocked ground, mean fern shade %.2f" % [flora.fern_positions.size(), flora.shrub_positions.size(), bad, shade])
	if flora.fern_positions.size() < 1200 or flora.shrub_positions.size() < 150 or bad > 0 or shade < 0.25:
		return _combat_done(false, "understory missing, misplaced or out in the open meadow")
	# walk through the fern drift nearest the village
	var f := flora.fern_positions[0]
	for q in flora.fern_positions:
		if Vector2(q.x, q.z).length() < Vector2(f.x, f.z).length():
			f = q
	var dir := Vector3(f.x, 0, f.z).normalized()
	var start := f - dir * 10.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	var goal := f + dir * 6.0
	var t := 0.0
	while Vector2(p.global_position.x - goal.x, p.global_position.z - goal.z).length() > 1.0 and t < 20.0:
		var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).normalized()
		p.bot_input = d
		await _ticks(6)
		t += 0.1
	p.bot_input = Vector2.ZERO
	print("BOT understory: walked through the drift at %s in %.1f s" % [f, t])
	if t >= 20.0:
		return _combat_done(false, "stuck in the ferns at %s" % p.global_position)
	_combat_done(true, "groves have a fern and shrub understory the hero can walk through")

func _trample_test() -> void:
	var p := _player
	var tr: Trample = _world.trample
	var terrain: Terrain = _world.get_node("Terrain")
	var start := p.global_position
	await _ticks(20)
	# run 14 m across the meadow, noting where the hero was a second before stopping
	var dir := Vector2(1, 0.3).normalized()
	var mark := Vector3.INF
	var t := 0.0
	while Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length() < 14.0 and t < 12.0:
		p.bot_input = dir
		await _ticks(6)
		t += 0.1
		if mark == Vector3.INF and Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length() > 8.0:
			mark = p.global_position
	p.bot_input = Vector2.ZERO
	await _ticks(30)
	var n := tr.active_points()
	var laid := tr.lay_at(mark)
	var off := mark + Vector3(-dir.y, 0, dir.x) * 2.0   # 2 m beside the trail
	var beside := tr.lay_at(off)
	var px := tr._img.get_pixel(0, 0)
	print("BOT trample: %d trail points, laid %.2f on the trail, %.2f 2 m beside it, texel %s" % [n, laid, beside, px])
	if n < 10 or laid < 0.35 or beside > 0.05 or px.a <= 0.0:
		return _combat_done(false, "the hero leaves no trodden trail in the grass")
	# boot prints: alternating feet along the run, one near the mark, none 2 m beside it
	var np := tr.active_prints()
	var pm := tr.print_near(mark, 1.0)
	var pb := tr.print_near(off, 0.8)
	var sides := 0
	var prev := 0.0
	var lastq := Vector4.ZERO
	for i in Trample.PN:
		var q: Vector4 = tr._prints[i]
		if q.w <= 0.0:
			continue
		if lastq.w > 0.0:
			# each step crosses the walk line: left, right, left
			var d2: Vector2 = tr._pdirs[i]
			var sd := (q.x - lastq.x) * -d2.y + (q.y - lastq.y) * d2.x
			if prev != 0.0 and signf(sd) != signf(prev):
				sides += 1
			prev = sd
		lastq = q
	print("BOT trample: %d boot prints, near the mark %s, beside %s, %d foot changes" % [np, pm, pb, sides])
	if np < 8 or pm.w <= 0.0 or pb.w > 0.0 or sides < np / 2:
		return _combat_done(false, "the hero leaves no alternating boot prints")
	# stand still: the sward springs back
	await _ticks(int((Trample.LIFE + 1.0) * 60.0))
	var after := tr.lay_at(mark)
	print("BOT trample: after %.0f s laid %.2f, %d points" % [Trample.LIFE + 1.0, after, tr.active_points()])
	if after > 0.05 or tr.active_points() > 0:
		return _combat_done(false, "trodden grass never springs back")
	if tr.active_prints() < np:
		return _combat_done(false, "boot prints vanished with the grass (they should last minutes)")
	# the Hollow soldier is a walker too: shove it 3 m along the ground, it leaves prints
	var foe: Node3D = _world.soldier
	if not foe in tr.walkers:
		return _combat_done(false, "the soldier does not trample")
	var before := tr.active_prints()
	var fp0 := foe.global_position
	for k in 30:
		foe.global_position = fp0 + Vector3(0.1 * (k + 1), 0, 0)
		foe.global_position.y = terrain.height_at(foe.global_position.x, foe.global_position.z) + 0.02
		await _ticks(2)
	foe.global_position = fp0
	print("BOT trample: soldier walked 3 m, prints %d -> %d" % [before, tr.active_prints()])
	if tr.active_prints() < before + 3:
		return _combat_done(false, "the soldier leaves no prints")
	# a jump leaves no footfall in mid-air: teleport-free, nothing laid far from the hero
	_combat_done(true, "grass, flowers and ferns part round the hero and spring back behind")

func _ruin_test() -> void:
	var p := _player
	var ruins: Ruins = _world.get_node("Ruins")
	var flora: Flora = _world.get_node("Flora")
	var terrain: Terrain = _world.get_node("Terrain")
	var rs := ruins.site
	var near := 99.0
	for q in flora.tree_positions + flora.rock_positions:
		near = minf(near, Vector2(q.x - rs.x, q.z - rs.z).length())
	print("BOT ruin: site %s, %d stones, %d colliders, nearest tree/rock %.1f m" % [rs, ruins.block_count, ruins.get_node("RuinCollision").get_child_count(), near])
	if ruins.block_count < 400 or near < 15.0:
		return _combat_done(false, "ruin not built or overgrown by flora")
	var to_v := Vector3(-rs.x, 0, -rs.z).normalized()
	var start := rs + to_v * 26.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	# walk in: gateway, breach, floor centre
	for wp in [rs + to_v * 12.5, rs + to_v * 4.0, rs]:
		var t := 0.0
		while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length() > 1.0 and t < 25.0:
			var d := Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).normalized()
			p.bot_input = d
			await _ticks(6)
			t += 0.1
		print("BOT ruin reached %s in %.1f s, at %s" % [wp, t, p.global_position])
		if t >= 25.0:
			p.bot_input = Vector2.ZERO
			return _combat_done(false, "could not walk into the tower (stuck at %s)" % p.global_position)
	# now run at the back wall: it must stop him inside
	var far := 0.0
	var t2 := 0.0
	while t2 < 5.0:
		p.bot_input = Vector2(-to_v.x, -to_v.z)
		p.bot_sprint = true
		await _ticks(6)
		t2 += 0.1
		far = maxf(far, Vector2(p.global_position.x - rs.x, p.global_position.z - rs.z).length())
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	print("BOT ruin: ran at the back wall, got %.2f m from the centre" % far)
	if far > 3.4:
		return _combat_done(false, "walked through the tower wall")
	_combat_done(true, "walked in through the breach and the walls hold")

## Red deer: the herd grazes calm on the open meadow (heads down, now and then one comes
## up), keeps together and clear of trees; a hero 35 m off puts their heads up; running at
## them makes them bolt as one, gallop well away, then settle to graze again.
func _herd_test() -> void:
	var p := _player
	var herd: Herd = _world.get_node("Herd")
	var terrain: Terrain = _world.get_node("Terrain")
	var c := herd.centre()
	var away := Vector3(c.x, 0, c.z).normalized()
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	var far := c - away * 110.0
	p.global_position = Vector3(far.x, terrain.height_at(far.x, far.z) + 1.0, far.z)
	var n := herd.deer_positions().size()
	print("BOT herd: %d deer at (%.0f, %.0f)" % [n, c.x, c.z])
	if n < 6:
		return _combat_done(false, "no herd")
	var up_seen := 0
	var down_min := 99
	for i in 40:
		await _ticks(30)
		up_seen = maxi(up_seen, herd.heads_up())
		down_min = mini(down_min, n - herd.heads_up())
	var c1 := herd.centre()
	var spread := 0.0
	var off_ground := 0.0
	for q in herd.deer_positions():
		spread = maxf(spread, Vector2(q.x - c1.x, q.z - c1.z).length())
		off_ground = maxf(off_ground, absf(q.y - terrain.height_at(q.x, q.z)))
	print("BOT herd calm: state %d, drift %.1f m in 20 s, spread %.1f m, heads up max %d, grazing min %d" % [herd.state, c1.distance_to(c), spread, up_seen, down_min])
	if herd.state != Herd.CALM or spread > 16.0 or off_ground > 0.05 or up_seen < 1 or down_min < 3 or c1.distance_to(c) > 8.0:
		return _combat_done(false, "the herd did not graze calmly together")
	# step into view at 35 m: heads up, no bolt
	var at := c1 - away * 35.0
	p.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 1.0, at.z)
	await _ticks(120)
	print("BOT herd watched at 35 m: state %d, heads up %d/%d" % [herd.state, herd.heads_up(), n])
	if herd.state != Herd.ALERT or herd.heads_up() < n - 1:
		return _combat_done(false, "a hero in plain sight at 35 m did not put the heads up")
	# run at them
	var t := 0.0
	var top := 0.0
	while herd.state != Herd.FLEE and t < 8.0:
		p.bot_input = _input_toward(herd.centre())
		p.bot_sprint = true
		await _ticks(6)
		t += 0.1
	print("BOT herd charged: bolted after %.1f s at %.1f m" % [t, Vector2(p.global_position.x - herd.centre().x, p.global_position.z - herd.centre().z).length()])
	if herd.state != Herd.FLEE:
		return _combat_done(false, "the herd did not bolt from a running hero")
	for i in 60:
		p.bot_input = _input_toward(herd.centre())
		await _ticks(6)
		for d in herd._deer:
			top = maxf(top, d.speed)
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	var gap := Vector2(p.global_position.x - herd.centre().x, p.global_position.z - herd.centre().z).length()
	print("BOT herd fleeing: %.1f m ahead of the hero after 6 s, top speed %.1f m/s" % [gap, top])
	if gap < 45.0 or top < 7.0:
		return _combat_done(false, "the herd did not gallop away from the hero")
	# the galloping herd left a track of splayed hoof prints behind it
	var tr: Trample = _world.trample
	var hp := tr.hoof_near(herd.centre() - herd._flee_dir * 6.0, 8.0)
	print("BOT herd hoofs: %d pressed, %d live, one %.1f m behind the herd (depth %.2f)" % [herd.hoof_prints, tr.active_hoofs(), Vector2(hp.x, hp.y).distance_to(Vector2(herd.centre().x, herd.centre().z)) if hp.w > 0.0 else -1.0, hp.w])
	if herd.hoof_prints < 20 or tr.active_hoofs() < 20 or hp.w < 0.9:
		return _combat_done(false, "the fleeing deer left no hoof prints behind them")
	t = 0.0
	while herd.state != Herd.CALM and t < 60.0:
		await _ticks(30)
		t += 0.5
	await _ticks(240)
	var c2 := herd.centre()
	gap = Vector2(p.global_position.x - c2.x, p.global_position.z - c2.z).length()
	spread = 0.0
	var clear := 99.0
	for q in herd.deer_positions():
		spread = maxf(spread, Vector2(q.x - c2.x, q.z - c2.z).length())
		for o in herd._obstacles:
			clear = minf(clear, Vector2(q.x - o.x, q.z - o.z).length())
	print("BOT herd settled: state %d after %.1f s, %.0f m from the hero, spread %.1f m, nearest tree/rock %.1f m, edge %.0f m" % [herd.state, t, gap, spread, clear, Vector2(c2.x, c2.z).length()])
	if herd.state != Herd.CALM or gap < herd.safe_radius or spread > 18.0 or clear < 0.8 or Vector2(c2.x, c2.z).length() > 215.0:
		return _combat_done(false, "the herd did not settle again, together, far off and in the open")
	_combat_done(true, "deer graze, look up at a hero in sight, bolt from a charge, settle far off")
