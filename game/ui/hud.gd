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

func _process(delta: float) -> void:
	if player == null:
		return
	var hp := player.health / Player.HEALTH_MAX
	var st := player.stamina / Player.STAMINA_MAX
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
	_bar(Rect2(x, y, w, maxf(7.0 * s, 5.0)), player.health / Player.HEALTH_MAX, _hp_lag,
		Color(0.62, 0.11, 0.09), Color(0.86, 0.72, 0.55))
	var st_w := w * 0.82
	_bar(Rect2(x, y + maxf(16.0 * s, 11.0), st_w, maxf(5.0 * s, 4.0)), player.stamina / Player.STAMINA_MAX, _st_lag,
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
