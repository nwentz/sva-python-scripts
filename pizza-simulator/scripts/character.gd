extends CharacterBody3D
## Base character controller. WASD move (camera-relative), Space jump.

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const SPRINT_SPEED := 8.0
const ACCELERATION := 10.0
const FRICTION := 15.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	input = input.limit_length(1.0)

	var dir := Vector3.ZERO
	if input != Vector2.ZERO:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var fwd := -cam.global_basis.z; fwd.y = 0.0
			var right := cam.global_basis.x; right.y = 0.0
			dir = (fwd * -input.y + right * input.x).normalized()
		else:
			dir = Vector3(input.x, 0.0, input.y).normalized()

	# Apply acceleration and friction
	var current_speed := SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed = SPRINT_SPEED

	# Apply horizontal movement with acceleration
	var target_velocity_x = dir.x * current_speed
	var target_velocity_z = dir.z * current_speed

	velocity.x = move_toward(velocity.x, target_velocity_x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity_z, ACCELERATION * delta)

	move_and_slide()

	if dir != Vector3.ZERO:
		var target := global_position + dir
		target.y = global_position.y
		if global_position.distance_squared_to(target) > 0.0001:
			look_at(target, Vector3.UP)
