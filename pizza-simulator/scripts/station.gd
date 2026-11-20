class_name KitchenStation
extends StaticBody3D
## An interactable station. Builds its own pizza anchor and name label.
##
## A station is either a plain box (the default) or a 3D model. The model is
## fitted to the station's footprint automatically: it is scaled so that it
## matches `size` (width, height, depth), turned to face the room and placed
## with its base on the floor.

enum Kind { DOUGH, SAUCE, CHEESE, TOPPING, PREP, OVEN, COUNTER }

@export var metadata := {
	"kind": 0,
	"label": "",
	"ingredient": ""
}

var kind: int:
	get:
		return metadata.get("kind", 0)
var label: String:
	get:
		return metadata.get("label", "")
var ingredient: String:
	get:
		return metadata.get("ingredient", "")

var placed_pizza: Pizza = null
var oven_pizza: Pizza = null
var anchor: Node3D
var _announced := false
var _material: StandardMaterial3D

## Footprint of the station: width (x), height (y), depth (z).
var _size := Vector3(1.4, 1.1, 1.4)
## Optional 3D model used instead of the plain box.
var _model_path := ""
var _model: Node3D = null
var _model_meshes: Array[MeshInstance3D] = []
var _glowing := false
var _baking := false
var _bake_light: OmniLight3D = null
var _smoke: GPUParticles3D = null

func setup_station(kind: int, label: String, ingredient: String) -> void:
	metadata = {
		"kind": kind,
		"label": label,
		"ingredient": ingredient
	}
	if is_inside_tree():
		# The node's _ready() built it with the default (DOUGH) kind. Rebuild
		# now so e.g. the serve station gets its round table and collider.
		_build()
		_refresh()

## Uses a 3D model instead of the plain box. The model is scaled to `size`
## (width, height, depth) and rotated by `yaw_deg` so that it faces the
## room, with its base resting on the floor.
func setup_model(path: String, size: Vector3, yaw_deg: float) -> void:
	_model_path = path
	_size = size
	_model_yaw = yaw_deg
	if is_inside_tree():
		_build()
		_refresh()

var _model_yaw := 0.0

func _ready() -> void:
	add_to_group("stations")
	_build()
	_refresh()

## Builds the visual and the collision shape.
func _build() -> void:
	_clear_visuals()

	if _model_path != "":
		_build_model()
	elif kind == Kind.COUNTER:
		_build_round_table()
	else:
		_build_box()

	# The collision always matches the station's footprint. The serve station
	# is a round table, so give it a cylindrical collider.
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	if kind == Kind.COUNTER:
		var cyl := CylinderShape3D.new()
		# Slightly tighter than the visible top so the player can step right
		# up to the table instead of being held off by an invisible lip.
		cyl.radius = COUNTER_RADIUS - 0.08
		cyl.height = _size.y
		cs.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = _size
		cs.shape = box
	cs.position = Vector3(0, _size.y * 0.5, 0)
	add_child(cs)

	_anchor()
	_build_effects()

## The light and smoke that show that a pizza is cooking.
func _build_effects() -> void:
	if _bake_light != null and is_instance_valid(_bake_light):
		return
	_bake_light = OmniLight3D.new()
	_bake_light.name = "BakeLight"
	_bake_light.position = Vector3(0, _size.y + 0.3, 0)
	_bake_light.light_color = Color(1.0, 0.5, 0.12)
	_bake_light.light_energy = 0.0
	_bake_light.omni_range = 3.6
	_bake_light.visible = false
	add_child(_bake_light)

	_smoke = Fx.make_smoke()
	_smoke.name = "Smoke"
	_smoke.position = Vector3(0, _size.y + 0.12, 0)
	add_child(_smoke)

func _clear_visuals() -> void:
	for c in get_children():
		if c is MeshInstance3D or c is CollisionShape3D or c is Node3D and c.name == "Model":
			if c.name == "Anchor" or c.name == "Label3D" or c.name == "IngredientProp":
				continue
			remove_child(c)
			c.queue_free()
	_model = null
	_model_meshes.clear()

func _build_box() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "BoxMesh"
	var bm := BoxMesh.new()
	bm.size = _size
	mi.mesh = bm
	mi.position = Vector3(0, _size.y * 0.5, 0)
	add_child(mi)

## The serve station is a round pedestal table instead of a grey box.
const COUNTER_RADIUS := 0.78

func _build_round_table() -> void:
	var top := MeshInstance3D.new()
	top.name = "TableTop"
	var disc := CylinderMesh.new()
	disc.top_radius = COUNTER_RADIUS
	disc.bottom_radius = COUNTER_RADIUS
	disc.height = 0.12
	top.mesh = disc
	top.position = Vector3(0, _size.y - 0.06, 0)
	add_child(top)

	var stem := MeshInstance3D.new()
	stem.name = "TableStem"
	var post := CylinderMesh.new()
	post.top_radius = 0.10
	post.bottom_radius = 0.14
	post.height = _size.y - 0.12
	stem.mesh = post
	stem.position = Vector3(0, (_size.y - 0.12) * 0.5, 0)
	add_child(stem)

	var foot := MeshInstance3D.new()
	foot.name = "TableFoot"
	var base := CylinderMesh.new()
	base.top_radius = 0.32
	base.bottom_radius = 0.38
	base.height = 0.07
	foot.mesh = base
	foot.position = Vector3(0, 0.035, 0)
	add_child(foot)

func _build_model() -> void:
	var ps: PackedScene = load(_model_path)
	if ps == null:
		push_error("KitchenStation: could not load model %s" % _model_path)
		_build_box()
		return
	var inst := ps.instantiate()
	inst.name = "Model"
	add_child(inst)
	_model = inst

	# Work out how to fit the model into the station's footprint. The model
	# is turned first, so its local axes line up with the world axes.
	var local := _local_aabb(inst)
	if local.size.length_squared() < 0.000001:
		return
	var yaw := deg_to_rad(_model_yaw)
	var s_x := _size.z / local.size.x
	var s_y := _size.y / local.size.y
	var s_z := _size.x / local.size.z
	if absf(sin(yaw)) > 0.5:
		# turned by 90 degrees: the model's x and z swap over
		s_x = _size.z / local.size.x
		s_z = _size.x / local.size.z
	var b := Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_scale(Vector3(s_x, s_y, s_z))

	# Centre the model on the station and put its base on the floor.
	var corners := _corners(local)
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for c in corners:
		var p := b * c
		mn = Vector3(minf(mn.x, p.x), minf(mn.y, p.y), minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), maxf(mx.y, p.y), maxf(mx.z, p.z))
	var origin := Vector3(-(mn.x + mx.x) * 0.5, -mn.y, -(mn.z + mx.z) * 0.5)

	var base: Transform3D = inst.transform
	inst.transform = Transform3D(b, origin) * base

	# Take copies of the model's materials so the baking glow can be
	# switched on and off without touching the imported resource.
	for m in _find_meshes(inst):
		_model_meshes.append(m)
		var mat := m.material_override
		if mat == null and m.mesh != null and m.mesh.get_surface_count() > 0:
			mat = m.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var copy: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
			copy.emission_enabled = false
			m.material_override = copy

func _find_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_find_meshes(c))
	return out

## Bounding box of the model in the model's own local space.
func _local_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _find_meshes(n):
		var xf: AABB = m.transform * m.mesh.get_aabb()
		if first:
			out = xf
			first = false
		else:
			out = out.merge(xf)
	return out

func _corners(aabb: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 8:
		out.append(Vector3(
			aabb.position.x if (i & 1) == 0 else aabb.end.x,
			aabb.position.y if (i & 2) == 0 else aabb.end.y,
			aabb.position.z if (i & 4) == 0 else aabb.end.z))
	return out

func _refresh() -> void:
	match metadata["kind"]:
		Kind.DOUGH: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.55, 0.55, 0.55)
		Kind.SAUCE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.50, 0.50, 0.50)
		Kind.CHEESE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.60, 0.60, 0.60)
		Kind.TOPPING: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.48, 0.48, 0.48)
		Kind.PREP: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.65, 0.65, 0.65)
		Kind.OVEN: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.30, 0.30, 0.30)
		Kind.COUNTER: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.44, 0.29, 0.19)
		_: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.50, 0.50, 0.50)

	for c in get_children():
		if c is MeshInstance3D and c.name != "IngredientProp":
			(c as MeshInstance3D).material_override = _material

	_apply_model_materials()

	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl == null:
		lbl = Label3D.new()
		lbl.name = "Label3D"
		lbl.font_size = 34
		lbl.outline_size = 8
		lbl.modulate = Color(1, 1, 1)
		lbl.render_priority = 10
		add_child(lbl)
	# The prep table stands in front of the counter row, so it is much closer
	# to the camera than the stations behind it. Its label is shrunk to keep
	# it from covering the station labels.
	if kind == Kind.PREP:
		lbl.font_size = 22
		lbl.outline_size = 5
	else:
		lbl.font_size = 34
		lbl.outline_size = 8
	# Turn the label towards the middle of the kitchen, otherwise the ones on
	# the far wall (oven, serve counter) read backwards.
	var facing := _facing()
	lbl.rotation_degrees = Vector3(0, rad_to_deg(atan2(facing.x, facing.z)), 0)
	lbl.position = Vector3(0, _size.y + 0.52, 0) + facing * 0.35
	lbl.text = metadata.get("label", "")
	_ingredient_prop()

## Direction from the station towards the middle of the kitchen.
func _facing() -> Vector3:
	var to_centre := Vector3(-global_position.x, 0.0, -global_position.z)
	if to_centre.length_squared() < 0.0001:
		return Vector3(0, 0, 1)
	return to_centre.normalized()

## The imported models are plain white. Tint them to the station's colour so
## they fit the rest of the kitchen, keeping the handles a shade brighter so
## the shape still reads.
func _apply_model_materials() -> void:
	if _model_meshes.is_empty() or _material == null:
		return
	for m in _model_meshes:
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		if m.name.contains("Body"):
			mat.albedo_color = _material.albedo_color
			mat.metallic = 0.25
			mat.roughness = 0.5
		else:
			mat.albedo_color = _material.albedo_color.lightened(0.3)
			mat.metallic = 0.7
			mat.roughness = 0.3

func _ingredient_prop() -> void:
	# Show a visible ingredient item on top of ingredient stations
	var old := get_node_or_null("IngredientProp")
	if old:
		remove_child(old)
		old.queue_free()
	var ing: String = metadata.get("ingredient", "")
	var kind: int = metadata.get("kind", 0)
	if ing == "" and kind != Kind.DOUGH:
		return
	var col := Color(0.9, 0.3, 0.2)
	var mi := MeshInstance3D.new()
	mi.name = "IngredientProp"
	match ing:
		"sauce":
			col = Color(0.90, 0.06, 0.03)
			var bottle := CylinderMesh.new()
			bottle.top_radius = 0.10
			bottle.bottom_radius = 0.19
			bottle.height = 0.44
			mi.mesh = bottle
			mi.position = Vector3(0, 1.32, 0)
			var cap := MeshInstance3D.new()
			cap.name = "BottleCap"
			var neck := CylinderMesh.new()
			neck.top_radius = 0.055
			neck.bottom_radius = 0.055
			neck.height = 0.10
			cap.mesh = neck
			cap.position = Vector3(0, 0.27, 0)
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.82, 0.82, 0.84)
			cap_mat.roughness = 0.5
			cap.material_override = cap_mat
			mi.add_child(cap)
		"cheese":
			col = Color(1.0, 0.76, 0.0)
			var block := BoxMesh.new()
			block.size = Vector3(0.5, 0.28, 0.5)
			mi.mesh = block
			mi.position = Vector3(0, 1.26, 0)
		"pepperoni":
			col = Color(0.70, 0.04, 0.05)
			var disc := CylinderMesh.new()
			disc.top_radius = 0.17
			disc.bottom_radius = 0.17
			disc.height = 0.08
			mi.mesh = disc
			mi.position = Vector3(0, 1.16, 0)
		_:
			col = Color(0.97, 0.88, 0.55)
			var ball := SphereMesh.new()
			ball.radius = 0.15
			ball.height = 0.30
			mi.mesh = ball
			mi.position = Vector3(0, 1.20, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	mi.material_override = mat
	add_child(mi)

func _anchor() -> void:
	# Reuse the anchor: freeing and re-adding it would make Godot rename
	# the new one (the old one is still a child until the end of the frame).
	if anchor == null or not is_instance_valid(anchor):
		anchor = Node3D.new()
		anchor.name = "Anchor"
		add_child(anchor)
	anchor.position = Vector3(0, _size.y + 0.02, 0)

func _label() -> void:
	var l := Label3D.new()
	l.text = metadata["label"]
	l.position = Vector3(0, 1.0, 0.55)
	l.font_size = 56
	l.outline_size = 10
	l.modulate = Color(1, 1, 1)
	l.render_priority = 10
	add_child(l)

func _physics_process(delta: float) -> void:
	if oven_pizza == null:
		_announced = false
		_baking = false
		_set_glow(false)
		_set_effects(false)
		return

	# Visual feedback for oven status
	var baking := oven_pizza.stage == Pizza.Stage.BAKING
	_baking = baking
	_set_glow(baking)
	_set_effects(baking)

	oven_pizza.bake(delta)
	var done := oven_pizza.stage == Pizza.Stage.BAKED or oven_pizza.stage == Pizza.Stage.BURNT
	if done and not _announced:
		_announced = true
		GameManager.set_hint("Pizza is done! Pull it out with G.")

## Lights the oven up and puffs smoke while the pizza is baking.
func _set_effects(on: bool) -> void:
	if on:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
		if _bake_light != null and is_instance_valid(_bake_light):
			_bake_light.visible = true
			_bake_light.light_energy = 0.9 + 1.1 * pulse
		if _smoke != null and is_instance_valid(_smoke):
			_smoke.emitting = true
		_glow_colour(Color(1.0, 0.32, 0.04) * (0.22 + 0.3 * pulse))
	else:
		if _bake_light != null and is_instance_valid(_bake_light):
			_bake_light.visible = false
			_bake_light.light_energy = 0.0
		if _smoke != null and is_instance_valid(_smoke):
			_smoke.emitting = false

## Makes the station glow while the pizza is baking.
func _set_glow(on: bool) -> void:
	if on == _glowing:
		return
	_glowing = on
	for m in _model_meshes:
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.emission_enabled = on
	if _material != null:
		_material.emission_enabled = on

## Colour of the baking glow (it pulses while the pizza is in the oven).
func _glow_colour(col: Color) -> void:
	for m in _model_meshes:
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.emission = col
	if _material != null:
		_material.emission = col
