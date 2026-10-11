extends SceneTree
## Prints the triangle count of each wildflower mesh (flowers.gd), for the perf budget.
func _init() -> void:
	for sp in MeadowFlowers.SPECIES:
		var m := MeadowFlowers.mesh(sp)
		print("FLOWER %d tris %d" % [sp, m.surface_get_array_len(0) / 3])
	quit()
