extends SceneTree
## Lists which leg/hips tracks each vanguard clip keys (bone, type, key count).
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var m := (load("res://player/models/vanguard.glb") as PackedScene).instantiate()
	root.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in ["Idle", "Walk", "Run"]:
		var a := ap.get_animation(clip)
		var names := []
		for t in a.get_track_count():
			var p := str(a.track_get_path(t))
			if p.contains("Leg") or p.contains("Hips") or p.contains("Foot") or p.contains("Toe"):
				names.append("%s:%d:%d" % [p.get_slice(":", 1), a.track_get_type(t), a.track_get_key_count(t)])
		print("%s tracks %d legs %s" % [clip, a.get_track_count(), " ".join(names)])
	quit()
