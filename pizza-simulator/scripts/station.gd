class_name KitchenStation
extends StaticBody3D
## An interactable station. Builds its own pizza anchor and name label.

enum Kind { DOUGH, SAUCE, CHEESE, TOPPING, PREP, OVEN, COUNTER }

@export var metadata := {
	"kind": 0,
	"label": "",
	"ingredient": ""
}

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

func _ready() -> void:
	_anchor()

	if metadata.get("label", "") != "":
		_label()

	# Set up material based on station type
	match metadata["kind"]:
		Kind.DOUGH: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.95, 0.87, 0.7)
		Kind.SAUCE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.78, 0.17, 0.12)
		Kind.CHEESE: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.98, 0.85, 0.42)
		Kind.TOPPING: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.7, 0.4, 0.4)
		Kind.PREP: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.9, 0.9, 0.9)
		Kind.OVEN: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.4, 0.4, 0.4)
		Kind.COUNTER: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.1, 0.1, 0.1)
		_: _material = StandardMaterial3D.new(); _material.albedo_color = Color(0.44, 0.38, 0.31)

func _anchor() -> void:
	anchor = Node3D.new()
	anchor.name = "Anchor"
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
		GameManager.set_hint("Pizza is done! Pull it out with E.")
