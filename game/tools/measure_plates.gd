extends SceneTree
## Skins the Vanguard mesh on the CPU at the Idle pose and prints, per height band, how far the
## armour reaches sideways and front/back in body space (to size the mantle over the shoulder plates).
func _init() -> void:
	var p: Node = load("res://player/player.tscn").instantiate()
	p.set("use_bot_input", true)
	root.add_child(p)
	for i in 4:
		await process_frame
	var skel := p.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi := p.find_child("vanguard_Mesh", true, false) as MeshInstance3D
	var body := p.find_child("Body", true, false) as Node3D
	var skin := mi.skin
	var bind_bone := PackedInt32Array()
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = skel.find_bone(skin.get_bind_name(i))
		bind_bone.append(b)
	var to_body := body.global_transform.affine_inverse() * skel.global_transform
	var bands := {}
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bo = arr[Mesh.ARRAY_BONES]
		var we = arr[Mesh.ARRAY_WEIGHTS]
		var n := v.size()
		var k: int = bo.size() / n
		for i in n:
			var acc := Vector3.ZERO
			for j in k:
				var w: float = we[i * k + j]
				if w <= 0.0:
					continue
				var bi: int = bo[i * k + j]
				var xf := skel.get_bone_global_pose(bind_bone[bi]) * skin.get_bind_pose(bi)
				acc += w * (xf * v[i])
			var q := to_body * acc
			var band := int(floor(q.y / 0.05))
			if band < 22 or band > 35:
				continue
			var e = bands.get(band, [0.0, 0.0, 0.0, 0.0])
			e[0] = maxf(e[0], q.x); e[1] = minf(e[1], q.x); e[2] = maxf(e[2], q.z); e[3] = minf(e[3], q.z)
			bands[band] = e
	var ks := bands.keys(); ks.sort()
	for b in ks:
		var e = bands[b]
		print("y %.2f-%.2f  x %+.3f..%+.3f  z %+.3f..%+.3f" % [b * 0.05, b * 0.05 + 0.05, e[1], e[0], e[3], e[2]])
	var ch := skel.find_bone("mixamorig_Spine2")
	print("chest bone body y ", (to_body * skel.get_bone_global_pose(ch).origin))
	quit()
