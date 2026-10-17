class_name Hearth
extends Node3D
## Hesper's cookfire on the keep floor beside her bed (Keeper.hearth_at): a ring of sooted
## fieldstones round an ash bed, four oak deadwood logs from her basket laid in a star with
## their charred ends meeting in the middle. Kept by the clock: she lights it as the light
## goes (~19:30), it blazes through the evening, burns down to a low fire while she dozes and
## to embers by dawn, cold ash and a last smoke wisp through the morning. Burning, it throws
## flickering warm light and soft shadows round the keep, flames lick up off the logs,
## sparks rise and drift, smoke leans with the wind, the logs crackle and pop, and moths come
## in out of the dark to circle it. Rain knocks the flames down and thickens the smoke.
## Bots read `level`, `light`, `flames`, `moth_positions()`, `crackle`, `flint_sounds`,
## `blow_sounds`.

const RING_R := 0.36
const LOGS := 4
const MOTHS := 9

var world: Node3D
var weather: Weather
var terrain: Terrain
var level := 0.0                # 0 cold .. 1 blazing (bots)
var light: OmniLight3D
var bounce: OmniLight3D          # the glow off the ash bed and hot stones, low and unshadowed
var flames: CPUParticles3D
var sparks: CPUParticles3D
var smoke: CPUParticles3D
var crackle: AudioStreamPlayer3D
var flint: AudioStreamPlayer3D   # the steel's click and scrape on each strike
var blow: AudioStreamPlayer3D    # her breath into the smouldering tinder, and the soft whump as it takes
var flint_sounds := 0           # (bots)
var blow_sounds := 0            # (bots)
var _mat: Array[ShaderMaterial] = []
var _moth_mm: MultiMesh
var _moths: Array = []          # [phase, radius, height, speed, dive phase, flap rate]
var _moth_on := 0.0
var _flick := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var strike: CPUParticles3D       # flint sparks into the tinder while Hesper kneels to light it
var strikes := 0                # (bots)
var flame_gain := 1.0           # flame brightness (dimmed while the tinder is young; bots)
var kindled := -1.0             # s since Hesper put flame to the tinder tonight (-1: not yet)
const KINDLE_RAMP := 22.0       # s from the first smoke to a full blaze once she has lit it

## Fire level by the hour: lit at dusk, blazing in the evening, burning down overnight.
## Hesper lights it herself at dusk (`kindle`); if she has not by 20:24 (sheltering, or the
## hero was away) it catches by the clock.
static func level_for(h: float) -> float:
	if h >= 19.5 and h < 20.4:
		return 0.0
	if h >= 20.4 and h < 20.9:
		return smoothstep(20.4, 20.9, h)
	if h >= 20.9 and h < 23.0:
		return 1.0
	if h >= 23.0 or h < 5.5:
		var x := fposmod(h - 23.0, 24.0) / 6.5
		return lerpf(1.0, 0.3, x)
	if h < 7.0:
		return lerpf(0.3, 0.08, (h - 5.5) / 1.5)
	if h < 9.5:
		return lerpf(0.08, 0.0, (h - 7.0) / 2.5)
	return 0.0

func setup(w: Node3D, at: Vector3) -> void:
	world = w
	weather = w.get("weather")
	terrain = w.get_node("Terrain")
	name = "Hearth"
	_rng.seed = 5519
	_flick.seed = 77
	_flick.frequency = 2.2
	_flick.fractal_octaves = 3
	position = Vector3(at.x, terrain.height_at(at.x, at.z), at.z)
	w.add_child(self)
	for p in 3:
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/hearth.gdshader")
		m.set_shader_parameter("part", p)
		m.set_shader_parameter("centre", global_position)
		m.set_shader_parameter("ring_r", RING_R)
		_mat.append(m)
	_build_bed()
	_build_stones()
	_build_logs()
	_build_fire()
	_build_moths()
	_build_sound()
	_build_strike_sounds()
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RING_R + 0.1
	cyl.height = 0.4
	cs.shape = cyl
	body.add_child(cs)
	add_child(body)
	_apply(level_for(_hour()), 0.0)

func _hour() -> float:
	return world.time_of_day if world != null else 12.0

func _ground(x: float, z: float) -> float:
	# local height of the floor under a local (x, z)
	return terrain.height_at(global_position.x + x, global_position.z + z) - global_position.y

# ---------------------------------------------------------------- build

## Ash bed: a low dome of ash inside the ring, sinking under the floor at a ragged rim.
func _build_bed() -> void:
	var n := FastNoiseLite.new()
	n.seed = 41
	n.frequency = 3.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 28
	const RINGS := 7
	var pts := []
	for i in RINGS + 1:
		var row := []
		var t := float(i) / RINGS
		for k in SEG:
			var a := TAU * k / SEG
			var rr := RING_R * 1.55 * t * (1.0 + n.get_noise_1d(a * 3.0) * 0.25 * t)
			var x := cos(a) * rr
			var z := sin(a) * rr
			var dome := 0.035 * (1.0 - smoothstep(0.0, 0.75, t)) + 0.012
			var y := _ground(x, z) + dome - (0.03 if i == RINGS else 0.0)
			row.append(Vector3(x, y, z))
		pts.append(row)
	for i in RINGS:
		for k in SEG:
			var k2 := (k + 1) % SEG
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][k2]
			var c: Vector3 = pts[i + 1][k]
			var d: Vector3 = pts[i + 1][k2]
			for v in [a, d, b, a, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "AshBed"
	mi.mesh = st.commit()
	mi.material_override = _mat[2]
	add_child(mi)

## Ring stones: flattish weathered fieldstones set a third into the floor.
func _build_stones() -> void:
	var flora := world.get_node("Flora") as Flora
	var ico: Array = flora._icosphere(2)
	var n := FastNoiseLite.new()
	n.seed = 9
	n.frequency = 1.4
	var count := 10
	for i in count:
		var a := TAU * (i + _rng.randf_range(-0.2, 0.2)) / count
		var s := _rng.randf_range(0.1, 0.15)
		var rr := RING_R + s * 0.35 + _rng.randf_range(-0.02, 0.03)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var off := Vector3(_rng.randf() * 10.0, i * 3.1, 0)
		var out := PackedVector3Array()
		for p: Vector3 in ico[0]:
			var q := p * (1.0 + n.get_noise_3dv(p + off) * 0.3)
			if q.y < -0.35:
				q.y = -0.35 + (q.y + 0.35) * 0.3
			out.append(q)
		for t in ico[1]:
			st.add_vertex(out[t])
		st.index()
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mat[0]
		var x := cos(a) * rr
		var z := sin(a) * rr
		var b := Basis(Vector3.UP, -a + _rng.randf_range(-0.4, 0.4))
		b = b * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.15, 0.15))
		mi.transform = Transform3D(b.scaled(Vector3(s * _rng.randf_range(0.9, 1.3), s * _rng.randf_range(0.55, 0.75), s)), Vector3(x, _ground(x, z) + s * 0.18, z))
		add_child(mi)

## Four oak logs in a star, charred ends meeting over the middle; a split one among them,
## and charcoal crumbs fallen into the ash.
func _build_logs() -> void:
	var n := FastNoiseLite.new()
	n.seed = 3
	n.frequency = 6.0
	var a0 := _rng.randf() * TAU
	for i in LOGS:
		var a := a0 + TAU * i / LOGS + _rng.randf_range(-0.25, 0.25)
		var ln := _rng.randf_range(0.5, 0.68)
		var r0 := _rng.randf_range(0.035, 0.055)
		var split := i == 1
		var mesh := _log_mesh(ln, r0, split, n, float(i) * 5.0)
		var dir := Vector3(cos(a), 0, sin(a))
		var inner := dir * _rng.randf_range(0.02, 0.07)
		var outer := dir * (inner.length() + ln * 0.97)
		inner.y = _ground(inner.x, inner.z) + 0.045
		outer.y = maxf(_ground(outer.x, outer.z) + r0, 0.12 + r0)   # rests over the ring stone
		var y := (outer - inner).normalized()
		var x := y.cross(Vector3.UP).normalized()
		var z := x.cross(y)
		var mi := MeshInstance3D.new()
		mi.name = "Log%d" % i
		mi.mesh = mesh
		mi.material_override = _mat[1]
		mi.transform = Transform3D(Basis(x, y, z) * Basis(Vector3.UP, _rng.randf() * TAU), inner)
		add_child(mi)
	# charcoal crumbs
	var flora := world.get_node("Flora") as Flora
	var ico: Array = flora._icosphere(1)
	for k in 9:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in ico[1]:
			var p: Vector3 = ico[0][t]
			st.add_vertex(p * (1.0 + n.get_noise_3dv(p * 0.3 + Vector3(k, 0, 0)) * 0.4))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mat[1]
		var a := _rng.randf() * TAU
		var rr := _rng.randf_range(0.03, RING_R * 0.85)
		var s := _rng.randf_range(0.012, 0.028)
		var x := cos(a) * rr
		var z := sin(a) * rr
		mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 1.4, s * 0.7, s)), Vector3(x, _ground(x, z) + 0.035, z))
		add_child(mi)

## A log along local +y from its burnt end (0, tapering to a charred point) to its sawn
## outer end; `split` flattens one side into a riven face (COLOR.r = 1 there).
func _log_mesh(ln: float, r0: float, split: bool, n: FastNoiseLite, off: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 10
	var rows := int(ln / 0.03) + 1
	var grid := []
	var cols := []
	for j in rows + 1:
		var v := float(j) / rows
		var along := v * ln
		var taper := lerpf(0.35, 1.0, smoothstep(0.0, 0.16, along))
		var row := []
		var crow := []
		for k in SIDES + 1:
			var th := TAU * k / SIDES
			var c := Vector2(cos(th), sin(th))
			var face := 0.0
			if split and c.y < -0.2:
				c.y = -0.2
				face = 1.0
			var rr := r0 * taper * (1.0 + n.get_noise_2d(th * 2.0 + off, along * 8.0) * 0.12)
			row.append(Vector3(c.x * rr, along, c.y * rr))
			crow.append(face)
		grid.append(row)
		cols.append(crow)
	for j in rows:
		for k in SIDES:
			var q := [[j, k], [j, k + 1], [j + 1, k + 1], [j, k], [j + 1, k + 1], [j + 1, k]]
			for e in q:
				st.set_color(Color(cols[e[0]][e[1]], 0, 0))
				st.add_vertex(grid[e[0]][e[1]])
	# end caps: the sawn outer end shows its grain (split-face colour), the burnt end a char point
	for cap in [0, rows]:
		var mid := Vector3(0, grid[cap][0].y, 0)
		for k in SIDES:
			var a: Vector3 = grid[cap][k]
			var b: Vector3 = grid[cap][k + 1]
			st.set_color(Color(1.0 if cap == rows else 0.0, 0, 0))
			if cap == 0:
				st.add_vertex(mid); st.add_vertex(b); st.add_vertex(a)
			else:
				st.add_vertex(mid); st.add_vertex(a); st.add_vertex(b)
	st.generate_normals()
	return st.commit()

func _flame_tex() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 12
	n.frequency = 0.09
	var w := 64
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := 1.0 - float(y) / (h - 1)          # 0 at the bottom
		var half := 0.85 * pow(sin(PI * pow(v, 0.55)), 0.9) * (1.0 - v * 0.35)
		for x in w:
			var u := (float(x) / (w - 1)) * 2.0 - 1.0
			u += n.get_noise_2d(x * 0.6, y * 0.5) * 0.25 * v
			var e := 1.0 - smoothstep(half * 0.45, half + 0.02, absf(u))
			var core := (1.0 - smoothstep(0.0, half * 0.6 + 0.01, absf(u))) * (1.0 - smoothstep(0.1, 0.6, v))
			var a := e * smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.75, 1.0, v))
			var b := clampf(0.55 + core * 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(b, b, b, a))
	return ImageTexture.create_from_image(img)

func _puff_tex() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 31
	n.frequency = 0.07
	n.fractal_octaves = 4
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5)
			var a := (1.0 - smoothstep(0.2, 1.0, d)) * clampf(0.55 + n.get_noise_2d(x, y) * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _build_fire() -> void:
	# flames: tongues licking up off the log ends, white-gold at the root, red at the tips
	flames = CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 56
	flames.lifetime = 0.7
	flames.local_coords = false
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(0.14, 0.02, 0.14)
	flames.direction = Vector3.UP
	flames.spread = 10.0
	flames.initial_velocity_min = 0.35
	flames.initial_velocity_max = 0.8
	flames.gravity = Vector3(0, 1.1, 0)
	flames.damping_min = 0.3
	flames.damping_max = 0.8
	flames.scale_amount_min = 0.65
	flames.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.55))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1.0, 0.25))
	flames.scale_amount_curve = sc
	var fg := Gradient.new()
	fg.set_color(0, Color(3.2, 2.2, 1.0, 0.0))
	fg.set_color(1, Color(1.2, 0.15, 0.02, 0.0))
	fg.add_point(0.08, Color(3.4, 2.1, 0.8, 0.9))
	fg.add_point(0.4, Color(2.6, 1.0, 0.2, 0.75))
	fg.add_point(0.75, Color(1.6, 0.35, 0.05, 0.35))
	flames.color_ramp = fg
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.46)
	q.center_offset = Vector3(0, 0.16, 0)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fm.billboard_keep_scale = true
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = _flame_tex()
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.disable_receive_shadows = true
	q.material = fm
	flames.mesh = q
	flames.position = Vector3(0, 0.06, 0)
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flames)
	# sparks rising off the fire, wandering as they cool
	sparks = CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 14
	sparks.lifetime = 1.8
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.1
	sparks.direction = Vector3.UP
	sparks.spread = 28.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.2
	sparks.gravity = Vector3(0, 0.3, 0)
	sparks.damping_min = 0.6
	sparks.damping_max = 1.4
	sparks.tangential_accel_min = -0.6
	sparks.tangential_accel_max = 0.6
	var sg := Gradient.new()
	sg.set_color(0, Color(4.0, 2.4, 0.8, 1.0))
	sg.set_color(1, Color(1.2, 0.2, 0.02, 0.0))
	sparks.color_ramp = sg
	var sq := QuadMesh.new()
	sq.size = Vector2(0.008, 0.008)
	var sm := fm.duplicate() as StandardMaterial3D
	sm.albedo_texture = null
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = sm
	sparks.mesh = sq
	sparks.position = Vector3(0, 0.15, 0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	# flint sparks: a short hot spray off the steel down into the tinder at the log ends
	strike = sparks.duplicate() as CPUParticles3D
	strike.name = "Strike"
	strike.amount = 10
	strike.lifetime = 0.45
	strike.one_shot = true
	strike.explosiveness = 0.9
	strike.emitting = false
	strike.emission_sphere_radius = 0.03
	strike.direction = Vector3.DOWN
	strike.spread = 55.0
	strike.initial_velocity_min = 0.6
	strike.initial_velocity_max = 1.6
	strike.gravity = Vector3(0, -4.0, 0)
	strike.position = Vector3(0, 0.16, 0)
	add_child(strike)
	# smoke: a soft grey column leaning off with the wind, spreading as it climbs
	smoke = CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 28
	smoke.lifetime = 6.0
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.08
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0.12, 0.15, 0.09)
	smoke.damping_min = 0.05
	smoke.damping_max = 0.15
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.angular_velocity_min = -12.0
	smoke.angular_velocity_max = 12.0
	var gc := Curve.new()
	gc.add_point(Vector2(0.0, 0.25))
	gc.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = gc
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 1.6
	var mg := Gradient.new()
	mg.set_color(0, Color(0.42, 0.4, 0.38, 0.0))
	mg.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	mg.add_point(0.12, Color(0.4, 0.38, 0.36, 0.32))
	mg.add_point(0.55, Color(0.46, 0.45, 0.44, 0.16))
	smoke.color_ramp = mg
	var pq := QuadMesh.new()
	pq.size = Vector2(0.7, 0.7)
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = _puff_tex()
	pm.roughness = 1.0
	pm.proximity_fade_enabled = true
	pm.proximity_fade_distance = 0.4
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pq.material = pm
	smoke.mesh = pq
	smoke.position = Vector3(0, 0.4, 0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.5, 0.2)
	light.omni_range = 8.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = true
	light.light_size = 0.12
	light.light_specular = 0.4
	light.position = Vector3(0, 0.7, 0)
	add_child(light)
	# the ring stones and logs shadow the main light off anyone knelt close; this soft glow
	# off the embers and the inside of the ring wraps her front, knees and hands instead
	bounce = OmniLight3D.new()
	bounce.name = "FireBounce"
	bounce.light_color = Color(1.0, 0.45, 0.18)
	bounce.omni_range = 2.6
	bounce.omni_attenuation = 1.3
	bounce.shadow_enabled = false
	bounce.light_specular = 0.1
	bounce.position = Vector3(0, 0.3, 0)
	add_child(bounce)

## Moths: small dusty wings circling the flame, darting in and swerving out.
func _build_moths() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# one forewing+hindwing outline from the hinge (x = 0) out along +x, in the xz plane
	var outline := [Vector3(0, 0, 0.004), Vector3(0.008, 0, 0.012), Vector3(0.019, 0, 0.009), Vector3(0.022, 0, 0.002), Vector3(0.016, 0, -0.008), Vector3(0.007, 0, -0.011), Vector3(0, 0, -0.006)]
	for i in range(1, outline.size() - 1):
		st.set_normal(Vector3.UP)
		st.add_vertex(outline[0]); st.add_vertex(outline[i]); st.add_vertex(outline[i + 1])
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.5, 0.43, 0.33)
	mm.roughness = 1.0
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.backlight_enabled = true
	mm.backlight = Color(0.55, 0.36, 0.2)
	var mesh := st.commit()
	mesh.surface_set_material(0, mm)
	_moth_mm = MultiMesh.new()
	_moth_mm.transform_format = MultiMesh.TRANSFORM_3D
	_moth_mm.mesh = mesh
	_moth_mm.instance_count = MOTHS * 2
	var mi := MultiMeshInstance3D.new()
	mi.name = "Moths"
	mi.multimesh = _moth_mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	for i in MOTHS:
		_moths.append([_rng.randf() * TAU, _rng.randf_range(0.3, 0.9), _rng.randf_range(0.5, 1.4),
			_rng.randf_range(1.6, 3.4) * (1.0 if _rng.randf() < 0.5 else -1.0), _rng.randf() * TAU, _rng.randf_range(24.0, 34.0)])

func moth_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _moth_on < 0.5:
		return out
	for i in MOTHS:
		out.append(_moth_at(i, _t))
	return out

func _moth_at(i: int, t: float) -> Vector3:
	var m: Array = _moths[i]
	var a: float = m[0] + t * m[3]
	# every few seconds it darts in at the flame and swerves back out
	var dive := pow(maxf(sin(t * 0.9 + m[4]), 0.0), 6.0)
	var r: float = m[1] * (1.0 - dive * 0.75) + sin(t * 3.7 + m[4]) * 0.06
	var h: float = m[2] - dive * 0.3 + sin(t * 2.3 + m[0]) * 0.12
	var j := Vector3(sin(t * 11.0 + m[4] * 3.0), sin(t * 13.0 + m[0]), cos(t * 9.0 + m[4])) * 0.025
	return global_position + Vector3(cos(a) * r, h + 0.2, sin(a) * r) + j

# ---------------------------------------------------------------- sound

func _build_sound() -> void:
	const RATE := 22050
	var n := RATE * 5
	var x := PackedFloat32Array()
	x.resize(n)
	var lp := 0.0
	var br := 0.0
	# a low breathing roar of the draught under everything
	for i in n:
		br = clampf(br + (_rng.randf() * 2.0 - 1.0) * 0.02, -1.0, 1.0)
		lp += (br - lp) * 0.05
		x[i] = lp * 0.5 * (0.8 + 0.2 * sin(TAU * i / n * 3.0))
	# crackles and pops: short noise bursts, a few big snaps of sap among many small ticks
	var t := 0
	while t < n:
		t += int(_rng.randf_range(0.01, 0.14) * RATE)
		if t >= n:
			break
		var amp := pow(_rng.randf(), 2.5) * (3.0 if _rng.randf() < 0.07 else 1.0)
		var dur := int(RATE * _rng.randf_range(0.002, 0.012) * (2.0 if amp > 1.0 else 1.0))
		var prev := 0.0
		for k in dur * 4:
			var e := exp(-float(k) / dur * 1.6)
			var w := _rng.randf() * 2.0 - 1.0
			var i := (t + k) % n
			x[i] += (w - prev * 0.6) * e * amp     # a little highpass: bright ticks
			prev = w
	var fade := RATE / 4
	var m := n - fade
	for i in fade:
		var k := float(i) / fade
		x[i] = x[i] * k + x[m + i] * (1.0 - k)
	var peak := 0.0001
	for i in m:
		peak = maxf(peak, absf(x[i]))
	var b := PackedByteArray()
	b.resize(m * 2)
	for i in m:
		b.encode_s16(i * 2, int(clampf(x[i] / peak * 0.89, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = b
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = m
	crackle = AudioStreamPlayer3D.new()
	crackle.name = "Crackle"
	crackle.stream = s
	crackle.bus = &"SFX"
	crackle.unit_size = 2.5
	crackle.max_distance = 35.0
	crackle.position = Vector3(0, 0.2, 0)
	crackle.volume_db = -80.0
	add_child(crackle)

## A one-shot 16-bit WAV from float samples, normalised to `gain`.
static func _wav(x: PackedFloat32Array, rate: int, gain: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var b := PackedByteArray()
	b.resize(x.size() * 2)
	for i in x.size():
		b.encode_s16(i * 2, int(clampf(x[i] / peak * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = b
	return s

func _one_shot(n: String, s: AudioStream, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.name = n
	a.stream = s
	a.bus = &"SFX"
	a.unit_size = 2.0
	a.max_distance = 25.0
	a.volume_db = db
	a.position = Vector3(0, 0.2, 0)
	add_child(a)
	return a

## Flint and steel: a bright scrape of the steel down the flint's edge, then the click of the
## blow ringing off the steel for a few ms.
func _build_strike_sounds() -> void:
	const RATE := 22050
	var n := int(RATE * 0.22)
	var x := PackedFloat32Array()
	x.resize(n)
	var prev := 0.0
	var scrape := int(RATE * 0.045)
	for i in scrape:                         # rasp: highpassed noise, rising then cut off
		var w := _rng.randf() * 2.0 - 1.0
		var e := pow(float(i) / scrape, 1.5) * 0.35
		x[i] = (w - prev * 0.85) * e
		prev = w
	for i in n - scrape:                     # the click: three steel partials, fast decay
		var t := float(i) / RATE
		var e := exp(-t * 55.0)
		x[scrape + i] += e * (sin(TAU * 3150.0 * t) * 0.6 + sin(TAU * 4710.0 * t + 1.0) * 0.4 + sin(TAU * 6930.0 * t + 2.0) * 0.25)
		if i < RATE * 0.006:
			x[scrape + i] += (_rng.randf() * 2.0 - 1.0) * (1.0 - i / (RATE * 0.006))
	flint = _one_shot("Flint", _wav(x, RATE, 0.85), -9.0)
	# the catch: two soft breaths into the tinder (lowpassed noise swelling and dying) and the
	# low whump of the flame taking on the second
	n = RATE * 3
	x = PackedFloat32Array()
	x.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.12
		lp2 += (lp - lp2) * 0.3
		var b1 := sin(PI * clampf(t / 0.7, 0.0, 1.0))
		var b2 := sin(PI * clampf((t - 0.95) / 0.9, 0.0, 1.0))
		x[i] = lp2 * (b1 * b1 * 0.7 + b2 * b2)
		if t > 1.55:                         # the whump: a low swell with a breathy roar on top
			var u := t - 1.55
			var env := (1.0 - exp(-u * 18.0)) * exp(-u * 2.2)
			x[i] += env * (sin(TAU * (62.0 + 30.0 * exp(-u * 6.0)) * u) * 0.9 + lp * 1.6)
	blow = _one_shot("Blow", _wav(x, RATE, 0.8), -6.0)

# ---------------------------------------------------------------- run

func _process(delta: float) -> void:
	_t += delta
	var h := _hour()
	var f := level_for(h)
	if h >= 9.5 and h < 19.5:
		kindled = -1.0                       # a new evening: cold until she lights it
	elif kindled >= 0.0:
		kindled += delta
	if kindled >= 0.0 and h >= 19.5 and h < 23.0:  # after 23 it burns down by the clock
		var k := smoothstep(0.0, KINDLE_RAMP, kindled)
		f = maxf(f, k * k)                   # a long smoulder before the flames take
	_apply(f, delta)

## Hesper's flint: a burst of sparks into the tinder.
func strike_flint(from: Vector3) -> void:
	strikes += 1
	var d := Vector3(from.x - global_position.x, 0, from.z - global_position.z)
	d = d.normalized() if d.length() > 0.05 else Vector3.FORWARD
	strike.position = d * 0.2 + Vector3.UP * 0.18
	strike.restart()
	strike.emitting = true
	if flint.is_inside_tree():
		flint.pitch_scale = _rng.randf_range(0.9, 1.12)
		flint.play()
		flint_sounds += 1

## Hesper's tinder has caught: the fire takes from here, smoke first, then flame.
func kindle() -> void:
	if kindled < 0.0:
		kindled = 0.0
		if blow.is_inside_tree():
			blow.play()
			blow_sounds += 1

func _apply(f: float, delta: float) -> void:
	var rain := weather.rain if weather != null else 0.0
	level = f
	var flame := clampf((f - 0.15) / 0.85, 0.0, 1.0) * (1.0 - 0.6 * rain)
	for m in _mat:
		m.set_shader_parameter("glow", f)
	flames.emitting = flame > 0.02
	flames.scale_amount_min = 0.4 + 0.35 * flame
	flames.scale_amount_max = 0.7 + 0.6 * flame
	# young flames off fresh tinder are thin and orange, not a white-hot core: half the
	# brightness for the first ~20 s after it catches
	var young := 1.0 if kindled < 0.0 else lerpf(0.5, 1.0, smoothstep(6.0, 20.0, kindled))
	flame_gain = young
	flames.color = Color(young, young, young, clampf(flame * 1.4, 0.0, 1.0))
	sparks.emitting = flame > 0.25
	# smoke from the first smoulder to the last wisp; thicker when rain hisses on it
	smoke.emitting = f > 0.01
	var wisp := clampf(0.35 + 0.5 * (1.0 - flame) + rain * 0.5, 0.0, 0.8) * clampf(f * 12.0, 0.0, 1.0)
	smoke.color = Color(1, 1, 1, wisp)
	var wind := weather.wind if weather != null else 0.0
	smoke.gravity = Vector3(0.8, 0, 0.6) * (0.15 + 0.6 * wind) + Vector3(0, 0.15, 0)
	# light: a flicker of a few octaves, embers alone give a dim red glow
	var fl := 0.82 + 0.18 * _flick.get_noise_1d(_t * 9.0) + 0.06 * _flick.get_noise_1d(_t * 31.0 + 100.0)
	light.light_energy = (2.6 * flame + 0.35 * clampf(f * 3.0, 0.0, 1.0)) * fl
	light.light_color = Color(1.0, 0.5, 0.2).lerp(Color(1.0, 0.3, 0.1), 1.0 - flame)
	light.visible = light.light_energy > 0.01
	# strongest while the fire is low (smouldering tinder, embers) when the main light is weak
	bounce.light_energy = (0.55 * flame + 0.5 * clampf(f * 4.0, 0.0, 1.0) * (1.0 - 0.5 * flame)) * fl
	bounce.light_color = light.light_color
	bounce.visible = bounce.light_energy > 0.01
	light.position = Vector3(_flick.get_noise_1d(_t * 5.0 + 50.0) * 0.04, 0.62 + 0.12 * flame, _flick.get_noise_1d(_t * 5.0 + 90.0) * 0.04)
	if crackle.is_inside_tree():
		var want := linear_to_db(maxf(flame * 0.9 + clampf(f * 3.0, 0.0, 1.0) * 0.1, 0.0001)) - 6.0
		crackle.volume_db = want
		if f > 0.01 and not crackle.playing:
			crackle.play(_rng.randf() * 4.0)
		elif f <= 0.01 and crackle.playing:
			crackle.stop()
	# moths: only round a real flame in the dark
	var night := _hour() >= 19.8 or _hour() < 5.6
	_moth_on = move_toward(_moth_on, 1.0 if (night and flame > 0.3 and rain < 0.3) else 0.0, delta * 0.1 if delta > 0.0 else 1.0)
	if delta == 0.0:
		_moth_on = 1.0 if (night and flame > 0.3 and rain < 0.3) else 0.0
	var on := int(round(_moth_on * MOTHS))
	for i in MOTHS:
		var p := _moth_at(i, _t)
		var vel := _moth_at(i, _t + 0.05) - p
		var fwd := vel.normalized() if vel.length() > 1e-4 else Vector3.FORWARD
		var right := fwd.cross(Vector3.UP).normalized()
		if right.length() < 0.5:
			right = Vector3.RIGHT
		var up := right.cross(fwd)
		var flap := sin(_t * _moths[i][5] + i) * 0.9
		var body := Basis(right, up, -fwd)
		var vis := 1.0 if i < on else 0.0
		for side in 2:
			var sgn := 1.0 if side == 0 else -1.0
			var wing := body * Basis(Vector3(0, 0, 1), flap * sgn) * Basis.from_scale(Vector3(sgn, 1, 1) * vis)
			_moth_mm.set_instance_transform(i * 2 + side, Transform3D(wing, p))
