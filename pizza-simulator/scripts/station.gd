class_name KitchenStation
extends StaticBody3D
## An interactable station. Builds its own pizza anchor and name label.

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

func setup_station(kind: int, label: String, ingredient: String) -> void:
	metadata = {
		"kind": kind,
		"label": label,
		"ingredient": ingredient
	}
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	_anchor()
	add_to_group("stations")

	# Visible box + collision (only if the scene didn't already provide one)
	var has_mesh := false
	for c in get_children():
		if c is MeshInstance3D:
			has_mesh = true
	if not has_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 1.1, 1.4)
		mi.mesh = bm
		mi.position = Vector3(0, 0.55, 0)
		add_child(mi)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 1.1, 1.4)
		cs.shape = box
		cs.position = Vector3(0, 0.55, 0)
		add_child(cs)

	_refresh()

func _refresh() -> void:
	match metadata["kind"]:
		Kind.DOUGH: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.55, 0.55, 0.55)
		Kind.SAUCE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.50, 0.50, 0.50)
		Kind.CHEESE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.60, 0.60, 0.60)
		Kind.TOPPING: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.48, 0.48, 0.48)
		Kind.PREP: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.65, 0.65, 0.65)
		Kind.OVEN: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.30, 0.30, 0.30)
		Kind.COUNTER: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.40, 0.40, 0.40)
		_: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.50, 0.50, 0.50)

	for c in get_children():
		if c is MeshInstance3D and c.name != "IngredientProp":
			(c as MeshInstance3D).material_override = _material

	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl == null:
		lbl = Label3D.new()
		lbl.name = "Label3D"
		lbl.position = Vector3(0, 1.62, 0.35)
		lbl.font_size = 34
		lbl.outline_size = 8
		lbl.modulate = Color(1, 1, 1)
		lbl.render_priority = 10
		add_child(lbl)
	lbl.text = metadata.get("label", "")
	_ingredient_prop()

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
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.22
			cyl.height = 0.42
			mi.mesh = cyl
			mi.position = Vector3(0, 1.32, 0)
		"cheese":
			col = Color(1.0, 0.76, 0.0)
			var block := BoxMesh.new()
			block.size = Vector3(0.5, 0.28, 0.5)
			mi.mesh = block
			mi.position = Vector3(0, 1.26, 0)
		"pepperoni":
			col = Color(0.70, 0.04, 0.05)
			var disc := CylinderMesh.new()
			disc.top_radius = 0.28
			disc.bottom_radius = 0.28
			disc.height = 0.10
			mi.mesh = disc
			mi.position = Vector3(0, 1.18, 0)
		_:
			col = Color(0.97, 0.88, 0.55)
			var ball := SphereMesh.new()
			ball.radius = 0.26
			ball.height = 0.52
			mi.mesh = ball
			mi.position = Vector3(0, 1.26, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	mi.material_override = mat
	add_child(mi)

func _anchor() -> void:
	anchor = Node3D.new()
	anchor.name = "Anchor"
	anchor.position = Vector3(0, 1.12, 0)
	add_child(anchor)

func _label() -> void:
	var l := Label3D.new()
	l.text = metadata["label"]
	l.position = Vector3(0, 1.0, 0.55)
	l.font_size = 56
	l.outline_size = 10
	l.modulate = Color(1, 1, 1)
	l.z_index = 10
	add_child(l)

func _physics_process(delta: float) -> void:
	if oven_pizza == null:
		_announced = false
		return

	# Visual feedback for oven status
	if _material:
		if oven_pizza.stage == Pizza.Stage.BAKING:
			_material.emissive = Color(0.3, 0.2, 0.1) * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))
		else:
			_material.emissive = Color(0, 0, 0, 0)

	oven_pizza.bake(delta)
	var done := oven_pizza.stage == Pizza.Stage.BAKED or oven_pizza.stage == Pizza.Stage.BURNT
	if done and not _announced:
		_announced = true
		GameManager.set_hint("Pizza is done! Pull it out with G.")
