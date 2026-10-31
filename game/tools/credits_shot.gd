extends SceneTree
## Renders only the Credits screen (no world) to the path after `--`; a quick UI check:
## xvfb-run godot --script res://tools/credits_shot.gd -- ../shots/credits.png

func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.2, 0.17)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var c := Credits.new()
	root.add_child(c)
	await process_frame
	c.show_screen()
	for i in 10:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "../shots/credits.png"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join(out))
	quit()
