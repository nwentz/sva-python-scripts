extends Node3D
## Third-person orbit camera. Sits behind the character and looks at it.

const DISTANCE := 3.2
const HEIGHT := 1.55

# Keep the camera inside the kitchen
const BOUNDS_X := 7.2
const BOUNDS_Z_MIN := -8.2
const BOUNDS_Z_MAX := 8.2

var target: Node3D
var yaw := 0.0
var pitch := -0.18
var camera: Camera3D

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
	print("Camera rig set up, mouse captured")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.0028
		pitch = clampf(pitch - e.relative.y * 0.0025, -0.9, 0.6)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position + Vector3(0, HEIGHT, 0)
	rotation = Vector3(pitch, yaw, 0)
	# Clamp the camera inside the room
	if camera:
		camera.global_position.x = clampf(camera.global_position.x, -BOUNDS_X, BOUNDS_X)
		camera.global_position.z = clampf(camera.global_position.z, BOUNDS_Z_MIN, BOUNDS_Z_MAX)
