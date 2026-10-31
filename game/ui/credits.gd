class_name Credits
extends CanvasLayer
## The Credits screen: every CC BY credit the game owes (work, author, source, license), plus
## thanks to the CC0 / public-domain authors and the Mixamo model. Opened from the pause menu
## ("Credits"); `roll()` scrolls it by itself, for after the ending. Same lacquer-and-brass
## panel as the pause menu. Keep SECTIONS in step with ASSETS.md: bot `credits` fails if a
## CC BY author listed there is missing here.

signal closed

const BRASS := Color(0.62, 0.5, 0.3)
const INK := Color(0.86, 0.82, 0.74)
const ROLL_SPEED := 38.0     # px/s when rolling after the ending

## [heading, [[line, sub-line], ...]]. The sub-line names the source and the license.
const SECTIONS := [
	["Music  (CC BY 3.0, creativecommons.org/licenses/by/3.0)", [
		["\"Mystical Theme\", \"Without\", \"Medicine\", \"Decision\", \"Steeps of Destiny\", \"Heroes Theme\" (end, edited)  by Alexandr Zhelanov", "opengameart.org/users/alexandr-zhelanov"],
		["\"Battle in the winter\"  by Johan Brodd (jobromedia)", "opengameart.org/content/battle-in-the-winter"],
		["\"Lazy Day\"  by FoxSynergy", "opengameart.org/content/lazy-day"],
	]],
	["Sound effects  (CC BY 3.0 unless noted; cut, filtered and re-levelled)", [
		["Stone hits, flint and steel  by Benboncan", "freesound.org/s/71823, /s/66457  (via minetest_game)"],
		["Wet footsteps  by AGFX", "freesound.org/people/AGFX/packs/1253  (via minetest_game)"],
		["Stone footsteps  by Erdie", "freesound.org/s/41579  (via minetest_game)"],
		["Fire crackle  by Dynamicell", "freesound.org/s/17548  (via minetest_game)"],
		["Forest Rain  by Corsica_S", "freesound.org/s/169031  (CC BY, via Muges/ambientsounds)"],
		["Heavy Rain  by D W", "freesound.org/s/136971  (CC BY, via Muges/ambientsounds)"],
		["Thunderstorm  by RHumphries", "freesound.org/s/2523  (CC BY, via Muges/ambientsounds)"],
		["Terrier barks  by Anton", "freesound.org/s/157322  (via HybridDog/dogblocks)"],
		["Eating crunch  by InspectorJ (www.jshaw.co.uk)", "freesound.org/s/429591  (via VoxeLibre)"],
		["Digging (grain)  by Stephen Hall (shall555)", "freesound.org/s/72199  (via OpenClonk)"],
		["Grunts  by bennychico11", "freesound.org/s/80438  (via OpenClonk)"],
		["Windbag breaths  by Ringwaul (OpenClonk team)", "github.com/openclonk/openclonk"],
		["Flame catching  by CGEffex", "freesound.org/s/94102  (via OpenClonk)"],
		["Wind loop  by ERH", "freesound.org/s/34338  (via OpenClonk)"],
		["Wing flutter, bucket hits  by ala (OpenClonk team)", "github.com/openclonk/openclonk"],
	]],
	["Character", [
		["Vanguard model and animations", "Mixamo (Adobe), used under the Mixamo license"],
	]],
	["With thanks  (CC0 / public domain, no credit required)", [
		["Kenney (Impact Sounds, RPG Audio, Sci-fi Sounds), qubodup, Sheyvan, worthahep88, lolamadeus, evsecrets", ""],
		["felix.blume, kvgarlic, sonidosreales245, Porrumentzio, Lisa Redfern (soundbible.com)", ""],
		["Sadiquecat, dave.des, MeanRaccoon, migoreng1, CVLTIV8R, florianreichelt, Halgrimm, LilMati, DeVern, Kinoton", ""],
	]],
	["Made with", [
		["Godot Engine  (MIT license, godotengine.org/license)", ""],
	]],
]

var open := false
var rolling := false
var scroll: ScrollContainer   # bots read it
var _roll_y := 0.0
var _root: Control
var _col: VBoxContainer

func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.047, 0.04, 0.94)
	sb.border_color = BRASS.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	outer.add_child(_label("CREDITS", 22, INK, HORIZONTAL_ALIGNMENT_CENTER))
	outer.add_child(_rule())
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_col = VBoxContainer.new()
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_theme_constant_override("separation", 4)
	scroll.add_child(_col)
	_col.add_child(_label("Emberfall", 18, INK, HORIZONTAL_ALIGNMENT_CENTER))
	for sec: Array in SECTIONS:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 12)
		_col.add_child(gap)
		_col.add_child(_label(sec[0], 15, BRASS))
		for ln: Array in sec[1]:
			_col.add_child(_label(ln[0], 14, INK))
			if ln[1] != "":
				_col.add_child(_label("      " + ln[1], 12, INK.darkened(0.35)))
	outer.add_child(_rule())
	var back := Button.new()
	back.text = "Back"
	back.flat = true
	back.add_theme_color_override("font_color", INK)
	back.add_theme_color_override("font_hover_color", BRASS.lightened(0.3))
	back.pressed.connect(close)
	outer.add_child(back)

func _label(t: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = BRASS.darkened(0.45)
	r.custom_minimum_size = Vector2(0, 1)
	return r

## Every line of the screen as one string (bots search it).
static func text() -> String:
	var out := PackedStringArray()
	for sec: Array in SECTIONS:
		out.append(sec[0])
		for ln: Array in sec[1]:
			out.append(ln[0])
			out.append(ln[1])
	return "\n".join(out)

func show_screen() -> void:
	open = true
	rolling = false
	_root.visible = true
	scroll.scroll_vertical = 0

## After the ending: open and scroll slowly to the bottom by itself; Back still closes it.
func roll() -> void:
	show_screen()
	_roll_y = 0.0
	rolling = true

func close() -> void:
	open = false
	rolling = false
	_root.visible = false
	closed.emit()

func _process(delta: float) -> void:
	if rolling:
		_roll_y += ROLL_SPEED * delta
		scroll.scroll_vertical = int(_roll_y)

func _unhandled_input(event: InputEvent) -> void:
	if open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
