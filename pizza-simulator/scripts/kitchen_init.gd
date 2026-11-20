extends Node3D
## Initializes all stations in the kitchen.

var initialized_count := 0

func _ready() -> void:
	initialize_stations()

func initialize_stations() -> void:
	initialized_count = 0
	# The cooking line runs along z = 5. It reads left to right from the
	# player's default view: ingredients, prep table, oven, then the serve
	# counter on the far side.
	var stations = [
		{"name": "DOUGH_STATION", "kind": 0, "label": "DOUGH", "ing": "", "pos": Vector3(6.3, 0, 5)},
		{"name": "SAUCE_STATION", "kind": 1, "label": "SAUCE", "ing": "sauce", "pos": Vector3(4.8, 0, 5)},
		{"name": "CHEESE_STATION", "kind": 2, "label": "CHEESE", "ing": "cheese", "pos": Vector3(3.3, 0, 5)},
		{"name": "TOPPING_STATION", "kind": 3, "label": "TOPPINGS", "ing": "pepperoni", "pos": Vector3(1.8, 0, 5)},
		{"name": "PREP_TABLE", "kind": 4, "label": "PREP TABLE", "ing": "", "pos": Vector3(2.55, 0, 2)},
		# The oven is a real model: width, height, depth and the yaw that
		# turns its front towards the room.
		{"name": "OVEN", "kind": 5, "label": "OVEN", "ing": "", "pos": Vector3(0, 0, 5),
			"model": "res://models/Pizza-Oven.glb", "size": Vector3(1.5, 1.0, 0.9), "yaw": 90.0},
		{"name": "COUNTER", "kind": 6, "label": "SERVE", "ing": "", "pos": Vector3(-6.3, 0, 3.6)}
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
		if s.has("model") and node.has_method("setup_model"):
			node.setup_model(s.model, s.size, s.yaw)
			initialized_count += 1
		else:
			initialized_count += 1

	if initialized_count < total_stations:
		printerr("Initialized only %d/%d stations." % [initialized_count, total_stations])
	else:
		print("Kitchen initialized successfully with %d stations." % initialized_count)
