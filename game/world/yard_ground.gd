class_name YardGround
extends RefCounted
## The worn ground round the stone cottage: the hens' garth scratched to bare earth (Hens.YARD)
## and a beaten footpath from the garth gate round the gable, in through the yard wall's
## squeeze gap to the cottage door, and from the door out through the cart gateway toward
## the green. Both are baked into a small mask texture (global `yard_mask` / `yard_box`) that
## the terrain shader turns into dust, packed loam, claw rakes and dust baths; grass and
## flowers ask `worn` so the path stays bare.

const RES := 0.15     # mask texel (m)
## Footpaths in the stone cottage's local frame (x along its length, +z out of the door).
const PATHS_LOCAL := [
	# the garth gate (DryWall run 0), round the east gable, the squeeze gap, the door
	[Vector2(2.4, -6.7), Vector2(4.3, -6.4), Vector2(6.3, -4.4), Vector2(6.9, 2.2),
	 Vector2(5.9, 9.25), Vector2(4.99, 9.4), Vector2(4.1, 9.55), Vector2(1.8, 6.6), Vector2(0.6, 3.75)],
	# the door, across the yard, out of the cart gateway toward the green
	[Vector2(0.6, 3.75), Vector2(-1.4, 6.0), Vector2(-3.2, 7.4), Vector2(-5.2, 8.6),
	 Vector2(-6.8, 12.0), Vector2(-6.4, 17.0)],
]

static var _paths_world: Array = []
static var mask: ImageTexture        # as published (bots read these back)
static var mask_box := Vector4.ZERO

static func _to_local(x: float, z: float) -> Vector2:
	var d := Vector2(x, z) - StoneCottage.SITE
	var y := StoneCottage.yaw()
	return Vector2(d.x * cos(y) - d.y * sin(y), d.x * sin(y) + d.y * cos(y))

static func _paths() -> Array:
	if _paths_world.is_empty():
		for p: Array in PATHS_LOCAL:
			var w := PackedVector2Array()
			for l: Vector2 in p:
				w.append(DryWall._to_world(l))
			_paths_world.append(w)
	return _paths_world

## Distance (m) from world (x, z) to the nearest path centre line.
static func path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for w: PackedVector2Array in _paths():
		for i in w.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, w[i], w[i + 1])))
	return best

## Signed distance (m) into the garth from its wall feet: positive inside, negative outside.
static func garth_dist(x: float, z: float) -> float:
	var l := _to_local(x, z)
	var e := INF
	for i in Hens.YARD.size():
		e = minf(e, l.distance_to(Geometry2D.get_closest_point_to_segment(l, Hens.YARD[i], Hens.YARD[(i + 1) % Hens.YARD.size()])))
	return e if Hens.inside_yard(l) else -e

## 0..1: how bare the path has worn the turf at (x, z) (1 on the line, 0 past ~0.5 m).
static func worn(x: float, z: float) -> float:
	var d := Vector2(x, z) - StoneCottage.SITE
	if d.length_squared() > 625.0:
		return 0.0
	return 1.0 - smoothstep(0.22, 0.5, path_dist(x, z))

## World xz square covering the garth and the paths: (x0, z0, side).
static func box() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := -lo
	var pts: Array = []
	for w: PackedVector2Array in _paths():
		pts.append_array(Array(w))
	for c: Vector2 in Hens.YARD:
		pts.append(DryWall._to_world(c))
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var side := maxf(hi.x - lo.x, hi.y - lo.y) + 4.0
	var c := (lo + hi) * 0.5
	return Vector3(c.x - side * 0.5, c.y - side * 0.5, side)

## Bakes the mask and hands it to the shaders.
static func publish() -> void:
	var t0 := Time.get_ticks_usec()
	var b := box()
	var n := int(ceil(b.z / RES))
	var img := Image.create(n, n, false, Image.FORMAT_RG8)
	for j in n:
		var z := b.y + (j + 0.5) * b.z / n
		for i in n:
			var x := b.x + (i + 0.5) * b.z / n
			var g := clampf((garth_dist(x, z) + 1.0) / 3.0, 0.0, 1.0)
			var t := clampf(path_dist(x, z) / 2.0, 0.0, 1.0)
			img.set_pixel(i, j, Color(g, t, 0.0))
	mask = ImageTexture.create_from_image(img)
	mask_box = Vector4(b.x, b.y, b.z, 0.0)
	RenderingServer.global_shader_parameter_set("yard_mask", mask)
	RenderingServer.global_shader_parameter_set("yard_box", mask_box)
	print("YardGround: %dx%d mask over %.1f m in %.0f ms" % [n, n, b.z, (Time.get_ticks_usec() - t0) / 1000.0])
