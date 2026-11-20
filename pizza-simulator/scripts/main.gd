extends Node3D
## Builds the whole kitchen at runtime: room, stations, player, camera, HUD.

var _character: Node3D = null
var _camera_rig: Node3D = null

const CHARACTER := "res://scenes/character.tscn"
const CAMERA_RIG := "res://scripts/camera_rig.gd"
const INTERACTION := "res://scripts/interaction_controller.gd"

# Room size. The kitchen is centred on the cooking line (see _room) so the
# counters fill the view instead of leaving the player in an empty room.
const ROOM_W := 17.0
const ROOM_D := 9.4
const ROOM_H := 4.0
const ROOM_CZ := 1.35
## Inner faces of the walls.
const WALL_X := ROOM_W * 0.5 - 0.15
const WALL_Z_MIN := ROOM_CZ - ROOM_D * 0.5 + 0.15
const WALL_Z_MAX := ROOM_CZ + ROOM_D * 0.5 - 0.15

func _ready() -> void:
	print("=== Pizza Simulator ===")
	print("Starting...")

	_environment()
	_room()
	_decor()

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
	# The player starts in front of the counters, with room behind them for
	# the camera to pull back.
	character.position = Vector3(0, 0, 2.0)
	# The camera starts looking towards the cooking line (+Z), so the
	# character has to start facing away from the camera as well.
	character.rotation_degrees = Vector3(0, 180, 0)
	# Rigged GLB model (stands on the floor, origin at feet)
	var glb = load("res://models/Low-Poly Character.glb")
	if glb:
		var m = glb.instantiate()
		m.name = "RiggedModel"
		# The GLB's face points +Z; the character controller walks along -Z.
		m.rotation_degrees = Vector3(0, 180, 0)
		_tint_skin(m)
		character.add_child(m)
	# Let the character pose its skeleton for walking and gestures.
	if character.has_method("setup_rig"):
		character.setup_rig()
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
	oven_glow.position = Vector3(0, 1.0, 5.6)
	oven_glow.light_energy = 8.0
	oven_glow.light_color = Color(1.0, 0.7, 0.3)
	oven_glow.visible = false
	add_child(oven_glow)

	print("Environment created")

func _room() -> void:
	var w := ROOM_W
	var d := ROOM_D
	var h := ROOM_H
	# The room is centred on the cooking line instead of on the world origin,
	# so the counters fill the view rather than leaving the player in the
	# middle of an empty floor.
	var cz := ROOM_CZ
	print("Creating room - Size:", Vector3(w, h, d))
	_box(Vector3(0, -0.1, cz), Vector3(w, 0.2, d), Color(0.44, 0.38, 0.31))
	_box(Vector3(0, h, cz), Vector3(w, 0.2, d), Color(0.86, 0.86, 0.89))
	_box(Vector3(0, h * 0.5, cz - d * 0.5), Vector3(w, h, 0.3), Color(0.79, 0.8, 0.83))
	_box(Vector3(0, h * 0.5, cz + d * 0.5), Vector3(w, h, 0.3), Color(0.79, 0.8, 0.83))
	_box(Vector3(-w * 0.5, h * 0.5, cz), Vector3(0.3, h, d), Color(0.73, 0.75, 0.79))
	_box(Vector3(w * 0.5, h * 0.5, cz), Vector3(0.3, h, d), Color(0.73, 0.75, 0.79))
	print("Room created")

# --- decorations ---
# A plain box room feels empty, so the kitchen gets a door, a tiled
# splashback, pendant lamps over the counters and a few wall decorations.

## A plain box on a wall. Decorations never get a collider, so they can
## never block the player or the interaction ray.
func _panel(pos: Vector3, size: Vector3, color: Color, n: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if n != "":
		mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

## The way into the kitchen, on the wall behind the player.
func _door() -> void:
	var z := WALL_Z_MIN
	_panel(Vector3(0, 1.25, z + 0.05), Vector3(1.95, 2.6, 0.16), Color(0.42, 0.30, 0.21), "DoorFrame")
	_panel(Vector3(0, 1.15, z + 0.16), Vector3(1.65, 2.35, 0.08), Color(0.63, 0.45, 0.29), "DoorPanel")
	_panel(Vector3(0, 1.15, z + 0.22), Vector3(1.15, 1.9, 0.05), Color(0.56, 0.39, 0.25), "DoorInset")
	_panel(Vector3(0, 1.15, z + 0.25), Vector3(0.05, 1.9, 0.04), Color(0.50, 0.34, 0.22), "DoorSeam")
	# Handle and a small lamp above the door.
	_panel(Vector3(0.52, 1.05, z + 0.30), Vector3(0.22, 0.05, 0.05), Color(0.85, 0.76, 0.38))
	_panel(Vector3(0.52, 1.05, z + 0.30), Vector3(0.05, 0.22, 0.05), Color(0.85, 0.76, 0.38))
	var lamp := OmniLight3D.new()
	lamp.name = "DoorLight"
	lamp.position = Vector3(0, 2.85, z + 0.7)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.8
	lamp.omni_range = 4.5
	add_child(lamp)
	print("Door added")

## Tiles, a clock, a menu board and a shelf on the wall behind the counters.
func _back_wall() -> void:
	var z := WALL_Z_MAX
	# Tiled splashback running the length of the counter.
	_panel(Vector3(0, 1.55, z - 0.03), Vector3(14.6, 0.95, 0.06), Color(0.88, 0.87, 0.83), "Splashback")
	_panel(Vector3(0, 2.06, z - 0.05), Vector3(14.6, 0.06, 0.10), Color(0.55, 0.42, 0.30), "SplashbackRail")

	# Wall clock.
	var cx := -0.4
	var cy := 3.05
	var rim := MeshInstance3D.new()
	rim.name = "ClockRim"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.09
	rim.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.28, 0.22, 0.18)
	cmat.roughness = 0.7
	rim.material_override = cmat
	rim.position = Vector3(cx, cy, z - 0.05)
	rim.rotation_degrees = Vector3(90, 0, 0)
	add_child(rim)
	var face := MeshInstance3D.new()
	face.name = "ClockFace"
	var fm := CylinderMesh.new()
	fm.top_radius = 0.29
	fm.bottom_radius = 0.29
	fm.height = 0.05
	face.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.95, 0.94, 0.90)
	face.material_override = fmat
	face.position = Vector3(cx, cy, z - 0.11)
	face.rotation_degrees = Vector3(90, 0, 0)
	add_child(face)
	# Hour and minute hands.
	var hands := [{"a": 40.0, "len": 0.16, "w": 0.04}, {"a": 310.0, "len": 0.24, "w": 0.03}]
	for hand in hands:
		var a: float = hand["a"]
		var ln: float = hand["len"]
		var wd: float = hand["w"]
		var ang := deg_to_rad(a)
		var dir := Vector3(sin(ang), cos(ang), 0)
		var p := Vector3(cx, cy, z - 0.14) + dir * (ln * 0.5)
		var mi := _panel(p, Vector3(wd, ln, 0.02), Color(0.15, 0.12, 0.10))
		mi.rotation_degrees = Vector3(0, 0, -ang)

	# Menu board.
	var bx := -5.2
	_panel(Vector3(bx, 2.55, z - 0.05), Vector3(2.3, 1.5, 0.08), Color(0.35, 0.24, 0.17), "MenuFrame")
	_panel(Vector3(bx, 2.55, z - 0.10), Vector3(2.05, 1.28, 0.05), Color(0.16, 0.26, 0.20), "MenuBoard")
	var menu := Label3D.new()
	menu.name = "MenuText"
	menu.text = "MENU\nMargherita\nPepperoni\nOlives"
	menu.font_size = 34
	menu.outline_size = 6
	menu.modulate = Color(0.96, 0.95, 0.88)
	menu.pixel_size = 0.0035
	menu.position = Vector3(bx, 2.55, z - 0.14)
	menu.rotation_degrees = Vector3(0, 180, 0)
	add_child(menu)

	# A shelf with jars and bottles.
	var sx := 5.4
	_panel(Vector3(sx, 2.35, z - 0.22), Vector3(2.4, 0.08, 0.42), Color(0.48, 0.34, 0.23), "Shelf")
	var jar_colors := [Color(0.80, 0.28, 0.22), Color(0.85, 0.72, 0.25), Color(0.35, 0.55, 0.30), Color(0.85, 0.85, 0.85)]
	for i in range(jar_colors.size()):
		var jar := MeshInstance3D.new()
		jar.name = "Jar%d" % i
		var jm := CylinderMesh.new()
		jm.top_radius = 0.11
		jm.bottom_radius = 0.12
		jm.height = 0.34
		jar.mesh = jm
		var jmat := StandardMaterial3D.new()
		jmat.albedo_color = jar_colors[i]
		jmat.roughness = 0.5
		jar.material_override = jmat
		jar.position = Vector3(sx - 0.9 + i * 0.6, 2.56, z - 0.22)
		add_child(jar)

## Framed pictures on the side walls.
func _side_walls() -> void:
	var pics := [
		{"x": WALL_X, "z": 2.6, "y": 2.6, "c": Color(0.78, 0.55, 0.32), "s": 1.2},
		{"x": WALL_X, "z": 0.4, "y": 2.9, "c": Color(0.36, 0.48, 0.62), "s": 0.9},
		{"x": -WALL_X, "z": 3.6, "y": 2.7, "c": Color(0.42, 0.55, 0.40), "s": 1.1},
		{"x": -WALL_X, "z": 0.8, "y": 2.5, "c": Color(0.66, 0.42, 0.52), "s": 0.85},
	]
	for p in pics:
		var px: float = p["x"]
		var pz: float = p["z"]
		var py: float = p["y"]
		var psz: float = p["s"]
		var pc: Color = p["c"]
		var side := 1.0 if px > 0.0 else -1.0
		_panel(Vector3(px - side * 0.04, py, pz), Vector3(0.08, psz, psz + 0.2), Color(0.40, 0.28, 0.19))
		_panel(Vector3(px - side * 0.10, py, pz), Vector3(0.05, psz - 0.22, psz - 0.02), pc)

## Pendant lamps hanging over the counter row.
func _pendants() -> void:
	for x in [5.6, 2.55, -0.6, -4.2]:
		var z := 4.55
		_panel(Vector3(x, 3.5, z), Vector3(0.035, 0.8, 0.035), Color(0.15, 0.13, 0.12), "PendantCord")
		var shade := MeshInstance3D.new()
		shade.name = "PendantShade"
		var sm := CylinderMesh.new()
		sm.top_radius = 0.08
		sm.bottom_radius = 0.30
		sm.height = 0.30
		shade.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.28, 0.42, 0.35)
		smat.roughness = 0.6
		shade.material_override = smat
		shade.position = Vector3(x, 3.0, z)
		add_child(shade)
		var bulb := OmniLight3D.new()
		bulb.name = "PendantLight"
		bulb.position = Vector3(x, 2.85, z)
		bulb.light_color = Color(1.0, 0.92, 0.78)
		bulb.light_energy = 2.2
		bulb.omni_range = 5.0
		add_child(bulb)
	print("Decorations added")

## Builds every decoration in one go.
func _decor() -> void:
	_door()
	_back_wall()
	_side_walls()
	_pendants()

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
	# Let the character know about the camera so it can keep room for the
	# camera boom behind the player.
	if _character != null and "camera_rig" in _character:
		_character.camera_rig = rig

	print("Camera rig created at:", rig.global_position, "rotation:", rig.rotation)

func _interaction(character: PhysicsBody3D) -> void:
	print("Setting up interaction controller")
	var n := Node3D.new()
	n.name = "Interaction"
	n.set_script(load(INTERACTION))
	add_child(n)
	n.call("setup", character)
