extends Node3D
## Third-person orbit camera. Sits behind the character and looks at it.

const DISTANCE := 3.0
const HEIGHT := 1.55

## The boom never gets shorter than this, so the view always stays third
## person even when the player is backed against a wall.
const MIN_BOOM := 0.9
## Below this distance the camera lifts and tilts down so it looks over the
## player's shoulder instead of into the back of their head.
const CLOSE_DISTANCE := 2.6
## How high the camera is lifted when it is squeezed against a wall.
const CLOSE_LIFT := 0.9

# Inner faces of the room walls - the camera must stay inside these.
const ROOM_X := 8.35
const ROOM_Z_MIN := -3.2
const ROOM_Z_MAX := 5.9

# How far the character may stray from the middle of the kitchen. The
# outermost counters sit at x = +-6.3 with a 1.4 m footprint (edge at 7.0),
# and the counter row starts at z = 4.3. The capsule radius is 0.3, so the
# centre has to stop short of both or the clamp would push the player back
# into a station.
const CHAR_X_MIN := -7.2
const CHAR_X_MAX := 6.6
const CHAR_Z_MIN := -2.9
const CHAR_Z_MAX := 4.2

# Keep the camera this far away from whatever it would otherwise touch.
const WALL_MARGIN := 0.25

var target: Node3D
## The kitchen's cooking line (ingredients, prep table, oven, counter) sits on
## the +Z side of the room, so the camera starts looking that way.
var yaw := PI
var pitch := -0.18
var camera: Camera3D
## Capturing the mouse warps the pointer into the window, which arrives as a
## burst of huge relative motions. The first frames after a capture are
## ignored, and any single event bigger than a real mouse flick is dropped,
## so the view does not spin away from the cooking line when the game starts.
var _mouse_settle := 0
## No single mouse event may move the camera further than this.
const MAX_MOUSE_STEP := 60.0

## While the player kneads the dough the camera leaves the third-person rig
## and moves in for a close-up of the pizza on the prep table. The blend is
## eased so the cut never snaps.
var focus_target: Node3D = null
var focus_blend := 0.0
## Remember the last point so the blend can ease back out after the target is
## cleared, without dereferencing a freed pizza.
var focus_point := Vector3.ZERO
const FOCUS_SPEED := 2.5

func focus_on(p: Node3D) -> void:
	focus_target = p
	focus_point = p.global_position

func clear_focus() -> void:
	focus_target = null
	# Snap back so aiming is never left pointing at the prep table from the
	# close-up; the eased blend is only used while moving *into* the dough.
	focus_blend = 0.0
	# Ignore the mouse for a moment. Otherwise the circular motions used to
	# spread sauce spill straight into the orbit camera as it returns.
	_mouse_settle = 30

func setup(t: Node3D) -> void:
	target = t
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 70.0
		camera.position = Vector3(0, 0, DISTANCE)
		camera.rotation_degrees = Vector3(-8, 0, 0)
		add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_settle = 30
	print("Camera rig set up, mouse captured")

func _unhandled_input(e: InputEvent) -> void:
	# The kneading close-up is a short cinematic beat: the player cannot orbit
	# the camera while it is active.
	if focus_target != null:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _mouse_settle > 0:
			# Keep ignoring motion while the player is still waving the mouse
			# around after a close-up; only a quiet pause releases the camera.
			_mouse_settle = mini(_mouse_settle + 4, 90)
			return
		var raw: Vector2 = (e as InputEventMouseMotion).relative
		if raw.length() > MAX_MOUSE_STEP:
			# A pointer warp, not a real movement.
			return
		yaw -= raw.x * 0.0028
		pitch = clampf(pitch - raw.y * 0.0025, -0.9, 0.6)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_settle = 30
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_settle = 30

func _process(delta: float) -> void:
	if _mouse_settle > 0:
		_mouse_settle -= 1
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position + Vector3(0, HEIGHT, 0)
	rotation = Vector3(pitch, yaw, 0)

	# The boom is solved in world space and then converted back into the
	# rig's local space. Writing a global position as a local one would make
	# the boom collapse into the character a little more every frame.
	var boom := _boom_length()
	var close := clampf((CLOSE_DISTANCE - boom) / CLOSE_DISTANCE, 0.0, 1.0)
	var want := global_transform * Vector3(0, 0, boom)
	want.y += close * CLOSE_LIFT

	# The normal third-person shot. When the boom is short (the player is
	# backed against a wall) it tilts down over the player's shoulder.
	var cam_pitch := -8.0 - 32.0 * close
	var normal := Transform3D(global_transform.basis * Basis.from_euler(
		Vector3(deg_to_rad(cam_pitch), 0, 0)), want)

	# Kneading swaps this for a close-up of the dough on the prep table.
	var want_focus := 0.0
	if focus_target != null and is_instance_valid(focus_target):
		want_focus = 1.0
		focus_point = focus_target.global_position
	focus_blend = move_toward(focus_blend, want_focus, delta * FOCUS_SPEED)

	if focus_blend > 0.001:
		# Sit *in front of* and above the player, who is standing just behind
		# the prep table. The old camera landed right at chef-hat height and
		# the hat filled the lens. Looking steeply down also keeps the whole
		# dough in frame.
		var closeup := Transform3D(Basis(), focus_point + Vector3(0, 1.55, -0.85))
		closeup = closeup.looking_at(focus_point + Vector3(0, 0.02, 0), Vector3.UP)
		normal = normal.interpolate_with(closeup, focus_blend)

	camera.global_transform = normal
	camera.fov = lerp(70.0, 52.0, focus_blend)

## How far the camera can sit behind the character before it would leave the
## room or push through a wall. The boom is shortened along its own axis, so
## the camera always stays directly behind the player.
func _boom_length() -> float:
	var boom := DISTANCE

	# Walls and counters: stop the camera in front of whatever it hits.
	var wall := _wall_distance()
	if wall < boom:
		boom = wall

	# The camera must never end up outside the room - that would show the
	# player the inside of a wall.
	var dir := global_transform.basis * Vector3(0, 0, 1)
	if absf(dir.x) > 0.0001:
		var t_x := ((ROOM_X - global_position.x) / dir.x) if dir.x > 0.0 else ((-ROOM_X - global_position.x) / dir.x)
		boom = minf(boom, t_x)
	if absf(dir.z) > 0.0001:
		var t_z := ((ROOM_Z_MAX - global_position.z) / dir.z) if dir.z > 0.0 else ((ROOM_Z_MIN - global_position.z) / dir.z)
		boom = minf(boom, t_z)

	return maxf(boom, MIN_BOOM)

## Distance from the rig to the first wall along the boom, or DISTANCE when
## the way is clear.
func _wall_distance() -> float:
	var to_cam := global_transform.basis * Vector3(0, 0, DISTANCE)
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + to_cam)
	q.exclude = _excluded()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return DISTANCE
	var d: float = global_position.distance_to(hit["position"])
	return maxf(d - WALL_MARGIN, 0.0)

## Keeps the character inside the kitchen. The bounds leave room for the
## camera behind the player and still let them walk up to every station.
func clamp_target(p: Vector3) -> Vector3:
	var out := p
	out.x = clampf(out.x, CHAR_X_MIN, CHAR_X_MAX)
	out.z = clampf(out.z, CHAR_Z_MIN, CHAR_Z_MAX)
	return out

## The player and everything they carry must not block the camera.
func _excluded() -> Array[RID]:
	var out: Array[RID] = []
	if target == null or not is_instance_valid(target):
		return out
	if target is CollisionObject3D:
		out.append((target as CollisionObject3D).get_rid())
	_collect_bodies(target, out)
	return out

func _collect_bodies(node: Node, out: Array[RID]) -> void:
	for c in node.get_children():
		if c is CollisionObject3D:
			out.append((c as CollisionObject3D).get_rid())
		_collect_bodies(c, out)
