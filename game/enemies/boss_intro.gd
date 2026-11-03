class_name BossIntro
extends Node3D
## The in-engine camera reveal a boss gets the first time the hero walks into its arena (owner
## rule 2026-11-03: "Intro: in-engine camera reveal, then the fight starts"). Reusable: any boss
## that calls `BossIntro.play(boss, hero)` and keeps itself out of the fight while
## `boss.intro_playing()` is true gets the same three shots:
##  1. CRANE (0 .. CRANE_T): a low camera at the giant's feet, off its shoulder, cranes up the
##     body and dollies back while the aim climbs from its feet to its helm.
##  2. ROAR (.. ROAR_END): held low, looking up; the boss does its own roar beat (the knight heaves
##     the glaive overhead with the ember flaring), the frame shakes.
##  3. HAND-OFF (.. T): the camera glides into the hero's own over-the-shoulder view, already
##     turned on the boss, and the hero's camera takes over. Then the bar comes up and it fights.
## The hero stands still while it plays (no input). Letterbox bars slide in and out; the frame
## has a shallow depth of field on the boss. Any attack/jump/interact press skips to the
## hand-off. Plays once per boss per run (a retry after a death goes straight to the fight).

const CRANE_T := 2.8
const ROAR_END := 4.0
const T := 4.9
const BARS := 0.11              # letterbox height, fraction of the screen per bar

signal finished(skipped: bool)

var boss: Node3D
var hero: Player
var t := 0.0
var skipped := false
var cam: Camera3D
var bars := 0.0                 # 0..1, the HUD draws the letterbox from it
var max_lift := 0.0             # bots: how far the crane climbed (m above the boss's feet)
var min_dist := INF             # bots: closest the lens came to the boss's axis
var _fwd := Vector3.FORWARD     # from the boss toward the hero, flat (fixed at the start)
var _side := Vector3.RIGHT
var _from: Transform3D          # the last intro frame, blended into the hero's camera
var _done := false

## Starts the reveal; returns the node (added under the boss's parent).
static func play(b: Node3D, h: Player) -> BossIntro:
	var i := BossIntro.new()
	i.name = "BossIntro"
	i.boss = b
	i.hero = h
	b.get_parent().add_child(i)
	return i

func _ready() -> void:
	add_to_group("cinematic")
	process_physics_priority = 100       # after the hero and the boss have moved this tick
	var to := hero.global_position - boss.global_position
	to.y = 0.0
	_fwd = to.normalized() if to.length() > 0.1 else Vector3.BACK
	_side = _fwd.cross(Vector3.UP).normalized()
	hero.cinematic = true
	# turn the hero's own camera onto the boss now, so the hand-off lands on the fight view
	hero._yaw = atan2(_fwd.x, _fwd.z)
	hero._pitch = -0.12
	cam = Camera3D.new()
	cam.name = "IntroCam"
	cam.fov = 50.0
	cam.near = 0.1
	cam.far = hero.camera.far
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_amount = 0.06
	cam.attributes = ca
	add_child(cam)
	_frame(0.0)
	cam.make_current()

func _size() -> float:
	var s = boss.get("size_scale")
	return float(s) if s != null else 1.0

## The boss's height (feet to crown) from its hurt capsule.
func _height() -> float:
	if boss.has_method("hurt_capsule"):
		var c: Array = boss.hurt_capsule()
		return maxf((c[1] as Vector3).y - boss.global_position.y + float(c[2]), 1.5)
	return 2.0 * _size()

## The camera for intro time `u` (seconds), as a transform.
func _shot(u: float) -> Transform3D:
	var s := _size()
	var h := _height()
	var feet := boss.global_position
	var c := smoothstep(0.0, CRANE_T, u)
	var r := clampf((u - CRANE_T) / (ROAR_END - CRANE_T), 0.0, 1.0)
	# off the boss's right shoulder on the hero's side, rising from ankle height to just under
	# the helm and pulling back so the whole giant is in frame by the roar
	var out := lerpf(1.25, 2.7, c) + 0.7 * r
	var pos := feet + _fwd * (out * s) + _side * (lerpf(0.55, 0.95, c) * s) + Vector3.UP * lerpf(0.12 * h, 0.5 * h, c)
	var aim := feet + Vector3.UP * lerpf(0.08 * h, 0.86 * h, c) - _side * (0.1 * s)
	var xf := Transform3D(Basis(), pos)
	return xf.looking_at(aim, Vector3.UP)

func _frame(u: float) -> void:
	var xf := _shot(minf(u, ROAR_END))
	if u > ROAR_END or skipped:
		var k := smoothstep(0.0, 1.0, clampf((u - ROAR_END) / (T - ROAR_END), 0.0, 1.0))
		var src := _from if skipped else xf
		var dst := hero.camera.global_transform
		xf = Transform3D(src.basis.slerp(dst.basis, k).orthonormalized(), src.origin.lerp(dst.origin, k))
		cam.fov = lerpf(50.0, hero.camera.fov, k)
	cam.global_transform = xf
	# roar shake (the boss's own shake goes to the hero's camera, which is not current)
	if u > CRANE_T + 0.3 and u < ROAR_END:
		var q := sin(PI * clampf((u - CRANE_T - 0.3) / (ROAR_END - CRANE_T - 0.3), 0.0, 1.0)) * 0.05 * sqrt(_size())
		cam.h_offset = q * sin(u * 61.0)
		cam.v_offset = q * sin(u * 79.0 + 1.3)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	var ca := cam.attributes as CameraAttributesPractical
	var focus := cam.global_position.distance_to(boss.global_position + Vector3.UP * 0.5 * _height())
	ca.dof_blur_far_distance = focus + 3.0 * _size()
	ca.dof_blur_far_transition = 6.0 * _size()
	ca.dof_blur_amount = 0.06 * (1.0 - clampf((u - ROAR_END) / (T - ROAR_END), 0.0, 1.0))
	var lift := cam.global_position.y - boss.global_position.y
	max_lift = maxf(max_lift, lift)
	var flat := cam.global_position - boss.global_position
	flat.y = 0.0
	min_dist = minf(min_dist, flat.length())

func is_playing() -> bool:
	return not _done

## Jumps to the hand-off (a press during the intro); the boss stops its roar beat.
func skip() -> void:
	if skipped or _done or t >= ROAR_END:
		return
	skipped = true
	_from = cam.global_transform
	t = ROAR_END

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(boss) or not is_instance_valid(hero):
		_finish()
		return
	if t > 0.4 and hero.cinematic_skip_pressed():
		skip()
	t += delta
	bars = smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(ROAR_END, T, t))
	_frame(t)
	if t >= T:
		_finish()

func _finish() -> void:
	_done = true
	bars = 0.0
	if is_instance_valid(hero):
		hero.cinematic = false
		hero.camera.make_current()
	finished.emit(skipped)
	queue_free()
