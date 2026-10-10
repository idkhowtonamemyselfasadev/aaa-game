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
	_route = ROUTES.get(name, [] if name in ["combat", "dodge", "soldier", "lockon", "heavy"] else ROUTES["walk"])
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
	print("BOT soldier: fight %.1f s, hits taken %d, staggers %d, health %.0f -> %.0f, dead %s, thrusts %d" % [t, s.hits_taken, s.staggers, hp0, s.health, s.is_dead(), s.strikes])
	if not s.is_dead():
		return _combat_done(false, "the hero could not kill the soldier")
	if s.staggers < 1:
		return _combat_done(false, "soldier never staggered")
	if s.is_in_group("hittable"):
		return _combat_done(false, "dead soldier is still hittable")
	var spear := s.spear
	await _ticks(400)
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
