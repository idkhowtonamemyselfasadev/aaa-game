class_name Trample
extends Node
## Tracks the hero's footfalls and hands them to the plant shaders (trample.gdshaderinc):
## grass, wildflowers and ferns part round the legs and stay laid over along the trail,
## springing back over TRAMPLE_LIFE seconds.

const N := 32             # footfalls kept (oldest recycled): ~19 m of trail
const LIFE := 9.0         # s for a laid plant to stand up again (shader TRAMPLE_LIFE)
const STEP := 0.6        # m between trail points

var player: Node3D
var _pts: Array[Vector4] = []    # x, z, age, strength
var _dirs: Array[Vector2] = []
var _next := 0
var _dist := 0.0
var _last := Vector3.INF
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
	if _last == Vector3.INF:
		_last = p
	var mv := Vector2(p.x - _last.x, p.z - _last.z)
	_last = p
	for i in N:
		var r := _pts[i]
		if r.w > 0.0:
			r.z += delta
			if r.z > LIFE:
				r = Vector4.ZERO
			_pts[i] = r
	if grounded and mv.length() < 2.0:   # ignore teleports (respawn)
		_dist += mv.length()
		if _dist >= STEP:
			_dist = 0.0
			# a run tramples harder than a walk
			var sp := mv.length() / maxf(delta, 1e-4)
			_pts[_next] = Vector4(p.x, p.z, 0.0, lerpf(0.75, 1.0, clampf(sp / 6.0, 0.0, 1.0)))
			_dirs[_next] = mv.normalized()
			_next = (_next + 1) % N
	_upload()

func _upload() -> void:
	for i in N:
		var r := _pts[i]
		_img.set_pixel(i, 0, Color(r.x, r.y, r.z, r.w))
		_img.set_pixel(i, 1, Color(_dirs[i].x, _dirs[i].y, 0.0, 0.0))
	_tex.update(_img)

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
	frozen = true
	_upload()

## Trail points still laying plants over (bots).
func active_points() -> int:
	var n := 0
	for r in _pts:
		if r.w > 0.0:
			n += 1
	return n

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
		var rec := smoothstep(0.0, 0.08, a.z) * (1.0 - smoothstep(0.1, 1.0, a.z / LIFE))
		amt = maxf(amt, (1.0 - smoothstep(reach * 0.35, reach, d)) * rec * a.w)
	return clampf(amt, 0.0, 1.0)
