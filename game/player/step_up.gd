class_name StepUp
## Step-up for a walking CharacterBody3D (the hero, the Hollow soldiers, the Ashen Knight, the
## Stone Sentinel). A capsule's round bottom rides over a lip of ~0.12 m by itself, but a stair
## tread, a plinth course or a kerb stone (0.2-0.3 m) meets it as a wall. Called just before
## move_and_slide: if the body walks into a riser no taller than `max_h`, with room above it and
## a walkable tread behind it, the body is lifted onto the tread so the slide carries it on; the
## lift is returned so the caller can ease the visible body up through it (no pop of the root:
## the hips rise over a few frames while the foot IK keeps the soles on their own ground).

const PROBE := 0.14          # look this far ahead at least (a slow walk still finds the riser)
const CLEAR := 0.012         # a hair over the tread so the slide does not catch its edge
const MIN_RISE := 0.03       # below this the capsule handles it alone

## Returns the rise climbed this tick (0 when no step was taken).
static var why := ""   # debug: why the last try did not step

static func try(cb: CharacterBody3D, delta: float, max_h: float, carry := true) -> float:
	if not cb.is_on_floor() or max_h <= MIN_RISE:
		why = "r1"
		return 0.0
	var hv := Vector3(cb.velocity.x, 0.0, cb.velocity.z)
	var sp := hv.length()
	if sp < 0.08:
		why = "r2"
		return 0.0     # standing (a slow arrival at a spot still steps)
	var dir := hv / sp
	var ahead := dir * maxf(sp * delta, PROBE)
	var xf := cb.global_transform
	var col := KinematicCollision3D.new()
	if not cb.test_move(xf, ahead, col, 0.001):
		why = "r3"
		return 0.0
	var wall_y := cos(cb.floor_max_angle)
	var n := col.get_normal()
	if n.y >= wall_y or n.dot(dir) > -0.2:
		why = "r4"
		return 0.0                     # walkable, or only grazing it: the slide handles it
	if col.get_position().y - xf.origin.y > max_h + 0.02:
		why = "r5"
		return 0.0                     # the contact is above a step: a wall
	# room overhead, then free to move forward at tread height
	if cb.test_move(xf, Vector3.UP * max_h, null, 0.001):
		why = "r6"
		return 0.0
	var up := xf.translated(Vector3.UP * max_h)
	if cb.test_move(up, ahead, null, 0.001):
		why = "r7"
		return 0.0                     # taller than a step
	var fwd := up.translated(ahead)
	var down := KinematicCollision3D.new()
	if not cb.test_move(fwd, Vector3.DOWN * (max_h + 0.05), down, 0.001):
		why = "r8"
		return 0.0                     # nothing to stand on behind the lip
	if down.get_normal().y < wall_y:
		why = "r9"
		return 0.0                     # the far side is a steep face, not a tread
	var rise := max_h - absf(down.get_travel().y)
	if rise < MIN_RISE or rise > max_h:
		why = "r10"
		return 0.0
	# onto the tread where it was found: lifted, and carried on by what this tick's slide will
	# not cover itself (a slow walker's slide would leave the round bottom behind the edge and
	# let it settle back off the corner)
	cb.global_position += Vector3.UP * (rise + CLEAR) + (dir * maxf(ahead.length() - sp * delta, 0.0) if carry else Vector3.ZERO)
	why = ""
	return rise + CLEAR

## Eases the visible body's offset from the root back to it: a dip (< 0, after a step up) about a
## step's rise over the time of a stride (~0.25 s), never faster than the walker could lift its
## hips at its pace (a run up a stair climbs quicker than a walk), so the hips rise with the step
## and not in one tick; a hold (> 0, after a step down) lets the hips down a little quicker, as
## the leading leg reaches for the lower tread and takes the weight. `size` slows a giant in
## proportion.
const DOWN_K := 1.4

static func ease_dip(dip: float, speed: float, delta: float, size: float) -> float:
	if dip == 0.0:
		return 0.0
	var m := absf(dip)
	var k := DOWN_K if dip > 0.0 else 1.0
	var rate := minf(m * 7.0 * k, (0.9 + 0.45 * speed / size) * sqrt(size) * k)
	m = maxf(m - maxf(rate, 0.15 * sqrt(size)) * delta, 0.0)
	return 0.0 if m < 0.002 else signf(dip) * m

## Step-down, called right after move_and_slide: a walker that was on its floor and walked off a
## tread edge, a kerb or a plinth course no deeper than `max_h` is set down on the lower tread at
## once (no fall, no landing) and kept on its floor; a ledge deeper than that is a real drop and
## is left to fall. Returns how far the visible body should be held above the root (>= 0, m):
## the root's whole drop this tick less what the slope under it accounts for, so the caller can
## let the hips down through the step with ease_dip instead of popping them down.
static var steps_down := 0      # bots: every step taken down, any walker
static var last_down_hz := 0.0  # bots: how far the last step down slid the root off the edge (m)

static func step_down(cb: CharacterBody3D, y_pre: float, delta: float, max_h: float, size: float) -> float:
	if cb.velocity.y > 0.5:
		return 0.0                      # a jump, a vault: not a step
	var snapped := 0.0
	if not cb.is_on_floor():
		# the lower tread, under the body's axis (the round bottom may still hang on the edge)
		var o := cb.global_position
		var fell := maxf(y_pre - o.y, 0.0)
		var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 0.3 * size, o + Vector3.DOWN * (max_h - fell + 0.03), cb.collision_mask, [cb.get_rid()])
		var hit := cb.get_world_3d().direct_space_state.intersect_ray(q)
		var wall_y := cos(cb.floor_max_angle)
		if hit.is_empty() or (hit.normal as Vector3).y < wall_y:
			return 0.0                  # nothing within a step below (a ledge: let it fall), or a steep face
		# down onto it, sliding the round bottom off the tread edge it hangs on
		var xf := cb.global_transform
		var motion := Vector3.DOWN * (o.y - (hit.position as Vector3).y + 0.02)
		var landed := false
		for k in 4:
			var col := KinematicCollision3D.new()
			if not cb.test_move(xf, motion, col, 0.001):
				xf.origin += motion
				break
			xf.origin += col.get_travel()
			if col.get_normal().y >= wall_y:
				landed = true
				break
			motion = col.get_remainder().slide(col.get_normal())
			if motion.length() < 0.002:
				break
		var hz := Vector2(xf.origin.x - o.x, xf.origin.z - o.z).length()
		if not landed or hz > 0.2 * size:
			return 0.0                  # it would not settle on the tread: leave it to the fall
		cb.global_position = xf.origin
		cb.velocity.y = 0.0
		cb.apply_floor_snap()
		snapped = o.y - xf.origin.y
		if snapped + fell > MIN_RISE:
			steps_down += 1
		last_down_hz = hz
	var dy := y_pre - cb.global_position.y
	if dy <= 0.004 * size:
		return 0.0
	return maxf(dy - _slope_allow(cb, delta, size), 0.0)

static func _slope_allow(cb: CharacterBody3D, delta: float, size: float) -> float:
	var speed := Vector2(cb.velocity.x, cb.velocity.z).length()
	var o := cb.global_position
	var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 0.3 * size, o + Vector3.DOWN * 0.6 * size, cb.collision_mask, [cb.get_rid()])
	var hit := cb.get_world_3d().direct_space_state.intersect_ray(q)
	var ny := 1.0
	if not hit.is_empty():
		ny = clampf((hit.normal as Vector3).y, 0.3, 1.0)
	return speed * delta * sqrt(1.0 - ny * ny) / ny * 1.15 + 0.004 * size

## How much of a grounded root's rise this tick (`dy`, the lift and the slide together) is a
## riser or a lip rather than the ground's own slope: the slope is read by a ray straight down
## from the body's axis (a stair tread or the flat in front of a riser reads level, so the whole
## climb is eased; a hillside reads as itself, so the hips do not lag on a real slope).
static func lip_excess(cb: CharacterBody3D, dy: float, delta: float, size: float) -> float:
	if dy <= 0.004 * size:
		return 0.0
	return maxf(dy - _slope_allow(cb, delta, size), 0.0)
