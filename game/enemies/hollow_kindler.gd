class_name HollowKindler
extends HollowSoldier
## Hollow Kindler, the caster: a Hollow that was a hearth-priest. It still carries its spear,
## but it holds it up like a standard and fights through the others. Rule changes against
## the spear soldier:
##  HANGS BACK. While another Hollow is fighting the hero it keeps KEEP_MIN..KEEP_MAX m off,
##    behind its ally, walking backward when the hero comes for it (slower than the hero
##    runs: it can be caught).
##  KINDLE (the tell). It raises the spear point to the sky, its chest ember swells and a
##    stream of embers pours from it to the ally for CHANT_T. Finish the chant and the ally
##    is KINDLED for KINDLE_T s: its ember burns white-hot, sparks trail off it, it winds up
##    and strikes KINDLE_TEMPO times faster and hits KINDLE_DMG harder.
##  FRAIL CHANT. The chant is open: any blow breaks it (the stream gutters, it reels), so a
##    hero who reads the raised spear and closes in stops the kindling. Kill the Kindler and
##    every flame it lit gutters out at once.
##  ALONE. With no ally left to kindle (or crowded inside CROWD m) it fights with the spear
##    like a soldier, a little slower and weaker: fragile, a quick kill once reached.

const KINDLER_HP := 60.0
const KINDLER_POISE := 18.0
const KINDLE_MOVE := 2
const KINDLE_R := 15.0          # m: allies this near it can be kindled
const KEEP_MIN := 5.5           # closer than this (and not crowded) it backs away
const KEEP_MAX := 9.0           # farther than this it walks closer
const CROWD := 2.6              # inside this it gives up the chant and fights
const BACK_SPEED := 1.6
const CHANT_T := 1.7            # s of chant before the ally is kindled
const CHANT_RECOVER_T := 0.7
const CHANT_COOLDOWN := 4.0     # s between chants
const KINDLE_T := 12.0          # s an ally stays kindled
const STREAM_SPEED := 9.0       # m/s the ember stream flows to the ally

# spear held up like a standard, point to the sky, in front of the chest
const CHANT := [0.0, 84.0, Vector3(0.0, 1.85, 0.42), 0.0, 0.0, 0.5]

## the chant starts: point, the chest; ally is the Hollow it is kindling (foley: a low roar)
signal chant_started(point: Vector3, ally: HollowSoldier)
## the chant finished and the ally caught (foley: a fire whoomph)
signal kindled_ally(point: Vector3, ally: HollowSoldier)
## a blow broke the chant
signal chant_broken(point: Vector3)

var chants := 0
var kindles := 0
var chants_broken := 0
var backsteps := 0.0
var lit: Array[HollowSoldier] = []   # allies it kindled that still burn
var target: HollowSoldier            # the ally of the current chant
var _cool := 1.0
var _stream: CPUParticles3D
var _trail: MeshInstance3D   # a faint hot thread under the motes, so the stream reads as one ribbon
var _trail_a := 0.0
var sag_m := 0.0   # how far the thread hangs at its middle, metres (read by the bot)

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.0;
uniform vec4 hot : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// sag: world-down in the thread's local x/z (metres, set per frame); it hangs like a heavy
// rope of embers and wavers sideways, so it never reads as a laser line
uniform vec2 sag = vec2(0.0);
void vertex() {
	float t = 0.5 - VERTEX.y;              // 0 at the spear, 1 at the ally
	float arc = 4.0 * t * (1.0 - t);
	vec2 side = length(sag) > 0.001 ? normalize(vec2(-sag.y, sag.x)) : vec2(1.0, 0.0);
	float w = sin(t * 9.4 - TIME * 4.5) * 0.6 + sin(t * 17.0 + TIME * 2.3) * 0.4;
	VERTEX.xz += sag * arc + side * w * 0.05 * arc + sag * w * 0.15 * arc;
}
void fragment() {
	// UV.y runs the length (0 at the top = the Kindler's spear); clumps pour down it to the ally
	float along = UV.y;
	float flow = fract(along * 9.0 - TIME * 3.2);
	float clump = 0.55 + 0.45 * smoothstep(0.0, 0.25, flow) * (1.0 - smoothstep(0.45, 1.0, flow));
	// soft round edge: brightest where the side faces the eye
	float rim = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float ends = smoothstep(0.0, 0.08, along) * smoothstep(1.0, 0.85, along);
	ALBEDO = hot.rgb * 1.6;
	ALPHA = strength * clump * rim * ends * 0.4;   // (0.55 read as a laser line in the 16.5 GL frame)
}
"""

func _ready() -> void:
	health_max = KINDLER_HP
	health = KINDLER_HP
	poise_max = KINDLER_POISE
	engage_delay = 0.45
	notice = 14.0
	super._ready()
	name = "HollowKindler"
	# a darker, soot-black ash and a rust-red priest's hood: it reads apart from the soldiers
	_set_skin("ash_light", Color(0.27, 0.25, 0.24))
	rags.set_param("cloth_dark", Color(0.08, 0.025, 0.015))
	rags.set_param("cloth_light", Color(0.33, 0.12, 0.07))
	_ember_light.omni_range = 3.2
	_stream = CPUParticles3D.new()
	_stream.name = "EmberStream"
	_stream.top_level = true
	_stream.amount = 120
	_stream.lifetime = 1.0
	_stream.emitting = false
	_stream.local_coords = false
	_stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_stream.emission_sphere_radius = 0.06   # (0.12 + spread 6 scattered it into loose sparks on screen)
	_stream.spread = 3.0
	_stream.gravity = Vector3(0, 0.6, 0)
	_stream.scale_amount_min = 0.5
	_stream.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)   # (0.07 vanished past 6 m; the stream is the tell to break)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = AshFlame._soft_texture()
	q.material = m
	_stream.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.5, 0.0))
	g.set_color(1, Color(0.9, 0.25, 0.03, 0.0))
	g.add_point(0.12, Color(1.0, 0.7, 0.3, 1.0))
	g.add_point(0.8, Color(1.0, 0.4, 0.08, 0.8))
	_stream.color_ramp = g
	add_child(_stream)
	_trail = MeshInstance3D.new()
	_trail.name = "EmberTrail"
	_trail.top_level = true
	var cy := CylinderMesh.new()
	cy.top_radius = 0.022
	cy.bottom_radius = 0.022
	cy.height = 1.0
	cy.radial_segments = 6
	cy.rings = 18   # enough segments for the sag + waver to bend smoothly
	cy.cap_top = false
	cy.cap_bottom = false
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TRAIL_SHADER
	sm.shader = sh
	cy.material = sm
	_trail.mesh = cy
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.visible = false
	add_child(_trail)

func return_to_post() -> void:
	super.return_to_post()
	_stop_stream()
	target = null
	_cool = 1.0

func chanting() -> bool:
	return state == WINDUP and move_kind == KINDLE_MOVE

## A living Hollow (not a statue, a boss or another Kindler) fighting the hero within
## KINDLE_R that is not already burning; the nearest, or null.
func pick_ally() -> HollowSoldier:
	var best: HollowSoldier = null
	var bd := KINDLE_R
	for n in get_tree().get_nodes_in_group("enemy"):
		var s := n as HollowSoldier
		if s == null or s == self or s is HollowKindler or s is AshenKnight or s is StoneSentinel:
			continue
		if s.is_dead() or s.kindled > 2.0 or not s.can_process():
			continue
		if not (s.state in [STALK, WINDUP, STRIKE, RECOVER, STAGGER]):
			continue
		var d := s.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = s
	return best

func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	for i in range(lit.size() - 1, -1, -1):
		if not is_instance_valid(lit[i]) or lit[i].kindled <= 0.0:
			lit.remove_at(i)
	super._physics_process(delta)
	if chanting() and target != null and is_instance_valid(target):
		# the stream pours from the raised spear's point, not the chest (11-03 frame: from the
		# chest it read as a beam out of the body, the spear an unrelated prop)
		var from := spear_tip()
		var to_c := target.global_position + Vector3.UP * 1.25
		var d := to_c - from
		_stream.global_position = from
		# the motes fall along the same hanging arc as the thread: they dip sag metres below
		# the straight line at mid-flight and still land on the ally
		var fly := clampf(d.length() / STREAM_SPEED, 0.15, 2.0)
		var g := 8.0 * clampf(d.length() * 0.05, 0.05, 0.45) / (fly * fly)
		# (11-03: launched UP against a DOWN pull the path bulged sag metres ABOVE the line,
		# motes flying over the hanging thread; a hanging arc is the opposite: a pull UP and a
		# launch dipped down by g*T/2, so mid-flight they sit sag metres below the line)
		var v := d / fly - Vector3.UP * g * fly * 0.5
		_stream.gravity = Vector3.UP * g
		_stream.direction = v.normalized()
		_stream.initial_velocity_min = v.length() * 0.97
		_stream.initial_velocity_max = v.length() * 1.03
		_stream.lifetime = fly
		_stream.emitting = clampf(t / CHANT_T, 0.0, 1.0) > 0.15
		_place_trail(from, to_c, smoothstep(0.15, 0.5, clampf(t / CHANT_T, 0.0, 1.0)))
	elif _trail != null and _trail.visible:
		_trail_a = maxf(_trail_a - delta * 4.0, 0.0)
		(_trail.mesh.material as ShaderMaterial).set_shader_parameter("strength", _trail_a)
		_trail.visible = _trail_a > 0.0

## world position of the spear point (falls back to above the chest if the spear is gone)
func spear_tip() -> Vector3:
	if spear != null and is_instance_valid(spear) and spear.get_parent() == _wield:
		return spear.to_global(spear.tip_local())
	return global_position + Vector3.UP * 1.3 + body.global_basis.z * 0.35

## stretch the thread from the spear (top) to the ally's chest (bottom); a = 0..1 strength
func _place_trail(from: Vector3, to_c: Vector3, a: float) -> void:
	var d := to_c - from
	var l := d.length()
	if l < 0.05:
		return
	var y := -d / l    # cylinder +Y points back up the stream to the spear
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_trail.global_transform = Transform3D(Basis(x, y * l, z), from.lerp(to_c, 0.5))
	_trail_a = a
	var mat := _trail.mesh.material as ShaderMaterial
	# hangs ~5 % of its length (a 6 m pour dips ~0.3 m), in the thread's local x/z
	sag_m = clampf(l * 0.05, 0.05, 0.45)
	mat.set_shader_parameter("sag", Vector2(x.dot(Vector3.DOWN), z.dot(Vector3.DOWN)) * sag_m)
	mat.set_shader_parameter("strength", a)
	_trail.visible = a > 0.0

func _stalk(to: Vector3, dist: float) -> Vector3:
	var ally := pick_ally() if dist > CROWD else null
	if ally == null:
		return super._stalk(to, dist)
	if _cool <= 0.0 and dist < KEEP_MAX + 2.0:
		target = ally
		windups += 1
		chants += 1
		_from = _pose
		move_kind = KINDLE_MOVE
		_enter(WINDUP)
		chant_started.emit(global_position + Vector3.UP * 1.3, ally)
		return Vector3.ZERO
	if dist < KEEP_MIN:
		backsteps += BACK_SPEED * get_physics_process_delta_time()
		return -to.normalized() * BACK_SPEED
	if dist > KEEP_MAX:
		return to.normalized() * STALK_SPEED * 0.8
	return Vector3.ZERO

func _special_tick(delta: float, to: Vector3, _dist: float) -> Array:
	match state:
		WINDUP:
			var u := clampf(t / CHANT_T, 0.0, 1.0)
			if target == null or not is_instance_valid(target) or target.is_dead():
				_stop_stream()
				_cool = 1.0
				_from = _pose
				_enter(RECOVER)
				return [Vector3.ZERO, 0.0, 0.0, 1.5]
			var ad := target.global_position - global_position
			ad.y = 0.0
			_turn_to(ad, delta, 5.0)
			_pose = _lerp_pose(_from, CHANT, minf(u * 3.0, 1.0))
			# a slow tremble of the raised spear as the chant builds
			_pose[0] = float(_pose[0]) + sin(t * 31.0) * 2.0 * smoothstep(0.3, 1.0, u)
			if u >= 1.0:
				kindles += 1
				target.kindle(KINDLE_T)
				if not lit.has(target):
					lit.append(target)
				kindled_ally.emit(target.global_position + Vector3.UP * 1.25, target)
				_stop_stream()
				_cool = CHANT_COOLDOWN
				_from = _pose
				_enter(RECOVER)
			return [Vector3.ZERO, -0.08 * smoothstep(0.0, 0.5, u), 0.0, 1.0 + 4.0 * smoothstep(0.1, 1.0, u)]
		RECOVER:
			var u := clampf(t / CHANT_RECOVER_T, 0.0, 1.0)
			_pose = _lerp_pose(_from, guard_pose, u)
			if u >= 1.0:
				target = null
				_enter(STALK)
			return [Vector3.ZERO, -0.08 * (1.0 - u), 0.0, 2.5 - 1.5 * u]
	_enter(STALK)
	return [Vector3.ZERO, 0.0, 0.0, 1.0]

func take_hit(point: Vector3, dir: Vector3, power: float, hitstop: float) -> void:
	if chanting():
		# the chant is open: any blow breaks it and the Kindler reels
		chants_broken += 1
		_stop_stream()
		_cool = CHANT_COOLDOWN * 0.5
		target = null
		chant_broken.emit(global_position + Vector3.UP * 1.3)
		_enter(STALK)
		poise = poise_max
	super.take_hit(point, dir, power, hitstop)

func _die(dir: Vector3) -> void:
	_stop_stream()
	# every flame it lit gutters out with it
	for s in lit:
		if is_instance_valid(s):
			s.douse()
	lit.clear()
	super._die(dir)

func _stop_stream() -> void:
	if _stream:
		_stream.emitting = false
