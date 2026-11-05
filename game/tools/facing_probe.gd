extends SceneTree
## Prints which way the hero model visually faces vs Body +Z: the toe bones lie ahead of the
## ankles and the left shoulder sits on the body's left. Run: godot --headless -s tools/facing_probe.gd
func _probe(skel: Skeleton3D, body: Node3D, tag: String) -> void:
	var gp := func(n: String) -> Vector3:
		return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(n)).origin
	var fwd := body.global_basis.z
	var toe: Vector3 = gp.call("mixamorig_LeftToeBase") - gp.call("mixamorig_LeftFoot")
	var lr: Vector3 = gp.call("mixamorig_LeftArm") - gp.call("mixamorig_RightArm")
	var left := Vector3.UP.cross(fwd)   # the body's left if +Z is forward
	print("FACING %s yaw %.2f body+Z %s toe.fwd %.3f left.dot %.3f" % [tag, body.rotation.y, fwd, toe.normalized().dot(fwd), lr.normalized().dot(left)])
func _init() -> void:
	for k in ["hero", "soldier", "knight"]:
		var p: Node
		if k == "hero":
			p = load("res://player/player.tscn").instantiate()
			p.set("use_bot_input", true)
		elif k == "soldier":
			p = HollowSoldier.new()
		else:
			p = AshenKnight.new()
		root.add_child(p)
		for i in 4:
			await physics_frame
		var body := p.get("body") as Node3D
		var skel := p.find_child("Skeleton3D", true, false) as Skeleton3D
		for y in [0.0, PI * 0.5, 3.07]:
			body.rotation.y = y
			await process_frame
			_probe(skel, body, k)
	quit()
