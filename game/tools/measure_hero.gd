extends SceneTree
## Prints the hero's proportions at the Idle pose: bone heights, head and leg ratios, and the
## garb pieces' world-space AABBs (hat, hood, mantle). Run: godot --headless -s tools/measure_hero.gd
func _init() -> void:
	var p: Node = load("res://player/player.tscn").instantiate()
	p.set("use_bot_input", true)
	root.add_child(p)
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	var skel := p.find_child("Skeleton3D", true, false) as Skeleton3D
	var y0: float = p.global_position.y
	var names := ["mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot",
		"mixamorig_LeftToeBase", "mixamorig_Spine", "mixamorig_Spine2", "mixamorig_Neck",
		"mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_LeftShoulder", "mixamorig_RightShoulder",
		"mixamorig_LeftArm", "mixamorig_RightArm", "mixamorig_LeftHand"]
	var h := {}
	for n in names:
		var b := skel.find_bone(n)
		if b < 0:
			print(n, " missing"); continue
		var gp := skel.global_transform * skel.get_bone_global_pose(b).origin
		h[n] = gp
		print("%-26s y=%.3f  x=%.3f z=%.3f" % [n, gp.y - y0, gp.x, gp.z])
	print("skel scale ", skel.global_transform.basis.get_scale())
	var mesh_top := -1e9
	var mesh_bot := 1e9
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible or m.mesh == null:
			continue
		var bb := m.global_transform * m.get_aabb()
		print("%-28s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f)" % [m.name, bb.position.x, bb.position.y - y0, bb.position.z, bb.size.x, bb.size.y, bb.size.z])
	if h.has("mixamorig_HeadTop_End") and h.has("mixamorig_LeftFoot"):
		var top: float = h["mixamorig_HeadTop_End"].y - y0
		var chin: float = h["mixamorig_Neck"].y - y0
		print("stature(headtop) %.3f  head(neck->top) %.3f = 1/%.2f" % [top, top - chin, top / maxf(top - chin, 0.01)])
		var hip: float = h["mixamorig_LeftUpLeg"].y - y0
		print("leg (hip joint height) %.3f = %.3f of stature" % [hip, hip / top])
		var sw: float = (h["mixamorig_LeftArm"] - h["mixamorig_RightArm"]).length()
		print("shoulder joint width %.3f = %.3f of stature" % [sw, sw / top])
	quit()
