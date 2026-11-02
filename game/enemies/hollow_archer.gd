class_name HollowArcher
extends HollowSoldier
## Ashen Archer: a Hollow that was a bowman and still carries its yew self bow. It sees the hero
## from farther off and keeps its distance. Rule changes against the spear soldier:
##  SHOT. Standing off between BACK_OFF and SHOOT_MAX it turns side-on, raises the bow, nocks
##    and draws to the jaw, then holds the draw for a beat that is never the same length
##    (HOLD_MIN..HOLD_MAX) while it tracks the hero; the ember runs up the arrow and the
##    bodkin glints, the aim freezes, and it looses. The arrow flies straight at where the
##    hero's chest was on the glint: keep moving across the aim on the glint and it goes
##    behind you; stand still or run straight at it and it lands. A roll as it arrives lets it
##    pass, and a heavy timed on its arrival turns it.
##  KEEPS ITS DISTANCE. Closer than BACK_OFF it walks backward while facing the hero (slower
##    than the hero runs: it can be caught), and draws again once it has room.
##  STAVE. Crowded inside SHOVE_IN it swings the bow stave like a club (the soldier's flat
##    sweep, shorter and weaker), then backs off again.
##  HIGH GROUND. It takes its post on the highest turf near where it was set (a knoll it
##    can see the meadow from), and when it backs off it bends its retreat uphill: of the
##    ways that lead away from the hero it takes the one that climbs, so a hero chasing it
##    runs uphill into its next draw.
##  RELOAD. After the loose it lowers the bow and reaches for the next arrow: the punish
##    window for a hero who closed in during the draw.
##  COVER. If a trunk or a rock stands within COVER_REACH after the loose, it nocks the next
##    arrow walking to the far side of it, out of the hero's line, waits there a beat
##    (COVER_WAIT_MIN..MAX), then steps out to the side to draw. A hero who rushes the cover
##    while it hides gets there with the bow down; one who flanks it is seen and drawn on.
##    Cottage walls, dry-stone walls and banks count too: it probes a ring of spots round
##    itself for one hard behind something solid (WALL_HUG) that shuts the hero's line, and
##    takes whichever cover, trunk or wall, is the shorter walk.

const ARCHER_HP := 70.0
const ARCHER_POISE := 22.0
const SHOT_MOVE := 2
const SHOOT_MAX := 17.0          # farther than this it walks closer
const BACK_OFF := 5.5            # closer than this it walks backward
const SHOVE_IN := 2.2            # closer than this it clubs with the stave
const BACK_SPEED := 1.7          # slower than the hero's run (it can be caught)
const RAISE_T := 0.42            # s to bring the bow up and nock
const DRAW_T := 0.55             # s to draw to the jaw
const HOLD_MIN := 0.2            # s held at full draw before the glint (random each shot)
const HOLD_MAX := 0.75
const GLINT_T := 0.3             # s of glint; the aim freezes when it starts
const LOOSE_T := 0.14
const RELOAD_T := 0.85
const SHOT_DAMAGE := 18.0
const STAVE_REACH := 1.9
const AIM_TWIST := -55.0         # degrees the chest turns side-on to draw (left shoulder to the hero)
const BOW_ARM := 0.62            # m from the left shoulder to the bow hand at full extension
const STAND_REACH := 16.0        # m from where it was set that it looks for a sunny knoll to stand on
const STAND_MIN_GAIN := 0.15     # a knoll must be at least this much higher to be worth the move
const RETREAT_FAN := [0.0, -0.5, 0.5, -0.95, 0.95]  # radians off straight-away it weighs when backing
const RETREAT_LOOK := 2.0        # m ahead it samples the turf for each way
const STAND_CLEAR := 4.5         # m its post keeps from any tree or rock (trunk, roots and the line of sight)
const SUN_HOURS := [8.0, 10.0, 12.0, 14.0, 16.0]   # day hours it scores its post's sunlight at
const SUN_W := 3.0               # score for a post in sun all day (vs 1.0 per metre of height)
const CROWN_DEPTH := 9.0         # m of leaves above the lowest leaves of an oak crown
const UPHILL_W := 1.6            # score per metre of climb (vs 1.0 for heading straight away)
const LOS_EYE := 1.5              # m above its feet the line of sight is cast from (the bow hand)
const LOS_STEPS := [1.6, -1.6, 3.2, -3.2, 4.8, -4.8]   # m sideways it tries for a clear line
const LOS_RETHINK := 0.5          # s between searches for a clear spot
const LOS_LOSE_T := 0.35          # s the line may stay shut mid-draw before it lowers the bow
const COVER_REACH := 7.0         # m from where it loosed it looks for a trunk or rock to hide behind
const COVER_BEHIND := 1.15        # m beyond the trunk/rock centre it stands to hide
const COVER_FAN := [0.0, 0.45, -0.45, 0.9, -0.9]   # radians round the trunk off straight-behind
const COVER_WAIT_MIN := 1.0       # s it waits in cover before stepping out
const COVER_WAIT_MAX := 2.0
const WALL_RINGS := [1.5, 2.25, 3.0, 3.75, 4.5, 5.5, 6.5]   # m out it probes for a spot behind a wall
const WALL_SPOKES := 20           # spots per ring
const WALL_HUG := 2.2             # m: the solid that hides it must stand this close toward the hero
const WALL_ROOM := 0.45           # m of free space it needs round the spot (its body)
const COVER_GO_T := 3.5           # s it may take to reach cover before it gives up on it
const ANCHOR := Vector3(0.05, 1.58, 0.06)  # the drawing hand's anchor under the jaw (body space)

# shaft-rig poses for the carry (bow held across the body, upper limb up and forward)
const CARRY := [24.0, 62.0, Vector3(0.12, 1.36, 0.42), 6.0, 0.0, 0.5]

## the bow comes up and the arrow is nocked (foley: a creak of the stave, a rustle)
signal drew(point: Vector3)
## the arrow leaves the string (foley: the string's slap and the shaft's hiss)
signal loosed(point: Vector3, arrow: HollowArrow)
## an arrow it loosed ended its flight: "hit", "parried", "dodged", "perfect", "ground"
signal arrow_landed(point: Vector3, result: String)

var bow: HollowBow
var shots := 0
var shot_hits := 0
var last_hold := 0.0
var last_arrow: HollowArrow
var last_arrow_result := ""
var backsteps := 0.0             # metres it has walked backward to keep its distance
var _hold := 0.4
var _aim_k := 0.0                # 0 bow on the carry .. 1 raised at the aim
var _draw := 0.0
var _aim_pitch := 0.0            # degrees above level to the hero's chest
var _aim_point := Vector3.ZERO   # the world point the arrow flies at (frozen on the glint)
var _rng := RandomNumberGenerator.new()
var terrain: Terrain
var stand_gain := 0.0            # m its post stands above the turf where it was set
var retreat_climb := 0.0         # m it has climbed while backing off (bots)
var retreat_dir := Vector3.ZERO  # the way it is backing (smoothed, world xz)
var sun_lit := 1.0               # share of SUN_HOURS its post stands in sun (bots)
var _flora: Flora
var obstacles: Array[Vector3] = []   # tree and rock centres it keeps its post and its retreat clear of
var sidesteps := 0               # bots: times it moved off to find a clear line on the hero
var blocked_draws := 0           # bots: draws it lowered because the hero went behind cover
var los_clear := true            # the line to the hero's chest was clear at the last check
var _los_spot := Vector3.INF     # where it is walking to get a clear line (INF: none)
var _los_think := 0.0
var _seeking := false            # walking off to a clear spot since the line last shut
var _los_shut := 0.0             # s the line has been shut during this draw
var covers := 0                  # bots: times it reached cover and hid
var in_cover := false            # standing hidden behind a trunk or rock right now
var wall_covers := 0               # bots: times the cover was a wall/house/bank, not a trunk or rock
var cover_by := ""                # bots: the name of the solid the wall probe hid behind
var wall_cover_on := true        # bots switch the wall probe off to test trunk cover alone
var cover_is_wall := false        # the current cover spot came from the wall probe
var cover_hidden := 0.0          # bots: s of the last wait in cover with the line shut
var _want_cover := false         # set by the loose: look for cover before the next draw
var _cover_spot := Vector3.INF
var _cover_t := 0.0              # s walking to cover, then s left to wait in it

## True when nothing solid (turf, a wall, a trunk, a rock) stands between a bow held at
## `from` and `target`.
func clear_line(from: Vector3, target: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * LOS_EYE, target, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## The nearest spot to the side (across the line to the hero) with a clear line on the
## hero's chest that it can walk to without going through anything; INF when none.
func _find_clear_spot(to: Vector3) -> Vector3:
	var p := global_position
	var across := Vector3.UP.cross(to.normalized()).normalized()
	var target := _chest_target()
	for off in LOS_STEPS:
		var q: Vector3 = p + across * float(off)
		if terrain:
			q.y = terrain.height_at(q.x, q.z)
		if (q - _home).length() > give_up - 2.0 or _clearance(q) < 1.4:
			continue
		var w := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.9, q + Vector3.UP * 0.9, 1)
		w.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(w).is_empty():
			continue                           # a wall or trunk between here and there
		if clear_line(q, target):
			return q
	return Vector3.INF

## With the line on the hero shut: strafe to a clear spot, or close in round the corner.
func _seek_line(to: Vector3, dist: float) -> Vector3:
	_los_think -= get_physics_process_delta_time()
	if _los_think <= 0.0 or _los_spot == Vector3.INF:
		_los_think = LOS_RETHINK
		var s := _find_clear_spot(to)
		if s != Vector3.INF and not _seeking:
			sidesteps += 1
			_seeking = true
		_los_spot = s
	if _los_spot != Vector3.INF:
		var d := _los_spot - global_position
		d.y = 0.0
		if d.length() > 0.25:
			return d.normalized() * STALK_SPEED
		return Vector3.ZERO
	if dist > BACK_OFF + 1.0:
		return to.normalized() * STALK_SPEED * 0.8
	return Vector3.ZERO

## A spot on the far side of a trunk or rock within COVER_REACH, out of the hero's line, that
## it can walk to straight; INF when none.
func _find_cover(to: Vector3) -> Vector3:
	var p := global_position
	var hero := p + to
	var target := _chest_target()
	var best := Vector3.INF
	var best_d := INF
	for o in obstacles:
		var od := Vector2(o.x - p.x, o.z - p.z).length()
		if od > COVER_REACH or od >= best_d:
			continue
		var behind := Vector3(o.x - hero.x, 0.0, o.z - hero.z)
		if behind.length() < 2.0 or behind.length() > SHOOT_MAX + 2.0:
			continue
		behind = behind.normalized()
		for a in COVER_FAN:
			var q: Vector3 = o + behind.rotated(Vector3.UP, a) * COVER_BEHIND
			if terrain:
				q.y = terrain.height_at(q.x, q.z)
			if (q - _home).length() > give_up - 2.0 or _clearance_except(q, o) < 1.0:
				continue
			var w := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.9, q + Vector3.UP * 0.9, 1)
			w.exclude = [get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(w).is_empty():
				continue                       # would have to walk through it
			if clear_line(q, target):
				continue                       # not hidden there
			best = q
			best_d = od
			break
	cover_is_wall = false
	var wq := _find_wall_cover(to, minf(best_d, COVER_REACH)) if wall_cover_on else Vector3.INF
	if wq != Vector3.INF:
		cover_is_wall = true
		return wq
	return best

func _ray_hit(a: Vector3, b: Vector3) -> Dictionary:
	var w := PhysicsRayQueryParameters3D.create(a, b, 1)
	w.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(w)

## A spot within `reach` hard behind anything solid on layer 1 (a cottage, a wall, a bank)
## that shuts the hero's line and can be walked to straight; INF when none nearer than
## `reach`. Rings are probed inside out, so the first hit is the shortest walk.
func _find_wall_cover(to: Vector3, reach: float) -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var p := global_position
	var target := _chest_target()
	var away := Vector3(-to.x, 0.0, -to.z).normalized()
	for r in WALL_RINGS:
		if float(r) >= reach:
			break
		for i in WALL_SPOKES:
			# spokes from straight away from the hero outwards, alternating sides
			var k := (i + 1) / 2
			var sgn := 1.0 if i % 2 == 0 else -1.0
			var a := sgn * float(k) * TAU / float(WALL_SPOKES)
			var q: Vector3 = p + away.rotated(Vector3.UP, a) * float(r)
			if terrain:
				q.y = terrain.height_at(q.x, q.z)
			if (q - _home).length() > give_up - 2.0 or _clearance(q) < 1.0:
				continue
			var waist := Vector3.UP * 0.9
			var step := q - p
			step.y = 0.0
			var past := q + step.normalized() * WALL_ROOM
			past.y = q.y
			if not _ray_hit(p + waist, past + waist).is_empty():
				continue                       # through a wall, or no room to stand
			var eye := q + Vector3.UP * LOS_EYE
			var hug := _ray_hit(eye, target)
			if hug.is_empty():
				continue                       # in plain sight there
			var hd: float = (hug.position - eye).length()
			if hd > WALL_HUG or hd < WALL_ROOM:
				continue                       # nothing close to hide behind, or nose to the wall
			cover_by = str(hug.collider.name) if hug.collider else ""
			return q
	return Vector3.INF

## After the loose: walk to cover, wait out of the line, then let the stalk step out and
## draw. Returns null when it is done with cover (or found none).
func _take_cover(to: Vector3) -> Variant:
	var dt := get_physics_process_delta_time()
	if _cover_spot == Vector3.INF:
		_cover_spot = _find_cover(to)
		_cover_t = 0.0
		in_cover = false
		if _cover_spot == Vector3.INF:
			_want_cover = false
			return null
	if not in_cover:
		var d := _cover_spot - global_position
		d.y = 0.0
		_cover_t += dt
		if _cover_t > COVER_GO_T:
			_end_cover()
			return null
		if d.length() > 0.3:
			return d.normalized() * STALK_SPEED * 1.2
		in_cover = true
		covers += 1
		if cover_is_wall:
			wall_covers += 1
		cover_hidden = 0.0
		_cover_t = _rng.randf_range(COVER_WAIT_MIN, COVER_WAIT_MAX)
	# hidden: wait, unless the hero has come round into sight
	if los_clear:
		_end_cover()
		return null
	cover_hidden += dt
	_cover_t -= dt
	if _cover_t <= 0.0:
		_end_cover()
		return null
	return Vector3.ZERO

func _end_cover() -> void:
	_want_cover = false
	in_cover = false
	_cover_spot = Vector3.INF

func _clearance_except(q: Vector3, skip: Vector3) -> float:
	var m := INF
	for o in obstacles:
		if o != skip:
			m = minf(m, Vector2(o.x - q.x, o.z - q.z).length())
	return m

func _clearance(q: Vector3) -> float:
	var m := INF
	for o in obstacles:
		m = minf(m, Vector2(o.x - q.x, o.z - q.z).length())
	return m

func _ready() -> void:
	health_max = ARCHER_HP
	health = ARCHER_HP
	poise_max = ARCHER_POISE
	guard_pose = CARRY
	engage_delay = 0.6
	sweep_reach = STAVE_REACH
	notice = 18.0
	give_up = 28.0
	super._ready()
	name = "HollowArcher"
	_rng.seed = 4127
	# lighter, leaner ash; the rags a faded earth-red bowman's jerkin
	_set_skin("ash_light", Color(0.36, 0.35, 0.34))
	rags.set_param("cloth_dark", Color(0.08, 0.045, 0.035))
	rags.set_param("cloth_light", Color(0.30, 0.17, 0.12))
	if not rags.mats.is_empty():
		rags.mats[0].set_shader_parameter("wool", 0.7)
		rags.mats[0].set_shader_parameter("weathered", 0.9)
	model.scale = Vector3(1.0, 1.04, 1.0)    # leaner than the spearmen
	spear.mesh = null
	bow = HollowBow.new()
	bow.name = "Bow"
	_wield.add_child(bow)
	bow.arrow_on = true
	_place(guard_pose)

## Set on the turf, then move its post to the highest, sunniest ground within STAND_REACH:
## the knoll it watches from and comes back to, out of the oaks' shadow so it reads against
## the sky.
func plant(t_: Terrain) -> void:
	super.plant(t_)
	terrain = t_
	var flora: Flora = get_parent().get_node_or_null("Flora") if get_parent() else null
	_flora = flora
	if flora:
		obstacles.append_array(flora.tree_positions)
		obstacles.append_array(flora.rock_positions)
	var p := global_position
	var h0 := t_.height_at(p.x, p.z)
	var best := Vector3(p.x, h0, p.z)
	var best_s := h0 + SUN_W * sunlight(best)
	var s0 := best_s
	for ri in range(1, 9):
		var r := STAND_REACH * ri / 8.0
		for ai in 16:
			var a := TAU * ai / 16.0
			var q := Vector3(p.x + sin(a) * r, 0.0, p.z + cos(a) * r)
			q.y = t_.height_at(q.x, q.z)
			# flat enough to stand and draw on, and a little weight on staying near
			if t_.normal_at(q.x, q.z).y < 0.94 or _clearance(q) < STAND_CLEAR:
				continue
			var sc := q.y - 0.02 * r + SUN_W * sunlight(q)
			if sc > best_s:
				best_s = sc
				best = q
	if best_s - s0 >= STAND_MIN_GAIN:
		global_position = best + Vector3.UP * 0.05
		_home = global_position
		stand_gain = best.y - h0
	sun_lit = sunlight(_home)

## Share of SUN_HOURS a figure standing at `q` is in sun: from its chest, march toward the
## sun of each hour (the world's arc: up at 06:00, peak sun_peak_deg at noon) and count it
## shaded if the ray passes through an oak crown (between its lowest leaves and CROWN_DEPTH
## above) or into the turf. The Long Dusk sun is low, so oak shadows reach 20 m and more.
func sunlight(q: Vector3) -> float:
	if _flora == null or terrain == null:
		return 1.0
	var peak := 28.0
	var wl := get_parent()
	if wl and "sun_peak_deg" in wl:
		peak = wl.sun_peak_deg
	var lit := 0
	for hr: float in SUN_HOURS:
		var elev := deg_to_rad(peak) * sin((hr - 6.0) / 12.0 * PI)
		var az := hr / 24.0 * TAU + PI * 0.5
		var d := Basis.from_euler(Vector3(-elev, az, 0.0)).z    # toward the sun
		var o := q + Vector3.UP * 1.4
		var shaded := false
		var t := 1.0
		while t < 60.0 and not shaded:
			var x := o + d * t
			var lo := _flora.leaf_height_at(x.x, x.z)
			if lo > -999.0 and x.y > lo - 0.5 and x.y < lo + CROWN_DEPTH and _flora.shelter_at(x.x, x.z) > 0.3:
				shaded = true
			elif x.y < terrain.height_at(x.x, x.z):
				shaded = true
			t += 1.0
		if not shaded:
			lit += 1
	return float(lit) / SUN_HOURS.size()

## Which way to back off from the hero (world xz, unit): of a fan of ways that lead away, the
## one that climbs most per step, weighed against heading straight away and against straying
## past its tether.
func _retreat_way(to: Vector3) -> Vector3:
	var away := -to.normalized()
	if terrain == null:
		return away
	var p := global_position
	var h := terrain.height_at(p.x, p.z)
	var best := away
	var best_s := -INF
	for a in RETREAT_FAN:
		var d := away.rotated(Vector3.UP, a)
		var q := p + d * RETREAT_LOOK
		var climb := terrain.height_at(q.x, q.z) - h
		var sc := cos(a) + UPHILL_W * climb
		if (q - _home).length() > give_up - 2.0:
			sc -= 2.0
		if _clearance(q) < 1.4:
			sc -= 3.0                          # not backward into a trunk or a rock
		if sc > best_s:
			best_s = sc
			best = d
	return best

func return_to_post() -> void:
	super.return_to_post()
	_aim_k = 0.0
	_draw = 0.0
	if bow:
		bow.arrow_on = true

# --- footwork ---

func _stalk(to: Vector3, dist: float) -> Vector3:
	var ready := t > engage_delay and _facing(to) > 0.9
	if dist < SHOVE_IN and ready:
		_begin_attack(dist)
		return Vector3.ZERO
	los_clear = clear_line(global_position, _chest_target())
	if los_clear:
		_los_spot = Vector3.INF
		_seeking = false
	if dist < BACK_OFF:
		# back away facing the hero; draw anyway if it has been backing a while (pinned)
		if t > 2.4 and ready and dist > SHOVE_IN + 0.6 and los_clear:
			_begin_attack(dist)
			return Vector3.ZERO
		var dt := get_physics_process_delta_time()
		backsteps += BACK_SPEED * dt
		var way := _retreat_way(to)
		retreat_dir = way if retreat_dir == Vector3.ZERO else retreat_dir.lerp(way, minf(dt * 4.0, 1.0)).normalized()
		if terrain:
			var p := global_position
			var q := p + retreat_dir * BACK_SPEED * dt
			retreat_climb += maxf(terrain.height_at(q.x, q.z) - terrain.height_at(p.x, p.z), 0.0)
		return retreat_dir * BACK_SPEED
	retreat_dir = Vector3.ZERO
	if _want_cover:
		var c: Variant = _take_cover(to)
		if c != null:
			return c
	if dist > SHOOT_MAX:
		return to.normalized() * STALK_SPEED * 0.8
	if not los_clear:
		return _seek_line(to, dist)
	if ready:
		_begin_attack(dist)
	return Vector3.ZERO

func _choose(dist: float) -> int:
	var k := force_move
	if k < 0:
		k = SWEEP_MOVE if dist < SHOVE_IN else SHOT_MOVE
	if k == SHOT_MOVE:
		_hold = _rng.randf_range(HOLD_MIN, HOLD_MAX)
		last_hold = _hold
		bow.arrow_on = true
		drew.emit(bow.global_position)
	return k

## True from the raise to the loose (bots, foley, music).
func drawing() -> bool:
	return state == WINDUP and move_kind == SHOT_MOVE

func shot_windup() -> float:
	return RAISE_T + DRAW_T + _hold + GLINT_T

# --- the shot ---

func _chest_target() -> Vector3:
	if _player == null:
		return global_position + body.global_basis.z * 10.0 + Vector3.UP * 1.2
	return _player.global_position + Vector3.UP * 1.15

func _special_tick(delta: float, to: Vector3, _dist: float) -> Array:
	var move := Vector3.ZERO
	var lean := 0.0
	var sink := 0.0
	var ember := 1.0
	match state:
		WINDUP:
			var total := shot_windup()
			var g := clampf((t - RAISE_T - DRAW_T - _hold) / GLINT_T, 0.0, 1.0)
			if g <= 0.0:
				_aim_point = _chest_target()
				# the hero stepped behind something before the glint: hold, then lower the bow
				if clear_line(global_position, _aim_point):
					_los_shut = 0.0
				else:
					_los_shut += delta
					if _los_shut > LOS_LOSE_T:
						_los_shut = 0.0
						blocked_draws += 1
						bow.arrow_on = true
						_enter(STALK)
						return [move, 0.0, 0.0, 1.0]
			# side-on: the body yaws past the hero so the twisted chest (left shoulder) points at it
			var aim_dir := _aim_point - global_position
			aim_dir.y = 0.0
			_turn_to(aim_dir, delta, 7.0 * (1.0 - g))
			var r := clampf(t / RAISE_T, 0.0, 1.0)
			var dr := clampf((t - RAISE_T) / DRAW_T, 0.0, 1.0)
			_aim_k = smoothstep(0.0, 1.0, r)
			_draw = dr * dr * (3.0 - 2.0 * dr)
			# hold tremble at full draw, stronger the longer it holds
			var held := maxf(t - RAISE_T - DRAW_T, 0.0)
			_draw -= 0.02 * sin(t * 37.0) * smoothstep(0.0, 0.3, held)
			_pose = guard_pose
			lean = -0.05 * _aim_k
			sink = 0.05 * _aim_k
			ember = 1.0 + 1.0 * _draw + 2.6 * g
			_update_glint(smoothstep(0.0, 0.35, g) * (1.0 - smoothstep(0.9, 1.0, g)))
			if t >= total:
				_loose()
				_enter(STRIKE)
		STRIKE:
			var u := clampf(t / LOOSE_T, 0.0, 1.0)
			_update_glint(0.0)
			_draw = maxf(0.0, 1.0 - u * 6.0)
			_aim_k = 1.0
			_pose = guard_pose
			lean = -0.05 - 0.04 * sin(PI * u)   # the bow arm kicks with the release
			sink = 0.05
			ember = 3.0 - u
			if u >= 1.0:
				_enter(RECOVER)
		RECOVER:
			var u := clampf(t / RELOAD_T, 0.0, 1.0)
			_draw = 0.0
			_aim_k = 1.0 - smoothstep(0.0, 0.6, u)
			_pose = guard_pose
			lean = -0.05 * _aim_k
			sink = 0.05 * _aim_k
			ember = 1.4 - 0.4 * u
			if u > 0.55:
				bow.arrow_on = true             # the next arrow drawn from the quiver
			if u >= 1.0:
				_enter(STALK)
	return [move, lean, sink, ember]

func _loose() -> void:
	var from := bow.to_global(bow.nock_local + Vector3(0, 0, 0.0)) if bow else global_position + Vector3.UP * 1.5
	var tip := bow.to_global(Vector3(0.012, 0.02, 0.0)) if bow else from + body.global_basis.z
	# the arrow starts at the bow hand (the shaft's middle there) and flies at the frozen aim
	var start := tip.lerp(from, 0.1)
	var d := (_aim_point - start)
	var flight := d.length() / HollowArrow.SPEED
	# aim a touch high for the drop over the flight
	d.y += 0.5 * HollowArrow.DROP * flight * flight
	var a := HollowArrow.loose(get_parent(), start + d.normalized() * HollowBow.ARROW_LEN * 0.5, d.normalized() * HollowArrow.SPEED, self)
	a.damage = SHOT_DAMAGE * damage_mul
	a.landed.connect(_on_arrow_landed.bind(a))
	last_arrow = a
	last_arrow_result = ""
	bow.arrow_on = false
	strikes += 1
	shots += 1
	_resolved = true
	loosed.emit(start, a)

func _on_arrow_landed(at: Vector3, r: String, a: HollowArrow) -> void:
	if a == last_arrow and last_arrow_result == "":
		last_arrow_result = r
		last_result = r if r != "ground" and r != "wall" else "miss"
		if r == "hit":
			shot_hits += 1
		struck.emit(last_result)
	arrow_landed.emit(at, r)

## A blow that staggers or parries it spoils the draw: the arrow is dropped back to the carry.
func _enter(s: int) -> void:
	if s == STALK and state == RECOVER and move_kind == SHOT_MOVE:
		_want_cover = true                     # after the loose: find cover before the next draw
	else:
		_end_cover()
	if s == STAGGER or s == DEAD or (s == STALK and state != RECOVER):
		_aim_k = 0.0
		_draw = 0.0
		if s == STAGGER and bow and move_kind == SHOT_MOVE:
			bow.arrow_on = true
	super._enter(s)

# --- posing ---

## The carry/stave poses come from the soldier's shaft rig (the bow's grip at the left hand,
## the stave along the shaft); the shot blends to an archer's stance: chest side-on, the bow
## arm out along the aim, the string hand drawn back to the anchor under the jaw.
func _place(pose: Array) -> void:
	super._place(pose)
	if bow == null:
		return
	# the bow on the shaft rig
	var d := spear.transform.basis.y.normalized()
	var grip := _grip_l.position          # the bow hand holds the grip wherever the reach clamp put it
	var fwd := Vector3(0, 0, 1) - d * d.z
	if fwd.length() < 1e-3:
		fwd = Vector3.UP
	fwd = fwd.normalized()
	var carry := Transform3D(Basis(d.cross(fwd).normalized(), d, fwd).orthonormalized(), grip)
	var k := _aim_k
	if k <= 0.001:
		bow.transform = carry
		bow.draw = 0.0
		bow.nock_local = Vector3(0, 0, -HollowBow.BRACE)
		return
	# the aim stance, in body space
	var tw := deg_to_rad(lerpf(float(pose[3]), AIM_TWIST, k))
	var sl := SHOULDER.rotated(Vector3.UP, tw)
	var target := body.global_transform.affine_inverse() * _aim_point if _aim_point != Vector3.ZERO else Vector3(0, 1.4, 10)
	var ad := (target - ANCHOR)
	ad.x = 0.0                                   # the aim runs straight ahead of the body
	ad = ad.normalized() if ad.length() > 1e-3 else Vector3.BACK
	ad = Vector3(0, ad.y, absf(ad.z)).normalized()
	_aim_pitch = rad_to_deg(asin(clampf(ad.y, -1.0, 1.0)))
	var reach := lerpf(0.36, BOW_ARM, smoothstep(0.3, 1.0, k))
	var bow_hand := sl + ad * reach
	# the bow is canted a little off vertical, its back toward the hero
	var up := Vector3.UP.rotated(ad, deg_to_rad(-12.0))
	up = (up - ad * up.dot(ad)).normalized()
	var aim_xf := Transform3D(Basis(up.cross(ad).normalized(), up, ad).orthonormalized(), bow_hand)
	# the string hand: on the string at brace, then drawn back along the aim to the anchor
	var at_brace := bow_hand - ad * HollowBow.BRACE
	var anchor := ANCHOR.rotated(Vector3.UP, tw - deg_to_rad(AIM_TWIST))
	var line_anchor := bow_hand - ad * (bow_hand - anchor).dot(ad)
	var string_hand := at_brace.lerp(line_anchor, _draw)
	# blend from the carry to the aim
	var bx := carry.interpolate_with(aim_xf, k)
	bow.transform = bx
	bow.draw = clampf(_draw, 0.0, 1.0)
	bow.nock_local = bow.transform.affine_inverse() * string_hand
	_grip_l.position = _grip_l.position.lerp(bow_hand, k)
	_grip_r.position = _grip_r.position.lerp(string_hand, k)
	if _twist != null:
		_twist.twist = tw
	if _glint != null and _glint.visible:
		_glint.global_position = bow.to_global(Vector3(0.012, 0.02, 0.06))

func _update_glint(a: float) -> void:
	super._update_glint(a)
	if _glint != null and bow != null:
		_glint.global_position = bow.to_global(Vector3(0.012, 0.02, 0.06))
