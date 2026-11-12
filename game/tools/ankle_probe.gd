extends SceneTree
## Prints the hero's base-mesh verts round the left ankle at rest (body space): per height band above
## the ankle joint, surface index, dominant bone (Leg/Foot), count and max radius from the shin axis,
## so the gap between the shin binding's end and the foot puttee can be sized.
func _init() -> void:
	var p: Node = load("res://player/player.tscn").instantiate()
	p.set("use_bot_input", true)
	root.add_child(p)
	for i in 4:
		await process_frame
	var skel := p.find_child("Skeleton3D", true, false) as Skeleton3D
	var body := p.find_child("Body", true, false) as Node3D
	var to_body := body.global_transform.affine_inverse() * skel.global_transform
	var knee := (to_body * skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftLeg"))).origin
	var ank := (to_body * skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftFoot"))).origin
	var toe := (to_body * skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftToeBase"))).origin
	var d := (ank - knee).normalized()
	print("PROBE knee ", knee, " ankle ", ank, " toe ", toe, " shin len ", knee.distance_to(ank))
	var bands := {}
	var uvb := {}
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null or not (m.mesh is ArrayMesh) or not m.is_visible_in_tree():
			continue
		var skin := m.skin
		var bb := PackedInt32Array()
		for i in skin.get_bind_count():
			var b := skin.get_bind_bone(i)
			if b < 0:
				b = skel.find_bone(skin.get_bind_name(i))
			bb.append(b)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var we: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			if v.is_empty() or bo.is_empty():
				continue
			var per := bo.size() / v.size()
			for i in v.size():
				var acc := Vector3.ZERO
				var best := -1
				var bw := 0.0
				for j in per:
					var w := we[i * per + j]
					if w <= 0.0:
						continue
					var bone := bb[bo[i * per + j]]
					acc += w * (to_body * skel.get_bone_global_rest(bone) * skin.get_bind_pose(bo[i * per + j]) * v[i])
					if w > bw:
						bw = w
						best = bone
				var nm := skel.get_bone_name(best)
				var grp := "foot" if (nm.contains("Foot") or nm.contains("Toe")) else "other"
				var cell := Vector2i(int(uv[i].x * 20.0), int(uv[i].y * 20.0))
				var cm: Dictionary = uvb.get(grp, {})
				cm[cell] = cm.get(cell, 0) + 1
				uvb[grp] = cm
				if not (nm.begins_with("mixamorig_LeftLeg") or nm.begins_with("mixamorig_LeftFoot") or nm.begins_with("mixamorig_LeftToe")):
					continue
				var h := acc.y - ank.y
				if h < -0.12 or h > 0.10:
					continue
				var key := "%s s%d %s h%+.2f" % [m.name, s, nm.replace("mixamorig_Left", ""), snappedf(h, 0.02)]
				var q := acc - ank
				q.y = 0.0
				var e: Array = bands.get(key, [0, 0.0, 0.0, 0.0])
				e[0] += 1
				e[1] = maxf(e[1], q.length())
				e[2] = maxf(e[2], q.z)     # forward reach
				e[3] = minf(e[3], q.z)     # back reach
				bands[key] = e
	for k in uvb:
		print("UVB %s %s" % [k, uvb[k]])
	var keys := bands.keys()
	keys.sort()
	for k in keys:
		var e: Array = bands[k]
		print("PROBE %s n%d r%.3f fwd%.3f back%.3f" % [k, e[0], e[1], e[2], e[3]])
	quit()
