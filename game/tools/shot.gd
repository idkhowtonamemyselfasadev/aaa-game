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
	# (the frame above can resolve before the world's _process: without this the lenses that
	# read the sun -- `stonehouse ... sunny` -- aimed by the scene's default 17.25 h sun)
	world._apply_time()
	if args.size() > 3:
		# the folk were placed for the scene's default hour: put them where the shot's hour
		# has them (indoors with the lamp lit after dark, out at work by day)
		for who in [world.keeper, world.villager, world.neighbour]:
			if who != null:
				who.settle(world, world.time_of_day)
		for c in [world.stone_cottage, world.white_cottage]:
			c.lit = c._lit_now(world.time_of_day, 10.0)   # already kindled, not lighting up now
		world.cottage.lit = StoneCottage.lit_for(world.time_of_day)
	var player: Player = world.get_node("Player")
	var terrain: Terrain = world.get_node("Terrain")
	var cam: Camera3D = player.camera
	if spot == "credits":   # the Credits screen over the village view (not paused, so frames run)
		world.pause_menu.credits.show_screen()
		spot = "village"
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
	if spot == "roots":
		# close on the bole foot of the oak nearest the village edge: surface roots in the moss
		var flora: Flora = world.get_node("Flora")
		var best := flora.tree_positions[0]
		for q in flora.tree_positions:
			if Vector2(q.x + 20, q.z - 50).length() < Vector2(best.x + 20, best.z - 50).length():
				best = q
		var back := -best
		back.y = 0
		var cp := best + back.normalized() * 5.5
		cp.y = terrain.height_at(cp.x, cp.z) + 1.9
		SPOTS[spot] = [cp, best + Vector3.UP * 0.4]
	if spot == "boulder":
		# a big boulder near the village, seen from its shaded side (moss creeping up the flank)
		var flora: Flora = world.get_node("Flora")
		var bf := Vector3.ZERO
		for f: Vector3 in flora._rock_feet:
			if f.y > 1.8 and (bf == Vector3.ZERO or Vector2(f.x, f.z).length() < Vector2(bf.x, bf.z).length()):
				bf = f
		var dir := Vector3(-0.6, 0, -0.8).rotated(Vector3.UP, 0.6)
		var cp := Vector3(bf.x, 0, bf.z) + dir * (bf.y * 1.2 + 4.0)
		cp.y = terrain.height_at(cp.x, cp.z) + 1.6
		SPOTS[spot] = [cp, Vector3(bf.x, terrain.height_at(bf.x, bf.z) + bf.y * 0.15, bf.z)]
		print("SHOT boulder size %.1f at %s" % [bf.y, bf])
	if spot == "birds" or spot == "rooks":
		# "birds": camera close enough that the flock bursts up; "rooks": they keep feeding
		var site: Vector3 = world.get_node("Birds").site_positions()[0]
		var d := 9.0 if spot == "birds" else 15.5
		SPOTS[spot] = [site + Vector3(-d * 0.8, 0, d * 0.6), site + Vector3(0, -0.5 if spot == "rooks" else 3.5, 0)]
	if spot == "mob":
		# a kite caught low over the meadow by the rooks: it is sent down at the first flock
		# from 40 m out, the camera stands by the flock and is aimed up at it after the warm-up
		var bd: Birds = world.get_node("Birds")
		var site: Vector3 = bd.site_positions()[bd._flocks[0].site]
		SPOTS[spot] = [site + Vector3(-12.4, 0, 9.3), site + Vector3(0, 6, 0)]
		var kt: Birds.Bird = bd._kites[0]
		kt.pos = site + Vector3(20, terrain.height_at(site.x + 20, site.z + 15) - site.y + 18, 15)
		kt.vel = Vector3(-8, -3, -6)
		bd.stoop(kt)
	if spot == "midges":
		# a midge swarm against the low sun: camera on the far side, sun behind the cloud
		await get_tree().process_frame
		var c: Vector3 = world.get_node("Insects").swarm_centres()[0]
		var sd: Vector3 = world.sun.global_transform.basis.z
		sd.y = 0.0
		sd = sd.normalized()
		SPOTS[spot] = [c - sd * 3.2 + sd.cross(Vector3.UP) * 0.6, c + sd * 2.0]
		print("SHOT midge swarm at %s, sun dir %s" % [c, sd])
	if spot == "butterflies":
		# butterflies [species=0..3]: close and low on a settled one basking on the grass
		# heads, 4+ m from the hero; it is held settled for the shot
		var want_sp := 0
		for a in args:
			if a.begins_with("species="):
				want_sp = int(a.substr(8))
		for i in 20:
			await get_tree().process_frame
		var bf: Butterflies = world.get_node("Insects").butterflies
		var pick: Variant = null
		var pp := player.global_position
		for b in bf._bs:
			if b.state != Butterflies.REST or b.pos.distance_to(pp) < 4.0:
				continue
			var score: float = b.pos.distance_to(pp) + (0.0 if b.species == want_sp else 40.0) + (0.0 if b.bask > 0.0 or want_sp == 1 else 20.0)
			if pick == null or score < pick[0]:
				pick = [score, b]
		var bb = pick[1]
		bb.timer = 1.0e6
		var sd: Vector3 = world.sun.global_transform.basis.z
		var side := Vector3(sd.x, 0, sd.z).normalized().rotated(Vector3.UP, 0.7)
		SPOTS[spot] = [bb.pos + side * 0.17 + Vector3.UP * 0.11, bb.pos]
		print("SHOT butterfly species %d bask %.0f at %s" % [bb.species, bb.bask, bb.pos])
	if spot == "flowers":
		# flowers [species=0..3]: knee height in a wildflower drift near the hero, looking
		# across the heads toward the sun's side
		var want_fl := -1
		for a in args:
			if a.begins_with("species="):
				want_fl = int(a.substr(8))
		for i in 20:
			await get_tree().process_frame
		var grass: GrassField = world.get_node("Grass")
		var frng := RandomNumberGenerator.new()
		frng.seed = 3
		var fh := grass.flower_near(player.global_position, 14.0, frng, want_fl)
		var sd2: Vector3 = world.sun.global_transform.basis.z
		var back2 := Vector3(sd2.x, 0, sd2.z).normalized().rotated(Vector3.UP, 1.2)
		SPOTS[spot] = [fh + back2 * 0.9 + Vector3.UP * 0.12, fh - back2 * 3.0 - Vector3.UP * 0.2]
		print("SHOT flower at %s" % fh)
	if spot == "turf":
		# looking down at the meadow floor between the clumps a few metres from the hero:
		# the ground layer (turf, clover, moss, litter) close up. turf [dx] [dz] moves it.
		var pp := player.global_position
		var off := Vector3(4.0, 0, 3.0)
		for a in args:
			if a.begins_with("dx="):
				off.x = float(a.substr(3))
			if a.begins_with("dz="):
				off.z = float(a.substr(3))
		var g := pp + off
		SPOTS[spot] = [g + Vector3(-1.0, 1.5, -0.6), g + Vector3(0.6, -1.6, 0.4)]
	if spot == "puddles":
		# the nearest sure pool (Terrain.pond_at) to the hero, seen low from 7 m
		var pp2 := player.global_position
		var best := pp2
		var best_h := -1e9
		for j in 49:
			for i in 49:
				var q := pp2 + Vector3(i * 5.0 - 120.0, 0, j * 5.0 - 120.0)
				var hv: float = terrain.pond_at(q.x, q.z) - q.distance_to(pp2) * 0.002
				if hv > best_h:
					best_h = hv
					best = q
		var sdp: Vector3 = world.sun.global_transform.basis.z
		var tow := Vector3(sdp.x, 0, sdp.z).normalized()   # look into the sun: glint on water
		SPOTS[spot] = [best - tow * 4.5, best + tow * 1.5]
		print("SHOT puddle hollow %.2f m at %s" % [terrain.hollow_at(best.x, best.z), best])
	if spot == "wade":
		# the hero runs (+X) across the nearest sure pool, seen side-on (pass rain= to soak it)
		var pw := player.global_position
		var bw := pw
		var bh := -1e9
		for j in 49:
			for i in 49:
				var q := pw + Vector3(i * 5.0 - 120.0, 0, j * 5.0 - 120.0)
				var hv: float = terrain.pond_at(q.x, q.z) - q.distance_to(pw) * 0.002
				if hv > bh:
					bh = hv
					bw = q
		player.global_position = Vector3(bw.x - 3.2, terrain.height_at(bw.x - 3.2, bw.z) + 0.05, bw.z)
		player.use_bot_input = true
		player.set_look(-PI * 0.5, -0.1)
		player.bot_input = Vector2(0, -1)
		SPOTS[spot] = [bw + Vector3(0.4, 0, 3.4), bw + Vector3(0.4, 0, 0)]
		print("SHOT wade pool %.2f at %s" % [bh, bw])
	if spot == "shelter" or spot == "drip":
		# (drip: close in at the crown edge, where the leaves shed their water)
		# the hero sheltering under the oak nearest the start in a downpour, seen from the
		# open meadow: dry ground and no drops under the crown, rain all round it
		var flora: Flora = world.get_node("Flora")
		var p0 := player.global_position
		var best := Vector3.INF
		for q in flora.tree_positions:
			if flora.shelter_at(q.x + 1.6, q.z) > 0.7 and (best == Vector3.INF or q.distance_to(p0) < best.distance_to(p0)):
				best = q
		var hp := best + Vector3(1.6, 0, 0.4)
		player.global_position = Vector3(hp.x, terrain.height_at(hp.x, hp.z) + 0.05, hp.z)
		var out_dir := Vector3(1.0, 0, 0.55).normalized()
		var cp := best + out_dir * (11.0 if spot == "shelter" else 7.0)
		cp.y = terrain.height_at(cp.x, cp.z)
		SPOTS[spot] = [cp, best + Vector3.UP * (0.6 if spot == "shelter" else 1.2) - out_dir * 0.5]
		print("SHOT shelter oak at %s, shelter %.2f under it" % [best, flora.shelter_at(hp.x, hp.z)])
	if spot == "rookery":
		# the roost oaks at dusk from the meadow below, looking up at the crowns against the
		# afterglow; "roostin": the flocks are still streaming in and wheeling over the grove
		var birds: Birds = world.get_node("Birds")
		var rk := birds.rookery
		# stand ~50 m out on the side with the fewest oaks between the camera and the grove
		var flora: Flora = world.get_node("Flora")
		var cp := rk
		var best_n := 1 << 30
		for k in 12:
			var dir := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0))
			var n := 0
			for q in flora.tree_positions:
				for f in [0.45, 0.7, 1.0]:
					if Vector2(q.x - (rk.x + dir.x * 50.0 * f), q.z - (rk.z + dir.z * 50.0 * f)).length() < 9.0:
						n += 1
			if n < best_n:
				best_n = n
				cp = rk + dir * 50.0
		cp.y = terrain.height_at(cp.x, cp.z) + 1.7
		player.global_position = Vector3(cp.x, terrain.height_at(cp.x, cp.z) + 0.05, cp.z) + (rk - cp).normalized() * 4.0
		SPOTS[spot] = [cp, rk + Vector3.UP * 14.0]
		if "roosted" in args:   # already settled in the evening light (roost hour pulled early)
			birds.roost_hour = 17.0
			for fl in birds._flocks:
				birds.settle_roost(fl)
		if "roostin" in args:
			for fl in birds._flocks:
				var from := rk + Vector3(_rr(-40, 40), 16, _rr(30, 55))
				for bb in fl.birds:
					bb.pos = from + Vector3(_rr(-5, 5), _rr(-2, 2), _rr(-5, 5))
				birds._lift(fl, rk + Vector3.UP * 20.0, true)
				fl.air_t = 3.0
				for bb in fl.birds:
					bb.delay = 0.0
					bb.vel = (rk - bb.pos).normalized() * 8.0
		print("SHOT rookery at %s" % rk)
	if spot == "stonehouse":
		# the stone cottage, three-quarter from the front: door, windows, the slate
		# slope and the chimney stack ("close": at the door, up at the eaves and the slates)
		# ("white": the same lenses on the limewashed cottage)
		var ct: StoneCottage = world.white_cottage if "white" in args else world.stone_cottage
		var o := ct.global_basis.z
		var sd := ct.global_basis.x
		var mid := ct.global_position + Vector3.UP * (ct.floor_y + 2.4)
		if "sunny" in args:
			# close three-quarter on whichever wall (front, back or a gable) the sun lights most
			# at this hour, so the rubble is read in sunlight rather than flat sky shade
			var to_sun: Vector3 = world.sun.global_basis.z
			to_sun.y = 0.0
			var faces := [[o, sd, ct.wdep], [-o, -sd, ct.wdep], [sd, -o, ct.wlen], [-sd, o, ct.wlen]]
			var best: Array = faces[0]
			for f in faces:
				if (f[0] as Vector3).dot(to_sun) > (best[0] as Vector3).dot(to_sun):
					best = f
			var fo: Vector3 = best[0]
			var fs: Vector3 = best[1]
			var wc: Vector3 = ct.global_position + Vector3.UP * (ct.floor_y + 1.2) + fo * (float(best[2]) * 0.5)
			SPOTS[spot] = [wc + fo * 3.4 + fs * 1.8 + Vector3.UP * 0.3, wc - fs * 0.6 + Vector3.UP * 0.2]
			print("SHOT stonehouse sunny face %s (sun dot %.2f, to sun %s)" % [fo, fo.dot(to_sun.normalized()), world.sun.global_basis.z])
		elif "butt" in args and ct is WhiteCottage:
			# the water butt under the eaves drip, a little above it so the water shows, the
			# bench and the door beyond along the wall
			var bp: Vector3 = (ct as WhiteCottage).butt.global_position
			SPOTS[spot] = [bp + o * 1.7 + sd * 0.9 + Vector3.UP * 2.0, bp + Vector3.UP * 0.5 - sd * 1.2]
		elif "lean" in args and ct is WhiteCottage:
			# the woodshed lean-to off the east gable from the green, three-quarter on its
			# open end: the woodpile inside, the chopping block and the axe out front
			var gx := ct.wlen * 0.5
			var lm := ct.to_global(Vector3(gx + 0.9, ct.floor_y + 0.5, -0.7))
			var cp := ct.to_global(Vector3(gx + 2.3, 0.0, WhiteCottage.LEAN_Z + 3.3))
			cp.y = terrain.height_at(cp.x, cp.z) + 2.0
			SPOTS[spot] = [cp, lm]
		elif "close" in args:
			SPOTS[spot] = [ct.door_gap + o * 3.2 + sd * 1.6 + Vector3.UP * 0.6, ct.door_gap + Vector3.UP * 1.3 - sd * 0.8]
		else:
			SPOTS[spot] = [mid + o * 12.0 + sd * 7.5 - Vector3.UP * 0.6, mid - Vector3.UP * 0.5]
		var pp := ct.door_gap + o * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT stonehouse at %s, %d stones %d slates" % [ct.global_position, ct.stone_count, ct.slate_count])
	if spot == "hens":
		# low in the garth, ~2 m off the nearest hen with the flock and the cottage's back
		# wall beyond ("wide": from the yard's far corner, the whole flock and the house)
		var hn: Hens = world.hens
		var ct: StoneCottage = world.stone_cottage
		for i in 120:
			hn._process(1.0 / 30.0)
		var hp := hn.at(0)
		var mid := ct.to_global(Vector3(0, 0, -5.5))
		var cp: Vector3
		if "house" in args:
			# the hen house from the yard, three-quarter on its ladder face, a hen part way up
			var h0: Dictionary = hn.hens[0]
			h0.state = Hens.CLIMB
			h0.c = 0.15
			h0.wing = 0.0
			hn._process(0.0)
			hp = hn.at(0)
			cp = ct.to_global(Vector3(-0.2, 0, -6.4))
			cp.y = terrain.height_at(cp.x, cp.z) + 1.15
			var tgt := ct.to_global(Vector3(-2.9, 0, -8.5))
			tgt.y = hn.house.base_y + 0.55
			SPOTS[spot] = [cp, tgt]
		elif "wide" in args:
			cp = ct.to_global(Vector3(2.2, 0, -9.2))
			cp.y = terrain.height_at(cp.x, cp.z) + 1.25
			SPOTS[spot] = [cp, mid + Vector3.UP * 0.4]
		else:
			var away := (hp - ct.to_global(Vector3(0, 0, -3.0)))
			away.y = 0
			away = away.normalized()
			cp = hp + away * 1.9 + ct.global_basis.x * 0.5
			var cl := Hens.clamp_yard(Vector2(ct.to_local(cp).x, ct.to_local(cp).z))
			cp = ct.to_global(Vector3(cl.x, 0, cl.y))
			cp.y = terrain.height_at(cp.x, cp.z) + 0.75
			SPOTS[spot] = [cp, hp + Vector3.UP * 0.25]
		var pp := ct.door_gap + ct.global_basis.z * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT hens: hen 0 at %s state %d, cam %s" % [hp, hn.hens[0].state, cp])
	if spot == "drywall" or spot == "yardwall":
		# the garth wall behind the stone cottage: from outside the east side, at the
		# gateway with the wall running back and the house beyond ("back": from beyond the
		# back corner, along the back run toward the gable and its chimney)
		var dw: DryWall = world.dry_wall
		var ct: StoneCottage = world.stone_cottage
		var bz := ct.global_basis.z
		var bx := ct.global_basis.x
		var g := dw.gate
		if "back" in args:
			var cn := ct.to_global(Vector3(7.5, 0, -14.5))
			cn.y = terrain.height_at(cn.x, cn.z) + 1.7
			var lk := ct.to_global(Vector3(-3.0, 0, -6.0))
			lk.y = terrain.height_at(lk.x, lk.z) + 1.4
			SPOTS[spot] = [cn, lk]
		elif "stile" in args:
			# the squeeze stile in the back run, from the fell footpath outside, a little off
			# square so both slabs and the slot between them show, the garth beyond
			var sc := ct.to_global(Vector3(0.4, 0, -14.3))
			sc.y = terrain.height_at(sc.x, sc.z) + 1.55
			SPOTS[spot] = [sc, dw.stile + Vector3.UP * 0.55]
		elif "gate" in args:
			# close on the field gate from outside, a little off square ("ajar": swung half
			# open into the yard)
			var gc := dw.field_gate.centre()
			var ow := (g - ct.to_global(Vector3(0, 0, -6.7)))
			ow.y = 0
			ow = ow.normalized()
			var cp := gc + ow * 3.4 + bz * 1.3
			cp.y = terrain.height_at(cp.x, cp.z) + 1.5
			SPOTS[spot] = [cp, gc - ow * 0.6 - Vector3.UP * 0.15]
		else:
			var cp := g + bx * 5.5 + bz * 3.0
			cp.y = terrain.height_at(cp.x, cp.z) + 1.65
			SPOTS[spot] = [cp, g - bz * 2.2 + Vector3.UP * 0.9]
		if "ajar" in args:
			dw.field_gate.pose(-0.75)
		var pp := ct.door_gap + bz * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT drywall gate %s, %d stones" % [g, dw.stone_count])
	if spot == "ruin" or spot == "ruinin":
		# the watchtower ruin on its knoll: "ruin" from the approach below the breach,
		# "ruinin" standing in the breach looking across the floor at the inner face
		var rs: Vector3 = world.get_node("Ruins").site
		var to_v := Vector3(-rs.x, 0, -rs.z).normalized()
		if spot == "ruin":
			# from up the slope with the sun over the shoulder: between the breach side and
			# the sunward side, so the keep is lit and the breach still shows
			var sd: Vector3 = world.sun.global_transform.basis.z
			var sunward := Vector3(sd.x, 0, sd.z).normalized()
			var dir := (to_v + sunward * 1.3).normalized()
			SPOTS[spot] = [rs + dir * 22.0, rs + Vector3.UP * 1.5]
		else:
			SPOTS[spot] = [rs + to_v * 2.2 + to_v.cross(Vector3.UP) * 0.8, rs - to_v * 4.0]
		var pp := rs + to_v * 40.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT ruin at %s" % rs)
	if spot == "keeper" or spot == "keeperback" or spot == "keeperside":
		# Hesper, the shrine keeper, three-quarter from the front at her spot for the hour
		# ("keeperback": three-quarter from behind, for the basket and the stoop; "keeperside":
		# square side-on, for the skirt)
		var kp: Keeper = world.keeper
		kp.settle(world, world.time_of_day)
		var at := kp.global_position
		var yaw := kp.body.rotation.y
		kp._gather_t = 1.0e6                       # hold her at this spot for the frame
		kp.pick_hold = "pick" in args              # down in the litter, reaching
		var off := 0.55 if spot == "keeper" else (PI * 0.5 if spot == "keeperside" else PI - 0.8)
		var dir := Vector3(sin(yaw + off), 0, cos(yaw + off))
		var dir2 := Vector3(sin(yaw - off), 0, cos(yaw - off))
		var flora: Flora = world.get_node("Flora")
		var clear := func(d: Vector3) -> float:
			var m := INF
			for q in flora.tree_positions:
				m = minf(m, Vector2(q.x - (at.x + d.x * 3.0), q.z - (at.z + d.z * 3.0)).length())
			return m
		if clear.call(dir2) > clear.call(dir):
			dir = dir2
		if spot == "keeperside" and "pick" in args:
			# the low pick lens on the oak's slope tilts the frame (the hillside runs across it
			# diagonally); swing the lens round her, up to 0.6 rad off square, to the side
			# whose ground runs most level across the frame, keeping clear of the boles
			var best := INF
			for base in [off, -off]:
				for k in [0.0, 0.3, -0.3, 0.45, -0.45, 0.6, -0.6]:
					var a: float = yaw + base + k
					var d := Vector3(sin(a), 0, cos(a))
					if clear.call(d) < 2.6:
						continue
					var r := d.cross(Vector3.UP) * 2.5
					var c := at + d * 3.0
					var cross := absf(terrain.height_at(c.x + r.x, c.z + r.z) - terrain.height_at(c.x - r.x, c.z - r.z))
					var score := cross + absf(k) * 0.4          # prefer near side-on
					if score < best:
						best = score
						dir = d
			print("SHOT keeperside pick cross-slope score %.2f" % best)
		var cp := at + dir * 3.0
		cp.y = maxf(terrain.height_at(cp.x, cp.z), at.y) + 1.55
		var rel := Vector3(at.x - kp.site.x, 0, at.z - kp.site.z)
		if rel.length() < Keeper.KEEP_R and spot == "keeper":
			# on the keep floor: from across the shrine lid, over the plinth, at her eye level
			cp = kp.site - rel.normalized() * 0.9 + rel.normalized().cross(Vector3.UP) * 0.6
			cp.y = at.y + 1.45
		if kp.pick_hold:
			# crouched at the litter: low and back, near her own height, so the reach reads
			# side-on against the grove instead of from above
			# side-on against the grove instead of from above; aimed level (look target at the
			# lens height) so the oak's slope does not tilt the frame into the grass
			cp = at + dir * 3.0
			cp.y = maxf(terrain.height_at(cp.x, cp.z) + 0.45, at.y + 0.65)
		kp.toss_hold = "toss" in args              # up, dropping a find in the basket
		var look_at := at + Vector3.UP * 1.15
		if kp.pick_hold:
			look_at = Vector3(at.x, cp.y - 0.08, at.z)
		SPOTS[spot] = [cp, look_at]
		var pp := at + Vector3(30, 0, 30)
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT keeper %s at %s" % [kp.activity, at])
	if spot == "dog":
		# Brack on the white cottage's track (where the sward is trodden short), sat watching
		# the yard (or "sniff": nose to the turf; "door": in its place by the door; "down":
		# lying in the sun); the lens
		# stands further out on the same track looking back up it at the dog and the door
		var dg: Dog = world.dog
		var run: PackedVector2Array = DoorStones.runs()[1][0]
		var dl := 1.0 if "door" in args else 4.5
		var dq: Array = DoorStones.along(run, dl)
		var lq: Array = DoorStones.along(run, dl + (2.4 if "close" in args else 3.4))
		var at := dg._ground(Vector3(dq[0].x, 0, dq[0].y))
		if "door" in args:
			dg.place_bed()
			at = dg.bed
			dg.doze = dg.lie   # long settled: asleep, chin on its paws
		else:
			dg.global_position = at
			dg._start(Dog.SNIFF if "sniff" in args else Dog.REST, 1e6)
			dg.sit = 0.0 if "sniff" in args else 1.0
			dg.graze = 1.0 if "sniff" in args else 0.0
			dg.yaw = atan2(-dq[1].x, -dq[1].y) + 0.5   # facing out down the track, turned a little
			if "down" in args:   # a daytime rest taken lying, head up
				dg.sit = 1.0
				dg.lie = 1.0
				dg.rest_down = true
		at = dg.global_position
		var lv := Vector2(lq[0].x, lq[0].y) + Vector2(-lq[1].y, lq[1].x) * 0.6
		var cp := Vector3(lv.x, terrain.height_at(lv.x, lv.y) + 1.25, lv.y)
		SPOTS[spot] = [cp, Vector3(at.x, at.y + 0.35, at.z)]
		var pp := at + Vector3(40, 0, 40)
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT dog at %s yaw %.2f state %d lie %.2f" % [at, dg.yaw, dg.state, dg.lie])
	if spot == "hare":
		# a brown hare in the south-east meadow, sat up watching (or "feed": nose down in the
		# grass; "run": bolting); low over the grass from 1.8 m (at 3.5 m it filled ~40 px),
		# three-quarter front
		var hr: Hare = world.hares[0]
		var st := Hare.FEED if "feed" in args else (Hare.BOLT if "run" in args else Hare.ALERT)
		var at := hr.global_position
		hr.place(at, 0.6, st)
		if st == Hare.BOLT:
			hr.speed = 10.0
			hr.ears_back = 0.85
			hr.set_process(false)
			hr._pose(0.0)
		var fwd := Vector3(-sin(hr.yaw), 0, -cos(hr.yaw))
		var lv := at + fwd.rotated(Vector3.UP, 0.75 if st != Hare.BOLT else 1.45) * 1.8
		var cp := Vector3(lv.x, terrain.height_at(lv.x, lv.z) + 0.6, lv.z)
		SPOTS[spot] = [cp, Vector3(at.x, at.y + 0.2, at.z)]
		var pp := at + Vector3(60, 0, 60)
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT hare at %s yaw %.2f state %d" % [at, hr.yaw, hr.state])
	if spot == "fox":
		# the fox sat just in from the breach at the edge of Hesper's firelight, looking in at
		# the fire: low, three-quarter from round the floor ring (Fox.lens_of)
		var kp: Keeper = world.keeper
		kp.settle(world, world.time_of_day)
		var fx: Fox = world.fox
		fx.place_sitting()
		if "crust" in args:
			fx.place_eating()
		var hp: Vector3 = world.hearth.global_position
		var to_fx := Vector3(fx.sit_at.x - hp.x, 0, fx.sit_at.z - hp.z).normalized()
		var cp := Fox.lens_of(kp.site)
		if "side" in args:
			# square side-on, to check the sit pose (hind legs folded, brush round the paws)
			cp = fx.sit_at + to_fx.cross(Vector3.UP) * 1.6
		cp.y = terrain.height_at(cp.x, cp.z) + 0.55
		SPOTS[spot] = [cp, Vector3(fx.sit_at.x, fx.sit_at.y + 0.3, fx.sit_at.z)]
		if "henhouse" in args:
			# the small hours at Osric's hen house: up the hens' ladder, nose to the shut slide;
			# from the garth, side-on three-quarter across the ladder, the house filling the frame
			var hn: Hens = world.hens
			hn._settle_now()
			hn.house.set_shut(true)
			fx.place_at_slide()
			var sc: Node3D = world.stone_cottage
			var lp := sc.to_global(Vector3(-2.1, 0, -6.75))
			lp.y = terrain.height_at(lp.x, lp.z) + 0.75
			var tg := fx.global_position + Vector3.UP * 0.25
			SPOTS[spot] = [lp, tg]
			var pp := fx.global_position + Vector3(40, 0, 40)
			player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
			print("SHOT fox at the slide %s pitch %.2f yaw %.2f slide %.2f" % [fx.global_position, fx.pitch, fx.yaw, hn.house.shut])
		if "crust" in args:
			# eating Hesper's crust: front three-quarter from out by the wall foot (Fox.crust_lens_of)
			var fq := fx.global_position
			cp = Fox.crust_lens_of(kp.site)
			cp.y = terrain.height_at(cp.x, cp.z) + 0.55
			SPOTS[spot] = [cp, Vector3(fq.x, fq.y + 0.15, fq.z)]
			if OS.get_environment("FOXDBG") != "":
				var rn: Ruins = world.get_node("Ruins")
				var fwd := Vector3(-sin(fx.yaw), 0, -cos(fx.yaw))
				var head := fq + fwd * 0.45 + Vector3.UP * 0.2
				print("SHOT foxdbg site %s fox %s yaw %.2f crust %s hearth %s cam %s head %s" % [kp.site, fq, fx.yaw, fx._scrap.global_position, hp, cp, head])
				for per in rn._per:
					for e in per:
						var xf: Transform3D = e[0]
						var o := xf.origin
						var ab := head - cp
						var t := clampf((o - cp).dot(ab) / ab.length_squared(), 0.0, 1.0)
						var dd := (cp + ab * t).distance_to(o)
						if dd < 0.6 or o.distance_to(head) < 0.8:
							print("SHOT foxdbg block %s r %.2f ang %.2f d_line %.2f d_head %.2f t %.2f size %s laid %.0f" % [o, Vector2(o.x - kp.site.x, o.z - kp.site.z).length(), 0, dd, o.distance_to(head), t, xf.basis.get_scale(), (e[1] as Color).b])
		if "close" in args:
			# a portrait lens a metre off its face, a little to the side
			cp = fx.sit_at - to_fx * 1.05 + to_fx.cross(Vector3.UP) * 0.5
			cp.y = fx.sit_at.y + 0.5
			SPOTS[spot] = [cp, Vector3(fx.sit_at.x, fx.sit_at.y + 0.38, fx.sit_at.z)]
		var pp := kp.site + kp.to_v * 60.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
	if spot == "hearth":
		# Hesper's cookfire on the keep floor: from across the floor by the lid, the fire in
		# the foreground, her bed and the inner face lit behind it (at night she dozes by it)
		var kp: Keeper = world.keeper
		kp.settle(world, world.time_of_day)
		var hp: Vector3 = world.hearth.global_position
		var kn: Vector3 = kp._spots["kindle"][0]
		if "kindle" in args:
			# the lighting moment: down at the ring, the tinder smoking and the first flames up
			kp._place(kn)
			kp.body.rotation.y = kp._spots["kindle"][1]
			kp.goal_yaw = kp.body.rotation.y
			kp.state = Keeper.STAND
			kp.pick = 1.0
			kp.pick_hold = true                   # stays down for the frame
			world.hearth.kindled = 13.0
			world.hearth.strike_flint(kn)
		# from standing on the lid, across the keep floor: the fire and Hesper side by side
		# with the inner face and its ivy lit behind them (was a lens down in the wall-foot
		# rubble)
		var mid := (hp + kn) * 0.5
		var outw := Vector3(mid.x - kp.site.x, 0, mid.z - kp.site.z).normalized()
		# from the lid's front edge (0.82 m radius), so its rim drops below the frame instead
		# of filling the bottom fifth
		var cp := kp.site + outw * 0.55
		cp.y = hp.y + 1.95
		# aimed a little higher so the sooted face over the fire fills the frame, not the plinth
		SPOTS[spot] = [cp, Vector3(mid.x, hp.y + 0.8, mid.z)]
		if "kindle" in args:
			# on her face side: she kneels three-quarter on to the lens, her firelit front and
			# hands at the tinder, the flames beside her and the inner face behind
			var sp := Keeper.kindle_lens(kp.site)
			SPOTS[spot] = [sp, Vector3(kn.x, hp.y + 0.5, kn.z).lerp(Vector3(hp.x, hp.y + 0.3, hp.z), 0.4)]
			var near := 0
			var ruins: Ruins = world.get_node("Ruins")
			for v in ruins._per.size():
				for e in ruins._per[v]:
					var o: Vector3 = e[0].origin
					if Vector2(o.x - sp.x, o.z - sp.z).length() < 1.2:
						near += 1
			print("SHOT kindle lens: %d keep stones within 1.2 m of its foot" % near)
		if "warm" in args:
			# three-quarter on to her as she sits warming her hands: from the keep floor on her
			# face side, her firelit front and hands, the flames beside her, the wall behind
			var kb: Vector3 = kp._spots["sleep"][0]
			var inw := Vector3(kp.site.x - kb.x, 0, kp.site.z - kb.z).normalized()
			var tf := Vector3(hp.x - kb.x, 0, hp.z - kb.z).normalized()
			var sp := kb + (inw * 0.8 + tf * 0.6).normalized() * 2.1
			sp.y = hp.y + 1.15
			SPOTS[spot] = [sp, kb.lerp(hp, 0.45) + Vector3.UP * 0.45]
		if "flick" in args:
			# the crust in her raised hand, about to go to the fox sat in the breach
			world.fox.place_sitting()
			kp.warm_hold = 1.0
			kp.sit = 1.0
			kp.throw_scrap()
			kp.flick_hold = Keeper.FLICK_UP
		var pp := kp.site + (kp.to_v) * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT hearth at %s, level %.2f, Hesper %s" % [hp, Hearth.level_for(world.time_of_day), kp.activity])
	if spot == "talk":
		# speaking with Hesper: over the hero's shoulder at her, out under an oak by day, her
		# line as a subtitle
		var kp: Keeper = world.keeper
		kp.settle(world, world.time_of_day)
		kp._gather_t = 1.0e6
		var at := kp.global_position
		var oak: Vector3 = kp._oaks[kp._gather_i] if not kp._oaks.is_empty() else at + Vector3.FORWARD
		var away := Vector3(at.x - oak.x, 0, at.z - oak.z).normalized()
		var pp := at + away.rotated(Vector3.UP, 0.5) * 2.1
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.05, pp.z)
		var to_k := Vector3(at.x - pp.x, 0, at.z - pp.z).normalized()
		player.body.rotation.y = atan2(to_k.x, to_k.z)
		kp.body.rotation.y = atan2(-to_k.x, -to_k.z)
		kp.goal_yaw = kp.body.rotation.y
		kp.talking = 1.0e6
		var hud: Hud = player.get_node("Hud")
		hud.say("Hesper", Keeper.INTRO[1], 1.0e6)
		if "quest" in args:
			# mid-errand: the loaf handed over, her word for Edda on the subtitle, the next
			# objective in the quest corner
			var ql: Quests = player.get_node("Quests")
			ql.stage[Quests.BREAD] = 2
			hud.say("Hesper", Quests.DEFS[Quests.BREAD]["talk"][1][1], 1.0e6)
		var cp := pp - to_k * 2.4 + to_k.cross(Vector3.UP) * 1.45
		cp.y = terrain.height_at(cp.x, cp.z) + 1.75
		SPOTS[spot] = [cp, at.lerp(pp, 0.3) + Vector3.UP * 1.3]
		print("SHOT talk %s at %s" % [kp.activity, at])
	if spot == "fellbell":
		# Osric's bellwether's bell on the last fold post under the great stone, the quest at its
		# first step (the Take prompt up); `wide` stands back to show the stone and the vale below
		var b: FellBell = world.fell_bell
		var ql: Quests = player.get_node("Quests")
		ql.stage[Quests.FLOCK] = 1
		var at := b.post_top
		var down := Vector3(FellBell.TOWARD.x - at.x, 0, FellBell.TOWARD.y - at.z).normalized()
		var sd := down.cross(Vector3.UP)
		var pp := at + down * 1.1 + sd * 0.5
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.05, pp.z)
		player.body.rotation.y = atan2(at.x - pp.x, at.z - pp.z)
		var cp := at + down * 0.5 - sd * 0.35 if not "wide" in args else at + down * 5.5 - sd * 2.5
		cp.y = at.y + (-0.1 if not "wide" in args else 1.2)
		var look := at + Vector3.DOWN * 0.2 if not "wide" in args else at - down * 2.5 + Vector3.UP * 0.4
		if not "wide" in args and not "fold" in args:
			# the hero's fresh track up to the post: the sward under the close lens lies trodden
			# (its standing straw ribbons filled the frame), then lift the lens a little over it
			var tr := PackedVector3Array()
			for o in [Vector3(6.0, 0, -0.6), Vector3(2.6, 0, -0.4), Vector3(0.5, 0, -0.35), Vector3(0.15, 0, -0.1)]:
				var q: Vector3 = at + down * o.x + sd * o.z
				tr.append(Vector3(q.x, terrain.height_at(q.x, q.z), q.z))
			tr.append(player.global_position)
			world.trample.seed_trail(tr, 1.2, 0.1)
			world.trample.frozen = true
			cp = at + down * 0.75 - sd * 0.4
			cp.y = at.y + 0.05
			look = at + Vector3.DOWN * 0.3
		if "fold" in args:
			# the ruined fold ring from down the slope outside it, the post at its gateway
			var fc2 := FellBell.fold_centre()
			var fc := Vector3(fc2.x, terrain.height_at(fc2.x, fc2.y), fc2.y)
			cp = fc + down * 7.5 - sd * 3.5
			cp.y = maxf(terrain.height_at(cp.x, cp.z), fc.y) + 3.0
			look = fc + Vector3.UP * 0.3
			print("SHOT fellbell fold: %d stones" % b.fold_stones)
			world.wheatears.seat_for_shot(cp, 2.0)
			if "birds" in args:
				# close on the cock on his wall top, low beside the wall, the great stone behind him
				var wp: Vector3 = world.wheatears.bird_positions()[0]
				var outw := Vector3(wp.x - fc.x, 0, wp.z - fc.z).normalized()
				cp = wp + outw * 1.1 + outw.cross(Vector3.UP) * 0.6 + Vector3.UP * 0.12
				look = wp + Vector3.UP * 0.07
			if "plain" in args:
				# diagnostic: the fold stones in a flat grey StandardMaterial3D, to tell the masonry
				# shader's shading from the geometry/normals when they read near-black
				var pm := StandardMaterial3D.new()
				pm.albedo_color = Color(0.5, 0.5, 0.5)
				pm.roughness = 0.9
				for ch in b.get_children():
					if ch is MultiMeshInstance3D and ch.name.begins_with("Fold_"):
						ch.material_override = pm
		SPOTS[spot] = [cp, look]
		print("SHOT fellbell at %s" % at)
	if spot == "wander":
		# Hesper on her afternoon meadow walk, the deer grazing on beyond her
		var kp: Keeper = world.keeper
		kp.settle(world, 14.0)
		kp._gather_t = 1.0e6
		var at := kp.global_position
		var outw := Vector3(at.x - kp.site.x, 0, at.z - kp.site.z).normalized()
		world.herd.place(at + outw * 16.0 + outw.cross(Vector3.UP) * 3.0)
		var to_h := Vector3(world.herd.centre().x - at.x, 0, world.herd.centre().z - at.z).normalized()
		kp.body.rotation.y = atan2(to_h.x, to_h.z)
		kp.goal_yaw = kp.body.rotation.y
		kp._rest_yaw = kp.goal_yaw
		var pp := at - outw * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.05, pp.z)
		var cp := at - to_h * 4.5 + to_h.cross(Vector3.UP) * 1.6
		cp.y = maxf(terrain.height_at(cp.x, cp.z), at.y) + 2.1
		SPOTS[spot] = [cp, at + to_h * 5.0 + Vector3.UP * 0.9]
		print("SHOT wander %s at %s, herd %.1f m" % [kp.activity, at, at.distance_to(world.herd.centre())])
	if spot == "seal":
		# the carved shrine lid in the keep floor, the hero standing at its edge so it wakes
		var rs: Vector3 = world.get_node("Ruins").site
		var to_v := Vector3(-rs.x, 0, -rs.z).normalized()
		var side := to_v.cross(Vector3.UP)
		SPOTS[spot] = [rs + to_v * 2.0 + side * 0.9, rs - to_v * 0.2]
		var pp := rs + to_v * 1.2 - side * 1.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.6, pp.z)
		if "footing" in args:
			# from the downhill side, where the footing courses step the plinth down to the turf
			var lo := INF
			var best := 0.0
			for k in 32:
				var a := TAU * k / 32.0
				var g: float = terrain.height_at(rs.x + cos(a) * 2.6, rs.z + sin(a) * 2.6)
				if g < lo:
					lo = g
					best = a
			var dv := Vector3(cos(best), 0, sin(best))
			var sd := dv.cross(Vector3.UP)
			SPOTS[spot] = [rs + dv * 5.2 + sd * 1.8, rs + dv * 1.7]
			pp = rs + dv * 1.0 - sd * 0.6
			player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.6, pp.z)
		print("SHOT seal at %s" % rs)
	if spot == "fireflies":
		# low over the night meadow just beside the hero, looking out across the grass
		var pp := player.global_position
		SPOTS[spot] = [pp + Vector3(-1.5, 0, 2.5), pp + Vector3(6, 0, -14)]
	if spot == "hero":
		# close three-quarter portrait of the idle player character
		var pp := player.global_position
		var fwd := player.body.global_transform.basis.z
		SPOTS[spot] = [pp + fwd.rotated(Vector3.UP, 0.6) * 3.2, pp]
		if "guard" in args:
			# "guard": the same portrait with the staff drawn and held in the mid guard
			player.use_bot_input = true
			player.combat._begin_draw()
			for i in 40:
				player.combat.physics_step(1.0 / 60.0)
			player.combat.idle_t = -1.0e6
			# camera on the sun side, 1.3 rad to the left of the hero's facing, so the whole
			# diagonal shaft (tip forward-left) shows clear of the arms and the hero is lit
			var light: Vector3 = -world.sun.global_transform.basis.z
			var to_cam := Vector3(-light.x, 0, -light.z).normalized()
			# (+1.3 rad and a raised lens: at +0.9 the shaft foreshortened to a level bar)
			player.body.rotation.y = atan2(to_cam.x, to_cam.z) + 1.3
			SPOTS[spot] = [pp + to_cam * 3.0 + Vector3.UP * 0.7, pp + Vector3.UP * 0.0]
			print("SHOT hero guard, staff drawn %s" % player.combat.is_drawn())
	if spot == "herocu":
		# the hero at ~2 m, chest up, three-quarter from the front: the range cutscenes see him at
		var pp := player.global_position
		var fwd := player.body.global_transform.basis.z
		SPOTS[spot] = [pp + fwd.rotated(Vector3.UP, 0.5) * 2.0, pp]
	if spot == "slope":
		# foot IK: the hero standing across the 22 deg hillside the `footik` bot uses, seen from
		# in front at shin height so the uphill and the downhill boot read at their own ground
		# (args: noik = the clip's flat stance, for comparison; side = from downhill)
		var sp := Vector3(34.0, 0, -81.0)
		for a in args:
			if a.begins_with("at="):
				var xz := a.substr(3).split(",")
				sp = Vector3(float(xz[0]), 0, float(xz[1]))
		if "step" in args and not Array(args).any(func(a): return String(a).begins_with("at=")):
			sp = player.global_position + Vector3(3.0, 0, -6.0)    # the footik bot's flat turf
		var n: Vector3 = terrain.normal_at(sp.x, sp.z, 0.6)
		var dn := Vector3(n.x, 0, n.z).normalized()
		var along := dn.cross(Vector3.UP)
		player.global_position = Vector3(sp.x, terrain.height_at(sp.x, sp.z) + 0.05, sp.z)
		player.velocity = Vector3.ZERO
		player.body.rotation.y = atan2(along.x, along.z)
		player.foot_ground_on = not ("noik" in args)
		var pp := player.global_position
		var eye := pp + (dn * 2.2 + Vector3.UP * 0.2 if "side" in args else along * 2.0 + dn * 0.3 + Vector3.UP * 0.45)
		if "step" in args:
			# toe IK: a dressed 16 cm block of the ruins' masonry set just ahead of the ankles, so
			# its edge runs under the balls of the feet; seen side-on at boot height
			var blk := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(1.0, 0.16, 0.8)
			cs.shape = bx
			blk.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bx.size
			mi.mesh = bm
			var rn := world.get_node_or_null("Ruins")
			if rn != null and rn.get("material") != null:
				mi.material_override = rn.material
			blk.add_child(mi)
			world.add_child(blk)
			var f := along
			var sd := f.cross(Vector3.UP)
			var gy := terrain.height_at(pp.x + f.x * 0.46, pp.z + f.z * 0.46)
			blk.global_transform = Transform3D(Basis(sd, Vector3.UP, f), Vector3(pp.x, gy + 0.06, pp.z) + f * (0.06 + 0.4))
			player.add_collision_exception_with(blk)
			eye = pp + sd * 1.6 + f * 0.25 + Vector3.UP * 0.3
		if "stepdown" in args:
			# step-down: the hero walks along the turf off the end of a 0.3 m masonry course (two
			# courses of 0.15 m, so it steps down twice), seen side-on at hip height
			var f := along
			var sd := f.cross(Vector3.UP)
			for c in 2:
				var blk := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				var ln := 2.4 - 0.45 * c
				bx.size = Vector3(1.2, 0.15 * (c + 1) + 0.3, ln)
				cs.shape = bx
				blk.add_child(cs)
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = bx.size
				mi.mesh = bm
				var rn := world.get_node_or_null("Ruins")
				if rn != null and rn.get("material") != null:
					mi.material_override = rn.material
				blk.add_child(mi)
				world.add_child(blk)
				var gy := terrain.height_at(pp.x, pp.z)
				# both courses end ahead of the hero: the top one 0.55 m on, the lower 1.0 m on
				blk.global_transform = Transform3D(Basis(sd, Vector3.UP, f), Vector3(pp.x, gy - 0.3 + bx.size.y * 0.5, pp.z) + f * (0.55 + 0.45 * c - ln * 0.5))
			player.global_position = pp + Vector3.UP * 0.35
			player.use_bot_input = true
			player.set_meta("shot_walk", f)
			eye = pp + f * 0.9 + sd * 3.4 + Vector3.UP * 0.6
			SPOTS[spot] = [eye, pp + f * 0.9 + Vector3.UP * 0.5]
		elif "step" in args:
			SPOTS[spot] = [eye, pp + Vector3.UP * 0.25 + along * 0.15]
		else:
			SPOTS[spot] = [eye, pp + Vector3.UP * 0.45]
		print("SHOT slope at %s, %.1f deg, ik %s" % [pp, rad_to_deg(acos(n.y)), player.foot_ground_on])
	if spot == "face":
		# head-and-shoulders of the idle player from the front-left: hat, hood, face cloth
		var pp := player.global_position
		var fwd := player.body.global_transform.basis.z
		SPOTS[spot] = [pp - fwd.rotated(Vector3.UP, 0.45) * 1.5, pp]
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
	if spot == "post":
		# post: a close 3/4 look at the practice post from the sun side, at chest height
		var post: Vector3 = world.training_post.global_position
		var light: Vector3 = -world.sun.global_transform.basis.z
		var to_cam := Vector3(-light.x, 0, -light.z).normalized().rotated(Vector3.UP, 0.6)
		SPOTS[spot] = [post + to_cam * 2.1 + Vector3.UP * 1.35, post + Vector3.UP * 0.95]
	if spot == "sentinel":
		# sentinel [awake] [close]: the Stone Sentinel on its post, the hero 6.5 m off on its
		# facing; a 3/4 view from the sun side, low, the statue filling the right of the frame.
		# `awake`: it wakes as the frames run (shudder, grit, the rune kindling)
		var sn: StoneSentinel = world.sentinel
		var post: Vector3 = sn._home
		var f3 := sn.body.global_basis.z
		f3.y = 0.0
		f3 = f3.normalized()
		var hp := post + f3 * 6.5
		player.global_position = Vector3(hp.x, terrain.height_at(hp.x, hp.z) + 0.05, hp.z)
		player.body.rotation.y = atan2(-f3.x, -f3.z)
		var light: Vector3 = -world.sun.global_transform.basis.z
		var side := f3.cross(Vector3.UP)
		if side.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
			side = -side
		var dist := 2.6 if "close" in args else (12.0 if "far" in args else 4.6)
		var scam := post + f3 * dist * 0.8 + side * dist * 0.6
		scam.y = terrain.height_at(scam.x, scam.z) + (1.5 if "close" in args else 1.2)
		SPOTS[spot] = [scam, post + Vector3.UP * (1.55 if "close" in args else (0.7 if "far" in args else 1.3)) + f3 * 0.4]
		if "awake" in args:
			sn.wake()
		if "slam" in args:
			# slam: the hero 3.4 m off, the statue already loose: it plants, heaves the glaive
			# and brings it down (~2.5 s to the impact; ~75 frames at 30 fps for the hold,
			# ~85 for the crack and shock), seen side-on from the sun side, wider
			hp = post + f3 * 3.4
			player.global_position = Vector3(hp.x, terrain.height_at(hp.x, hp.z) + 0.05, hp.z)
			sn.dormant = false
			sn.force_move = StoneSentinel.SLAM_MOVE
			sn._enter(HollowSoldier.STALK)
			var mid := post + f3 * 1.9
			scam = mid + side * 5.2 + f3 * 1.2
			scam.y = terrain.height_at(scam.x, scam.z) + 1.4
			SPOTS[spot] = [scam, mid + Vector3.UP * 1.0]
	var dodge_u := -1.0
	if spot == "ring":
		# the Ashen Knight's stone ring from just outside its entrance, the knight at its post
		# in the middle, the hero walking in through the gap
		var ring: StoneRing = world.stone_ring
		var f3 := Vector3(ring.facing.x, 0, ring.facing.y)
		world.knight.intro_enabled = false   # the arena itself, not the reveal
		var gate := ring.centre + f3 * (StoneRing.RADIUS + 1.5)
		player.global_position = Vector3(gate.x, terrain.height_at(gate.x, gate.z) + 0.05, gate.z)
		player.body.rotation.y = atan2(-f3.x, -f3.z)
		var rcam := ring.centre + f3 * (StoneRing.RADIUS + 6.5) + f3.cross(Vector3.UP) * 2.0
		rcam.y = terrain.height_at(rcam.x, rcam.z) + 3.4
		SPOTS[spot] = [rcam, ring.centre + Vector3.UP * 1.4]
	var kick_t := -1.0
	var kick_face := Vector3.ZERO
	if spot == "wallkick":
		# wallkick [kt=0.15] [aside]: the hero caught on the keep's outer face, then a jump with the
		# stick pulled back (aside: pushed right) kicks off it; frozen kt s after the press, seen
		# side-on along the face from the sunlit side
		kick_t = 0.15
		for a in args:
			if a.begins_with("kt="):
				kick_t = float(a.substr(3))
		var kr: Ruins = world.get_node("Ruins")
		var ks := kr.site
		var breach := atan2(-ks.z, -ks.x)
		var pick := INF
		var best := -1.0
		for k in 180:
			var a := TAU * k / 180.0
			if absf(wrapf(a - breach, -PI, PI)) < 1.2:
				continue
			var g := terrain.height_at(ks.x + cos(a) * 5.2, ks.z + sin(a) * 5.2)
			var h := kr.wall_top(a, 4.3) - g
			var score := absf(h - 3.6) + absf(kr.wall_top(a - 0.06, 4.3) - g - h) + absf(kr.wall_top(a + 0.06, 4.3) - g - h)
			if h > 2.8 and h < 4.6 and score < pick:
				pick = score
				best = a
		kick_face = Vector3(cos(best), 0, sin(best))
		var at := ks + kick_face * 5.1           # against the face, past the scree at its foot
		player.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.3, at.z)
		player.set_look(atan2(kick_face.x, kick_face.z), -0.2)
		var kl: Vector3 = -world.sun.global_transform.basis.z
		var tang := kick_face.cross(Vector3.UP)
		if tang.dot(Vector3(-kl.x, 0, -kl.z)) < 0.0:
			tang = -tang
		var kc := ks + kick_face * 7.2 + tang * 4.6
		var kf := ks + kick_face * 6.6
		if "near" in args:
			# near: truly side-on, level with the hero, so the legs and soles read at 720p
			kc = ks + kick_face * 6.0 + tang * 3.0
			kf = ks + kick_face * 5.9
		kc.y = terrain.height_at(kc.x, kc.z) + 1.5
		SPOTS[spot] = [kc, Vector3(kf.x, terrain.height_at(kf.x, kf.z) + 1.3, kf.z)]
	var jump_t := -1.0
	if spot == "jump":
		# jump [jt=0.3] [sprint] [drop] [land=0.06]: a running jump to world +X frozen jt s after
		# the press (or, with land=, that far into the landing; drop: a 4 m fall, hard landing)
		jump_t = 0.3
		for a in args:
			if a.begins_with("jt="):
				jump_t = float(a.substr(3))
		var pp := player.global_position
		if "clear" in args:
			# clear: off the practice post, onto open turf, with a raised 3/4 lens that sees the
			# crack star and the dust ring round a plunge's landing
			pp += Vector3(-7.0, 0, 0)
			pp.y = terrain.height_at(pp.x, pp.z) + 0.05
			player.global_position = pp
		var light: Vector3 = -world.sun.global_transform.basis.z
		var side := Vector3(0, 0, 1) if -light.z > 0.0 else Vector3(0, 0, -1)
		var mid := pp + Vector3(1.8 if not "drop" in args else 0.0, 0, 0)
		SPOTS[spot] = [mid + side * 4.2 + Vector3(0.4, 0, 0), mid]
		if "clear" in args:
			var jcam := mid + side * 5.2 + Vector3(2.2, 0, 0)
			jcam.y = terrain.height_at(jcam.x, jcam.z) + 2.6
			SPOTS[spot] = [jcam, mid + Vector3.UP * 0.5]
		if "close" in args:
			# close: a near side-on lens on the take-off spot itself (the hero is carried back
			# there once frozen), for the push-off and landing poses; flip takes the other side
			var cs := -side if "flip" in args else side
			SPOTS[spot] = [pp + cs * 3.3 + Vector3(0.5, 0, 0), pp + Vector3(0.2, 0, 0)]
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
		elif "recover" in args:
			foe_state = HollowSoldier.RECOVER
		if "snapped" in args and not "lodged" in args:
			args.append("lodged")
		if "flinch" in args or "fallen" in args or "knocked" in args or "lodged" in args:
			# clear of the practice post, which stands at the start
			var at := player.global_position + Vector3(3.0, 0, -6.0)
			player.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.05, at.z)
		if "knoll" in args:
			# the archer on its post: the hero 9 m down the slope from it, looking up the rise
			var post: Vector3 = world.archer._home
			var nrm := terrain.normal_at(post.x, post.z, 3.0)
			var down := Vector3(nrm.x, 0, nrm.z)
			down = down.normalized() if down.length() > 0.01 else Vector3(0, 0, -1)
			var at := post + down * 9.0
			player.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.05, at.z)
		var pp := player.global_position
		# "knight" in the args: the Ashen Knight stands in for the soldier (the soldier is moved off)
		# "warden": the shield warden stands in the same way
		var foe: HollowSoldier = world.knight if "knight" in args else (world.warden if "warden" in args else (world.hewer if "hewer" in args else (world.archer if "archer" in args else (world.harrier if "harrier" in args else world.soldier))))
		if "knight" in args or "warden" in args or "hewer" in args or "archer" in args or "harrier" in args:
			world.soldier.global_position += Vector3(0, 0, 60)
		var fp := pp + (Vector3(-3.4, 0, 0.6) if spot != "lockon" else Vector3(-1.2, 0, 4.6))
		if "archer" in args:
			fp = pp + Vector3(-5.5, 0, 1.0)      # an archer draws from a stand-off, not at spear length
		if "knoll" in args:
			fp = world.archer._home
		if "knight" in args and "leap" in args:
			fp = pp + Vector3(-7.6, 0, 1.2)      # the ember leap springs from out of glaive reach
		# g1 / g2 / g3: the knight at its phase-1/2/3 size (BossGrowth), standing off from the hero
		var giant := 0
		for gi in [1, 2, 3]:
			if "knight" in args and ("g%d" % gi) in args:
				giant = gi
		if giant > 0:
			var gk: AshenKnight = world.knight
			gk._set_phase(giant)
			gk.set_size_scale(gk.growth.scale_of(giant))
			fp = pp + Vector3(-1.0, 0, 0.18) * (1.6 + 1.25 * gk.size_scale)
		foe.global_position = Vector3(fp.x, terrain.height_at(fp.x, fp.z) + 0.05, fp.z)
		foe._home = foe.global_position
		foe.face(pp)
		player.body.rotation.y = atan2(fp.x - pp.x, fp.z - pp.z)
		if "kindler" in args:
			# the Kindler hangs back 6 m behind the warden's off shoulder, facing it to chant
			var kl_line := Vector3(fp.x - pp.x, 0, fp.z - pp.z).normalized()
			var kl_side := kl_line.cross(Vector3.UP)
			var kp := fp + kl_line * 5.4 + kl_side * 2.6
			if "kfront" in args:
				# (08:15 11-03: the body does face the warden (dot 1.00), but from that stand the
				# sun sat behind it at 13:00-14:30, so its front was shade and its lit back read
				# as the face. For the close-up it stands on the far side of the warden from the
				# sun, a little off the sun line, so it chants into the light.)
				var ks: Vector3 = -world.sun.global_transform.basis.z
				var ks_g := Vector3(-ks.x, 0, -ks.z).normalized()      # ground toward the sun
				var ks_side := ks_g.cross(Vector3.UP)
				if ks_side.dot(pp - fp) > 0.0:
					ks_side = -ks_side                                  # step away from the hero
				kp = fp - ks_g * 5.4 + ks_side * 2.2
			world.kindler.set_physics_process(false)
			world.kindler.global_position = Vector3(kp.x, terrain.height_at(kp.x, kp.z) + 0.05, kp.z)
			world.kindler._home = world.kindler.global_position
			world.kindler.face(fp)
		if "harrier" in args:
			# the harrier crouched at the hero's back: the hero faces away from it
			player.body.rotation.y += PI
		var light: Vector3 = -world.sun.global_transform.basis.z
		var line := Vector3(fp.x - pp.x, 0, fp.z - pp.z).normalized()
		var side := line.cross(Vector3.UP)
		if side.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
			side = -side
		var mid := pp.lerp(fp, 0.5)
		if spot == "soldier":
			var back := 4.8 if "flinch" in args or "fallen" in args else 3.6
			SPOTS[spot] = [mid + side * back - line * 0.4, mid]
			if "flinch" in args and "close" in args:
				# (animation review) close on the hero, side-on to the blow's line
				SPOTS[spot] = [pp + side * 2.7 - line * 0.5, pp - line * 0.25]
			if "fallen" in args:
				# frame the body where it falls (forward along its facing, toward the soldier)
				SPOTS[spot] = [pp + side * 3.0 + line * 0.2, pp + line * 0.8]
			if "knight" in args and "p3" in args:
				# the eruption under the hero: low and close from the side, so the scorch, the
				# column and the knight beyond all read in one frame
				var focus := pp.lerp(fp, 0.25)
				SPOTS[spot] = [focus + side * 4.2 - line * 1.4, focus]
			if "knight" in args and "leap" in args:
				# the knight high in its arc between them: square on to the leap, back far enough
				# to hold the whole arc and the hero under it
				# (closer and a little low, looking up into the tuck and the heaved glaive)
				SPOTS[spot] = [mid + side * 4.6 - line * 0.4 + Vector3.UP * 0.05, mid + Vector3.UP * 1.6]
			if giant > 0:
				# the giant whole, the hero small at its feet: wide from the lit side, low,
				# looking up a little, pulled back as it grows
				var gs: float = world.knight.size_scale
				SPOTS[spot] = [mid + side * (3.0 + 2.6 * gs) - line * (0.6 + 0.4 * gs) + Vector3.UP * 0.9, mid + Vector3.UP * (1.0 * gs)]
			if "lodged" in args:
				# the arrow standing in the hero: close on the hero's flank, the archer beyond
				SPOTS[spot] = [pp + side * 2.4 + line * 0.5 + Vector3.UP * 0.25, pp.lerp(fp, 0.18) + Vector3.UP * 1.05]
			if "knoll" in args:
				# low behind the hero's shoulder, looking up the rise at the archer on its post
				SPOTS[spot] = [pp - line * 2.0 + side * 3.4 + Vector3.UP * 0.9, pp.lerp(fp, 0.7) + Vector3.UP * 1.1]
			if "harrier" in args and "close" in args:
				# the harrier's crouch at the hero's back: close on its lit flank, front three-quarter,
				# low, so the coif, the bare shoulders and the low spear read against the hero
				SPOTS[spot] = [fp + side * 2.7 - line * 0.9 + Vector3.UP * 0.3, fp.lerp(pp, 0.2) + Vector3.UP * 0.95]
			if "harrier" in args and "coif" in args:
				# tight on the harrier's head from its flank, a little behind: the wound coif's
				# uneven turns, the loose end at the temple and the knotted tails down the nape
				# (08:15 11-03: from behind the shoulder hid the loose end and the tails, and the
				# head read as a pot. Now from its left front quarter, a touch wider, at eye level,
				# so the temple tuck, the uneven laps and one tail past the neck share the frame)
				SPOTS[spot] = [fp + side * 1.25 - line * 0.55 + Vector3.UP * 1.6, fp + side * 0.05 + Vector3.UP * 1.5]
			if "kindler" in args:
				# over the hero's shoulder at the kindled warden, the Kindler mid-chant beyond it
				# with its ember stream pouring in; a little off-axis so the stream reads across
				# (09:00 11-03: over the shoulder put the hero in silhouette over half the frame and
				# the Kindler tiny by the cottage; now square on to the warden->Kindler line from
				# the sun side, the hero at the left edge, both Hollows and the stream across)
				var kq: Vector3 = world.kindler.global_position
				var kline := Vector3(kq.x - fp.x, 0, kq.z - fp.z).normalized()
				var kside := kline.cross(Vector3.UP)
				if kside.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
					kside = -kside
				var kmid := fp.lerp(kq, 0.5)
				SPOTS[spot] = [kmid + kside * 4.6 - kline * 1.0, kmid - kline * 0.3]
				if "kfront" in args:
					# from the Kindler's front quarter on the sun side: its face and raised spear
					# toward the lens, the sagging thread running off past the camera's shoulder
					# to the burning warden at the frame edge
					# (04:45 11-03: 2.2 toward the warden + 3.4 aside was square on to its profile and
					# read as its back; now 3.8 toward the warden + 1.9 aside, ~27 deg off its face)
					# (05:45 11-03: that put the Kindler backlit, face in shade, warden out of frame.
					# Now the lens swings round toward the sun inside the Kindler's front half --
					# sun over the camera's shoulder when the hour allows, square side-on with the
					# sun at 90 deg when the sun is behind it -- and backs off to 5.6 m looking a
					# third of the way to the warden, so the burning warden takes the frame edge)
					# (08:15 11-03: kfwd was the Kindler -> warden line, but the 07:15 frame still read
					# from behind at lens.fwd 0.71, so the body does not square to that line at the
					# shot moment. Use the Kindler body's own facing (+Z, as spear_tip()/face() do),
					# flattened; fall back to the warden line if the basis is degenerate.)
					var kbz: Vector3 = world.kindler.body.global_basis.z
					var kfwd := Vector3(kbz.x, 0, kbz.z)
					if kfwd.length() < 0.1:
						kfwd = -kline
					kfwd = kfwd.normalized()
					print("SHOT kfront body.fwd vs warden line %.2f" % kfwd.dot(-kline))
					kside = kfwd.cross(Vector3.UP)
					if kside.dot(Vector3(-light.x, 0, -light.z)) < 0.0:
						kside = -kside
					var ksun := Vector3(-light.x, 0, -light.z).normalized() # ground toward the sun
					var kdir: Vector3
					if ksun.dot(kfwd) > 0.0:
						kdir = (kfwd * 0.75 + ksun * 0.9).normalized()
						if kdir.dot(kfwd) < 0.45:
							kdir = (kfwd * 0.45 + kside * 0.89).normalized()
					else:
						# (07:15 11-03: 0.3 toward its front left the hood hiding the face; 0.6 shows
						# the face under the hood at the cost of some shade on it)
						kdir = (kfwd * 0.6 + kside * 0.8).normalized()
					# keep the lens clear of the lantern post on the green: its lamp hung into the
					# top-left corner of the 06:20 frames. Swing round the Kindler in 8 deg steps
					# (staying inside its front half) until the camera is >= 3.5 m off the post.
					var kpost := Vector3(LanternPost.SITE.x, 0, LanternPost.SITE.y)
					var kbase := kdir
					for kstep in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
						var ktry: Vector3 = kbase.rotated(Vector3.UP, deg_to_rad(8.0 * kstep))
						if ktry.dot(kfwd) < 0.35:
							continue
						var kcam: Vector3 = kq + ktry * 7.4
						kdir = ktry
						if Vector2(kcam.x - kpost.x, kcam.z - kpost.z).length() >= 3.5:
							break
					var kcam_at: Vector3 = kq + kdir * 7.4    # (09:25 11-03: 5.6 left the warden off the right edge)
					print("SHOT kfront sun.fwd %.2f sun.side %.2f lens.fwd %.2f lens.sun %.2f post %.1f m" % [ksun.dot(kfwd), ksun.dot(kside), kdir.dot(kfwd), kdir.dot(ksun), Vector2(kcam_at.x - kpost.x, kcam_at.z - kpost.z).length()])
					# (09:10 11-03: the 08:10 frame had the hero standing between the lens and the
					# warden, filling the right third with the warden off the edge. Put the hero
					# behind the camera, 2.4 m back along the view line and a little to the warden's
					# side, re-face the warden at it, and look 45% of the way to the warden so the
					# burning warden takes the right of the frame instead of the hero.)
					var klook: Vector3 = kq.lerp(fp, 0.5)
					var kview := Vector3(klook.x - kcam_at.x, 0, klook.z - kcam_at.z).normalized()
					var kright := kview.cross(Vector3.UP)
					if kright.dot(fp - kq) < 0.0:
						kright = -kright
					var khero: Vector3 = kcam_at - kview * 2.4 + kright * 0.8
					player.global_position = Vector3(khero.x, terrain.height_at(khero.x, khero.z) + 0.05, khero.z)
					player.body.rotation.y = atan2(fp.x - khero.x, fp.z - khero.z)
					foe.face(player.global_position)
					var kpp := player.global_position - kcam_at
					print("SHOT kfront hero %.1f m behind the lens (dot %.2f)" % [kpp.length(), Vector3(kpp.x, 0, kpp.z).normalized().dot(kview)])
					SPOTS[spot] = [kcam_at, klook + Vector3.UP * 1.6]
			if "flight" in args:
				# the arrow in the air between them: square on to the flight line, a little back
				SPOTS[spot] = [mid + side * 4.2 + Vector3.UP * 0.1, mid + Vector3.UP * 1.3]
			if "bite" in args:
				# the bit buries ~1 m in front of the hewer: frame that patch of turf from the
				# hewer's lit flank, low, with the hewer filling the left of the frame
				var bite_at := fp - line * HollowHewer.BITE_Z    # `line` runs hero -> foe: the bit lands toward the hero
				var look := fp.lerp(bite_at, 0.55) + Vector3.UP * 0.55    # the bent back and the bit together
				SPOTS[spot] = [bite_at + side * 3.0 - line * 0.6 + Vector3.UP * 0.4, look]
		elif spot == "lockon":
			pass                                  # the follow camera, swung by the lock
		elif "lit" in args:
			# soldierface lit: swing the camera round toward the light-travel side (lit side at
			# midday; at a low evening sun the frame can still come out backlit)
			# (`light` is the travel direction: the sun itself lies along -light, so the
			# camera stands there; the old +light put the sun behind the knight)
			var sunward := Vector3(-light.x, 0, -light.z).normalized()
			var d := (sunward * 2.0 - line).normalized()
			SPOTS[spot] = [fp + d * 2.3, fp]
			# turn the foe 3/4 to the lens (it faced the hero, showing the camera its back)
			var lens := fp + d * 2.3
			foe.face(lens.lerp(pp, 0.35))
		else:
			SPOTS[spot] = [fp - line * 2.4 + side * 1.0, fp]
	if spot == "hounds":
		# hounds: the Briar Hound pair on their own ground -- one crouched at the end of its
		# tell (eyes flaring), its mate loping round the hero's other side; from the sun side
		var hs: Array = world.hounds
		var c: Vector3 = hs[0].global_position
		var hp := c + Vector3(-4.0, 0, -1.0)
		player.global_position = Vector3(hp.x, terrain.height_at(hp.x, hp.z) + 0.05, hp.z)
		var a: BriarHound = hs[0]
		var b: BriarHound = hs[1]
		var pa := hp + Vector3(3.6, 0, 0.9)
		var pb := hp + Vector3(-1.2, 0, 2.6)
		a.global_position = Vector3(pa.x, terrain.height_at(pa.x, pa.z), pa.z)
		b.global_position = Vector3(pb.x, terrain.height_at(pb.x, pb.z), pb.z)
		a.face(hp)
		b.face(pb + (pb - hp).cross(Vector3.UP))
		player.body.rotation.y = atan2(pa.x - hp.x, pa.z - hp.z)
		a.state = BriarHound.WINDUP
		a._speed = 0.0
		a._graze = 0.45
		a._eyes = 1.6
		a._mi.position = Vector3(0, -0.09, 0)
		a._mi.rotation.x = -0.12
		b.state = BriarHound.STALK
		b._speed = 3.4
		b._phase = 0.3
		b._graze = 0.35
		b._eyes = 0.3
		for h: BriarHound in hs:
			h._yaw = h.rotation.y
			h._pose(0.0)
			h.press_grass()           # the bed under the crouched one; the runner's lane below
			h.process_mode = Node.PROCESS_MODE_DISABLED
		var tr: Trample = world.get_node_or_null("Trample")
		if tr:
			var back := (pb - (pb - hp).cross(Vector3.UP).normalized() * 3.0)
			var rd := pb - back
			tr.add_herd_point(Vector2(pb.x, pb.z), Vector2(rd.x, rd.z), 1.0, 2.0, 0.3, rd.length())
			tr.add_herd_point(Vector2(back.x, back.z), Vector2(rd.x, rd.z), 1.0, 5.0, 0.3, rd.length())
		# the hero squares up to the crouched one, staff drawn
		player.use_bot_input = true
		player.combat._begin_draw()
		for i in 30:
			player.combat.physics_step(1.0 / 60.0)
		# the warm-up runs longer than SHEATHE_AFTER (5 s) with no input: without this the
		# staff went back across the shoulders before the frame was taken (19:25 10-31)
		player.combat.idle_t = -1.0e6
		print("SHOT hounds staff drawn %s" % player.combat.is_drawn())
		var light: Vector3 = -world.sun.global_transform.basis.z
		var sunward := Vector3(-light.x, 0, -light.z).normalized()
		var mid := (hp + pa + pb) / 3.0
		var hcam := mid + sunward * 4.6 + Vector3(0, 1.0, 0)
		SPOTS[spot] = [hcam, mid + Vector3(0, 0.5, 0)]
	if spot == "wisps" and "fire" in args:
		# night: the knot drawn in off the meadow, wheeling in the smoke over Hesper's fire,
		# seen from the lid across the keep floor (the `hearth` lens, aimed higher)
		var kp: Keeper = world.keeper
		kp.settle(world, world.time_of_day)
		var hp: Vector3 = world.hearth.global_position
		var ws: Array = world.wisps
		var away := hp + Vector3(90.0, 0, 90.0)
		player.global_position = Vector3(away.x, terrain.height_at(away.x, away.z) + 0.05, away.z)
		for i in ws.size():
			var w: HollowWisp = ws[i]
			var a := TAU * i / ws.size() + w._ang
			w.global_position = hp + Vector3(sin(a) * HollowWisp.FIRE_RING, HollowWisp.FIRE_HOVER, cos(a) * HollowWisp.FIRE_RING)
			w.drawn_to = world.hearth
			w.at_fire = true
			w._heat = HollowWisp.FIRE_HEAT
			w._hover = HollowWisp.FIRE_HOVER
			w._ghost(true)
			for ch in w.get_children():
				if ch is CPUParticles3D:
					ch.preprocess = 1.5
		var kn: Vector3 = kp._spots["kindle"][0]
		var mid := (hp + kn) * 0.5
		var outw := Vector3(mid.x - kp.site.x, 0, mid.z - kp.site.z).normalized()
		# across the floor from the fire, back against the wall foot, low, looking up into
		# the smoke so the fire, the keep's inner face and the wheeling knot share the frame
		var back := Vector3(kp.site.x + outw.x * 0.55 - hp.x, 0, kp.site.z + outw.z * 0.55 - hp.z).normalized()
		var cp := hp + back * 3.1
		cp.y = hp.y + 1.25
		SPOTS[spot] = [cp, Vector3(hp.x, hp.y + 1.45, hp.z)]
		if "cower" in args:
			# Hesper backed to the wall from them, arm up before her face: seen from over the
			# lid on the far side of the keep centre, so she and the knot over the fire share it
			var cs: Vector3 = kp._spots["cower"][0]
			kp._place(cs)
			kp.path.clear()
			kp.activity = "cower"
			kp.state = Keeper.STAND
			kp.sit = 0.0
			kp.warm = 0.0
			kp.cower = 1.0
			kp._fear_t = Keeper.FEAR_HOLD
			var tf := Vector3(hp.x - cs.x, 0, hp.z - cs.z)
			kp.body.rotation.y = atan2(tf.x, tf.z)
			kp.goal_yaw = kp.body.rotation.y
			# in front of her, a little toward the fire and the keep centre, at her eye height,
			# so her face and the raised arm catch the firelight
			var tf2 := tf.normalized()
			var o2 := Vector3(kp.site.x - cs.x, 0, kp.site.z - cs.z).normalized()
			cp = cs + (tf2 * 0.75 + o2 * 0.65).normalized() * 2.1
			cp.y = cs.y + 1.05
			SPOTS[spot] = [cp, Vector3(cs.x, cs.y + 1.35, cs.z)]
		print("SHOT wisps fire %s wisps %s lens %s" % [hp, ws.map(func(w): return w.global_position), cp])
	elif spot == "wisps":
		# wisps: the knot round the hero -- the near one at the peak of its flare (shards
		# snapped in, the heart white-hot), its kin drifting loose behind; from the sun side
		var ws: Array = world.wisps
		var c: Vector3 = ws[0]._home
		var hp := c + Vector3(-3.0, 0, -2.0)
		player.global_position = Vector3(hp.x, terrain.height_at(hp.x, hp.z) + 0.05, hp.z)
		var spots := [hp + Vector3(1.0, 0, 2.6), hp + Vector3(-1.4, 0, 3.6), hp + Vector3(1.9, 0, 4.6)]
		for i in ws.size():
			var w: HollowWisp = ws[i]
			var q: Vector3 = spots[i]
			w.global_position = Vector3(q.x, terrain.height_at(q.x, q.z) + (1.45 if i == 0 else 1.3 + 0.15 * i), q.z)
			w._heat = 4.2 if i == 0 else 0.8
			if "rain" in args:
				# a doused knot: guttering coals, steam boiling off, sparks drowned
				w.douse = 1.0
				w._heat *= 1.0 - HollowWisp.DOUSE_HEAT
				w.global_position.y -= HollowWisp.DOUSE_SINK
			w._gather = 1.0 if i == 0 else 0.0
			w.state = HollowWisp.WINDUP if i == 0 else HollowWisp.STALK
			w._visuals(0.0)
			w.process_mode = Node.PROCESS_MODE_DISABLED
			for ch in w.get_children():
				if ch is CPUParticles3D:
					ch.process_mode = Node.PROCESS_MODE_ALWAYS
					ch.preprocess = 1.5
		var pa: Vector3 = spots[0]
		player.body.rotation.y = atan2(pa.x - hp.x, pa.z - hp.z)
		player.use_bot_input = true
		player.combat._begin_draw()
		for i in 30:
			player.combat.physics_step(1.0 / 60.0)
		player.combat.idle_t = -1.0e6
		# over the hero's right shoulder, looking into the knot
		var fwd := Vector3(0, 0, 1)
		var mid := hp + Vector3(0.4, 0, 3.4)
		if "rain" in args:
			world.weather.force(1.0)
		if "close" in args:
			# tight over the shoulder, ~1 m behind it so the hero is in frame: the flaring one
			# ~3.3 m off the lens, its kin beyond
			mid = hp + Vector3(0.6, 0, 3.2)
			SPOTS[spot] = [hp + Vector3(-1.0, 0, -1.7), mid]
		else:
			SPOTS[spot] = [hp - fwd * 2.3 + Vector3(-0.9, 0, 0), mid]
		print("SHOT wisps hero %s wisps %s lens %s" % [player.global_position, ws.map(func(w): return w.global_position), SPOTS[spot][0]])
	if spot == "ferns":
		# the densest fern drift (most ferns within 5 m), framed with its oak behind it
		var flora: Flora = world.get_node("Flora")
		var fl := flora.fern_positions
		var bestf := fl[0]
		var bestn := -1
		for i in range(0, fl.size(), 3):
			var n := 0
			for q in fl:
				if (q - fl[i]).length_squared() < 25.0:
					n += 1
			if n > bestn:
				bestn = n
				bestf = fl[i]
		var tr := flora.tree_positions[0]
		for q in flora.tree_positions:
			if Vector2(q.x - bestf.x, q.z - bestf.z).length() < Vector2(tr.x - bestf.x, tr.z - bestf.z).length():
				tr = q
		var away := Vector3(bestf.x - tr.x, 0, bestf.z - tr.z).normalized()
		SPOTS[spot] = [bestf + away * 7.5 + away.cross(Vector3.UP) * 1.5, bestf - away * 3.0]
		print("SHOT ferns: drift of %d at %s, %d ferns, %d shrubs" % [bestn, bestf, fl.size(), flora.shrub_positions.size()])
	if spot == "trample":
		# a trodden track through the meadow: 18 m of trail curving in to where the hero
		# stands, oldest end nearly sprung back; seen from beside the start, looking along it
		var pp := player.global_position
		var fwd := Vector3(0.8, 0, 0.6)
		var side := fwd.cross(Vector3.UP)
		var path := PackedVector3Array()
		for k in 7:
			var u := k / 6.0
			path.append(pp - fwd * (18.0 * (1.0 - u)) + side * sin(u * PI) * 2.2)
		world.trample.seed_trail(path, 8.0, 0.2)
		player.body.rotation.y = atan2(fwd.x, fwd.z)
		SPOTS[spot] = [pp - fwd * 15.0 + side * 1.3, pp - fwd * 5.0 + side * 1.0]
		if "close" in args:   # down at the boot prints, a few metres along the track
			SPOTS[spot] = [pp - fwd * 9.0 + side * 1.6, pp - fwd * 5.5 + side * 1.3]
	if spot == "herd":
		# the red deer grazing on the open meadow, seen low from ~20 m with the sun behind the
		# camera; "alert" lets them notice the hero (heads up), otherwise they keep grazing
		var herd: Herd = world.herd
		if not "alert" in args:
			herd.alert_radius = 0.0
			herd.flee_radius = 0.0
		if "bed" in args:   # the herd lying in its beds in the grass
			herd.force_bed = true
			for d: Herd.Deer in herd._deer:
				d.bed = 1.0
		var hc := herd.centre()
		var sdh: Vector3 = world.sun.global_transform.basis.z
		sdh = Vector3(sdh.x, 0, sdh.z).normalized().rotated(Vector3.UP, 0.5)
		# "near": ~10 m from the closest deer, to judge the coat and shape
		var dist := 19.0
		if "near" in args:
			var best := hc
			for dp in herd.deer_positions():
				if (dp - (hc + sdh * 19.0)).length() < (best - (hc + sdh * 19.0)).length():
					best = dp
			hc = best
			dist = 10.0
		if "stag" in args:   # ~8 m from the stag, broadside, head up, aimed at his antlers
			for d: Herd.Deer in herd._deer:
				if d.stag:
					var fw := sdh.cross(Vector3.UP)
					d.yaw = atan2(-fw.x, -fw.z)
					d.head = 0.0
					d.head_target = 0.0
					d.head_yaw = 0.5   # glancing toward the camera
					d.look_t = 1e6
					d.step_t = 1e6
					d.goal = d.pos
					d.speed = 0.0
					hc = d.pos + Vector3.UP * 1.4
			dist = 8.0
		SPOTS[spot] = [hc + sdh * dist, hc]
		print("SHOT herd at %s, %d deer" % [hc, herd.deer_positions().size()])
	if spot == "deercross":
		# the herd walking over the cart track in single file, seen low from the verge ~13 m
		# up the track: the herd is run on (not rendered) until the lead is just over the ruts
		var herd: Herd = world.herd
		herd.alert_radius = 0.0
		herd.flee_radius = 0.0
		herd.cross_road()
		var far := [Vector3(1e6, 0, 1e6), 0.0]
		var side0 := Herd.road_side(Vector2(herd.cross_from.x, herd.cross_from.z))
		var lead_past := 3.0
		for a in args:
			if a.begins_with("past="):
				lead_past = float(a.substr(5))
		for i in 30 * 400:
			herd._tick(1.0 / 30.0, far)
			var an := Vector2(herd.anchor.x, herd.anchor.z)
			if Herd.road_side(an) != side0 and (Herd.road_nearest(an)[2] as float) > lead_past:
				break
		var at := herd.cross_at
		var rd: Vector2 = Herd.road_nearest(Vector2(at.x, at.z))[1]
		var back := rd.orthogonal() * side0   # toward the side they came from
		var cp := Vector2(at.x, at.z) - rd * 13.0 + back * 4.0
		var dc_cam := Vector3(cp.x, terrain.height_at(cp.x, cp.y) + 1.5, cp.y)
		SPOTS[spot] = [dc_cam, at + Vector3.UP * 0.8]
		print("SHOT deercross at %s, lead %s, %d on the track, cam %s" % [at.round(), herd.anchor.round(), herd.on_road(), dc_cam.round()])
	if spot == "hooves":
		# deer tracks pressed into the meadow beside the hero: a hind's walking trail
		# crossing a galloping one, seen low from ~3 m
		var herd: Herd = world.herd
		herd.alert_radius = 0.0
		herd.flee_radius = 0.0
		herd.place(player.global_position + Vector3(60, 0, 60))
		var pp := player.global_position
		var fwd := Vector3(0.8, 0, 0.6)
		var side := fwd.cross(Vector3.UP)
		var hc := pp + fwd * 4.0
		for k in 2:
			var dr := Herd.Deer.new()
			dr.scale = 1.0
			dr.speed = 0.9 if k == 0 else 9.0
			var dir := side if k == 0 else (fwd + side * 0.3).normalized()
			var start := hc - dir * 6.0 + (fwd * 0.6 if k == 0 else -fwd * 0.4)
			if k == 0:   # a deer path: the grass along the walking track lies trodden
				world.trample.seed_trail(PackedVector3Array([start, start + dir * 6.0, start + dir * 12.0]), 7.0, 3.0)
			for j in 160:
				dr.pos = start + dir * (j * 0.08)
				herd._hooves(dr, dir, 0.08)
		world.trample.frozen = true
		SPOTS[spot] = [hc - fwd * 2.4 + side * 0.9, hc + fwd * 0.6 + side * 0.3]
		print("SHOT hooves at %s, %d prints" % [hc, world.trample.active_hoofs()])
	if spot == "doorstones":
		# standing on a house's track a few metres out, looking down it over the stepping
		# stones to the door (default the white cottage; "stone": the stone cottage,
		# "timber": the timber house)
		var k := 1 if not ("stone" in args or "timber" in args) else (0 if "stone" in args else 2)
		var w: PackedVector2Array = DoorStones.runs()[k][0]
		var far: Array = DoorStones.along(w, 3.8)
		var q: Vector2 = far[0]
		var side: Vector2 = (far[1] as Vector2).orthogonal() * 0.45
		var cp := Vector3(q.x + side.x, 0.0, q.y + side.y)
		cp.y = terrain.height_at(cp.x, cp.z) + 1.8
		var at: Vector2 = DoorStones.along(w, 0.6)[0]
		SPOTS[spot] = [cp, Vector3(at.x, terrain.height_at(at.x, at.y) + 0.25, at.y)]
		print("SHOT doorstones %d slabs" % world.door_stones.stone_count)
	if spot == "cottage":
		# Harrowmere's first house from the green: three-quarter on the door side and the
		# chimney gable ("close": on the door and window; "back": the rear slope and chimney)
		var c: Cottage = world.cottage
		var f := Cottage.front()
		var al := f.cross(Vector3.UP)          # the house's -x (toward the chimney gable)
		var cp := c.global_position
		var d := 12.5
		var off := f * d + al * 5.5
		if "close" in args:
			off = f * 5.2 - al * 0.6
		elif "back" in args:
			off = -f * 10.0 + al * 7.5
		var pos := cp + off
		pos.y = terrain.height_at(pos.x, pos.z) + 1.65
		SPOTS[spot] = [pos, cp + Vector3.UP * (1.3 if "close" in args else 2.1) - al * (0.4 if "close" in args else 0.0)]
		print("SHOT cottage %d slates %d stones %d beams" % [c.slate_count, c.stone_count, c.beam_count])
	if spot == "lantern":
		# the lantern post from the green, three-quarter on the arm: the lantern a little
		# above eye height with the houses beyond ("wide": back 8 m, its light on the grass)
		var lp: LanternPost = world.lantern_post
		var at := lp.global_position
		var o := lp.global_basis.z
		var sd := lp.global_basis.x
		var lc := lp.lantern_center()
		var cp: Vector3
		var tgt: Vector3
		if "track" in args:
			# standing on the track out toward the start, looking back up it to where the
			# tracks meet at the post, the white cottage's and timber house's tracks beyond
			cp = Vector3(-3.6, 0.0, 1.2)
			cp.y = terrain.height_at(cp.x, cp.z) + 2.3
			tgt = Vector3(-10.0, terrain.height_at(-10.0, 4.5) + 0.2, 4.5)
		elif "wide" in args:
			cp = at + o * 7.0 + sd * 4.5
			cp.y = terrain.height_at(cp.x, cp.z) + 1.7
			tgt = at + o * 0.5 + Vector3.UP * 1.2
		elif "bat" in args:
			# under the lantern looking up past it: the bat crossing the light a metre out,
			# its full span, the candle glowing through its wings
			cp = lc + o * 2.0 + sd * 0.9
			cp.y = lc.y - 0.6
			tgt = lc + Vector3.UP * 0.25
			var b := lp.bat
			var to_cam := (cp - lc).normalized()
			b.global_position = lc + to_cam * 0.75 + Vector3.UP * 0.3 + to_cam.cross(Vector3.UP).normalized() * 0.18
			# flying away from the lens over the light: the whole span shows from behind-below
			var fly := Vector3(-to_cam.x, 0.12, -to_cam.z).normalized()
			b.basis = Basis.looking_at(fly, Vector3.UP).rotated(fly, -0.3)
			b.state = Bat.PATROL
			b.hold = true
		elif "roost" in args:
			# under the woodshed eaves by day: the bat hanging head down from the boards,
			# wings wrapped, seen from just outside the open end and below
			var b := lp.bat
			var f: Vector3 = b.roost_face
			var sdr := f.cross(Vector3.UP).normalized()
			cp = b.roost_at + f * 0.5 + sdr * 0.16 - Vector3.UP * 0.22
			tgt = b.roost_at - Vector3.UP * 0.05
			b._stretch_in = 1e6
		elif "moths" in args:
			# close under the lantern: the moths looping round the panes, the post face beside
			cp = lc + o * 0.95 + sd * 0.75
			cp.y = lc.y - 0.35
			tgt = lc - o * 0.25 - Vector3.UP * 0.1
		else:
			cp = lc + o * 1.9 + sd * 1.3
			cp.y = terrain.height_at(cp.x, cp.z) + 1.6
			tgt = lc - Vector3.UP * 0.25 - o * 0.3
		SPOTS[spot] = [cp, tgt]
		var pp := at + o * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT lantern at %s, lantern %s, lit %.2f" % [at, lc, lp.lit])
	if spot == "roadmeet":
		# Wat walking back to the meadow meets Hild coming up the cart track: both stopped
		# mid-word on the ruts, face to face, she on her right; the lens on the verge beside
		# them, the track running away past them toward the green
		var pd: Pedlar = world.pedlar
		var hd: Traveller = world.traveller
		pd.settle(world, world.time_of_day)
		hd.settle(world, world.time_of_day)
		pd.set_out(true)
		hd.set_out(false)
		var ra: Vector2 = YardGround.ROAD[1][0]
		var rb: Vector2 = YardGround.ROAD[2][0]
		var dir := (rb - ra).normalized()        # up the track toward the green
		var lft := Vector2(dir.y, -dir.x)
		var wp := ra.lerp(rb, 0.5)
		var hp := wp - dir * 1.2 - lft * 0.8      # she keeps to her right coming up, ~1.4 m off
		pd._place(Vector3(wp.x, terrain.height_at(wp.x, wp.y), wp.y))
		hd._place(Vector3(hp.x, terrain.height_at(hp.x, hp.y), hp.y))
		for v in [pd, hd]:
			v.state = Villager.STAND
			v.path.clear()
			v.greeting = 999.0
		pd.greet_to = hd
		hd.greet_to = pd
		pd.mate = hd
		hd.mate = pd
		var tw := hd.global_position - pd.global_position
		pd.goal_yaw = atan2(tw.x, tw.z)
		hd.goal_yaw = atan2(-tw.x, -tw.z)
		pd.body.rotation.y = pd.goal_yaw
		hd.body.rotation.y = hd.goal_yaw
		var mid := (pd.global_position + hd.global_position) * 0.5
		# the lens square-on to the line between them, on the far verge from Hild (her verge saw
		# them three-quarter from behind in 02:50),
		# so both faces read in profile ("near": the other verge)
		var tw2 := Vector2(tw.x, tw.z).normalized()
		var perp := Vector2(tw2.y, -tw2.x)
		if perp.dot(lft) < 0.0:
			perp = -perp
		var side := -1.0 if "near" in args else 1.0
		# the lens on the sun's side of their line (at 16.5 the far verge looked into the low
		# west sun and both faces were black against it): "near"/"far" still force a verge
		var sz: Vector3 = world.sun.global_basis.z
		if not ("near" in args or "far" in args) and Vector2(sz.x, sz.z).dot(perp) < 0.0:
			side = -1.0
		# swung a little toward the sun along their line, so the lit side of the faces turns to us
		var sw := clampf(Vector2(sz.x, sz.z).normalized().dot(tw2), -0.5, 0.5)
		var c := Vector2(mid.x, mid.z) + (perp * side + tw2 * sw).normalized() * 3.6
		var cp := Vector3(c.x, terrain.height_at(c.x, c.y) + 1.5, c.y)
		SPOTS[spot] = [cp, mid + Vector3.UP * 1.2]
		if "hild" in args:
			# a head-and-shoulders portrait of Hild at 1.2 m, halfway between her front and the
			# verge lens: her face, the wimple under her chin, the hood round it
			var fc: Vector3 = (hd.garb.face.global_transform * hd.garb.face.get_aabb()).get_center()
			var hf := Vector3(sin(hd.goal_yaw), 0, cos(hd.goal_yaw))
			var toc := cp - fc
			toc.y = 0.0
			var lf := (hf + toc.normalized()).normalized()
			SPOTS[spot] = [fc + lf * 1.2 + Vector3.UP * 0.03, fc - Vector3.UP * 0.12]
			if "chest" in args:
				# head and chest: the wimple's hem, the smock's collar and the mantle's open front
				SPOTS[spot] = [fc + lf * 1.3 - Vector3.UP * 0.1, fc - Vector3.UP * 0.26]
			elif "full" in args:
				# head to foot: the kirtle's front panel below the sash and the shin wraps under the hem
				# (from the verge side: on her front line at 2.8 m Wat and his creel stand in the way)
				var lv := (hf * 0.25 + toc.normalized()).normalized()
				SPOTS[spot] = [fc + lv * 2.8 - Vector3.UP * 0.6, fc - Vector3.UP * 0.82]
		var pp := mid + Vector3(dir.x, 0, dir.y) * 30.0
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
	if spot == "pedlar":
		# Wat on his stand on the green, the creel on his back: three-quarter from the front at
		# 3.6 m ("back": from behind his shoulder, the creel and the green beyond)
		var pd: Pedlar = world.pedlar
		pd.settle(world, world.time_of_day)
		pd.set_out(false)
		pd._place(pd._legs[3][0])
		pd._leg = 3
		pd._arrive()
		pd._stand_t = 999.0
		pd.body.rotation.y = pd.goal_yaw
		var at := pd.global_position
		var f := Vector3(sin(pd.goal_yaw), 0, cos(pd.goal_yaw))
		var lens := f.rotated(Vector3.UP, 2.5 if "back" in args else 0.6)
		var cp := at + lens * 3.6
		cp.y = terrain.height_at(cp.x, cp.z) + 1.5
		SPOTS[spot] = [cp, at + Vector3.UP * 1.15]
		if "road" in args:
			# out on the cart track in the meadow, walking in toward the village: the lens low
			# behind him on the verge, both ruts running away past him to the green
			var ra: Vector2 = YardGround.ROAD[1][0]
			var rb: Vector2 = YardGround.ROAD[2][0]
			var wp := ra.lerp(rb, 0.45)
			pd._place(Vector3(wp.x, terrain.height_at(wp.x, wp.y), wp.y))
			pd._stand_t = 999.0
			var dir := (rb - ra).normalized()
			pd.goal_yaw = atan2(dir.x, dir.y)
			pd.body.rotation.y = pd.goal_yaw
			var c2 := ra - dir * 3.0 + dir.orthogonal() * 1.1
			var cp2 := Vector3(c2.x, terrain.height_at(c2.x, c2.y) + 1.35, c2.y)
			var gr: Vector2 = YardGround.ROAD[4][0]
			SPOTS[spot] = [cp2, Vector3(gr.x, terrain.height_at(gr.x, gr.y) + 1.6, gr.y)]
			if "lamp" in args:
				# dusk: ahead of him along `dir` (wp - dir lands behind his creel) and to one side, low,
				# looking back at the lit horn lantern at his knee, its pool on the ruts; the
				# lens stands on the rut side of the verge so no stalk crosses the foreground
				var lft := Vector2(dir.y, -dir.x)
				var c3 := wp + dir * 3.4 + lft * 1.3
				var cp3 := Vector3(c3.x, terrain.height_at(c3.x, c3.y) + 1.2, c3.y)
				SPOTS[spot] = [cp3, pd.global_position + Vector3.UP * 0.75 + Vector3(lft.x, 0, lft.y) * 0.2]
				if "moths" in args and pd.hand_lantern != null:
					# close on the lantern at his knee: the lens 1.7 m off, level with the horn, so
					# the moths looping it stand against the dark verge rather than the lit ruts
					# the lantern rides a hand bone attachment that only follows the body once the
					# skeleton has posed: read the flame after a few frames, not where it hung on the green
					for i in 4:
						await get_tree().process_frame
					var lc := pd.hand_lantern.flame_center()
					var cm := Vector2(lc.x, lc.z) + dir * 1.3 + lft * 1.1
					print("SHOT moths: flame %s, %.2f m from the pedlar" % [lc, Vector2(lc.x - pd.global_position.x, lc.z - pd.global_position.z).length()])
					SPOTS[spot] = [Vector3(cm.x, lc.y + 0.25, cm.y), lc + Vector3.UP * 0.05]
		if pd.hand_lantern != null:
			pd.hand_lantern.lit = 1.0 if Pedlar.lantern_for(world.time_of_day) else 0.0
			pd.hand_lantern.visible = pd.hand_lantern.lit > 0.0
		if "woof" in args:
			# Brack stood off 5 m from him on the green, seeing him off: the lens low behind
			# the dog's shoulder, the dog large in the foreground and Wat beyond it
			var dg: Dog = world.dog
			var away := (dg.home - at)
			away.y = 0.0
			away = away.normalized()
			var dp := at + away * 5.0
			dp = Vector3(dp.x, terrain.height_at(dp.x, dp.z), dp.z)
			dg.global_position = dp
			dg.yaw = atan2(away.x, away.z)
			dg._warned = pd.journeys
			dg._warn_from = dp
			dg._start(Dog.WARN, 0.0)
			var sd := away.cross(Vector3.UP)
			var cpw := dp + away * 2.2 + sd * 1.1
			cpw.y = terrain.height_at(cpw.x, cpw.z) + 0.75
			SPOTS[spot] = [cpw, at + Vector3.UP * 0.8]
		if "sidestep" in args:
			# Wat walking off the green with Brack sat on his line a stride ahead: he bends his
			# course round the dog; the lens low off to the side the dog is on, both in frame
			var dg: Dog = world.dog
			var nx: Vector3 = pd._legs[4][0]
			var dir := Vector3(nx.x - at.x, 0, nx.z - at.z).normalized()
			var dp := at + dir * 2.6
			dp = Vector3(dp.x, terrain.height_at(dp.x, dp.z), dp.z)
			dg.global_position = dp
			dg.yaw = atan2(-dir.x, -dir.z)
			dg._warned = pd.journeys
			dg._start(Dog.REST, 999.0)
			dg.sit = 1.0
			pd._go_leg(4)
			var sd := dir.cross(Vector3.UP)
			var cps := dp + sd * 3.4 + dir * 1.2
			cps.y = terrain.height_at(cps.x, cps.z) + 1.1
			SPOTS[spot] = [cps, dp + Vector3.UP * 0.7 - dir * 0.6]
	if spot == "osric":
		# Osric at his spot for the hour, three-quarter from the front at 3.4 m; leaning on the
		# garth's back wall the lens stands out in the field beyond it, looking back at him
		# over the cope with the hen house and the cottage's back behind
		var nb: Neighbour = world.neighbour
		nb.settle(world, world.time_of_day)
		var at := nb.global_position
		var f := Vector3(sin(nb.goal_yaw), 0, cos(nb.goal_yaw))
		var lens := f.rotated(Vector3.UP, 0.55 if nb.activity == "lean" else 0.7)
		var cp := at + lens * (3.6 if nb.activity == "lean" else 3.4)
		cp.y = terrain.height_at(cp.x, cp.z) + 1.5
		SPOTS[spot] = [cp, at + Vector3.UP * 1.3]
		if "close" in args:
			# the whole figure at 2.3 m, to judge how the cape hangs over the arms
			var cc := at + lens * 2.3
			cc.y = terrain.height_at(cc.x, cc.z) + 1.45
			SPOTS[spot] = [cc, at + Vector3.UP * 1.25]
		if "shade" in args:
			# on the fell, a few seconds into a hand raised to the brim (the warm-up adds ~3 s)
			nb._gt = 1.5
		if "stile" in args:
			# squeezing through the stile in the back wall on his way out onto the fell, from
			# the fell footpath outside, a little off square, the garth and the cottage beyond
			var sl: Vector3 = nb._spots["stile2"][0]
			var sf: Vector3 = nb._spots["fell"][0]
			nb.global_position = Vector3(sl.x, terrain.height_at(sl.x, sl.z) + 0.03, sl.z)
			nb.goal_yaw = atan2(sf.x - sl.x, sf.z - sl.z)
			nb.body.rotation.y = nb.goal_yaw
			var sc := nb.cottage.to_global(Vector3(0.6, 0, -14.6))
			sc.y = terrain.height_at(sc.x, sc.z) + 1.6
			SPOTS[spot] = [sc, sl + Vector3.UP * 1.1]
		if "slide" in args:
			# dusk, the hens all in: Osric beside the hen house ladder, bent to the pop-hole with
			# his hand on the slide just dropped over it; from the yard, three-quarter on the house
			var hn: Hens = world.hens
			hn._settle_now()
			var sp: Array = nb._spots["slide"]
			var s0: Vector3 = sp[0]
			nb.global_position = Vector3(s0.x, terrain.height_at(s0.x, s0.z) + 0.03, s0.z)
			nb.goal_yaw = sp[1]
			nb.body.rotation.y = nb.goal_yaw
			nb.state = Villager.STAND
			nb.path.clear()
			nb.hold_latch = true
			nb.latch = 1.0
			hn.house.set_shut(true)
			var sc := nb.cottage.to_global(Vector3(-0.6, 0, -6.1))
			sc.y = terrain.height_at(sc.x, sc.z) + 1.45
			var tg := nb.cottage.to_global(Vector3(-3.0, 0, -8.15))
			tg.y = hn.house.base_y + 0.75
			SPOTS[spot] = [sc, tg]
		if "lookout" in args:
			# woken in the night: Osric in the squeeze gap of the east yard wall, the horn lantern
			# held up before him, peering down the gable toward the garth; from down the gable,
			# three-quarter on his lit face, the candle in the cottage window behind
			var lp: Array = nb._spots["lookout"]
			var l0: Vector3 = lp[0]
			nb.global_position = Vector3(l0.x, terrain.height_at(l0.x, l0.z) + 0.03, l0.z)
			nb._show(true)
			nb.activity = "lookout"
			nb._looking = true
			nb._look_t = 6.0
			nb.state = Villager.STAND
			nb.path.clear()
			nb.goal_yaw = lp[1]
			nb.body.rotation.y = nb.goal_yaw
			nb.hold_lift = true
			nb.lift = 1.0
			nb.hand_lantern.lit = 1.0
			nb.cottage._rouse_t = 600.0
			if "lightdebug" in args:
				# which light paints what: the hand lantern green, the cottage window lamp blue
				nb.hand_lantern.lamp.light_color = Color(0, 1, 0)
				nb.cottage.lamp.light_color = Color(0, 0.3, 1)
			var dgl = world.get("dog")
			if dgl != null:
				dgl.place_attend()      # Brack sat at his knee
			var lf := Vector3(sin(nb.goal_yaw), 0, cos(nb.goal_yaw)).rotated(Vector3.UP, -0.5)
			var lc := l0 + lf * 3.2
			lc.y = terrain.height_at(lc.x, lc.z) + 1.55
			SPOTS[spot] = [lc, l0 + Vector3.UP * 1.35]
		if "face" in args:
			# a head-and-shoulders portrait at 1.1 m: the nose, the beard, the eyes under the brim
			var fb := nb.garb.face.global_transform * nb.garb.face.get_aabb()
			var fc := fb.get_center()
			var lf := f.rotated(Vector3.UP, 0.45)
			SPOTS[spot] = [fc + lf * 1.1 + Vector3.UP * 0.02, fc - Vector3.UP * 0.12]
		if "pair" in args:
			# Edda at her feed round over the garth wall, the two of them passing a word: the
			# lens off to the side of the line between them, framing both
			var ed: Villager = world.villager
			ed.settle(world, world.time_of_day)
			var mid := (ed.global_position + at) * 0.5
			var ln := at - ed.global_position
			ln.y = 0.0
			var side := Vector3(-ln.z, 0, ln.x).normalized()
			if side.dot(mid - nb.cottage.global_position) < 0.0:
				side = -side
			var pc := mid + side * 7.5
			pc.y = terrain.height_at(pc.x, pc.z) + 1.6
			SPOTS[spot] = [pc, mid + Vector3.UP * 1.1]
		if "flock" in args:
			# the hens already drifted over to peck round his boots (Hens._next does it over a
			# minute; the shot's warm-up is two seconds)
			var hn: Hens = world.hens
			var kl := nb.cottage.to_local(at)
			var kf3 := nb.cottage.to_local(at + f) - kl
			var kf := Vector2(kf3.x, kf3.z).normalized()
			for k in hn.hens.size():
				var hh: Dictionary = hn.hens[k]
				hh.pos = Hens.clamp_yard(Vector2(kl.x, kl.z) + kf.rotated(-1.3 + 0.65 * k) * (0.8 + 0.25 * (k % 3)))
				hh.state = Hens.STAND
				hh.t = 0.3 * k
				hh.yaw = _rng_yaw(k)
		var pp := at + Vector3(40, 0, 40)
		player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		print("SHOT osric %s at %s lean %.2f" % [nb.activity, at, nb.lean])
	if spot == "villager":
		# Edda at her spot for the hour, three-quarter from the front at 3.4 m, eye height
		# ("wide": back 7 m with the house behind her)
		var vg: Villager = world.villager
		vg.settle(world, world.time_of_day)
		var at := vg.global_position
		var f := Vector3(sin(vg.goal_yaw), 0, cos(vg.goal_yaw))
		var dist := 7.0 if "wide" in args else 3.4
		var lens := f.rotated(Vector3.UP, 0.6)
		if vg.activity != "lamp":
			# round the house: always from the green side, never against a wall
			lens = (lens + vg.home.global_basis.z * 1.2).normalized()
		var cp := at + lens * dist
		cp.y = terrain.height_at(cp.x, cp.z) + (1.7 if "wide" in args else 1.45)
		var tgt := at + Vector3.UP * (1.0 if vg.state == Villager.SIT else 1.25)
		if vg.activity == "lamp":
			tgt = at.lerp(world.lantern_post.lantern_center(), 0.5)
			cp.y += 0.2
		if "chop" in args or "split" in args:
			# side on from the green to the block: her heave and the axe's arc, the halves
			# ("split": the moment after the blow, the halves jumping off)
			var ch := vg.chop
			ch._round_on = true
			ch._t = 3.0 if "chop" in args else 3.95
			ch.pin = 3.98 if "chop" in args else 4.62
			lens = (vg.home.global_basis.z + f * 0.45).normalized()
			cp = at + f * 0.35 + lens * 3.6
			cp.y = terrain.height_at(cp.x, cp.z) + 1.35
			tgt = at + f * 0.45 + Vector3.UP * 1.05
		if "feed" in args and vg.feed != null:
			# from inside the garth, low over the hens at the grain, Edda casting over the wall
			var hn: Hens = world.hens
			var ct: StoneCottage = world.stone_cottage
			if "wait" in args:
				# ("wait": before the first handful, the hens lined up at the wall at her call)
				for k in 150:
					hn.expect(vg.global_position + Vector3.UP * 1.55)
					hn._process(1.0 / 30.0)
				vg.feed._t = 0.0
			else:
				for k in 3:
					var lw := HenFeed.LAND + Vector2(0.5 * (k - 1), 0.4 * sin(k * 2.0))
					hn._land(lw, (lw - Villager.FEED_STAND).normalized())
				for k in 150:
					hn._process(1.0 / 30.0)
				# the capture lands a little after the hand opens
				vg.feed._t = HenFeed.CAST_T * (2.0 + HenFeed.RELEASE + 0.03) - 2.0
			cp = ct.to_global(Vector3(-0.4, 0, -6.9))
			cp.y = terrain.height_at(cp.x, cp.z) + 1.25
			tgt = ct.to_global(Vector3(3.6, 0, -8.1))
			tgt.y = terrain.height_at(tgt.x, tgt.z) + 0.75
		var pp := at + f * -30.0
		if "talk" in args:
			# speaking with her: over the hero's shoulder from the green side, her line as a
			# subtitle, the house and her work behind her
			var to_side := lens if vg.activity != "lamp" else f
			pp = at + to_side * 2.0
			var to_v := Vector3(at.x - pp.x, 0, at.z - pp.z).normalized()
			vg.talking = 1.0e6
			vg.body.rotation.y = atan2(-to_v.x, -to_v.z)
			vg.goal_yaw = vg.body.rotation.y
			var hud: Hud = player.get_node("Hud")
			hud.say("Edda", Villager.LINES["wood"][3] if vg.activity == "wood" else Villager.INTRO[1], 1.0e6)
			cp = pp - to_v * 2.2 + to_v.cross(Vector3.UP) * 1.2
			cp.y = terrain.height_at(cp.x, cp.z) + 1.7
			tgt = at.lerp(pp, 0.3) + Vector3.UP * 1.3
			player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.05, pp.z)
			player.body.rotation.y = atan2(to_v.x, to_v.z)
		else:
			player.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.1, pp.z)
		SPOTS[spot] = [cp, tgt]
		print("SHOT villager %s at %s" % [vg.activity, at])
	if spot == "glide":
		# the hero under the open glider high over the vale, seen by the follow camera from
		# behind and a little to one side and above, the valley floor and the far ridges ahead
		var gfrom := Vector3(60, 0, -140)
		var gto := Vector3(-60, 0, 60)
		var galt := 16.0
		var gpitch := -0.22
		var gyaw := 0.55                       # lens bearing off dead astern (rad); ~1.4 for side-on
		for a in args:
			if a.begins_with("at="):
				var xz := a.substr(3).split(",")
				gfrom = Vector3(float(xz[0]), 0, float(xz[1]))
			elif a.begins_with("to="):
				var tz := a.substr(3).split(",")
				gto = Vector3(float(tz[0]), 0, float(tz[1]))
			elif a.begins_with("alt="):
				galt = float(a.substr(4))
			elif a.begins_with("pitch="):
				gpitch = float(a.substr(6))
			elif a.begins_with("yaw="):
				gyaw = float(a.substr(4))
		var gdir := (gto - gfrom).normalized()
		player.use_bot_input = true
		player.global_position = gfrom + Vector3.UP * (terrain.height_at(gfrom.x, gfrom.z) + galt)
		player.body.rotation.y = atan2(gdir.x, gdir.z)
		player.velocity = gdir * Player.GLIDE_SPEED
		player._glide_tick(0.0, Vector2.ZERO, true, false)
		player.glider.open = 1.0
		var yc := atan2(gdir.x, gdir.z) + PI + gyaw
		player.set_look(yc, gpitch)
		# the stick holds the heading (camera-relative), so the hero flies on past the lens
		var cf := Vector3(-sin(yc), 0, -cos(yc))
		var cr := Vector3(cos(yc), 0, -sin(yc))
		player.bot_input = Vector2(gdir.dot(cr), -gdir.dot(cf))
		player.spring.spring_length = 4.6
		print("SHOT glide from %s heading %s" % [player.global_position, gdir])
	if spot == "climb":
		# the hero halfway up the keep's outer face, hands up on the stones, from below and
		# off to one side so the wall, the figure and the crown above all read
		var ruins: Ruins = world.get_node("Ruins")
		var rs: Vector3 = ruins.site
		var breach := atan2(-rs.z, -rs.x)
		var best := 0.0
		var pick := INF
		for k in 180:
			var a := TAU * k / 180.0
			if absf(wrapf(a - breach, -PI, PI)) < 1.2:
				continue
			var g := terrain.height_at(rs.x + cos(a) * 5.2, rs.z + sin(a) * 5.2)
			var h := ruins.wall_top(a, 4.3) - g
			if h > 4.0 and absf(h - 5.0) < pick:
				pick = absf(h - 5.0)
				best = a
		var rad := Vector3(cos(best), 0, sin(best))
		var tan := Vector3(-rad.z, 0, rad.x)
		var foot := rs + rad * 5.0
		var g0 := terrain.height_at(foot.x, foot.z)
		player.use_bot_input = true
		player.global_position = Vector3(foot.x, g0 + 1.6, foot.z)
		player.body.rotation.y = atan2(-rad.x, -rad.z)
		player._start_climb(rad)
		player.climbed = 0.6
		var hero := player.global_position + Vector3.UP * 1.1
		var cp := hero + rad * 4.2 + tan * 2.4
		cp.y = terrain.height_at(cp.x, cp.z) + 1.4
		if "side" in args:
			# three-quarter, mostly along the face from one side, level with the hips: the
			# hero's side, the hands and feet on the stones and the face's relief raking away
			# (rad * 1.2 still left the robe and back filling the frame: the drum curves away from
			# the tangent, so the camera can sit nearer the face plane and look up at the hands)
			cp = hero + rad * 0.7 + tan * 3.0 + Vector3.DOWN * 0.5
		SPOTS[spot] = [cp, hero + Vector3.UP * (0.5 if "side" in args else 0.3)]
		print("SHOT climb at %.2f rad, face %.1f m" % [best, pick + 5.0])
	if spot == "devil":
		# a dust devil standing up on the dry meadow 22-34 m off the hero, seen from beside the hero
		world.weather.force(0.0)
		world.weather.wet = 0.0
		await get_tree().process_frame
		var dd: DustDevils = world.dust_devils
		var hp := player.global_position
		# `near`: 11-15 m off, close enough to see the spin streaks and the grass swirl
		var close := "near" in args
		if dd.spawn_near(hp, 11.0 if close else 22.0, 15.0 if close else 34.0):
			dd.age = 8.0
			# 5 m behind the hero and 1.5 m to the hero's right, so the hero stands in frame left of the whirl
			var back := Vector3(hp.x - dd.pos.x, 0, hp.z - dd.pos.z).normalized()
			var right := back.cross(Vector3.UP)
			SPOTS[spot] = [hp + back * 5.0 + right * 1.5, dd.pos]
			print("SHOT devil at %s, %.0f m" % [dd.pos, Vector2(dd.pos.x - hp.x, dd.pos.z - hp.z).length()])
		else:
			print("SHOT devil: none stood up (thermal strength %.2f)" % world.thermals.strength)
			SPOTS[spot] = [hp, hp + Vector3(20, 0, 0)]
	if spot != "player" and SPOTS.has(spot):
		var s: Array = SPOTS[spot]
		var pos: Vector3 = s[0]
		var look: Vector3 = s[1]
		pos.y = look.y - 0.35 if spot == "midges" else (s[0] as Vector3).y if spot in ["butterflies", "flowers"] else terrain.height_at(pos.x, pos.z) + (1.2 if spot == "fireflies" else 1.5 if spot in ["hero", "heroback", "staff", "wade"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 or jump_t >= 0.0 or foe_u >= 0.0 else 2.5)
		look.y = (s[1] as Vector3).y if spot in ["midges", "butterflies", "flowers"] else terrain.height_at(look.x, look.z) + (0.6 if spot == "fireflies" else 1.3 if spot == "staff" else 1.1 if spot in ["hero", "heroback"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 or jump_t >= 0.0 else 1.35 if foe_u >= 0.0 else 1.5)
		if spot == "slope":
			pos = s[0]                           # the lens as framed (shin height), not 2.5 m up
			look = s[1]
		if spot == "soldier" and "knight" in args and "p3" in args:
			# 0.9 m (08:00 10-31) put the scorch behind the meadow grass: look down on it instead
			pos.y = terrain.height_at(pos.x, pos.z) + 2.1
			look.y = terrain.height_at(look.x, look.z) + 0.9
		if spot == "soldier" and "kindler" in args:
			pos.y = terrain.height_at(pos.x, pos.z) + (1.5 if "kfront" in args else 2.0)
			look.y = terrain.height_at(look.x, look.z) + (1.75 if "kfront" in args else 1.2)
		if spot == "soldier" and "harrier" in args and "coif" in args:
			# level with the wound head, wherever the crouch has put it (its Head bone)
			var hsk: Skeleton3D = world.harrier.model.find_children("*", "Skeleton3D", true, false)[0]
			var hhead: Vector3 = hsk.global_transform * hsk.get_bone_global_pose(hsk.find_bone("mixamorig_Head")).origin
			# (15:00 11-03: framing off the harrier's stand put the head at the bottom edge,
			# seen from above: the crouch carries the head well off fp. Now both ends hang off
			# the Head bone itself, from the body's own basis: +Z its front, +X the wearer's left.
			# `rear` swings round to the right rear quarter, onto the tie-off knot)
			var hb: Basis = world.harrier.global_transform.basis
			var hfwd := Vector3(hb.z.x, 0, hb.z.z).normalized()
			var hleft := Vector3(hb.x.x, 0, hb.x.z).normalized()
			var hoff := (hfwd * 0.55 + hleft * 0.85) if not "rear" in args else (-hfwd * 0.7 - hleft * 0.75)
			look = hhead + Vector3.UP * 0.06
			pos = hhead + hoff.normalized() * 1.05 + Vector3.UP * 0.1
			print("SHOT coif head at %.2f m over the turf" % (hhead.y - terrain.height_at(hhead.x, hhead.z)))
		if spot == "soldier" and "bite" in args:
			# look down at the buried bit and its turf burst, the hewer's arms above
			pos.y = terrain.height_at(pos.x, pos.z) + 1.75    # (2.7 looked straight down on the bent back; 1.75 profiles the stoop over the helve)
			look.y = terrain.height_at(look.x, look.z) + 0.5
		if spot == "wisps" and not "fire" in args:
			pos.y = terrain.height_at(pos.x, pos.z) + (1.9 if "close" in args else 1.45)
			look.y = terrain.height_at(look.x, look.z) + 1.25
		if spot == "hounds":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.25
			look.y = terrain.height_at(look.x, look.z) + 0.6
		if spot == "post":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.35
			look.y = (s[1] as Vector3).y
		if spot == "keeper" or spot == "talk" or spot == "wander" or spot == "keeperback" or spot == "keeperside" or spot == "hearth" or spot == "fox" or spot == "cottage" or spot == "stonehouse" or spot == "drywall" or spot == "yardwall" or spot == "hens" or spot == "lantern" or spot == "villager" or spot == "doorstones" or spot == "dog" or spot == "osric" or spot == "pedlar" or spot == "roadmeet" or spot == "climb" or spot == "hare" or spot == "fellbell":
			pos.y = (s[0] as Vector3).y
			look.y = (s[1] as Vector3).y
		if spot == "devil":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.7
			look.y = terrain.height_at(look.x, look.z) + 3.5
		if spot == "herocu":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.65
			look.y = terrain.height_at(look.x, look.z) + 1.4
		if spot == "face":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.8
			look.y = terrain.height_at(look.x, look.z) + 1.75
		if spot == "ruin":
			pos.y += 2.5
		if spot == "seal":
			var st: float = world.get_node("Ruins").seal.top_y
			pos.y = st + 2.0
			look.y = st - 0.1
			if "footing" in args:
				pos.y = terrain.height_at(pos.x, pos.z) + 1.5
				look.y = st - 0.7
		if spot == "ferns":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.7
			look.y = terrain.height_at(look.x, look.z) + 0.3
		if spot == "puddles":
			pos.y = terrain.height_at(pos.x, pos.z) + 2.1
			look.y = terrain.height_at(look.x, look.z)
		if spot == "trample":
			pos.y = terrain.height_at(pos.x, pos.z) + (1.45 if "close" in args else 1.75)
			look.y = terrain.height_at(look.x, look.z)
		if spot == "hooves":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.6
			look.y = terrain.height_at(look.x, look.z)
		if spot == "herd":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.6
			look.y = terrain.height_at(look.x, look.z) + 0.7
		if spot == "turf":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.4
			look.y = terrain.height_at(look.x, look.z)
		var free := Camera3D.new()
		free.fov = 65.0
		free.far = 4000.0                       # same as the player camera (cloud deck at 3.4 km)
		world.add_child(free)
		free.global_position = pos
		for a in args:
			if a.begins_with("tilt="):          # pitch the view up by N degrees (sky shots)
				var hd := Vector2(look.x - pos.x, look.z - pos.z).length()
				look.y = pos.y + hd * tan(deg_to_rad(float(a.substr(5))))
		free.look_at(look)
		free.current = true
		cam = free
		if world.keeper.pick_hold and spot.begins_with("keeper"):
			# the low pick lens sits in the meadow: clip the blades within 0.9 m of it
			free.near = 0.9
		if spot == "hare":
			print("SHOT hare lens %s look %s" % [pos, look])
		if spot == "flowers":
			free.near = 0.02
			var cf := CameraAttributesPractical.new()
			cf.dof_blur_far_enabled = true
			cf.dof_blur_far_distance = 2.0
			cf.dof_blur_far_transition = 6.0
			cf.dof_blur_amount = 0.08
			free.attributes = cf
		if spot == "butterflies":
			# macro lens: the meadow behind melts away
			free.near = 0.01
			var ca := CameraAttributesPractical.new()
			ca.dof_blur_far_enabled = true
			ca.dof_blur_far_distance = 0.35
			ca.dof_blur_far_transition = 1.2
			ca.dof_blur_amount = 0.18
			free.attributes = ca
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
	if "nosun" in args:
		# is a surface lit by a sun that leaks through a gap? Cuts the direct sun only (World
		# rewrites its energy every frame; the bounce fill keeps reading sun.visible)
		world.sun.light_cull_mask = 0
	if "nogi" in args:
		world.env.environment.sdfgi_enabled = false
		world.env.environment.ssao_enabled = false
		world.env.environment.ssil_enabled = false
	if "noglow" in args:
		world.env.environment.glow_enabled = false
	if "nomoonshadow" in args:
		# is the night mid-valley lost in the moon's shadow map (150 m reach) rather than unlit?
		world.moon.shadow_enabled = false
	for a in args:
		if a.begins_with("moonshadow="):   # the moon's shadow reach in metres (world.gd: 150)
			world.moon.directional_shadow_max_distance = float(a.substr(11))
		if a.begins_with("ngfill="):   # the night ground fill (world.gd NIGHT_GROUND_FILL 0.7); 0 = 23:51's look
			world.night_ground_fill = float(a.substr(7))
		if a.begins_with("skyx="):
			world.sky_energy_scale = float(a.substr(5))
		if a.begins_with("ambx="):
			world.ambient_scale = float(a.substr(5))
	if "clear" in args:
		# pin a clear sky: the software renderer's first frames compile shaders for minutes, and
		# those long deltas can run the clock past Weather's first clear hold, rolling a front in
		world.weather.force(0.0)
		world.weather.wet = 0.0
	for a in args:
		if a.begins_with("rain="):
			# rain= is the rain level wanted, not the front strength: a front under ~0.6
			# is only overcast (Weather._rain_level), so rain=0.5 used to give rain 0.00
			var want := clampf(float(a.substr(5)), 0.0, 1.0)
			var lo := 0.0
			var hi := 1.0
			for _i in 24:
				var mid := (lo + hi) * 0.5
				if smoothstep(0.55, 0.95, mid) * mid < want:
					lo = mid
				else:
					hi = mid
			world.weather.force(hi if want > 0.0 else 0.0)
		if a.begins_with("cloud="):   # a front strength as is (below 0.55: overcast, dry)
			world.weather.force(float(a.substr(6)))
	for a in args:
		if a.begins_with("wet="):    # soak the ground after a passing shower (pools, light rain)
			world.weather.wet = float(a.substr(4))
		if a.begins_with("drip="):   # crowns still running with water (after a shower)
			world.weather.canopy_water = float(a.substr(5))
		if a.begins_with("soak="):   # drench (or dry) the hero and the soldier
			player.soak.level = float(a.substr(5))
			if world.soldier != null:
				world.soldier.soak.level = float(a.substr(5))
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
	if kick_t >= 0.0:
		Engine.max_physics_steps_per_frame = 1
		Engine.time_scale = 1.0
		player.use_bot_input = true
		RenderingServer.render_loop_enabled = false
		for i in 90:
			await get_tree().physics_frame
		var rs2: Vector3 = world.get_node("Ruins").site
		for i in 240:
			if i % 50 == 0 and player.is_on_floor():
				player.bot_jump = true             # (again, if the first leap fell short)
			var to := rs2 - player.global_position
			to.y = 0.0
			var f := -player.cam_pivot.global_basis.z
			f.y = 0.0
			var r := player.cam_pivot.global_basis.x
			r.y = 0.0
			player.bot_input = Vector2(to.dot(r.normalized()), -to.dot(f.normalized())).normalized()
			await get_tree().physics_frame
			if player.climbing:
				break
		player.bot_input = Vector2.ZERO
		for i in 20:
			await get_tree().physics_frame
		print("SHOT wallkick climbing %s mantles %d mantle_t %.2f climbs %d y %.2f" % [player.climbing, player.mantles, player.mantle_t, player.climbs, player.global_position.y])
		player.bot_input = Vector2(1, 0.2) if "aside" in args else Vector2(0, 1)
		player.bot_jump = true
		player.bot_jump_hold = true
		var kt := 0.0
		for i in 600:
			await get_tree().physics_frame
			kt += 1.0 / 60.0
			if i == 1:
				player.bot_input = Vector2.ZERO
			if kt >= kick_t:
				break
		get_tree().paused = true
		RenderingServer.render_loop_enabled = true
		print("SHOT wallkick t %.3f kicks %d wj_t %.2f y %.2f yaw %.2f knee %.2f hip %.2f" % [kt, player.wall_jumps, player._wj_t, player.global_position.y, player.body.rotation.y, player.crumple.knee, player.crumple.hip])
	if jump_t >= 0.0:
		Engine.max_physics_steps_per_frame = 1
		Engine.time_scale = 1.0
		player.use_bot_input = true
		RenderingServer.render_loop_enabled = false
		for i in 30:
			await get_tree().physics_frame
		var land := -1.0
		for a in args:
			if a.begins_with("land="):
				land = float(a.substr(5))
		var spr := "sprint" in args
		var jstart := player.global_position
		if "drop" in args:
			player.global_position += Vector3.UP * 4.0
		elif not "fromrest" in args:
			for i in 60:
				player.bot_input = _stick_for(player, Vector3(1, 0, 0))
				player.bot_sprint = spr
				await get_tree().physics_frame
		# pivotat=<t>: the stick thrown back to world -X at a run (the plant-and-spin pivot)
		var pivot_at := -1.0
		for a in args:
			if a.begins_with("pivotat="):
				pivot_at = float(a.substr(8))
		# nojump: only run (with fromrest from a standstill), stopat=<t> lets go of the stick,
		# turnat=<t> swings it 90 deg: the start / stop / turn lean frames
		var stop_at := -1.0
		var turn_at := -1.0
		for a in args:
			if a.begins_with("stopat="):
				stop_at = float(a.substr(7))
			if a.begins_with("turnat="):
				turn_at = float(a.substr(7))
		if not "drop" in args and not "nojump" in args:
			player.bot_jump = true
		player.bot_jump_hold = true
		var t := 0.0
		# press=<t> with light/heavy: the jump attack or the plunge pressed that far into the jump
		var press_t := -1.0
		for a in args:
			if a.begins_with("press="):
				press_t = float(a.substr(6))
		var pressed := -1
		for i in 600:
			if not "drop" in args:
				# world-space: the camera rig follows the hero, so a fixed stick would curve the run
				player.bot_input = _stick_for(player, Vector3(1, 0, 0))
				if turn_at >= 0.0 and t >= turn_at:
					player.bot_input = _stick_for(player, Vector3(0, 0, 1))
				if "spotturn" in args:
					# standing: the body squares up 160 deg round at turnat (stepped, head first) and
					# ends square to the stoplens/pivotlens lens (sun side of the run line, +/-Z, a
					# touch toward +X), so the head arrives at the camera first; body +Z is the face
					var sl: Vector3 = -world.sun.global_transform.basis.z
					var lz := 1.0 if -sl.z > 0.0 else -1.0
					if "flip" in args:
						lz = -lz
					var lens_yaw := atan2(0.7, 3.0 * lz)
					player.bot_input = Vector2.ZERO
					if t == 0.0:
						player.body.rotation.y = lens_yaw - deg_to_rad(160.0)
					if t >= maxf(turn_at, 0.0) and is_nan(player.bot_square_yaw):
						player.bot_square_yaw = lens_yaw
				if pivot_at >= 0.0 and t >= pivot_at:
					player.bot_input = _stick_for(player, Vector3(-1, 0, 0))
				if stop_at >= 0.0 and t >= stop_at:
					player.bot_input = Vector2.ZERO
				player.bot_sprint = spr
			if press_t >= 0.0 and pressed < 0 and t >= press_t:
				pressed = i
				if "heavy" in args:
					player.bot_heavy = true
				else:
					player.bot_attack = true
			if pressed >= 0 and i > pressed + 2:
				player.bot_heavy = false
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if land < 0.0 and t >= jump_t:
				break
			if land >= 0.0 and player.land_t >= land:
				break
		get_tree().paused = true
		RenderingServer.render_loop_enabled = true
		# carried back to where the run began, so the side-on lens set up there frames the leap
		# (same height over the turf; the pose is already frozen)
		var jd := player.global_position - jstart
		var jh := player.global_position.y - terrain.height_at(player.global_position.x, player.global_position.z)
		var back := Vector3(jstart.x, 0, jstart.z) + Vector3(0, terrain.height_at(jstart.x, jstart.z) + jh, 0)
		player.global_position = back
		if "pivotlens" in args or "stoplens" in args:
			# pivotlens: a low front-3/4 lens on the frozen hero itself, on the sun side, so the
			# skid, the planted leg and the shoulders winding round all face the camera in light
			var plight: Vector3 = -world.sun.global_transform.basis.z
			var pside := Vector3(0, 0, 1) if -plight.z > 0.0 else Vector3(0, 0, -1)
			if "flip" in args:
				pside = -pside
			# stoplens: the same, but a touch ahead of the hero (the stop faces on along +X)
			var pc := back + pside * 3.0 + Vector3(0.7 if "stoplens" in args else -1.4, 0, 0)
			pc.y = terrain.height_at(pc.x, pc.z) + 1.25
			var aim := back + Vector3.UP * 0.85
			if "feetlens" in args:
				# feetlens: closer and high, looking down onto the soles (a pivot foot, a step round)
				pc = back + (pc - back).normalized() * 2.3
				pc.y = terrain.height_at(pc.x, pc.z) + 2.3
				aim = back + Vector3.UP * 0.45
			var pcam := get_viewport().get_camera_3d()
			pcam.global_position = pc
			pcam.look_at(aim)
			print("SHOT pivotlens cam %s hero %s side %s" % [pc, back, pside])
		print("SHOT jump ran %.2f m" % Vector2(jd.x, jd.z).length())
		print("SHOT lean pitch %.3f roll %.3f blend %.2f" % [player.lean.x, player.lean.y, player._blend])
		print("SHOT pivot t %.3f pivots %d yaw %.2f stride %.2f dip %.3f" % [player.pivot_t, player.pivots, player.body.rotation.y, player.crumple.stride, player._pose_dip])
		print("SHOT stop t %.3f stops %d lead %+.0f hip_lr %s knee_lr %s dip %.3f" % [player.stop_t, player.stops, player.stop_lead, player.crumple.hip_lr, player.crumple.knee_lr, player._pose_dip])
		print("SHOT jump t %.3f air %.3f land %.3f knee %.2f hip %.2f y %.2f" % [t, player._air_t, player.land_t, player.crumple.knee, player.crumple.hip, player.global_position.y])
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
	if spot == "ring" and "intro" in args:
		# intro [it=1.0]: the knight's camera reveal (BossIntro), stepped by hand to `it` seconds,
		# seen through the reveal's own lens with the letterbox drawn
		var iu := 1.0
		for a in args:
			if a.begins_with("it="):
				iu = float(a.substr(3))
		var kk: AshenKnight = world.knight
		var gate := player.global_position
		var kin := gate.lerp(kk.global_position, 0.42)   # the hero a few steps inside the ring
		player.global_position = Vector3(kin.x, terrain.height_at(kin.x, kin.z) + 0.05, kin.z)
		player.use_bot_input = true
		kk._player = player
		kk.set_physics_process(false)
		kk._begin_intro()
		var bi: BossIntro = kk.intro
		bi.set_physics_process(false)
		var dt := 1.0 / 60.0
		for i in int(iu * 60.0):
			bi.t += dt
			bi.bars = smoothstep(0.0, 0.5, bi.t) * (1.0 - smoothstep(BossIntro.ROAR_END, BossIntro.T, bi.t))
			kk._physics_process(dt)
			player._physics_process(dt)
			bi._frame(bi.t)
		bi.cam.make_current()
		cam = bi.cam
		var hud = player.get_node_or_null("Hud")
		if hud != null:
			hud.letterbox = bi.bars
			hud._letterbox.queue_redraw()
		get_tree().paused = true
		print("SHOT intro t %.2f cam %s lift %.1f heave %.2f bars %.2f" % [bi.t, bi.cam.global_position, bi.max_lift, kk._heave_now, bi.bars])
	if spot == "ring" and "crown" in args:
		# ring crown [ct=N] [p2]: the hero dropped 3 m over the knight's helm, a heavy pressed (the
		# plunge), stepped by hand N physics ticks (~16: the crown strike's hit-stop; ~34: the vault
		# off the shoulders), seen from the knight's flank, low, the helm against the sky
		var ct := 16
		for a in args:
			if a.begins_with("ct="):
				ct = int(a.substr(3))
		var ck: AshenKnight = world.knight
		var cr: StoneRing = world.stone_ring
		var cf := Vector3(cr.facing.x, 0, cr.facing.y)
		var cside := cf.cross(Vector3.UP)
		ck.intro_seen = true
		ck._player = player
		if "p2" in args:
			ck._set_phase(2)
			ck.set_size_scale(ck.growth.scale_of(2))
		ck.face(ck.global_position + cf * 5.0)
		ck.set_physics_process(false)
		var cc: Array = ck.hurt_capsule()
		var ctop: float = maxf(cc[0].y, cc[1].y) + float(cc[2])
		player.use_bot_input = true
		player.global_position = ck.global_position + Vector3(0.12, ctop - ck.global_position.y + 3.0, 0.08)
		player.body.rotation.y = atan2(cf.x, cf.z)
		player.velocity = Vector3.ZERO
		var cdt := 1.0 / 60.0
		for i in 3:
			player._physics_process(cdt)
		player.bot_heavy = true
		for i in ct:
			if i == 2:
				player.bot_heavy = false
			ck._physics_process(cdt)
			player._physics_process(cdt)
		var kp := ck.global_position
		var cp := kp + cside * 7.5 * ck.size_scale / 2.2 - cf * 2.5
		cp.y = terrain.height_at(cp.x, cp.z) + 1.4
		cam.global_position = cp
		cam.look_at(kp + Vector3.UP * (ctop - kp.y) * 0.8)
		get_tree().paused = true
		print("SHOT crown ct %d size %.2f crowns %d vaults %d hero %s knight state %d" % [ct, ck.size_scale, player.combat.crown_strikes, player.vaults, player.global_position - kp, ck.state])
	if spot == "ring" and "reel" in args:
		# ring reel [rt=S] [p2] [front]: the knight's crown reel S seconds in (the head knocked
		# onto the chest at 0, lolling at 0.4, shaking it off at 0.85, thrown back at 1.05), the
		# hero stood off out of frame, seen from the knight's flank-front, low, against the sky
		var rt := 0.3
		for a in args:
			if a.begins_with("rt="):
				rt = float(a.substr(3))
		var ek: AshenKnight = world.knight
		var er: StoneRing = world.stone_ring
		var ef := Vector3(er.facing.x, 0, er.facing.y)
		var eside := ef.cross(Vector3.UP)
		ek.intro_seen = true
		if "p2" in args:
			ek._set_phase(2)
			ek.set_size_scale(ek.growth.scale_of(2))
		ek.face(ek.global_position + ef * 5.0)
		player.use_bot_input = true
		player.global_position = ek.global_position - ef * 14.0
		player.global_position.y = terrain.height_at(player.global_position.x, player.global_position.z) + 0.1
		ek._player = player
		ek.state = HollowSoldier.IDLE
		ek.crowned(ek.global_position + Vector3.UP * 5.0)
		ek.set_physics_process(false)
		var edt := 1.0 / 60.0
		for i in int(round((rt - AshenKnight.CROWN_IMPACT_U * AshenKnight.CROWN_STAGGER) / edt)):
			ek._physics_process(edt)
		var kp := ek.global_position
		# frame off the body's own facing (the ring's facing is not where its chest points)
		ef = ek.body.global_basis.z
		ef.y = 0.0
		ef = ef.normalized()
		eside = ef.cross(Vector3.UP)
		var side_k := -1.0 if "flip" in args else 1.0
		var ep := kp + eside * side_k * (2.6 if "front" in args else 6.0) * ek.size_scale / 2.2 + ef * (7.0 if "front" in args else 2.0) * ek.size_scale / 2.2
		ep.y = terrain.height_at(ep.x, ep.z) + 1.0
		cam.global_position = ep
		cam.look_at(kp + Vector3.UP * 1.25 * ek.size_scale)
		print("SHOT reel rt %.2f size %.2f state %d bow %.2f roll %.2f" % [rt, ek.size_scale, ek.state, ek.head.bow, ek.head.roll])
		print("SHOT reel cam %s cur %s knight %s fwd %s hero %s" % [cam.global_position, get_viewport().get_camera_3d().global_position, kp, ek.body.global_basis.z, player.global_position])
	if spot == "ring" and "stride" in args:
		# ring stride [sz=4.6] [v=4.5]: the knight at size sz walking across the ring at v m/s
		# (bot_move), seen side-on from the gate; the frame count sets the stride phase
		var rk: AshenKnight = world.knight
		var rr: StoneRing = world.stone_ring
		var rf := Vector3(rr.facing.x, 0, rr.facing.y)
		var rside := rf.cross(Vector3.UP)
		var sz := 4.6
		var sv := -1.0
		for a in args:
			if a.begins_with("sz="):
				sz = float(a.substr(3))
			if a.begins_with("v="):
				sv = float(a.substr(2))
		if sv < 0.0:
			sv = HollowSoldier.STALK_SPEED * sqrt(sz)
		rk.set_size_scale(sz)
		rk.notice = -1.0
		var kst := rr.centre - rside * 4.0
		rk.global_position = Vector3(kst.x, terrain.height_at(kst.x, kst.z) + 0.05, kst.z)
		rk.bot_move = rside * sv
		var sc := rr.centre + rf * (4.0 + 2.6 * sz)
		sc.y = terrain.height_at(sc.x, sc.z) + 0.25 * sz
		cam.global_position = sc
		cam.look_at(rr.centre + Vector3.UP * 0.9 * sz)
		print("SHOT ring stride size %.2f at %.2f m/s" % [sz, sv])
	if spot == "ring" and "turn" in args:
		# ring turn [sz=4.6]: the knight at size sz standing side-on in the ring, turning on the spot
		# to face the gate (bot_face, 90 deg); the frame count sets how far into the turn it is
		var rk: AshenKnight = world.knight
		var rr: StoneRing = world.stone_ring
		var rf := Vector3(rr.facing.x, 0, rr.facing.y)
		var rside := rf.cross(Vector3.UP)
		var sz := 4.6
		for a in args:
			if a.begins_with("sz="):
				sz = float(a.substr(3))
		rk.set_size_scale(sz)
		rk.notice = -1.0
		rk.state = HollowSoldier.IDLE
		rk.global_position = Vector3(rr.centre.x, terrain.height_at(rr.centre.x, rr.centre.z) + 0.05, rr.centre.z)
		rk._home = rk.global_position
		rk.face(rk.global_position + rside * 5.0)
		rk._prev_yaw = rk.body.rotation.y
		rk.bot_face = rf
		var sc := rr.centre + rf * (3.0 + 2.2 * sz) + rside * 1.2 * sz
		sc.y = terrain.height_at(sc.x, sc.z) + 0.2 * sz
		cam.global_position = sc
		cam.look_at(rr.centre + Vector3.UP * 0.55 * sz)
		print("SHOT ring turn size %.2f" % sz)
	if spot == "ring" and "surge" in args:
		# ring surge [st=N]: the knight at its post growing into phase 2 (BossGrowth), N physics
		# ticks in: the armour seams spitting fire and grit shaken off the stones behind it,
		# seen from inside the ring a few steps in front of the gate
		var st := 24
		for a in args:
			if a.begins_with("st="):
				st = int(a.substr(3))
		var rk: AshenKnight = world.knight
		var rr: StoneRing = world.stone_ring
		var rf := Vector3(rr.facing.x, 0, rr.facing.y)
		var rside := rf.cross(Vector3.UP)
		rk.face(rk.global_position + rf * 5.0 + rside * 2.0)
		rk._begin_surge()
		var sdt := 1.0 / 30.0
		for i in st:
			rk._physics_process(sdt)
		var sc := rr.centre + rf * 11.0 + rside * 3.0
		sc.y = terrain.height_at(sc.x, sc.z) + 1.2
		cam.global_position = sc
		cam.look_at(rr.centre + Vector3.UP * 3.4)
		if "side" in args:
			# from the knight's flank, low, looking up at its chest: the burst against the sky
			var kp := rk.global_position
			var sp := kp + rside * 9.0 * rk.size_scale / 2.2 + rf * 3.0
			sp.y = terrain.height_at(sp.x, sp.z) + 0.9
			cam.global_position = sp
			cam.look_at(kp + Vector3.UP * 1.9 * rk.size_scale)
		print("SHOT ring surge st %d size %.2f embers %d grit %d" % [st, rk.size_scale, rk.growth.ember_bursts, rk.growth.grit_falls])
		for a in args:
			if a.begins_with("hide="):
				for nm in a.substr(5).split(","):
					var hn := world.get_node_or_null(NodePath(nm))
					if hn != null:
						hn.visible = false
						hn.process_mode = Node.PROCESS_MODE_DISABLED
		var names := []
		for ch in world.get_children():
			names.append(ch.name)
		print("SHOT world children ", names)
	if foe_u >= 0.0:
		# step the soldier and the hero's draw by hand (awaiting physics frames with the
		# render loop off stalls under Vulkan here), then hold everything still for the shot
		player.use_bot_input = true
		var foe: HollowSoldier = world.knight if "knight" in args else (world.warden if "warden" in args else (world.hewer if "hewer" in args else (world.archer if "archer" in args else (world.harrier if "harrier" in args else world.soldier))))
		var dt := 1.0 / 60.0
		foe.set_physics_process(false)
		player.combat._begin_draw()
		for i in 30:
			player.combat.physics_step(dt)
		var sw := "sweep" in args
		if sw:
			foe.move_kind = HollowSoldier.SWEEP_MOVE
		var dur := {HollowSoldier.WINDUP: HollowSoldier.SWEEP_WINDUP_T if sw else HollowSoldier.WINDUP_T, HollowSoldier.STRIKE: HollowSoldier.SWEEP_T if sw else HollowSoldier.STRIKE_T, HollowSoldier.STAGGER: HollowSoldier.STAGGER_T, HollowSoldier.DEAD: 2.4}
		if foe is HollowHewer and not sw:
			# hewer: the chop (raise + a 0.3 s hitch + glint, then the fall)
			foe.move_kind = HollowHewer.CHOP_MOVE
			dur[HollowSoldier.WINDUP] = HollowHewer.RAISE_T + 0.3 + HollowHewer.GLINT_T
			dur[HollowSoldier.STRIKE] = HollowHewer.CHOP_T
			dur[HollowSoldier.RECOVER] = HollowHewer.STUCK_T
		if foe is HollowArcher and not sw:
			# archer: the shot (raise + draw + a 0.4 s hold + glint, then the loose)
			foe.move_kind = HollowArcher.SHOT_MOVE
			dur[HollowSoldier.WINDUP] = foe.shot_windup()
			dur[HollowSoldier.STRIKE] = HollowArcher.LOOSE_T
			dur[HollowSoldier.RECOVER] = HollowArcher.RELOAD_T
		if foe is HollowHarrier and not sw:
			# harrier: the crouch at the hero's back, then the dart
			foe.move_kind = HollowHarrier.DART_MOVE
			dur[HollowSoldier.WINDUP] = HollowHarrier.TELL_T
			dur[HollowSoldier.STRIKE] = HollowHarrier.DART_T
			dur[HollowSoldier.RECOVER] = HollowHarrier.OVERRUN_T
		if foe_state == HollowSoldier.STAGGER:
			foe.take_hit(foe.global_position + Vector3.UP, Vector3(1, 0, 0), 1.0, 0.0)
		elif foe_state == HollowSoldier.DEAD:
			foe.take_hit(foe.global_position + Vector3.UP, Vector3(1, 0, 0), 20.0, 0.0)
		else:
			foe.windups += 1
			foe._enter(HollowSoldier.WINDUP)
			if foe_state == HollowSoldier.STRIKE or foe_state == HollowSoldier.RECOVER:
				foe.t = float(dur[HollowSoldier.WINDUP])
		var rolled_clear := false
		for i in 600:
			foe._physics_process(dt)
			if "bite" in args and not rolled_clear and foe.state == HollowSoldier.STRIKE:
				# bite: the hero has rolled clear as the axe falls, so the bit buries in the turf
				rolled_clear = true
				foe._aimed = false
				# roll away from the lens so the hero never steps into the frame's foreground
				var away: Vector3 = foe.body.global_basis.x
				var lens_at: Vector3 = (SPOTS[spot] as Array)[0]
				if away.dot(lens_at - player.global_position) > 0.0:
					away = -away
				var off: Vector3 = player.global_position + away * 1.7
				player.global_position = Vector3(off.x, (world.get_node("Terrain") as Terrain).height_at(off.x, off.z) + 0.05, off.z)
			if foe.state == foe_state and foe.t >= foe_u * float(dur[foe_state]):
				break
		if "harrier" in args and "coif" in args and cam != null:
			# the hand-stepped crouch has moved and turned the head since the lens was set:
			# re-aim on the Head bone now, from the body's own basis (+Z front, +X its left)
			# (18:00 11-03: in the crouch the head is turned ~90 deg off the body basis: +cfwd+cleft framed
			# the bare back-left of the skull, +cfwd-cleft the visor; the knot quarter is -cfwd+cleft)
			var csk: Skeleton3D = foe.model.find_children("*", "Skeleton3D", true, false)[0]
			var chead: Vector3 = csk.global_transform * csk.get_bone_global_pose(csk.find_bone("mixamorig_Head")).origin
			var cb: Basis = foe.body.global_basis
			var cfwd := Vector3(cb.z.x, 0, cb.z.z).normalized()
			var cleft := Vector3(cb.x.x, 0, cb.x.z).normalized()
			# (15:40 11-03: +Z put the lens behind the crouched harrier's shoulder: its face is -Z)
			var coff := (-cfwd * 0.55 - cleft * 0.85) if not "rear" in args else (-cfwd * 0.7 + cleft * 0.75)
			cam.global_position = chead + coff.normalized() * 1.05 + Vector3.UP * 0.1
			cam.look_at(chead + Vector3.UP * 0.06)
			print("SHOT coif re-aimed on the head at %s" % chead)
		if "kindler" in args:
			# kindler: the warden already burning white-hot, the Kindler at u= of a fresh chant
			# into it (spear raised, ember stream flowing); particles run on through the warm-up
			var kn: HollowKindler = world.kindler
			foe.kindle(HollowKindler.KINDLE_T)
			kn._player = player
			kn.target = foe
			kn._from = kn._pose
			kn.move_kind = HollowKindler.KINDLE_MOVE
			kn._enter(HollowSoldier.WINDUP)
			for i in 400:
				kn._physics_process(dt)
				if not kn.chanting() or kn.t >= foe_u * HollowKindler.CHANT_T:
					break
			kn._stream.preprocess = 0.6
			kn._stream.restart()
			if foe._kindle_sparks != null:
				foe._kindle_sparks.preprocess = 0.8
				foe._kindle_sparks.restart()
			print("SHOT kindler chanting %s t %.2f stream %s, warden kindled %.1f" % [kn.chanting(), kn.t, kn._stream.emitting, foe.kindled])
		if "knight" in args and "stomp" in args:
			# stomp (with g2/g3): the knee up at u= of the raise+hold; "wave": on past the stamp,
			# the shockwave caught wt= s out (default 0.5)
			var ksm: AshenKnight = foe
			ksm._player = player
			ksm.intro_seen = true
			ksm._flame_t = -999.0
			ksm.state = HollowSoldier.STALK
			ksm._from = ksm._pose
			ksm.move_kind = AshenKnight.STOMP_MOVE
			ksm._enter(HollowSoldier.WINDUP)
			var wt := 0.5
			for a2 in args:
				if a2.begins_with("wt="):
					wt = float(a2.substr(3))
			for i in 600:
				ksm._physics_process(dt)
				if "wave" in args:
					if ksm.last_wave != null and is_instance_valid(ksm.last_wave):
						if ksm.last_wave.t >= wt:
							break
						ksm.last_wave._process(dt)
				elif ksm.state == HollowSoldier.WINDUP and ksm.t >= foe_u * (AshenKnight.STOMP_RAISE_T + AshenKnight.STOMP_HOLD_T):
					break
			ksm.set_physics_process(false)
			if ksm.last_wave != null and is_instance_valid(ksm.last_wave):
				ksm.last_wave.set_process(false)
			print("SHOT knight stomp state %d t %.2f lift %.2f wave %s" % [ksm.state, ksm.t, ksm.tuck.lift_hip if ksm.tuck else 0.0, ksm.last_wave.r if ksm.last_wave != null and is_instance_valid(ksm.last_wave) else -1.0])
		if "knight" in args and "leap" in args:
			# leap: phase 2, the knight sprung from 7.7 m off, caught at u= of its airtime
			var kl: AshenKnight = foe
			kl._set_phase(2)
			kl._leap_cool = 0.0
			kl._player = player
			kl.state = HollowSoldier.STALK
			kl.t = 1.0
			kl.set_physics_process(true)
			for i in 400:
				kl._physics_process(dt)
				if "scorched" in args:
					# on through the landing: bent over the bitten glaive, the burn fresh
					if kl.move_kind == AshenKnight.LEAP_MOVE and kl.state == HollowSoldier.RECOVER and kl.t >= foe_u * AshenKnight.LEAP_RECOVER_T:
						break
				elif kl.move_kind == AshenKnight.LEAP_MOVE and kl.state == HollowSoldier.STRIKE and kl.t >= foe_u * AshenKnight.LEAP_T:
					break
			kl.set_physics_process(false)
			if "scorched" in args and kl.last_scorch != null:
				# low on the burn from the lit side, the knight stooped over it beyond
				var bt := kl.last_scorch.global_position
				var kd := Vector3(kl.global_position.x - bt.x, 0, kl.global_position.z - bt.z).normalized()
				var sd := kd.cross(Vector3.UP)
				var sl: Vector3 = -world.sun.global_transform.basis.z
				if sd.dot(Vector3(-sl.x, 0, -sl.z)) < 0.0:
					sd = -sd
				var cp := bt + sd * 2.4 - kd * 1.4
				cp.y = terrain.height_at(cp.x, cp.z) + 2.3
				cam.global_position = cp
				cam.look_at(bt.lerp(kl.global_position, 0.2) + Vector3.UP * 0.25)
				if "cooled" in args:
					# cooled: 8 s on, the cracks gone dark and the char left black
					for i in 80:
						kl.last_scorch._process(0.1)
				print("SHOT knight scorch at %s heat %.2f, camera %s" % [bt, kl.last_scorch.heat, cp])
			print("SHOT knight leap state %d t %.2f lift %.2f" % [kl.state, kl.t, kl.leap_lift])
		if "knight" in args and ("surge" in args or "p3" in args):
			# surge: the knight down on its knee as the ring of fire bursts (phase 2 -> 3);
			# p3: phase 3, the ground under the hero erupting. Fire is held back so it bursts
			# a few frames before the capture (run with fixfps).
			var k: AshenKnight = foe
			k._set_phase(2)
			if "surge" in args:
				# st=N: physics ticks into the surge before the warm-up frames (default 62: the
				# blast just gone; ~10-30 catches the growth with the seams spitting fire)
				var st := 62
				for a in args:
					if a.begins_with("st="):
						st = int(a.substr(3))
				k._begin_surge()
				for i in st:
					k._physics_process(dt)
			else:
				k._set_phase(3)
				var f := k.spawn_flame(player.global_position + (player.global_position - foe.global_position).normalized() * 0.4)
				f.t = AshFlame.WARN   # with the hold below it burst 7 frames before the capture
			var hold := (frames - 7) / 30.0
			for c in world.get_children():
				if c is AshFlame:
					(c as AshFlame).t -= hold
			print("SHOT knight phase %d surge %.2f flames %d" % [k.phase, k._surge, k.flames_spawned])
		if foe is HollowArcher and ("flight" in args or "lodged" in args):
			# flight: the loosed arrow ~4 m short of the hero, its streak behind it;
			# lodged: the arrow has struck and stands in the hero's torso
			var arr: HollowArrow = foe.last_arrow
			if arr == null:
				foe.t = float(dur[HollowSoldier.WINDUP])
				for i in 120:
					foe._physics_process(dt)
					if foe.last_arrow != null:
						break
				arr = foe.last_arrow
			if arr != null:
				arr.set_physics_process(false)
				for i in 240:
					if not is_instance_valid(arr):
						break
					arr._physics_process(dt)
					if "flight" in args and arr.point().distance_to(player.global_position + Vector3.UP * 1.2) < 1.5:
						break
					if "lodged" in args and arr.in_hero >= 0.0:
						for k in 20:
							player._physics_process(dt)
						if "snapped" in args:
							# the hero rolls on it: the shaft snaps and the fletched half drops
							player.dodge_t = HollowArrow.SNAP_AFTER + 0.01
							for k in 180:
								arr._physics_process(dt)
								if arr.lying:
									break
							player.dodge_t = -1.0
							var ap := arr.global_position
							var ln := Vector3(foe.global_position.x - ap.x, 0, foe.global_position.z - ap.z).normalized()
							var sd := ln.cross(Vector3.UP)
							# the roll has carried the hero on, away from the archer, past the half
							var rp := ap - ln * 2.4 + sd * 0.6
							player.global_position = Vector3(rp.x, terrain.height_at(rp.x, rp.z) + 0.05, rp.z)
							var vc := get_viewport().get_camera_3d()
							if vc != null:
								var cp := ap - sd * 1.1 + ln * 0.3
								cp.y = terrain.height_at(cp.x, cp.z) + 1.15
								vc.global_position = cp
								vc.look_at(ap)
								print("SHOT snapped lens %s %s -> screen %s" % [vc.name, vc.global_position, vc.unproject_position(ap)])
							print("SHOT snapped broken %s lying %s at %s" % [arr.broken, arr.lying, ap])
						break
				if "flight" in args and is_instance_valid(arr) and arr.in_hero < 0.0:
					# frame the arrow itself: square on to its line from 1.6 m on the sun side and
					# 0.45 m under it so it crosses the tree line, not the meadow; looking 0.7 m
					# ahead puts it left of centre, the streak trailing off left, the hero right
					# (a 5 mm shaft is a 3 px line at 2.2 m: it read as a far-off speck)
					var vc := get_viewport().get_camera_3d()
					var fl := Vector3(arr.vel.x, 0, arr.vel.z).normalized()
					var sd := fl.cross(Vector3.UP)
					var sun_l: Vector3 = -world.sun.global_transform.basis.z
					if sd.dot(Vector3(-sun_l.x, 0, -sun_l.z)) < 0.0:
						sd = -sd
					var ap := arr.global_position
					if vc != null:
						var cp := ap + sd * 1.6
						cp.y = maxf(ap.y - 0.45, terrain.height_at(cp.x, cp.z) + 0.6)
						vc.global_position = cp
						vc.look_at(ap + fl * 0.7)
						print("SHOT flight lens %s -> screen %s" % [vc.global_position, vc.unproject_position(ap)])
				if is_instance_valid(arr):
					arr.frozen = true
					print("SHOT arrow result '%s' in_hero %.2f streak %.2f m at %s" % [arr.result, arr.in_hero, arr.streak_length(), arr.point()])
		player.set_physics_process(false)
		if "parry" in args or "smash" in args or "flinch" in args or "fallen" in args or "knocked" in args:
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
	for a in args:
		if a.begins_with("bolt=") or a.begins_with("sheet="):
			# sheet= takes the same args: an in-cloud flash with no channel
			# bolt=<metres>[,<yaw offset deg>]: lightning ahead of the camera, frozen at its peak
			world.weather.lightning.auto_strikes = false
	if world.has_node("Grass") and get_viewport().get_camera_3d() != null:
		var gf: GrassField = world.get_node("Grass")
		gf.fill_around(get_viewport().get_camera_3d().global_position)
		print("SHOT grass: sward %d chunks %d clumps" % [gf.sward_chunks(), gf.sward_clumps()])
	for i in frames:
		if player.has_meta("shot_walk"):
			player.bot_input = _stick_for(player, player.get_meta("shot_walk")) * 0.5
		await get_tree().process_frame
	if player.has_meta("shot_walk"):
		print("SHOT stepdown root %.3f body off %.3f floor %s set down %d" % [player.global_position.y, player.body.position.y, player.is_on_floor(), StepUp.steps_down])
	if spot == "hearth" and "kindle" in args:
		# which side of her the lens sees: her model forward (+Z) against the lens direction
		var kb: Node3D = world.keeper.body
		var kf := kb.global_basis.z
		var to_lens := get_viewport().get_camera_3d().global_position - kb.global_position
		print("SHOT kindle facing %s yaw %.2f (spot %.2f), lens dir %s, dot %.2f" % [kf, kb.rotation.y,
			world.keeper._spots["kindle"][1], to_lens, Vector2(kf.x, kf.z).normalized().dot(Vector2(to_lens.x, to_lens.z).normalized())])
	if spot == "face" and cam != null:
		# aim from where the face actually is after the warm-up: out along head bone -> eyes,
		# 3/4 from the left, from a little below eye level (the idle head pitches down, so
		# from eye height the hat brim hides the eyes)
		var e0 := player.garb.eyes[0].global_position
		var e1 := player.garb.eyes[1].global_position
		var fc := (e0 + e1) * 0.5
		var hsk := player.model.find_child("Skeleton3D", true, false) as Skeleton3D
		var hb := hsk.global_transform * hsk.get_bone_global_pose(hsk.find_bone("mixamorig_Head")).origin
		var ef := fc - hb
		var fdir := Vector3(ef.x, 0, ef.z).normalized().rotated(Vector3.UP, 0.4)
		cam.global_position = fc + fdir * 0.85 + Vector3.DOWN * 0.14
		cam.look_at(fc + Vector3.DOWN * 0.04)
		print("SHOT face at %s, camera %s" % [fc, cam.global_position])
		for i in 3:
			await get_tree().process_frame
	if spot == "climb" and "side" in args:
		# re-aim after the warm-up from the hero's actual facing (the climb eases the body to
		# the averaged stone normal, so -rad at setup left the lens behind the shoulder):
		# square to the hero's left, a little out from the face and a touch above the hips so
		# the bed tops over the hands show their moss
		var lens := get_viewport().get_camera_3d()
		# aim from the measured face normal, not the body basis (the model's own facing in the
		# climb pose is not body +Z): along the face, a little out and well above the hands,
		# looking down so the hero is side-on and the bed tops (their moss) show
		var cn := player.climb_normal
		if cn.length() < 0.5:
			cn = -player.body.global_basis.z
		var face_out := Vector3(cn.x, 0, cn.z).normalized()
		var fwd := -face_out
		var lft := face_out.cross(Vector3.UP).normalized()
		var hp := player.global_position + Vector3.UP * 1.3
		lens.global_position = hp + face_out * 0.6 + lft * 2.6 + Vector3.UP * 1.5
		lens.look_at(hp + Vector3.UP * 0.2 - face_out * 0.15)
		var hsk2 := player.find_child("Skeleton3D", true, false) as Skeleton3D
		if hsk2 != null and hsk2.find_bone("mixamorig_Hips") >= 0:
			var hz := (hsk2.global_basis * hsk2.get_bone_global_pose(hsk2.find_bone("mixamorig_Hips")).basis).z
			print("SHOT climb hips fwd %s vs into-face %s" % [Vector3(hz.x, 0, hz.z).normalized(), fwd])
		print("SHOT climb re-aim fwd %s lens %s" % [fwd, lens.global_position])
		for i in 3:
			await get_tree().process_frame
	if spot == "osric" and "face" in args and cam != null:
		# the portrait aimed after the warm-up, from where his face is in the pose he holds
		# (leaning, the head drops forward over the cope): 3/4 from the front, just under eye level
		var nb2: Neighbour = world.neighbour
		var fc := (nb2.garb.eyes[0].global_position + nb2.garb.eyes[1].global_position) * 0.5
		var hsk := nb2.skel
		var hb := hsk.global_transform * hsk.get_bone_global_pose(hsk.find_bone("mixamorig_Head")).origin
		var ef := fc - hb
		var fdir := Vector3(ef.x, 0, ef.z).normalized().rotated(Vector3.UP, 0.45)
		cam.global_position = fc + fdir * 0.9 + Vector3.DOWN * 0.08
		cam.look_at(fc + Vector3.DOWN * 0.06)
		print("SHOT osric face at %s, camera %s" % [fc, cam.global_position])
		for i in 3:
			await get_tree().process_frame
	for a in args:
		if a.begins_with("bolt=") or a.begins_with("sheet="):
			var bp := a.substr(a.find("=") + 1).split(",")
			var bc := get_viewport().get_camera_3d()
			var bf := -bc.global_basis.z
			var byaw := atan2(bf.x, bf.z) + deg_to_rad(float(bp[1]) if bp.size() > 1 else 0.0)
			var bd := float(bp[0])
			var lt: Lightning = world.weather.lightning
			var at := Vector3(bc.global_position.x + sin(byaw) * bd, 0.0, bc.global_position.z + cos(byaw) * bd)
			at.y = lt._ground(at.x, at.z)
			lt.strike(at, a.begins_with("bolt="))
			lt.hold_age = 0.01
			for i in 3:
				await get_tree().process_frame
			print("SHOT bolt at %s flash %.2f strikes %d" % [at, lt.flash, lt.strikes])
	# debug: drop the volumetric haze ("novol") or the depth fog ("nofog") to see which paints a band
	if "novol" in args or "nofog" in args:
		var de: Environment = world.env.environment
		de.volumetric_fog_enabled = not "novol" in args
		de.fog_enabled = not "nofog" in args
		for i in 3:
			await get_tree().process_frame
	# debug: drop the screen-space passes ("nosse" = SSIL+SSAO+SSR, or one of nossil/nossao/nossr/noglow)
	if "nosse" in args or "nossil" in args or "nossao" in args or "nossr" in args or "noglow" in args:
		var se: Environment = world.env.environment
		if "nosse" in args or "nossil" in args:
			se.ssil_enabled = false
		if "nosse" in args or "nossao" in args:
			se.ssao_enabled = false
		if "nosse" in args or "nossr" in args:
			se.ssr_enabled = false
		if "noglow" in args:
			se.glow_enabled = false
		for i in 3:
			await get_tree().process_frame
	# debug: "hide=Flora,Horizon" hides those world nodes (by name) to find what paints a patch
	for a in args:
		if a.begins_with("hide="):
			for nn in a.substr(5).split(","):
				var hn := world.find_child(nn, true, false)
				if hn is Node3D:
					(hn as Node3D).visible = false
					print("SHOT hid ", nn)
			for i in 3:
				await get_tree().process_frame
	if spot == "mob" and cam != null:
		var kb: Birds.Bird = (world.get_node("Birds") as Birds)._kites[0]
		cam.fov = 34.0
		cam.look_at(kb.pos + Vector3.DOWN * 1.0)
		print("SHOT mob kite %s (hunt %d) %.1f m from the lens, %d mob events" % [kb.pos, kb.hunt, kb.pos.distance_to(cam.global_position), world.get_node("Birds").mob_events])
		for i in 2:
			await get_tree().process_frame
	if dodge_u < 0.0 and foe_u < 0.0 and impact_step < 0 and not "hud" in args:
		# the vitality/stamina bars only belong in combat frames ("hud" keeps them anywhere)
		(player.get_node("Hud/Bars") as Control).visible = false
		for i in 2:
			await get_tree().process_frame
	if _action.is_valid():
		await _action.call()
		for i in 2:
			await get_tree().process_frame
	if "menu" in args:   # the pause menu over the frame
		world.pause_menu.toggle()
		for i in 2:
			await get_tree().process_frame
	if spot == "pedlar" and world.pedlar.hand_lantern != null:
		for ch in world.pedlar.hand_lantern.get_children():
			if ch is HandMoths:
				var mcam := get_viewport().get_camera_3d()
				var fc: Vector3 = world.pedlar.hand_lantern.flame_center()
				print("SHOT flame %s screen %s, lens %s, view %s" % [fc, mcam.unproject_position(fc), mcam.global_position, get_viewport().get_visible_rect().size])
				for mp in (ch as HandMoths).moth_positions():
					print("SHOT moth %.2f m from the flame, %.2f m from the lens, screen %s%s" % [mp.distance_to(fc), mp.distance_to(mcam.global_position), mcam.unproject_position(mp), " (behind)" if mcam.is_position_behind(mp) else ""])
	if spot == "fellbell" and world.wheatears != null:
		var wcam := get_viewport().get_camera_3d()
		for wp in world.wheatears.bird_positions():
			print("SHOT wheatear %.1f m from the lens, screen %s%s" % [wp.distance_to(wcam.global_position), wcam.unproject_position(wp), " (behind)" if wcam.is_position_behind(wp) else ""])
	if spot == "soldier" and "flight" in args:
		var fcam := get_viewport().get_camera_3d()
		for ch in world.get_children():
			if ch is HollowArrow and is_instance_valid(ch):
				var ah := ch as HollowArrow
				print("SHOT capture hero %s screen %s, lens fov %.0f size %s, cams %s" % [player.global_position, fcam.unproject_position(player.global_position + Vector3.UP), fcam.fov, get_viewport().get_visible_rect().size, fcam.get_path()])
				print("SHOT capture lens %s: arrow %s %.1f m, screen %s%s, frozen %s" % [fcam.global_position, ah.global_position, ah.global_position.distance_to(fcam.global_position), fcam.unproject_position(ah.global_position), " (behind)" if fcam.is_position_behind(ah.global_position) else "", ah.frozen])
	_print_facing(world, player)
	var img := get_viewport().get_texture().get_image()
	var abs := ProjectSettings.globalize_path("res://") .path_join(out)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var err := img.save_png(abs)
	print("SHOT %s -> %s (%s) err=%d" % [spot, abs, img.get_size(), err])
	var we: Weather = world.weather
	print("SHOT wade splashes %d" % we.wade_splashes)
	if "dripdbg" in args:
		print("SHOT drips aabb %s cam %s land %s" % [we._drips.capture_aabb(), get_viewport().get_camera_3d().global_position, we._drip_land.slice(0, 3)])
	if "lights" in args or "nolights" in args:
		# light census round the hearth: which lights reach it at this hour
		var hp: Vector3 = world.hearth.global_position if world.get("hearth") else Vector3.ZERO
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			var lt := l as Light3D
			var rng := (lt as OmniLight3D).omni_range if lt is OmniLight3D else -1.0
			print("SHOT light %s vis %s e %.3f col %s range %.2f d %.2f mask %d" % [lt.get_path(), lt.is_visible_in_tree(), lt.light_energy, lt.light_color, rng, lt.global_position.distance_to(hp), lt.light_cull_mask])
		print("SHOT amb %s x %.3f" % [world.env.environment.ambient_light_color, world.env.environment.ambient_light_energy])
	if spot == "boulder":
		print("SHOT rock fill bounce %s sky_floor %s sdfgi %s" % [world.bounce_light, world.sky_floor, world.env.environment.sdfgi_enabled])
	if spot == "roadmeet":
		print("SHOT fill ground %s bounce %s sdfgi %s" % [world.ground_fill, RenderingServer.global_shader_parameter_get("bounce_light"), world.env.environment.sdfgi_enabled])
		for v in [world.pedlar, world.traveller]:
			var f: Vector3 = v.body.global_basis.z
			var tc: Vector3 = get_viewport().get_camera_3d().global_position - v.global_position
			print("SHOT roadmeet %s yaw %.2f goal %.2f faces-lens %.2f" % [v.name, v.body.rotation.y, v.goal_yaw, Vector2(f.x, f.z).normalized().dot(Vector2(tc.x, tc.z).normalized())])
	print("SHOT state: hour %.2f cloud %.2f rain %.2f wind %.2f wet %.2f sun %.2f fog %.4f fogcol %s canopy %.2f drips %d" % [world.time_of_day, we.cloud, we.rain, we.wind, we.wet, world.sun.light_energy, world.env.environment.fog_density, world.env.environment.fog_light_color, we.canopy_water, we.canopy_drips])
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
		if "facefoe" in args:
			var tf: Vector3 = foe.global_position - player.global_position
			player.body.rotation.y = atan2(tf.x, tf.z)   # squared up to the soldier (the body faces +Z)
		player.receive_attack(foe, HollowSoldier.DAMAGE)
		ImpactFX.spawn(player.get_parent(), player.global_position + Vector3.UP * 1.15, foe.body.global_basis.z, "stone", 0.7)
		var fticks := 6
		for a in args:
			if a.begins_with("ft="):
				fticks = int(a.substr(3))      # physics ticks into the stagger (a frame sequence)
		for i in fticks:
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
	elif "knocked" in args:
		# the soldier's sweep throws the hero onto their back (knocked=<seconds after the blow>)
		var at := 0.8
		for a in args:
			if a.begins_with("knocked="):
				at = float(a.substr(8))
		player.receive_attack(foe, HollowSoldier.SWEEP_DAMAGE, true)
		for i in int(at * 60.0):
			player._physics_process(dt)
		var mid := player.model.global_transform * Vector3(0, 0.9, 0)
		var cam := get_viewport().get_camera_3d()
		var side := player.body.global_basis.x
		# side-on and low, just over the grass tops, so the whole body reads lying on the sward
		cam.global_position = mid + side * 2.6 + player.body.global_basis.z * 0.4 + Vector3.UP * 1.3
		cam.look_at(mid - Vector3.UP * 0.55)
		print("SHOT knocked down_t %.2f knockdowns %d" % [player.down_t, player.knockdowns])
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

func _rr(a: float, b: float) -> float:
	return randf_range(a, b)

## A spread of headings for staged birds.
func _rng_yaw(k: int) -> float:
	return fmod(k * 2.39, TAU)

## The bot stick that drives the hero along a world direction, whatever way the camera rig faces.
func _stick_for(player: Player, dir: Vector3) -> Vector2:
	var b: Basis = player.cam_pivot.global_transform.basis
	var f := -b.z
	f.y = 0.0
	var r := b.x
	r.y = 0.0
	return Vector2(dir.dot(r.normalized()), -dir.dot(f.normalized()))

## Facing check at capture: which way each figure's body and feet point vs the lens that
## renders the frame (+1 = faces the camera, -1 = its back to it, 0 = side-on).
func _print_facing(world: Node3D, player: Player) -> void:
	var c := get_viewport().get_camera_3d()
	if c == null:
		return
	var figs := {"hero": player}
	if world.get("knight") != null:
		figs["knight"] = world.knight
	for k in figs:
		var f: Node3D = figs[k]
		if f == null or not is_instance_valid(f) or not f.is_inside_tree():
			continue
		var b: Node3D = f.get("body")
		var sk := f.find_child("Skeleton3D", true, false) as Skeleton3D
		var to_cam := c.global_position - f.global_position
		to_cam.y = 0.0
		to_cam = to_cam.normalized()
		var bz := b.global_basis.z
		bz.y = 0.0
		var toe_dot := NAN
		if sk != null and sk.find_bone("mixamorig_LeftToeBase") >= 0:
			var t := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftToeBase")).origin
			var a := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin
			var td := t - a
			td.y = 0.0
			toe_dot = td.normalized().dot(to_cam)
		for sk2 in f.find_children("*", "Skeleton3D", true, false):
			var s3 := sk2 as Skeleton3D
			var hb := s3.find_bone("mixamorig_Head")
			var hz := (s3.global_basis * s3.get_bone_global_pose(hb).basis).z if hb >= 0 else Vector3.ZERO
			hz.y = 0.0
			print("SHOT facing   skel %s vis %s basis.z.cam %.2f head.z.cam %.2f" % [f.get_path_to(s3), s3.is_visible_in_tree(), Vector3(s3.global_basis.z.x, 0, s3.global_basis.z.z).normalized().dot(to_cam), hz.normalized().dot(to_cam)])
		if k == "hero":
			var m: Node3D = f.get("model")
			print("SHOT facing   model.z.cam %.2f model %s" % [Vector3(m.global_basis.z.x, 0, m.global_basis.z.z).normalized().dot(to_cam), m.transform.basis.get_euler()])
		print("SHOT facing %s yaw %.2f body+Z.cam %.2f toe.cam %.2f lens %s (%s)" % [k, b.rotation.y, bz.normalized().dot(to_cam), toe_dot, c.global_position, c.get_path()])
