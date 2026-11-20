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
# outermost counters sit at x = +-6.3, so the player has to be able to walk
# right up to them.
const CHAR_X := 7.2
const CHAR_Z_MIN := -2.9
const CHAR_Z_MAX := 5.4

# Keep the camera this far away from whatever it would otherwise touch.
const WALL_MARGIN := 0.25

var target: Node3D
## The kitchen's cooking line (ingredients, prep table, oven, counter) sits on
## the +Z side of the room, so the camera starts looking that way.
var yaw := PI
var pitch := -0.18
var camera: Camera3D
## Capturing the mouse warps the pointer into the window, which arrives as one
## huge relative motion. The first frames after a capture are ignored so the
## view does not spin away from the cooking line when the game starts.
var _mouse_settle := 0
## No single mouse event may move the camera further than this, so a stray
## warp can never fling the view around.
const MAX_MOUSE_STEP := 90.0

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
	_mouse_settle = 12
	print("Camera rig set up, mouse captured")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _mouse_settle > 0:
			return
		var rel: Vector2 = (e as InputEventMouseMotion).relative.limit_length(MAX_MOUSE_STEP)
		yaw -= rel.x * 0.0028
		pitch = clampf(pitch - rel.y * 0.0025, -0.9, 0.6)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_settle = 12
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_settle = 12

func _process(_delta: float) -> void:
	if _mouse_settle > 0:
		_mouse_settle -= 1
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position + Vector3(0, HEIGHT, 0)
	rotation = Vector3(pitch, yaw, 0)

	# The boom is solved in world space and then written as a *local*
	# position. Writing the camera's global position instead would overwrite
	# the offset every frame, so the boom would shrink a little more each
	# time until the camera collapsed into the character and the view
	# flipped into first person.
	var boom := _boom_length()
	var close := clampf((CLOSE_DISTANCE - boom) / CLOSE_DISTANCE, 0.0, 1.0)

	# Where the camera wants to be: behind the player, lifted when the boom
	# is short.
	var want := global_transform * Vector3(0, 0, boom)
	want.y += close * CLOSE_LIFT

	# Convert back into the rig's local space. The camera is a child of the
	# rig, so this is what puts it exactly where we want it.
	camera.position = global_transform.affine_inverse() * want

	# When the boom is short (the player is backed against a wall) tilt the
	# camera down so it looks over the player's shoulder rather than at the
	# back of their head.
	camera.rotation_degrees = Vector3(-8.0 - 32.0 * close, 0, 0)

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
	out.x = clampf(out.x, -CHAR_X, CHAR_X)
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
