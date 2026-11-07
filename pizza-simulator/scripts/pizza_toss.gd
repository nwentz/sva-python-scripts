extends Node3D
class_name PizzaToss

@export var dough_scene: PackedScene
@export var toss_impulse: Vector3 = Vector3(0, 4, -2)
@export var toss_torque: Vector3 = Vector3(2, 0, 1)
@export var spawn_offset: Vector3 = Vector3(0, 1.2, 0)

var active_dough: RigidBody3D = null

func toss_dough() -> void:
	if dough_scene == null:
		push_warning("PizzaToss: no dough_scene assigned")
		return
	if active_dough != null and is_instance_valid(active_dough):
		active_dough.queue_free()
	active_dough = dough_scene.instantiate() as RigidBody3D
	add_child(active_dough)
	active_dough.global_position = global_position + spawn_offset
	active_dough.apply_central_impulse(toss_impulse)
	active_dough.apply_torque_impulse(toss_torque)

func _process(_delta: float) -> void:
	if active_dough == null or not is_instance_valid(active_dough):
		return
	# Freeze once it settles on a surface.
	if active_dough.sleeping:
		active_dough.freeze = true
