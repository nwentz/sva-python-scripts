class_name PhysicsDropper
extends Node
## Runtime wrapper around the Physics Placer add-on's PPSim.
##
## Physics Placer is an editor tool, but its PPSim core only touches editor
## APIs behind `Engine.is_editor_hint()` guards, so the simulation itself can be
## driven in-game. This node runs a drop in a throwaway physics bubble and
## reports where the dropped item came to rest.
##
## The bubble's environment is described explicitly by the caller (see
## `drop()`), which keeps the drop predictable: the item lands on exactly the
## surfaces that were declared and nothing else.

signal dropped(node: Node3D, result: Dictionary)

## One surface in the sim bubble.
## Box:  {"kind": "box", "center": Vector3, "size": Vector3}
## Cyl:  {"kind": "cyl", "center": Vector3, "radius": float, "height": float}
class Surface extends RefCounted:
	var kind: String
	var center: Vector3
	var size: Vector3
	var radius: float
	var height: float

	static func box(center: Vector3, size: Vector3) -> Surface:
		var s := Surface.new()
		s.kind = "box"
		s.center = center
		s.size = size
		return s

	static func cyl(center: Vector3, radius: float, height: float) -> Surface:
		var s := Surface.new()
		s.kind = "cyl"
		s.center = center
		s.radius = radius
		s.height = height
		return s

## PPSim normally takes over the global PhysicsServer3D while it runs, which
## would freeze the running game. This subclass keeps the server running and
## only activates the bubble's own space.
class RuntimeSim extends PPSim:
	func _activate_server() -> void:
		PhysicsServer3D.set_active(true)
		var own_space: RID = _viewport.world_3d.space if is_instance_valid(_viewport) else RID()
		if own_space.is_valid():
			PhysicsServer3D.space_set_active(own_space, true)

	func _deactivate_server() -> void:
		pass

var last_result: Dictionary = {}
var _sim: PPSim
var _settings: PPSettings
var _busy := false

func _ready() -> void:
	_settings = PPSettings.new()
	_settings.time_limit = 1.6
	_settings.stop_when_settled = true
	_settings.settle_time = 0.20
	_settings.settle_linear = 0.04
	_settings.settle_angular = 0.08
	_settings.sleep_settled = true
	_settings.retire_settled = true
	_settings.mass = 0.6
	_settings.friction = 0.9
	_settings.bounce = 0.0
	_settings.affect_scene_objects = false
	_settings.env_use_scene_colliders = false
	_settings.env_use_mesh_geometry = false
	_settings.env_radius = 0.0
	_settings.preview_hz = 60.0
	_settings.live_preview = true
	# The bubble lives in its own World3D whose space has no gravity of its own,
	# so let PPSim install an explicit gravity override area.
	_settings.use_project_gravity = false
	_settings.gravity_direction = Vector3.DOWN
	_settings.gravity_magnitude = 9.8

	_sim = RuntimeSim.new()
	_sim.name = "PPSim"
	add_child(_sim)
	_sim.setup(_settings)

func is_busy() -> bool:
	return _busy

## Drops `node` from its current global position and reports the resting spot.
## `surfaces` describes what the item can land on.
func drop(node: Node3D, surfaces: Array) -> void:
	if node == null or _busy:
		return
	_busy = true
	last_result = {"ok": false, "reason": "not started"}
	_sim.reset(true)
	var item := _sim.add_object(node)
	if item == null:
		_busy = false
		last_result = {"ok": false, "reason": "not simulatable"}
		dropped.emit(node, last_result)
		return
	# A body that starts at rest would otherwise fall asleep before gravity
	# could pull it down, so keep it awake until it has actually moved.
	if item.body and is_instance_valid(item.body):
		item.body.can_sleep = false
		item.body.sleeping = false
	_build_environment(surfaces)
	_sim.start(true)
	await _sim.sim_finished
	var final: Transform3D = item.final_global
	_sim.reset(true)
	node.global_transform = final
	_busy = false
	last_result = {"ok": true, "transform": final}
	dropped.emit(node, last_result)

## Builds the bubble's collision world from the given surfaces.
func _build_environment(surfaces: Array) -> void:
	_sim._ensure_viewport()
	_sim._clear_env()
	var env := StaticBody3D.new()
	env.name = "EnvCollision"
	_sim._env_root.add_child(env)
	for s in surfaces:
		if not (s is Surface):
			continue
		var cs := CollisionShape3D.new()
		if s.kind == "box":
			var box := BoxShape3D.new()
			box.size = s.size
			cs.shape = box
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = s.radius
			cyl.height = s.height
			cs.shape = cyl
		env.add_child(cs)
		cs.global_transform = Transform3D(Basis.IDENTITY, s.center)
