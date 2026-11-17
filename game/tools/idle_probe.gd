extends SceneTree
## Samples a clip of the vanguard model and prints each ankle (skeleton space) over its length.
## usage: godot --headless --script res://tools/idle_probe.gd -- [clip]
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var clip := "Idle"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		clip = args[0]
	var m := (load("res://player/models/vanguard.glb") as PackedScene).instantiate()
	root.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var a := ap.get_animation(clip)
	print("clip %s len %.3f" % [clip, a.length])
	ap.play(clip)
	var n := 40
	var l := sk.find_bone("mixamorig_LeftFoot")
	var r := sk.find_bone("mixamorig_RightFoot")
	var h := sk.find_bone("mixamorig_Hips")
	for i in n + 1:
		ap.seek(a.length * i / n, true)
		await process_frame
		print("t %.3f L %s R %s hips %s" % [a.length * i / n, sk.get_bone_global_pose(l).origin, sk.get_bone_global_pose(r).origin, sk.get_bone_global_pose(h).origin])
		print("rot t %.3f RUp %s RLeg %s RFoot %s LUp %s LLeg %s" % [a.length * i / n, sk.get_bone_pose_rotation(sk.find_bone("mixamorig_RightUpLeg")), sk.get_bone_pose_rotation(sk.find_bone("mixamorig_RightLeg")), sk.get_bone_pose_rotation(sk.find_bone("mixamorig_RightFoot")), sk.get_bone_pose_rotation(sk.find_bone("mixamorig_LeftUpLeg")), sk.get_bone_pose_rotation(sk.find_bone("mixamorig_LeftLeg"))])
	quit()

