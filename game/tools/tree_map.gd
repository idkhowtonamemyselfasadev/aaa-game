extends Node
## Top-down map of the vale's oaks (first pass green, outer woods red) over the terrain
## heights, with the glide and devil shot lenses drawn in, plus a histogram of oaks by
## bearing from a viewpoint. Usage: godot --headless res://tools/tree_map.tscn -- out.png [x,z]
var world: Node3D

func _ready() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "../shots/tree_map.png"
	print("MAP world up")
	var terrain: Terrain = world.get_node("Terrain")
	var flora: Flora = world.get_node("Flora")
	const N := 256
	var half := terrain.size_m * 0.5
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for py in N:
		for px in N:
			var x := (px + 0.5) / N * terrain.size_m - half
			var z := (py + 0.5) / N * terrain.size_m - half
			var h := terrain.height_at(x, z)
			var v := clampf(0.2 + h / 80.0, 0.0, 1.0)
			img.set_pixel(px, py, Color(v, v, v))
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x + half) / terrain.size_m * N), int((z + half) / terrain.size_m * N))
	for i in flora.tree_positions.size():
		var p: Vector3 = flora.tree_positions[i]
		var c := Color(1, 0.1, 0.1) if i >= flora.outer_tree_start else Color(0.1, 0.9, 0.2)
		var q: Vector2i = to_px.call(p.x, p.z)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var pp := q + Vector2i(dx, dy)
				if pp.x >= 0 and pp.y >= 0 and pp.x < N and pp.y < N:
					img.set_pixel(pp.x, pp.y, c)
	for w in flora.wood_centres.size():
		var c: Vector2i = to_px.call(flora.wood_centres[w].x, flora.wood_centres[w].z)
		img.fill_rect(Rect2i(c - Vector2i(2, 2), Vector2i(5, 5)), Color(0.2, 0.4, 1))
		print("MAP wood %d at %s r %.0f" % [w, flora.wood_centres[w], flora.wood_radii[w]])
	img.save_png(out)
	var vp := Vector2(60, -140)
	if args.size() > 1:
		var xz := args[1].split(",")
		vp = Vector2(float(xz[0]), float(xz[1]))
	var bins := []
	bins.resize(16)
	bins.fill(0)
	var obins := bins.duplicate()
	for i in flora.tree_positions.size():
		var p: Vector3 = flora.tree_positions[i]
		var d := Vector2(p.x, p.z) - vp
		var a := fposmod(atan2(d.x, d.y), TAU)
		var b := int(a / TAU * 16.0) % 16
		bins[b] += 1
		if i >= flora.outer_tree_start:
			obins[b] += 1
	print("MAP trees %d (outer from %d, %d lone thinned) ruin %s" % [flora.tree_positions.size(), flora.outer_tree_start, flora.thinned_lone, flora.ruin_site])
	for b in 16:
		print("MAP bearing %5.1f deg (atan2 x,z): all %3d outer %3d" % [b * 22.5, bins[b], obins[b]])
	get_tree().quit()
