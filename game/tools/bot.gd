extends Node
## Headless scripted player. Usage (after `--`): <route> [max_seconds]
## Routes are lists of world-space XZ waypoints; the bot steers the Player toward each and
## reports PASS/FAIL. Exit code 0 on pass. Run with: godot --headless res://tools/bot.tscn -- walk

const ROUTES := {
	# walk a loop across the vale: proves terrain collision, slopes and stamina work
	"walk": [Vector2(0, 0), Vector2(40, 10), Vector2(60, -40), Vector2(0, -60), Vector2(-50, -10), Vector2(-24, -12), Vector2(0, 0)],   # (round the south of the white cottage)
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
	_route = ROUTES.get(name, [] if name in ["combat", "dodge", "soldier", "lockon", "heavy", "sweep", "insects", "butterflies", "flinch", "death", "weather", "roost", "ruin", "understory", "trample", "herd", "bed", "shrine", "facelight", "sound", "foley", "mix", "gfx", "keeper", "talk", "hearth", "fox", "cottage", "stonehouse", "whitehouse", "leanto", "waterbutt", "drywall", "yardwall", "hens", "yardpath", "lantern", "villager", "chop", "feed", "eddatalk", "bat", "doorstones", "dog", "neighbour", "greet", "kite", "pedlar", "verge", "rutstones", "henfox"] else ROUTES["walk"])
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
	if name == "sound":
		_sound_test()
		return
	if name == "foley":
		_foley_test()
		return
	if name == "mix":
		_mix_test()
		return
	if name == "gfx":
		_gfx_test()
		return
	if name == "keeper":
		_keeper_test()
		return
	if name == "talk":
		_talk_test()
		return
	if name == "hearth":
		_hearth_test()
		return
	if name == "fox":
		_fox_test()
		return
	if name == "henfox":
		_henfox_test()
		return
	if name == "dog":
		_dog_test()
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
	if name == "kite":
		_kite_test()
		return
	if name == "ruin":
		_ruin_test()
	if name == "cottage":
		_cottage_test()
		return
	if name == "stonehouse":
		_stonehouse_test()
	if name == "whitehouse":
		_stonehouse_test(_world.white_cottage)
		return
	if name == "leanto":
		_leanto_test()
		return
	if name == "lantern":
		_lantern_test()
		return
	if name == "waterbutt":
		_waterbutt_test()
		return
	if name == "drywall":
		_drywall_test()
		return
	if name == "yardwall":
		_yardwall_test()
		return
	if name == "hens":
		_hens_test()
		return
	if name == "yardpath":
		_yardpath_test()
		return
	if name == "rutstones":
		_rutstones_test()
		return
	if name == "verge":
		_verge_test()
		return
	if name == "doorstones":
		_doorstones_test()
		return
	if name == "neighbour":
		_neighbour_test()
		return
	if name == "greet":
		_greet_test()
		return
	if name == "pedlar":
		_pedlar_test()
		return
	if name == "villager":
		_villager_test()
		return
	if name == "eddatalk":
		_eddatalk_test()
		return
	if name == "bat":
		_bat_test()
		return
	if name == "chop":
		_chop_test()
		return
	if name == "feed":
		_feed_test()
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
	if name == "bed":
		_bed_test()
		return
	if name == "moss":
		_moss_test()
		return
	if name == "shrine":
		_shrine_test()
		return
	if name == "facelight":
		_facelight_test()
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
			# the cloth's top (its AABB) is the peak where it rides over the nose bridge, ~5 mm
			# above where it crosses under the eyes either side
			if ok and _route.size() > 0 and (e0.distance_to(e1) < 0.04 or e0.distance_to(e1) > 0.08
					or eye_front < 0.03 or mid.y < veil.end.y - 0.012 or mid.y > hat_box.end.y):
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

## The bat over the green: out only after dark with the lantern burning, hunting the moths
## round it (stoops, catches, misses, moths diving away) without touching the lantern, the
## post or the turf, and gone in a storm and by day.
func _bat_test() -> void:
	var lp: LanternPost = _world.lantern_post
	if lp == null or lp.bat == null:
		return _combat_done(false, "no bat at the lantern")
	var b := lp.bat
	var mo := lp.moths
	var weather: Weather = _world.weather
	weather.force(0.0)
	weather.wind = 0.0
	_world.time_of_day = 12.0
	await _ticks(60)
	var noon := b.state != Bat.ROOST
	var hang_off := b.global_position.distance_to(b.roost_at)
	var noon_y: float = b.global_position.y - _world.terrain.height_at(b.global_position.x, b.global_position.z)
	var wc: WhiteCottage = _world.white_cottage
	var under := WhiteCottage.covers(b.global_position.x, b.global_position.z)
	# a stretch of the wings now and then while it hangs
	b._stretch_in = 0.5
	var st0 := b.stretches
	await _ticks(180)
	var stretched := b.stretches > st0 and b.state == Bat.ROOST
	var grumbled := b.grumbles > 0 and b.calls == 0
	_world.time_of_day = 19.3
	await _ticks(60)
	var dusk := b.state != Bat.ROOST
	print("BOT bat: noon %s at the roost (%.3f m off its hold, %.2f m up, under the woodshed %s), stretched %s, dusk %s" % [b.state, hang_off, noon_y, under, stretched, dusk])
	if noon or hang_off > 0.06 or not under or noon_y < 1.6 or not stretched or wc == null:
		return _combat_done(false, "the bat is not hanging under the woodshed eaves by day")
	_world.time_of_day = 21.5
	var out_at := -1
	var far := 0.0
	var door_by := false
	for i in 240:
		await _ticks(10)
		if (b.state == Bat.PATROL or b.state == Bat.CHASE) and out_at < 0:
			out_at = i
		if b.state == Bat.PATROL or b.state == Bat.CHASE:
			var c := lp.lantern_center()
			far = maxf(far, Vector2(b.global_position.x - c.x, b.global_position.z - c.z).length())
	print("BOT bat: noon %s, dusk %s, out from tick %d0, stoops %d, catches %d (moths eaten %d), misses %d, moth dives %d" % [noon, dusk, out_at, b.stoops, b.catches, mo.eaten, b.misses, mo.dodges])
	print("BOT bat: nearest the lantern %.2f m, lowest %.2f m over the post foot, farthest out %.2f m" % [b.nearest_lamp, b.lowest, far])
	# read off the bat's own per-step record: a 10-tick sample at 4x missed the 0.1 s it spends by the door
	door_by = b.door_pass < 0.6
	print("BOT bat: drops %d, fell %.2f m before flying, out by the woodshed door %s (%.2f m)" % [b.drops, b.fell, door_by, b.door_pass])
	if noon or dusk:
		return _combat_done(false, "the bat is out by day or before the lantern is lit")
	if b.drops != 1 or b.fell < 0.1 or not door_by:
		return _combat_done(false, "the bat never drops out of the woodshed roost at dusk")
	if out_at < 0 or b.stoops < 3 or b.catches + b.misses < 2 or mo.eaten != b.catches:
		return _combat_done(false, "the bat never hunts the moths")
	if b.nearest_lamp < Bat.KEEP_OFF - 0.02 or b.lowest < 0.98 or far > Bat.LOOP_R.y + 2.0:
		return _combat_done(false, "the bat flies into the lantern, the turf or off the green")
	var f: Foley = _world.foley
	print("BOT bat: voice -- %d calls on the wing, %d buzzes for %d stoops, %d grumbles at the roost (quiet there by day %s); Foley played call %d, buzz %d, grumble %d" % [b.calls, b.buzzes, b.stoops, b.grumbles, grumbled, f.played.get("bat_call", 0), f.played.get("bat_buzz", 0), f.played.get("bat_grumble", 0)])
	if not grumbled or b.calls < 3 or b.buzzes != b.stoops:
		return _combat_done(false, "the bat is silent, or calls from the roost, or stoops without a feeding buzz")
	if f.played.get("bat_call", 0) < 1 or f.played.get("bat_buzz", 0) < 1 or f.played.get("bat_grumble", 0) < 1:
		return _combat_done(false, "the bat's chirps never reach the Foley")
	weather.force(1.0)
	await _ticks(900)
	var storm := b.state != Bat.ROOST
	var h0 := b.homings
	weather.force(0.0)
	await _ticks(600)
	var back_out := b.state in [Bat.PATROL, Bat.CHASE, Bat.IN] and b.drops == 2
	_world.time_of_day = 7.0
	await _ticks(900)
	print("BOT bat: sheltered from the storm %s (homings %d), out again after it %s, roosting after dawn %s (%.3f m off its hold), homings %d" % [not storm, h0, back_out, b.state == Bat.ROOST, b.global_position.distance_to(b.roost_at), b.homings])
	if storm or h0 < 1 or b.state != Bat.ROOST or b.homings < 2:
		return _combat_done(false, "the bat stays out in the rain or the daylight instead of going home to roost")
	if not back_out:
		return _combat_done(false, "the bat never comes out again once the rain has passed")
	_combat_done(true, "the bat hawks the moths at the lantern after dark")

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
## Soundscape: layers follow the clock and the weather; birds sing by day, crickets at
## night, thunder follows a strike, rooks caw when a flock scatters.
func _sound_test() -> void:
	var ss: Soundscape = _world.soundscape
	var wx: Weather = _world.weather
	print("BOT sound: synthesised in %d ms" % ss.build_ms)
	for k in ["WindBed", "LeavesBed", "RainBed", "CricketsBed"]:
		var bed: AudioStreamPlayer = ss.get_node(k)
		var st: AudioStreamWAV = bed.stream
		if st == null or st.data.size() < 20000 or st.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			return _combat_done(false, "%s has no looping stream" % k)
	wx.force(0.0)
	_world.time_of_day = 6.5
	var c0 := ss.calls
	await _ticks(60 * 20)   # 20 s game time at dawn
	var dawn: Dictionary = ss.levels.duplicate()
	var dawn_calls := ss.calls - c0
	print("BOT sound dawn: %s, calls %d" % [str(dawn), dawn_calls])
	if dawn.birds < 0.9 or dawn_calls < 4 or dawn.crickets > 0.01 or dawn.rain > 0.01:
		return _combat_done(false, "no dawn chorus, or crickets/rain heard at dawn")
	_world.time_of_day = 23.0
	c0 = ss.calls
	await _ticks(60 * 15)
	var night: Dictionary = ss.levels.duplicate()
	print("BOT sound night: %s, calls %d" % [str(night), ss.calls - c0])
	if night.crickets < 0.9 or night.birds > 0.01 or ss.calls - c0 > 1:
		return _combat_done(false, "no crickets at night, or birds singing in the dark")
	_world.time_of_day = 14.0
	wx.force(1.0)
	await _ticks(60 * 4)
	var storm: Dictionary = ss.levels.duplicate()
	print("BOT sound storm: rain %.2f wind %.2f, weather rain %.2f wind %.2f" % [storm.rain, storm.wind, wx.rain, wx.wind])
	if storm.rain < 0.8 or storm.wind <= dawn.wind or storm.birds > 0.2:
		return _combat_done(false, "storm not louder than the calm, or birds singing through it")
	var k0 := ss.claps
	wx.lightning.strike()
	var t := 0.0
	while ss.claps == k0 and t < 12.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("BOT sound: thunder %.1f s after the strike (claps %d)" % [t, ss.claps])
	if ss.claps == k0:
		return _combat_done(false, "no thunder after a lightning strike")
	var birds: Node = _world.get_node("Birds")
	var r0 := ss.caws
	for fl in birds._flocks:
		if fl.state != 1:   # not already in the air
			birds.scatter(fl, _player.global_position)
			break
	await _ticks(10)
	print("BOT sound: rook caws %d" % (ss.caws - r0))
	if ss.caws == r0:
		return _combat_done(false, "no caws when a rook flock scattered")
	_combat_done(true, "soundscape follows clock and weather, thunder and rook calls fire")

func _foley_test() -> void:
	var p := _player
	var f: Foley = _world.foley
	var c: StaffCombat = p.combat
	var wx: Weather = _world.weather
	wx.force(0.0)
	print("BOT foley: synthesised in %d ms" % f.build_ms)
	await _ticks(10)
	# the light string on the practice post: a swish per swing, straw thuds on contact
	var t := 0.0
	var press := 0.0
	while t < 4.5:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		press += dt
		if press > 0.3 and c.swings < 4:
			p.bot_attack = true
			press = 0.0
	print("BOT foley string: swings %d hits %d, played %s" % [c.swings, c.hits, str(f.played)])
	if int(f.played.get("swish", 0)) < 4 or int(f.played.get("straw", 0)) < 1:
		return _combat_done(false, "light string swung or struck the post in silence")
	# a tapped heavy: the deep whoom, the post struck with a boom under it, the ground slam
	p.stamina = Player.STAMINA_MAX
	p.bot_heavy = true
	await _ticks(2)
	p.bot_heavy = false
	await _wait_heavy_done(c)
	await _ticks(30)
	print("BOT foley heavy: %s" % str(f.played))
	if int(f.played.get("whoom", 0)) < 1 or int(f.played.get("boom", 0)) < 1 or int(f.played.get("slam", 0)) < 1:
		return _combat_done(false, "heavy smash had no whoom / boom / slam")
	# a dodge whooshes
	p.stamina = Player.STAMINA_MAX
	p.bot_input = Vector2(1, 0)
	p.bot_dodge = true
	await _ticks(40)
	p.bot_input = Vector2.ZERO
	if int(f.played.get("dodge", 0)) < 1:
		return _combat_done(false, "dodge made no sound")
	# footfalls on the dry meadow, then on soaked ground
	await _ticks(60)
	var g0 := int(f.played.get("step_grass", 0))
	var h0 := f.hero_steps
	var x0 := p.global_position
	p.bot_input = Vector2(0, -1)
	await _ticks(60 * 3)
	var grass := int(f.played.get("step_grass", 0)) - g0
	print("BOT foley: hero %d steps over %.1f m, soldier %d" % [f.hero_steps - h0, p.global_position.distance_to(x0), grass - (f.hero_steps - h0)])
	wx.force(1.0)
	wx.wet = 1.0
	await _ticks(60 * 3)
	p.bot_input = Vector2.ZERO
	var wet := int(f.played.get("step_wet", 0))
	var keep := f.surface_at(_world.get_node("Flora").ruin_site)
	print("BOT foley steps: grass %d in 12 s dry, wet %d in 12 s soaked, keep floor '%s'" % [grass, wet, keep])
	if grass < 4 or wet < 4 or keep != "grit":
		return _combat_done(false, "footfalls missing or on the wrong surface")
	_combat_done(true, "swishes, impacts, slam, dodge and footfalls on grass/wet/grit all sound")

func _mix_test() -> void:
	var p := _player
	var mix: AudioMix = _world.audio_mix
	var f: Foley = _world.foley
	var sc: Soundscape = _world.soundscape
	var rs: Vector3 = _world.get_node("Flora").ruin_site
	# the layers exist and route as Master > Ambience > Wildlife, Master > SFX, Master > Music
	var miss := []
	for b: String in AudioMix.BUSES:
		if AudioServer.get_bus_index(b) == -1:
			miss.append(b)
	var sends := "%s %s %s" % [AudioServer.get_bus_send(AudioServer.get_bus_index("Wildlife")),
		AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")), AudioServer.get_bus_send(AudioServer.get_bus_index("SFX"))]
	print("BOT mix: buses %d, missing %s, sends Wildlife/Ambience/SFX -> %s" % [AudioServer.bus_count, str(miss), sends])
	if not miss.is_empty() or sends != "Ambience Master Master":
		return _combat_done(false, "bus layout wrong")
	var wrong := 0
	for n in f.get_children() + sc.get_children():
		if n is AudioStreamPlayer3D or n is AudioStreamPlayer:
			if not (String(n.bus) in ["SFX", "Wildlife", "Ambience"]):
				wrong += 1
	print("BOT mix: %d players on Master directly" % wrong)
	if wrong > 0:
		return _combat_done(false, "players not routed to a layer")
	# out on the meadow: dry; inside the keep: the stone rings and the ambience dulls
	await _ticks(60)
	var open_e := mix.enclosure
	var to_v := Vector3(-rs.x, 0, -rs.z).normalized()
	var inside := rs + to_v * 1.7
	p.global_position = Vector3(inside.x, rs.y + 0.6, inside.z)
	await _ticks(60 * 3)
	var verb := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX"), 0) as AudioEffectReverb
	var lp := AudioServer.get_bus_effect(AudioServer.get_bus_index("Ambience"), 0) as AudioEffectLowPassFilter
	print("BOT mix: enclosure open %.2f, in keep %.2f (hero %.1f m from centre), reverb wet %.2f, ambience cut %.0f Hz" % [open_e, mix.enclosure, Vector2(p.global_position.x - rs.x, p.global_position.z - rs.z).length(), verb.wet, lp.cutoff_hz])
	if open_e > 0.02 or mix.enclosure < 0.9 or verb.wet < 0.25 or lp.cutoff_hz > 5000.0:
		return _combat_done(false, "keep did not change the space")
	var away := rs + to_v * 20.0
	p.global_position = Vector3(away.x, _world.get_node("Terrain").height_at(away.x, away.z) + 0.5, away.z)
	await _ticks(60 * 3)
	print("BOT mix: back on the slope enclosure %.2f, reverb on %s" % [mix.enclosure, AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("SFX"), 0)])
	if mix.enclosure > 0.02:
		return _combat_done(false, "reverb stayed on outside")
	# the pause menu: pauses, its sliders set the layer volumes and are kept
	var pm: PauseMenu = _world.pause_menu
	pm.toggle()
	var paused := get_tree().paused
	(pm.sliders["SFX"] as HSlider).value = 0.5
	(pm.sliders["Music"] as HSlider).value = 0.0
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	var mute := AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	pm.toggle()
	var cf := ConfigFile.new()
	cf.load(AudioMix.SETTINGS)
	var saved := float(cf.get_value("audio", "sfx", -1.0))
	print("BOT mix menu: paused %s, unpaused %s, SFX %.1f dB, music muted %s, saved sfx %.2f" % [paused, not get_tree().paused, sfx_db, mute, saved])
	mix.set_volume("SFX", 1.0)
	mix.set_volume("Music", 0.8)
	mix.save_settings()
	if not paused or get_tree().paused or absf(sfx_db + 6.02) > 0.1 or not mute or absf(saved - 0.5) > 0.01:
		return _combat_done(false, "pause menu volumes did not apply or save")
	_combat_done(true, "layers routed, keep reverb in/out, pause menu volumes apply and save")

## The picture panel: each preset sets its passes, the quality slider and render scale in
## the pause menu drive them (FSR 2 below native), and both are kept in settings.cfg.
func _gfx_test() -> void:
	var g: GraphicsQuality = _world.graphics
	var e: Environment = (_world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var vp := get_viewport()
	print("BOT gfx: default %s, ssil %s, ssr %s, scale %.2f mode %d" % [GraphicsQuality.NAMES[g.level], e.ssil_enabled, e.ssr_enabled, vp.scaling_3d_scale, vp.scaling_3d_mode])
	var default_ok := g.level == 2 and e.ssil_enabled and e.ssr_enabled and vp.scaling_3d_scale == 1.0
	var pm: PauseMenu = _world.pause_menu
	pm.toggle()
	pm.quality_slider.value = 0.0
	var low := [g.level, e.ssil_enabled, e.ssr_enabled, e.sdfgi_enabled, vp.mesh_lod_threshold]
	pm.quality_slider.value = 3.0
	var ultra := [g.level, e.ssil_enabled, e.ssr_enabled, e.sdfgi_cascades, vp.mesh_lod_threshold]
	pm.scale_slider.value = 0.7
	var fsr := [vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2, vp.scaling_3d_scale, vp.use_taa]
	pm.toggle()
	var cf := ConfigFile.new()
	cf.load(GraphicsQuality.SETTINGS)
	var saved := [int(cf.get_value("graphics", "quality", -1)), float(cf.get_value("graphics", "render_scale", -1.0)), cf.has_section("audio")]
	print("BOT gfx: low %s, ultra %s, fsr %s, saved %s" % [low, ultra, fsr, saved])
	# a fresh load reads them back
	g.level = 2
	g.render_scale = 1.0
	g.load_settings()
	var reread := [g.level, g.render_scale]
	g.set_level(2)
	g.set_render_scale(1.0)
	g.save_settings()
	print("BOT gfx: reloaded %s, restored %s %.2f" % [reread, GraphicsQuality.NAMES[g.level], vp.scaling_3d_scale])
	if not default_ok:
		return _combat_done(false, "default preset is not High at native scale")
	if low[0] != 0 or low[1] or low[2] or low[3] or low[4] < 3.0:
		return _combat_done(false, "Low preset did not drop SSIL/SSR/GI or raise the LOD threshold")
	if ultra[0] != 3 or not ultra[1] or not ultra[2] or ultra[3] != 4 or ultra[4] > 1.0:
		return _combat_done(false, "Ultra preset wrong")
	if not fsr[0] or absf(fsr[1] - 0.7) > 0.01 or fsr[2]:
		return _combat_done(false, "render scale did not switch to FSR 2")
	if saved[0] != 3 or absf(saved[1] - 0.7) > 0.01 or not saved[2] or reread[0] != 3 or absf(reread[1] - 0.7) > 0.01:
		return _combat_done(false, "picture settings not saved/reloaded (or sound section lost)")
	_combat_done(true, "presets Low..Ultra apply, FSR 2 render scale, saved and reloaded")

## Hesper keeps her day: tends the lid in the morning, gathers under the oaks (leaving the
## keep through the breach), eats in the shade, shelters under a crown in the rain, dozes
## seated against the inner wall at night, and stops to face the hero (named once).
## Hesper's cookfire: on the keep floor clear of the plinth and her way out, its meshes face
## out, it blazes with light, flames, crackle and moths at night, is cold ash at noon, and rain
## knocks the flames down; she walks out past it at dawn without stepping into it.
## Hesper's right hand (it rides the modifier) to a point, flat (m).
func _keeper_hand_to(k: Keeper, at: Vector3) -> float:
	var p: Vector3 = k.hand_mark.global_position
	return Vector2(p.x - at.x, p.z - at.z).length()

func _hearth_test() -> void:
	var k: Keeper = _world.keeper
	var hr: Hearth = _world.hearth
	var wx: Weather = _world.weather
	wx.force(0.0)
	var hp := hr.global_position
	var r := Vector2(hp.x - k.site.x, hp.z - k.site.z).length()
	var bed: Vector3 = k._spots["sleep"][0]
	var to_bed := Vector2(hp.x - bed.x, hp.z - bed.z).length()
	var fb := k._floor_basket.global_position
	var to_basket := Vector2(hp.x - fb.x, hp.z - fb.z).length()
	print("BOT hearth at r %.2f from the lid (plinth 1.75, keep %.1f), %.2f m from her bed, %.2f m from the basket" % [r, Keeper.KEEP_R, to_bed, to_basket])
	if r - Hearth.RING_R < 1.8 or r + Hearth.RING_R > Keeper.KEEP_R - 0.4 or to_bed < 0.9 or to_bed > 2.0 or to_basket < 1.0:
		return _combat_done(false, "hearth badly placed on the keep floor")
	# her swept floor: no loose spalls or slabs on the ring or where she kneels
	var ru: Ruins = _world.get_node("Ruins")
	var knee: Vector3 = k._spots["kindle"][0]
	var near_fire := 0
	var near_knee := 0
	for c in ru.get_children():
		if c is MultiMeshInstance3D and c.name.begins_with("Stones_"):
			var mm: MultiMesh = c.multimesh
			for i in mm.instance_count:
				var o: Vector3 = c.global_transform * mm.get_instance_transform(i).origin
				if Vector2(o.x - hp.x, o.z - hp.z).length() < 0.9:
					near_fire += 1
				if Vector2(o.x - knee.x, o.z - knee.z).length() < 0.6:
					near_knee += 1
	print("BOT hearth swept floor: %d loose stones left out, %d stones within 0.9 m of the fire, %d within 0.6 m of her kneel spot" % [ru.swept_count, near_fire, near_knee])
	if ru.swept_count < 3 or near_fire > 0 or near_knee > 0:
		return _combat_done(false, "the floor round the hearth should be swept of rubble")
	# every mesh faces outward (normals away from its own centre)
	var bad := 0
	var n_mesh := 0
	for mi: MeshInstance3D in hr.find_children("*", "MeshInstance3D", true, false):
		var a := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var c := Vector3.ZERO
		for v in vs:
			c += v
		c /= vs.size()
		var out := 0.0
		for i in vs.size():
			var d := vs[i] - c
			if mi.name == "AshBed" or mi.name.begins_with("Log"):
				d.y = 0.0                        # logs: radial, along their length y
			out += ns[i].dot(Vector3.UP if mi.name == "AshBed" else d.normalized())
		n_mesh += 1
		if out <= 0.0:
			bad += 1
			print("BOT hearth inward mesh %s (%.1f)" % [mi.name, out])
	print("BOT hearth meshes: %d, %d facing inward" % [n_mesh, bad])
	if bad > 0 or n_mesh < 20:
		return _combat_done(false, "hearth meshes missing or inside out")
	# dusk: cold until Hesper walks in from the breach, kneels at the ring and strikes it alight
	_player.global_position = k.site + k.to_v * 60.0 + Vector3.UP * 30.0
	_world.time_of_day = 19.3
	k.settle(_world, 19.3)
	await _ticks(60)
	hr.kindled = -1.0
	_world.time_of_day = 19.55
	await _ticks(30)
	var cold := hr.level
	var basket_walk := k.garb.basket_node.visible
	var basket_kneel := true
	var kn: Array = k._spots["kindle"]
	var k_near := INF
	var k_fire := INF
	var down_at := -1
	var warps0 := k.warps
	var young_gain := INF
	for i in 2400:
		_world.time_of_day = 19.6                # hold the hour: watch her, not the clock
		await get_tree().physics_frame
		var kp := k.global_position
		k_fire = minf(k_fire, Vector2(kp.x - hp.x, kp.z - hp.z).length())
		if k.pick > 0.95 and down_at < 0:
			down_at = i
			k_near = Vector2(kp.x - kn[0].x, kp.z - kn[0].z).length()
			basket_kneel = k.garb.basket_node.visible or not k._floor_basket.visible
		if hr.kindled >= 0.0 and hr.kindled < 5.0:
			young_gain = minf(young_gain, hr.flame_gain)
		if hr.kindled > Keeper.KINDLE_NURSE and hr.level > 0.6 and k.pick < 0.05:
			break
	var face := absf(wrapf(k.body.rotation.y - float(kn[1]), -PI, PI))
	print("BOT hearth kindle: cold %.2f before her, %s %s, down at frame %d %.2f m from the spot, %.2f m closest to the fire, facing it within %.2f rad, %d strikes, kindles %d, level %.2f now, pick %.2f, warps %d" % [cold, k.activity, k.state, down_at, k_near, k_fire, face, hr.strikes, k.kindles, hr.level, k.pick, k.warps - warps0])
	if cold > 0.0 or k.activity != "kindle" or down_at < 0 or k_near > 0.5 or k_fire < Hearth.RING_R + 0.3 or face > 0.5:
		return _combat_done(false, "Hesper should walk to the ring and kneel at it facing the fire")
	if hr.strikes < Keeper.KINDLE_STRIKES or k.kindles != 1 or hr.level < 0.6 or not hr.flames.emitting or k.pick > 0.05 or k.warps > warps0:
		return _combat_done(false, "her flint should light the fire, and she should get up once it takes")
	print("BOT hearth basket: on her back walking in %s, on her back kneeling %s; flint sounds %d for %d strikes, catch sounds %d" % [basket_walk, basket_kneel, hr.flint_sounds, hr.strikes, hr.blow_sounds])
	if not basket_walk or basket_kneel:
		return _combat_done(false, "the basket should come off her back before she kneels at the fire")
	if hr.flint_sounds != hr.strikes or hr.blow_sounds != 1:
		return _combat_done(false, "each flint strike should click, and the catch should sound once")
	# evening: blazing
	_world.time_of_day = 21.0
	await _ticks(240)
	var moths := hr.moth_positions()
	var far := 0.0
	var low := INF
	for m in moths:
		far = maxf(far, m.distance_to(hr.global_position))
		low = minf(low, m.y - hr.global_position.y)
	print("BOT hearth 21 h: level %.2f, light %.2f, flames %s, sparks %s, smoke %s, crackle %s %.1f dB, moths %d within %.2f m, lowest %.2f m up" % [hr.level, hr.light.light_energy, hr.flames.emitting, hr.sparks.emitting, hr.smoke.emitting, hr.crackle.playing, hr.crackle.volume_db, moths.size(), far, low])
	print("BOT hearth bounce glow %.2f; flame brightness %.2f just after it caught, %.2f at 21 h" % [hr.bounce.light_energy, young_gain, hr.flame_gain])
	if young_gain > 0.6 or hr.flame_gain < 0.99:
		return _combat_done(false, "young flames should burn dimmer than the evening blaze")
	if hr.level < 0.95 or hr.light.light_energy < 0.8 or not hr.bounce.visible or hr.bounce.light_energy < 0.3 or not hr.flames.emitting or not hr.crackle.playing or moths.size() < Hearth.MOTHS or far > 1.8 or low < 0.2:
		return _combat_done(false, "the fire should blaze at night with moths round it")
	# 22 h: sat down for the night but still up to the blaze, turned to it, hands held out
	_world.time_of_day = 22.0
	k.settle(_world, 22.0)
	await _ticks(120)
	var sleep_yaw: float = k._spots["sleep"][1]
	var to_f := Vector3(hp.x - k.global_position.x, 0, hp.z - k.global_position.z)
	var off_sq := absf(angle_difference(sleep_yaw, atan2(to_f.x, to_f.z)))
	var hand_warm := _keeper_hand_to(k, hp)
	var warm_line := k._next_line()
	print("BOT hearth warm 22 h: %s sit %.2f warm %.2f, facing %.2f rad off the fire (square to the keep %.2f), hands %.2f m from it, line \"%s\"" % [k.activity, k.sit, k.warm, k.warm_facing(), off_sq, hand_warm, warm_line])
	if not (warm_line in Keeper.LINES["warm"]) or k.activity != "sleep" or k.warm < 0.9 or k.warm_facing() > off_sq * 0.6:
		return _combat_done(false, "at 22 h she should sit turned to the fire, warming her hands")
	var flame_a := hr.flames.color.a
	var smoke_a := hr.smoke.color.a
	wx.force(1.0)
	await _ticks(240)
	print("BOT hearth rain: flames alpha %.2f (dry %.2f), smoke alpha %.2f (dry %.2f), moths %d" % [hr.flames.color.a, flame_a, hr.smoke.color.a, smoke_a, hr.moth_positions().size()])
	if wx.rain > 0.5 and (hr.flames.color.a >= flame_a or hr.smoke.color.a <= smoke_a):
		return _combat_done(false, "rain should knock the flames down and thicken the smoke")
	wx.force(0.0)
	_world.time_of_day = 3.0
	await _ticks(60)
	print("BOT hearth 3 h: level %.2f, light %.2f" % [hr.level, hr.light.light_energy])
	if hr.level > 0.7 or hr.level < 0.3:
		return _combat_done(false, "the fire should burn down overnight")
	await _ticks(400)
	var hand_doze := _keeper_hand_to(k, hp)
	print("BOT hearth doze 3 h: warm %.2f, facing %.2f rad off the fire, hands %.2f m from it (%.2f warming)" % [k.warm, k.warm_facing(), hand_doze, hand_warm])
	if k.warm > 0.05 or hand_doze < hand_warm + 0.1:
		return _combat_done(false, "by 3 h she should have nodded off, hands drawn in")
	# noon: cold
	_world.time_of_day = 12.0
	await _ticks(60)
	print("BOT hearth noon: level %.2f, light visible %s, flames %s, crackle %s, moths %d" % [hr.level, hr.light.visible, hr.flames.emitting, hr.crackle.playing, hr.moth_positions().size()])
	if hr.level > 0.0 or hr.light.visible or hr.bounce.visible or hr.flames.emitting or hr.crackle.playing or not hr.moth_positions().is_empty():
		return _combat_done(false, "the fire should be cold ash at noon")
	# dawn: she gets up from beside it and walks out to the breach, round it
	_world.time_of_day = 5.0
	k.settle(_world, 5.0)
	await _ticks(60)
	_world.time_of_day = 5.6
	var closest := INF
	for i in 1500:
		await get_tree().physics_frame
		closest = minf(closest, Vector2(k.global_position.x - hp.x, k.global_position.z - hp.z).length())
		if k.state == Keeper.STAND and k.activity == "wake" and i > 100:
			break
	print("BOT hearth dawn: Hesper %s, closest %.2f m to the fire centre" % [k.activity, closest])
	if closest < Hearth.RING_R + 0.3 or k.activity != "wake":
		return _combat_done(false, "she should walk out round the fire at dawn")
	_combat_done(true, "Hesper lights the hearth at dusk; it burns down by dawn and draws moths")

## The fox: comes in through the gateway once the fire is going after dark, sits in the
## breach at the edge of the firelight facing it, bolts from a hero walking up, keeps away.
## Brack, Edda's collie: potters about the green by day, runs out barking and wagging to
## meet the hero, keeps at his heel about the cottage and stays home when he leaves, and
## sits by the white cottage door at night and in rain, guard-barking at a hero in the dark.
func _dog_test() -> void:
	var dg: Dog = _world.dog
	var tr: Terrain = _world.get_node("Terrain")
	_world.weather.force(0.0)
	var far := dg.home + Vector3(70.0, 0, 0)
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	_world.time_of_day = 10.0
	await _ticks(30)
	var moved := 0.0
	var sniffs := 0
	var rests := 0
	var prev := dg.global_position
	var max_home := 0.0
	var prev_state := dg.state
	var on_track := 0
	var lay_min := 1.0
	var rest_lay := -1.0
	var day_lie := 0
	for i in 3000:
		await get_tree().physics_frame
		if YardGround.path_dist(dg.global_position.x, dg.global_position.z) < 0.8:
			on_track += 1
		if dg.state == Dog.REST and dg.lie > 0.99:
			day_lie += 1
		if dg.state == Dog.REST and dg.sit > 0.99:
			# how flat the grass beside it lies by the time it gets up (it presses as it sits)
			rest_lay = maxf(rest_lay, _world.trample.herd_lay_at(dg.global_position + Vector3(0.3, 0, 0)))
		elif rest_lay >= 0.0 and dg.state != Dog.REST:
			lay_min = minf(lay_min, rest_lay)
			rest_lay = -1.0
		moved += dg.global_position.distance_to(prev)
		prev = dg.global_position
		max_home = maxf(max_home, Vector2(prev.x - dg.home.x, prev.z - dg.home.z).length())
		if dg.state != prev_state:
			if dg.state == Dog.SNIFF:
				sniffs += 1
			if dg.state == Dog.REST:
				rests += 1
			prev_state = dg.state
	print("BOT dog day: walked %.1f m, %d sniffs, %d rests, at most %.1f m from home, state %d" % [moved, sniffs, rests, max_home, dg.state])
	if moved < 5.0 or sniffs < 1 or rests < 1 or max_home > Dog.RANGE or dg.state in [Dog.GREET, Dog.HEEL, Dog.BED]:
		return _combat_done(false, "the dog should potter about the green by day, nosing about and sitting")
	print("BOT dog shows: %.0f%% of the time on a trodden track, %d spots pressed, grass beside it laid %.2f (min while sat)" % [100.0 * on_track / 3000.0, dg.pressed, lay_min])
	print("BOT dog day rests lying down: %d frames" % day_lie)
	if on_track < 900 or dg.pressed < 1 or lay_min < 0.5 or day_lie < 1:
		return _combat_done(false, "the dog should keep mostly to the tracks and press the grass flat where it sits")
	# the hero walks up: it barks, runs to meet him wagging, and sits at his heel
	var fb0: int = _world.foley.played.get("dog_bark", 0)
	var b0 := dg.barks
	# about 11 m from where it is, on open ground within its range of home
	var near := dg.home
	for k in 24:
		var a := TAU * k / 24.0
		var q := dg.global_position + Vector3(cos(a), 0, sin(a)) * 11.0
		if dg._clear(q, 1.6) and Vector2(q.x - dg.home.x, q.z - dg.home.z).length() < Dog.RANGE - 6.0:
			near = q
			break
	_player.global_position = Vector3(near.x, tr.height_at(near.x, near.z) + 0.2, near.z)
	var met := -1
	var wag_max := 0.0
	for i in 1200:
		await get_tree().physics_frame
		wag_max = maxf(wag_max, dg.wag)
		if dg.state == Dog.HEEL and met < 0:
			met = i
		if met >= 0 and i > met + 200:
			break
	var gap := Vector2(dg.global_position.x - _player.global_position.x, dg.global_position.z - _player.global_position.z).length()
	print("BOT dog greet: state %d, met at frame %d, %.2f m from the hero, wag %.2f, sit %.2f, %d barks (%d sounded), greets %d" % [dg.state, met, gap, wag_max, dg.sit, dg.barks - b0, _world.foley.played.get("dog_bark", 0) - fb0, dg.greets])
	if met < 0 or gap > Dog.HEEL_R + 1.0 or gap < 0.8 or wag_max < 0.6 or dg.barks - b0 < 2 or _world.foley.played.get("dog_bark", 0) - fb0 < 1:
		return _combat_done(false, "the dog should bark, run out wagging and come to the hero's heel")
	# the hero leaves the village: it gives up and goes back to its pottering near home
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	await _ticks(120)
	var back := Vector2(dg.global_position.x - dg.home.x, dg.global_position.z - dg.home.z).length()
	print("BOT dog hero gone: state %d, %.1f m from home" % [dg.state, back])
	if dg.state in [Dog.GREET, Dog.HEEL] or back > Dog.RANGE:
		return _combat_done(false, "the dog should stay home when the hero leaves")
	# dusk: back to the door, sat
	_world.time_of_day = 22.0
	var bedded := -1
	for i in 2400:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
		if dg.state == Dog.BED and dg.sit > 0.99:
			bedded = i
			break
	print("BOT dog night: state %d bedded at frame %d, %.2f m from its place by the door" % [dg.state, bedded, dg.global_position.distance_to(dg.bed)])
	if bedded < 0 or dg.global_position.distance_to(dg.bed) > 0.4:
		return _combat_done(false, "the dog should go to its place by the door at night")
	for i in 240:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
	print("BOT dog lies down: lie %.2f sit %.2f doze %.2f" % [dg.lie, dg.sit, dg.doze])
	if dg.lie < 0.95 or dg.doze < 0.5:
		return _combat_done(false, "the dog should lie down in its place at night")
	# a hero walking up on the dark house sets it barking
	var b1 := dg.barks
	var by := dg.bed + Vector3(dg.bed.x - dg.home.x, 0, dg.bed.z - dg.home.z).normalized() * -6.0
	_player.global_position = Vector3(by.x, tr.height_at(by.x, by.z) + 0.2, by.z)
	var lie_min := 1.0
	for i in 240:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
		lie_min = minf(lie_min, dg.lie)
	print("BOT dog night hero: %d guard barks, still in bed %s, sat up to bark (lie %.2f)" % [dg.barks - b1, dg.state == Dog.BED, lie_min])
	if dg.barks - b1 < 2 or dg.barks - b1 > 6 or dg.state != Dog.BED or lie_min > 0.1:
		return _combat_done(false, "the dog should guard-bark from the door at a hero in the dark")
	# rain at noon keeps it by the door too
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	_world.time_of_day = 12.0
	_world.weather.force(1.0)
	await _ticks(60)
	print("BOT dog rain: rain %.2f state %d lie %.2f" % [_world.weather.rain, dg.state, dg.lie])
	if dg.state != Dog.BED or dg.lie > 0.05:
		return _combat_done(false, "the dog should shelter at the door in rain")
	_world.weather.force(0.0)
	return _combat_done(true, "the collie potters on the green, runs out barking and wagging to the hero's heel, stays home when he leaves, keeps to the tracks pressing the grass where it sits, lies down by the door at night and sits up to bark, and shelters there in rain")

func _fox_test() -> void:
	var k: Keeper = _world.keeper
	var fx: Fox = _world.fox
	var hr: Hearth = _world.hearth
	var tr: Terrain = _world.get_node("Terrain")
	_world.weather.force(0.0)
	var far := k.site + k.to_v * 60.0
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	_world.time_of_day = 12.0
	await _ticks(30)
	print("BOT fox noon: state %d visible %s" % [fx.state, fx.visible])
	if fx.state != Fox.AWAY or fx.visible:
		return _combat_done(false, "no fox at the keep by day")
	fx.arrive_h = 21.0
	_world.time_of_day = 22.0
	var wall_hits := 0
	var sat_at := -1
	for i in 6000:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
		var q := fx.global_position
		var r := Vector2(q.x - k.site.x, q.z - k.site.z).length()
		var off := absf(Vector3(q.x - k.site.x, 0, q.z - k.site.z).normalized().signed_angle_to(k.to_v, Vector3.UP))
		if fx.visible and (((r > 11.6 and r < 13.4) or (r > 3.1 and r < 4.1)) and off > 0.3 or (r < Keeper.KEEP_R - 0.1 and off > 0.6)):
			wall_hits += 1
		if fx.state == Fox.SIT and fx.sit > 0.99:
			sat_at = i
			break
	var q := fx.global_position
	var to_fire := Vector2(hr.global_position.x - q.x, hr.global_position.z - q.z)
	var face := absf(wrapf(fx.yaw - fx._face_fire(), -PI, PI))
	print("BOT fox 22 h: state %d sat at frame %d, %.2f m off its seat, %.2f m from the fire (level %.2f), facing it within %.2f rad, %d frames through a wall, visits %d" % [fx.state, sat_at, q.distance_to(fx.sit_at), to_fire.length(), hr.level, face, wall_hits, fx.visits])
	if sat_at < 0 or q.distance_to(fx.sit_at) > 0.35 or to_fire.length() < 3.5 or to_fire.length() > 8.0 or face > 0.3 or wall_hits > 0 or not fx.visible:
		return _combat_done(false, "the fox should come in by the gateway and sit at the edge of the firelight facing it")
	# looks round now and then (Hesper holds her crust back until the crust check below)
	k._scrap_night = int(floor((22.0 + 12.0) / 24.0))
	var yaw_span := 0.0
	for i in 900:
		await get_tree().physics_frame
		yaw_span = maxf(yaw_span, absf(fx.head_yaw))
	print("BOT fox head turns up to %.2f rad while sat" % yaw_span)
	if yaw_span < 0.2 or fx.state != Fox.SIT:
		return _combat_done(false, "the sat fox should look round now and then")
	# Hesper, sat up warming her hands, tosses it a crust: it gets up, eats it, sits again
	k.settle(_world, 22.0)
	k._scrap_night = -1
	var thrown := -1
	var min_land := 99.0
	var top_graze := 0.0
	var crust_at := Vector3.ZERO
	var flick := 0.0
	var nose_r := 99.0        # nearest its nose came to the keep centre while eating
	for i in 3600:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
		flick = maxf(flick, k.crumple.flick)
		if k.scraps > 0 and thrown < 0:
			thrown = i
		if fx._scrap != null:
			crust_at = fx._scrap.global_position
		top_graze = maxf(top_graze, fx.graze)
		if fx.graze > 0.5:
			var nose: Vector3 = fx.global_position + Vector3(-sin(fx.yaw), 0, -cos(fx.yaw)) * Fox.SNOUT
			nose_r = minf(nose_r, Vector2(nose.x - k.site.x, nose.z - k.site.z).length())
		if fx.eaten > 0 and fx.state == Fox.SIT and fx.sit > 0.99:
			break
	if crust_at != Vector3.ZERO:
		min_land = crust_at.distance_to(fx.sit_at)
	print("BOT fox crust: thrown at frame %d (warm %.2f, sit %.2f, arm up %.2f), landed %.2f m from its seat, nose down %.2f, eaten %d, back sat %s %.2f m off its seat" % [thrown, k.warm, k.sit, flick, min_land, top_graze, fx.eaten, fx.state == Fox.SIT, fx.global_position.distance_to(fx.sit_at)])
	if thrown < 0 or flick < 0.9 or min_land > 1.3 or top_graze < 0.9 or fx.eaten < 1 or fx.state != Fox.SIT or fx.global_position.distance_to(fx.sit_at) > 0.35:
		return _combat_done(false, "Hesper should toss the sat fox a crust, and it should eat it and sit again")
	# the lid's plinth's laid blocks reach out to r ~1.9: eating, its nose stays on open floor
	print("BOT fox crust floor: nose down at r %.2f m from the keep centre (plinth edge ~1.9)" % nose_r)
	if nose_r < 1.95:
		return _combat_done(false, "the fox should eat the crust on open floor, not with its head in the lid's plinth")
	var fol := _world.get_node_or_null("Foley")
	var crunches := int(fol.played.get("crunch", 0)) if fol != null and "played" in fol else -1
	print("BOT fox manners: glanced %.2f rad round at her before it got up, licked its chops %d times, head shake %.2f rad, crunches %d" % [fx.glance, fx.licks, fx.shook, crunches])
	if fx.glance < 0.15 or fx.licks < 2 or fx.shook < 0.3 or crunches == 0:
		return _combat_done(false, "the fox should glance at Hesper before taking the crust, crunch it, then lick its chops and shake its head")
	# once a night
	for i in 900:
		_world.time_of_day = 22.0
		await get_tree().physics_frame
	if k.scraps != 1:
		return _combat_done(false, "only one crust a night (%d)" % k.scraps)
	# the hero walks up: it bolts out into the dark
	var side := fx.sit_at + k.to_v.cross(Vector3.UP) * 6.0
	_player.global_position = Vector3(side.x, tr.height_at(side.x, side.z) + 0.2, side.z)
	await _ticks(20)
	var bolted := fx.state == Fox.BOLT
	var top := 0.0
	for i in 3000:
		await get_tree().physics_frame
		top = maxf(top, fx.speed)
		if fx.state == Fox.AWAY:
			break
	print("BOT fox scare: bolted %s, top speed %.1f m/s, state %d visible %s, bolts %d, keeps away %.0f s" % [bolted, top, fx.state, fx.visible, fx.bolts, fx.shy_t])
	if not bolted or top < 5.0 or fx.state != Fox.AWAY or fx.visible or fx.shy_t <= 0.0:
		return _combat_done(false, "a hero walking up should send the fox off into the dark")
	var fl = _world.get("foley")
	var yelps: int = fl.played.get("fox_yelp", 0) if fl else -1
	print("BOT fox yelp as it bolted: %d (barks %d)" % [yelps, fx.barks])
	if yelps < 1:
		return _combat_done(false, "a bolting fox should yelp")
	# out in the dark it barks now and then from round its den
	fx._bark_t = 0.5
	await _ticks(60)
	var calls: int = fl.played.get("fox_bark", 0)
	print("BOT fox night bark from the dark: %d" % calls)
	if calls < 1:
		return _combat_done(false, "the fox should bark from the dark at night")
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	await _ticks(120)
	if fx.state != Fox.AWAY:
		return _combat_done(false, "a scared fox should keep away a while")
	# before dawn: no fox once the fire is down and the light coming
	fx.shy_t = 0.0
	_world.time_of_day = 5.5
	await _ticks(120)
	print("BOT fox 5:30: state %d visible %s (fire %.2f)" % [fx.state, fx.visible, hr.level])
	if fx.state != Fox.AWAY:
		return _combat_done(false, "the fox should not come at first light")
	var before: int = fl.played.get("fox_bark", 0)
	_world.time_of_day = 12.0
	fx._bark_t = 0.5
	await _ticks(60)
	if fl.played.get("fox_bark", 0) != before:
		return _combat_done(false, "no fox barks by day")
	_combat_done(true, "a fox comes to sit at the edge of Hesper's firelight after dark, eats the crust she tosses it, and bolts from the hero")

## Osric woken by the barking (_henfox_test): out to the gap with his lantern and back in.
var _os := {}

func _osric_sample(i: int) -> void:
	var nb: Neighbour = _world.neighbour
	if _os["back_in"] >= 0 or _world.stone_cottage.rousings == 0:
		return                           # (before the barking he may still be walking in)
	if nb.outdoors():
		_os["out"] = true
		var gap: Vector3 = nb._spots["lookout"][0]
		_os["lamp"] = maxf(_os["lamp"], nb.hand_lantern.lit if nb.hand_lantern.visible else 0.0)
		_os["lift"] = maxf(_os["lift"], nb.lift)
		if nb.lift > 0.95 and nb.hand_lantern.visible:
			# the ring in the hand: how high and how far out before him it is held
			var rp: Vector3 = nb.hand_lantern.global_position - nb.global_position
			var fwd: Vector3 = nb.body.global_transform.basis.z
			_os["ring_y"] = maxf(_os["ring_y"], rp.y)
			_os["ring_out"] = maxf(_os["ring_out"], Vector2(rp.x, rp.z).dot(Vector2(fwd.x, fwd.z).normalized()))
			# the fist on the bail clear of his face, not held up beside his cheek
			var sk: Skeleton3D = nb.find_children("*", "Skeleton3D", true, false)[0]
			var hb := sk.find_bone("mixamorig_Head")
			var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
			_os["face_gap"] = minf(_os["face_gap"], (nb.hand_lantern.global_position - head).length())
			# the fingers closed round the bail (as the pose modifier posed them: the skeleton's
			# own poses are restored after the modifiers run)
			_os["fist"] = maxf(_os["fist"], nb.crumple.grip_fold)
			_os["fist_turn"] = minf(_os["fist_turn"], nb.crumple.grip_turn)
			_os["fist_thumb"] = maxf(_os["fist_thumb"], nb.crumple.grip_thumb)
			_os["thumb_gap"] = minf(_os["thumb_gap"], nb.crumple.grip_gap)
			_os["thumb_tip"] = nb.crumple.grip_tip
			# the vent glow that lights his face from below
			var fl: OmniLight3D = nb.hand_lantern.fill
			if fl.visible:
				_os["fill"] = maxf(_os["fill"], fl.light_energy)
				_os["fill_y"] = maxf(_os["fill_y"], fl.global_position.y - nb.global_position.y)
				_os["fill_head"] = minf(_os["fill_head"], fl.global_position.distance_to(head + Vector3.UP * 0.12))
		_os["gap"] = minf(_os["gap"], Vector2(nb.global_position.x - gap.x, nb.global_position.z - gap.z).length())
		_os["sill"] = minf(_os["sill"], _world.stone_cottage.lit)
		# Brack over by him at the gap, sat at his knee
		var dg: Dog = _world.dog
		if dg.state == Dog.ATTEND and dg.speed > 0.5:
			for o in dg._obstacles:
				_os["dog_clear"] = minf(_os["dog_clear"], Vector2(dg.global_position.x - o.x, dg.global_position.z - o.z).length())
		if nb._look_t > 4.0:
			var dd := Vector2(dg.global_position.x - nb.global_position.x, dg.global_position.z - nb.global_position.z).length()
			_os["dog_near"] = minf(_os["dog_near"], dd)
			if dd < 1.8:
				_os["dog_sit"] = maxf(_os["dog_sit"], dg.sit)
	elif _os["out"]:
		_os["back_in"] = i

func _henfox_test() -> void:
	var fx: Fox = _world.fox
	var sc: Node3D = _world.stone_cottage
	var hn: Hens = _world.hens
	var hh: HenHouse = hn.house
	var dg: Dog = _world.dog
	var tr: Terrain = _world.get_node("Terrain")
	var fl = _world.get("foley")
	var stile: Vector3 = _world.dry_wall.stile
	_world.weather.force(0.0)
	var far := sc.global_position + Vector3(0, 0, 70.0)
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	# the small hours, the hens shut in, Brack lying at Edda's door
	_world.time_of_day = 1.5
	hn._settle_now()
	dg.place_bed()
	fx.prowl_h = 1.0
	await _ticks(30)
	print("BOT henfox start: slide shut %.2f, hens all in %s, dog state %d lie %.2f, fox state %d" % [hh.shut, hn.all_in(), dg.state, dg.lie, fx.state])
	if hh.shut < 0.99 or not hn.all_in():
		return _combat_done(false, "the hens should be shut in at 01:30")
	var sq0: int = fl.played.get("squawk", 0)
	var db0: int = fl.played.get("dog_bark", 0)
	var wd0: int = fl.played.get("wood", 0)
	var b0 := dg.barks
	var stile_in := 99.0
	var stile_out := 99.0
	var top_pitch := 0.0
	var top_y := 0.0
	var lie_min := 1.0
	var dog_look := 0.0
	var reached := -1
	var gone := -1
	_os = {"out": false, "gap": 99.0, "lamp": 0.0, "lift": 0.0, "ring_y": 0.0, "ring_out": -9.0, "sill": 1.0, "back_in": -1, "dog_near": 99.0, "dog_sit": 0.0, "dog_clear": 99.0, "fill": 0.0, "fill_y": 0.0, "face_gap": 99.0, "fist": -9.0, "fist_turn": 9.0, "fist_thumb": -9.0, "fill_head": 99.0, "thumb_gap": 99.0, "thumb_tip": Vector3.ZERO}
	for i in 9000:
		_world.time_of_day = 1.5
		await get_tree().physics_frame
		_osric_sample(i)
		if fx.state != Fox.PROWL and fx.prowls == 0:
			continue
		var d := Vector2(fx.global_position.x - stile.x, fx.global_position.z - stile.z).length()
		if fx.tries == 0:
			stile_in = minf(stile_in, d)
		elif fx._pstep == 4:
			stile_out = minf(stile_out, d)
		top_pitch = maxf(top_pitch, fx.pitch)
		top_y = maxf(top_y, fx.global_position.y - tr.height_at(fx.global_position.x, fx.global_position.z))
		if fx.tries > 0 and reached < 0:
			reached = i
		if dg.fox_alarms > 0:
			lie_min = minf(lie_min, dg.lie)
			dog_look = maxf(dog_look, absf(dg.head_yaw))
		if fx.prowls > 0 and fx.state == Fox.AWAY:
			gone = i
			break
	var sill := hh.ladder_at(0.0)
	print("BOT henfox prowl: prowls %d, through the stile in %.2f m / out %.2f m, up the ladder at frame %d (pitch %.2f rad, %.2f m off the ground), scrabbles %d, hens squawked %d (%d sounded), dog alarms %d barks %d (%d sounded, lie down to %.2f, head round %.2f), wood knocks %d, fled %d, gone at frame %d visible %s" % [fx.prowls, stile_in, stile_out, reached, top_pitch, top_y, fx.scrabbles, hn.stirred, fl.played.get("squawk", 0) - sq0, dg.fox_alarms, dg.barks - b0, fl.played.get("dog_bark", 0) - db0, lie_min, dog_look, fl.played.get("wood", 0) - wd0, fx.fled, gone, fx.visible])
	if fx.prowls != 1 or reached < 0 or stile_in > 0.6 or stile_out > 0.6 or top_pitch < 0.3 or top_y < 0.2:
		return _combat_done(false, "the fox should come in through the stile and up the hens' ladder to the slide")
	if fx.scrabbles < 1 or hn.stirred < 1 or fl.played.get("squawk", 0) - sq0 < 1 or fl.played.get("wood", 0) - wd0 < 1:
		return _combat_done(false, "the fox should scrabble at the slide and set the hens squawking")
	if dg.fox_alarms < 1 or dg.barks - b0 < 3 or fl.played.get("dog_bark", 0) - db0 < 1 or lie_min > 0.3:
		return _combat_done(false, "Brack should sit up at the door and bark at the fox")
	if fx.fled < 1 or gone < 0 or fx.visible:
		return _combat_done(false, "the dog's barking should send the fox back out through the stile")
	if hh.shut < 0.99 or not hn.all_in():
		return _combat_done(false, "the slide should hold and the hens stay in")
	# the barking wakes Osric: his candle comes on (dark before the fox came)
	var lit_max := 0.0
	for i in 240:
		_world.time_of_day = 1.5
		await get_tree().physics_frame
		lit_max = maxf(lit_max, sc.lit)
		_osric_sample(i)
	print("BOT henfox candle: rousings %d, lit %.2f, Osric outdoors %s" % [sc.rousings, lit_max, _world.neighbour.outdoors()])
	if sc.rousings < 1 or lit_max < 0.3:
		return _combat_done(false, "Brack's barking should wake Osric and light his candle")
	# and a little after he comes out with his lantern lit to the gap in the yard wall, holds it
	# up, calls into the dark, and goes back in to bed
	var nb: Neighbour = _world.neighbour
	for i in 4000:
		if _os["back_in"] >= 0:
			break
		_world.time_of_day = 1.5
		await get_tree().physics_frame
		_osric_sample(i)
	var gap_min: float = _os["gap"]
	var lamp_max: float = _os["lamp"]
	var lift_max: float = _os["lift"]
	var sill_min: float = _os["sill"]
	var back_in: int = _os["back_in"]
	print("BOT henfox lookout: lookouts %d, out %s, at the gap %.2f m, lantern lit %.2f, lifted %.2f (ring %.2f m up, %.2f m out), calls %d, window while out %.2f, back in at frame %d, lantern shown %s" % [nb.lookouts, _os["out"], gap_min, lamp_max, lift_max, _os["ring_y"], _os["ring_out"], nb.calls, sill_min, back_in, nb.hand_lantern.visible])
	if nb.lookouts != 1 or gap_min > 0.5 or lamp_max < 0.8 or lift_max < 0.95 or nb.calls < 2:
		return _combat_done(false, "woken, Osric should come out to the gap with his lantern lit, hold it up and call out")
	if _os["ring_y"] < 1.5 or _os["ring_out"] < 0.25:
		return _combat_done(false, "Osric should hold the lantern up and out before him at chin height, not at his waist")
	print("BOT henfox lantern hand: %.2f m from his head" % _os["face_gap"])
	if _os["face_gap"] < 0.47:
		return _combat_done(false, "Osric's lantern fist should be out before him, not up beside his face")
	print("BOT henfox thumb tip: along the hand %.2f, index-ward %.2f, palm-ward %.2f" % [_os["thumb_tip"].x, _os["thumb_tip"].y, _os["thumb_tip"].z])
	print("BOT henfox fist: middle finger's first bone %.2f into the palm, its second %.2f along the hand (below 0: folded back), thumb %.2f over into the palm, its last joint %.3f m from the index's middle joint" % [_os["fist"], _os["fist_turn"], _os["fist_thumb"], _os["thumb_gap"]])
	if _os["fist"] < 0.8 or _os["fist_turn"] > -0.3 or _os["fist_thumb"] < 0.5 or _os["thumb_gap"] > 0.08 or _os["thumb_tip"].y > -0.75:
		return _combat_done(false, "Osric's fingers should close round the lantern bail, not hang open in a wave")
	print("BOT henfox face glow: energy %.2f at %.2f m up, %.2f m from his eyes" % [_os["fill"], _os["fill_y"], _os["fill_head"]])
	if _os["fill"] < 0.3 or _os["fill_y"] < 1.65 or _os["fill_head"] > 0.38:   # 1.65: the glow sits a little lower since 10-22 21:30 (higher lit a band on the brim)
		return _combat_done(false, "the held-up lantern should throw a warm glow up onto Osric's face")
	if back_in < 0 or nb.hand_lantern.visible or nb.activity != "in":
		return _combat_done(false, "Osric should go back in to bed after looking")
	if sill_min < 0.2:
		return _combat_done(false, "the candle should stay burning on the sill while he is out")
	# Brack trotted over to sit by him at the gap, and goes back to its place when he goes in
	for i in 900:
		_world.time_of_day = 1.6
		await get_tree().physics_frame
		if dg.state == Dog.BED and dg.global_position.distance_to(dg.bed) < 0.35:
			break
	print("BOT henfox brack: attends %d, nearest to Osric at the gap %.2f m, sat by him %.2f, closest to a wall on the way %.2f m, back at its place %.2f m (state %d)" % [dg.attends, _os["dog_near"], _os["dog_sit"], _os["dog_clear"], dg.global_position.distance_to(dg.bed), dg.state])
	if dg.attends != 1 or _os["dog_near"] > 1.6 or _os["dog_sit"] < 0.9 or _os["dog_clear"] < 0.3:
		return _combat_done(false, "Brack should trot over and sit by Osric at the gap while he looks out")
	if dg.state != Dog.BED or dg.global_position.distance_to(dg.bed) > 0.35:
		return _combat_done(false, "Brack should go back to its place by Edda's door when Osric goes in")
	# once a night
	for i in 600:
		_world.time_of_day = 1.6
		await get_tree().physics_frame
	if fx.prowls != 1:
		return _combat_done(false, "the fox should try the hen house only once a night (%d)" % fx.prowls)
	# the hero about the garth: it bolts back out of the stile
	fx._prowled = false
	fx.shy_t = 0.0
	dg._fox_t = 0.0
	var bolts0 := fx.bolts
	var inside := sc.to_global(Vector3(1.5, 0, -5.0))
	var scared := false
	for i in 9000:
		_world.time_of_day = 1.6
		await get_tree().physics_frame
		if fx.state == Fox.PROWL and fx._pstep == 0 and fx.path.size() <= Fox.ROUND.size() + 1 and not scared:
			_player.global_position = Vector3(inside.x, tr.height_at(inside.x, inside.z) + 0.2, inside.z)
			scared = true
		if scared and fx.state == Fox.AWAY:
			break
	print("BOT henfox scare: prowls %d, bolts %d, tries %d, state %d visible %s" % [fx.prowls, fx.bolts - bolts0, fx.tries, fx.state, fx.visible])
	if fx.prowls != 2 or fx.bolts - bolts0 < 1 or fx.tries != 1 or fx.state != Fox.AWAY:
		return _combat_done(false, "a hero in the garth should send the prowling fox off before it reaches the ladder")
	# the slide left propped: it does not come
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.2, far.z)
	fx._prowled = false
	fx.shy_t = 0.0
	hh.set_shut(false)
	for i in 900:
		_world.time_of_day = 1.6
		await get_tree().physics_frame
	if fx.prowls != 2 or fx.state == Fox.PROWL:
		return _combat_done(false, "no prowl at an open hen house")
	_combat_done(true, "a fox tries Osric's shut hen house in the small hours and Brack barks it off")

func _keeper_test() -> void:
	var k: Keeper = _world.keeper
	var wx: Weather = _world.weather
	wx.force(0.0)
	_player.global_position = Vector3(0, _player.global_position.y, 0)
	# her own cut: no hat, a basket of deadwood on her back, an ankle robe, a stooped head
	# (2 s: her shoulders square up off the idle's chest turn)
	await _ticks(130)
	var hb := k.skel.find_bone("mixamorig_Head")
	# the stoop: how far the face cloth (it rides the head bone through its attachment, which
	# sees the Crumple modifier; bone poses read here do not) sits forward of the feet
	var lean := func(g: HeroGarb, b: Node3D) -> float:
		var c := g.veil.global_transform * g.veil.get_aabb().get_center()
		return (b.global_basis.inverse() * (c - b.global_position)).z
	var head_k: float = lean.call(k.garb, k.body)
	var head_p: float = lean.call(_player.garb, _player.get_node("Body"))
	var bk := k.garb.basket_node
	var meshes := bk.find_children("*", "MeshInstance3D", true, false).size() if bk != null else 0
	var bpos := k.body.global_basis.inverse() * ((bk.get_child(0) as MeshInstance3D).global_transform * (bk.get_child(0) as MeshInstance3D).get_aabb().get_center() - k.body.global_position) if bk != null else Vector3.ZERO
	var hem := func(g: HeroGarb) -> float:
		var lo := INF
		for piv in [g._front, g._back]:
			var mi := (piv as Node3D).get_child(0) as MeshInstance3D
			lo = minf(lo, (mi.global_transform * mi.get_aabb()).position.y)
		return lo
	var hem_k: float = hem.call(k.garb) - k.global_position.y
	var hem_p: float = hem.call(_player.garb) - _player.global_position.y
	print("BOT keeper cut: hat %s, basket %d meshes at body %s, face %.2f m ahead of the feet (hero %.2f), robe hem %.2f m (hero %.2f)" % [k.garb.hat != null, meshes, bpos, head_k, head_p, hem_k, hem_p])
	if absf(bpos.x) > 0.05:
		return _combat_done(false, "Hesper's basket hangs %.2f m off her spine" % bpos.x)
	if k.garb.hat != null or meshes < 10 or bpos.z > -0.2 or bpos.y < 0.9 or head_k < head_p + 0.06 or hem_k > hem_p - 0.06 or hem_k < 0.0:
		return _combat_done(false, "Hesper still cut like the hero (hat, no basket on her back, not stooped or robe not to the ankles)")
	# the skirt: a gore each side, outside the knees, from the sash down past the shins
	var gore_ok := k.garb.gores.size() == 2
	var gore_txt := ""
	for side in ["Left", "Right"]:
		var kb := k.skel.find_bone("mixamorig_%sLeg" % side)
		var knee := k.body.global_basis.inverse() * (k.skel.global_transform * k.skel.get_bone_global_pose(kb).origin - k.body.global_position)
		var outer := 0.0
		var lo := INF
		var hi := -INF
		for g in k.garb.gores:
			var bb: AABB = g.global_transform * g.get_aabb()
			var c := k.body.global_basis.inverse() * (bb.get_center() - k.body.global_position)
			if signf(c.x) == signf(knee.x):
				outer = absf(c.x) + bb.size.x * 0.25
				lo = bb.position.y - k.global_position.y
				hi = bb.end.y - k.global_position.y
		var fb := k.skel.find_bone("mixamorig_%sFoot" % side)
		var foot := k.body.global_basis.inverse() * (k.skel.global_transform * k.skel.get_bone_global_pose(fb).origin - k.body.global_position)
		gore_txt += "%s knee %s foot %s gore x %.2f y %.2f..%.2f; " % [side, knee, foot, outer, lo, hi]
		if outer < absf(knee.x) + 0.05 or lo > 0.3 or hi < 1.0:
			gore_ok = false
	print("BOT keeper skirt: %d gores, %s" % [k.garb.gores.size(), gore_txt])
	if not gore_ok:
		return _combat_done(false, "Hesper's robe does not close into a skirt at the sides")
	var log := []
	for leg in [[8.0, "tend"], [11.0, "gather"], [13.0, "eat"], [14.0, "wander"], [14.1, "wander"], [22.0, "sleep"], [6.0, "wake"]]:
		_world.time_of_day = leg[0]
		var n0 := int(k.visits.get(leg[1], 0))
		if leg[1] == "wander" and k.activity == "wander" and k.state == Keeper.STAND:
			k._gather_t = 0.05                 # the next stop of her walk
		var t := 0.0
		var breach := false
		var through_wall := false
		while int(k.visits.get(leg[1], 0)) <= n0 and t < 240.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			var r := Vector2(k.global_position.x - k.site.x, k.global_position.z - k.site.z)
			var ang := absf(r.angle_to(Vector2(k.to_v.x, k.to_v.z)))
			if r.length() > 2.9 and r.length() < 4.4:
				if ang < 0.45:
					breach = true
				else:
					through_wall = true
			if r.length() > 12.1 and r.length() < 12.9 and ang > 0.2:
				through_wall = true            # over the curtain wall, not through the gateway
		var at := k.global_position
		var inside := Vector2(at.x - k.site.x, at.z - k.site.z).length() < 3.0
		log.append("%s %.0fs in=%s breach=%s wall=%s" % [leg[1], t, inside, breach, through_wall])
		print("BOT keeper %.1f h: %s after %.1f s at %s, inside keep %s, through breach %s, crossed wall %s" % [leg[0], k.activity, t, at, inside, breach, through_wall])
		if int(k.visits.get(leg[1], 0)) <= n0:
			return _combat_done(false, "did not reach her %s spot" % leg[1])
		if through_wall:
			return _combat_done(false, "walked through the keep wall going to %s" % leg[1])
		if leg[1] in ["tend", "sleep"] and not inside:
			return _combat_done(false, "%s should be on the keep floor" % leg[1])
		if leg[1] in ["gather", "eat"] and inside:
			return _combat_done(false, "%s should be out under the oaks" % leg[1])
		if leg[1] == "gather":
			# working the litter: she crouches and reaches, and stays put while she does
			var p0 := k.picks
			var deep := 0.0
			var drift := 0.0
			var drop := 0.0
			var hand_lo := INF     # the wrist: the fingers reach ~0.18 m further, into the litter
			var hand_back := -INF
			var at0 := k.global_position
			var tg := 0.0
			var t0 := k.tosses
			var to_mouth := INF    # the hand at the top of its toss, from the basket mouth
			var held_seen := false
			var tipped := 0.0
			var knee_fold := 0.0
			var hem_lo := INF
			var gore_gap := 0.0
			while (k.picks < p0 + 2 or k._toss_t >= 0.0) and tg < 40.0:
				await get_tree().physics_frame
				tg += get_physics_process_delta_time()
				if k.pick > deep:
					deep = k.pick
					drop = -k.model.position.y
				var hm: Vector3 = k.hand_mark.global_position
				if k.pick > 0.97:
					hand_lo = minf(hand_lo, hm.y - _world.terrain.height_at(hm.x, hm.z))
					# the robe hangs: front over the knees, both hems at or above the litter
					var g: HeroGarb = k.garb
					tipped = maxf(tipped, g.tip)
					knee_fold = maxf(knee_fold, g.fold_front.y)
					for pf in [[g._front, g.fold_front, g.fold_front2], [g._back, g.fold_back, Vector2(1000, 0)]]:
						var pv: Node3D = pf[0]
						var f1: Vector2 = pf[1]
						var f2: Vector2 = pf[2]
						var ln: float = pv.get_meta("len", 1.0)
						# the hem through both folds, in the panel's own space, then to the world
						var e := Vector2(-ln, 0.0)      # (y, z)
						for fo in [f2, f1]:
							if -e.x > fo.x:
								e = Vector2(e.x + fo.x, e.y).rotated(fo.y) - Vector2(fo.x, 0.0)
						var stoop_hem: Vector3 = pv.global_transform * Vector3(0, e.x, e.y)
						hem_lo = minf(hem_lo, stoop_hem.y - _world.terrain.height_at(stoop_hem.x, stoop_hem.z))
						if pv == g._front and not g.gores.is_empty():
							# the gores' front ends close on the front panel's hem corners
							var hw: float = pv.get_meta("w1", 0.5) * 0.5
							for gi in 2:
								var gh: Vector3 = g.gore_hem(gi, 0.0)
								var corner: Vector3 = pv.global_transform * Vector3(hw * (-1.0 if gi == 0 else 1.0), e.x, e.y)
								gore_gap = maxf(gore_gap, gh.distance_to(corner))
								hem_lo = minf(hem_lo, gh.y - _world.terrain.height_at(gh.x, gh.z))
				if k._back_hand > 0.9 and k.pick < 0.3:
					# behind the body's centre line: the hand is on her back
					hand_back = maxf(hand_back, -(k.body.global_basis.inverse() * (hm - k.global_position)).z)
				if k._held.visible:
					held_seen = true
				if k.toss > 0.95:
					var bn: Node3D = k.garb.basket_node
					# the near (right-hand) side of the rim: the 0.3 m stick reaches on into the mouth
					var mouth := bn.global_transform * Vector3(-0.15, HeroGarb.BASKET_TOP, HeroGarb.BASKET_Z)
					to_mouth = minf(to_mouth, hm.distance_to(mouth))
				if k.pick > 0.05:
					drift = maxf(drift, Vector2(k.global_position.x - at0.x, k.global_position.z - at0.z).length())
			print("BOT keeper gather: %d picks in %.1f s, deepest %.2f (body drop %.2f m), hand %.2f m off the litter, %.2f m behind her rising, drifted %.2f m while stooped" % [k.picks - p0, tg, deep, drop, hand_lo, hand_back, drift])
			print("BOT keeper robe: pelvis tip %.2f rad, front fold over the knees %.2f rad, lowest hem %.2f m off the litter, gore ends %.2f m from the front hem corners" % [tipped, knee_fold, hem_lo, gore_gap])
			if knee_fold < 0.3 or hem_lo < -0.1 or gore_gap > 0.25:
				return _combat_done(false, "her robe should hang over her knees and stay out of the ground when she stoops")
			print("BOT keeper toss: %d finds into the basket, stick seen in hand %s, hand %.2f m from the rim at the top of the toss" % [k.tosses - t0, held_seen, to_mouth])
			if k.tosses - t0 < 2 or not held_seen or to_mouth > 0.14:
				return _combat_done(false, "her finds should go over her shoulder into the basket")
			if k.picks < p0 + 2 or deep < 0.95 or drop < 0.12 or drift > 0.3 or hand_lo > 0.26 or hand_lo < -0.05 or hand_back < 0.0:
				return _combat_done(false, "did not stoop to pick at the litter under the oaks")
		if leg[1] == "wander":
			var wr := Vector2(at.x - k.site.x, at.z - k.site.z).length()
			var hd := Vector2(at.x - _world.herd.centre().x, at.z - _world.herd.centre().z).length()
			var slope := (_world.get_node("Terrain") as Terrain).normal_at(at.x, at.z, 1.5).y
			print("BOT keeper wander: stop %d at r %.1f from the keep, herd centre %.1f m off, ground normal %.2f" % [k.wander_stops.size(), wr, hd, slope])
			if wr < 18.0 or wr > 47.0:
				return _combat_done(false, "her meadow walk should stop 20-45 m out, got %.1f" % wr)
			# the herd knows her: grazing near her they look up and watch, they never bolt
			var hd2: Herd = _world.herd
			hd2.place(at + Vector3(10, 0, 6))
			var g0 := hd2.glances
			var f0 := hd2.flee_events
			var tw := 0.0
			while tw < 40.0:
				await get_tree().physics_frame
				tw += get_physics_process_delta_time()
			print("BOT keeper herd: %d glances at her in %.0f s, state %d, flee events %d" % [hd2.glances - g0, tw, hd2.state, hd2.flee_events - f0])
			if hd2.glances - g0 < 2 or hd2.flee_events != f0:
				return _combat_done(false, "the deer near her should look up at her and not flee")
		if leg[1] == "sleep":
			await _ticks(200)
			print("BOT keeper: dozing sit %.2f, model drop %.2f" % [k.sit, k.model.position.y])
			if k.sit < 0.95:
				return _combat_done(false, "did not sit down to doze")
			var fb: Node3D = k._floor_basket
			var fb_mi := fb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var fb_low: float = (fb_mi.global_transform * fb_mi.get_aabb()).position.y - _world.get_node("Terrain").height_at(fb.global_position.x, fb.global_position.z)
			var fb_r: float = Vector2(fb.global_position.x - k.site.x, fb.global_position.z - k.site.z).length()
			print("BOT keeper: worn basket %s, floor basket %s at r %.2f, %.2f m off the floor" % [k.garb.basket_node.visible, fb.visible, fb_r, fb_low])
			if k.garb.basket_node.visible or not fb.visible or fb_r > 2.9 or absf(fb_low) > 0.12:
				return _combat_done(false, "basket not set down on the keep floor for the night")
	# rain: breaks off and gets under an oak crown
	_world.time_of_day = 11.0
	await _ticks(30)
	wx.force(1.0)
	var t2 := 0.0
	while int(k.visits.get("shelter", 0)) < 1 and t2 < 240.0:
		await get_tree().physics_frame
		t2 += get_physics_process_delta_time()
	var sh := wx.shelter_at(k.global_position.x, k.global_position.z)
	print("BOT keeper rain: %s after %.1f s, crown shelter %.2f" % [k.activity, t2, sh])
	if k.activity != "shelter" or int(k.visits.get("shelter", 0)) < 1 or sh < 0.3:
		return _combat_done(false, "did not shelter under an oak in the rain")
	wx.force(0.0)
	await _ticks(20)
	if k.activity == "shelter":
		return _combat_done(false, "kept sheltering after the rain stopped")
	# the hero walks up: she stops, turns to him and the HUD names her
	var fwd := Vector3(sin(k.body.rotation.y), 0, cos(k.body.rotation.y))
	var pp := k.global_position + fwd.rotated(Vector3.UP, 2.2) * 3.5
	_player.global_position = Vector3(pp.x, _world.get_node("Terrain").height_at(pp.x, pp.z) + 0.3, pp.z)
	await _ticks(150)
	var d := _player.global_position - k.global_position
	var face := absf(wrapf(atan2(d.x, d.z) - k.body.rotation.y, -PI, PI))
	var hud: Hud = _player.get_node("Hud")
	print("BOT keeper meet: noticing %s, facing off %.2f rad, speed %.2f, caption '%s'" % [k.noticing, face, Vector2(k.velocity.x, k.velocity.z).length(), hud.caption_title])
	if not k.noticing or face > 0.35 or hud.caption_title != "Hesper":
		return _combat_done(false, "did not stop, face and get named when the hero came up")
	print("BOT keeper: warps %d, last at r %.1f from the keep (%s)" % [k.warps, Vector2(k.last_warp.x - k.site.x, k.last_warp.z - k.site.z).length(), k.last_warp])
	if k.warps > 1:
		return _combat_done(false, "got wedged %d times" % k.warps)
	_combat_done(true, "day kept: %s; sheltered in rain, faced and named on meeting" % ", ".join(log))

func _talk_test() -> void:
	var k: Keeper = _world.keeper
	var hud: Hud = _player.get_node("Hud")
	var terrain: Terrain = _world.get_node("Terrain")
	_world.weather.force(0.0)
	_world.time_of_day = 9.0
	k.settle(_world, 9.0)
	await _ticks(10)
	# out of reach: no prompt, a press says nothing
	var far := k.global_position + Vector3(0, 0, 6.0)
	_player.global_position = Vector3(far.x, terrain.height_at(far.x, far.z) + 0.3, far.z)
	await _ticks(20)
	_player.bot_interact = true
	await _ticks(20)
	print("BOT talk far: prompt '%s' talks %d" % [hud.prompt_key if hud._prompt_hold > 0.0 else "", k.talks])
	if k.talks > 0:
		return _combat_done(false, "she answered from out of reach")
	# step up beside her on the keep floor (round the plinth from her tend spot)
	var side := (k.global_position - k.site)
	side.y = 0.0
	var pp := k.global_position + side.normalized().rotated(Vector3.UP, 1.3) * 1.6
	_player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.3, pp.z)
	await _ticks(40)
	print("BOT talk near: prompt '%s %s' (hold %.2f)" % [hud.prompt_key, hud.prompt_verb, hud._prompt_hold])
	if hud._prompt_hold <= 0.0 or hud.prompt_verb != "Speak":
		return _combat_done(false, "no Speak prompt beside her")
	var heard := []
	var p0 := k.global_position
	for i in 4:
		_player.bot_interact = true
		await _ticks(3)
		heard.append(k.last_line)
		print("BOT talk %d: '%s' | hud '%s: %s' saying %s" % [i, k.last_line, hud.say_speaker, hud.say_line, hud.saying()])
		if hud.say_line != k.last_line or hud.say_speaker != "Hesper" or not hud.saying():
			return _combat_done(false, "her line did not show as a subtitle")
		await _ticks(60)
	if k.talks != 4 or heard[0] != Keeper.INTRO[0] or heard[2] != Keeper.INTRO[2] or not (heard[3] in Keeper.LINES["tend"]):
		return _combat_done(false, "lines out of order: %s" % [heard])
	var d := _player.global_position - k.global_position
	var face := absf(wrapf(atan2(d.x, d.z) - k.body.rotation.y, -PI, PI))
	var moved := Vector2(k.global_position.x - p0.x, k.global_position.z - p0.z).length()
	print("BOT talk: facing off %.2f rad, moved %.2f m while talking" % [face, moved])
	if face > 0.4 or moved > 0.3:
		return _combat_done(false, "did not hold still facing the hero while talking")
	# the subtitle clears after its time
	var t := 0.0
	while hud.saying() and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if hud.saying():
		return _combat_done(false, "subtitle never cleared")
	# dozing at night (past the hour she sits up warming her hands): only a mumble, and she
	# stays down
	_world.time_of_day = 1.0
	k.settle(_world, 1.0)
	var sp := k.global_position + (k.site - k.global_position).normalized() * 1.4
	_player.global_position = Vector3(sp.x, terrain.height_at(sp.x, sp.z) + 0.3, sp.z)
	await _ticks(30)
	var verb := hud.prompt_verb
	_player.bot_interact = true
	await _ticks(5)
	print("BOT talk doze: prompt '%s', line '%s', sit %.2f" % [verb, k.last_line, k.sit])
	if verb != "Listen" or not (k.last_line in Keeper.LINES["sleep"]) or k.sit < 0.95:
		return _combat_done(false, "dozing she should only mumble")
	_combat_done(true, "intro x3 then a tend line, subtitled, facing him; mumbles in her doze")

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
	# the walled keep: none drift in there to sit on the lens by Hesper's fire
	var ks: Vector3 = _world.get_node("Flora").ruin_site
	p.global_position = Vector3(ks.x + 2.0, terrain.height_at(ks.x + 2.0, ks.z) + 0.2, ks.z)
	await _ticks(240)
	var in_keep := 0
	var near_keep := 0
	for f in ins.firefly_positions():
		var dk := Vector2(f.x - ks.x, f.z - ks.z).length()
		if dk < Insects.KEEP_OUT - 0.3:
			in_keep += 1
		elif dk < Insects.KEEP_OUT + 12.0:
			near_keep += 1
	print("BOT insects keep: %d fireflies inside the keep walls, %d in the grass round it" % [in_keep, near_keep])
	if in_keep > 0 or near_keep < 5:
		return _combat_done(false, "fireflies inside the keep, or none round it")
	# the small hours: the display has thinned to a few stragglers
	_world.time_of_day = 1.5
	await _ticks(90)
	var late_lit := ins.visible_fireflies()
	print("BOT insects small hours: lit %d (at 22:00 %d), share %.2f" % [late_lit, lit, ins.late_share])
	if late_lit > lit * 0.45 or late_lit < 1:
		return _combat_done(false, "fireflies not thinned after midnight, or none left at all")
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
			# a pool ~5 m long along the run, so two walking footfalls land in it
			var long_pool := true
			for k in 7:
				long_pool = long_pool and wx.pool_at(q.x + k * 0.8 - 2.4, q.z)
			if long_pool \
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
	_player.bot_input = Vector2(0, -0.5)   # walk, not run: at 6.5 m/s one stride clears a puddle
	while _player.global_position.x < pool.x - 3.2 and dry_steps < 600:
		await get_tree().physics_frame
		dry_steps += 1
		if wx.pool_at(_player.global_position.x, _player.global_position.z):
			break
	var w_dry := wx.wade_splashes - w0
	var rings := 0
	# walk on across the pool (it reaches ~2.4 m past its centre) for up to 3 s
	for i in 180:
		await get_tree().physics_frame
		rings = maxi(rings, wx.wake_rings())
		if i >= 50 and (_player.global_position.x > pool.x + 2.3 or wx.wade_splashes - w0 - w_dry >= 2):
			break
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

## A kite hunts: it leaves its circle, slants down at a feeding flock, the rooks go up and a
## few mob it close on its tail while it climbs back, then let it go and the flock settles.
func _kite_test() -> void:
	var birds: Birds = _world.get_node("Birds")
	var terrain: Terrain = _world.get_node("Terrain")
	_player.global_position = Vector3(0, terrain.height_at(0, 0) + 1.0, 0)
	_world.time_of_day = 11.0
	await _ticks(120)
	# a soaring kite whistles, and the soundscape plays it from up where the kite is
	var ss: Soundscape = _world.soundscape
	var sc0 := ss.kite_calls
	birds._kites[0].call_t = 0.0
	await _ticks(10)
	var voice: AudioStreamPlayer3D = ss._kite_voice
	var up := voice.global_position.y - terrain.height_at(voice.global_position.x, voice.global_position.z)
	print("BOT kite call: %d soaring call(s), voice %.0f m up, %.1f s long" % [ss.kite_calls - sc0, up, voice.stream.get_length() if voice.stream else 0.0])
	if ss.kite_calls == sc0 or up < 40.0 or voice.stream == ss._kite_harsh:
		return _combat_done(false, "a soaring kite did not whistle from the sky")
	var k: Birds.Bird = null
	for kk: Birds.Bird in birds._kites:
		var c0: int = birds.census()["ground"]
		if c0 > 0 and birds.stoop(kk):
			k = kk
			break
	if k == null:
		return _combat_done(false, "no kite could find a feeding flock to stoop at")
	var fl: Birds.Flock = k.prey
	var site: Vector3 = birds._sites[fl.site]
	var h0 := k.pos.y - terrain.height_at(k.pos.x, k.pos.z)
	var s0 := birds.scatter_events
	var lo := INF
	var t := 0.0
	while k.hunt == Birds.STOOP and t < 60.0:
		await _ticks(10)
		t += 10.0 / 60.0
		lo = minf(lo, k.pos.y - terrain.height_at(k.pos.x, k.pos.z))
	print("BOT kite stoop: from %.0f m up, down to %.0f m over the meadow in %.1f s, %d m from the flock" % [h0, lo, t, int(Vector2(k.pos.x - site.x, k.pos.z - site.z).length())])
	if k.hunt != Birds.MOBBED or birds.scatter_events == s0 or fl.state != Birds.AIR:
		return _combat_done(false, "the stoop did not put the flock up")
	if lo > h0 - 20.0:
		return _combat_done(false, "the kite did not come down on the flock")
	var n := 0
	for b: Birds.Bird in fl.birds:
		if b.mob == k:
			n += 1
	t = 0.0
	var caws0 := birds.mob_caws
	var climb_lo := k.pos.y
	var harsh := 0
	var heard := ss.kite_calls
	while k.hunt == Birds.MOBBED and t < 40.0:
		await _ticks(10)
		t += 10.0 / 60.0
		if ss.kite_calls != heard:
			heard = ss.kite_calls
			if voice.stream == ss._kite_harsh:
				harsh += 1
	print("BOT kite harsh: the mobbed kite shrieked %d times in %.1f s" % [harsh, t])
	if harsh == 0:
		return _combat_done(false, "the mobbed kite never shrieked")
	print("BOT kite mobbed: %d rooks on it, closest %.1f m, %d mob caws, climbed %.0f m in %.1f s" % [n, birds.mob_closest, birds.mob_caws - caws0, k.pos.y - climb_lo, t])
	if n < 3 or birds.mob_closest > 4.0:
		return _combat_done(false, "the rooks did not mob the kite")
	if k.pos.y - climb_lo < 15.0:
		return _combat_done(false, "the kite did not climb away from the mob")
	t = 0.0
	while (k.hunt != Birds.SOAR or fl.state != Birds.GROUND) and t < 120.0:
		await _ticks(30)
		t += 0.5
	var stray := 0
	for b: Birds.Bird in fl.birds:
		if b.mob != null:
			stray += 1
	print("BOT kite after: kite %s, flock %s after %.1f s, %d still mobbing" % [["soaring", "stooping", "mobbed", "rejoining"][k.hunt], ["ground", "air", "landing", "perch"][fl.state], t, stray])
	if k.hunt != Birds.SOAR or fl.state != Birds.GROUND or stray > 0:
		return _combat_done(false, "kite or flock did not go back to soaring / feeding")
	_combat_done(true, "a kite stoops at the rooks, they mob it back up into the sky, then settle")

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

## Moss collars: every oak bole has moss at its foot, more on the shaded side than the
## sunny side; the big boulders have moss round their feet; the open meadow has none.
func _moss_test() -> void:
	var flora: Flora = _world.get_node("Flora")
	var collared := 0
	var shaded_more := 0
	for xf in flora.tree_xforms:
		var c := Vector2(xf.origin.x, xf.origin.z)
		var r := 0.5 * xf.basis.get_scale().x + 1.0
		var sh := c + Flora.MOSS_SHADE * r
		var su := c - Flora.MOSS_SHADE * r
		if flora.moss_at(sh.x, sh.y) > 0.3:
			collared += 1
		if flora.moss_at(sh.x, sh.y) > flora.moss_at(su.x, su.y):
			shaded_more += 1
	var rocks := 0
	var big := 0
	for f in flora._rock_feet:
		if f.y < 1.4:
			continue
		big += 1
		if flora.moss_at(f.x + f.y * 0.9, f.z) > 0.2 or flora.moss_at(f.x - f.y * 0.9, f.z) > 0.2:
			rocks += 1
	# the open meadow round the village has no collars
	var open_moss := 0.0
	for k in 64:
		var a := k * TAU / 64.0
		open_moss = maxf(open_moss, flora.moss_at(cos(a) * 30.0, sin(a) * 30.0))
	# the meadow gives way to the moss: grass sites on full cushions are rare next to the
	# same terrain a few metres out in the open
	var grass := _world.get_node("Grass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var on_moss := 0
	var on_tries := 0
	for xf in flora.tree_xforms:
		var c := Vector2(xf.origin.x, xf.origin.z)
		for k in 6:
			var a := k * TAU / 6.0
			var q := c + Vector2(cos(a), sin(a)) * (0.5 * xf.basis.get_scale().x + 0.6)
			if flora.moss_at(q.x, q.y) < 0.6:
				continue
			on_tries += 1
			if grass._site(q.x, q.y, rng, flora).x >= 0.0:
				on_moss += 1
	var open_ok := 0
	for k in 400:
		var a := k * TAU / 400.0
		if grass._site(cos(a) * (20.0 + k % 20), sin(a) * (20.0 + k % 20), rng, flora).x >= 0.0:
			open_ok += 1
	var moss_rate := float(on_moss) / maxf(on_tries, 1)
	var open_rate := open_ok / 400.0
	print("BOT moss grass: %d/%d sites on full moss grow grass (%.2f), open meadow %.2f" % [on_moss, on_tries, moss_rate, open_rate])
	var n := flora.tree_xforms.size()
	print("BOT moss: %d/%d oaks collared, %d shaded side mossier, %d/%d big boulders ringed, open meadow max %.2f" % [collared, n, shaded_more, rocks, big, open_moss])
	# surface roots: every root dives into the soil at its tip and never floats clear of it
	var terr: Terrain = _world.get_node("Terrain")
	var buried := 0
	for q in flora.root_tips:
		if q.y < terr.height_at(q.x, q.z) + 0.02:
			buried += 1
	var root_meshes := 0
	var floating := 0
	var verts := 0
	for c in flora.get_children():
		if c is MeshInstance3D and c.name.begins_with("OakRoots"):
			root_meshes += 1
			var arr: Array = c.mesh.surface_get_arrays(0)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			verts += vs.size()
			for vi in range(0, vs.size(), 5):
				var v := vs[vi]
				if v.y - terr.height_at(v.x, v.z) < 0.45:
					continue
				# only the buttress against the bole may stand that high
				var near := false
				for t in flora.tree_xforms:
					if Vector2(t.origin.x - v.x, t.origin.z - v.z).length() < 1.35 * t.basis.get_scale().x:
						near = true
						break
				if not near:
					floating += 1
	var nroots := flora.root_tips.size()
	print("BOT roots: %d roots on %d oaks in %d chunks (%d verts), %d tips buried, %d verts >0.45 m above the soil away from a bole" % [nroots, n, root_meshes, verts, buried, floating])
	_combat_done(collared >= n * 0.95 and shaded_more >= n * 0.9 and rocks >= big * 0.9 and big > 0 and open_moss < 0.05
		and on_tries > 100 and moss_rate < 0.08 and open_rate > 0.3
		and nroots >= n * 4 and buried >= nroots * 0.97 and floating == 0 and root_meshes > 0,
		"moss collars at the oak boles and boulder feet, none in the open meadow, no tall grass on the cushions, surface roots run out from every bole into the soil")

func _trample_test() -> void:
	var p := _player
	var tr: Trample = _world.trample
	# the point counts below are global: hold Hesper still so only the hero lays a trail
	_world.keeper.set_physics_process(false)
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

## The stone cottage: built (stones, slates, smoke), clear of the timber house, the hero
## walks up the step and in through the door, the back wall stops him inside, and the
## windows light at dusk.
func _stonehouse_test(c: StoneCottage = null) -> void:
	var p := _player
	if c == null:
		c = _world.stone_cottage
	if Cottage.inside(c.global_position.x, c.global_position.z, c.wlen * 0.5 + 1.0):
		return _combat_done(false, "the stone cottage overlaps the timber house")
	if c != _world.stone_cottage and (StoneCottage.inside(c.global_position.x, c.global_position.z, c.wlen * 0.5 + 1.0) or YardWall.near(c.global_position.x, c.global_position.z, c.wlen * 0.5 + 1.0)):
		return _combat_done(false, "the white cottage overlaps the stone cottage or the yard")
	print("BOT stonehouse: %d stones, %d slates, %d colliders, floor %.2f m, base %.2f m" % [c.stone_count, c.slate_count, c.get_node("StoneCottageCollision").get_child_count(), c.floor_y, c.base_y])
	if c.stone_count < 450 or c.slate_count < 800:
		return _combat_done(false, "cottage walls or roof not built")
	var flora: Flora = _world.get_node("Flora")
	var near := 99.0
	for q in flora.tree_positions + flora.rock_positions:
		near = minf(near, Vector2(q.x - c.global_position.x, q.z - c.global_position.z).length())
	print("BOT stonehouse: nearest tree/rock %.1f m" % near)
	if near < 6.0:
		return _combat_done(false, "a tree or rock stands in the cottage")
	var out := c.global_basis.z
	var start := c.door_gap + out * 6.0
	var terrain: Terrain = _world.get_node("Terrain")
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	for wp in [c.door_gap + out * 1.5, c.door_gap, c.global_position]:
		var t := 0.0
		while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length() > 0.6 and t < 15.0:
			var d := Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).normalized()
			p.bot_input = d
			await _ticks(6)
			t += 0.1
		print("BOT stonehouse reached %s in %.1f s, at %s" % [wp, t, p.global_position])
		if t >= 15.0:
			p.bot_input = Vector2.ZERO
			return _combat_done(false, "could not walk into the cottage (stuck at %s)" % p.global_position)
	var fy := c.global_position.y + c.floor_y
	print("BOT stonehouse: inside at y %.2f, floor %.2f" % [p.global_position.y, fy])
	if absf(p.global_position.y - fy) > 0.3:
		return _combat_done(false, "not standing on the cottage floor")
	var t2 := 0.0
	var far := 0.0
	while t2 < 4.0:
		p.bot_input = Vector2(-out.x, -out.z)
		p.bot_sprint = true
		await _ticks(6)
		t2 += 0.1
		far = maxf(far, (p.global_position - c.global_position).dot(-out))
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	print("BOT stonehouse: ran at the back wall, got %.2f m in from the centre" % far)
	if far > c.wdep * 0.5 - StoneCottage.T + 0.1:
		return _combat_done(false, "walked through the cottage back wall")
	_world.time_of_day = 12.0
	await _ticks(2)
	var noon := c.lit
	_world.time_of_day = 19.5
	await _ticks(2)
	if c is WhiteCottage and _world.villager != null:
		# Edda's lamp: dark while she sits out, lit once she has gone in for the night
		_world.villager.settle(_world, 19.9)
		await _ticks(200)
		var out_lit := c.lit
		_world.time_of_day = 21.0
		_world.villager.settle(_world, 21.0)
		await _ticks(200)
		print("BOT whitehouse: lamp %.2f while she sits out at 19:54, %.2f once she is in" % [out_lit, c.lit])
		if out_lit > 0.05:
			return _combat_done(false, "the lamp burns with nobody in")
	elif not c is WhiteCottage and _world.get("neighbour") != null:
		# Osric's lamp: dark while he sees the hens up at 19:30, lit once he is in at 21:00
		var nb: Node = _world.get("neighbour")
		nb.settle(_world, 19.5)
		await _ticks(200)
		var out_lit := c.lit
		_world.time_of_day = 21.2
		nb.settle(_world, 21.2)
		await _ticks(200)
		print("BOT stonehouse: lamp %.2f while Osric is out at 19:30, %.2f once he is in" % [out_lit, c.lit])
		if out_lit > 0.05:
			return _combat_done(false, "the lamp burns with nobody in")
	print("BOT stonehouse: window light noon %.2f, 19:30 %.2f, smoke %s" % [noon, c.lit, c.smoke.emitting])
	if noon > 0.01 or c.lit < 0.9 or not c.smoke.emitting:
		return _combat_done(false, "windows not lit at dusk or no chimney smoke")
	_combat_done(true, "walked up the step and in at the door, the walls hold, windows light at dusk")

func _leanto_test() -> void:
	var p := _player
	var c: WhiteCottage = _world.white_cottage
	var terrain: Terrain = _world.get_node("Terrain")
	print("BOT leanto: %d wall stones, %d logs, %d slates on the house+lean-to, floor %.2f" % [c.lean_stones, c.logs, c.slate_count, c.lean_floor])
	if c.lean_stones < 60 or c.logs < 60 or c.get_node_or_null("ChoppingBlock") == null:
		return _combat_done(false, "lean-to walls, woodpile or chopping block not built")
	var gx := c.wlen * 0.5
	var mid := c.to_global(Vector3(gx + (WhiteCottage.LEAN_D - StoneCottage.T) * 0.5, 0, 0))
	var flora: Flora = _world.get_node("Flora")
	var near := 99.0
	for q in flora.tree_positions + flora.rock_positions:
		near = minf(near, Vector2(q.x - mid.x, q.z - mid.z).length())
	print("BOT leanto: nearest tree/rock %.1f m" % near)
	if near < 3.5:
		return _combat_done(false, "a tree or rock stands in the lean-to")
	if StoneCottage.inside(mid.x, mid.z, 3.0) or Cottage.inside(mid.x, mid.z, 2.0) or YardWall.near(mid.x, mid.z, 2.0):
		return _combat_done(false, "the lean-to runs into another house or the yard wall")
	# headroom at the open end: the rafters must clear a walker
	var head := c.lean_top(gx + 0.85) - WhiteCottage.RAFTER + c.floor_y - c.lean_floor
	print("BOT leanto: headroom %.2f m in the middle of the open end" % head)
	if head < 1.95:
		return _combat_done(false, "no headroom under the lean-to roof")
	# walk in from the green through the open end, to just in front of the woodpile
	var front := c.to_global(Vector3(gx + 0.8, 0, WhiteCottage.LEAN_Z + 2.4))
	p.global_position = Vector3(front.x, terrain.height_at(front.x, front.z) + 0.5, front.z)
	await _ticks(20)
	var inner := c.to_global(Vector3(gx + 0.8, 0, -0.05))
	for wp in [c.to_global(Vector3(gx + 0.8, 0, WhiteCottage.LEAN_Z + 0.4)), inner]:
		var t := 0.0
		while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length() > 0.45 and t < 12.0:
			p.bot_input = Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).normalized()
			await _ticks(6)
			t += 0.1
		print("BOT leanto reached %s in %.1f s" % [wp, t])
		if t >= 12.0:
			p.bot_input = Vector2.ZERO
			return _combat_done(false, "could not walk into the lean-to (stuck at %s)" % c.to_local(p.global_position))
	# sprint at the outer wall and at the woodpile's end wall from the middle: both hold
	# (only a crossing in line with the wall counts; sliding out round the open end does not)
	var lims := []
	for dirl in [Vector3.RIGHT, Vector3.FORWARD]:
		p.global_position = Vector3(inner.x, terrain.height_at(inner.x, inner.z) + 0.3, inner.z)
		p.velocity = Vector3.ZERO
		await _ticks(10)
		var d: Vector3 = c.global_basis * dirl
		var t2 := 0.0
		var far := -99.0
		while t2 < 2.0:
			p.bot_input = Vector2(d.x, d.z).normalized()
			p.bot_sprint = true
			await _ticks(3)
			t2 += 0.05
			var l := c.to_local(p.global_position)
			if (dirl.x > 0.5 and absf(l.z) < WhiteCottage.LEAN_Z - 0.4) or (dirl.x < 0.5 and l.x > gx + 0.3 and l.x < gx + WhiteCottage.LEAN_D - StoneCottage.T - 0.3):
				far = maxf(far, l.dot(dirl))
		lims.append(far)
		p.bot_input = Vector2.ZERO
		p.bot_sprint = false
		await _ticks(10)
	print("BOT leanto: ran at the outer wall to x %.2f (inner face %.2f), at the back to z %.2f (wall face %.2f)" % [lims[0], gx + WhiteCottage.LEAN_D - StoneCottage.T, -lims[1], -WhiteCottage.LEAN_Z + StoneCottage.T])
	if lims[0] > gx + WhiteCottage.LEAN_D - StoneCottage.T + 0.05:
		return _combat_done(false, "walked through the lean-to's outer wall")
	if -lims[1] < -WhiteCottage.LEAN_Z - 0.05:
		return _combat_done(false, "walked through the lean-to's end wall")
	_combat_done(true, "lean-to built clear of trees and houses, walked in at its open end, its walls hold")

func _lantern_test() -> void:
	var p := _player
	var lp: LanternPost = _world.lantern_post
	if lp == null or lp.get_node_or_null("Post") == null or lp.pivot.get_node_or_null("Lantern") == null:
		return _combat_done(false, "no lantern post on the green")
	var terrain: Terrain = _world.get_node("Terrain")
	var at := lp.global_position
	var gy := terrain.height_at(at.x, at.z)
	var lc := lp.lantern_center()
	print("BOT lantern: post foot %.2f m off the ground, lantern %.2f m up, %.2f m out" % [at.y - gy, lc.y - gy, Vector2(lc.x - at.x, lc.z - at.z).length()])
	if absf(at.y - gy) > 0.05 or lc.y - gy < 1.7 or lc.y - gy > 2.4:
		return _combat_done(false, "the lantern hangs at a silly height")
	for q in [Vector2(at.x, at.z), Vector2(lc.x, lc.z)]:
		if Cottage.inside(q.x, q.y, 0.8) or StoneCottage.inside(q.x, q.y, 0.8) or WhiteCottage.covers(q.x, q.y, 0.8) or YardWall.near(q.x, q.y, 0.8) or DryWall.near(q.x, q.y, 0.8):
			return _combat_done(false, "the lantern post stands in a house or a wall")
	# dark by day, burning at night, out again after dawn
	var lits := []
	for h in [12.0, 19.0, 21.0, 2.0, 7.0]:
		_world.time_of_day = h
		await _ticks(20)
		lits.append(lp.lit)
	print("BOT lantern: lit at 12/19/21/2/7 h = %s, lamp energy now %.2f" % [str(lits), lp.lamp.light_energy])
	if lits[0] > 0.0 or lits[1] > 0.0 or lits[2] < 0.95 or lits[3] < 0.95 or lits[4] > 0.0:
		return _combat_done(false, "the lantern keeps the wrong hours")
	_world.time_of_day = 21.0
	await _ticks(3)
	if not lp.lamp.visible or lp.lamp.light_energy < 0.8:
		return _combat_done(false, "a lit lantern gives no light")
	# moths come in to the light at night, loop round it, bump the panes, settle on the post
	var mo := lp.moths
	var weather0: Weather = _world.weather
	weather0.force(0.0)
	mo.bumps = 0
	var seen := 0
	var sat := 0
	for k in 40:
		await _ticks(30)
		seen = maxi(seen, mo.visible_count)
		sat = maxi(sat, mo.settled_count)
	mo.max_dist = 0.0
	await _ticks(300)
	print("BOT lantern: moths round the light %d (max), settled on the post %d, pane bumps %d, strayed %.2f m, dodged the bat %d" % [seen, sat, mo.bumps, mo.max_dist, mo.dodges])
	if seen < 6 or mo.bumps < 1 or sat < 1 or mo.max_dist > 1.4 or mo.max_dist < 0.15:
		return _combat_done(false, "no believable moths round the lantern")
	for m in mo._m:
		if m.state != Moths.AWAY:
			var rel: Vector3 = m.pos - lp.lantern_center()
			if rel.y > -0.2 and rel.y < 0.25 and Vector2(rel.x, rel.z).length() < Moths.PANE_R - 0.005:
				return _combat_done(false, "a moth flew inside the lantern")
	weather0.force(1.0)
	await _ticks(900)
	var in_rain := mo.visible_count
	weather0.force(0.0)
	_world.time_of_day = 12.0
	await _ticks(900)
	print("BOT lantern: moths in a storm %d, at noon %d" % [in_rain, mo.visible_count])
	if in_rain > 3 or mo.visible_count > 0:
		return _combat_done(false, "moths ignore the rain or the daylight")
	_world.time_of_day = 21.0
	await _ticks(3)
	# it sways a little in the breeze and more in a storm, but never flies up
	var weather: Weather = _world.weather
	lp.max_sway = 0.0
	weather.force(0.0)
	await _ticks(300)
	var calm := lp.max_sway
	weather.force(1.0)
	weather.wind = 1.0
	lp.max_sway = 0.0
	await _ticks(300)
	var storm := lp.max_sway
	print("BOT lantern: sway %.3f rad in the breeze, %.3f in a storm" % [calm, storm])
	if calm < 0.005 or calm > 0.12 or storm <= calm or storm > 0.35:
		return _combat_done(false, "the lantern does not swing right")
	weather.force(0.0)
	# walk at the post: it must stop the hero
	var out := lp.global_basis.z
	var start := at + out.rotated(Vector3.UP, 1.2) * 3.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	var t := 0.0
	var closest := 99.0
	while t < 3.0:
		var d := Vector2(at.x - p.global_position.x, at.z - p.global_position.z).normalized()
		p.bot_input = d
		await _ticks(6)
		t += 0.1
		closest = minf(closest, Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length())
	p.bot_input = Vector2.ZERO
	print("BOT lantern: walked at the post, closest %.2f m from its axis" % closest)
	if closest < LanternPost.POST_W * 0.5:
		return _combat_done(false, "walked through the lantern post")
	_combat_done(true, "lantern post stands on the green, lit dusk to dawn, moths at the light, sways, blocks the hero")

func _waterbutt_test() -> void:
	var p := _player
	var c: WhiteCottage = _world.white_cottage
	var b := c.butt
	if b == null or b.get_node_or_null("Cask") == null or b.get_node_or_null("Hoops") == null:
		return _combat_done(false, "no water butt by the white cottage")
	var terrain: Terrain = _world.get_node("Terrain")
	var bp := b.global_position
	var gy := terrain.height_at(bp.x, bp.z)
	print("BOT waterbutt: butt foot %.2f m over the ground, level %.2f, bench seat %.2f m up" % [bp.y - gy, b.level, c.bench_seat.y - terrain.height_at(c.bench_seat.x, c.bench_seat.z)])
	if absf(bp.y - gy - 0.13) > 0.12:
		return _combat_done(false, "the butt floats or sinks")
	var sh := c.bench_seat.y - terrain.height_at(c.bench_seat.x, c.bench_seat.z)
	if sh < 0.3 or sh > 0.65:
		return _combat_done(false, "bench seat at a silly height")
	# walk at the butt from the green: it must stop the hero
	var out := c.global_basis.z
	var start := bp + out * 3.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	var t := 0.0
	var closest := 99.0
	while t < 3.0:
		var d := Vector2(bp.x - p.global_position.x, bp.z - p.global_position.z).normalized()
		p.bot_input = d
		await _ticks(6)
		t += 0.1
		closest = minf(closest, Vector2(bp.x - p.global_position.x, bp.z - p.global_position.z).length())
	p.bot_input = Vector2.ZERO
	print("BOT waterbutt: walked at it, closest %.2f m from its axis" % closest)
	if closest < WaterButt.R_MID:
		return _combat_done(false, "walked through the water butt")
	# a downpour fills it, a dry spell lowers it
	var weather: Weather = _world.weather
	b.level = 0.5
	weather.force(1.0)
	b._set_level()
	var y0 := b.surface_y()
	await _ticks(600)
	var wet_level := b.level
	print("BOT waterbutt: rain %.2f, level 0.50 -> %.2f, surface %.3f -> %.3f m" % [weather.rain, wet_level, y0, b.surface_y()])
	if wet_level < 0.53 or b.surface_y() <= y0:
		return _combat_done(false, "the rain did not fill the butt")
	b.level = 0.999
	await _ticks(300)
	print("BOT waterbutt: brim-full in the rain, spill %.2f" % b.spill)
	if b.spill < 0.2:
		return _combat_done(false, "a full butt does not run over")
	weather.force(0.0)
	b.level = 0.5
	await _ticks(600)
	print("BOT waterbutt: dry, level 0.50 -> %.3f, spill %.2f" % [b.level, b.spill])
	if b.level >= 0.5 or b.spill > 0.05:
		return _combat_done(false, "the butt does not settle in dry weather")
	_combat_done(true, "the butt stands on its stones, blocks the hero, fills in rain, runs over when full")

func _drywall_test() -> void:
	var p := _player
	var w: DryWall = _world.dry_wall
	var c: StoneCottage = _world.stone_cottage
	print("BOT drywall: %d stones (%d cope, %d through), %d colliders, gate %s, stile %s" % [w.stone_count, w.cope_count, w.through_count, w.get_node("DryWallCollision").get_child_count(), w.gate, w.stile])
	if w.stile == Vector3.ZERO:
		return _combat_done(false, "no squeeze stile in the back wall")
	if w.stone_count < 700 or w.cope_count < 100 or w.through_count < 15:
		return _combat_done(false, "garth wall not built")
	var flora: Flora = _world.get_node("Flora")
	var near := 99.0
	for q in flora.tree_positions + flora.rock_positions:
		for o in w.outline(0.5):
			near = minf(near, Vector2(q.x - o.x, q.z - o.z).length())
	print("BOT drywall: nearest tree/rock to the wall %.1f m" % near)
	if near < 1.2:
		return _combat_done(false, "a tree or rock stands in the garth wall")
	for o in w.outline(0.5):
		if Cottage.inside(o.x, o.z, 0.5):
			return _combat_done(false, "the garth wall runs into the timber house")
	# walk round the east gable, through the gateway, into the middle of the yard
	var terrain: Terrain = _world.get_node("Terrain")
	var yard := c.to_global(Vector3(-0.3, 0, -6.8))
	var out := (w.gate - c.to_global(Vector3(0, 0, -6.7)))
	out.y = 0
	out = out.normalized()
	var start := w.gate + out * 5.0 + c.global_basis.z * 2.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(20)
	for wp in [w.gate + out * 2.0, w.gate, w.gate - out * 1.5, yard]:
		var t := 0.0
		while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length() > 0.6 and t < 15.0:
			var d := Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).normalized()
			p.bot_input = d
			await _ticks(6)
			t += 0.1
		print("BOT drywall reached %s in %.1f s, at %s" % [wp, t, p.global_position])
		if t >= 15.0:
			p.bot_input = Vector2.ZERO
			return _combat_done(false, "could not walk through the gateway into the yard (stuck at %s)" % p.global_position)
	# the field gate gave way as the hero came at it, and swung away from him into the yard
	var fg := w.field_gate
	print("BOT drywall gate: opened %d times, at %.2f rad" % [fg.opens, fg.angle])
	if fg.opens < 1:
		return _combat_done(false, "the field gate never swung open")
	# run at the back of the yard: the wall must hold
	var back := -c.global_basis.z
	var t2 := 0.0
	var far := 0.0
	while t2 < 4.0:
		p.bot_input = Vector2(back.x, back.z)
		p.bot_sprint = true
		await _ticks(6)
		t2 += 0.1
		far = maxf(far, c.to_local(p.global_position).z * -1.0)
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	print("BOT drywall: ran at the back wall, got %.2f m behind the house centre (wall at ~10.4)" % far)
	if far > 10.4:
		return _combat_done(false, "ran through the garth wall")
	# left alone, the gate falls shut by its weight and knocks to rest
	var t3 := 0.0
	while t3 < 12.0 and (fg.shuts < 1 or fg.angle != 0.0):
		await _ticks(6)
		t3 += 0.1
	var foley: Foley = _world.foley
	print("BOT drywall gate: shut after %.1f s (%d knocks), angle %.3f, creaks %d, knocks heard %d" % [t3, fg.shuts, fg.angle, foley.played.get("creak", 0), foley.played.get("wood", 0)])
	if fg.shuts < 1 or fg.angle != 0.0:
		return _combat_done(false, "the field gate did not fall shut")
	if foley.played.get("creak", 0) < 1:
		return _combat_done(false, "the gate swung without a creak")
	# shut, it bars the way: walk at it from the yard side and it gives again, the other way
	var o0 := fg.opens
	var inside := w.gate - out * 2.5
	p.global_position = Vector3(inside.x, terrain.height_at(inside.x, inside.z) + 0.5, inside.z)
	await _ticks(10)
	var t4 := 0.0
	var mn := 0.0
	var mx := 0.0
	while t4 < 6.0 and Vector2(p.global_position.x - w.gate.x, p.global_position.z - w.gate.z).dot(Vector2(out.x, out.z)) < 1.5:
		p.bot_input = Vector2(out.x, out.z)
		await _ticks(6)
		t4 += 0.1
		mn = minf(mn, fg.angle)
		mx = maxf(mx, fg.angle)
	p.bot_input = Vector2.ZERO
	print("BOT drywall gate from the yard: opened %d -> %d, swung %.2f..%.2f rad, out in %.1f s" % [o0, fg.opens, mn, mx, t4])
	if fg.opens <= o0 or t4 >= 6.0:
		return _combat_done(false, "could not get back out through the field gate")
	if mn < -0.5 and mx > 0.5:
		return _combat_done(false, "the gate swung both ways for one push")
	_combat_done(true, "the yard wall stands clear of trees and the timber house, the field gate swings away from you and falls shut with a creak and a knock, the wall holds")
## Yard walls: built of enough stones, clear of both houses' doors, trees and rocks; the
## hero runs at a wall and is stopped by it, then walks out through the cart gateway.
## Hens: five birds in the garth that potter, scratch, peck and cluck by day, run squawking
## from a hero walking up on them without leaving the yard, stand out heavy rain under the
## back eaves, go up the hen house ladder one at a time at dusk and come down it at dawn.
## The garth's bare earth and the worn path: mask baked, and the hero can walk each path
## end to end (door -> squeeze gap -> round the gable -> garth gate; door -> cart gateway).
## The stepping stones at the doors: laid on the worn tracks, clear of the houses and walls,
## a lip proud of the dirt (not buried, not floating), and the hero walks out over them.
func _doorstones_test() -> void:
	var p := _player
	var ds: DoorStones = _world.door_stones
	var tr: Terrain = _world.terrain
	print("BOT doorstones: %d slabs" % ds.stone_count)
	if ds.stone_count != 10:
		return _combat_done(false, "expected 10 slabs, got %d" % ds.stone_count)
	for q in ds.stones:
		var g := tr.height_at(q.x, q.z)
		var house := StoneCottage.inside(q.x, q.z, 0.3) or WhiteCottage.covers(q.x, q.z, 0.3) or Cottage.inside(q.x, q.z, 0.3)
		print("BOT doorstones: slab %s lip %.3f worn %.2f house %s wall %s" % [q, q.y - g, YardGround.worn(q.x, q.z), house, YardWall.near(q.x, q.z, 0.3)])
		if q.y - g < 0.0 or q.y - g > 0.09:
			return _combat_done(false, "slab at %s sits %.3f off the ground" % [q, q.y - g])
		if YardGround.worn(q.x, q.z) < 0.5:
			return _combat_done(false, "slab at %s is off the worn track" % q)
		if house or YardWall.near(q.x, q.z, 0.3) or DryWall.near(q.x, q.z, 0.3):
			return _combat_done(false, "slab at %s is in a house or wall" % q)
		if not DoorStones.under(q.x, q.z) or ds.top_at(q.x, q.z) != q.y:
			return _combat_done(false, "plan footprint misses the slab at %s" % q)
	# the dirt gaps + rain pools: one draped patch per slab, reaching GAP + POOL past its edges
	var gaps := ds.get_node_or_null("Gaps") as MeshInstance3D
	if gaps == null or gaps.mesh.surface_get_array_len(0) != ds.stone_count * 216:
		return _combat_done(false, "dirt/pool patches missing round the slabs")
	var ga := gaps.mesh.get_aabb()
	print("BOT doorstones: gap patches %d verts, aabb %s" % [gaps.mesh.surface_get_array_len(0), ga.size])
	# the opaque pool skins: a fine ring round each slab, each vertex's edge distance in COLOR.r
	var pools := ds.get_node_or_null("Pools") as MeshInstance3D
	if pools == null or pools.mesh.get_surface_count() != 1:
		return _combat_done(false, "rain pool rings missing round the slabs")
	var pa := pools.mesh.surface_get_arrays(0)
	var pcol: PackedColorArray = pa[Mesh.ARRAY_COLOR]
	var pv: PackedVector3Array = pa[Mesh.ARRAY_VERTEX]
	var lo := 1.0
	var hi := 0.0
	for cc in pcol:
		lo = minf(lo, cc.r)
		hi = maxf(hi, cc.r)
	print("BOT doorstones: pool rings %d verts, edge distance %.2f..%.2f" % [pv.size(), lo, hi])
	if pv.size() < ds.stone_count * 600 or lo > 0.01 or hi < 0.99:
		return _combat_done(false, "pool rings do not span the slab edge out to POOL_OUT")
	# the warm yard bounce under each doorway: up by day, out by night
	if ds.bounces.size() != DoorStones.runs().size():
		return _combat_done(false, "expected a door bounce light per door, got %d" % ds.bounces.size())
	var h0: float = _world.time_of_day
	for hr: float in [13.0, 1.0]:
		_world.time_of_day = hr
		await _ticks(6)
		var be := ds.bounces[0].light_energy
		print("BOT doorstones: door bounce at %.0f h: %.2f (sun %.2f)" % [hr, be, _world.sun.light_energy])
		if (hr == 13.0 and be < 0.15) or (hr == 1.0 and ds.bounces[0].visible):
			return _combat_done(false, "door bounce %.2f wrong at %.0f h" % [be, hr])
	_world.time_of_day = h0
	await _ticks(6)
	var foley: Foley = _world.foley
	var stone0 := int(foley.played.get("step_stone", 0))
	var steps0 := foley.hero_steps
	# walk out of each door along its track, over the slabs, to a point 2.6 m out
	for r: Array in DoorStones.runs():
		var w: PackedVector2Array = r[0]
		var st: Vector2 = DoorStones.along(w, 0.15)[0]
		var to: Vector2 = DoorStones.along(w, 2.6)[0]
		p.global_position = Vector3(st.x, tr.height_at(st.x, st.y) + 0.5, st.y)
		await _ticks(20)
		var t := 0.0
		var mid: Vector2 = DoorStones.along(w, 1.3)[0]
		for wp: Vector2 in [mid, to]:
			while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.y).length() > 0.35 and t < 8.0:
				# a walk, not a run: at a run a stride nearly spans the 2 m of slabs
				p.bot_input = _input_toward(Vector3(wp.x, 0.0, wp.y)) * 0.3
				await _ticks(1)
				t += 0.017
		p.bot_input = Vector2.ZERO
		print("BOT doorstones: walked from %s to %s in %.1f s" % [st, p.global_position, t])
		if t >= 8.0:
			return _combat_done(false, "could not walk out over the slabs from %s" % st)
	var on_stone := int(foley.played.get("step_stone", 0)) - stone0
	print("BOT doorstones: %d hero steps, %d on stone" % [foley.hero_steps - steps0, on_stone])
	if on_stone < 3:
		return _combat_done(false, "only %d footsteps sounded on the slabs" % on_stone)
	# no blade of the meadow or the short sward through a slab (grass streamed round the last door)
	await _ticks(240)
	var grass := _world.get_node("Grass")
	var blades := 0
	var through := 0
	var tall := 0
	var tall_max := 0.0
	var in_pools := 0
	for ch in grass.get_children():
		var mmis: Array = [ch] if ch is MultiMeshInstance3D else []
		for c in ch.get_children():
			if c is MultiMeshInstance3D:
				mmis.append(c)
		for m: MultiMeshInstance3D in mmis:
			for i in m.multimesh.instance_count:
				var o: Vector3 = m.global_transform * m.multimesh.get_instance_transform(i).origin
				if absf(o.x - p.global_position.x) > 12.0 or absf(o.z - p.global_position.z) > 12.0:
					continue
				blades += 1
				if DoorStones.under(o.x, o.z, -0.02):
					through += 1
				# the short sward kept off the bare loam band where the rain pools lie
				elif m.name.begins_with("Sward") and DoorStones.under(o.x, o.z, 0.24):
					in_pools += 1
				# a tall meadow clump (not the short sward) standing right at a slab's edge
				if not m.name.begins_with("Sward") and DoorStones.near(o.x, o.z) > 0.6:
					var hgt := m.multimesh.get_instance_transform(i).basis.y.length()
					if hgt > tall_max:
						tall_max = hgt
					if hgt > 0.75:
						tall += 1
	print("BOT doorstones: %d clumps near the last door, %d through a slab, %d tall at a slab edge (max scale %.2f)" % [blades, through, tall, tall_max])
	if blades < 50 or through > 0:
		return _combat_done(false, "%d grass clumps grow through the slabs (%d near)" % [through, blades])
	if tall > 0:
		return _combat_done(false, "%d tall clumps lean over the slabs" % tall)
	print("BOT doorstones: %d sward blades in the pool band" % in_pools)
	if in_pools > 0:
		return _combat_done(false, "%d sward blades stand in the pool band round the slabs" % in_pools)
	_combat_done(true, "door stones laid, walkable, grass-free and sounding of stone")

## Verge flowers: the cart track runs between two ribbons of wildflowers, much denser than the
## open meadow a few metres off, with a few low ones on the crown strip and none in the ruts.
func _verge_test() -> void:
	var terrain: Terrain = _world.get_node("Terrain")
	var grass: GrassField = _world.get_node("Grass")
	await _ticks(10)
	var road: Array = YardGround.ROAD
	var ruts := YardGround.road_ruts()
	var ks := {}
	for i in road.size() - 1:
		var a: Vector2 = road[i][0]
		var b: Vector2 = road[i + 1][0]
		for t in 21:
			for o in [-8.0, 0.0, 8.0]:
				var q: Vector2 = a.lerp(b, t / 20.0) + (b - a).normalized().orthogonal() * o
				ks[Vector2i(floori(q.x / grass.chunk_m), floori(q.y / grass.chunk_m))] = true
	var verge := 0
	var meadow := 0
	var crown := 0
	var in_rut := 0
	var sp_v := [0, 0, 0, 0]
	for k: Vector2i in ks:
		var fl := MeadowFlowers.build_chunk(k, grass.chunk_m, terrain, 0.0, grass._ruin, grass._find_ruin())
		(fl[0] as Node).free()
		var hs: PackedVector3Array = fl[1]
		var kinds: PackedInt32Array = fl[2]
		for n in hs.size():
			var h := Vector2(hs[n].x, hs[n].z)
			# distance to the centre line over its worn stretch (wear > 0.4)
			var d := INF
			for i in range(1, road.size() - 2):
				d = minf(d, h.distance_to(Geometry2D.get_closest_point_to_segment(h, road[i][0], road[i + 1][0])))
			var dr := INF
			for r in ruts:
				var w: PackedVector2Array = r[0]
				for i in range(1, w.size() - 2):
					dr = minf(dr, h.distance_to(Geometry2D.get_closest_point_to_segment(h, w[i], w[i + 1])))
			if d < 0.3:
				crown += 1
			elif d > 1.0 and d < 2.6:
				verge += 1
				sp_v[kinds[n]] += 1
			elif d > 6.0 and d < 7.6:
				meadow += 1
			if dr < 0.12:
				in_rut += 1
	print("BOT verge: %d chunks, verge band %d heads (daisy %d buttercup %d knapweed %d yarrow %d), same-width meadow band 6 m out %d, crown %d, in the ruts %d" % [ks.size(), verge, sp_v[0], sp_v[1], sp_v[2], sp_v[3], meadow, crown, in_rut])
	if verge < 120 or verge < meadow * 2:
		return _combat_done(false, "the verges are not markedly more flowery than the meadow")
	if crown < 5:
		return _combat_done(false, "no low flowers on the crown strip")
	if in_rut > 0:
		return _combat_done(false, "%d flowers growing in the wheel ruts" % in_rut)
	# the verge sward is cropped short so the flowers stand over it: tall clumps fewer and lower
	var tall := [[0, 0.0, 0], [0, 0.0, 0]]   # [clumps, summed height, seeding kind] verge / meadow
	var tall_all := 0
	grass.record_clumps = []
	for k: Vector2i in ks:
		grass._build_chunk(k).free()
	tall_all = grass.record_clumps.size()
	for c: Array in grass.record_clumps:
		var xf: Transform3D = c[1]
		var h := Vector2(xf.origin.x, xf.origin.z)
		var d := INF
		for i in range(1, road.size() - 2):
			d = minf(d, h.distance_to(Geometry2D.get_closest_point_to_segment(h, road[i][0], road[i + 1][0])))
		var b := 0 if d > 1.1 and d < 2.3 else 1 if d > 6.0 and d < 7.2 else -1
		if b >= 0:
			tall[b][0] += 1
			tall[b][1] += xf.basis.y.length()
			if c[0] == 2:
				tall[b][2] += 1
	grass.record_clumps = null
	var hv: float = tall[0][1] / maxf(tall[0][0], 1.0)
	var hm: float = tall[1][1] / maxf(tall[1][0], 1.0)
	print("BOT verge: tall clumps verge band %d (mean height x%.2f, seeding %d) vs meadow band %d (x%.2f, seeding %d), %d in all" % [tall[0][0], hv, tall[0][2], tall[1][0], hm, tall[1][2], tall_all])
	if tall[1][0] < 50 or tall[0][0] > tall[1][0] * 0.6 or hv > hm * 0.75 or tall[0][2] > 0:
		return _combat_done(false, "the verge sward is not cropped shorter than the meadow")
	_combat_done(true, "the cart track runs between flowered verges")

func _rutstones_test() -> void:
	var terrain: Terrain = _world.get_node("Terrain")
	var rs: RutStones = _world.get_node("RutStones")
	var grass: GrassField = _world.get_node("Grass")
	await _ticks(10)
	var ruts := YardGround.road_ruts()
	var road: Array = YardGround.ROAD
	# cobbles: in the rut beds, sitting on the ground, none floating or buried
	var off_rut := 0
	var bad_y := 0
	for c: Vector3 in rs.cobbles:
		var h := Vector2(c.x, c.z)
		var dr := INF
		for r in ruts:
			var w: PackedVector2Array = r[0]
			for i in w.size() - 1:
				dr = minf(dr, h.distance_to(Geometry2D.get_closest_point_to_segment(h, w[i], w[i + 1])))
		if dr > 0.2:
			off_rut += 1
		var g := terrain.height_at(c.x, c.z)
		if c.y < g + 0.004 or c.y > g + 0.07:
			bad_y += 1
	# verge stones: out past the ruts, in the verge band, none in the wheel track
	var in_track := 0
	for b: Vector3 in rs.boulders:
		var h := Vector2(b.x, b.z)
		var d := INF
		for i in road.size() - 1:
			d = minf(d, h.distance_to(Geometry2D.get_closest_point_to_segment(h, road[i][0], road[i + 1][0])))
		if d < 0.95:
			in_track += 1
	print("BOT rutstones: %d cobbles in the ruts (%d off the rut bed, %d not sitting on the ground), %d verge stones (%d in the wheel track)" % [rs.cobble_count, off_rut, bad_y, rs.boulder_count, in_track])
	if rs.cobble_count < 80 or off_rut > 0 or bad_y > 0:
		return _combat_done(false, "the rut cobbles are missing or misplaced")
	if rs.boulder_count < 4 or in_track > 0:
		return _combat_done(false, "the verge stones are missing or lie in the track")
	# no grass blade or flower growing up through a verge stone
	var ks := {}
	for b: Vector3 in rs.boulders:
		ks[Vector2i(floori(b.x / grass.chunk_m), floori(b.z / grass.chunk_m))] = true
	var through := 0
	grass.record_clumps = []
	for k: Vector2i in ks:
		grass._build_chunk(k).free()
		var fl := MeadowFlowers.build_chunk(k, grass.chunk_m, terrain, 0.0, grass._ruin, grass._find_ruin())
		(fl[0] as Node).free()
		for hp: Vector3 in (fl[1] as PackedVector3Array):
			if RutStones.under(hp.x, hp.z, -0.04):
				through += 1
	for c: Array in grass.record_clumps:
		var xf: Transform3D = c[1]
		if RutStones.under(xf.origin.x, xf.origin.z, -0.04):
			through += 1
	grass.record_clumps = null
	print("BOT rutstones: %d chunks checked, %d clumps/flowers growing through a verge stone" % [ks.size(), through])
	if through > 0:
		return _combat_done(false, "grass grows through the verge stones")
	_combat_done(true, "the cart track's ruts are stony and its verges strewn with field stones")

func _yardpath_test() -> void:
	var p := _player
	var terrain: Terrain = _world.get_node("Terrain")
	var b := YardGround.mask_box
	var tex := YardGround.mask
	print("BOT yardpath: box %s, mask %s" % [b, tex])
	if b.z <= 0.0 or not tex is Texture2D:
		return _combat_done(false, "yard mask not published")
	var c := StoneCottage.SITE
	var mid := DryWall._to_world(Vector2(-0.3, -6.8))
	print("BOT yardpath: garth middle dist %.2f scratched %.2f, house centre dist %.2f" % [YardGround.garth_dist(mid.x, mid.y), Hens.scratched(mid.x, mid.y), YardGround.garth_dist(c.x, c.y)])
	if YardGround.garth_dist(mid.x, mid.y) < 2.0 or YardGround.garth_dist(c.x, c.y) > 0.0:
		return _combat_done(false, "garth mask does not match the yard")
	var flora: Flora = _world.get_node("Flora")
	for q in flora.tree_positions + flora.rock_positions:
		if YardGround.path_dist(q.x, q.z) < 2.0:
			print("BOT yardpath: tree/rock %.1f m off the path at local %s" % [YardGround.path_dist(q.x, q.z), YardGround._to_local(q.x, q.z)])
	# the village tracks: the mask's wear channel is full on the green and gone at the meadow end
	var img := (tex as ImageTexture).get_image()
	for t: Array in YardGround.TRACKS:
		for q: Array in [t[1], t[t.size() - 1]]:
			var w: Vector2 = q[0]
			var px := img.get_pixel(clampi(int((w.x - b.x) / b.z * img.get_width()), 0, img.get_width() - 1), clampi(int((w.y - b.y) / b.z * img.get_height()), 0, img.get_height() - 1))
			print("BOT yardpath: track point %s wear %.2f mask dist %.2f wear %.2f worn %.2f" % [w, q[1], px.g * 2.0, px.b, YardGround.worn(w.x, w.y)])
			if px.g * 2.0 > 0.2 or absf(px.b - q[1]) > 0.1:
				return _combat_done(false, "track mask does not match the track at %s" % w)
			if (q[1] > 0.9 and YardGround.worn(w.x, w.y) < 0.95) or (q[1] < 0.05 and YardGround.worn(w.x, w.y) > 0.05):
				return _combat_done(false, "track wear wrong at %s" % w)
	# the pedlar's cart track: both wheel ruts beaten bare, the sward standing between them,
	# and his footpath on over the fell worn where he walks it
	for i in range(1, YardGround.ROAD.size() - 1):
		var rc0: Vector2 = YardGround.ROAD[i][0]
		var nrm: Vector2 = (YardGround.ROAD[i + 1][0] - YardGround.ROAD[i - 1][0]).normalized().orthogonal()
		var r0 := rc0 - nrm * YardGround.GAUGE * 0.5
		var r1 := rc0 + nrm * YardGround.GAUGE * 0.5
		print("BOT yardpath: road %s wear %.2f ruts worn %.2f %.2f, middle %.2f" % [rc0, YardGround.ROAD[i][1], YardGround.worn(r0.x, r0.y), YardGround.worn(r1.x, r1.y), YardGround.worn(rc0.x, rc0.y)])
		if YardGround.ROAD[i][1] >= 0.55 and (YardGround.worn(r0.x, r0.y) < 0.85 or YardGround.worn(r1.x, r1.y) < 0.85):
			return _combat_done(false, "road ruts not worn at %s" % rc0)
		if YardGround.ROAD[i][1] >= 0.55 and YardGround.worn(rc0.x, rc0.y) > 0.05:
			return _combat_done(false, "road middle worn bare at %s" % rc0)
	for q: Array in YardGround.ROAD_PATHS[0].slice(1, -1):
		var w: Vector2 = q[0]
		if YardGround.worn(w.x, w.y) < 0.85:
			return _combat_done(false, "fell path not worn at %s" % w)
	for k in YardGround.PATHS_LOCAL.size() + YardGround.TRACKS.size():
		var pts: Array = YardGround._paths()[k]
		var pts_r := pts.duplicate()
		pts_r.reverse()   # from the door outward
		var st: Vector2 = pts_r[0] if k == 0 else pts[0]
		p.global_position = Vector3(st.x, terrain.height_at(st.x, st.y) + 0.5, st.y)
		await _ticks(20)
		var route: Array = pts_r if k == 0 else pts
		for i in range(1, route.size()):
			var wp: Vector2 = route[i]
			if k < YardGround.PATHS_LOCAL.size() and YardGround.worn(wp.x, wp.y) < 0.99:
				return _combat_done(false, "path %d point %d not worn" % [k, i])
			var t := 0.0
			# thread the squeeze gap (0.9 m) and the gateways closely; elsewhere he may cut corners
			var tight := 0.3 if YardWall.dist(wp.x, wp.y) < 1.2 or DryWall.near(wp.x, wp.y, 0.8) else 0.8
			while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.y).length() > tight and t < 15.0:
				p.bot_input = _input_toward(Vector3(wp.x, 0.0, wp.y))
				await _ticks(1)
				t += 0.017
			if t >= 15.0:
				p.bot_input = Vector2.ZERO
				var qp := PhysicsShapeQueryParameters3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 1.0
				qp.shape = sph
				qp.transform = Transform3D(Basis.IDENTITY, p.global_position + Vector3.UP)
				for hit in p.get_world_3d().direct_space_state.intersect_shape(qp, 16):
					print("BOT yardpath: touching ", hit.collider, " ", hit.collider.get_parent())
				return _combat_done(false, "could not walk path %d to point %d (stuck at %s, local %s, start %s)" % [k, i, p.global_position, YardGround._to_local(p.global_position.x, p.global_position.z), YardGround._to_local(st.x, st.y)])
		p.bot_input = Vector2.ZERO
		print("BOT yardpath: walked path %d (%d legs) to %s" % [k, route.size() - 1, p.global_position])
	# after rain the tracks hold water in their scuffed dips: none when dry, a few after a
	# shower, a chain of pools down the middle when soaked, never out on the sward
	var tr: Terrain = _world.terrain
	var cover := {}
	for wet in [0.0, 0.5, 1.0]:
		var r_on := 0
		var r_n := 0
		var r_off := 0
		for t: Array in YardGround.TRACKS:
			for i in t.size() - 1:
				var ra: Vector2 = t[i][0]
				var rc: Vector2 = t[i + 1][0]
				for k in 20:
					var rq := ra.lerp(rc, k / 20.0)
					var nrm := (rc - ra).normalized().orthogonal()
					if YardGround.rut_pool(Vector3(rq.x, tr.height_at(rq.x, rq.y), rq.y), wet):
						r_on += 1
					var ro := rq + nrm * 1.2
					if YardGround.rut_pool(Vector3(ro.x, tr.height_at(ro.x, ro.y), ro.y), wet):
						r_off += 1
					r_n += 1
		cover[wet] = float(r_on) / r_n
		print("BOT yardpath: wet %.1f, %.0f %% of the track centre lines hold water, %d pools 1.2 m out on the sward" % [wet, cover[wet] * 100.0, r_off])
		if r_off > 0:
			return _combat_done(false, "track pools spill out onto the sward")
	if cover[0.0] > 0.0 or cover[0.5] >= cover[1.0] or cover[1.0] < 0.12 or cover[1.0] > 0.7:
		return _combat_done(false, "track pools do not fill with the rain (%s)" % cover)
	# the hero splashes through them
	var wx: Weather = _world.weather
	wx.wet = 1.0
	# the longest run of pool down a track's middle: walk it from a metre before to past it
	var best := [0, Vector2.ZERO, Vector2.ZERO]
	for t: Array in YardGround.TRACKS:
		for i in t.size() - 1:
			var run := 0
			var first := Vector2.ZERO
			for k in 41:
				var pq: Vector2 = (t[i][0] as Vector2).lerp(t[i + 1][0], k / 40.0)
				if wx.pool_at(pq.x, pq.y):
					if run == 0:
						first = pq
					run += 1
					if run > best[0]:
						best = [run, first, pq]
				else:
					run = 0
	if best[0] < 2:
		return _combat_done(false, "no track pool to wade through when soaked")
	var pa: Vector2 = best[1]
	var pb: Vector2 = best[2]
	var dir2 := (pb - pa).normalized()
	var st2 := pa - dir2 * 1.5
	var en2 := pb + dir2 * 1.0
	var pool := Vector3(pa.x, tr.height_at(pa.x, pa.y), pa.y)
	var w0 := wx.wade_splashes
	p.global_position = Vector3(st2.x, tr.height_at(st2.x, st2.y) + 0.1, st2.y)
	# a short pool can fall between two strides: down it, and back up it if no foot landed
	for aim: Vector2 in [en2, st2]:
		for i in 240:
			if Vector2(p.global_position.x, p.global_position.z).distance_to(aim) < 0.3:
				break
			p.bot_input = _input_toward(Vector3(aim.x, 0.0, aim.y))
			await _ticks(1)
		if wx.wade_splashes > w0:
			break
	p.bot_input = Vector2.ZERO
	print("BOT yardpath: track pool %.1f m long at %s, %d wade splashes walking down it" % [pa.distance_to(pb), pool, wx.wade_splashes - w0])
	wx.wet = 0.0
	if wx.wade_splashes - w0 < 1:
		return _combat_done(false, "hero does not splash in the track pool")
	return _combat_done(true, "garth mask baked, both yard paths and the four village tracks walkable end to end, the tracks fade out toward the meadow, and hold pools after rain that the hero splashes through")

func _hens_test() -> void:
	var hn: Hens = _world.hens
	var c: StoneCottage = _world.stone_cottage
	var tr: Terrain = _world.get_node("Terrain")
	var foley: Foley = _world.foley
	_world.weather.force(0.0)
	_world.time_of_day = 10.0
	var far := c.to_global(Vector3(0, 0, 25.0))
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.3, far.z)
	await _ticks(10)
	print("BOT hens: %d birds" % hn.hens.size())
	if hn.hens.size() < 5:
		return _combat_done(false, "no hens in the garth")
	for h: Dictionary in hn.hens:
		if not Hens.inside_yard(h.pos):
			return _combat_done(false, "a hen starts outside the garth at %s" % h.pos)
	# a day's pottering: ~40 s of game time
	await _ticks(600)
	print("BOT hens day: walked %.1f m, %d pecks, %d scratches, %d clucks (heard %d), flees %d" % [hn.walked, hn.pecks, hn.scratches, hn.clucks, foley.played.get("cluck", 0), hn.flees])
	if hn.walked < 3.0 or hn.pecks < 5 or hn.scratches < 2 or hn.clucks < 3 or foley.played.get("cluck", 0) < 1:
		return _combat_done(false, "the hens are not working the yard")
	if hn.flees > 0:
		return _combat_done(false, "a hen fled with nobody near")
	# walk up on the nearest from 4 m away: it runs, squawking, and stays in the garth
	var h0: Dictionary = hn.hens[0]
	var hp := hn.at(0)
	var from := hp + (c.to_global(Vector3(0, 0, -6.8)) - hp).normalized() * -0.0 + c.global_basis.x * 4.0
	var fl := Hens.clamp_yard(Vector2(c.to_local(from).x, c.to_local(from).z))
	from = c.to_global(Vector3(fl.x, 0, fl.y))
	_player.global_position = Vector3(from.x, tr.height_at(from.x, from.z) + 0.3, from.z)
	await _ticks(20)
	var f0 := hn.flees
	var t := 0.0
	while hn.flees == f0 and t < 8.0:
		hp = hn.at(0)
		var d := Vector2(hp.x - _player.global_position.x, hp.z - _player.global_position.z)
		_player.bot_input = d.normalized()
		await _ticks(6)
		t += 0.1
	_player.bot_input = Vector2.ZERO
	var close := Vector2(hn.at(0).x - _player.global_position.x, hn.at(0).z - _player.global_position.z).length()
	print("BOT hens: walked up, %d flights after %.1f s (hero %.1f m off), squawks heard %d" % [hn.flees - f0, t, close, foley.played.get("squawk", 0)])
	if hn.flees == f0 or foley.played.get("squawk", 0) < 1:
		return _combat_done(false, "the hens let the hero walk right up")
	var mx := 0.0
	for i in 60:
		await _ticks(3)
		for h: Dictionary in hn.hens:
			mx = maxf(mx, h.speed)
			if not Hens.inside_yard(h.pos):
				return _combat_done(false, "a hen ran out of the garth at %s" % h.pos)
	print("BOT hens: fastest run %.1f m/s, all still inside the garth" % mx)
	if mx < 1.5:
		return _combat_done(false, "the fleeing hen never ran")
	# heavy rain: in under the back eaves
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.3, far.z)
	_world.weather.force(1.0)
	await _ticks(500)
	var sheltered := 0
	for h: Dictionary in hn.hens:
		if h.state == Hens.SHELTER and (h.pos as Vector2).y > Hens.EAVES_Z - 0.4:
			sheltered += 1
	print("BOT hens rain: %d under the eaves (rain %.2f)" % [sheltered, _world.weather.rain])
	if sheltered < 4:
		return _combat_done(false, "the hens stood out in the rain")
	_world.weather.force(0.0)
	await _ticks(200)
	var out := 0
	for h: Dictionary in hn.hens:
		if h.state != Hens.SHELTER and h.state != Hens.ROOST:
			out += 1
	print("BOT hens after rain: %d back out" % out)
	if out < 4:
		return _combat_done(false, "the hens stayed in after the rain")
	# dusk: queued at the hen house ladder, up it one at a time and in
	_world.time_of_day = 19.8
	var hh: HenHouse = hn.house
	print("BOT hens: house %d boards, floor foot y %.2f, sill y %.2f, ladder foot local %s" % [hh.boards, hh.base_y, hh.sill_y(), HenHouse.foot()])
	if hh.boards < 60 or not Hens.inside_yard(HenHouse.foot()):
		return _combat_done(false, "no hen house in the garth")
	var both := 0
	var climb_y := -INF
	for i in 1200:
		await _ticks(1)
		var on := 0
		for h: Dictionary in hn.hens:
			if h.state == Hens.CLIMB or h.state == Hens.DESCEND:
				on += 1
				climb_y = maxf(climb_y, hn.at(h.id).y)
		if on > 1:
			both += 1
		if hn.went_in >= 5:
			break
	var inside := 0
	for h: Dictionary in hn.hens:
		if h.inside and h.state == Hens.ROOST and not (h.mi as Node3D).visible:
			inside += 1
	print("BOT hens night: %d went up the ladder, %d in the house, highest on the ladder %.2f (sill %.2f), frames with two on it %d" % [hn.went_in, inside, climb_y, hh.sill_y(), both])
	if inside < 5 or hn.went_in < 5:
		return _combat_done(false, "the hens did not go into the hen house at dusk")
	if both > 0:
		return _combat_done(false, "two hens on the ladder at once")
	if climb_y < hh.sill_y() - 0.1:
		return _combat_done(false, "the hens never climbed the ladder")
	# the hero walking past the house at night does not flush them out
	var hp2 := c.to_global(Vector3(HenHouse.foot().x + 0.6, 0, HenHouse.foot().y))
	_player.global_position = Vector3(hp2.x, tr.height_at(hp2.x, hp2.z) + 0.3, hp2.z)
	var fl0 := hn.flees
	await _ticks(60)
	if hn.flees != fl0:
		return _combat_done(false, "a hen fled from inside the house")
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.3, far.z)
	_world.time_of_day = 7.0
	for i in 1500:
		await _ticks(1)
		if hn.came_out >= 5:
			break
	await _ticks(60)
	var up := 0
	for h: Dictionary in hn.hens:
		if h.state != Hens.ROOST and not h.inside and h.sit < 0.5 and (h.mi as Node3D).visible and Hens.inside_yard(h.pos):
			up += 1
	print("BOT hens morning: %d came down the ladder, %d up and about" % [hn.came_out, up])
	if up < 5:
		return _combat_done(false, "the hens never came out in the morning")
	_combat_done(true, "hens potter, scratch, peck and cluck, flee squawking inside the garth, shelter from rain, go up the ladder into the hen house one at a time at dusk and come down it at first light")

func _yardwall_test() -> void:
	var p := _player
	var w: YardWall = _world.yard_wall
	var terrain: Terrain = _world.get_node("Terrain")
	print("BOT yardwall: %d stones (%d copes, %d throughs, %d pins), %d colliders" % [w.stone_count, w.cope_count, w.through_count, w.pin_count, w.get_node("YardWallCollision").get_child_count()])
	if w.stone_count < 400 or w.cope_count < 80 or w.through_count < 8:
		return _combat_done(false, "walls not built")
	var flora: Flora = _world.get_node("Flora")
	var near := 99.0
	for q in flora.tree_positions + flora.rock_positions:
		near = minf(near, YardWall.dist(q.x, q.z))
	print("BOT yardwall: nearest tree/rock %.1f m from a wall" % near)
	if near < 1.2:
		return _combat_done(false, "a tree or rock stands in a wall")
	var sc: StoneCottage = _world.stone_cottage
	var dd := YardWall.dist(sc.door_gap.x, sc.door_gap.z)
	print("BOT yardwall: stone cottage door %.1f m from a wall" % dd)
	if dd < 2.0:
		return _combat_done(false, "a wall blocks the stone cottage door")
	# the yard: halfway between the houses
	var yard := Vector3((Cottage.SITE.x + StoneCottage.SITE.x) * 0.5, 0, (Cottage.SITE.y + StoneCottage.SITE.y) * 0.5)
	var r: Array = YardWall.runs()[1]          # the west wall (squeeze gap at 0.4)
	var a: Vector2 = r[0]
	var b: Vector2 = r[1]
	var m := a.lerp(b, 0.75)                   # a solid stretch
	var out := Vector3(m.x - yard.x, 0, m.y - yard.z).normalized()
	p.global_position = Vector3(yard.x, terrain.height_at(yard.x, yard.z) + 0.5, yard.z)
	await _ticks(20)
	var t := 0.0
	var best := 99.0
	while t < 5.0:
		var dv := Vector2(m.x - p.global_position.x, m.y - p.global_position.z)
		p.bot_input = dv.normalized() if dv.length() > 0.1 else Vector2(out.x, out.z)
		p.bot_sprint = true
		await _ticks(6)
		t += 0.1
		best = minf(best, YardWall.dist(p.global_position.x, p.global_position.z))
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	var past := Vector2(p.global_position.x - yard.x, p.global_position.z - yard.z).length() > Vector2(m.x - yard.x, m.y - yard.z).length() + 0.3
	print("BOT yardwall: ran at the west wall, nearest %.2f m from its centre line, through: %s" % [best, past])
	if past or best < 0.2:
		return _combat_done(false, "ran through the yard wall")
	# out through the cart gateway
	var g: Array = YardWall.runs()[0]
	var ga: Vector2 = g[0]
	var gb: Vector2 = g[1]
	var gc := ga.lerp(gb, g[2])
	var gout := Vector2(gc.x - yard.x, gc.y - yard.z).normalized()
	# walk at the gateway's mouth from the yard side, then on through it; done once he
	# stands 2 m out past the wall line (the hero overshoots waypoints at 4x time)
	var gn := Vector2(-(gb - ga).y, (gb - ga).x).normalized()
	if gn.dot(gout) < 0.0:
		gn = -gn
	var t2 := 0.0
	var crossed := -99.0
	while t2 < 15.0:
		var pp := Vector2(p.global_position.x, p.global_position.z)
		crossed = (pp - gc).dot(gn)
		if crossed > 2.0:
			break
		var wp := gc - gn * 1.2 if crossed < -1.0 and absf((pp - gc).dot(gn.orthogonal())) > 0.6 else gc + gn * 3.0
		p.bot_input = (wp - pp).normalized()
		await _ticks(6)
		t2 += 0.1
	p.bot_input = Vector2.ZERO
	print("BOT yardwall: through the gateway in %.1f s, %.1f m out past the wall line, at %s" % [t2, crossed, p.global_position])
	if crossed <= 2.0:
		return _combat_done(false, "could not walk out through the gateway (stuck at %s)" % p.global_position)
	if YardWall.dist(p.global_position.x, p.global_position.z) < 0.5:
		return _combat_done(false, "ended up inside the wall")
	_combat_done(true, "walls stand between the houses, hold the hero, and the gateway lets him out")

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
	# ivy on the keep: enough leaves, none floating clear of the wall faces or above the crown
	var stray := 0
	for shape in ruins.ivy.leaves:
		for it in shape:
			var o: Vector3 = (it[0] as Transform3D).origin
			var rr := Vector2(o.x - rs.x, o.z - rs.z).length()
			if not ((rr > 4.55 and rr < 4.9) or (rr > 2.6 and rr < 2.95)):
				stray += 1
	print("BOT ruin: ivy %d leaves, %d off the wall" % [ruins.ivy.leaf_count, stray])
	if ruins.ivy.leaf_count < 800 or stray > 0:
		return _combat_done(false, "ivy missing or leaves off the wall")
	print("BOT ruin: %d scree stones heaped against the low wall" % ruins.scree_count)
	if ruins.scree_count < 80:
		return _combat_done(false, "no talus against the broken-down wall")
	print("BOT ruin: %d talus stones at the curtain wall feet" % ruins.curtain_scree)
	if ruins.curtain_scree < 150:
		return _combat_done(false, "no talus at the curtain wall")
	print("BOT ruin: %d curtain stones weathered dark (aged)" % ruins.aged_count)
	if ruins.aged_count < 300:
		return _combat_done(false, "curtain stones not flagged as weathered")
	print("BOT ruin: %d grass tufts in the low wall joints" % ruins.joint_tufts)
	if ruins.joint_tufts < 60:
		return _combat_done(false, "no grass in the low wall joints")
	print("BOT ruin: %d grass tufts on the wall tops" % ruins.tuft_count)
	if ruins.tuft_count < 40 or ruins.get_node_or_null("CrownGrass") == null:
		return _combat_done(false, "no grass on the broken crown")
	print("BOT ruin: %d wall tufts burnt off by the hearth, %d singed" % [ruins.burnt_tufts, ruins.scorched_tufts])
	if ruins.burnt_tufts + ruins.scorched_tufts == 0:
		return _combat_done(false, "the wall grass by Hesper's fire is not singed")
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

## Harrowmere's first house: built (slates, footing stones, frame), standing on the green
## clear of the start, the herd steers off it, and the hero walks from the start to its door
## and cannot run in through the wall.
func _cottage_test() -> void:
	var p := _player
	var c: Cottage = _world.cottage
	var terrain: Terrain = _world.get_node("Terrain")
	print("BOT cottage: %d slates, %d stones, %d beams, footing %.2f m deep, ridge %.2f m" % [c.slate_count, c.stone_count, c.beam_count, -c.base_y, c.ridge_y])
	if c.slate_count < 1200 or c.stone_count < 60 or c.beam_count < 80:
		return _combat_done(false, "cottage not fully built")
	var start := p.global_position
	if Cottage.inside(start.x, start.z, 4.0) or Cottage.inside(_world.soldier.global_position.x, _world.soldier.global_position.z, 2.0):
		return _combat_done(false, "cottage stands on the start or the soldier's post")
	var herd: Herd = _world.herd
	var obs := 0
	for o in herd._obstacles:
		if Cottage.inside(o.x, o.z):
			obs += 1
	if obs < 10:
		return _combat_done(false, "the herd does not know the house is there")
	# walk to the doorstep
	var door := c.global_position + Cottage.front() * (Cottage.WID * 0.5 + 1.2) - Cottage.front().cross(Vector3.UP) * 0.75
	var t := 0.0
	while Vector2(p.global_position.x - door.x, p.global_position.z - door.z).length() > 0.8 and t < 30.0:
		var d := Vector2(door.x - p.global_position.x, door.z - p.global_position.z).normalized()
		p.bot_input = d
		await _ticks(6)
		t += 0.1
	print("BOT cottage: reached the door in %.1f s at %s" % [t, p.global_position])
	if t >= 30.0:
		p.bot_input = Vector2.ZERO
		return _combat_done(false, "could not walk to the cottage door")
	# run at the door and the wall: he must stay outside
	var deepest := 99.0
	var t2 := 0.0
	var f := Cottage.front()
	while t2 < 4.0:
		p.bot_input = Vector2(-f.x, -f.z)
		p.bot_sprint = true
		await _ticks(6)
		t2 += 0.1
		var l := Cottage.to_local_xz(p.global_position.x, p.global_position.z)
		deepest = minf(deepest, l.y)
	p.bot_input = Vector2.ZERO
	p.bot_sprint = false
	print("BOT cottage: ran at the door, nearest %.2f m from the ridge line (wall at %.2f)" % [deepest, Cottage.WID * 0.5])
	if deepest < Cottage.WID * 0.5 - 0.1:
		return _combat_done(false, "walked through the cottage wall")
	_combat_done(true, "the house stands on the green and its walls hold")

## Shrine seal in the keep: the lid sleeps dim from the gateway, the hero walks in through
## the breach and up the plinth onto the lid, the sigil wakes and the place names itself;
## walking back out lets the caption fade and the glow sink again.
func _shrine_test() -> void:
	var p := _player
	var ruins: Ruins = _world.get_node("Ruins")
	var terrain: Terrain = _world.get_node("Terrain")
	var seal := ruins.seal
	if seal == null:
		return _combat_done(false, "no shrine seal")
	var hud: Hud = p.get_node("Hud")
	var rs := ruins.site
	var to_v := Vector3(-rs.x, 0, -rs.z).normalized()
	var start := rs + to_v * 14.0
	p.global_position = Vector3(start.x, terrain.height_at(start.x, start.z) + 0.5, start.z)
	await _ticks(60)
	var g0 := seal.glow
	print("BOT shrine: lid top %.2f (floor %.2f), glow at 14 m %.2f, caption a %.2f" % [seal.top_y, rs.y, g0, hud.caption_alpha])
	if g0 > 0.05 or hud.caption_alpha > 0.01:
		return _combat_done(false, "seal awake from the gateway")
	for wp in [rs + to_v * 4.0, rs]:
		var t := 0.0
		while Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length() > 0.5 and t < 25.0:
			var d := Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).normalized()
			p.bot_input = d
			await _ticks(6)
			t += 0.1
		if t >= 25.0:
			p.bot_input = Vector2.ZERO
			return _combat_done(false, "could not reach %s (stuck at %s)" % [wp, p.global_position])
	p.bot_input = Vector2.ZERO
	await _ticks(240)
	print("BOT shrine: on the lid at %s, glow %.2f, caption '%s' a %.2f" % [p.global_position, seal.glow, hud.caption_title, hud.caption_alpha])
	if p.global_position.y < seal.top_y - 0.3:   # on the plinth (he coasts a little past the lid)
		return _combat_done(false, "hero not up on the plinth (y %.2f, lid %.2f)" % [p.global_position.y, seal.top_y])
	if seal.glow < 0.8 or hud.caption_alpha < 0.9 or hud.caption_title != "Shrine of Binding":
		return _combat_done(false, "seal did not wake / name itself")
	var t2 := 0.0
	while t2 < 4.0:
		p.bot_input = Vector2(to_v.x, to_v.z)
		await _ticks(6)
		t2 += 0.1
	p.bot_input = Vector2.ZERO
	await _ticks(300)
	print("BOT shrine: walked out to %.1f m, glow %.2f, caption a %.2f" % [Vector2(p.global_position.x - rs.x, p.global_position.z - rs.z).length(), seal.glow, hud.caption_alpha])
	if hud.caption_alpha > 0.05 or seal.glow > 0.6:
		return _combat_done(false, "caption/glow did not settle after leaving")
	_combat_done(true, "walked up onto the shrine seal, it woke and named itself, then slept again")

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
	# ... with an alarm bark as they went and their hooves drumming the turf
	var fl: Foley = _world.foley
	print("BOT herd voices: %d barks, played bark %d gallop %d (synth %d ms)" % [herd.barks, int(fl.played.get("bark", 0)), int(fl.played.get("gallop", 0)) + int(fl.played.get("gallop_wet", 0)), fl.build_ms])
	if herd.barks < 1 or int(fl.played.get("bark", 0)) < 1 or int(fl.played.get("gallop", 0)) + int(fl.played.get("gallop_wet", 0)) < 6:
		return _combat_done(false, "the herd bolted without an alarm bark or hoofbeats")
	# the stag runs with his hinds, not left behind
	var sc := herd.centre()
	var stag_gap := -1.0
	for k in herd.deer_positions().size():
		if herd.is_stag(k):
			var sp: Vector3 = herd.deer_positions()[k]
			stag_gap = Vector2(sp.x - sc.x, sp.z - sc.z).length()
	print("BOT herd stag: %d stag(s), %.1f m from the fleeing herd's centre" % [herd.stag_count(), stag_gap])
	if herd.stag_count() < 1 or stag_gap < 0.0 or stag_gap > 20.0:
		return _combat_done(false, "the stag did not flee with the herd")
	# the galloping herd left a track of splayed hoof prints behind it
	var tr: Trample = _world.trample
	var hp := tr.hoof_near(herd.centre() - herd._flee_dir * 6.0, 8.0)
	print("BOT herd hoofs: %d pressed, %d live, one %.1f m behind the herd (depth %.2f)" % [herd.hoof_prints, tr.active_hoofs(), Vector2(hp.x, hp.y).distance_to(Vector2(herd.centre().x, herd.centre().z)) if hp.w > 0.0 else -1.0, hp.w])
	if herd.hoof_prints < 20 or tr.active_hoofs() < 20 or hp.w < 0.9:
		return _combat_done(false, "the fleeing deer left no hoof prints behind them")
	# ... and combed a lane through the grass where it ran (its own trail buffer)
	var lane := 0
	var lay_max := 0.0
	for k in 8:
		var q := herd.centre() - herd._flee_dir * (6.0 + k * 3.0)
		var best := 0.0
		for dx in range(-6, 7):
			best = maxf(best, tr.herd_lay_at(q + herd._flee_dir.cross(Vector3.UP).normalized() * dx * 0.7))
		lay_max = maxf(lay_max, best)
		if best > 0.5:
			lane += 1
	print("BOT herd lane: %d herd trail points live, grass laid at %d/8 spots 6-27 m behind the herd (max %.2f)" % [tr.active_herd_points(), lane, lay_max])
	if tr.active_herd_points() < 15 or lane < 5:
		return _combat_done(false, "the fleeing herd left no trodden lane in the grass")
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
	# the stag roars at dusk while the herd is at peace, never at noon
	var r0 := herd.roars
	_world.time_of_day = 13.0
	herd.roar_t = 0.0
	await _ticks(30)
	var noon := herd.roars - r0
	_world.time_of_day = 19.0
	herd.roar_t = 0.0
	await _ticks(30)
	print("BOT herd rut: roars at noon %d, at 19 h %d, played roar %d" % [noon, herd.roars - r0 - noon, int(_world.foley.played.get("roar", 0))])
	if noon != 0 or herd.roars - r0 - noon < 1 or int(_world.foley.played.get("roar", 0)) < 1:
		return _combat_done(false, "the stag did not roar at dusk (or roared at noon)")
	_combat_done(true, "deer graze, look up at a hero in sight, bolt barking from a charge with drumming hooves, settle far off; the stag roars at dusk")

## Red deer at night: the herd beds down in the meadow (each deer lying in its own pressed
## patch of grass), springs up to stare at a hero who comes into sight, lies down again once
## he has gone, and is up and grazing again by dawn.
func _bed_test() -> void:
	var p := _player
	var herd: Herd = _world.get_node("Herd")
	var terrain: Terrain = _world.get_node("Terrain")
	var tr: Trample = _world.trample
	var c := herd.centre()
	var away := Vector3(c.x, 0, c.z).normalized()
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	var far := c - away * 110.0
	p.global_position = Vector3(far.x, terrain.height_at(far.x, far.z) + 1.0, far.z)
	_world.time_of_day = 23.0
	var n := herd.deer_positions().size()
	await _ticks(60 * 12)
	var c1 := herd.centre()
	var laid := 0
	for q in herd.deer_positions():
		if tr.herd_lay_at(q, 0.6) > 0.3:
			laid += 1
	print("BOT bed night: %d/%d deer lying at 23 h, drift %.1f m, %d lying in laid grass" % [herd.bedded(), n, c1.distance_to(c), laid])
	if herd.bedded() < n - 1 or c1.distance_to(c) > 3.0 or laid < n - 2:
		return _combat_done(false, "the herd did not bed down for the night")
	var at := c1 - away * 35.0
	p.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 1.0, at.z)
	await _ticks(60 * 4)
	var up := 0
	for d: Herd.Deer in herd._deer:
		if d.bed < 0.01:
			up += 1
	print("BOT bed alarmed: state %d, %d/%d deer up on their feet, heads up %d" % [herd.state, up, n, herd.heads_up()])
	if herd.state != Herd.ALERT or up < n or herd.heads_up() < n - 1:
		return _combat_done(false, "the bedded herd did not rise to stare at the hero")
	p.global_position = Vector3(far.x, terrain.height_at(far.x, far.z) + 1.0, far.z)
	await _ticks(60 * 14)
	print("BOT bed settled again: state %d, %d/%d lying" % [herd.state, herd.bedded(), n])
	if herd.state != Herd.CALM or herd.bedded() < n - 1:
		return _combat_done(false, "the herd did not lie down again once the hero had gone")
	_world.time_of_day = 6.0
	await _ticks(60 * 6)
	var grazing := 0
	for d: Herd.Deer in herd._deer:
		if d.bed <= 0.0:
			grazing += 1
	print("BOT bed dawn: %d/%d up at 6 h, %d lying" % [grazing, n, herd.bedded()])
	if grazing < n:
		return _combat_done(false, "the herd did not get up at dawn")
	_combat_done(true, "deer bed down at night, rise to stare at a hero, lie down again, get up at dawn")

## The face fill under the hat follows the scene's shade light: full at noon, still lifting the
## face at dusk, a dim cool glow at night (not a warm lamp under a moonlit hat).
func _facelight_test() -> void:
	var fill: OmniLight3D = _player.garb.fill
	var got := {}
	for h in [13.0, 17.5, 18.4, 19.2, 23.0, 6.3]:
		_world.time_of_day = h
		await _ticks(10)
		var c := fill.light_color
		got[h] = [fill.light_energy, c]
		var s: Color = _world.face_shade
		print("BOT facelight %.1f h: shade lum %.3f, fill %.3f colour (%.2f %.2f %.2f)" % [h,
				s.r * 0.3 + s.g * 0.59 + s.b * 0.11, fill.light_energy, c.r, c.g, c.b])
	var noon: float = got[13.0][0]
	var dusk: float = got[18.4][0]
	var night: float = got[23.0][0]
	var nc: Color = got[23.0][1]
	if absf(noon - HeroGarb.FILL_NOON) > 0.04:
		return _combat_done(false, "noon face fill %.3f is off its tuned %.2f" % [noon, HeroGarb.FILL_NOON])
	# exposure opens up to 1.6 at night vs 0.85 at noon: compare what reaches the screen
	if dusk < noon * 0.3 or night * 1.6 > noon * 0.85 * 0.8:
		return _combat_done(false, "face fill does not dim from noon through dusk into night")
	if nc.b <= nc.r:
		return _combat_done(false, "the night face fill is still warm")
	_combat_done(true, "the face fill follows the shade light from noon to night")

## Edda keeps her day: out of the door at dawn, stooping at the butt and the woodpile, sat on
## the bench at noon, out to the lantern at dusk to light it with her taper (and it stays dark
## until she does), in at night, and in out of the rain.
## Edda: no answer from out of reach; beside her at the woodpile a Speak prompt, her two intro
## lines then a wood line, subtitled, held still facing the hero; sat on the bench at noon she
## answers with an eat line without getting up; indoors no prompt at all.
func _eddatalk_test() -> void:
	var v: Villager = _world.villager
	var hud: Hud = _player.get_node("Hud")
	var tr: Terrain = _world.get_node("Terrain")
	if v == null:
		return _combat_done(false, "no villager")
	_world.weather.force(0.0)
	_world.time_of_day = 9.0
	v.settle(_world, 9.0)
	await _ticks(10)
	var far := v.global_position + Vector3(0, 0, 7.0).rotated(Vector3.UP, v.body.rotation.y)
	_player.global_position = Vector3(far.x, tr.height_at(far.x, far.z) + 0.3, far.z)
	await _ticks(20)
	_player.bot_interact = true
	await _ticks(20)
	print("BOT eddatalk far: talks %d" % v.talks)
	if v.talks > 0:
		return _combat_done(false, "she answered from out of reach")
	var pp := v.global_position + Vector3(0, 0, 1.7).rotated(Vector3.UP, v.body.rotation.y + 0.6)
	_player.global_position = Vector3(pp.x, tr.height_at(pp.x, pp.z) + 0.3, pp.z)
	await _ticks(60)
	print("BOT eddatalk near: prompt '%s %s' (hold %.2f), named %s" % [hud.prompt_key, hud.prompt_verb, hud._prompt_hold, v.named])
	if hud._prompt_hold <= 0.0 or hud.prompt_verb != "Speak" or not v.named:
		return _combat_done(false, "no Speak prompt beside her")
	var heard := []
	var p0 := v.global_position
	for i in 3:
		_player.bot_interact = true
		await _ticks(3)
		heard.append(v.last_line)
		print("BOT eddatalk %d: '%s' | hud '%s' saying %s" % [i, v.last_line, hud.say_speaker, hud.saying()])
		if hud.say_line != v.last_line or hud.say_speaker != "Edda" or not hud.saying():
			return _combat_done(false, "her line did not show as a subtitle")
		await _ticks(90)
	if v.talks != 3 or heard[0] != Villager.INTRO[0] or heard[1] != Villager.INTRO[1] or not (heard[2] in Villager.LINES["wood"]):
		return _combat_done(false, "lines out of order: %s" % [heard])
	var d := _player.global_position - v.global_position
	var face := absf(wrapf(atan2(d.x, d.z) - v.body.rotation.y, -PI, PI))
	var moved := Vector2(v.global_position.x - p0.x, v.global_position.z - p0.z).length()
	print("BOT eddatalk: facing off %.2f rad, moved %.2f m, stoop %.2f, talking %.1f s" % [face, moved, v.stoop, v.talking])
	if face > 0.4 or moved > 0.3:
		return _combat_done(false, "did not hold still facing the hero while talking")
	# noon on the bench: an eat line, and she stays sat
	_world.time_of_day = 12.2
	v.settle(_world, 12.2)
	var sp: Vector3 = v.global_position + Vector3(0, 0, 1.6).rotated(Vector3.UP, v.body.rotation.y)
	_player.global_position = Vector3(sp.x, tr.height_at(sp.x, sp.z) + 0.3, sp.z)
	await _ticks(30)
	_player.bot_interact = true
	await _ticks(30)
	print("BOT eddatalk bench: '%s', sit %.2f" % [v.last_line, v.sit])
	if not (v.last_line in Villager.LINES["eat"]) or v.sit < 0.95:
		return _combat_done(false, "on the bench she should answer sat")
	# night: she is in, no prompt and no line
	_world.time_of_day = 23.0
	v.settle(_world, 23.0)
	await _ticks(10)
	var n0 := v.talks
	_player.bot_interact = true
	await _ticks(20)
	if v.talks != n0:
		return _combat_done(false, "she answered from inside the house")
	_combat_done(true, "intro x2 then a wood line, subtitled, facing him; an eat line sat on the bench; silent indoors")

## Holds the clock at hour h for n physics ticks (a long walk must not run past the slot).
func _hold_hour(h: float, n: int) -> void:
	for i in n:
		_world.time_of_day = h
		await get_tree().physics_frame

## Holds hour h until the walker has stopped walking (at most n ticks), then `after` more.
func _hold_arrive(v: Villager, h: float, n: int, after: int) -> void:
	await _hold_hour(h, 20)
	for i in n:
		if v.state != Villager.WALK:
			break
		_world.time_of_day = h
		await get_tree().physics_frame
	await _hold_hour(h, after)

## Osric's day: out on his step, round by the squeeze gap and in at the field gate to the
## eggs, leaning on the back wall, tending the garth, the long way in for his dinner and out
## again, in out of the rain, by the hen house at dusk, in at night; turns to the hero.
func _neighbour_test() -> void:
	var v: Neighbour = _world.neighbour
	var tr: Terrain = _world.get_node("Terrain")
	var fg: FieldGate = _world.dry_wall.field_gate
	if v == null or v.cottage == null:
		return _combat_done(false, "no neighbour")
	_world.weather.force(0.0)
	_player.global_position = Vector3(30.0, tr.height_at(30.0, -30.0) + 0.5, -30.0)
	_world.time_of_day = 3.0
	v.settle(_world, 3.0)
	await _ticks(10)
	print("BOT neighbour at 3 h: %s, visible %s" % [v.activity, v.visible])
	if v.visible or v.activity != "in":
		return _combat_done(false, "he is out at 3 in the morning")
	# his own face and a grey beard, not the hero's face cloth; the face runs down past the nose
	var g := v.garb
	var fb := g.face.get_aabb() if g.face != null else AABB()
	print("BOT neighbour face: %s over the jaw, face %.3f..%.3f m, eyes %d" % [g.veil.name if g.veil else "nothing", fb.position.y, fb.end.y, g.eyes.size()])
	if g.veil == null or g.veil.name != "Beard" or g.face == null or fb.position.y > 1.88 or g.eyes.size() != 2:
		return _combat_done(false, "Osric has no beard or no nose")
	var o0 := fg.opens
	var stages := [[6.9, "wake", 0], [7.5, "eggs", 700], [9.0, "lean", 200], [11.0, "tend", 700], [12.5, "in", 0], [14.0, "lean", 200], [17.1, "fell", 0], [19.2, "shut", 0], [20.0, "step", 0]]
	for st in stages:
		var s0 := v.stoops
		var g0 := v.goings_in
		if st[1] == "step":
			# he waits by the ladder till the last hen is up and the slide dropped
			for i in 6000:
				if v.activity == "step":
					break
				_world.time_of_day = st[0]
				await get_tree().physics_frame
		await _hold_arrive(v, st[0], 3000, st[2] + 40)
		var lc := v.cottage.to_local(v.global_position)
		print("BOT neighbour at %.1f h: %s, state %d, visits %s, stoops +%d, lean %.2f, gate opens %d, warps %d, at (%.1f, %.1f) local" % [st[0], v.activity, v.state, str(v.visits), v.stoops - s0, v.lean, fg.opens - o0, v.warps, lc.x, lc.z])
		if v.activity != st[1] or v.visits.get(st[1], 0) < 1:
			return _combat_done(false, "he never got to his %s" % st[1])
		if st[1] == "in":
			if v.visible or v.goings_in <= g0:
				return _combat_done(false, "he did not go in for his dinner")
		elif not v.visible:
			return _combat_done(false, "he is not out at his %s" % st[1])
		if (st[1] == "eggs" or st[1] == "tend") and v.stoops - s0 < 2:
			return _combat_done(false, "he stands idle at the %s" % st[1])
		if st[1] == "lean" and v.lean < 0.95:
			return _combat_done(false, "he does not lean on the wall")
		if st[1] == "fell":
			# out through the squeeze stile and up the fell footpath, not lifted over the wall
			print("BOT neighbour fell: stiles %d, past the wall %s, warps %d" % [v.stiles, Neighbour.past_stile(lc), v.warps])
			if v.stiles < 1 or not Neighbour.past_stile(lc) or v.warps > 0:
				return _combat_done(false, "he never went out through the stile onto the fell")
			# standing up there looking up the fell, not frozen: a hand to the brim now and then
			var sh0 := v.shades
			for i in 3000:
				if v.shades > sh0:
					break
				await get_tree().physics_frame
			print("BOT neighbour on the fell: gaze %.2f, hand to the brim %d" % [v.gaze, v.shades - sh0])
			if v.gaze < 0.95 or v.shades <= sh0:
				return _combat_done(false, "he stands stiff on the fell")
		if st[1] == "shut" and (v.stiles < 2 or Neighbour.past_stile(lc)):
			return _combat_done(false, "he never came back in through the stile")
		if st[1] == "eggs" and fg.opens - o0 < 1:
			return _combat_done(false, "the field gate never swung for him")
		if st[1] == "step":
			# out on his step at dusk: nobody in, so his lamp is not lit yet
			print("BOT neighbour lamp while he is on the step: %.2f" % v.cottage.lit)
			if v.cottage.lit > 0.05:
				return _combat_done(false, "his lamp burns with nobody in")
			# the hens all in and the slide down over the pop-hole before he left them
			var hh: HenHouse = _world.hens.house
			print("BOT neighbour slide at dusk: all in %s, shut %.2f, his drops %d, house drops %d" % [_world.hens.all_in(), hh.shut, v.shuts, hh.drops])
			if not _world.hens.all_in() or hh.shut < 0.99 or v.shuts < 1:
				return _combat_done(false, "he left the hen house open to the fox")
			# stood on his step he is never quite still: his weight goes foot to foot, he looks about
			var r_lo := 1.0
			var r_hi := -1.0
			var t_lo := 1.0
			var t_hi := -1.0
			for i in 12:
				await _hold_hour(20.0, 60)
				r_lo = minf(r_lo, v.roll)
				r_hi = maxf(r_hi, v.roll)
				t_lo = minf(t_lo, v.crumple.head_turn)
				t_hi = maxf(t_hi, v.crumple.head_turn)
			print("BOT neighbour idle on the step: idle %.2f, roll %.3f..%.3f rad, head %.2f..%.2f" % [v.idle, r_lo, r_hi, t_lo, t_hi])
			if v.idle < 0.95 or r_hi - r_lo < 0.02 or r_hi - r_lo > 0.05 or t_hi - t_lo < 0.15:
				return _combat_done(false, "he stands stiff as a post on his step")
	if fg.angle != 0.0 and absf(fg.angle) > 0.05:
		await _hold_hour(20.0, 300)
	print("BOT neighbour gate after: angle %.2f, opens %d, shuts %d" % [fg.angle, fg.opens - o0, fg.shuts])
	if absf(fg.angle) > 0.05:
		return _combat_done(false, "the field gate hangs open after him")
	# the hens: over to peck round his boots while he tends the garth, out of his road as he goes
	var hn: Hens = _world.hens
	v.settle(_world, 11.0)
	var most := 0
	for i in 60:
		await _hold_hour(11.0, 20)
		most = maxi(most, hn.round_keeper)
	print("BOT neighbour hens round him at the garth: up to %d of %d within 2 m (%s)" % [most, hn.hens.size(), v.activity])
	if most < 3:
		return _combat_done(false, "the hens pay him no mind while he tends the garth")
	# all five strung across his road to the field gate, then off he goes for his dinner
	var a := v.cottage.to_local(v.global_position)
	var b: Vector2 = Neighbour.WAY[Neighbour.WAY.size() - 1]
	for k in hn.hens.size():
		var hh: Dictionary = hn.hens[k]
		hh.pos = Hens.clamp_yard(Vector2(a.x, a.z).lerp(b, 0.2 + 0.15 * k))
		hh.state = Hens.STAND
		hh.t = 30.0
		hh.hurry = 0.0
	var gw0 := hn.gave_way
	var f0 := hn.flees
	var closest := 9.0
	_world.time_of_day = 12.3
	for i in 1500:
		_world.time_of_day = 12.3
		await get_tree().physics_frame
		if not v.visible:
			break
		var kl := v.cottage.to_local(v.global_position)
		if Hens.inside_yard(Vector2(kl.x, kl.z)):
			for hh: Dictionary in hn.hens:
				closest = minf(closest, (hh.pos as Vector2).distance_to(Vector2(kl.x, kl.z)))
	print("BOT neighbour hens in his road: gave way %d times, closest %.2f m, flights %d" % [hn.gave_way - gw0, closest, hn.flees - f0])
	if hn.gave_way - gw0 < 2 or closest < 0.3:
		return _combat_done(false, "the hens do not get out of his road")
	# rain at the wall sends him in, the long way round; when it passes he comes out again
	await _hold_arrive(v, 14.5, 3000, 200)
	_world.weather.force(1.0)
	await _hold_arrive(v, 14.5, 3000, 60)
	var in_rain := v.visible
	var goes := v.goings_in
	_world.weather.force(0.0)
	await _hold_arrive(v, 14.5, 3000, 200)
	print("BOT neighbour rain: out in it %s, gone in %d, after: %s visible %s lean %.2f" % [in_rain, goes, v.activity, v.visible, v.lean])
	if in_rain or goes < 2 or not v.visible or v.activity != "lean":
		return _combat_done(false, "he does not shelter from the rain")
	await _hold_arrive(v, 21.2, 3000, 40)
	print("BOT neighbour night: %s visible %s gone in %d, warps %d, lamp %.2f" % [v.activity, v.visible, v.goings_in, v.warps, v.cottage.lit])
	if v.visible or v.activity != "in":
		return _combat_done(false, "he does not go in at night")
	if v.cottage.lit < 0.5:
		return _combat_done(false, "he is in at night with his lamp unlit")
	if v.warps > 0:
		return _combat_done(false, "he wedged on his rounds and was lifted %d times" % v.warps)
	# first light: the slide is still down and the hens wait in; out he comes, reaches down and
	# draws it up, and they come down the ladder one after another; then he goes to his step
	var hh2: HenHouse = hn.house
	_world.time_of_day = 5.0
	hn._settle_now()
	v.settle(_world, 5.0)
	await _hold_hour(5.0, 30)
	var op0 := v.opens
	var shut_at_5 := hh2.shut
	await _hold_hour(5.95, 600)
	var held := hn.all_in()
	await _hold_arrive(v, 5.95, 3000, 400)
	var down := 0
	for i in 2400:
		_world.time_of_day = 5.95
		await get_tree().physics_frame
		down = 0
		for hd: Dictionary in hn.hens:
			if not hd.inside and hd.state != Hens.CLIMB and hd.state != Hens.DESCEND:
				down += 1
		if down == hn.hens.size() and v.activity == "wake":
			break
	print("BOT neighbour slide at dawn: shut at 5 h %.2f, hens held in %s, opens +%d, shut now %.2f, hens down %d of %d, he is at his %s" % [shut_at_5, held, v.opens - op0, hh2.shut, down, hn.hens.size(), v.activity])
	if shut_at_5 < 0.99 or v.opens - op0 < 1 or hh2.shut > 0.01 or down < hn.hens.size() or v.activity != "wake":
		return _combat_done(false, "the hen house is not opened at first light")
	# the hero walks up while he leans on the wall: he straightens and turns to him
	v.settle(_world, 9.0)
	await _hold_hour(9.0, 200)
	var to := v.global_position + Vector3(2.0, 0, 0.0).rotated(Vector3.UP, v.body.rotation.y + 2.2)
	_player.global_position = Vector3(to.x, tr.height_at(to.x, to.z) + 0.3, to.z)
	await _hold_hour(9.0, 200)
	var d := _player.global_position - v.global_position
	var off := absf(wrapf(atan2(d.x, d.z) - v.body.rotation.y, -PI, PI))
	print("BOT neighbour notice: noticing %s, facing off %.2f rad, lean %.2f" % [v.noticing, off, v.lean])
	if not v.noticing or off > 0.35 or v.lean > 0.1:
		return _combat_done(false, "he ignores the hero")
	_combat_done(true, "Osric keeps his day (his lamp lit only while he is in; the hens peck round his boots and get out of his road): eggs, the wall, the garth, out through the stile onto the fell and back, in for dinner and at night, out of the rain, through the field gate; he drops the hen house slide at dusk and lifts it at first light")

## Edda and Osric pass a word when her feed round brings her by his garth: both stop and turn
## to each other, she says hers and he answers; the hero overhears it from nearby, and they do
## not keep at it while they stand together.
func _greet_test() -> void:
	var e: Villager = _world.villager
	var o: Neighbour = _world.neighbour
	var tr: Terrain = _world.get_node("Terrain")
	if e == null or o == null or e.mate != o or o.mate != e:
		return _combat_done(false, "the neighbours do not know each other")
	_world.weather.force(0.0)
	_player.global_position = Vector3(30.0, tr.height_at(30.0, -30.0) + 0.5, -30.0)
	var fl = _world.get("foley")
	for h in [7.4, 16.4]:
		e.settle(_world, h)
		o.settle(_world, h)
		var g0 := e.greets + o.greets
		var m0: int = fl.played.get("murmur", 0) + fl.played.get("murmur_low", 0) if fl != null else 0
		var closest := 99.0
		var faced := 9.0
		var both := false
		var first := -1
		for i in 2400:
			_world.time_of_day = h
			await get_tree().physics_frame
			var dd := e.global_position.distance_to(o.global_position)
			closest = minf(closest, dd)
			if first < 0 and e.greets + o.greets > g0:
				first = i
			if e.greeting > 0.0 and o.greeting > 0.0 and e.greeting < 1.5:
				both = true
				var a := e.global_position.direction_to(o.global_position)
				var b := o.global_position.direction_to(e.global_position)
				faced = minf(faced, absf(wrapf(atan2(a.x, a.z) - e.body.rotation.y, -PI, PI)) + absf(wrapf(atan2(b.x, b.z) - o.body.rotation.y, -PI, PI)))
			if first >= 0 and i > first + 900:
				break
		var lines := e.greets + o.greets - g0
		var m1: int = fl.played.get("murmur", 0) + fl.played.get("murmur_low", 0) if fl != null else 0
		print("BOT greet at %.1f h: %s / %s, closest %.1f m, lines %d (first at tick %d), turned to each other off %.2f rad, murmurs %d" % [h, e.activity, o.activity, closest, lines, first, faced, m1 - m0])
		if lines < 2:
			return _combat_done(false, "Edda and Osric pass without a word at %.1f h" % h)
		if lines > 2:
			return _combat_done(false, "they keep on talking (%d lines in one meeting)" % lines)
		if not both or faced > 0.6:
			return _combat_done(false, "they do not turn to each other")
		if fl != null and m1 - m0 < 2:
			return _combat_done(false, "no murmur of voices")
	# the hero standing off a few metres hears it on the HUD
	e.settle(_world, 16.4)
	o.settle(_world, 16.4)
	var hud = _player.get_node_or_null("Hud")
	var h0 := e.heard + o.heard
	var saw := ""
	var placed := false
	for i in 2400:
		_world.time_of_day = 16.4
		await get_tree().physics_frame
		var dd := e.global_position.distance_to(o.global_position)
		if not placed and dd < Villager.GREET_R + 1.5:
			# 8 m behind Edda, outside her notice ring
			var at := e.global_position + (e.global_position - o.global_position).normalized() * 8.0
			_player.global_position = Vector3(at.x, tr.height_at(at.x, at.z) + 0.3, at.z)
			placed = true
		if hud != null and hud.saying() and saw.find(hud.say_speaker) < 0:
			saw += hud.say_speaker + " "
		if e.heard + o.heard - h0 >= 2:
			break
	print("BOT greet overheard: %d lines, HUD showed %s, hero %.1f m from Edda" % [e.heard + o.heard - h0, saw, _player.global_position.distance_to(e.global_position)])
	if e.heard + o.heard - h0 < 2 or saw.find("Edda") < 0 or saw.find("Osric") < 0:
		return _combat_done(false, "the hero does not overhear them")
	_combat_done(true, "Edda and Osric stop, turn to each other and pass a word at the garth (once a meeting), murmuring, and the hero overhears it")

func _pedlar_test() -> void:
	var pd: Pedlar = _world.pedlar
	var e: Villager = _world.villager
	var o: Neighbour = _world.neighbour
	var tr: Terrain = _world.get_node("Terrain")
	if pd == null:
		return _combat_done(false, "no pedlar")
	_world.weather.force(0.0)
	_player.global_position = Vector3(30.0, tr.height_at(30.0, 30.0) + 0.5, 30.0)
	# off the road at dawn, sets out by the clock at 09:00
	e.settle(_world, 8.95)
	o.settle(_world, 8.95)
	pd.settle(_world, 8.95)
	var hidden := not pd.visible
	for i in 30:
		_world.time_of_day = 9.02
		await get_tree().physics_frame
	if not hidden or not pd.on_road or not pd.visible:
		return _combat_done(false, "the pedlar does not set out at 09:00 (hidden before %s, on road %s)" % [hidden, pd.on_road])
	for leg in [[9.3, false], [14.6, true], [19.5, false]]:
		var h: float = leg[0]
		var dusk := Pedlar.lantern_for(h)
		var lit_max := 0.0
		var lamp_hi := -INF
		var lamp_lo := INF
		var sway0 := pd.hand_lantern.max_sway if pd.hand_lantern else 0.0
		e.settle(_world, h)
		o.settle(_world, h)
		pd.settle(_world, h)
		pd.set_out(leg[1])
		var j0 := pd.journeys
		var s0 := pd.stops
		var w0 := pd.warps
		var faced := 9.0
		var wet := 0
		var ticks := 0
		var dg: Dog = _world.dog
		var wf0 := dg.woofs
		var wn0 := dg.warns
		var fw0: int = _world.foley.played.get("dog_woof", 0)
		var dog_out := 0.0
		var dog_eye := 9.0
		var dog_closest := 99.0
		var dog_pass := 99.0
		var sd0 := pd.sidesteps
		for i in 30000:
			_world.time_of_day = h
			await get_tree().physics_frame
			ticks = i
			if pd.hand_lantern != null and pd.visible:
				lit_max = maxf(lit_max, pd.hand_lantern.lit)
				if pd.hand_lantern.lit > 0.5 and pd.state == Villager.WALK:
					var ly := pd.hand_lantern.flame_center().y - pd.global_position.y
					lamp_hi = maxf(lamp_hi, ly)
					lamp_lo = minf(lamp_lo, ly)
			dog_closest = minf(dog_closest, dg.global_position.distance_to(pd.global_position))
			if pd.state == Villager.WALK:
				dog_pass = minf(dog_pass, Vector2(dg.global_position.x - pd.global_position.x, dg.global_position.z - pd.global_position.z).length())
			if dg.state == Dog.WARN:
				dog_out = maxf(dog_out, dg.global_position.distance_to(dg._warn_from))
				var dp := pd.global_position - dg.global_position
				dog_eye = minf(dog_eye, absf(wrapf(atan2(-dp.x, -dp.z) - (dg.yaw + dg.head_yaw), -PI, PI)))
			if pd.greeting > 0.0 and pd.mate != null and pd.mate.greeting > 0.0 and pd.greeting < 1.5:
				var m: Villager = pd.mate
				var a := m.global_position.direction_to(pd.global_position)
				faced = minf(faced, absf(wrapf(atan2(a.x, a.z) - m.body.rotation.y, -PI, PI)))
			if pd.journeys > j0:
				break
		print("BOT pedlar %.1f h (%s): %d ticks, journeys %d, stands %d, warps %d, greeted %s, Edda %s / Osric %s, mate turned to him off %.2f rad" % [h, "back" if leg[1] else "out", ticks, pd.journeys - j0, pd.stops - s0, pd.warps - w0, pd.greeted.keys(), e.activity, o.activity, faced])
		print("BOT pedlar dog: closest %.1f m, woofs %d (%d sounded), warns %d, trotted out %.1f m, eyes on him off %.2f rad, state after %d" % [dog_closest, dg.woofs - wf0, _world.foley.played.get("dog_woof", 0) - fw0, dg.warns - wn0, dog_out, dog_eye, dg.state])
		print("BOT pedlar walks past the dog no closer than %.2f m, sidesteps %d" % [dog_pass, pd.sidesteps - sd0])
		print("BOT pedlar lantern: lit max %.2f, flame %.2f..%.2f m above his feet, swing %.2f rad" % [lit_max, lamp_lo, lamp_hi, (pd.hand_lantern.max_sway if pd.hand_lantern else 0.0)])
		if pd.hand_lantern == null:
			return _combat_done(false, "the pedlar has no hand lantern")
		if dusk and lit_max < 0.95:
			return _combat_done(false, "the pedlar's lantern is not lit on the dusk walk (%.2f)" % lit_max)
		if not dusk and lit_max > 0.0:
			return _combat_done(false, "the pedlar's lantern burns in daylight")
		if dusk and (lamp_lo < 0.15 or lamp_hi > 0.9):
			return _combat_done(false, "the lantern does not hang from his hand at his knee (%.2f..%.2f m)" % [lamp_lo, lamp_hi])
		if dusk and pd.hand_lantern.max_sway < 0.03:
			return _combat_done(false, "the lantern does not swing as he walks (%.3f rad)" % pd.hand_lantern.max_sway)
		if dog_pass < 0.75:
			return _combat_done(false, "the pedlar walks through the dog (%.2f m)" % dog_pass)
		if dg.woofs - wf0 != 1 or dg.warns - wn0 != 1 or _world.foley.played.get("dog_woof", 0) - fw0 < 1:
			return _combat_done(false, "the dog should woof once at the pedlar going by")
		if dog_out < 1.0 or dog_out > Dog.FOLLOW + 1.0 or dog_eye > 0.3 or dg.state == Dog.WARN:
			return _combat_done(false, "the dog should trot a few steps after the pedlar, watch him and go back to pottering")
		if pd.journeys == j0:
			return _combat_done(false, "the pedlar never got through the village (leg %d of %d at %s)" % [pd._leg, pd._legs.size(), pd.global_position])
		if pd.stops - s0 != 2:
			return _combat_done(false, "the pedlar made %d stands, not 2" % (pd.stops - s0))
		if pd.warps - w0 > 1:
			return _combat_done(false, "the pedlar got stuck %d times" % (pd.warps - w0))
		if not pd.greeted.has("Edda") or not pd.greeted.has("Osric"):
			return _combat_done(false, "the pedlar passed without a word for %s" % ("Edda" if not pd.greeted.has("Edda") else "Osric"))
		if faced > 0.7:
			return _combat_done(false, "the one he greets does not turn to him")
		if pd.visible:
			return _combat_done(false, "the pedlar is still drawn off the road")
	# rain does not stop him: he hurries on
	e.settle(_world, 10.0)
	o.settle(_world, 10.0)
	pd.settle(_world, 10.0)
	pd.set_out(false)
	_world.weather.force(1.0)
	var p0 := pd.global_position
	for i in 600:
		_world.time_of_day = 10.0
		await get_tree().physics_frame
	var moved := pd.global_position.distance_to(p0)
	print("BOT pedlar in rain: %s, moved %.1f m in 600 ticks, visible %s" % [pd.activity, moved, pd.visible])
	_world.weather.force(0.0)
	if moved < 8.0 or not pd.visible:
		return _combat_done(false, "the rain stops the pedlar")
	_combat_done(true, "Wat the pedlar sets out at 09:00, walks the road through the village both ways, stands on the green and at Osric's wall, passes a word with Edda and Osric (they turn to him), and hurries on through rain; at dusk he comes through again with a lit horn lantern swinging from his left hand; Brack woofs at him, trots a few steps after him and watches him go; he steps round the dog instead of through it")

func _villager_test() -> void:
	var v: Villager = _world.villager
	var lp: LanternPost = _world.lantern_post
	var tr: Terrain = _world.get_node("Terrain")
	if v == null or v.home == null:
		return _combat_done(false, "no villager")
	_world.weather.force(0.0)
	# the hero well away, so she does not stop to watch him
	_player.global_position = Vector3(30.0, tr.height_at(30.0, -30.0) + 0.5, -30.0)
	_world.time_of_day = 3.0
	v.settle(_world, 3.0)
	await _ticks(10)
	print("BOT villager at 3 h: %s, visible %s" % [v.activity, v.visible])
	if v.visible or v.activity != "in":
		return _combat_done(false, "she is out at 3 in the morning")
	var stages := [[6.1, "wake", 300], [6.6, "water", 900], [9.0, "wood", 900], [12.1, "eat", 400]]
	for st in stages:
		_world.time_of_day = st[0]
		var s0 := v.stoops
		await _ticks(st[2])
		print("BOT villager at %.1f h: %s, state %d, visits %s, stoops +%d, sit %.2f, warps %d" % [st[0], v.activity, v.state, str(v.visits), v.stoops - s0, v.sit, v.warps])
		if v.activity != st[1] or v.visits.get(st[1], 0) < 1 or not v.visible:
			return _combat_done(false, "she never got to her %s" % st[1])
		if (st[1] == "water" or st[1] == "wood") and v.stoops - s0 < 2:
			return _combat_done(false, "she stands idle at the %s" % st[1])
		if st[1] == "water":
			var pl: WaterButt = v.home.pail
			var grip := pl.global_position + Vector3.UP * WhiteCottage.pail_grip()
			print("BOT villager pail: carrying %s, dips %d, level %.2f, grip %.2f m from her hand" % [v.carrying, v.dips, pl.level, grip.distance_to(v.hand_mark.global_position)])
			if not v.carrying or v.dips < 1 or pl.level < 0.8:
				return _combat_done(false, "she never filled her pail at the butt")
			if v.stoop < 0.5 and grip.distance_to(v.hand_mark.global_position) > 0.1:
				return _combat_done(false, "the pail does not hang from her hand")
		if st[1] == "wood":
			var pl: WaterButt = v.home.pail
			var bt: Vector3 = v.home.butt.global_position
			var off := Vector2(pl.global_position.x - bt.x, pl.global_position.z - bt.z).length()
			var tr0: Terrain = _world.get_node("Terrain")
			print("BOT villager pail down: carrying %s, moves %d, %.2f m from the butt, foot %.2f above ground" % [v.carrying, v.pail_moves, off, pl.global_position.y - tr0.height_at(pl.global_position.x, pl.global_position.z)])
			if v.carrying or v.pail_moves < 2 or off > 1.6 or absf(pl.global_position.y - tr0.height_at(pl.global_position.x, pl.global_position.z)) > 0.05:
				return _combat_done(false, "she did not set the pail down by the butt")
	if v.sit < 0.95 or v.global_position.distance_to(Vector3(v.home.bench_seat.x, v.global_position.y, v.home.bench_seat.z)) > 0.2:
		return _combat_done(false, "she is not sat on the bench at noon")
	# rain sends her in; when it passes she comes out again
	_world.time_of_day = 15.0
	await _ticks(600)
	_world.weather.force(1.0)
	await _ticks(600)
	var in_rain := v.visible
	var goes := v.goings_in
	_world.weather.force(0.0)
	await _ticks(900)
	print("BOT villager rain: out in it %s, gone in %d, after: %s visible %s" % [in_rain, goes, v.activity, v.visible])
	if in_rain or goes < 1 or not v.visible or v.activity != "wood":
		return _combat_done(false, "she does not shelter from the rain")
	# dusk: the lantern stays dark until she has walked out and lit it
	_world.time_of_day = 18.85
	var dark_until := 0.0
	var lit_at := -1.0
	for i in 120:
		await _ticks(10)
		if lp.lit < 0.05:
			dark_until = i
		if lp.lit > 0.9 and lit_at < 0.0:
			lit_at = i
	var hand := v.hand_mark.global_position.distance_to(lp.lantern_center()) if v.hand_mark else 99.0
	print("BOT villager lamp: lights %d, dark for %d0 ticks, burning from tick %d0, %s, at the post %.2f m" % [v.lights, dark_until, lit_at, v.activity, Vector2(v.global_position.x - lp.global_position.x, v.global_position.z - lp.global_position.z).length()])
	if v.lights != 1 or lit_at < 0.0 or dark_until < 10:
		return _combat_done(false, "she never lit the lantern")
	_world.time_of_day = 20.0
	await _ticks(400)
	print("BOT villager evening: %s sit %.2f; lantern %.2f" % [v.activity, v.sit, lp.lit])
	if v.activity != "evening" or v.sit < 0.9 or lp.lit < 0.95:
		return _combat_done(false, "no evening on the bench")
	var h0 := v.hums
	for i in 1500:
		_world.time_of_day = 20.0
		await get_tree().physics_frame
	print("BOT villager hums on the bench: %d (heard %d)" % [v.hums - h0, _world.foley.played.get("hum", 0)])
	if v.hums - h0 < 1 or _world.foley.played.get("hum", 0) < 1:
		return _combat_done(false, "she does not hum on the bench")
	_world.time_of_day = 20.8
	await _ticks(600)
	print("BOT villager night: %s visible %s gone in %d, warps %d" % [v.activity, v.visible, v.goings_in, v.warps])
	if v.visible or v.activity != "in":
		return _combat_done(false, "she does not go in at night")
	print("BOT villager lamp in the window: %.2f" % v.home.lit)
	if v.home.lit < 0.9:
		return _combat_done(false, "no lamp in her window once she is in")
	if v.warps > 0:
		return _combat_done(false, "she wedged on her rounds and was lifted %d times" % v.warps)
	# the hero walks up by day: she stops and turns to him
	_world.time_of_day = 9.5
	await _ticks(600)
	var to := v.global_position + Vector3(2.5, 0, 0.0).rotated(Vector3.UP, v.body.rotation.y + 2.0)
	_player.global_position = Vector3(to.x, tr.height_at(to.x, to.z) + 0.3, to.z)
	await _ticks(200)
	var d := _player.global_position - v.global_position
	var off := absf(wrapf(atan2(d.x, d.z) - v.body.rotation.y, -PI, PI))
	print("BOT villager notice: noticing %s, facing off %.2f rad" % [v.noticing, off])
	if not v.noticing or off > 0.35:
		return _combat_done(false, "she ignores the hero")
	_combat_done(true, "Edda keeps her day: water, wood, the bench, the lantern, in at night and out of the rain")

## Edda at the chopping block: the axe comes out of the block into her hands, she heaves it
## overhead and brings the bit down onto the round, the round splits and the halves land on
## the ground either side; a thud and a crack are heard; the axe goes back in the block after.
func _chop_test() -> void:
	var v: Villager = _world.villager
	var tr: Terrain = _world.get_node("Terrain")
	if v == null or v.chop == null:
		return _combat_done(false, "no villager or no chop")
	var c := v.chop
	_world.weather.force(0.0)
	_player.global_position = Vector3(30.0, tr.height_at(30.0, -30.0) + 0.5, -30.0)
	_world.time_of_day = 9.0
	v.settle(_world, 9.0)
	var hits: Array = []
	c.chopped.connect(func(at: Vector3, split: bool) -> void: hits.append([at, split, -1.0]))
	var top_lift := 0.0
	var gap := 0.0
	var gaps := 0
	var held := 0
	for i in 1600:
		await get_tree().physics_frame
		top_lift = maxf(top_lift, c.lift)
		if c.holding:
			held += 1
			if c.lift > 0.95 or c.lift < -0.95:
				gap += v.left_hand_pos().distance_to(v.hand_mark.global_position)
				gaps += 1
		for h in hits:
			if h[2] < 0.0:
				h[2] = (c.axe.global_transform * Axe.edge_point()).distance_to(h[0])
	var errs := hits.map(func(h: Array) -> float: return h[2])
	var halves_ok := true
	for i in 2:
		var mm := (c.get_child(2 + i) as MultiMeshInstance3D).multimesh
		var o := mm.get_instance_transform(0).origin
		if c.splits > 0 and c._halves_on and absf(o.y - tr.height_at(o.x, o.z)) > 0.2:
			halves_ok = false
	var foley: Foley = _world.foley
	print("BOT chop: held %d ticks, swings %d, splits %d, top lift %.2f, bit off the mark %s, reach %.2f, hand gap %.2f m, halves on the ground %s, chops heard %d thuds %d, block axe shown %s" % [held, c.swings, c.splits, top_lift, str(errs), c.reach, gap / maxf(gaps, 1), halves_ok, foley.played.get("chop", 0), foley.played.get("thud", 0), c.block_axe.visible])
	if held < 600 or c.swings < 2 or c.splits < 1 or top_lift < 0.95:
		return _combat_done(false, "she does not chop")
	for e in errs:
		if e > 0.12:
			return _combat_done(false, "the bit lands %.2f m off the round" % e)
	if not halves_ok or c.block_axe.visible:
		return _combat_done(false, "halves hang in the air or the axe stayed in the block")
	if foley.played.get("chop", 0) < 1:
		return _combat_done(false, "no chop heard")
	print("BOT chop heaves: %d for %d swings, grunts heard %d" % [c.heaves, c.swings, foley.played.get("grunt", 0)])
	if c.heaves < c.swings or foley.played.get("grunt", 0) < 1:
		return _combat_done(false, "no breath on the heave")
	_world.time_of_day = 12.1
	await _ticks(400)
	print("BOT chop after: %s holding %s, block axe shown %s" % [v.activity, c.holding, c.block_axe.visible])
	if c.holding or not c.block_axe.visible or c.axe.visible:
		return _combat_done(false, "the axe went to the bench with her")
	_combat_done(true, "Edda splits rounds at the block: heave, strike, the halves jump off")

## Edda feeds the hens: from the butt she takes the grain bag round the outside of the yard
## walls to the garth's east wall (never through a wall, never into the yard), casts six
## handfuls over it, the grain lies on the yard and the hens run to it and eat it; then she
## goes back round to the woodpile.
func _feed_test() -> void:
	var v: Villager = _world.villager
	var hn: Hens = _world.hens
	var tr: Terrain = _world.get_node("Terrain")
	if v == null or v.feed == null or hn == null:
		return _combat_done(false, "no villager, feed or hens")
	var f := v.feed
	_world.weather.force(0.0)
	_player.global_position = Vector3(30.0, tr.height_at(30.0, -30.0) + 0.5, -30.0)
	_world.time_of_day = 7.0
	v.settle(_world, 7.0)
	await _ticks(300)
	_world.time_of_day = 7.34
	var segs := DryWall.segments()
	var closest := INF
	var in_yard := 0
	var arrived := -1
	var bag_gap := INF
	var peak_grain := 0
	var wall_wait := 0          # most hens waiting at the east wall before the first grain fell
	var call_d := INF           # how near the garth she was at her first call
	for i in 2600:
		await get_tree().physics_frame
		var p := v.global_position
		if hn.thrown == 0:
			wall_wait = maxi(wall_wait, hn.at_wall)
		if f.calls > 0 and call_d == INF:
			call_d = v.global_position.distance_to(hn.cottage.to_global(Vector3(HenFeed.LAND.x, 0, HenFeed.LAND.y)))
		# clearance from either wall's face
		closest = minf(closest, YardWall.dist(p.x, p.z) - YardWall.W0 * 0.5)
		for sg in segs:
			var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), sg[0], sg[1])
			closest = minf(closest, q.distance_to(Vector2(p.x, p.z)) - DryWall.BASE_W * 0.5)
		var l := hn.cottage.to_local(p)
		if Hens.inside_yard(Vector2(l.x, l.z)):
			in_yard += 1
		if arrived < 0 and v.visits.get("feed", 0) > 0:
			arrived = i
		if f.weight > 0.9 and f.arm < 0.22:
			bag_gap = minf(bag_gap, v.hand_mark.global_position.distance_to(f.bag.global_position))
		peak_grain = maxi(peak_grain, hn.grain.size())
	var near := 0
	for h in hn.hens:
		if h.feed:
			near += 1
		print("BOT feed hen %d: state %d pos %s nearest grain %.2f m, t %.2f" % [h.id, h.state, str(h.pos), (h.pos as Vector2).distance_to(hn._nearest_grain(h.pos)), h.t])
	print("BOT feed: arrived tick %d, casts %d, thrown %d, peak on the ground %d, eaten %d, left %d, hens fed %d, warps %d, clear of the walls by %.2f m, ticks in the yard %d, hand to bag %.2f m, bag shown %s, grain heard %d" % [arrived, f.casts, hn.thrown, peak_grain, hn.fed, hn.grain.size(), near, v.warps, closest, in_yard, bag_gap, f.bag.visible, _world.foley.played.get("grain", 0)])
	print("BOT feed call: %d calls (heard %d), first %.1f m from the garth, %d hens waiting at the wall before the grain" % [f.calls, _world.foley.played.get("call", 0), call_d, wall_wait])
	if arrived < 0 or v.activity != "feed":
		return _combat_done(false, "she never got to the garth wall")
	if f.calls < 2 or _world.foley.played.get("call", 0) < 2:
		return _combat_done(false, "she did not call the hens as she came")
	if wall_wait < 4:
		return _combat_done(false, "the hens did not gather at the wall at her call")
	for i in Hens.COUNT:
		if not Hens.inside_yard(Hens.wall_spot(i)) or HenHouse.covers(Hens.wall_spot(i), 0.1):
			return _combat_done(false, "a wall spot outside the yard")
	if f.casts < HenFeed.CASTS or hn.thrown < 60:
		return _combat_done(false, "she did not cast the grain")
	if hn.fed < 30:
		return _combat_done(false, "the hens did not eat the grain")
	if v.warps > 0 or in_yard > 0 or closest < 0.2:
		return _combat_done(false, "she went through a wall or into the yard")
	if not f.bag.visible or bag_gap > 0.3:
		return _combat_done(false, "no grain bag at her hip, or her hand never in it")
	if _world.foley.played.get("grain", 0) < HenFeed.CASTS:
		return _combat_done(false, "the casts are not heard")
	# grain all lies inside the yard, on the ground
	for i in hn.grain.size():
		if not Hens.inside_yard(hn.grain[i]):
			return _combat_done(false, "grain outside the yard")
	# the rest gets eaten up
	await _ticks(1500)
	print("BOT feed after: eaten %d, left %d" % [hn.fed, hn.grain.size()])
	if hn.grain.size() > 0:
		return _combat_done(false, "grain left lying a minute on")
	_world.time_of_day = 8.45
	for i in 2600:
		await get_tree().physics_frame
		var p := v.global_position
		var l := hn.cottage.to_local(p)
		if Hens.inside_yard(Vector2(l.x, l.z)):
			in_yard += 1
		if v.visits.get("wood", 0) > 0 and v.state == Villager.STAND:
			break
	print("BOT feed back: %s visits %s, warps %d, bag shown %s" % [v.activity, str(v.visits), v.warps, f.bag.visible])
	if v.visits.get("wood", 0) < 1 or v.warps > 0 or f.bag.visible:
		return _combat_done(false, "she did not get back to the woodpile")
	_combat_done(true, "Edda calls the hens as she comes, they gather at the wall, she casts grain over it and they run to it and eat it up")
