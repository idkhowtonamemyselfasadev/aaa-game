class_name WhiteCottage
extends StoneCottage
## Harrowmere's third house: a smaller limewashed cottage on the south-west of the green,
## beside the timber-framed house, its door toward the start. Built by StoneCottage's
## builder (rubble walls, quoins, oak lintels, slates, a gable stack, lit windows) with its
## own shape, and every wall stone under coats of white lime (masonry a = 4: flaked low
## down, rain runs from the eaves, algae and splash grime at the foot).

const HOME := Vector2(-20.0, -2.0)
const W_LEN := 7.2
const W_DEP := 5.0
const W_EAVES := 2.35
## [wall, centre along the wall, sill above floor, width, height] as StoneCottage.OPENINGS
const W_OPENINGS := [
	[0, -0.3, 0.0, 0.95, 1.85],    # door
	[0, -2.2, 0.9, 0.7, 0.8],
	[0, 1.9, 0.9, 0.8, 0.85],
	[1, 1.0, 1.0, 0.6, 0.65],
	[2, 0.0, 1.05, 0.55, 0.55],
]

## World yaw: local +z (the door side) faces the village centre.
static func facing() -> float:
	return atan2(-HOME.x, -HOME.y)

## True when (x, z) lies under the house (walls, stack, eaves) plus `margin`.
static func covers(x: float, z: float, margin: float = 0.0) -> bool:
	var y := facing()
	var d := Vector2(x - HOME.x, z - HOME.y)
	var lx := d.x * cos(y) - d.y * sin(y)
	var lz := d.x * sin(y) + d.y * cos(y)
	return absf(lx) < W_LEN * 0.5 + OVER_V + margin and absf(lz) < W_DEP * 0.5 + OVER_E + margin

func _init() -> void:
	wlen = W_LEN
	wdep = W_DEP
	eaves = W_EAVES
	openings = W_OPENINGS
	limewash = true
	seed = 5151

## Under the eaves drip by the east corner of the door wall (cottage-local, on the ground).
const BUTT_AT := Vector2(3.05, 2.5 + 0.4)
## The bench against the door wall, left of the door under the window.
const BENCH_X := -1.75
const BENCH_LEN := 1.45

var butt: WaterButt
var bench_seat := Vector3.ZERO   # world centre of the bench's seat (bots)

func _ready() -> void:
	super()
	_yard_things()

func _ground(lx: float, lz: float) -> float:
	var p := to_global(Vector3(lx, 0, lz))
	return _terrain.height_at(p.x, p.z) - global_position.y

## The water butt on two stones and an oak bench on two stone legs by the door.
func _yard_things() -> void:
	var legs: Array = []
	var bx := BUTT_AT.x
	var bz := BUTT_AT.y
	# two flat dressed stones the cask stands on, bedded a little into the ground
	var g := _ground(bx, bz)
	for side in [-1.0, 1.0]:
		var c: Vector3 = Vector3(bx + side * 0.17, g + 0.04, bz)
		legs.append([Transform3D(Basis.from_euler(Vector3(0, side * 0.06, 0)) * Basis.from_scale(Vector3(0.2, 0.18, 0.62) / _dims[0]), c), Color(0.05, 0.62, 1.0, 1.0)])
	butt = WaterButt.new()
	butt.name = "WaterButt"
	add_child(butt)
	butt.position = Vector3(bx, g + 0.13, bz)
	butt.rotation.y = 0.4
	butt.weather = _world.get("weather")
	var tr = _world.get_node_or_null("Terrain")
	if tr:
		butt.terrain_mat = tr.material as ShaderMaterial
	_box(Vector3(bx, g + 0.13 + WaterButt.H * 0.5, bz), Vector3(0.66, WaterButt.H + 0.1, 0.66))
	# the bench: a thick oak plank, silvered on top, on two upright stones
	var hd := wdep * 0.5
	var sz := hd + 0.2
	var sg := maxf(_ground(BENCH_X, sz), floor_y - 0.15)
	var seat_y := sg + 0.45
	for side in [-1.0, 1.0]:
		var lx: float = BENCH_X + side * (BENCH_LEN * 0.5 - 0.22)
		var lg := _ground(lx, sz)
		var hgt := seat_y - 0.035 - lg + 0.08
		legs.append([Transform3D(Basis.from_scale(Vector3(0.14, hgt, 0.3) / _dims[0]), Vector3(lx, lg - 0.08 + hgt * 0.5, sz)), Color(0.05, 0.55, 1.0, 1.0)])
	_beam(Vector3(BENCH_X, seat_y, sz), Vector3.RIGHT, BENCH_LEN, Vector3(0.07, 0.34, 0.0), 6.1)
	_box(Vector3(BENCH_X, (sg + seat_y) * 0.5, sz), Vector3(BENCH_LEN, seat_y - sg + 0.05, 0.36))
	bench_seat = to_global(Vector3(BENCH_X, seat_y + 0.035, sz))
	_multimesh(_ruins._block_mesh(_dims[0], 20), legs, "YardStones")
