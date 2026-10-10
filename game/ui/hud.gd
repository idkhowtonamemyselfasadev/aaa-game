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

func _ready() -> void:
	layer = 5
	player = get_parent() as Player
	_bars = Control.new()
	_bars.name = "Bars"
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

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
