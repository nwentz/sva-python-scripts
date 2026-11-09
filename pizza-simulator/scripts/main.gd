extends Node3D
## Builds the whole kitchen at runtime: room, stations, player, camera, HUD.

var _character: Node3D = null
var _camera_rig: Node3D = null

const CHARACTER := "res://scenes/character.tscn"
const CAMERA_RIG := "res://scripts/camera_rig.gd"
const INTERACTION := "res://scripts/interaction_controller.gd"

func _ready() -> void:
	print("=== Pizza Simulator ===")
	print("Starting...")

	_environment()
	_room()

	var character: Node3D = load(CHARACTER).instantiate()
	character.position = Vector3(0, 0.05, 4.5)
	add_child(character)
	print("Character spawned at:", character.global_position)

	_camera(character)
	_interaction(character)
	print("Camera and interaction set up")

	# Ensure a Kitchen node exists for station init
	if not has_node("Kitchen"):
		var kitchen := Node3D.new()
		kitchen.name = "Kitchen"
		add_child(kitchen)
		print("Kitchen node created")

	var kitchen := get_node("Kitchen")
	var init_script := load("res://scripts/kitchen_init.gd")
	var init = init_script.new()
	kitchen.add_child(init)
	print("KitchenInit added to scene")

	await get_tree().process_frame
	if init.has_method("initialize_stations"):
		init.initialize_stations()

	add_child(HUD.new())
	print("HUD added")
	print("=== Setup Complete ===")

func _physics_process(delta: float) -> void:
	if _character and is_instance_valid(_character) and _camera_rig and is_instance_valid(_camera_rig):
		_camera_rig.global_position = _character.global_position + Vector3(0, 2.0, 0)

func _environment() -> void:
	print("Creating environment...")

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.2, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.61)
	env.ambient_light_energy = 2.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	sun.shadow_blur = 0.3
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.position = Vector3(0, 4.0, 0)
	fill.light_energy = 6.0
	fill.omni_range = 20.0
	fill.light_color = Color(1.0, 0.95, 0.9)
	add_child(fill)

	var oven_glow := OmniLight3D.new()
	oven_glow.name = "OvenGlow"
	oven_glow.position = Vector3(0, 1.0, 6.0)
	oven_glow.light_energy = 8.0
	oven_glow.light_color = Color(1.0, 0.7, 0.3)
	oven_glow.visible = false
	add_child(oven_glow)

	print("Environment created")

func _room() -> void:
	var w := 16.0
	var d := 12.0
	var h := 4.0
	print("Creating room - Size:", Vector3(w, h, d))
	_box(Vector3(0, -0.1, 0), Vector3(w, 0.2, d), Color(0.44, 0.38, 0.31))
	_box(Vector3(0, h, 0), Vector3(w, 0.2, d), Color(0.86, 0.86, 0.89))
	_box(Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, 0.3), Color(0.79, 0.8, 0.83))
	_box(Vector3(0, h * 0.5, d * 0.5), Vector3(w, h, 0.3), Color(0.79, 0.8, 0.83))
	_box(Vector3(-w * 0.5, h * 0.5, 0), Vector3(0.3, h, d), Color(0.73, 0.75, 0.79))
	_box(Vector3(w * 0.5, h * 0.5, 0), Vector3(0.3, h, d), Color(0.73, 0.75, 0.79))
	print("Room created")

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	b.add_child(m)
	var c := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = size
	c.shape = cs
	b.add_child(c)
	add_child(b)

func _camera(target: Node3D) -> void:
	print("Setting up camera for:", target.name)
	_character = target

	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.global_position = target.global_position + Vector3(0, 2.0, 0)
	rig.rotation = Vector3(-0.3, 0, 0)
	_camera_rig = rig

	var arm := SpringArm3D.new()
	arm.name = "CameraArm"
	arm.spring_length = 2.5
	arm.margin = 0.25
	arm.target_position = Vector3(0, 0.8, 0)
	rig.add_child(arm)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 70.0
	arm.add_child(cam)

	print("Adding camera rig to scene")
	add_child(rig)
	cam.make_current()

	print("Camera rig created at:", rig.global_position, "rotation:", rig.rotation)

func _interaction(character: PhysicsBody3D) -> void:
	print("Setting up interaction controller")
	var n := Node3D.new()
	n.name = "Interaction"
	n.set_script(load(INTERACTION))
	add_child(n)
	n.call("setup", character)
