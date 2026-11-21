extends Node3D
## Headless regression test for the make-a-pizza flow.
## Drives the interaction controller exactly like the player would.

var main: Node3D
var char: CharacterBody3D
var rig: Node3D
var inter: Node

func _ready() -> void:
	await _run()
	get_tree().quit()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	char = main.get_node_or_null("Character")
	rig = main.get_node_or_null("CameraRig")
	inter = main.get_node_or_null("Interaction")
	print("character=", char, " rig=", rig, " inter=", inter)
	if char == null or rig == null or inter == null:
		return

	# --- camera sanity -------------------------------------------------
	print("\n=== CAMERA CHECK ===")
	var cam_node := rig.get_node("Camera") as Camera3D
	for pos in [Vector3(0,0,0), Vector3(4,0,0), Vector3(7.2,0,0), Vector3(-7.2,0,0), Vector3(0,0,8.0),
			Vector3(0,0,-8.0), Vector3(5.0,0,6.0), Vector3(-5.0,0,-6.0), Vector3(0,0,6.0), Vector3(0,0,-6.0)]:
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			char.global_position = pos
			rig.set("yaw", yaw)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var cam := get_viewport().get_camera_3d()
			var tgt: Node3D = rig.get("target")
			var pivot := tgt.global_position + Vector3(0, 1.55, 0)
			var d := cam.global_position.distance_to(pivot)
			var behind: bool = (cam.global_position - pivot).dot(-cam.global_transform.basis.z) < 0.0
			# the camera must stay behind the player (never first person),
			# stay out of the floor and stay inside the room
			var inside := absf(cam.global_position.x) <= 8.85 and absf(cam.global_position.z) <= 9.85
			var flag := "OK " if (d > 1.0 and behind and inside and cam.global_position.y > 1.0) else "BAD"
			print("  %s char=%-16s yaw=%.2f cam=%-24s dist=%.2f behind=%s" % [flag, char.global_position, yaw, cam.global_position, d, behind])

	# --- reachability ---------------------------------------------------
	# Every station must be walkable to: the player has to be able to stand
	# in front of it and interact with it.
	print("\n=== REACHABILITY ===")
	for label in ["DOUGH", "SAUCE", "CHEESE", "TOPPINGS", "PREP TABLE", "OVEN", "SERVE"]:
		var st := _station(label)
		if st == null:
			print("  %-12s MISSING" % label)
			continue
		# stand 1.6 units in front of the station (towards the room centre)
		# and face it
		var s := st.global_position
		var side := Vector3(-s.x, 0.0, -s.z)
		if side.length() < 0.01:
			side = Vector3(0, 0, 1)
		side = side.normalized()
		var stand := s + side * 1.6
		stand.y = 0.0
		char.global_position = stand
		# the camera sits behind the player, so the player faces -side
		rig.set("yaw", atan2(side.x, side.z))
		for i in 4:
			await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var reached := char.global_position.distance_to(stand)
		var pick: Dictionary = inter.call("_pick")
		var stn: KitchenStation = inter.call("_station_of", pick.get("collider"))
		var got := stn.label if stn != null else "nothing"
		var flag := "OK " if (got == label and reached < 2.6) else "BAD"
		print("  %s %-12s stand=%s ended=%s (off by %.2f) picks=%s" % [flag, label, stand, char.global_position, reached, got])

	# The outermost stations sit at x = +-6: the player has to be able to
	# walk right up to them.
	print("\n=== OUTER STATIONS ===")
	for label in ["DOUGH", "SERVE"]:
		var st2 := _station(label)
		var s2 := st2.global_position
		# walk towards the station from the middle of the room
		var from := Vector3(0, 0, s2.z * 0.4)
		char.global_position = from
		# the camera looks along -offset, so to look at direction d the yaw is
		# atan2(-d.x, -d.z)
		var look2 := (s2 - from)
		look2.y = 0.0
		look2 = look2.normalized()
		rig.set("yaw", atan2(-look2.x, -look2.z))
		for i in 4:
			await get_tree().physics_frame
		await get_tree().process_frame
		# now drive the character towards the station with real movement.
		# ui_input is camera-relative: x is right, -y is forward.
		for i in 300:
			var cam2 := get_viewport().get_camera_3d()
			var fwd2 := -cam2.global_basis.z; fwd2.y = 0.0
			var right2 := cam2.global_basis.x; right2.y = 0.0
			var dir2 := (s2 - char.global_position)
			dir2.y = 0.0
			dir2 = dir2.normalized()
			char.ui_input = Vector2(dir2.dot(right2), -dir2.dot(fwd2))
			await get_tree().physics_frame
		char.ui_input = Vector2.ZERO
		await get_tree().process_frame
		# now aim at the station and check that it is the one being picked
		var aim2 := (s2 - char.global_position)
		aim2.y = 0.0
		aim2 = aim2.normalized()
		rig.set("yaw", atan2(-aim2.x, -aim2.z))
		await get_tree().process_frame
		await get_tree().process_frame
		var d2 := Vector2(char.global_position.x - s2.x, char.global_position.z - s2.z).length()
		var pick2: Dictionary = inter.call("_pick")
		var stn2: KitchenStation = inter.call("_station_of", pick2.get("collider"))
		var got2 := stn2.label if stn2 != null else "nothing"
		var flag2 := "OK " if (got2 == label and d2 < 1.6) else "BAD"
		print("  %s %-12s walked to=%s station=%s (dist %.2f) picks=%s" % [flag2, label, char.global_position, s2, d2, got2])

	# --- flow ----------------------------------------------------------
	print("\n=== FLOW ===")
	await _step("DOUGH", "interact")
	print("  hands_pizza=", GameManager.hands_pizza)
	await _drop()
	var table := _station("PREP TABLE")
	print("  table.placed_pizza=", table.placed_pizza)
	# Kneading is now required before sauce; work through the K minigame.
	await _knead_dough()
	print("  kneaded=", table.placed_pizza.kneaded if table.placed_pizza else false,
		" presses=", table.placed_pizza.kneads if table.placed_pizza else -1)

	await _step("SAUCE", "interact")
	print("  hands_ingredient=", GameManager.hands_ingredient)
	# The sauce bottle is spread by circling the mouse in the close-up.
	await _step("PREP TABLE", "interact")
	inter.call("_drop")  # L starts the spreading close-up
	await get_tree().process_frame
	for i in 144:
		var a := TAU * float(i) / 24.0
		inter.call("_spread_motion", Vector2(cos(a), sin(a)) * 8.0)
	await get_tree().process_frame
	print("  stage=", table.placed_pizza.stage if table.placed_pizza else -1)

	await _step("CHEESE", "interact")
	# Cheese is cut with C in its own close-up, not dropped.
	await _step("PREP TABLE", "interact")
	inter.call("_drop")  # L starts the cutting close-up
	for i in Pizza.CHEESE_CUTS_REQUIRED:
		inter.call("_cut_cheese")
		await get_tree().process_frame
	print("  stage=", table.placed_pizza.stage if table.placed_pizza else -1)

	for i in GameManager.required.size():
		await _step("TOPPINGS", "interact")
		print("  ingredient=", GameManager.hands_ingredient)
		await _drop()
		print("  stage=", table.placed_pizza.stage if table.placed_pizza else -1)

	# pick the pizza up
	await _step("PREP TABLE", "interact")
	print("  hands_pizza=", GameManager.hands_pizza, " table.placed=", table.placed_pizza)

	# into the oven
	await _step("OVEN", "interact")
	_debug_pick()
	var oven := _station("OVEN")
	print("  oven_pizza=", oven.oven_pizza, " stage=", oven.oven_pizza.stage if oven.oven_pizza else -1)
	print("  hands_pizza=", GameManager.hands_pizza)

	# wait for the bake
	await get_tree().create_timer(9.0).timeout
	print("  after 9s stage=", oven.oven_pizza.stage if oven.oven_pizza else -1)

	await _step("OVEN", "interact")
	print("  hands_pizza=", GameManager.hands_pizza, " oven_pizza=", oven.oven_pizza)

	await _step("SERVE", "interact")
	print("  score=", GameManager.score, " served=", GameManager.served)

	# --- phase 2: normal (undamaged) camera, standing at the oven --------
	print("\n=== PHASE 2: camera at full length ===")
	# hold a pizza so the carried pizza can block the interaction ray
	var held := Pizza.new()
	inter.add_child(held)
	GameManager.set_hands_pizza(held)
	inter.call("_hold", held)
	await get_tree().process_frame
	for spot in [Vector3(0,0,2.8), Vector3(0,0,4.0), Vector3(1.5,0,3.5), Vector3(0,0,1.0)]:
		cam_node.position = Vector3(0, 0, 3.2)
		char.global_position = spot
		rig.set("yaw", PI)
		await get_tree().process_frame
		await get_tree().process_frame
		print("  spot=", spot)
		_debug_pick()
		var pick: Dictionary = inter.call("_pick")
		var stn: KitchenStation = inter.call("_station_of", pick.get("collider"))
		print("    -> WOULD PICK: ", (stn.label if stn != null else "nothing"))

func _station(label: String) -> KitchenStation:
	for s in inter.call("_all_stations"):
		if s.label == label:
			return s
	return null

func _step(label: String, _kind: String) -> void:
	var st := _station(label)
	if st == null:
		print("!! station not found: ", label)
		return
	var s := st.global_position
	var approach := Vector3(-s.x, 0, -s.z)
	if approach.length() < 0.01:
		approach = Vector3(0, 0, 1)
	approach = approach.normalized()
	char.global_position = s + approach * 2.2
	rig.set("yaw", atan2(approach.x, approach.z))
	await get_tree().process_frame
	await get_tree().process_frame
	var pick: Dictionary = inter.call("_pick")
	var hit_name := "none"
	if not pick.is_empty():
		var col: Node = pick.get("collider")
		var stn: KitchenStation = inter.call("_station_of", col)
		hit_name = (stn.label if stn != null else str(col))
	inter.call("_interact")
	print("[%s] picked=%s hint=%s" % [label, hit_name, GameManager.hint])
	if label == "DOUGH":
		var c := get_viewport().get_camera_3d()
		var direct: Dictionary = inter.call("_cast", c.global_position, -c.global_transform.basis.z, 14.0)
		print("   cam=", c.global_position, " direct=", direct.get("collider"), " pos=", direct.get("position"))
		print("   char=", char.global_position, " target=", st.global_position)

func _drop() -> void:
	inter.call("_drop")
	await get_tree().create_timer(2.0).timeout
	await get_tree().process_frame

func _knead_dough() -> void:
	for i in Pizza.KNEADS_REQUIRED:
		inter.call("_knead")
		await get_tree().process_frame

func _debug_pick() -> void:
	var c := get_viewport().get_camera_3d()
	var cam_pos := c.global_position
	var cam_fwd := -c.global_transform.basis.z
	var direct: Dictionary = inter.call("_cast", cam_pos, cam_fwd, 14.0)
	var dn := "none"
	if not direct.is_empty():
		dn = str(direct.get("collider"))
	print("  cam=", cam_pos, " direct collider=", dn)
	var vp := c.get_viewport()
	var screen := vp.get_visible_rect().size * 0.5
	print("  screen center=", screen, " viewport=", vp.get_visible_rect().size)
	for s in inter.call("_all_stations"):
		var st: KitchenStation = s
		var center: Vector3 = st.global_position + Vector3(0, 0.9, 0)
		var sp := c.unproject_position(center)
		var behind := c.is_position_behind(center)
		print("    %-12s proj=%s behind=%s score=%.0f" % [st.label, sp, behind, sp.distance_to(screen)])
