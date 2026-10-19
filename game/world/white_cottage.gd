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
