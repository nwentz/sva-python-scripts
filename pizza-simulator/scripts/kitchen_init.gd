extends Node3D
## Initializes all stations in the kitchen.

var initialized_count := 0

func _ready() -> void:
	initialize_stations()

func initialize_stations() -> void:
	initialized_count = 0
	var stations = [
		{"name": "DOUGH_STATION", "kind": 0, "label": "DOUGH", "ing": "", "pos": Vector3(-6, 0.5, -5.2)},
		{"name": "SAUCE_STATION", "kind": 1, "label": "SAUCE", "ing": "sauce", "pos": Vector3(-4.5, 0.5, -5.2)},
		{"name": "CHEESE_STATION", "kind": 2, "label": "CHEESE", "ing": "cheese", "pos": Vector3(-3, 0.5, -5.2)},
		{"name": "TOPPING_STATION", "kind": 3, "label": "TOPPINGS", "ing": "pepperoni", "pos": Vector3(-1.5, 0.5, -5.2)},
		{"name": "PREP_TABLE", "kind": 4, "label": "PREP TABLE", "ing": "", "pos": Vector3(0, 0.5, -5.2)},
		{"name": "OVEN", "kind": 5, "label": "OVEN", "ing": "", "pos": Vector3(0, 0, 5)},
		{"name": "COUNTER", "kind": 6, "label": "SERVE", "ing": "", "pos": Vector3(6, 0, 5)}
	]

	var total_stations := len(stations)
	for s in stations:
		var node = get_parent().get_node_or_null(s.name)
		if node == null:
			node = KitchenStation.new()
			node.name = s.name
			node.position = s.pos
			get_parent().add_child(node)
		if node.has_method("setup_station"):
			node.setup_station(s.kind, s.label, s.ing)
			initialized_count += 1

	if initialized_count < total_stations:
		printerr("Initialized only %d/%d stations." % [initialized_count, total_stations])
	else:
		print("Kitchen initialized successfully with %d stations." % initialized_count)
