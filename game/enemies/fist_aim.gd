class_name FistAim
extends SkeletonModifier3D
## (11-10) The same-tick fist fit: runs after the fingers are posed (HandRest) and before a
## second pass of the arm IK. It reads each posed fist's centre against the haft's axis and
## sets that side's second-pass wrist target so the fist, not the wrist, lands on the shaft.
## The cross-tick fit (`HollowSoldier._fit_fists`) still takes out the steady offset; this
## catches what it lags in a fast move (the thrust's fist rode 7-9 cm off the haft).

var foe: Node   # HollowSoldier

func _process_modification_with_delta(_delta: float) -> void:
	if foe != null:
		foe._aim_fists()
