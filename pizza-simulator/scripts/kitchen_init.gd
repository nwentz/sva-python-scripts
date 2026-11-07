extends Node3D
## Initializes all stations in the kitchen.

var initialized_count := 0

func _ready() -> void:
	initialize_stations()

func initialize_stations() -> void:
	var stations = [
		{"name": "DOUGH_STATION", "kind": 0, "label": "DOUGH", "ing": ""},
		{"name": "SAUCE_STATION", "kind": 1, "label": "SAUCE", "ing": "sauce"},
		{"name": "CHEESE_STATION", "kind": 2, "label": "CHEESE", "ing": "cheese"},
		{"name": "TOPPING_STATION", "kind": 3, "label": "TOPPINGS", "ing": "pepperoni"},
		{"name": "PREP_TABLE", "kind": 4, "label": "PREP TABLE", "ing": ""},
		{"name": "OVEN", "kind": 5, "label": "OVEN", "ing": ""},
		{"name": "COUNTER", "kind": 6, "label": "SERVE", "ing": ""}
	]

	var total_stations := len(stations)
	for s in stations:
		var node = get_node(s.name)
		if node:
			if node.has_method("setup_station"):
				node.setup_station(s.kind, s.label, s.ing)
				initialized_count += 1
			else:
				push_warning("Station %s exists but doesn't have setup_station method" % s.name)
		else:
			push_warning("Station node %s not found in scene!" % s.name)

	if initialized_count < total_stations:
		printerr("Initialized only %d/%d stations. Some stations are missing from the scene." % [initialized_count, total_stations])
	else:
		print("Kitchen initialized successfully with %d stations." % initialized_count)
