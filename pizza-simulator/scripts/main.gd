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

	var character: Node3D = null
	var ps: PackedScene = load(CHARACTER)
	if ps != null:
		character = ps.instantiate()
	if character == null:
		# Fallback: build a simple capsule body so the game still runs.
		character = CharacterBody3D.new()
		character.name = "Character"
		var col := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.3
		shape.height = 1.8
		col.shape = shape
		col.position = Vector3(0, 0.9, 0)
		character.add_child(col)
		var mesh := MeshInstance3D.new()
		var bm := CapsuleMesh.new()
		bm.radius = 0.25
		bm.height = 1.8
		mesh.mesh = bm
		mesh.position = Vector3(0, 0.9, 0)
		character.add_child(mesh)
	character.position = Vector3(0, 0, 0)
	# Rigged GLB model (stands on the floor, origin at feet)
	var glb = load("res://models/Low-Poly Character.glb")
	if glb:
		var m = glb.instantiate()
		m.name = "RiggedModel"
		_tint_skin(m)
		character.add_child(m)
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

	add_child(HUD.new())
	print("HUD added")

	# On-screen movement arrows (bottom-left, laid out as a D-pad)
	var canvas := CanvasLayer.new()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var btns := {"↑": Vector2(0,-1), "↓": Vector2(0,1), "←": Vector2(-1,0), "→": Vector2(1,0)}
	# D-pad anchored to the bottom-right corner (HUD text lives bottom-left)
	var cells := {"↑": Vector2(-168, -240), "↓": Vector2(-168, -96), "←": Vector2(-240, -168), "→": Vector2(-96, -168)}
	for name in btns:
		var b := Button.new()
		b.text = name
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 44)
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		var c: Vector2 = cells[name]
		b.offset_left = c.x
		b.offset_right = c.x + 72
		b.offset_top = c.y
		b.offset_bottom = c.y + 72
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var v: Vector2 = btns[name]
		b.button_down.connect(func(): if _character: _character.ui_input = v)
		b.button_up.connect(func(): if _character: _character.ui_input = Vector2.ZERO)
		root.add_child(b)
	add_child(canvas)

	print("=== Setup Complete ===")

func _tint_skin(root: Node) -> void:
	var skin := Color(0.85, 0.62, 0.45)
	for n in root.get_children():
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			for s in range(mi.mesh.get_surface_count()):
				var m := StandardMaterial3D.new()
				m.albedo_color = skin
				m.roughness = 0.9
				mi.set_surface_override_material(s, m)
		_tint_skin(n)

func _physics_process(delta: float) -> void:
	pass

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
	var d := 18.0
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
	rig.set_script(load(CAMERA_RIG))
	rig.global_position = target.global_position + Vector3(0, 1.55, 0)
	_camera_rig = rig

	print("Adding camera rig to scene")
	add_child(rig)
	rig.call("setup", target)

	print("Camera rig created at:", rig.global_position, "rotation:", rig.rotation)

func _interaction(character: PhysicsBody3D) -> void:
	print("Setting up interaction controller")
	var n := Node3D.new()
	n.name = "Interaction"
	n.set_script(load(INTERACTION))
	add_child(n)
	n.call("setup", character)
