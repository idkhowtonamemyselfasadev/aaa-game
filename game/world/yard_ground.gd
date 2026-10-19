class_name YardGround
extends RefCounted
## The worn ground round the stone cottage: the hens' garth scratched to bare earth (Hens.YARD)
## and a beaten footpath from the garth gate round the gable, in through the yard wall's
## squeeze gap to the cottage door, and from the door out through the cart gateway toward
## the green. Both are baked into a small mask texture (global `yard_mask` / `yard_box`) that
## the terrain shader turns into dust, packed loam, claw rakes and dust baths; grass and
## flowers ask `worn` so the path stays bare.
## The village tracks are baked into the same mask: footpaths worn across the green from
## each house door to the lantern post where they meet, and one on from there out toward
## the start, fading back into the sward as fewer feet go that way.

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

## Village tracks in world xz: [point, wear 0..1] (wear fades the far end into the sward).
const TRACKS := [
	# the white cottage's door, round the front of the green to the lantern post
	[[Vector2(-16.75, -1.0), 1.0], [Vector2(-16.0, 0.3), 1.0], [Vector2(-13.8, 1.7), 1.0],
	 [Vector2(-11.7, 2.25), 1.0], [Vector2(-10.3, 2.2), 1.0], [Vector2(-9.7, 3.7), 1.0]],
	# the timber house's door, a few steps down to it
	[[Vector2(-10.45, 7.0), 1.0], [Vector2(-9.95, 6.1), 1.0], [Vector2(-9.6, 4.9), 1.0], [Vector2(-9.7, 3.7), 1.0]],
	# the stone cottage's cart gateway path, down the green past the timber house's gable
	[[Vector2(-7.14, 15.23), 1.0], [Vector2(-5.8, 12.6), 1.0], [Vector2(-6.3, 9.3), 1.0],
	 [Vector2(-8.2, 6.0), 1.0], [Vector2(-9.7, 3.7), 1.0]],
	# from the lantern post on out toward the start, wearing out into the meadow
	[[Vector2(-9.7, 3.7), 1.0], [Vector2(-7.6, 3.0), 0.95], [Vector2(-5.2, 2.0), 0.8],
	 [Vector2(-3.1, 1.3), 0.5], [Vector2(-1.4, 0.9), 0.0]],
]

static var _paths_world: Array = []
static var _wear_world: Array = []   # per point, parallel to _paths_world
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
			var e := PackedFloat32Array()
			for l: Vector2 in p:
				w.append(DryWall._to_world(l))
				e.append(1.0)
			_paths_world.append(w)
			_wear_world.append(e)
		for t: Array in TRACKS:
			var w := PackedVector2Array()
			var e := PackedFloat32Array()
			for q: Array in t:
				w.append(q[0])
				e.append(q[1])
			_paths_world.append(w)
			_wear_world.append(e)
	return _paths_world

## (distance (m) to the nearest path centre line, that path's wear there 0..1) at world (x, z).
static func path_wear(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := Vector2(INF, 0.0)
	var paths := _paths()
	for k in paths.size():
		var w: PackedVector2Array = paths[k]
		var e: PackedFloat32Array = _wear_world[k]
		for i in w.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, w[i], w[i + 1])
			var d := p.distance_to(c)
			if d < best.x:
				var sl := w[i].distance_to(w[i + 1])
				best = Vector2(d, lerpf(e[i], e[i + 1], w[i].distance_to(c) / maxf(sl, 1e-4)))
	return best

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
	var b := mask_box if mask_box.z > 0.0 else Vector4(-40.0, -10.0, 60.0, 0.0)
	if x < b.x or z < b.y or x > b.x + b.z or z > b.y + b.z:
		return 0.0
	var pw := path_wear(x, z)
	return (1.0 - smoothstep(0.22, 0.5, pw.x)) * smoothstep(0.1, 0.6, pw.y)

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

## Bakes the mask and hands it to the shaders: r garth, g path distance, b that path's wear.
## Each segment only writes the texels within 2 m of it, and the garth only its own corner,
## so the bake stays cheap as the tracks reach across the green.
static func publish() -> void:
	var t0 := Time.get_ticks_usec()
	var b := box()
	var n := int(ceil(b.z / RES))
	var cell := b.z / n
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	dist.fill(2.0)
	var wear := PackedFloat32Array()
	wear.resize(n * n)
	var paths := _paths()
	for k in paths.size():
		var w: PackedVector2Array = paths[k]
		var e: PackedFloat32Array = _wear_world[k]
		for s in w.size() - 1:
			var a := w[s]
			var c := w[s + 1]
			var sl := maxf(a.distance_to(c), 1e-4)
			var i0 := maxi(int((minf(a.x, c.x) - 2.0 - b.x) / cell), 0)
			var i1 := mini(int((maxf(a.x, c.x) + 2.0 - b.x) / cell) + 1, n)
			var j0 := maxi(int((minf(a.y, c.y) - 2.0 - b.y) / cell), 0)
			var j1 := mini(int((maxf(a.y, c.y) + 2.0 - b.y) / cell) + 1, n)
			for j in range(j0, j1):
				var z := b.y + (j + 0.5) * cell
				for i in range(i0, i1):
					var p := Vector2(b.x + (i + 0.5) * cell, z)
					var q := Geometry2D.get_closest_point_to_segment(p, a, c)
					var d := p.distance_to(q)
					if d < dist[j * n + i]:
						dist[j * n + i] = d
						wear[j * n + i] = lerpf(e[s], e[s + 1], a.distance_to(q) / sl)
	var garth := PackedFloat32Array()
	garth.resize(n * n)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for l: Vector2 in Hens.YARD:
		var g := DryWall._to_world(l)
		lo = Vector2(minf(lo.x, g.x), minf(lo.y, g.y))
		hi = Vector2(maxf(hi.x, g.x), maxf(hi.y, g.y))
	var gi0 := maxi(int((lo.x - 1.5 - b.x) / cell), 0)
	var gi1 := mini(int((hi.x + 1.5 - b.x) / cell) + 1, n)
	var gj0 := maxi(int((lo.y - 1.5 - b.y) / cell), 0)
	var gj1 := mini(int((hi.y + 1.5 - b.y) / cell) + 1, n)
	for j in range(gj0, gj1):
		for i in range(gi0, gi1):
			garth[j * n + i] = clampf((garth_dist(b.x + (i + 0.5) * cell, b.y + (j + 0.5) * cell) + 1.0) / 3.0, 0.0, 1.0)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var o := j * n + i
			img.set_pixel(i, j, Color(garth[o], clampf(dist[o] / 2.0, 0.0, 1.0), wear[o]))
	mask = ImageTexture.create_from_image(img)
	mask_box = Vector4(b.x, b.y, b.z, 0.0)
	RenderingServer.global_shader_parameter_set("yard_mask", mask)
	RenderingServer.global_shader_parameter_set("yard_box", mask_box)
	print("YardGround: %dx%d mask over %.1f m in %.0f ms" % [n, n, b.z, (Time.get_ticks_usec() - t0) / 1000.0])

## The terrain shader's value noise, mirrored so the CPU can tell where its patterns fall.
static func _fr(v: Vector3) -> Vector3:
	return v - v.floor()

static func _hash3(p: Vector3) -> float:
	p = _fr(p * 0.3183099 + Vector3(0.1, 0.2, 0.3)) * 17.0
	var r := p.x * p.y * p.z * (p.x + p.y + p.z)
	return r - floorf(r)

static func _vnoise(x: Vector3) -> float:
	var i := x.floor()
	var f := x - i
	f = f * f * (Vector3.ONE * 3.0 - 2.0 * f)
	return lerpf(lerpf(lerpf(_hash3(i), _hash3(i + Vector3(1, 0, 0)), f.x),
			lerpf(_hash3(i + Vector3(0, 1, 0)), _hash3(i + Vector3(1, 1, 0)), f.x), f.y),
		lerpf(lerpf(_hash3(i + Vector3(0, 0, 1)), _hash3(i + Vector3(1, 0, 1)), f.x),
			lerpf(_hash3(i + Vector3(0, 1, 1)), _hash3(i + Vector3(1, 1, 1)), f.x), f.y), f.z)

static func _fbm(p: Vector3) -> float:
	var a := 0.5
	var r := 0.0
	for k in 4:
		r += a * _vnoise(p)
		p = p * 2.03 + Vector3.ONE * 7.1
		a *= 0.5
	return r

## 0..1 depth of the trough the feet have worn down the middle of a track at world `w`
## (mirrors `rut` in terrain.gdshader, without its fine ragged-edge noise): rain stands in
## it from the deepest scuffed dips outward (see `rut_pool`).
static func rut_at(w: Vector3) -> float:
	var pw := path_wear(w.x, w.z)
	if pw.x > 0.6:
		return 0.0
	if Hens.inside_yard(_to_local(w.x, w.z)):
		return 0.0
	var wear := smoothstep(0.05, 0.85, pw.y)
	var hw := (0.34 + 0.12 * _vnoise(w * 0.7 + Vector3.ONE * 3.0)) * lerpf(0.55, 1.0, wear)
	var trackw := 1.0 - smoothstep(hw * 0.55, hw * 1.35, pw.x)
	var scuff := _fbm(Vector3(w.x * 0.9, 0.0, w.z * 0.9) + Vector3.ONE * 43.0)
	return trackw * (1.0 - smoothstep(0.0, hw * 0.85, pw.x)) \
		* smoothstep(0.42, 0.72, scuff + (_vnoise(w * 2.3 + Vector3.ONE * 7.0) - 0.5) * 0.18) * wear

## True where rain stands in a track at world `w` with the ground this wet (the shader's
## `rpool`: the water rises from the deepest dips as the ground soaks).
static func rut_pool(w: Vector3, wet: float) -> bool:
	if wet < 0.2:
		return false
	var rthr := lerpf(0.95, 0.25, smoothstep(0.3, 0.9, wet))
	return rut_at(w) > rthr + 0.05
