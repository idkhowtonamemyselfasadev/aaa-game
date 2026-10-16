class_name PauseMenu
extends CanvasLayer
## Esc pauses the world and opens a small dark panel: a sound section with one slider per
## mix layer (master, ambience, wildlife, effects, music), a picture section (quality preset
## Low..Ultra and the FSR 2 render scale), saved as they move, and Resume.
## Drawn in the HUD's language: near-black lacquer with a thin worn-brass edge.

const ROWS := [["Master", "Master"], ["Ambience", "Ambience"], ["Wildlife", "Wildlife"],
	["Effects", "SFX"], ["Music", "Music"]]
const BRASS := Color(0.62, 0.5, 0.3)
const INK := Color(0.86, 0.82, 0.74)

var mix: AudioMix
var graphics: GraphicsQuality
var quality_slider: HSlider  # bots read it
var scale_slider: HSlider
var open := false
var sliders := {}            # bus -> HSlider (bots read it)

var _root: Control
var _mouse_before := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.047, 0.04, 0.92)
	sb.border_color = BRASS.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(_label("PAUSED", 22, INK))
	col.add_child(_rule())
	col.add_child(_label("Sound", 15, BRASS))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for row: Array in ROWS:
		var bus: String = row[1]
		grid.add_child(_label(row[0], 15, INK))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(260, 18)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(s)
		var val := _label("", 14, INK.darkened(0.2))
		val.custom_minimum_size = Vector2(44, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		s.value_changed.connect(func(v: float) -> void:
			val.text = "%d" % roundi(v * 100.0)
			if mix:
				mix.set_volume(bus, v))
		sliders[bus] = s
	col.add_child(_rule())
	col.add_child(_label("Picture", 15, BRASS))
	var pic := GridContainer.new()
	pic.columns = 3
	pic.add_theme_constant_override("h_separation", 18)
	pic.add_theme_constant_override("v_separation", 10)
	col.add_child(pic)
	quality_slider = _row(pic, "Quality", 0.0, 3.0, 1.0, func(v: float) -> String:
		if graphics:
			graphics.set_level(roundi(v))
		return GraphicsQuality.NAMES[roundi(v)])
	quality_slider.tick_count = 4
	quality_slider.ticks_on_borders = true
	scale_slider = _row(pic, "Render scale", 0.5, 1.0, 0.05, func(v: float) -> String:
		if graphics:
			graphics.set_render_scale(v)
		return "%d%%" % roundi(v * 100.0) if v < 0.995 else "Native")
	col.add_child(_rule())
	var resume := Button.new()
	resume.text = "Resume"
	resume.flat = true
	resume.add_theme_color_override("font_color", INK)
	resume.add_theme_color_override("font_hover_color", BRASS.lightened(0.3))
	resume.pressed.connect(toggle)
	col.add_child(resume)

## One slider row in a 3-column grid; `on_change` applies the value and returns its readout.
func _row(grid: GridContainer, title: String, lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	grid.add_child(_label(title, 15, INK))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(260, 18)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(s)
	var val := _label("", 14, INK.darkened(0.2))
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(val)
	s.value_changed.connect(func(v: float) -> void: val.text = on_change.call(v))
	return s

func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = BRASS.darkened(0.45)
	r.custom_minimum_size = Vector2(0, 1)
	return r

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	open = not open
	_root.visible = open
	get_tree().paused = open
	if open:
		for bus: String in sliders:
			(sliders[bus] as HSlider).set_value_no_signal(mix.volumes.get(bus, 1.0) if mix else 1.0)
			(sliders[bus] as HSlider).value_changed.emit((sliders[bus] as HSlider).value)
		if graphics:
			quality_slider.set_value_no_signal(graphics.level)
			scale_slider.set_value_no_signal(graphics.render_scale)
		quality_slider.value_changed.emit(quality_slider.value)
		scale_slider.value_changed.emit(scale_slider.value)
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		(sliders["Master"] as HSlider).grab_focus()   # controller/keys can drive it too
	else:
		if mix:
			mix.save_settings()
		if graphics:
			graphics.save_settings()
		Input.mouse_mode = _mouse_before
