extends Node3D
## Third-person orbit camera on a spring arm.

var target: Node3D

func setup(t: Node3D) -> void:
	target = t
	var arm := get_node_or_null("SpringArm3D") as SpringArm3D
	if arm != null and t is PhysicsBody3D:
		arm.add_excluded_object(t.get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Camera rig set up, mouse captured")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= e.relative.x * 0.0028
		rotation.x = clamp(rotation.x - e.relative.y * 0.0028, -1.2, 0.5)
		print("Camera rotated, yaw:", rotation.y, "pitch:", rotation.x)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		print("Mouse mode toggled")
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("Mouse captured")

func _process(delta: float) -> void:
	if target:
		# Keep the camera above the target
		global_position = target.global_position + Vector3(0, 1.8, 0)
