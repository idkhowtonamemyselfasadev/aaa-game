class_name Trample
extends Node
## Tracks the hero's footfalls and hands them to the plant shaders (trample.gdshaderinc):
## grass, wildflowers and ferns part round the legs and stay laid over along the trail,
## springing back over TRAMPLE_LIFE seconds. Every walker (the hero, the Hollows) also
## presses boot prints into the ground (terrain.gdshader): left, right, left along the walk,
## darker pressed soil that fills with water in the rain and fades over PRINT_LIFE seconds.
## The red deer (world/herd.gd) press cloven hoof slots into a buffer of their own
## (hoof_prints): paired walking slots, splayed and deeper where they galloped, and lay a
## trail of their own through the grass (herd_trail): a lane of combed-over stems where the
## herd ran, standing up again over HERD_TRAIL_LIFE seconds.

## A boot print was pressed: who, where (world, at the walker's height), ground speed m/s.
signal footfall(walker: Node3D, at: Vector3, speed: float)

const N := 32             # footfalls kept (oldest recycled): ~19 m of trail
const LIFE := 9.0         # s for a laid plant to stand up again (shader TRAMPLE_LIFE)
const STEP := 0.6        # m between trail points

const PN := 64            # boot prints kept (oldest recycled)
const PRINT_LIFE := 180.0 # s for a print to weather away
const STRIDE := 0.72      # m between prints (alternating feet)
const GAIT := 0.11        # m each foot sits off the walk line

const HN := 256           # hoof prints kept (the whole herd shares them)
const HOOF_LIFE := 150.0  # s for a hoof print to weather away (shader HOOF_LIFE)

const HTN := 64                 # herd trail points (shader HERD_TRAIL_N)
const HERD_TRAIL_LIFE := 30.0   # s for grass laid by the herd to stand up (shader)
const HERD_MERGE := 0.7         # m: a deer passing an existing point refreshes it instead

var player: Node3D
var walkers: Array[Node3D] = []   # besides the hero: soldiers etc. (trail + prints)
var _wstate := {}                 # walker -> [last pos, trail dist, print dist, foot parity]
var _prints: Array[Vector4] = []  # x, z, age, depth 0..1
var _pdirs: Array[Vector2] = []
var _pnext := 0
var _pimg: Image
var _ptex: ImageTexture
var _hoofs: Array[Vector4] = []  # x, z, age, depth 0..1
var _hdirs: Array[Vector4] = []  # toe dir x, z, splay 0..1, size (m, hoof length)
var _hnext := 0
var _himg: Image
var _htex: ImageTexture
var _hts: Array[Vector4] = []    # herd trail: x, z, age, strength
var _htd: Array[Vector2] = []
var _htnext := 0
var _htimg: Image
var _httex: ImageTexture
var _pts: Array[Vector4] = []    # x, z, age, strength
var _dirs: Array[Vector2] = []
var _next := 0
var frozen := false      # shots: keep a seeded trail as it is (no ageing, no new points)
var _img: Image
var _tex: ImageTexture

func _ready() -> void:
	for i in N:
		_pts.append(Vector4.ZERO)
		_dirs.append(Vector2.ZERO)
	_img = Image.create_empty(N, 2, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("trample_trail", _tex)
	for i in PN:
		_prints.append(Vector4.ZERO)
		_pdirs.append(Vector2.ZERO)
	_pimg = Image.create_empty(PN, 2, false, Image.FORMAT_RGBAF)
	_ptex = ImageTexture.create_from_image(_pimg)
	RenderingServer.global_shader_parameter_set("foot_prints", _ptex)
	for i in HN:
		_hoofs.append(Vector4.ZERO)
		_hdirs.append(Vector4.ZERO)
	_himg = Image.create_empty(HN, 2, false, Image.FORMAT_RGBAF)
	_htex = ImageTexture.create_from_image(_himg)
	RenderingServer.global_shader_parameter_set("hoof_prints", _htex)
	for i in HTN:
		_hts.append(Vector4.ZERO)
		_htd.append(Vector2.ZERO)
	_htimg = Image.create_empty(HTN, 2, false, Image.FORMAT_RGBAF)
	_httex = ImageTexture.create_from_image(_htimg)
	RenderingServer.global_shader_parameter_set("herd_trail", _httex)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		RenderingServer.global_shader_parameter_set("trample_body", Vector4.ZERO)
		return
	var p := player.global_position
	var grounded := true
	if player is CharacterBody3D:
		grounded = (player as CharacterBody3D).is_on_floor()
	RenderingServer.global_shader_parameter_set("trample_body", Vector4(p.x, p.y, p.z, 2.0 if grounded else 1.0))
	if frozen:
		_upload()
		return
	for i in N:
		var r := _pts[i]
		if r.w > 0.0:
			r.z += delta
			if r.z > LIFE:
				r = Vector4.ZERO
			_pts[i] = r
	for i in PN:
		var q := _prints[i]
		if q.w > 0.0:
			q.z += delta
			if q.z > PRINT_LIFE:
				q = Vector4.ZERO
			_prints[i] = q
	for i in HN:
		var h := _hoofs[i]
		if h.w > 0.0:
			h.z += delta
			if h.z > HOOF_LIFE:
				h = Vector4.ZERO
			_hoofs[i] = h
	for i in HTN:
		var t := _hts[i]
		if t.w > 0.0:
			t.z += delta
			if t.z > HERD_TRAIL_LIFE:
				t = Vector4.ZERO
			_hts[i] = t
	_walk(player, delta, grounded)
	for w in walkers:
		if is_instance_valid(w) and w.is_inside_tree() and w.is_visible_in_tree():
			_walk(w, delta, (w as CharacterBody3D).is_on_floor() if w is CharacterBody3D else true)
	_upload()

## Lay trail points and boot prints behind one walker.
func _walk(w: Node3D, delta: float, grounded: bool) -> void:
	var p := w.global_position
	if not _wstate.has(w):
		_wstate[w] = [p, 0.0, 0.0, 0]
	var st: Array = _wstate[w]
	var last: Vector3 = st[0]
	var mv := Vector2(p.x - last.x, p.z - last.z)
	st[0] = p
	# airborne, teleport, or no physics step this frame; a slow frame (long delta) can carry
	# a runner well past 2 m, so the teleport test is a speed no walker reaches (20 m/s)
	if not grounded or mv.length() >= maxf(2.0, 20.0 * delta) or mv.length() < 1e-5:
		return
	var sp := mv.length() / maxf(delta, 1e-4)
	if w is CharacterBody3D:   # physics steps and frames do not line up: use the body's speed
		var v := (w as CharacterBody3D).velocity
		sp = Vector2(v.x, v.z).length()
	var d := mv.normalized()
	var from := Vector2(last.x, last.z)
	var len := mv.length()
	# a slow frame can carry the walker several steps: lay every trail point and print
	# along the way, not one per frame
	var stride := STRIDE * lerpf(1.0, 1.5, clampf((sp - 2.0) / 4.0, 0.0, 1.0))
	var at := 0.0
	while true:
		var to_pt: float = STEP - st[1]
		var to_print: float = stride - st[2]
		var step := minf(to_pt, to_print)
		if at + step > len:
			break
		at += step
		st[1] += step
		st[2] += step
		var q := from + d * at
		if st[1] >= STEP - 1e-4:
			st[1] = 0.0
			# a run tramples harder than a walk
			_pts[_next] = Vector4(q.x, q.y, 0.0, lerpf(0.75, 1.0, clampf(sp / 6.0, 0.0, 1.0)))
			_dirs[_next] = d
			_next = (_next + 1) % N
		# a run lengthens the stride and digs the toe in deeper
		if st[2] >= stride - 1e-4:
			st[2] = 0.0
			st[3] = 1 - int(st[3])
			var side := Vector2(-d.y, d.x) * (GAIT if st[3] == 0 else -GAIT)
			add_print(q + side, d, lerpf(0.7, 1.0, clampf(sp / 6.0, 0.0, 1.0)), 0.0)
			footfall.emit(w, Vector3(q.x + side.x, p.y, q.y + side.y), sp)
	st[1] += len - at
	st[2] += len - at

## Press one boot print at `at` (heel to toe along `dir`).
func add_print(at: Vector2, dir: Vector2, depth: float, age: float) -> void:
	_prints[_pnext] = Vector4(at.x, at.y, age, depth)
	_pdirs[_pnext] = dir.normalized()
	_pnext = (_pnext + 1) % PN

## Press one cloven hoof print at `at`, toe along `dir`; `splay` 0 (walk) .. 1 (gallop:
## the claws spread and the dew claws print behind), `size` the hoof length in metres.
func add_hoof(at: Vector2, dir: Vector2, depth: float, splay: float, size: float, age := 0.0) -> void:
	var d := dir.normalized()
	_hoofs[_hnext] = Vector4(at.x, at.y, age, depth)
	_hdirs[_hnext] = Vector4(d.x, d.y, splay, size)
	_hnext = (_hnext + 1) % HN

## A deer runs through the grass at `at` heading `dir`: lay the stems over there. Deer of
## one herd run in each other's tracks, so a point near an existing one refreshes it (and
## keeps the stronger push) rather than spending a new slot: the 64 points then cover a
## whole fled herd's lane instead of a few metres per animal.
## `merge`: how near an existing point must be to be refreshed instead (a sitting animal
## passes a small one so its press lands under it, not on an old spot beside it).
func add_herd_point(at: Vector2, dir: Vector2, strength: float, age := 0.0, merge := HERD_MERGE) -> void:
	for i in HTN:
		var t := _hts[i]
		if t.w > 0.0 and Vector2(t.x - at.x, t.y - at.y).length() < merge:
			_hts[i] = Vector4(t.x, t.y, minf(t.z, age), maxf(t.w, strength))
			if t.z > age:
				_htd[i] = dir.normalized()
			return
	_hts[_htnext] = Vector4(at.x, at.y, age, strength)
	_htd[_htnext] = dir.normalized()
	_htnext = (_htnext + 1) % HTN

## A body thrown down onto the sward: lay the grass flat under it, from the heels at `feet`
## to the head a body's length along `dir` (the way it was thrown, so the stems lie combed
## along the slide), with the herd's long-lived points so it stays pressed while it lies
## there and stands up slowly after it has got up.
func add_body(feet: Vector3, dir: Vector3, length := 1.75) -> void:
	var d := Vector2(dir.x, dir.z)
	if d.length() < 1e-3:
		return
	d = d.normalized()
	var n := 5
	for i in n:
		var q := Vector2(feet.x, feet.z) + d * (length * (0.1 + 0.85 * float(i) / (n - 1)))
		add_herd_point(q, d, 1.0, 0.0, 0.2)

## Live herd trail points (bots).
func active_herd_points() -> int:
	var n := 0
	for t in _hts:
		if t.w > 0.0:
			n += 1
	return n

## How far (0..1) the herd's run lays a plant rooted at `at` over: CPU mirror of
## herd_lay() in the shader (bots).
func herd_lay_at(at: Vector3, reach := 0.85) -> float:
	var amt := 0.0
	for t in _hts:
		if t.w <= 0.0:
			continue
		var d := Vector2(at.x - t.x, at.z - t.y).length()
		if d > reach:
			continue
		var rec := smoothstep(0.0, 0.15, t.z) * (1.0 - smoothstep(0.35, 1.0, t.z / HERD_TRAIL_LIFE))
		amt = maxf(amt, (1.0 - smoothstep(reach * 0.3, reach, d)) * rec * t.w)
	return clampf(amt, 0.0, 1.0)

func active_hoofs() -> int:
	var n := 0
	for h in _hoofs:
		if h.w > 0.0:
			n += 1
	return n

## Nearest live hoof print to `at` within `r` m: (x, z, age, depth), or zero.
func hoof_near(at: Vector3, r := 1.0) -> Vector4:
	var best := Vector4.ZERO
	var bd := r
	for h in _hoofs:
		if h.w <= 0.0:
			continue
		var dd := Vector2(h.x - at.x, h.y - at.z).length()
		if dd < bd:
			bd = dd
			best = h
	return best

func _upload() -> void:
	for i in N:
		var r := _pts[i]
		_img.set_pixel(i, 0, Color(r.x, r.y, r.z, r.w))
		_img.set_pixel(i, 1, Color(_dirs[i].x, _dirs[i].y, 0.0, 0.0))
	_tex.update(_img)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in PN:
		var q := _prints[i]
		_pimg.set_pixel(i, 0, Color(q.x, q.y, q.z, q.w))
		_pimg.set_pixel(i, 1, Color(_pdirs[i].x, _pdirs[i].y, 0.0, 0.0))
		if q.w > 0.0:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	_ptex.update(_pimg)
	# bounds of the live prints (+ a boot length): the terrain skips the loop outside
	if lo.x == INF:
		RenderingServer.global_shader_parameter_set("foot_box", Vector4(1e9, 1e9, -1e9, -1e9))
	else:
		RenderingServer.global_shader_parameter_set("foot_box", Vector4(lo.x - 0.3, lo.y - 0.3, hi.x + 0.3, hi.y + 0.3))
	lo = Vector2(INF, INF)
	hi = Vector2(-INF, -INF)
	for i in HN:
		var h := _hoofs[i]
		var hd := _hdirs[i]
		_himg.set_pixel(i, 0, Color(h.x, h.y, h.z, h.w))
		_himg.set_pixel(i, 1, Color(hd.x, hd.y, hd.z, hd.w))
		if h.w > 0.0:
			lo = Vector2(minf(lo.x, h.x), minf(lo.y, h.y))
			hi = Vector2(maxf(hi.x, h.x), maxf(hi.y, h.y))
	_htex.update(_himg)
	if lo.x == INF:
		RenderingServer.global_shader_parameter_set("hoof_box", Vector4(1e9, 1e9, -1e9, -1e9))
	else:
		RenderingServer.global_shader_parameter_set("hoof_box", Vector4(lo.x - 0.2, lo.y - 0.2, hi.x + 0.2, hi.y + 0.2))
	lo = Vector2(INF, INF)
	hi = Vector2(-INF, -INF)
	for i in HTN:
		var t := _hts[i]
		_htimg.set_pixel(i, 0, Color(t.x, t.y, t.z, t.w))
		_htimg.set_pixel(i, 1, Color(_htd[i].x, _htd[i].y, 0.0, 0.0))
		if t.w > 0.0:
			lo = Vector2(minf(lo.x, t.x), minf(lo.y, t.y))
			hi = Vector2(maxf(hi.x, t.x), maxf(hi.y, t.y))
	_httex.update(_htimg)
	# + the widest plant reach (ferns 1.1 m)
	if lo.x == INF:
		RenderingServer.global_shader_parameter_set("herd_trail_box", Vector4(1e9, 1e9, -1e9, -1e9))
	else:
		RenderingServer.global_shader_parameter_set("herd_trail_box", Vector4(lo.x - 1.2, lo.y - 1.2, hi.x + 1.2, hi.y + 1.2))

## Lay a trail along `path` (oldest first) whose footfalls are `age_old`..`age_new` s old
## (shots: a trodden track through the grass without having to walk it in real time).
func seed_trail(path: PackedVector3Array, age_old: float, age_new: float) -> void:
	var pts: Array[Vector3] = []
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var n := maxi(1, int((b - a).length() / STEP))
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	pts.append(path[path.size() - 1])
	var first := maxi(0, pts.size() - N)
	for j in range(first, pts.size()):
		var u := float(j - first) / maxf(1.0, pts.size() - 1 - first)
		var q := pts[j]
		var nxt := pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)]
		_pts[_next] = Vector4(q.x, q.z, lerpf(age_old, age_new, u), 1.0)
		_dirs[_next] = Vector2(nxt.x, nxt.z).normalized()
		_next = (_next + 1) % N
	# boot prints along the same track, alternating feet
	var foot := 0
	var acc := 0.0
	for j in range(1, pts.size()):
		acc += (pts[j] - pts[j - 1]).length()
		if acc < STRIDE:
			continue
		acc = 0.0
		foot = 1 - foot
		var dd := Vector2(pts[j].x - pts[j - 1].x, pts[j].z - pts[j - 1].z).normalized()
		var u := float(j) / (pts.size() - 1)
		add_print(Vector2(pts[j].x, pts[j].z) + Vector2(-dd.y, dd.x) * (GAIT if foot == 0 else -GAIT), dd, 0.9, lerpf(age_old, age_new, u))
	frozen = true
	_upload()

## Trail points still laying plants over (bots).
func active_points() -> int:
	var n := 0
	for r in _pts:
		if r.w > 0.0:
			n += 1
	return n

## Boot prints still pressed in the ground (bots).
func active_prints() -> int:
	var n := 0
	for q in _prints:
		if q.w > 0.0:
			n += 1
	return n

## Nearest live print to `at` (bots): Vector4(x, z, age, depth), w 0 if none within `r`.
func print_near(at: Vector3, r := 1.0) -> Vector4:
	var best := Vector4.ZERO
	var bd := r
	for q in _prints:
		if q.w > 0.0:
			var d := Vector2(at.x - q.x, at.z - q.y).length()
			if d < bd:
				bd = d
				best = q
	return best

## How far (0..1) a plant rooted at `at` is laid over right now: CPU mirror of
## trample_lay() in the shader (bots).
func lay_at(at: Vector3, reach := 0.7) -> float:
	var amt := 0.0
	if player:
		var dh := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
		amt = 1.0 - smoothstep(0.2, reach + 0.25, dh.length())
	for i in N:
		var a := _pts[i]
		if a.w <= 0.0:
			continue
		var d := Vector2(at.x - a.x, at.z - a.y).length()
		if d > reach:
			continue
		var rec := smoothstep(0.0, 0.08, a.z) * (1.0 - smoothstep(0.3, 1.0, a.z / LIFE))
		amt = maxf(amt, (1.0 - smoothstep(reach * 0.35, reach, d)) * rec * a.w)
	return clampf(amt, 0.0, 1.0)
