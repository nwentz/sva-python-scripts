extends Node3D
## Builds the whole kitchen at runtime: room, stations, player, camera, HUD.

var _character: Node3D = null

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
		# The low-poly body is a single skin-coloured mesh split into parts, so
		# clothes are done by colouring the parts: white jacket on the torso and
		# arms, white trousers on the legs, black shoes on the feet.
		_dress_body(m)
		character.add_child(m)
		# The chef's costume rides on the skeleton, so it follows the walk
		# cycle and the gestures instead of floating next to the body.
		_dress_model(m)
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
	# Now that the stations know their kinds, build the round serve area and
	# the customer that sits beside it.
	_serve_area()

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

	# Title screen sits above everything else and keeps the cursor free until
	# the player clicks PRESS PLAY or presses Enter.
	var title_ps: PackedScene = load("res://scenes/title_screen.tscn")
	if title_ps != null:
		add_child(title_ps.instantiate())

	print("=== Setup Complete ===")

func _dress_body(root: Node) -> void:
	var skin := Color(0.85, 0.62, 0.45)
	var shirt := Color(0.94, 0.94, 0.91)
	var trousers := Color(0.90, 0.90, 0.87)
	var shoes := Color(0.06, 0.06, 0.07)
	for n in root.get_children():
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var col := skin
			var rough := 0.9
			match String(mi.name):
				"Torso", "LArm", "RArm":
					col = shirt
					rough = 0.8
				"LUpperLeg", "RUpperLeg", "LLowerLeg", "RLowerLeg":
					col = trousers
					rough = 0.85
				"LFoot", "RFoot":
					col = shoes
					rough = 0.45
			for s in range(mi.mesh.get_surface_count()):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = col
				mat.roughness = rough
				mi.set_surface_override_material(s, mat)
		_dress_body(n)

# --- costume ---
# The low-poly character is otherwise naked. A red apron, a white chef's hat
# and a dark brown moustache are built from primitives and parented to bone
# attachments, so they move with the procedural animation.

const APRON_RED := Color(0.62, 0.07, 0.08)
const HAT_WHITE := Color(0.96, 0.96, 0.93)
const MOUSTACHE_BROWN := Color(0.21, 0.11, 0.05)

func _dress_model(root: Node3D) -> void:
	var skels := root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var sk := skels[0] as Skeleton3D

	# Apron on the hips. The bib and skirt are placed in skeleton space and
	# then converted into the bone's local frame by _bone_mesh(). Everything
	# sits tight against the torso (front face z = 0.132) so it reads as part
	# of the body instead of a board floating in front of it.
	var hips := _bone_attachment(sk, "DEF-spine")
	if hips != null:
		_bone_mesh(hips, _costume_box(Vector3(0.26, 0.42, 0.022)), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.42, 0.142)), "ApronBib")
		# The skirt stops just below the hips. A longer panel would be swept
		# through by the thighs during the walk cycle; ending at y 0.99 keeps
		# every leg swing behind it. It tapers towards the bottom so the
		# silhouette stays close to the body instead of bell-shaped.
		_bone_mesh(hips, _costume_skirt(0.32, 0.27, 0.24, 0.018), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.11, 0.145)), "ApronSkirt")
		for side in [-1.0, 1.0]:
			# Front strap lies on the jacket (torso front is z 0.132).
			var strap := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10), 0,
				deg_to_rad(14) * side)), Vector3(0.085 * side, 1.68, 0.15))
			_bone_mesh(hips, _costume_box(Vector3(0.035, 0.15, 0.02)), APRON_RED, strap, "ApronStrap")
			# Continue round the side of the neck to the back.
			var around := Transform3D(Basis.from_euler(Vector3(0,
				atan2(-0.05 * side, -0.18), 0)), Vector3(0.065 * side, 1.72, 0.03))
			_bone_mesh(hips, _costume_box(Vector3(0.022, 0.022, 0.19)), APRON_RED,
				around, "ApronNeckSide")
			# A loop of the bow behind the neck.
			var loop := Transform3D(Basis.from_euler(Vector3(0, 0,
				deg_to_rad(28) * side)), Vector3(0.062 * side, 1.735, -0.108))
			_bone_mesh(hips, _costume_box(Vector3(0.085, 0.038, 0.018)), APRON_RED,
				loop, "ApronBowLoop")
			var tail := Transform3D(Basis.from_euler(Vector3(0, 0,
				deg_to_rad(-12) * side)), Vector3(0.032 * side, 1.665, -0.108))
			_bone_mesh(hips, _costume_box(Vector3(0.026, 0.115, 0.014)), APRON_RED,
				tail, "ApronBowTail")
		# The knot that holds the bunny bow together.
		_bone_mesh(hips, _costume_box(Vector3(0.04, 0.032, 0.03)), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.715, -0.108)), "ApronBowKnot")
		# A band around the neck, like the waist band, tying the bib straps
		# and the bow together into one continuous apron.
		_bone_mesh(hips, _costume_box(Vector3(0.10, 0.035, 0.11)), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.70, 0.0)), "ApronNeckBand")
		# The waist tie is a closed loop: the bow is tied at the back, but the
		# band itself runs all the way round the sides and front of the shirt.
		_bone_mesh(hips, _costume_box(Vector3(0.292, 0.042, 0.276)), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.155, 0.0)), "ApronTieBand")
		for side in [-1.0, 1.0]:
			var loop := Transform3D(Basis.from_euler(Vector3(0, 0,
				deg_to_rad(26) * side)), Vector3(0.052 * side, 1.165, -0.153))
			_bone_mesh(hips, _costume_box(Vector3(0.095, 0.036, 0.018)), APRON_RED,
				loop, "ApronTieLoop")
			var tail := Transform3D(Basis.from_euler(Vector3(0, 0,
				deg_to_rad(-9) * side)), Vector3(0.036 * side, 1.075, -0.151))
			_bone_mesh(hips, _costume_box(Vector3(0.03, 0.16, 0.016)), APRON_RED,
				tail, "ApronTieTail")
		_bone_mesh(hips, _costume_box(Vector3(0.04, 0.04, 0.03)), APRON_RED,
			Transform3D(Basis(), Vector3(0, 1.16, -0.153)), "ApronTieKnot")

	# Hat and moustache on the head bone.
	var head := _bone_attachment(sk, "DEF-spine.006")
	if head != null:
		var band := CylinderMesh.new()
		band.top_radius = 0.124
		band.bottom_radius = 0.130
		band.height = 0.12
		_bone_mesh(head, band, HAT_WHITE,
			Transform3D(Basis(), Vector3(0, 2.02, 0.015)), "ChefHatBand")
		var puff := SphereMesh.new()
		puff.radius = 0.16
		puff.height = 0.22
		_bone_mesh(head, puff, HAT_WHITE,
			Transform3D(Basis(), Vector3(0, 2.135, 0.015)), "ChefHatPuff")
		for side in [-1.0, 1.0]:
			var whisker := Transform3D(Basis.from_euler(Vector3(0, 0,
				deg_to_rad(14) * side)), Vector3(0.030 * side, 1.817, 0.104))
			_bone_mesh(head, _costume_box(Vector3(0.055, 0.016, 0.018)), MOUSTACHE_BROWN,
				whisker, "Moustache")

## A bone attachment that the costume meshes can be parented to.
func _bone_attachment(sk: Skeleton3D, bone: String) -> BoneAttachment3D:
	var idx := sk.find_bone(bone)
	if idx < 0:
		push_warning("Costume: bone '%s' not found" % bone)
		return null
	var att := BoneAttachment3D.new()
	att.name = "Costume_" + bone.replace(".", "_")
	sk.add_child(att)
	att.bone_name = bone
	# The attachment copies the bone's *posed* transform, so positions given
	# in skeleton space have to be moved into the bone's rest frame.
	att.set_meta("rest_inv", sk.get_bone_global_rest(idx).affine_inverse())
	return att

## Adds a mesh to a bone attachment. `xf` is the desired transform in
## skeleton space (i.e. relative to the imported model).
func _bone_mesh(att: BoneAttachment3D, mesh: Mesh, color: Color,
		xf: Transform3D, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	# Costume panels are thin, so render both sides rather than letting the
	# backfaces vanish at grazing angles.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	att.add_child(mi)
	var rest_inv: Transform3D = att.get_meta("rest_inv")
	mi.transform = rest_inv * xf
	return mi

func _costume_box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

## A flat slab whose top edge is `top_w` wide and bottom edge `bottom_w`,
## used for the apron skirt so it tapers in towards the legs.
func _costume_skirt(top_w: float, bottom_w: float, h: float, t: float) -> ArrayMesh:
	var ht := top_w * 0.5
	var hb := bottom_w * 0.5
	var hy := h * 0.5
	var hz := t * 0.5
	var v: Array[Vector3] = [
		Vector3(-ht, hy, hz), Vector3(ht, hy, hz), Vector3(hb, -hy, hz), Vector3(-hb, -hy, hz),
		Vector3(-ht, hy, -hz), Vector3(ht, hy, -hz), Vector3(hb, -hy, -hz), Vector3(-hb, -hy, -hz),
	]
	var faces: Array[Array] = [
		[0, 1, 2], [0, 2, 3], [5, 4, 7], [5, 7, 6],
		[4, 0, 3], [4, 3, 7], [1, 5, 6], [1, 6, 2],
		[4, 5, 1], [4, 1, 0], [3, 2, 6], [3, 6, 7],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		for i in f:
			st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()

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

## The checkered kitchen floor. A generated texture keeps it to a single
## draw call instead of hundreds of tile meshes.
func _floor_tiles() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ROOM_W, ROOM_D)
	var mi := MeshInstance3D.new()
	mi.name = "FloorTiles"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _checker_texture()
	# Two squares per texture repeat, so one repeat is one 1 m tile.
	mat.uv1_scale = Vector3(ROOM_W, ROOM_D, 1.0)
	mat.roughness = 0.35
	mat.metallic = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = mat
	# Just above the floor slab so the two never z-fight.
	mi.position = Vector3(0, 0.005, ROOM_CZ)
	add_child(mi)

## A brown and white checkerboard, drawn once into a small texture.
func _checker_texture() -> ImageTexture:
	var px := 64
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var brown := Color(0.40, 0.29, 0.20)
	var cream := Color(0.87, 0.85, 0.79)
	var half := px / 2
	for y in px:
		for x in px:
			var c := brown if ((x / half) + (y / half)) % 2 == 0 else cream
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- decorations ---
# A plain box room feels empty, so the kitchen gets a door, windows with
# curtains, a tiled splashback, pendant lamps over the counters and a few
# more wall decorations.

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

## Windows with curtains, on the same wall as the door.
func _windows() -> void:
	var z := WALL_Z_MIN
	for wx in [-5.2, 5.2]:
		_window(wx, z)
	# A mat by the door and a potted plant in the corner.
	_panel(Vector3(0, 0.035, z + 0.95), Vector3(1.8, 0.05, 0.9), Color(0.33, 0.24, 0.18), "DoorMat")
	_plant(Vector3(2.1, 0.0, z + 0.6))
	_plant(Vector3(-7.6, 0.0, z + 0.6))

## A window: frame, sky pane, mullions, sill, curtains and a rod.
func _window(x: float, z: float) -> void:
	var y := 2.15
	var frame := Color(0.38, 0.27, 0.19)
	_panel(Vector3(x, y, z + 0.06), Vector3(2.5, 2.2, 0.16), frame, "WindowFrame")
	var sky := _panel(Vector3(x, y, z + 0.13), Vector3(2.2, 1.9, 0.04), Color(0.74, 0.85, 0.93), "WindowSky")
	var sky_mat := sky.material_override as StandardMaterial3D
	sky_mat.emission_enabled = true
	sky_mat.emission = Color(0.42, 0.55, 0.68)
	sky_mat.emission_energy_multiplier = 0.7
	sky_mat.roughness = 0.2
	# Mullions.
	_panel(Vector3(x, y, z + 0.17), Vector3(0.07, 1.9, 0.05), frame)
	_panel(Vector3(x, y, z + 0.17), Vector3(2.2, 0.07, 0.05), frame)
	# Sill.
	_panel(Vector3(x, y - 1.16, z + 0.12), Vector3(2.6, 0.12, 0.26), Color(0.46, 0.33, 0.22), "WindowSill")
	# Curtains, pulled back to either side of the frame.
	var curtain := Color(0.56, 0.30, 0.33)
	_panel(Vector3(x - 1.35, y - 0.1, z + 0.24), Vector3(0.72, 2.4, 0.16), curtain, "CurtainLeft")
	_panel(Vector3(x + 1.35, y - 0.1, z + 0.24), Vector3(0.72, 2.4, 0.16), curtain, "CurtainRight")
	_panel(Vector3(x, y + 1.3, z + 0.24), Vector3(3.6, 0.08, 0.08), Color(0.30, 0.24, 0.20), "CurtainRod")

## A potted plant for the corners.
func _plant(pos: Vector3) -> void:
	var pot := MeshInstance3D.new()
	pot.name = "PlantPot"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.24
	pm.bottom_radius = 0.17
	pm.height = 0.38
	pot.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.58, 0.36, 0.26)
	pmat.roughness = 0.9
	pot.material_override = pmat
	pot.position = pos + Vector3(0, 0.19, 0)
	add_child(pot)
	for i in range(5):
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf%d" % i
		var lm := SphereMesh.new()
		lm.radius = 0.17
		lm.height = 0.34
		leaf.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.24, 0.46, 0.26)
		lmat.roughness = 0.8
		leaf.material_override = lmat
		var ang := TAU * float(i) / 5.0
		leaf.position = pos + Vector3(cos(ang) * 0.16, 0.58 + 0.1 * sin(ang * 2.0), sin(ang) * 0.16)
		leaf.rotation_degrees = Vector3(0, rad_to_deg(ang), 28)
		add_child(leaf)

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

## A clock, a menu board and a shelf on the wall behind the counters.
func _back_wall() -> void:
	var z := WALL_Z_MAX

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
		{"x": -WALL_X, "z": 0.8, "y": 3.0, "c": Color(0.66, 0.42, 0.52), "s": 0.85},
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
	_floor_tiles()
	_door()
	_windows()
	_back_wall()
	_side_walls()
	_pendants()
	_drink_fridge()

## A glass-fronted drinks fridge in the near-right corner of the kitchen.
func _drink_fridge() -> void:
	var fridge := Node3D.new()
	fridge.name = "DrinkFridge"
	# On the wall behind the customer (-X), between them and the middle of
	# the room, clear of the shrub at z -2.6.
	fridge.position = Vector3(-7.9, 0, 0.8)
	# Same facing as the seated customer: local +Z (the glass door) points
	# towards +X, into the room.
	fridge.rotation_degrees = Vector3(0, 90, 0)
	add_child(fridge)
	# Solid cabinet: the chef has to walk around it.
	_add_box_collider(fridge, Vector3(1.3, 2.2, 0.72), Vector3(0, 1.1, 0))
	var shell := Color(0.12, 0.14, 0.16)
	var shelf_col := Color(0.30, 0.33, 0.36)

	# Cabinet: back, two sides, top and bottom.
	_decor_mesh(fridge, _costume_box(Vector3(1.3, 2.2, 0.06)), shell, Vector3(0, 1.1, -0.36), "FridgeBack")
	for side in [-1.0, 1.0]:
		_decor_mesh(fridge, _costume_box(Vector3(0.06, 2.2, 0.72)), shell,
			Vector3(0.65 * side, 1.1, 0), "FridgeSide")
	_decor_mesh(fridge, _costume_box(Vector3(1.3, 0.07, 0.72)), shell, Vector3(0, 2.16, 0), "FridgeTop")
	_decor_mesh(fridge, _costume_box(Vector3(1.3, 0.07, 0.72)), shell, Vector3(0, 0.04, 0), "FridgeBase")
	for y in [0.52, 1.05, 1.58]:
		_decor_mesh(fridge, _costume_box(Vector3(1.2, 0.035, 0.64)), shelf_col,
			Vector3(0, y, 0), "FridgeShelf")

	# Soda cans: short bright cylinders on the lower shelves.
	var can_cols := [Color(0.85, 0.10, 0.10), Color(0.12, 0.38, 0.78), Color(0.90, 0.62, 0.08)]
	for s in range(3):
		for i in range(4):
			var can := CylinderMesh.new()
			can.top_radius = 0.075
			can.bottom_radius = 0.075
			can.height = 0.19
			var cx := -0.42 + i * 0.28
			var cy := 0.52 + float(s) * 0.53 + 0.11
			_decor_mesh(fridge, can, can_cols[(s + i) % can_cols.size()],
				Vector3(cx, cy, 0.0), "SodaCan")
			# Darker grey lid reads clearly through the glass against the
			# bright can colours.
			var lid := CylinderMesh.new()
			lid.top_radius = 0.066
			lid.bottom_radius = 0.066
			lid.height = 0.014
			_decor_mesh(fridge, lid, Color(0.52, 0.54, 0.57),
				Vector3(cx, cy + 0.10, 0.0), "SodaCanLid")

	# Water bottles: tapered blue bodies with white caps on the top shelf.
	for i in range(3):
		var body := CylinderMesh.new()
		body.top_radius = 0.05
		body.bottom_radius = 0.075
		body.height = 0.32
		_decor_mesh(fridge, body, Color(0.65, 0.86, 0.95),
			Vector3(-0.36 + i * 0.36, 1.58 + 0.17, 0.0), "WaterBottle")
		var cap := CylinderMesh.new()
		cap.top_radius = 0.045
		cap.bottom_radius = 0.045
		cap.height = 0.05
		_decor_mesh(fridge, cap, Color(0.94, 0.97, 1.0),
			Vector3(-0.36 + i * 0.36, 1.58 + 0.36, 0.0), "BottleCap")

	# Clear glass door: alpha blended, no collision, so it never blocks the
	# player or the interaction ray.
	var glass := MeshInstance3D.new()
	glass.name = "FridgeGlass"
	var gm := BoxMesh.new()
	gm.size = Vector3(1.24, 2.06, 0.02)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.82, 0.92, 1.0, 0.22)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.roughness = 0.05
	gmat.metallic = 0.0
	glass.material_override = gmat
	glass.position = Vector3(0, 1.1, 0.37)
	fridge.add_child(glass)
	# Door handle.
	_decor_mesh(fridge, _costume_box(Vector3(0.04, 0.4, 0.05)), Color(0.75, 0.78, 0.80),
		Vector3(0.52, 1.15, 0.41), "FridgeHandle")

## A chair beside the round serve table with a customer sitting in it. All of
## it is decoration: no colliders, so it cannot block the player or the
## interaction ray.
func _serve_area() -> void:
	var counter: KitchenStation = null
	for s in get_tree().get_nodes_in_group("stations"):
		if s is KitchenStation and s.kind == KitchenStation.Kind.COUNTER:
			counter = s
			break
	if counter == null:
		return
	var c := counter.global_position
	var wood := Color(0.42, 0.27, 0.17)
	var dark := Color(0.28, 0.18, 0.12)

	var chair := Node3D.new()
	chair.name = "CustomerChair"
	chair.position = Vector3(c.x - 1.6, 0, c.z - 0.1)
	# Local +Z is the front of the chair; turn it towards the round table.
	chair.rotation_degrees = Vector3(0, 90, 0)
	add_child(chair)
	# One solid body for the chair and the seated customer, so the chef walks
	# around them instead of straight through the model.
	_add_box_collider(chair, Vector3(0.8, 1.45, 0.8), Vector3(0, 0.72, 0))
	# A full-size chair: the customer is the same size as the player chef.
	_decor_mesh(chair, _costume_box(Vector3(0.72, 0.10, 0.72)), wood, Vector3(0, 0.58, 0), "Seat")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_decor_mesh(chair, _costume_box(Vector3(0.08, 0.58, 0.08)), dark,
				Vector3(sx * 0.27, 0.29, sz * 0.27), "Leg")
	_decor_mesh(chair, _costume_box(Vector3(0.72, 0.66, 0.09)), wood,
		Vector3(0, 0.98, -0.32), "Backrest")

	# A soda can on the round table, within reach of the customer.
	var can := CylinderMesh.new()
	can.top_radius = 0.07
	can.bottom_radius = 0.07
	can.height = 0.17
	_decor_mesh(counter, can, Color(0.86, 0.10, 0.10),
		Vector3(0.12, 1.19, -0.18), "SodaCanOnTable")
	var lid := CylinderMesh.new()
	lid.top_radius = 0.062
	lid.bottom_radius = 0.062
	lid.height = 0.012
	_decor_mesh(counter, lid, Color(0.52, 0.54, 0.57),
		Vector3(0.12, 1.28, -0.18), "SodaCanLid")

	# The customer reuses the same low-poly rig as the player, posed sitting.
	var glb = load("res://models/Low-Poly Character.glb")
	if glb == null:
		return
	var cust: Node3D = glb.instantiate()
	cust.name = "Customer"
	chair.add_child(cust)
	# Full size, matching the player's chef exactly.
	cust.scale = Vector3.ONE
	# The GLB's origin is at its feet, so placing it on the seat would put the
	# hips far too high. Drop it until the hip bone lines up with the seat.
	var hip_y := 1.0
	var skels := cust.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var hi := (skels[0] as Skeleton3D).find_bone("DEF-spine")
		if hi >= 0:
			hip_y = (skels[0] as Skeleton3D).get_bone_global_rest(hi).origin.y
	cust.position = Vector3(0, 0.62 - hip_y, 0)
	_paint_customer(cust)
	# The customer script owns the seated pose, resting arms and eating anim.
	cust.set_script(load("res://scripts/customer.gd"))
	# Scripts attached at runtime do not automatically enable _process.
	cust.set_process(true)
	cust.call("setup")
	GameManager.customer_node = cust

## A simple static box collider for decoration that the player must not pass
## through (fridge, occupied chair). It follows the parent's transform.
func _add_box_collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "DecorCollider"
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)

func _decor_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, nm: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

## Civilian colours so the customer does not look like a second chef.
func _paint_customer(root: Node3D) -> void:
	var skin := Color(0.85, 0.62, 0.45)
	var shirt := Color(0.22, 0.42, 0.64)
	var trousers := Color(0.17, 0.18, 0.24)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var col := skin
		match String(mi.name):
			"Torso", "LArm", "RArm": col = shirt
			"LUpperLeg", "RUpperLeg", "LLowerLeg", "RLowerLeg": col = trousers
			"LFoot", "RFoot": col = Color(0.06, 0.06, 0.07)
		for s in range(mi.mesh.get_surface_count()):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.85
			mi.set_surface_override_material(s, mat)

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
