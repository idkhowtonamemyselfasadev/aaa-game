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
		var cp := pp - to_k * 2.4 + to_k.cross(Vector3.UP) * 1.45
		cp.y = terrain.height_at(cp.x, cp.z) + 1.75
		SPOTS[spot] = [cp, at.lerp(pp, 0.3) + Vector3.UP * 1.3]
		print("SHOT talk %s at %s" % [kp.activity, at])
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
	if spot != "player" and SPOTS.has(spot):
		var s: Array = SPOTS[spot]
		var pos: Vector3 = s[0]
		var look: Vector3 = s[1]
		pos.y = look.y - 0.35 if spot == "midges" else (s[0] as Vector3).y if spot in ["butterflies", "flowers"] else terrain.height_at(pos.x, pos.z) + (1.2 if spot == "fireflies" else 1.5 if spot in ["hero", "heroback", "staff", "wade"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 or foe_u >= 0.0 else 2.5)
		look.y = (s[1] as Vector3).y if spot in ["midges", "butterflies", "flowers"] else terrain.height_at(look.x, look.z) + (0.6 if spot == "fireflies" else 1.3 if spot == "staff" else 1.1 if spot in ["hero", "heroback"] or swing_step >= 0 or impact_step >= 0 or dodge_u >= 0.0 else 1.35 if foe_u >= 0.0 else 1.5)
		if spot == "post":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.35
			look.y = (s[1] as Vector3).y
		if spot == "keeper" or spot == "talk" or spot == "wander" or spot == "keeperback" or spot == "keeperside" or spot == "hearth" or spot == "fox" or spot == "cottage" or spot == "stonehouse" or spot == "drywall" or spot == "yardwall" or spot == "hens" or spot == "lantern" or spot == "villager" or spot == "doorstones" or spot == "dog" or spot == "osric" or spot == "pedlar":
			pos.y = (s[0] as Vector3).y
			look.y = (s[1] as Vector3).y
		if spot == "face":
			pos.y = terrain.height_at(pos.x, pos.z) + 1.8
			look.y = terrain.height_at(look.x, look.z) + 1.75
		if spot == "ruin":
			pos.y += 2.5
		if spot == "seal":
			var st: float = world.get_node("Ruins").seal.top_y
			pos.y = st + 2.0
			look.y = st - 0.1
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
	for a in args:
		if a.begins_with("skyx="):
			world.sky_energy_scale = float(a.substr(5))
		if a.begins_with("ambx="):
			world.ambient_scale = float(a.substr(5))
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
	for a in args:
		if a.begins_with("bolt=") or a.begins_with("sheet="):
			# sheet= takes the same args: an in-cloud flash with no channel
			# bolt=<metres>[,<yaw offset deg>]: lightning ahead of the camera, frozen at its peak
			world.weather.lightning.auto_strikes = false
	for i in frames:
		await get_tree().process_frame
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

func _rr(a: float, b: float) -> float:
	return randf_range(a, b)

## A spread of headings for staged birds.
func _rng_yaw(k: int) -> float:
	return fmod(k * 2.39, TAU)
