class_name Hud
extends CanvasLayer
## Minimal combat HUD, bottom-left: a thin vitality bar over a thinner stamina bar, drawn as
## worn-brass-edged strips. Both fade out after a few seconds at full; any change brings them
## back. Drain shows as a pale "lost" segment that catches up, so hits read at a glance.

const FADE_AFTER := 2.5
var player: Player
var _bars: Control
var _alpha := 0.0
var _calm := 0.0
var _hp_lag := 1.0
var _st_lag := 1.0
var _last := Vector2(-1, -1)
var _reticle: Control
var _lock_a := 0.0              # reticle fade
var _lock_pop := 0.0            # 1 -> 0 after a new lock: the ring closes in
var _lock_seen: Node3D = null
var _lock_t := 0.0
var reticle_screen := Vector2(-1, -1)   # last drawn position (bots/shots read it)
var _veil: Control
var veil_alpha := 0.0                   # black over the screen (bots read it)
var _cap: Control
var caption_title := ""                 # place caption (bots read it)
var caption_line := ""
var caption_alpha := 0.0
var _cap_hold := 0.0
var _talk: Control
var prompt_key := ""                    # "E" while a talker is in reach (bots read it)
var prompt_verb := ""
var _prompt_hold := 0.0
var _prompt_a := 0.0
var say_speaker := ""                   # the spoken line on screen (bots read it)
var say_line := ""
var _say_t := 0.0
var _say_a := 0.0
var _quest: Control
var quest_shown := ""                   # the objective line drawn top-left (bots read it)

func _ready() -> void:
	layer = 5
	player = get_parent() as Player
	_bars = Control.new()
	_bars.name = "Bars"
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_reticle = Control.new()
	_reticle.name = "Reticle"
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)
	_veil = Control.new()
	_veil.name = "Veil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.draw.connect(_draw_veil)
	add_child(_veil)
	_cap = Control.new()
	_cap.name = "Caption"
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cap.draw.connect(_draw_caption)
	add_child(_cap)
	_talk = Control.new()
	_talk.name = "Talk"
	_talk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talk.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk.draw.connect(_draw_talk)
	add_child(_talk)
	_quest = Control.new()
	_quest.name = "Quest"
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest.draw.connect(_draw_quest)
	add_child(_quest)

## A place names itself while the hero stands at it: call every frame he is there; it fades in,
## and out again shortly after the calls stop.
func caption(title: String, line: String) -> void:
	if title != caption_title:
		caption_alpha = 0.0
	caption_title = title
	caption_line = line
	_cap_hold = 0.4

## A talker in reach: call every frame it is; the key hint fades in beside the hero's feet line
## and out shortly after the calls stop.
func prompt(key: String, verb: String) -> void:
	prompt_key = key
	prompt_verb = verb
	_prompt_hold = 0.2

## A spoken line as a subtitle in the bottom band, held for `secs`, then fading.
func say(speaker: String, line: String, secs: float) -> void:
	say_speaker = speaker
	say_line = line
	_say_t = secs

func saying() -> bool:
	return _say_t > 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	var hp := player.health / player.health_max
	var st := player.stamina / player.stamina_max
	var cur := Vector2(hp, st)
	if cur != _last or hp < 1.0 or st < 1.0:
		_calm = 0.0
	else:
		_calm += delta
	_last = cur
	var want := 0.0 if _calm > FADE_AFTER else 1.0
	_alpha = move_toward(_alpha, want, delta * (4.0 if want > _alpha else 1.2))
	# the lost segment holds briefly, then drains toward the current value
	_hp_lag = hp if hp > _hp_lag else move_toward(_hp_lag, hp, delta * 0.35)
	_st_lag = st if st > _st_lag else move_toward(_st_lag, st, delta * 0.9)
	_bars.queue_redraw()
	var lt := player.lock_target
	if lt != _lock_seen:
		_lock_seen = lt
		if lt != null:
			_lock_pop = 1.0
	_lock_pop = move_toward(_lock_pop, 0.0, delta * 5.0)
	_lock_t += delta
	_lock_a = move_toward(_lock_a, 1.0 if lt != null else 0.0, delta * 8.0)
	_reticle.queue_redraw()
	_cap_hold -= delta
	var ca := move_toward(caption_alpha, 1.0 if _cap_hold > 0.0 else 0.0, delta * (0.8 if _cap_hold > 0.0 else 0.6))
	if ca != caption_alpha:
		caption_alpha = ca
		_cap.queue_redraw()
	_prompt_hold -= delta
	_say_t -= delta
	var pa := move_toward(_prompt_a, 1.0 if _prompt_hold > 0.0 and _say_t <= 0.0 else 0.0, delta * 5.0)
	var sa := move_toward(_say_a, 1.0 if _say_t > 0.0 else 0.0, delta * (6.0 if _say_t > 0.0 else 2.5))
	if pa != _prompt_a or sa != _say_a or _say_t > 0.0:
		_prompt_a = pa
		_say_a = sa
		_talk.queue_redraw()
	var ql = player.get_node_or_null("Quests")
	var qa: String = ql.active() if ql != null else ""
	var want_q: String = ql.objective(qa) if qa != "" else ""
	if want_q != quest_shown or (ql != null and ql.banner_t > 0.0):
		quest_shown = want_q
		_quest.queue_redraw()
	var va := player.screen_black()
	if va != veil_alpha or va > 0.0:
		veil_alpha = va
		_veil.queue_redraw()

## Death: the screen sinks to black, and a single pale word surfaces in it before the hero
## wakes at the rest point. The black is drawn warm, not pure, so it reads as a fade of the
## dusk world, not a cut.
func _draw_veil() -> void:
	if veil_alpha <= 0.001:
		return
	var vs := _veil.get_viewport_rect().size
	_veil.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.018, 0.012, 0.01, veil_alpha))
	if not player.is_dead():
		return
	var t := player.dead_t - Player.DEATH_FADE_AT - 0.35
	var a := clampf(t / 0.6, 0.0, 1.0) * clampf((Player.DEATH_RESPAWN_AT - 0.15 - player.dead_t) / 0.35, 0.0, 1.0)
	if a <= 0.0:
		return
	var s := vs.y / 1080.0
	var font := ThemeDB.fallback_font
	var size := int(46.0 * s)
	var word := "F A L L E N"
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2((vs.x - w) * 0.5, vs.y * 0.5 + size * 0.35)
	_veil.draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.78, 0.66, 0.52, 0.85 * a))
	# a thin rule under the word, widening as it surfaces
	var rw := w * (0.6 + 0.4 * a)
	_veil.draw_line(Vector2((vs.x - rw) * 0.5, at.y + 18.0 * s), Vector2((vs.x + rw) * 0.5, at.y + 18.0 * s), Color(0.55, 0.42, 0.28, 0.5 * a), maxf(1.0, s))

## Place caption: the name in spaced bone-white capitals over a thin brass rule, one line of
## italic-weight remark under it, in the lower third; a soft dark band behind keeps it legible
## on bright sky or grass.
func _draw_caption() -> void:
	if caption_alpha <= 0.001 or caption_title == "":
		return
	var vs := _cap.get_viewport_rect().size
	var s := vs.y / 1080.0
	var a := caption_alpha * caption_alpha * (3.0 - 2.0 * caption_alpha)
	var font := ThemeDB.fallback_font
	var tsize := int(34.0 * s)
	var lsize := int(21.0 * s)
	var title := " ".join(caption_title.to_upper().split(""))
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
	var lw := font.get_string_size(caption_line, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize).x
	var cy := vs.y * 0.74
	var bw := maxf(tw, lw) + 160.0 * s
	var band := Rect2((vs.x - bw) * 0.5, cy - tsize * 1.3, bw, tsize * 1.3 + lsize * 2.2)
	for i in 6:   # feathered dark band
		var g := band.grow_individual(-i * bw * 0.06, 0, -i * bw * 0.06, 0)
		_cap.draw_rect(g, Color(0.01, 0.01, 0.008, 0.07 * a))
	_cap.draw_string(font, Vector2((vs.x - tw) * 0.5, cy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize, Color(0.9, 0.85, 0.74, 0.95 * a))
	var rw := tw * (0.55 + 0.35 * a)
	var ry := cy + 12.0 * s
	_cap.draw_line(Vector2((vs.x - rw) * 0.5, ry), Vector2((vs.x + rw) * 0.5, ry), Color(0.62, 0.48, 0.3, 0.6 * a), maxf(1.0, s))
	_cap.draw_string(font, Vector2((vs.x - lw) * 0.5, ry + lsize * 1.45), caption_line, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, Color(0.78, 0.72, 0.62, 0.85 * a))

## Quest: the active quest's title in brass small caps over its objective in bone-white, top
## left, small and quiet; a banner (begun / complete, with the objective or the reward) rides
## high in the centre for a few seconds when a step opens or closes a quest.
func _draw_quest() -> void:
	var ql = player.get_node_or_null("Quests")
	if ql == null:
		return
	var vs := _quest.get_viewport_rect().size
	var s := vs.y / 1080.0
	var font := ThemeDB.fallback_font
	var qa: String = ql.active()
	if qa != "":
		var x := 42.0 * s
		var y := 58.0 * s
		var tsize := int(17.0 * s)
		var osize := int(21.0 * s)
		var t := " ".join(ql.title(qa).to_upper().split(""))
		var ow := font.get_string_size(quest_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, osize).x
		for i in 4:   # feathered dark band behind the text
			_quest.draw_rect(Rect2(x - (18.0 - i * 4.0) * s, y - tsize * 1.5, ow + (36.0 - i * 8.0) * s, tsize * 1.5 + osize * 1.6), Color(0.01, 0.01, 0.008, 0.08))
		_quest.draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize, Color(0.74, 0.58, 0.36, 0.9))
		_quest.draw_line(Vector2(x, y + 7.0 * s), Vector2(x + 46.0 * s, y + 7.0 * s), Color(0.62, 0.48, 0.3, 0.6), maxf(1.0, s))
		_quest.draw_string(font, Vector2(x, y + osize * 1.35), quest_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, osize, Color(0.88, 0.83, 0.72, 0.92))
	if ql.banner_t > 0.0:
		var a := clampf(ql.banner_t / 0.8, 0.0, 1.0) * clampf((6.0 - ql.banner_t) / 0.5, 0.0, 1.0)
		var bsize := int(30.0 * s)
		var lsize := int(20.0 * s)
		var bt: String = ql.banner_title
		var bl: String = ql.banner_line
		var bw := font.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, bsize).x
		var lw := font.get_string_size(bl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize).x
		var cy := vs.y * 0.2
		var w := maxf(bw, lw) + 140.0 * s
		var band := Rect2((vs.x - w) * 0.5, cy - bsize * 1.3, w, bsize * 1.3 + lsize * 2.2)
		for i in 6:
			_quest.draw_rect(band.grow_individual(-i * w * 0.06, 0, -i * w * 0.06, 0), Color(0.01, 0.01, 0.008, 0.07 * a))
		_quest.draw_string(font, Vector2((vs.x - bw) * 0.5, cy), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, bsize, Color(0.9, 0.85, 0.74, 0.95 * a))
		_quest.draw_line(Vector2((vs.x - bw * 0.7) * 0.5, cy + 12.0 * s), Vector2((vs.x + bw * 0.7) * 0.5, cy + 12.0 * s), Color(0.62, 0.48, 0.3, 0.6 * a), maxf(1.0, s))
		_quest.draw_string(font, Vector2((vs.x - lw) * 0.5, cy + 12.0 * s + lsize * 1.45), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, Color(0.78, 0.72, 0.62, 0.85 * a))

## Talk: the key hint is a small brass-rimmed keycap and a verb, low and centred; a spoken line
## is a subtitle near the bottom edge -- the speaker's name in brass small caps, the words in
## bone-white -- over a feathered dark band, wrapped to two lines at most.
func _draw_talk() -> void:
	var vs := _talk.get_viewport_rect().size
	var s := vs.y / 1080.0
	var font := ThemeDB.fallback_font
	if _prompt_a > 0.001 and prompt_key != "":
		var a := _prompt_a
		var ksize := int(20.0 * s)
		var vsize := int(22.0 * s)
		var kw := maxf(font.get_string_size(prompt_key, HORIZONTAL_ALIGNMENT_LEFT, -1, ksize).x + 16.0 * s, 30.0 * s)
		var vw := font.get_string_size(prompt_verb, HORIZONTAL_ALIGNMENT_LEFT, -1, vsize).x
		var w := kw + 12.0 * s + vw
		var x := (vs.x - w) * 0.5
		var y := vs.y * 0.82
		var key := Rect2(x, y - 22.0 * s, kw, 30.0 * s)
		_talk.draw_rect(key.grow(6.0 * s).grow_individual(0, 0, vw + 12.0 * s, 0), Color(0.01, 0.01, 0.008, 0.35 * a))
		_talk.draw_rect(key, Color(0.03, 0.025, 0.02, 0.75 * a))
		_talk.draw_rect(key, Color(0.62, 0.48, 0.3, 0.8 * a), false, maxf(1.0, 1.4 * s))
		_talk.draw_string(font, Vector2(x + (kw - font.get_string_size(prompt_key, HORIZONTAL_ALIGNMENT_LEFT, -1, ksize).x) * 0.5, y), prompt_key, HORIZONTAL_ALIGNMENT_LEFT, -1, ksize, Color(0.93, 0.86, 0.72, 0.95 * a))
		_talk.draw_string(font, Vector2(x + kw + 12.0 * s, y), prompt_verb, HORIZONTAL_ALIGNMENT_LEFT, -1, vsize, Color(0.86, 0.80, 0.68, 0.9 * a))
	if _say_a > 0.001 and say_line != "":
		var a := _say_a * _say_a * (3.0 - 2.0 * _say_a)
		var nsize := int(19.0 * s)
		var lsize := int(27.0 * s)
		var maxw := minf(vs.x * 0.62, 1100.0 * s)
		var lines := _wrap(font, say_line, lsize, maxw)
		var lh := lsize * 1.35
		var who := " ".join(say_speaker.to_upper().split(""))
		var y0 := vs.y - 70.0 * s - lh * lines.size()
		var bw := maxw + 140.0 * s
		var band := Rect2((vs.x - bw) * 0.5, y0 - nsize * 1.9, bw, nsize * 1.9 + lh * lines.size() + 22.0 * s)
		for i in 6:
			var g := band.grow_individual(-i * bw * 0.06, 0, -i * bw * 0.06, 0)
			_talk.draw_rect(g, Color(0.01, 0.01, 0.008, 0.08 * a))
		var nw := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, nsize).x
		_talk.draw_string(font, Vector2((vs.x - nw) * 0.5, y0 - nsize * 0.5), who, HORIZONTAL_ALIGNMENT_LEFT, -1, nsize, Color(0.80, 0.63, 0.40, 0.9 * a))
		for i in lines.size():
			var lw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lsize).x
			var at := Vector2((vs.x - lw) * 0.5, y0 + lh * (i + 0.85))
			_talk.draw_string(font, at + Vector2(0, 2.0 * s), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, Color(0, 0, 0, 0.55 * a))
			_talk.draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, Color(0.94, 0.91, 0.84, 0.97 * a))

static func _wrap(font: Font, text: String, size: int, maxw: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for w in text.split(" "):
		var t := w if cur == "" else cur + " " + w
		if cur != "" and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > maxw:
			out.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out

func reticle_visible() -> bool:
	return _lock_a > 0.5 and reticle_screen.x >= 0.0

## Lock-on marker: a small bone-white point in a thin ring at the target's chest, with a dark
## halo so it reads on bright grass and night alike. A fresh lock pops the ring in from wide.
func _draw_reticle() -> void:
	reticle_screen = Vector2(-1, -1)
	var lt := player.lock_target
	if _lock_a <= 0.01 or lt == null or not is_instance_valid(lt) or not lt.has_method("hurt_capsule"):
		return
	var cam := player.camera
	var p := Player.lock_point(lt)
	if cam.is_position_behind(p):
		return
	var c := cam.unproject_position(p)
	var vs := _reticle.get_viewport_rect().size
	if not Rect2(Vector2.ZERO, vs).has_point(c):
		return
	reticle_screen = c
	var s := vs.y / 1080.0
	var a := _lock_a
	var e := _lock_pop * _lock_pop
	var ring := (9.0 + 22.0 * e + 0.8 * sin(_lock_t * 4.0)) * s
	_reticle.draw_circle(c, 5.0 * s, Color(0, 0, 0, 0.35 * a))
	_reticle.draw_circle(c, 3.2 * s, Color(0.96, 0.92, 0.82, 0.95 * a))
	_reticle.draw_arc(c, ring, 0.0, TAU, 40, Color(0, 0, 0, 0.3 * a), maxf(3.0 * s, 2.0), true)
	_reticle.draw_arc(c, ring, 0.0, TAU, 40, Color(0.93, 0.80, 0.50, (0.75 - 0.4 * e) * a), maxf(1.4 * s, 1.0), true)

func visible_alpha() -> float:
	return _alpha

func _draw_bars() -> void:
	if _alpha <= 0.001:
		return
	var vs := _bars.get_viewport_rect().size
	var s := vs.y / 1080.0                    # authored at 1080p
	var x := 64.0 * s
	var y := vs.y - 92.0 * s
	var w := 360.0 * s
	_bar(Rect2(x, y, w, maxf(7.0 * s, 5.0)), player.health / player.health_max, _hp_lag,
		Color(0.62, 0.11, 0.09), Color(0.86, 0.72, 0.55))
	var st_w := w * 0.82
	_bar(Rect2(x, y + maxf(16.0 * s, 11.0), st_w, maxf(5.0 * s, 4.0)), player.stamina / player.stamina_max, _st_lag,
		Color(0.93, 0.80, 0.50), Color(0.55, 0.50, 0.42))

func _bar(r: Rect2, v: float, lag: float, fill: Color, lost: Color) -> void:
	var a := _alpha
	var edge := Color(0.55, 0.45, 0.30, 0.55 * a)       # thin brass rim
	_bars.draw_rect(r.grow(1.5), Color(0.02, 0.02, 0.02, 0.7 * a))
	_bars.draw_rect(r.grow(1.5), edge, false, 1.0)
	_bars.draw_rect(Rect2(r.position, Vector2(r.size.x * lag, r.size.y)), Color(lost, 0.55 * a))
	# fill with a faint vertical gradient (lighter top edge) so it is not a flat strip
	var fr := Rect2(r.position, Vector2(r.size.x * v, r.size.y))
	_bars.draw_rect(fr, Color(fill, 0.92 * a))
	_bars.draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(1.0, r.size.y * 0.3))), Color(fill.lightened(0.35), 0.6 * a))
