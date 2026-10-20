class_name FieldGate
extends Node3D
## The oak field gate hung in the garth wall's gateway (DryWall): a five-bar gate, bars set
## closer toward the foot to turn hens and lambs, a diagonal brace from the foot of the heel
## up to the head, iron strap hinges on crooks leaded into the hinge stoop and a ring latch on
## the head. Silvered, checked oak (timber.gdshader), rusty iron.
## It is hung on both-way crooks a hair off plumb, so it is a falling gate: walk up to it and
## it swings away from you (into the yard or out of it), and once you are through it falls
## back by its own weight, swings past, and knocks to rest against the latch stoop. A dry
## creak as it starts to swing, a wooden knock as it shuts (Foley hooks `creaked`/`knocked`).
## Its leaf collides only while it is shut.

signal creaked(at: Vector3)
signal knocked(at: Vector3, power: float)

const W := 1.22          # leaf length, heel to head
const H := 1.16          # height of the heel stile
const FOOT := 0.1        # clearance under the bottom bar
const BARS := [0.2, 0.39, 0.6, 0.84, 1.08]
const OPEN := 1.45       # how far it swings when pushed (rad)
const REACH := 1.9       # how near you come before it gives (m from the leaf centre)

var watch: Node3D        # who pushes it (the hero)
var walkers: Array[Node3D] = []   # villagers who go through it too (the nearest one shown pushes)
var angle := 0.0         # 0 shut; + swings toward +z (the leaf's local), - toward -z
var opens := 0           # times pushed open (bots)
var shuts := 0           # times knocked shut (bots)
var _vel := 0.0
var _side := 0.0         # which way it is being pushed, 0 when nobody is at it
var _hold := 0.0
var _creak_t := 0.0
var _leaf: Node3D
var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _timber: Shader
var _iron: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 808
	_timber = preload("res://shaders/timber.gdshader")
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.17, 0.12, 0.09)
	_iron.metallic = 0.55
	_iron.roughness = 0.82
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	add_child(_leaf)
	_build()
	_body = AnimatableBody3D.new()
	_body.name = "GateCollision"
	_body.sync_to_physics = false
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H - FOOT, 0.12)
	_shape.shape = box
	_shape.position = Vector3(W * 0.5, (H + FOOT) * 0.5, 0)
	_body.add_child(_shape)
	_leaf.add_child(_body)

## Oak in its own unscaled mesh, grain along the long axis: from a to b (leaf-local),
## section (w across, d through the gate).
func _oak(a: Vector3, b: Vector3, w: float, d: float, sd: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, a.distance_to(b), d)
	var m := ShaderMaterial.new()
	m.shader = _timber
	m.set_shader_parameter("seed", sd)
	bm.material = m
	mi.mesh = bm
	var y := (b - a).normalized()
	var z := Vector3.BACK
	var x := y.cross(z).normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized())
	mi.position = (a + b) * 0.5
	_leaf.add_child(mi)

func _ironbox(c: Vector3, size: Vector3, parent: Node3D, rot := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _iron
	mi.mesh = bm
	mi.position = c
	mi.rotation.z = rot
	parent.add_child(mi)

func _build() -> void:
	# the heel (hanging) stile, stout; the head stile a little lighter and shorter
	_oak(Vector3(0.05, FOOT - 0.02, 0), Vector3(0.05, H, 0), 0.1, 0.1, 1.0)
	_oak(Vector3(W - 0.04, FOOT, 0), Vector3(W - 0.04, H - 0.06, 0), 0.075, 0.08, 2.0)
	# five bars morticed through, the top rail deepest; each a hair off level like a hand-made gate
	for i in BARS.size():
		var y: float = BARS[i]
		var top := i == BARS.size() - 1
		var dz := _rng.randf_range(-0.012, 0.012)
		_oak(Vector3(0.1, y + dz, 0), Vector3(W - 0.08, y - dz, 0), 0.11 if top else 0.085, 0.055 if top else 0.035, 3.0 + i)
	# the brace: foot of the heel up to the head under the top rail, on the yard face of the bars
	_oak(Vector3(0.12, BARS[0] + 0.02, 0.035), Vector3(W - 0.14, BARS[3] + 0.06, 0.035), 0.075, 0.03, 9.0)
	# a short upright (the "dropper") at mid length, steadying the bars
	_oak(Vector3(W * 0.52, BARS[0] - 0.04, -0.035), Vector3(W * 0.52, BARS[4] + 0.04, -0.035), 0.07, 0.025, 10.0)
	# strap hinges along the top and bottom bars from the heel, bolt heads, an eye round the crook
	for y: float in [BARS[0], BARS[4]]:
		_ironbox(Vector3(0.3, y, 0.034), Vector3(0.5, 0.04, 0.008), _leaf)
		_ironbox(Vector3(0.3, y, -0.034), Vector3(0.5, 0.04, 0.008), _leaf)
		for bx in [0.16, 0.36, 0.52]:
			_ironbox(Vector3(bx, y, 0.04), Vector3(0.016, 0.016, 0.01), _leaf)
		_ironbox(Vector3(-0.02, y, 0), Vector3(0.05, 0.045, 0.045), _leaf)
	# the crooks: pins leaded into the hinge stoop (they stay put while the leaf swings)
	for y: float in [BARS[0], BARS[4]]:
		_ironbox(Vector3(-0.07, y - 0.035, 0), Vector3(0.12, 0.022, 0.022), self)
	# the latch: a ring and a short sneck on the head stile, both faces
	_ironbox(Vector3(W - 0.02, BARS[3] + 0.08, 0), Vector3(0.11, 0.022, 0.06), _leaf)
	for s in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.035
		tm.outer_radius = 0.047
		tm.material = _iron
		ring.mesh = tm
		ring.position = Vector3(W - 0.1, BARS[3] + 0.01, s * 0.05)
		ring.rotation = Vector3(PI * 0.5, 0, 0)
		_leaf.add_child(ring)

## Leaf centre in world space (bots, the shot lens).
func centre() -> Vector3:
	return _leaf.to_global(Vector3(W * 0.5, 0.6, 0))

func _physics_process(delta: float) -> void:
	var who := watch
	if who != null:
		var wd := Vector2(to_local(who.global_position).x - W * 0.5, to_local(who.global_position).z).length()
		for w in walkers:
			if w.visible:
				var lw := to_local(w.global_position)
				var dw := Vector2(lw.x - W * 0.5, lw.z).length()
				if dw < wd:
					who = w
					wd = dw
	if who:
		var lp := to_local(who.global_position)
		var near := Vector2(lp.x - W * 0.5, lp.z).length() < REACH and lp.y > -1.0 and lp.y < 2.5
		# inside the swept disc, it stays held open the way it went
		var swept := Vector2(lp.x, lp.z).length() < W + 0.6 and lp.x > -0.4
		if _side == 0.0 and near and absf(angle) < 0.5:
			# swing away from whoever comes at it; caught while still falling shut, it is
			# pushed back open the way it was already swinging
			if absf(angle) > 0.05:
				_side = signf(angle)
			else:
				_side = -signf(lp.z) if absf(lp.z) > 0.05 else 1.0
			opens += 1
			if _creak_t <= 0.0:
				creaked.emit(centre())
				_creak_t = 1.5
		if _side != 0.0 and (near or swept):
			_hold = 0.6
		elif _hold > 0.0:
			_hold -= delta
			if _hold <= 0.0:
				_side = 0.0
				if _creak_t <= 0.0:
					creaked.emit(centre())
					_creak_t = 1.5
	_creak_t -= delta
	var was := angle
	if _side != 0.0:
		# pushed: eased open, faster at first, never flung
		var goal := _side * OPEN
		_vel = clampf((goal - angle) * 4.0, -2.6, 2.6)
	else:
		# falling gate: its weight swings it back toward shut, a little past, settling
		_vel += -sin(angle) * 9.0 * delta - _vel * 1.4 * delta
	angle += _vel * delta
	if _side == 0.0 and signf(angle) != signf(was) and was != 0.0:
		# crossing shut: it knocks against the latch stoop and loses most of its swing
		var pw := absf(_vel)
		if pw > 0.12:
			knocked.emit(centre(), clampf(pw / 2.0, 0.1, 1.0))
			shuts += 1
		_vel *= -0.25
		angle = 0.0
	if _side == 0.0 and absf(angle) < 0.004 and absf(_vel) < 0.03:
		angle = 0.0
		_vel = 0.0
	_leaf.rotation.y = -angle
	_shape.disabled = absf(angle) > 0.12

## Holds the leaf at angle `a` and stops it swinging (shots).
func pose(a: float) -> void:
	set_physics_process(false)
	angle = a
	_leaf.rotation.y = -a
	_shape.disabled = absf(a) > 0.12
