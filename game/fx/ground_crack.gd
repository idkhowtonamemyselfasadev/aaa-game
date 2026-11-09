class_name GroundCrack
extends Node3D
## Where the Stone Sentinel's glaive comes down: the turf splits in a star of cracks round a
## shallow pit, stone chips and clods kick up, and a shock runs out along the ground as a
## ring of dust. The ring throws down a hero it passes under who is standing on the ground
## (unblockable); a hero in the air (a jump timed on the slam) lets it run under their feet,
## and dodge i-frames pass through it like any strike. The cracks linger and fade.

signal rang(result: String)

const RING_R := 4.4            # m the shock runs out before it dies
const RING_SPEED := 9.0        # m/s: ~0.5 s to its edge
const INNER := 0.9             # inside this the glaive itself did the work
const DAMAGE := 16.0
const AIR := 0.32              # feet this far over the turf are clear of the shock
const LIFE := 7.0

var source: Node               # receive_attack's attacker (the sentinel)
var player: Player
var terrain: Terrain
var spare_player := false      # the glaive already struck (or the hero was parrying): no second blow
var harmless := false          # the hero's own plunge: the marks and the dust, no shock to take
var ring_r := RING_R           # m this shock runs out (the hero's plunge: its burst radius)
var size_k := 1.0              # crack star / chip scale (set before add_child)
var t := 0.0
var result := ""               # "" until the ring reaches the hero: hit / perfect / dodged / jumped / miss
var front := 0.0
var _decal: Decal
var _dust: CPUParticles3D
var _chips: CPUParticles3D
var _puff: CPUParticles3D
var _front_dust: CPUParticles3D  # laid along the shock front as it runs: the ring that reads
var _clods: CPUParticles3D       # fist-sized turf clods thrown up and out (11-09 14:00)
var _column: CPUParticles3D      # dark earth column shot straight up over the pit (11-09 14:00)
var blasted := 0                 # grass points laid flat round the pit (bots)
var exposure := 0.0              # 0 deep shade / night .. 1 open midday sun at the pit (bots)
var glow := DUST_GLOW_E          # the dust's self-light after exposure (bots)

static var _crack_tex: ImageTexture
static var _soft: ImageTexture

## (11-09 13:00) the burst opens ON the contact tick: the dust used to fade in from alpha 0 over
## 6 % of its life (0.13 s for the puff) at under half size, low enough that the soft-particle
## fade ate it, so the plunge's impact frame showed bare turf and the cloud came a beat late.
## Now the puff and the ring dust open near full alpha at ~0.8 of their size and the puff is
## thrown up off the turf fast, then held by the air. CRACK_SOFTOPEN=1 = the old slow open.
static var SOFT_OPEN := OS.get_environment("CRACK_SOFTOPEN") == "1"
const OPEN_ALPHA := 0.6         # the dust's alpha on the very first frame (old 0.0)
const OPEN_SCALE := 0.85        # its size on the first frame, of the scale curve's top end (old 0.45)

## (11-09 14:00) the burst had no height and no texture: a flat, pale, even disc on the turf,
## its 3.5 cm chips too small to read. Now a column of dark earth shoots up over the pit and
## falls back as it thins, a dozen and a half fist-sized clods are thrown up and out on arcs,
## and the dust opens dark wet-earth brown and pales as it hangs. CRACK_FLATBURST=1 = old.
static var FLAT_BURST := OS.get_environment("CRACK_FLATBURST") == "1"
const EARTH_OPEN := Color(0.34, 0.29, 0.23)    # the dust's colour on the contact frame (old pale 0.55)
const CLOD_R := 0.075                          # m, a clod's radius at scale 1

## (11-09 18:00) GL frames showed the burst as a near-white glowing disc and no column. Test
## renders (CRACK_DBG, removed): switching the emission off changed nothing, the 0.34 brown
## albedo simply blows out under the full midday sun (energy 3.0). The dust now darkens with the
## sun's strength (`sun_tint`, x0.62 at noon, x1 at dusk/night). A red-painted column stood
## low and BEHIND the crouched hero: the hero's own plunge now raises it where the ferrule went
## in, 0.55 m in front of the hero (scaled), and fires it faster so it tops the hat by 0.15 s.
## CRACK_PALEDUST=1 / CRACK_COLBEHIND=1 = old.
static var PALE_DUST := OS.get_environment("CRACK_PALEDUST") == "1"
static var COL_BEHIND := OS.get_environment("CRACK_COLBEHIND") == "1"
const COL_FRONT := 0.55          # m ahead of the hero, at size_k 1 (where the ferrule strikes)
## (11-09 19:00) GL frames showed the column as translucent pale-grey smoke (its ramp paled to
## 0.45 by 35 % of life and dropped to alpha 0.5). Now it holds dark earth, alpha ~0.9, to 45 %
## of life with fewer, larger cards, and self-lights at a third of the dust glow.
## CRACK_PALECOL=1 = old.
static var PALE_COL := OS.get_environment("CRACK_PALECOL") == "1"
const COL_DARK := Color(0.21, 0.175, 0.135)
const COL_HOLD := 0.45
const COL_GLOW_K := 0.35
## (11-09 20:00) The dust at the hero's feet (puff, shock ring, front band) read as a pale
## glowing patch right under the lens in the land 0.30 frame: its ramp paled to 0.47 by 20 %
## of life and it kept the full self-glow. It now holds wet-earth brown to ~35 % of life
## (0.5 s on the ring) before it dries pale, with under half the glow.
## Only the hero's plunge (harmless): the Stone Sentinel's slam keeps the glow that lets its
## ring read in the shade under the oaks. CRACK_PALERING=1 = old.
static var PALE_RING := OS.get_environment("CRACK_PALERING") == "1"
const RING_HOLD := 0.35
const RING_GLOW_K := 0.45
## (11-09 22:00) A dozen whitish pebble dots round the hero's feet in the plunge frames: the
## chips were smooth grey (0.3) low-poly balls with the full specular and none of the dust's sun
## tint, so the midday sun lit each into a white bead; the clods had no tint either. Chips are
## now small lumpy crumbs of dark earth (the clod mesh at ~half size), near-matte, and chips and
## clods both darken with the sun like the dust. CRACK_PALECHIPS=1 = old.
static var PALE_CHIPS := OS.get_environment("CRACK_PALECHIPS") == "1"
const CHIP_EARTH := Color(0.2, 0.16, 0.12)
var sun_tint := 1.0              # the dust's albedo factor after the sun (bots)
var sun_e := 0.0                 # the sun's strength x height the tint answered (bots)

func _ready() -> void:
	_decal = Decal.new()
	_decal.size = Vector3(3.6 * size_k, 1.4, 3.6 * size_k)
	_decal.texture_albedo = crack_texture()
	_decal.albedo_mix = 1.0
	_decal.upper_fade = 0.3
	_decal.lower_fade = 0.3
	_decal.rotation.y = randf() * TAU
	add_child(_decal)
	_chips = _make_chips()
	add_child(_chips)
	_puff = _make_puff()
	add_child(_puff)
	_dust = _make_ring_dust()
	add_child(_dust)
	_front_dust = _make_front_dust()
	add_child(_front_dust)
	var all: Array = [_chips, _puff, _dust, _front_dust]
	if not FLAT_BURST:
		_clods = _make_clods()
		add_child(_clods)
		_column = _make_column()
		add_child(_column)
		all += [_clods, _column]
	for p in all:
		(p as CPUParticles3D).emitting = true
	_blast_grass.call_deferred()   # the sentinel places us after add_child
	_light_dust.call_deferred()

## Once placed: dust self-light by how sunlit the pit is (shade keeps the glow, sun drops it).
func _light_dust() -> void:
	exposure = _sun_exposure()
	glow = lerpf(DUST_GLOW_E, DUST_GLOW_SUN, exposure)
	sun_tint = 1.0 if PALE_DUST else _sun_tint()
	for p in [_puff, _dust, _front_dust, _column]:
		if p == null:
			continue
		var m := ((p as CPUParticles3D).mesh as QuadMesh).material as StandardMaterial3D
		var k := 1.0
		if p == _column and not PALE_COL:
			k = COL_GLOW_K
		elif p != _column and harmless and not PALE_RING and not FLAT_BURST:
			k = RING_GLOW_K
		m.emission_energy_multiplier = glow * k
		m.albedo_color = Color(sun_tint, sun_tint, sun_tint)
	if not PALE_CHIPS:
		var c := CHIP_EARTH * sun_tint
		c.a = 1.0
		_chips.color = c
		if _clods != null and _clods.color_initial_ramp != null:
			var g := _clods.color_initial_ramp.duplicate() as Gradient
			for i in g.get_point_count():
				var gc := g.get_color(i) * sun_tint
				gc.a = 1.0
				g.set_color(i, gc)
			_clods.color_initial_ramp = g

## How much darker the dust's albedo must be under the sun as it stands so it reads as earth,
## not chalk: 1.0 at dusk, at night and under a weak sun, down to ~0.62 at full midday sun.
## The sun's raw strength, not the shade estimate: the cards face the lens and catch it anyway.
func _sun_tint() -> float:
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun == null or not sun.visible:
		return 1.0
	var e := sun.light_energy * smoothstep(0.0, 0.25, sun.global_basis.z.normalized().y)
	sun_e = e
	return clampf(1.3 / (0.6 + 0.5 * e), 0.55, 1.0)

## Lay the sward flat round the pit, the stems combed outward away from the blow, so the
## crack star is not hidden in standing grass and the ground shows where the shock went.
func _blast_grass() -> void:
	var tr := get_node_or_null("../Trample") as Trample
	if tr == null:
		return
	var c := Vector2(global_position.x, global_position.z)
	tr.add_herd_point(c, Vector2(1, 0).rotated(randf() * TAU), 1.0, 0.0, 0.15)
	blasted += 1
	for ring: Array in [[0.85, 7, 1.0], [1.7, 11, 0.8], [2.6, 14, 0.5]]:
		var r: float = ring[0] * size_k
		var k: int = ring[1]
		var off := randf() * TAU
		for i in k:
			var d := Vector2.from_angle(off + TAU * i / k)
			tr.add_herd_point(c + d * r, d, ring[2], 0.0, 0.15)
			blasted += 1

func _physics_process(delta: float) -> void:
	var prev := front
	t += delta
	front = minf(t * RING_SPEED, ring_r + 0.5)
	if _front_dust.emitting:
		if front >= ring_r:
			_front_dust.emitting = false
		else:
			_front_dust.emission_ring_radius = maxf(front, 0.7)
			_front_dust.emission_ring_inner_radius = maxf(front - 0.25, 0.5)
	if result == "" and front > prev:
		if harmless:
			if front >= ring_r:
				result = "miss"
		else:
			_check_ring(prev)
	var u := clampf((t - 2.5) / (LIFE - 2.5), 0.0, 1.0)
	_decal.modulate = Color(1, 1, 1, 1.0 - u * u)
	if t > LIFE + 0.5:
		queue_free()

func _check_ring(_prev: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		result = "miss"
		return
	var d := player.global_position - global_position
	var flat := Vector2(d.x, d.z).length()
	if flat > ring_r or absf(d.y) > 1.8:
		if front >= ring_r:
			result = "miss"
			rang.emit(result)
		return
	if flat >= front:
		return                     # not reached them yet (a hero rolling in meets it sooner)
	if spare_player:
		result = "miss"
	elif _airborne():
		result = "jumped"
	else:
		result = player.receive_attack(source, DAMAGE, true, true)
	if result == "hit":
		ImpactFX.spawn(get_parent(), player.global_position + Vector3.UP * 0.25, Vector3(d.x, 0, d.z).normalized(), "dirt", 0.9)
	rang.emit(result)

func _airborne() -> bool:
	if player.is_on_floor():
		return false
	var g := global_position.y
	if terrain != null:
		g = terrain.height_at(player.global_position.x, player.global_position.z)
	return player.global_position.y - g > AIR

# --- particles ---

## Stone chips and clods thrown up out of the pit.
func _make_chips() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Chips"
	p.one_shot = true
	p.amount = 46
	p.lifetime = 1.3
	p.explosiveness = 0.95
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.position = Vector3(0, 0.08, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14.0, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.5
	if not PALE_CHIPS:
		# crumbs of the clod mesh at ~0.45 of its size (0.035 m like the old balls), tinted
		# per instance through the particle colour (set again under the sun in _light_dust)
		p.scale_amount_min = 0.35 * 0.45
		p.scale_amount_max = 1.5 * 0.45
		p.angle_max = 360.0
		p.particle_flag_rotate_y = true
		p.mesh = clod_mesh()
		p.color = CHIP_EARTH
		return p
	var q := SphereMesh.new()
	q.radius = 0.035
	q.height = 0.05
	q.radial_segments = 5
	q.rings = 2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.27, 0.22)
	m.roughness = 0.95
	q.material = m
	p.mesh = q
	return p

## Fist-sized clods of turf and earth, lumpy (a displaced icosphere, not a ball), thrown up
## out of the pit on steep arcs and out past the crouch; heavy, so they come down fast.
func _make_clods() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Clods"
	p.one_shot = true
	p.amount = int(18 * clampf(size_k, 0.85, 2.5))
	p.lifetime = 1.4
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 * size_k
	p.position = Vector3(0, 0.12, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 38.0
	p.initial_velocity_min = 3.2
	p.initial_velocity_max = 6.8
	p.gravity = Vector3(0, -16.0, 0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	# a clod is a chunk of turf whatever the blow: only lean its size a little with the burst
	var ck := lerpf(1.0, size_k, 0.4)
	p.scale_amount_min = 0.65 * ck
	p.scale_amount_max = 1.5 * ck
	p.particle_flag_rotate_y = true
	p.mesh = clod_mesh()
	# a few still carry their green top, most are bare dark earth
	var gi := Gradient.new()
	gi.offsets = PackedFloat32Array([0.0, 0.7, 0.72, 1.0])
	gi.colors = PackedColorArray([Color(0.26, 0.2, 0.15), Color(0.34, 0.27, 0.2), Color(0.3, 0.36, 0.17), Color(0.27, 0.33, 0.15)])
	p.color_initial_ramp = gi
	return p

static var _clod_mesh: ArrayMesh
## A lumpy clod: an icosphere pushed in and out by noise and squashed a little, dark earth,
## rough, lit properly (vertex colour picks its tint per clod).
static func clod_mesh() -> ArrayMesh:
	if _clod_mesh != null:
		return _clod_mesh
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 1.8
	var sph := SphereMesh.new()
	sph.radius = CLOD_R
	sph.height = CLOD_R * 1.5
	sph.radial_segments = 9
	sph.rings = 5
	var arr := sph.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var d := v[i].normalized()
		var k := 1.0 + 0.38 * noise.get_noise_3dv(d * 2.0)
		v[i] = v[i] * k
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 0.97
	m.metallic_specular = 0.15   # wet earth, not a glazed pebble: no white sun glint
	_clod_mesh = st.commit()
	_clod_mesh.surface_set_material(0, m)
	return _clod_mesh

## A column of dark earth shot straight up over the pit: it rises 1.2-2 m in a narrow plume,
## the air stops it, and it thins and pales as it hangs and spreads. Gives the burst height.
func _make_column() -> CPUParticles3D:
	var p := _dust_base(26, 1.6, 0.75 * clampf(size_k, 0.8, 2.0))
	p.name = "Column"
	p.explosiveness = 0.85
	p.position = Vector3(0, 0.25, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18 * size_k
	p.direction = Vector3(0, 1, 0)
	p.spread = 9.0
	var vk := lerpf(1.0, sqrt(size_k), 0.5)
	if harmless and not COL_BEHIND:
		# the hero's plunge: up where the ferrule went in, in front of the crouch, not behind it
		p.position = Vector3(0, 0.25, COL_FRONT * clampf(size_k, 0.8, 1.1))
		vk *= 1.25
	p.initial_velocity_min = 3.5 * vk
	p.initial_velocity_max = 5.0 * vk
	p.damping_min = 7.0
	p.damping_max = 8.5
	p.gravity = Vector3(0, -1.2, 0)
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.015, 0.35, 1.0])
	g.colors = PackedColorArray([Color(0.27, 0.23, 0.18, 0.85), Color(0.29, 0.25, 0.2, 0.85),
		Color(0.45, 0.41, 0.36, 0.5), Color(0.6, 0.58, 0.55, 0.0)])
	if not PALE_COL:
		# (11-09 19:00) thrown earth, not smoke: the column holds dark and near-opaque while it
		# rises and stalls (to ~45 % of life, 0.7 s), then pales and thins as it falls apart
		g.offsets = PackedFloat32Array([0.0, 0.015, COL_HOLD, 0.72, 1.0])
		g.colors = PackedColorArray([Color(COL_DARK, 0.93), Color(COL_DARK.lightened(0.03), 0.92),
			Color(COL_DARK.lightened(0.12), 0.85), Color(0.46, 0.43, 0.38, 0.38),
			Color(0.6, 0.58, 0.55, 0.0)])
		p.amount = 22
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.15
	p.color_ramp = g
	return p

## How dark the dust at the feet (the shock ring) is `age` s after the blow, and its self-glow:
## Vector2(luma, emission energy). For the bots.
func ring_read(age: float) -> Vector2:
	if _dust == null:
		return Vector2(1.0, 1.0)
	var c := _dust.color_ramp.sample(clampf(age / _dust.lifetime, 0.0, 1.0))
	var m := (_dust.mesh as QuadMesh).material as StandardMaterial3D
	return Vector2(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, m.emission_energy_multiplier)

## How dark and solid the column is `age` s after the blow: Vector2(luma, alpha). For the bots.
func column_read(age: float) -> Vector2:
	if _column == null:
		return Vector2(1.0, 0.0)
	var c := _column.color_ramp.sample(clampf(age / _column.lifetime, 0.0, 1.0))
	return Vector2(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, c.a)

## Roughly how high the column's slowest and fastest cards stop over the turf (m): the rise of
## a card fired at v and slowed by `damping` (linear, m/s^2) plus gravity. For the bots.
func column_peak() -> Vector2:
	if _column == null:
		return Vector2.ZERO
	var g := -_column.gravity.y
	var lo := _column.initial_velocity_min
	var hi := _column.initial_velocity_max
	return Vector2(_column.position.y + lo * lo / (2.0 * (_column.damping_max + g)),
		_column.position.y + hi * hi / (2.0 * (_column.damping_min + g)))

## The chips' albedo luminance after the sun, and their mesh's specular. For the bots.
func chip_read() -> Vector2:
	if _chips == null:
		return Vector2(1, 1)
	var c := _chips.color
	var spec := 0.5
	if _chips.mesh is SphereMesh:
		var m := (_chips.mesh as SphereMesh).material as StandardMaterial3D
		c = c * m.albedo_color
		spec = m.metallic_specular
	else:
		spec = (_chips.mesh.surface_get_material(0) as StandardMaterial3D).metallic_specular
	return Vector2(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, spec)

## The smallest clod's radius (m) and how many are thrown. For the bots.
func clod_read() -> Vector2:
	if _clods == null:
		return Vector2.ZERO
	return Vector2(CLOD_R * _clods.scale_amount_min, _clods.amount)

## How dark the dust opens (luminance of the ramp's first colour). For the bots.
func open_luma() -> float:
	if _puff == null:
		return 1.0
	var c := _puff.color_ramp.sample(0.0)
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## A heavy grey-brown puff out of the pit itself.
func _make_puff() -> CPUParticles3D:
	var p := _dust_base(44, 2.2)
	p.name = "Puff"
	p.position = Vector3(0, 0.4, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.9
	p.damping_min = 2.5
	p.damping_max = 4.0
	if not SOFT_OPEN:
		# thrown up out of the pit hard, then the air holds it: it clears the soft-particle
		# fade off the turf within a couple of frames instead of creeping up through it
		p.explosiveness = 1.0
		p.initial_velocity_min = 1.4
		p.initial_velocity_max = 3.6
		p.damping_min = 4.5
		p.damping_max = 6.5
		var m := (p.mesh as QuadMesh).material as StandardMaterial3D
		m.proximity_fade_distance = 0.18
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	return p

## The shock: a ring of dust thrown low and outward that keeps pace with the ring's front.
func _make_ring_dust() -> CPUParticles3D:
	var p := _dust_base(120, 1.5)
	p.name = "RingDust"
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.45
	p.emission_ring_height = 0.05
	p.direction = Vector3(0, 1, 0)
	p.spread = 15.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	# thrown outward hard, then the air takes it
	p.radial_accel_min = 26.0
	p.radial_accel_max = 32.0
	p.damping_min = 9.0
	p.damping_max = 12.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	return p

## Dust kicked up off the turf right where the shock front is, emitted on a ring whose radius
## follows `front` each frame (world coords: each puff stays where it was raised), so the run
## of the shock leaves a widening, low, hugging band of dust you can read as a ring.
func _make_front_dust() -> CPUParticles3D:
	var p := _dust_base(420, 1.5, 0.85)
	p.name = "FrontDust"
	p.one_shot = false
	p.explosiveness = 0.0
	p.position = Vector3(0, 0.08, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.04
	p.direction = Vector3(0, 1, 0)
	p.spread = 20.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.8
	p.radial_accel_min = 2.0
	p.radial_accel_max = 4.0
	p.damping_min = 2.5
	p.damping_max = 4.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.95
	return p

## `card` is the quad size. The dust is lit per vertex but also carries a faint pale
## emission (DUST_GLOW) so a ring raised in tree or cliff shade still reads as pale earth
## against the dark sward instead of vanishing (13:15 11-02 frame: lost in shade).
const DUST_GLOW := Color(0.62, 0.60, 0.56)
const DUST_GLOW_E := 0.32      # in shade, at dusk, at night
const DUST_GLOW_SUN := 0.1     # in full sun the light does the work; more reads chalk white (14:00 11-02 frame)

## How sunlit the pit is: the sun's height and strength, a cloud over it, and the oak crowns
## along the ray toward the sun (the flora shelter map, sampled where a crown ~7 m up would
## throw its shadow onto this spot).
func _sun_exposure() -> float:
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun == null or not sun.visible:
		return 0.0
	var to_sun := sun.global_basis.z.normalized()
	var e := clampf(sun.light_energy / 3.0, 0.0, 1.0) * smoothstep(0.0, 0.25, to_sun.y)
	var clouds := get_node_or_null("../Clouds") as CloudLayer
	if clouds != null:
		e *= remap(clouds.shade_at(global_position), 0.45, 1.0, 0.3, 1.0)
	var flora := get_node_or_null("../Flora")
	if flora != null and flora.has_method("shelter_at") and to_sun.y > 0.05:
		var reach := 7.0 / maxf(to_sun.y, 0.25)
		var h := Vector2(to_sun.x, to_sun.z).normalized() * reach
		var crown := 0.0
		for f in [0.6, 1.0, 1.4]:
			crown = maxf(crown, float(flora.shelter_at(global_position.x + h.x * f, global_position.z + h.y * f)))
		e *= 1.0 - smoothstep(0.1, 0.6, crown)
	return clampf(e, 0.0, 1.0)

func _dust_base(n: int, life: float, card := 0.6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.97
	p.local_coords = false
	p.position = Vector3(0, 0.15, 0)
	p.gravity = Vector3(0, 0.25, 0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(card, card)
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = DUST_GLOW
	m.emission_energy_multiplier = DUST_GLOW_E
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# soft particles: a camera-facing card cut off by the turf left a hard-floored pale
	# half-dome over the pit (14:00 11-02 frame); fade each card out where it meets ground
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.35
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	# grey-brown earth dust, paling and thinning as it hangs
	var a0 := 0.0 if SOFT_OPEN else OPEN_ALPHA
	var open := 0.06 if SOFT_OPEN else 0.015
	g.offsets = PackedFloat32Array([0.0, open, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.55, 0.52, 0.48, a0), Color(0.58, 0.55, 0.51, 0.68),
		Color(0.64, 0.62, 0.59, 0.42), Color(0.68, 0.67, 0.65, 0.0)])
	if not FLAT_BURST:
		# opens dark, wet-earth brown on the contact frame and pales as the cloud hangs and dries
		g.offsets = PackedFloat32Array([0.0, open, 0.2, 0.5, 1.0])
		g.colors = PackedColorArray([Color(EARTH_OPEN, a0), Color(EARTH_OPEN.lightened(0.05), 0.7),
			Color(0.47, 0.43, 0.37, 0.6), Color(0.62, 0.6, 0.56, 0.4), Color(0.68, 0.67, 0.65, 0.0)])
		if harmless and not PALE_RING:
			# (11-09 20:00, the hero's plunge; the Stone Sentinel's slam keeps its pale shade-reading dust) holds wet earth while the shock runs out, dries pale only as it hangs
			g.offsets = PackedFloat32Array([0.0, open, RING_HOLD, 0.7, 1.0])
			g.colors = PackedColorArray([Color(EARTH_OPEN, a0), Color(EARTH_OPEN.lightened(0.03), 0.72),
				Color(0.37, 0.33, 0.27, 0.62), Color(0.54, 0.52, 0.48, 0.36), Color(0.64, 0.63, 0.6, 0.0)])
	p.color_ramp = g
	var c := Curve.new()
	if SOFT_OPEN:
		c.add_point(Vector2(0, 0.45))
	else:
		# a quick bloom to near full size, then the slow spread as it hangs
		c.add_point(Vector2(0, OPEN_SCALE))
		c.add_point(Vector2(0.08, 1.05))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	return p

## How far ahead of `from` along `fwd` (flat) the column rises (m), for the bots.
func column_ahead(from: Vector3, fwd: Vector3) -> float:
	if _column == null:
		return -9.0
	var d := _column.global_position - from
	var f := Vector3(fwd.x, 0, fwd.z).normalized()
	return d.dot(f)

## The dust's lit brightness on the contact frame: its opening luma x the sun tint x the sun.
func lit_open() -> float:
	return open_luma() * sun_tint * maxf(sun_e, 1.0)

## How much of the puff a lens sees `age` s after the blow: its ramp alpha x its card area
## (scale curve x card size, squared), for the bots' contact-frame gate.
func puff_read(age: float) -> float:
	if _puff == null:
		return 0.0
	var u := clampf(age / _puff.lifetime, 0.0, 1.0)
	var a := _puff.color_ramp.sample(u).a
	var k := _puff.scale_amount_curve.sample(u) * ((_puff.mesh as QuadMesh).size.x)
	return a * k * k

static func _soft_texture() -> ImageTexture:
	if _soft != null:
		return _soft
	var n := 64
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n * 2.0 - Vector2.ONE
			var a := clampf(1.0 - p.length(), 0.0, 1.0)
			a = a * a * (0.7 + 0.3 * noise.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_soft = ImageTexture.create_from_image(img)
	return _soft

# --- the crack star ---

## A star of jagged cracks (each forking once or twice) out of a crushed pit, crossed by two
## broken rings of fracture, on a faint dusty bruise of the turf. Dark in the cracks (alpha
## high), clear between them.
static func crack_texture() -> ImageTexture:
	if _crack_tex != null:
		return _crack_tex
	var n := 512
	var rng := RandomNumberGenerator.new()
	rng.seed = 1709
	var a := PackedFloat32Array()
	a.resize(n * n)
	var c := Vector2(n, n) * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 23
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	# the bruise: crushed, dusty turf round the pit
	for y in n:
		for x in n:
			var p := (Vector2(x, y) - c) / (n * 0.5)
			var r := p.length() + noise.get_noise_2d(x, y) * 0.18
			a[y * n + x] = 0.42 * (1.0 - smoothstep(0.08, 0.55, r))
	# the pit
	_stamp(a, n, c, 22.0, 0.95)
	# the star
	var rays := 13
	var ends: Array[Vector2] = []
	for i in rays:
		var ang := TAU * (i + rng.randf_range(-0.3, 0.3)) / rays
		var length := rng.randf_range(0.55, 0.95) * n * 0.48
		ends.append(_crack(a, n, rng, c + Vector2.from_angle(ang) * 14.0, ang, length, 5.0, 2))
	# two broken rings of fracture between the rays
	for ring_r: float in [n * 0.11, n * 0.24]:
		var segs := 26
		for s in segs:
			if rng.randf() < 0.45:
				continue
			var a0 := TAU * s / segs
			var pos: Vector2 = c + Vector2.from_angle(a0) * ring_r * rng.randf_range(0.9, 1.1)
			var steps := int(ring_r * TAU / segs / 3.0)
			for k in steps:
				var aa := a0 + float(k) / steps * TAU / segs
				var tgt: Vector2 = c + Vector2.from_angle(aa) * ring_r * (1.0 + 0.08 * noise.get_noise_1d(aa * 60.0))
				pos = pos.lerp(tgt, 0.6)
				_stamp(a, n, pos, 1.6 if ring_r < n * 0.2 else 1.2, 0.85)
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := clampf(a[y * n + x], 0.0, 1.0)
			# deep cracks near black, the bruise a dull grey-brown dust
			var col := Color(0.32, 0.29, 0.24).lerp(Color(0.03, 0.025, 0.02), smoothstep(0.45, 0.9, v))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, v))
	img.generate_mipmaps()
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex

## One jagged crack from `from` along `ang`, thinning to nothing; forks `forks` times.
static func _crack(a: PackedFloat32Array, n: int, rng: RandomNumberGenerator, from: Vector2, ang: float, length: float, width: float, forks: int) -> Vector2:
	var pos := from
	var step := 2.5
	var steps := int(length / step)
	var heading := ang
	for i in steps:
		var f := float(i) / steps
		heading += rng.randf_range(-0.22, 0.22)
		heading = lerp_angle(heading, ang, 0.12)
		pos += Vector2.from_angle(heading) * step
		_stamp(a, n, pos, maxf(width * (1.0 - f * 0.85), 0.7), 1.0 - 0.3 * f)
		if forks > 0 and i > 6 and rng.randf() < 1.6 / steps:
			forks -= 1
			_crack(a, n, rng, pos, heading + rng.randf_range(0.35, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), length * (1.0 - f) * rng.randf_range(0.45, 0.8), width * (1.0 - f) * 0.7, 0)
	return pos

static func _stamp(a: PackedFloat32Array, n: int, at: Vector2, r: float, v: float) -> void:
	var x0 := maxi(int(at.x - r - 1), 0)
	var x1 := mini(int(at.x + r + 1), n - 1)
	var y0 := maxi(int(at.y - r - 1), 0)
	var y1 := mini(int(at.y + r + 1), n - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(at)
			var k := clampf(r + 0.5 - d, 0.0, 1.0) * v
			if k > a[y * n + x]:
				a[y * n + x] = k
