class_name Ruins
extends Node3D
## The ruined watchtower on the knoll above Harrowmere (Flora.ruin_site), all generated here:
##  - cut stone blocks: rounded boxes with chipped arrises (noise eaten into the bevels and
##    corners), 16 size variants, instanced through MultiMesh with a per-block tint;
##  - the tower: a round keep of three-leaf walls (outer face, rubble core, inner face)
##    of mixed stretchers, closers and headers on courses of varying height with open joints, broken down to a jagged crown with a breach toward the
##    village, slumped top stones, fallen blocks downslope and flagstones/rubble inside;
##  - a curtain wall ring 12.5 m out of two stone faces, robbed in stretches to the turf, its
##    crest stepped in columns, face stones fallen out and talus heaped at both feet;
##  - in the middle of the keep floor a worn two-step plinth carrying the carved lid over the
##    Shrine of Binding (ShrineSeal).
## Every block that stands above ground gets a box collider.

@export var terrain_path: NodePath
@export var flora_path: NodePath
@export var material: ShaderMaterial
@export var seed: int = 777

const VARIANTS := 16
const BEVEL := 0.06

var site := Vector3.ZERO
var block_count := 0
var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _dims: Array[Vector3] = []          # per variant: full size of the block mesh
var _per: Array = []                    # per variant: [Transform3D, Color]
var _body: StaticBody3D
var seal: ShrineSeal
var ivy: Ivy
var _crown_n: FastNoiseLite
var _breach := 0.0
var _swept: Array = []          # Hesper's swept hearth floor (_sweep_hearth)
var swept_count := 0            # loose stones left out of it (bots)
## Highest stone top laid so far per wall leaf (0-2 keep faces/core, 3-4 curtain faces) and angle
## bin, and the crest stones whose tops may stay open to the sky: after all courses are
## laid, the uncovered ones get loose stones and grass tufts (_dress_crown).
const BINS := 720
var _cover: Array[PackedFloat32Array] = []
var _crest_tops: Array = []          # [leaf, angle, arc, r, top y, depth]
var tuft_count := 0
var scree_count := 0
var curtain_scree := 0
var joint_tufts := 0
var _scree_tufts: Array = []         # grass rooted in the talus, planted with the crown tufts
## 1 while laying the curtain wall: its stones stood out in the weather longer, lower and
## damper than the keep's (darker crust, more lichen and moss; INSTANCE_CUSTOM.a)
var _aged := 0.0
var aged_count := 0

func _ready() -> void:
	_terrain = get_node(terrain_path)
	var flora: Flora = get_node(flora_path)
	site = flora.ruin_site
	# the keep's sunlit inner face lights its floor and rubble (see bounce.gdshaderinc)
	RenderingServer.global_shader_parameter_set("bounce_zone", Vector4(site.x, site.z, 3.4, 5.0))
	_rng.seed = seed
	_sweep_hearth()
	var meshes: Array[ArrayMesh] = []
	for v in VARIANTS:
		# lengths spread 0.4-1.5 m so a closer or a long stretcher gets a stone of its own
		# proportions (its bevels and chips are not squashed or stretched out of shape)
		var d := Vector3(lerpf(0.4, 1.5, (v + _rng.randf()) / VARIANTS), _rng.randf_range(0.3, 0.5), _rng.randf_range(0.5, 0.65))
		_dims.append(d)
		meshes.append(_block_mesh(d, v))
		_per.append([])
	_body = StaticBody3D.new()
	_body.name = "RuinCollision"
	add_child(_body)
	for l in 5:
		var c := PackedFloat32Array()
		c.resize(BINS)
		c.fill(-INF)
		_cover.append(c)
	_tower()
	_curtain()
	_scree()
	_dress_crown()
	_fallen()
	_plinth()
	for v in VARIANTS:
		_multimesh(meshes[v], _per[v], "Stones_%d" % v)
	ivy = Ivy.new()
	ivy.name = "Ivy"
	add_child(ivy)
	ivy.build(self, _terrain, seed + 31)

## World y of the keep's broken crown at angle a on the face of radius r (before the per-block
## jitter; the crest course is ragged ~0.25 m round it).
func wall_top(a: float, r: float) -> float:
	var gy := _terrain.height_at(site.x + cos(a) * r, site.z + sin(a) * r)
	var cr := _crown(_crown_n, a, _breach, 2.2, 7.4)
	var low := _low(cr)
	var leaf_off := -0.75 * low if r > 4.0 else 0.0
	return gy + cr + leaf_off + minf(0.0, _crown_n.get_noise_2d(cos(a) * 380.0 + 900.0, sin(a) * 380.0) * 1.5 * low)

## Wall crown height (m above the site floor) at angle a round the tower.
func _crown(n: FastNoiseLite, a: float, breach: float, lo: float, hi: float) -> float:
	# broad: one or two tall stretches round the ring; fine: a ragged step-down crest
	var broad := n.get_noise_2d(cos(a) * 14.0, sin(a) * 14.0)
	var fine := n.get_noise_2d(cos(a) * 70.0 + 300.0, sin(a) * 70.0) * 0.18
	var h := lerpf(lo, hi, smoothstep(-0.4, 0.45, broad + fine))
	var off := absf(wrapf(a - breach, -PI, PI))
	return lerpf(-0.6, h, smoothstep(0.2, 0.7, off))

func _tower() -> void:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.02
	n.fractal_octaves = 3
	var breach := atan2(-site.z, -site.x)         # toward the village
	_crown_n = n
	_breach = breach
	var floor_y := site.y
	var base := INF
	for k in 24:
		var a := TAU * k / 24.0
		base = minf(base, _terrain.height_at(site.x + cos(a) * 4.8, site.z + sin(a) * 4.8))
	base -= 0.35
	# three leaves: outer face, core (one course lower at the crown), inner face
	var leaves := [[4.3, 0.62, 0.0], [3.75, 0.5, -0.45], [3.2, 0.6, 0.0]]
	var y := base
	while y < floor_y + 8.0:
		var ch := _course_height(y - base)
		for li in leaves.size():
			var lf: Array = leaves[li]
			var r: float = lf[0]
			var depth: float = lf[1]
			for seg in _course_segments(r):
				var a: float = seg[0]
				var arc: float = seg[1]
				var p := site + Vector3(cos(a) * r, 0.0, sin(a) * r)
				var gy := _terrain.height_at(p.x, p.z)
				var cr := _crown(n, a, breach, 2.2, 7.4)
				var low := _low(cr)
				# where the wall is broken down low it steps back like a scree slope: the outer
				# face robbed a course or two below the core and the inner face, and the crest
				# stepping up and down in columns a stone or two wide
				var leaf_off: float = [-0.75, -0.3, 0.0][li] * low
				var steps := n.get_noise_2d(cos(a) * 380.0 + 900.0, sin(a) * 380.0) * 1.5 * low
				var top := gy + cr + float(lf[2]) + leaf_off + steps + _rng.randf_range(-0.25, 0.25)
				if y + ch > top:
					continue
				if y + ch < gy - 0.05:
					continue                         # buried footing
				if li == 0 and low > 0.3 and y > gy + 0.5 and y + ch * 2.0 < top and _rng.randf() < 0.2 * low:
					# a face stone fallen out mid-wall, the core showing in the hole; it lies at the foot
					var fp := site + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.8, 6.2)
					_rubble(fp, _rng.randf_range(0.35, 0.6))
					continue
				var crest := y + ch * 2.0 > top     # top course: loose, slumped, some gone
				if crest and _rng.randf() < 0.25:
					continue                         # robbed or fallen
				# open joints (2-6 cm, the mortar long washed out of them) and each block set on
				# its own bed: tops step, faces stand a little proud or sunk, slightly out of true
				var gap_v := _rng.randf_range(0.02, 0.06)
				var bh := ch - gap_v
				var bl := arc * r - _rng.randf_range(0.025, 0.065)
				var bd := depth
				var radial := _rng.randfn() * 0.018
				if r != 3.75 and arc * r < 0.62 and _rng.randf() < 0.6:
					bd = depth * 1.4                  # a header bonding into the core
					radial += (-0.12 if r > 4.0 else 0.12)
				p += Vector3(cos(a), 0, sin(a)) * radial
				p.y = y + bh * 0.5 + _rng.randf_range(0.0, gap_v * 0.4)
				var tilt := Vector3(_rng.randfn() * 0.012, _rng.randfn() * 0.02, _rng.randfn() * 0.012)
				var slumped := false
				if crest:
					tilt = Vector3(_rng.randfn() * 0.06, _rng.randfn() * 0.08, _rng.randfn() * 0.06)
					p += Vector3(cos(a), 0, sin(a)) * _rng.randf_range(-0.05, 0.12)
					if _rng.randf() < 0.3:
						# slid half off its bed and tipped over the face, mostly outward
						slumped = true
						var out := 1.0 if (_rng.randf() < 0.7) == (r > 3.75) else -1.0
						tilt.x = out * _rng.randf_range(0.15, 0.42)
						tilt.y += _rng.randfn() * 0.15
						p += Vector3(cos(a), 0, sin(a)) * out * _rng.randf_range(0.08, 0.22)
						p.y -= _rng.randf_range(0.02, 0.08)
				_place_ring(p, a, Vector3(bl, bh, bd), tilt, maxf(0.0, y - gy))
				_mark(li, a, arc, p.y + bh * 0.5)
				if li != 1 and not crest:
					_joint_tuft(p, a, bh, bd, 1.0 if li == 0 else -1.0, y - gy)
				if crest and not slumped:
					_crest_tops.append([li, a, arc, r, p.y + bh * 0.5, bd])
		y += ch
	# flagstones and rubble on the floor inside
	for i in 70:
		var a := _rng.randf() * TAU
		var rr := lerpf(1.85, 2.85, sqrt(_rng.randf()))   # the plinth holds the middle
		var p := site + Vector3(cos(a) * rr, 0, sin(a) * rr)
		p.y = _terrain.height_at(p.x, p.z)
		if i < 26:
			var s := Vector3(_rng.randf_range(0.6, 0.9), 0.14, _rng.randf_range(0.45, 0.7))
			p.y -= 0.04
			_place(p, Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.04), s, 0.0, false)
		else:
			_rubble(p, _rng.randf_range(0.35, 0.8))
	# spalls and chips knocked off the crown: heaped along the wall foot, scattered thinner
	# toward the plinth, half sunk in the floor
	for i in 110:
		var a := _rng.randf() * TAU
		var rr := lerpf(1.75, 2.95, pow(_rng.randf(), 0.6))
		var p := site + Vector3(cos(a) * rr, 0, sin(a) * rr)
		var s := _rng.randf_range(0.1, 0.3) * lerpf(0.7, 1.0, (rr - 1.75) / 1.2)
		_rubble(p, s)

## 0 where the keep stands tall, 1 where its crown (m above the ground) is broken down low.
func _low(crown: float) -> float:
	return 1.0 - smoothstep(3.0, 5.2, crown)

## Talus against the outer face wherever the keep is broken down low: the stones and spalls
## that fell off the crown heaped up to a metre against the wall foot and running out ~2.5 m,
## with grass and soil grown into them; the trodden way through the breach stays clear.
func _scree() -> void:
	var bd := Vector3(cos(_breach), 0, sin(_breach))
	var before := block_count
	for i in 900:
		var a := _rng.randf() * TAU
		var low := _low(_crown(_crown_n, a, _breach, 2.2, 7.4))
		if low < 0.15 or _rng.randf() > low:
			continue
		var hh := lerpf(0.5, 1.4, low) * (0.75 + 0.5 * _crown_n.get_noise_2d(cos(a) * 30.0, sin(a) * 30.0 + 500.0))
		var run := hh * 2.6
		var u := pow(_rng.randf(), 1.4)            # thicker against the wall
		var rr := 4.62 + u * run
		var p := site + Vector3(cos(a) * rr, 0, sin(a) * rr)
		var off := p - site
		if absf(off.dot(bd.cross(Vector3.UP))) < 1.4 and off.dot(bd) > 0.0:
			continue
		var g := _terrain.height_at(p.x, p.z)
		var surf := g + hh * pow(1.0 - u, 1.6)
		var s := _rng.randf_range(0.14, 0.42) * lerpf(1.0, 1.5, u)   # big stones roll furthest
		if _rng.randf() < 0.07:
			# a whole block off the crown, tipped and half sunk in the heap
			var v := _rng.randi() % VARIANTS
			var sz := _dims[v] * _rng.randf_range(0.8, 1.0)
			var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.45) * Basis(Vector3(0, 0, 1), _rng.randfn() * 0.35)
			_place(Vector3(p.x, surf - sz.y * 0.2, p.z), b, sz, 0.0, false, v)
			continue
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.7, 0.7)) * Basis(Vector3(0, 0, 1), _rng.randf_range(-0.5, 0.5))
		_place(Vector3(p.x, surf - s * 0.12, p.z), b, Vector3(s, s * 0.55, s * 0.75), 0.0, false)
		if _rng.randf() < 0.35:
			_scree_tufts.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.25)), Vector3(p.x, surf + s * 0.15, p.z)), 1 if _rng.randf() < 0.6 else 0])
	scree_count = block_count - before

## Height of the next course, h m above the footing: big squared stones low down, then a mix
## of ordinary courses and the odd thin levelling course of slabs.
func _course_height(h: float) -> float:
	if _rng.randf() < 0.12:
		return _rng.randf_range(0.2, 0.27)
	return _rng.randf_range(0.3, 0.52) * lerpf(1.18, 1.0, clampf(h / 2.0, 0.0, 1.0))

## One course of a ring wall of radius r, as [centre angle, arc] per stone: stretchers of mixed
## length with short closers and headers between them, the joints never lining up with the
## course below (random start angle per course and leaf).
func _course_segments(r: float) -> Array:
	var lens: Array[float] = []
	var total := 0.0
	var circ := TAU * r
	while total < circ - 0.3:
		var u := _rng.randf()
		var l := _rng.randf_range(0.36, 0.55) if u < 0.22 else (_rng.randf_range(1.15, 1.55) if u > 0.82 else _rng.randf_range(0.65, 1.05))
		lens.append(l)
		total += l
	var k := circ / total
	var a := _rng.randf() * TAU
	var out := []
	for l in lens:
		var arc := l * k / r
		out.append([a + arc * 0.5, arc])
		a += arc
	return out

## The curtain wall: two faces of squared stone (r +- 0.2 m) with the joint between them,
## robbed in long stretches down to the turf. What stands is broken like the keep's low side:
## the crest steps up and down in columns a stone or two wide, the two faces robbed to
## different heights so one stands a course above the other, face stones fallen out mid-wall
## and the stones heaped in a low talus against both feet.
func _curtain() -> void:
	var n := FastNoiseLite.new()
	n.seed = seed + 9
	n.frequency = 0.03
	n.fractal_octaves = 2
	var gate := atan2(-site.z, -site.x)
	var r := 12.5
	var hfn := func(a: float) -> float:
		return lerpf(-0.9, 1.9, smoothstep(-0.4, 0.45, n.get_noise_2d(cos(a) * 22.0, sin(a) * 22.0) + n.get_noise_2d(cos(a) * 90.0, sin(a) * 90.0) * 0.25))
	# per face: the crest in columns a stone or two wide, and the face's own robbing
	var top_of := func(a: float, li: int) -> float:
		var cols := n.get_noise_2d(cos(a) * 450.0 + 700.0 * li, sin(a) * 450.0) * 0.55
		var face := n.get_noise_2d(cos(a) * 160.0 - 400.0 * li, sin(a) * 160.0 + 250.0) * 0.4
		return float(hfn.call(a)) + cols + face
	# robbed stubs where the stone was carted off down to the turf
	for i in 80:
		var a := TAU * i / 80.0
		var p := site + Vector3(cos(a) * r, 0, sin(a) * r)
		if float(hfn.call(a)) < 0.2 and absf(wrapf(a - gate, -PI, PI)) >= 0.2 and _rng.randf() < 0.5:
			_rubble(p + Vector3(_rng.randfn(), 0, _rng.randfn()) * 0.8, _rng.randf_range(0.4, 0.9))
	# course by course, mixed stone lengths as in the keep; each stone stops where the robbed
	# crest height at its angle says
	var y0 := INF
	var y1 := -INF
	for i in 64:
		var g := _terrain.height_at(site.x + cos(TAU * i / 64.0) * r, site.z + sin(TAU * i / 64.0) * r)
		y0 = minf(y0, g)
		y1 = maxf(y1, g)
	var y := y0 - 0.2
	_aged = 1.0
	while y < y1 + 2.6:
		var ch := _course_height(y - y0 + 0.4)
		for li in 2:
			var rr := r + (0.2 if li == 0 else -0.2)
			var side := 1.0 if li == 0 else -1.0
			for seg in _course_segments(rr):
				var a: float = seg[0]
				var arc: float = seg[1]
				if absf(wrapf(a - gate, -PI, PI)) < 0.2:
					continue                             # the gateway
				var q := site + Vector3(cos(a), 0, sin(a)) * (rr + _rng.randf_range(-0.03, 0.03))
				var g := _terrain.height_at(q.x, q.z)
				var top := g + float(top_of.call(a, li)) + _rng.randf_range(-0.12, 0.12)
				if y < g - 0.2 - ch or y + ch * 0.5 > top:
					continue
				var crest := y + ch * 1.5 > top
				if crest and _rng.randf() < 0.2:
					continue                             # robbed or fallen
				if not crest and y > g + 0.25 and _rng.randf() < 0.1:
					# a face stone fallen out, the other face's back showing in the hole
					_rubble(site + Vector3(cos(a), 0, sin(a)) * (rr + side * _rng.randf_range(0.5, 1.4)), _rng.randf_range(0.3, 0.55))
					continue
				var gap_v := _rng.randf_range(0.02, 0.05)
				q.y = y + (ch - gap_v) * 0.5 + _rng.randf_range(0.0, gap_v * 0.4)
				q += Vector3(cos(a), 0, sin(a)) * _rng.randfn() * 0.02
				# out of true: the frost has worked each stone loose, the more the higher it sits
				# (the low courses are held by the talus and the turf)
				var loose := clampf((y - g) / 1.6, 0.0, 1.0)
				q += Vector3(cos(a), 0, sin(a)) * _rng.randfn() * (0.012 + 0.03 * loose)
				var tilt := Vector3(_rng.randfn() * (0.01 + 0.03 * loose), _rng.randfn() * (0.02 + 0.06 * loose), _rng.randfn() * (0.01 + 0.035 * loose))
				if crest:
					tilt = Vector3(_rng.randfn() * 0.06, _rng.randfn() * 0.08, _rng.randfn() * 0.06)
					if _rng.randf() < 0.25:
						tilt.x = side * _rng.randf_range(0.12, 0.35)   # tipped out over its face
						q += Vector3(cos(a), 0, sin(a)) * side * _rng.randf_range(0.04, 0.14)
				_place_ring(q, a, Vector3(arc * rr - _rng.randf_range(0.03, 0.06), ch - gap_v, 0.36), tilt, maxf(0.0, y - g))
				_mark(3 + li, a, arc, q.y + (ch - gap_v) * 0.5)
				if not crest:
					_joint_tuft(q, a, ch - gap_v, 0.36, side, y - g)
				if crest:
					_crest_tops.append([3 + li, a, arc, rr, q.y + (ch - gap_v) * 0.5, 0.36])
		y += ch
	# talus: the fallen stones and spalls heaped against both feet where the wall still stands,
	# grass grown into them; the way through the gateway stays clear
	var before := block_count
	for i in 1100:
		var a := _rng.randf() * TAU
		if absf(wrapf(a - gate, -PI, PI)) < 0.28:
			continue
		var stand := float(hfn.call(a))
		if stand < 0.0 or _rng.randf() > 0.35 + 0.35 * stand:
			continue
		var side := 1.0 if _rng.randf() < 0.55 else -1.0
		var hh := clampf(0.25 + stand * 0.38, 0.2, 0.85) * (0.7 + 0.6 * absf(n.get_noise_2d(cos(a) * 60.0, sin(a) * 60.0 - 300.0)))
		var u := pow(_rng.randf(), 1.3)
		var p := site + Vector3(cos(a), 0, sin(a)) * (r + side * (0.42 + u * hh * 3.0))
		var g := _terrain.height_at(p.x, p.z)
		var surf := g + hh * pow(1.0 - u, 1.6)
		var s := _rng.randf_range(0.12, 0.36) * lerpf(1.0, 1.4, u)
		if _rng.randf() < 0.05:
			var v := _rng.randi() % VARIANTS
			var sz := Vector3(_dims[v].x, _dims[v].y, 0.36) * _rng.randf_range(0.8, 1.0)
			var bb := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.45) * Basis(Vector3(0, 0, 1), _rng.randfn() * 0.35)
			_place(Vector3(p.x, surf - sz.y * 0.2, p.z), bb, sz, 0.0, false, v)
			continue
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.7, 0.7)) * Basis(Vector3(0, 0, 1), _rng.randf_range(-0.5, 0.5))
		_place(Vector3(p.x, surf - s * 0.12, p.z), b, Vector3(s, s * 0.55, s * 0.75), 0.0, false)
		if _rng.randf() < 0.4:
			_scree_tufts.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.25)), Vector3(p.x, surf + s * 0.15, p.z)), 1 if _rng.randf() < 0.6 else 0])
	curtain_scree = block_count - before
	_aged = 0.0

## Grass rooted in the soil lodged in a bed joint low on a wall face: on the open joint along
## the stone's top front edge, leaning out over the face (side = +1 outward, -1 inward).
## Dense near the damp foot, thinning out to ~2 m.
func _joint_tuft(c: Vector3, a: float, h: float, depth: float, side: float, above: float) -> void:
	if above < -0.1 or _rng.randf() > 0.3 * (1.0 - smoothstep(0.3, 2.0, above)):
		return
	var rad := Vector3(cos(a), 0, sin(a))
	var t := Vector3(-rad.z, 0, rad.x)
	var p := c + rad * side * (depth * 0.5 - 0.02) + t * _rng.randf_range(-0.3, 0.3) + Vector3.UP * (h * 0.5 - 0.01)
	var sc := _rng.randf_range(0.45, 0.8)
	var bb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.6, 0.95), sc))
	bb = Basis(t, -side * _rng.randf_range(0.35, 0.8)) * bb
	_scree_tufts.append([Transform3D(bb, p), 1 if _rng.randf() < 0.55 else 0])
	joint_tufts += 1

func _bin(a: float) -> int:
	return int(floor(wrapf(a, 0.0, TAU) / TAU * BINS)) % BINS

## Note a stone's top over the arc it covers in leaf l.
func _mark(l: int, a: float, arc: float, top: float) -> void:
	var c := _cover[l]
	var b0 := _bin(a - arc * 0.5)
	for k in int(ceil(arc / TAU * BINS)) + 1:
		var b := (b0 + k) % BINS
		c[b] = maxf(c[b], top)

## The broken crown once every course is laid: where a crest stone's top is still open to
## the sky (nothing set on it), loose stones knocked off the course above lie on it and grass
## tufts root in the soil blown into the joints and the rubble core.
func _dress_crown() -> void:
	var tufts: Array = _scree_tufts.duplicate()   # [Transform3D, kind]
	for ct in _crest_tops:
		var l: int = ct[0]
		var a: float = ct[1]
		var arc: float = ct[2]
		var r: float = ct[3]
		var top: float = ct[4]
		var depth: float = ct[5]
		var rad := Vector3(cos(a), 0, sin(a))
		# a few points along the stone; skip any that a stone above covers
		for i in 5:
			var aa := a + arc * _rng.randf_range(-0.45, 0.45)
			if _cover[l][_bin(aa)] > top + 0.06:
				continue
			var p := site + Vector3(cos(aa), 0, sin(aa)) * (r + _rng.randf_range(-0.3, 0.3) * depth)
			p.y = top
			var u := _rng.randf()
			if i == 0 and u < 0.16:
				# a loose stone off the course above, lying askew on this one
				var s := Vector3(_rng.randf_range(0.28, 0.5), _rng.randf_range(0.16, 0.26), _rng.randf_range(0.24, 0.4))
				var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.12) * Basis(Vector3(0, 0, 1), _rng.randfn() * 0.12)
				_place(p + Vector3.UP * (s.y * 0.45), b, s, top - _terrain.height_at(p.x, p.z), false)
			elif u < (0.85 if l == 1 else 0.65):
				# the core (rubble and soil) and the joints hold grass; tussocks most
				var kind := 1 if _rng.randf() < 0.6 else 0
				var sc := _rng.randf_range(0.8, 1.3) * (1.15 if l == 1 else 1.0)
				var bb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.7, 1.1), sc))
				# tufts on the face edge lean out over it
				bb = Basis(Vector3(-rad.z, 0, rad.x), _rng.randfn() * 0.15) * bb
				tufts.append([Transform3D(bb, p + Vector3.UP * 0.0), kind])
	tuft_count = tufts.size()
	var grass := get_node_or_null("../Grass") as GrassField
	if grass and tufts.size() > 0:
		var node := grass.static_tufts(tufts)
		node.name = "CrownGrass"
		add_child(node)

## Blocks that fell from the crown: thrown out round the tower, most through the breach
## and down the slope, half sunk in the turf at all angles.
func _fallen() -> void:
	var breach := atan2(-site.z, -site.x)
	for i in 64:
		var a := breach + _rng.randfn() * 0.5 if i < 34 else _rng.randf() * TAU
		var d := _rng.randf_range(4.8, 11.5) if i < 54 else _rng.randf_range(13.5, 22.0)
		var p := site + Vector3(cos(a) * d, 0, sin(a) * d)
		var off := p - site
		var bd := Vector3(cos(breach), 0, sin(breach))
		if absf(off.dot(bd.cross(Vector3.UP))) < 1.3 and off.dot(bd) > 0.0:
			continue                                 # the trodden way in stays clear
		var g := _terrain.height_at(p.x, p.z)
		var v := _rng.randi() % VARIANTS
		var s := _dims[v] * _rng.randf_range(0.85, 1.1)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randfn() * 0.5) * Basis(Vector3(0, 0, 1), _rng.randfn() * 0.35)
		p.y = g + s.y * 0.15
		_place(p, b, s, 0.0, true, v)

## Two worn courses of curved step stones round the shrine lid. The stones are instanced like
## the walls but do not collide; one low frustum collider ramps over both steps so the hero
## walks up onto the lid (the controller has no step-up).
func _plinth() -> void:
	var lo := INF
	var hi := -INF
	for k in 16:
		var a := TAU * k / 16.0
		for rr in [0.0, 0.9, 1.75]:
			var g := _terrain.height_at(site.x + cos(a) * rr, site.z + sin(a) * rr)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	var base := lo - 0.15
	var gc := _terrain.height_at(site.x, site.z)
	# set into the slope of the floor: the uphill side of the lower tread sinks flush
	var t1 := gc + 0.2                   # lower step top
	var t2 := t1 + 0.2                  # upper step top = lid seat
	var tiers := [[1.47, 0.5, t1, 0.55], [1.03, 0.42, t2, 0.5]]
	for tr in tiers:
		var r: float = tr[0]
		var count := int(round(TAU * r / float(tr[3])))
		var y := base
		var c := 0
		while y < float(tr[2]) - 0.02:
			var ch := minf(0.24, float(tr[2]) - y)
			var crest := y + ch >= float(tr[2]) - 0.02
			for i in count:
				var a := TAU * (i + (0.5 if c % 2 == 1 else 0.0)) / count + 0.2
				var p := Vector3(site.x + cos(a) * r, y + ch * 0.5, site.z + sin(a) * r)
				var tilt := Vector3(_rng.randfn() * 0.03, _rng.randfn() * 0.03, _rng.randfn() * 0.03) if crest else Vector3.ZERO
				if crest:
					p.y -= absf(_rng.randfn()) * 0.025       # worn, settled treads
				_place_ring(p, a, Vector3(TAU * r / count - 0.025, ch - 0.015, float(tr[1])), tilt, 0.0, false)
			y += ch
			c += 1
	var lid_top := t2 + 0.12
	# collider: a frustum from the lower step's outer edge up onto the lid
	var pts := PackedVector3Array()
	for k in 24:
		var a := TAU * k / 24.0
		var dv := Vector3(cos(a), 0, sin(a))
		var go := _terrain.height_at(site.x + dv.x * 3.0, site.z + dv.z * 3.0)
		var gm := _terrain.height_at(site.x + dv.x * 1.5, site.z + dv.z * 1.5)
		pts.append(site + dv * 3.0 + Vector3.UP * (go - 0.4 - site.y))
		pts.append(site + dv * 1.5 + Vector3.UP * (maxf(t1, gm + 0.03) - site.y))
		pts.append(site + dv * 0.75 + Vector3.UP * (lid_top - site.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.name = "Plinth"
	cs.shape = shape
	_body.add_child(cs)                  # points are world space (Ruins sits at the origin)
	seal = ShrineSeal.new()
	seal.name = "ShrineSeal"
	add_child(seal)
	seal.build(site, lid_top)

## Hesper's swept floor round her cookfire: no spalls or loose slabs on the ash ring, where
## she kneels to light it, or between there and the open floor toward the lid (the side the
## fire is seen from), as [a, b, r] capsules on the ground.
func _sweep_hearth() -> void:
	var hl := Keeper.hearth_layout(site)
	var hp: Vector3 = hl[0]
	var kn: Vector3 = hl[1]
	var mid := (hp + kn) * 0.5
	var side := Vector3(hp.x - kn.x, 0, hp.z - kn.z).normalized().cross(Vector3.UP)
	if (mid + side).distance_to(site) > (mid - side).distance_to(site):
		side = -side
	_swept = [[hp, hp, 1.05], [kn, kn, 0.8], [mid, mid + side * 1.9, 0.75]]

func _is_swept(p: Vector3) -> bool:
	for c in _swept:
		var a: Vector3 = c[0]
		var ab: Vector3 = c[1] - a
		ab.y = 0.0
		var ap := Vector3(p.x - a.x, 0, p.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if (ap - ab * t).length() < c[2]:
			return true
	return false

func _rubble(p: Vector3, s: float) -> void:
	var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.9, 0.9)) * Basis(Vector3(0, 0, 1), _rng.randf_range(-0.6, 0.6))
	p.y = _terrain.height_at(p.x, p.z)
	_place(p, b, Vector3(s, s * 0.55, s * 0.7), 0.0, false)

## A block in a ring wall at angle a: long axis along the circle.
func _place_ring(p: Vector3, a: float, size: Vector3, tilt: Vector3, above: float, collide := true) -> void:
	var t := Vector3(-sin(a), 0, cos(a))
	var rad := Vector3(cos(a), 0, sin(a))
	var b := Basis(t, Vector3.UP, -rad) * Basis.from_euler(tilt)
	_place(p, b, size, above, collide, -1, 1.0)

## laid = 1 for a stone laid in a wall course (its ends and beds sit in joints), 0 loose.
func _place(p: Vector3, b: Basis, size: Vector3, above: float, collide: bool, v: int = -1, laid := 0.0) -> void:
	if v < 0:
		# the best-fitting of three random variants by length
		v = _rng.randi() % VARIANTS
		for t in 2:
			var w := _rng.randi() % VARIANTS
			if absf(_dims[w].x - absf(size.x)) < absf(_dims[v].x - absf(size.x)):
				v = w
	var d: Vector3 = _dims[v]
	var sc := Vector3(size.x / d.x, size.y / d.y, size.z / d.z)
	# random flips so the same chips do not line up block after block
	if _rng.randf() < 0.5:
		sc.x = -sc.x
		sc.z = -sc.z
	var xf := Transform3D(b.orthonormalized() * Basis.from_scale(sc), p)
	if laid == 0.0 and not collide and _is_swept(p) and Vector2(p.x - site.x, p.z - site.z).length() > 1.7:
		swept_count += 1          # after the rng draws, so the rest of the keep is unchanged
		return
	_per[v].append([xf, Color(clampf(above / 8.0, 0.0, 1.0), _rng.randf(), laid, _aged)])
	block_count += 1
	if _aged > 0.0:
		aged_count += 1
	if collide and size.x > 0.4:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size.abs() * 0.96
		cs.shape = box
		cs.transform = Transform3D(b.orthonormalized(), p)
		_body.add_child(cs)

## A cut stone of size d: a subdivided box rounded off by BEVEL, its arrises and corners
## chipped with noise, faces slightly dished/bulged.
func _block_mesh(d: Vector3, v: int) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = seed + 50 + v
	n.frequency = 4.0
	n.fractal_octaves = 3
	var h := d * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var u_ax := (axis + 1) % 3
			var v_ax := (axis + 2) % 3
			var us := _ticks(h[u_ax])
			var vs := _ticks(h[v_ax])
			var grid := []
			var jg := {}   # shaped vertex -> joint colour of its unshaped grid point
			for iu in us.size():
				var row := []
				for iv in vs.size():
					var p := Vector3.ZERO
					p[axis] = h[axis] * sgn
					p[u_ax] = us[iu]
					p[v_ax] = vs[iv]
					var sp := _shape(p, h, n)
					jg[sp] = _joint(p, h)
					row.append(sp)
				grid.append(row)
			var fn := Vector3.ZERO
			fn[axis] = sgn
			for iu in us.size() - 1:
				for iv in vs.size() - 1:
					var a: Vector3 = grid[iu][iv]
					var b: Vector3 = grid[iu + 1][iv]
					var c: Vector3 = grid[iu + 1][iv + 1]
					var e: Vector3 = grid[iu][iv + 1]
					# Godot front faces wind clockwise seen from outside
					if (b - a).cross(c - a).dot(fn) > 0.0:
						for q in [a, c, b, a, e, c]:
							st.set_color(jg[q])
							st.add_vertex(q)
					else:
						for q in [a, b, c, a, c, e]:
							st.set_color(jg[q])
							st.add_vertex(q)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	if material:
		mesh.surface_set_material(0, material)
	return mesh

## Vertex colour r: how far a point lies from the stone's end and bed arrises (0 on the end
## and bed faces, 1 at >= 15 cm in on the face), so the shader can sink the joints into
## shadow. A function of position only, so the faces still share their arris vertices.
func _joint(q: Vector3, h: Vector3) -> Color:
	var d := minf(h.x - absf(q.x), h.y - absf(q.y))
	return Color(clampf(d / 0.15, 0.0, 1.0), 0, 0)

func _ticks(hh: float) -> PackedFloat32Array:
	# bevel rows plus interior rows every ~11 cm, so the chips along an arris are resolved
	var r := BEVEL
	var inner := hh - r
	var t := PackedFloat32Array([-hh, -hh + r * 0.4])
	var m := maxi(2, int(ceil(inner * 2.0 / 0.11)))
	for i in m + 1:
		t.append(lerpf(-inner, inner, float(i) / m))
	t.append_array(PackedFloat32Array([hh - r * 0.4, hh]))
	return t

func _shape(p: Vector3, h: Vector3, n: FastNoiseLite) -> Vector3:
	var inner := h - Vector3.ONE * BEVEL
	var q := p.clamp(-inner, inner)
	var dd := p - q
	var nrm: Vector3
	var edge := 0.0
	if dd.length() > 0.0001:
		nrm = dd.normalized()
		# on an arris or corner: two or three axes out of the inner box
		var outs := int(absf(dd.x) > 0.001) + int(absf(dd.y) > 0.001) + int(absf(dd.z) > 0.001)
		edge = 0.0 if outs < 2 else 1.0
		p = q + nrm * BEVEL
	else:
		nrm = p.normalized()
	# chips: ragged bites out of the arrises, a gentle bulge/dish over the faces
	var k := n.get_noise_3dv(p)
	# (low-frequency term: faces are hand-dressed, not machined flat)
	var bite := maxf(0.0, k + 0.1) * (0.1 * edge + 0.015) + maxf(0.0, n.get_noise_3dv(p * 0.6 + Vector3(4, 1, 8)) - 0.15) * 0.12 * edge + n.get_noise_3dv(p * 2.3 + Vector3(7, 3, 1)) * 0.012 \
		+ n.get_noise_3dv(p * 0.35 + Vector3(2, 9, 4)) * 0.03
	return p - nrm * bite

func _multimesh(mesh: Mesh, items: Array, nm: String) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
