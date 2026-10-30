extends SceneTree
## What stands between a spot and the sun through the day: marches from six points on a ring
## toward the sun (0.5 m steps, 200 m) and names the first thing in the way -- the terrain,
## an oak crown (a 4.5 m cylinder 2.5-11 m above its foot) or a boulder. Answers "why is this
## spot in shadow at hour H" before anyone touches albedo again. Defaults to the old fold.
## Usage: godot --headless --path game -s res://tools/sun_check.gd -- [x z [ring_r]]
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.run_clock = false
	await process_frame
	var terrain: Terrain = world.get_node("Terrain")
	var flora: Flora = world.get_node("Flora")
	var args := OS.get_cmdline_user_args()
	var c := FellBell.fold_centre()
	var ring := FellBell.FOLD_R
	if args.size() >= 2:
		c = Vector2(float(args[0]), float(args[1]))
		ring = float(args[2]) if args.size() > 2 else 2.0
	var pts: Array[Vector3] = []
	for k in 6:
		var p := c + Vector2.from_angle(TAU * k / 6.0) * ring
		pts.append(Vector3(p.x, terrain.height_at(p.x, p.y) + 0.4, p.y))
	print("SUN spot %s ring %.1f m (points E, then every 60 deg)" % [c, ring])
	for h in range(7, 19):
		world.time_of_day = float(h)
		world._apply_time()
		var tos: Vector3 = world.sun.global_transform.basis.z.normalized()
		if tos.y <= 0.0:
			continue
		var res: Array[String] = []
		for p in pts:
			res.append(_blocker(p, tos, terrain, flora))
		print("SUN %02d:00 elev %4.1f  %s" % [h, rad_to_deg(asin(tos.y)), ", ".join(res)])
	quit()

func _blocker(p: Vector3, tos: Vector3, terrain: Terrain, flora: Flora) -> String:
	for i in range(1, 400):
		var q := p + tos * (i * 0.5)
		if q.y < terrain.height_at(q.x, q.z):
			return "fell@%.0fm" % (i * 0.5)
		for t in flora.tree_positions:
			var g := terrain.height_at(t.x, t.z)
			if Vector2(q.x - t.x, q.z - t.z).length() < 4.5 and q.y > g + 2.5 and q.y < g + 11.0:
				return "oak(%.0f,%.0f)@%.0fm" % [t.x, t.z, i * 0.5]
		for r in flora._rock_feet:
			if Vector2(q.x - r.x, q.z - r.z).length() < r.y * 0.9 and q.y < terrain.height_at(r.x, r.z) + r.y * 1.2:
				return "stone(%.0f,%.0f)@%.0fm" % [r.x, r.z, i * 0.5]
	return "LIT"
