class_name InteractionController
extends Node3D
## Raycasts the world and routes the pizza-making flow.
##
## G = grab / interact (dough, sauce, cheese, toppings, prep table, oven, counter)
## L = drop whatever you are holding (it falls with real physics)
##
## The intended order is:
##   dough  -> prep table
##   sauce  -> onto the dough
##   cheese -> onto the sauce
##   toppings -> onto the cheese
##   then bake it and serve it.

var reach := 6.0
var camera_reach := 14.0
const STATION_AIM_HEIGHT := 0.9

var _char: PhysicsBody3D
var _dropper: PhysicsDropper

func setup(c: PhysicsBody3D) -> void:
	_char = c
	if _dropper == null:
		_dropper = PhysicsDropper.new()
		_dropper.name = "PhysicsDropper"
		add_child(_dropper)

func _unhandled_input(e: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_G:
			_interact()
		elif e.keycode == KEY_L:
			_drop()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_interact()

# --- targeting ---

func _cast(o: Vector3, d: Vector3, dist: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(o, o + d * dist)
	q.exclude = [_char.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _all_stations() -> Array:
	var out: Array = []
	for s in get_tree().get_nodes_in_group("stations"):
		if s is KitchenStation:
			out.append(s)
	if out.is_empty():
		var k = get_tree().current_scene.get_node_or_null("Kitchen")
		if k:
			for c in k.get_children():
				if c is KitchenStation:
					out.append(c)
	return out

func _station_center(s: KitchenStation) -> Vector3:
	return s.global_position + Vector3(0, STATION_AIM_HEIGHT, 0)

func _pick() -> Dictionary:
	var c := get_viewport().get_camera_3d()
	if c == null or _char == null:
		return {}
	var cam_pos := c.global_position
	var cam_fwd := -c.global_transform.basis.z

	# Aim the ray at countertop height so it lands on the stations instead of
	# sailing over them (the camera looks slightly downward).
	var aim := cam_fwd
	if cam_fwd.y < -0.02:
		var t: float = (STATION_AIM_HEIGHT - cam_pos.y) / cam_fwd.y
		if t > 0.0 and t < camera_reach:
			aim = ((cam_pos + cam_fwd * t) - cam_pos).normalized()
	if aim.y < -0.6:
		aim.y = -0.6
		aim = aim.normalized()

	var direct := _cast(cam_pos, aim, camera_reach)
	if not direct.is_empty() and _station_of(direct.get("collider") as Node) != null:
		return direct

	# Screen-space pick: the station whose centre projects closest to the middle
	# of the screen is the one the player is looking at.
	var vp := c.get_viewport()
	var screen := vp.get_visible_rect().size * 0.5
	var best: KitchenStation = null
	var best_score := 1e20
	for s in _all_stations():
		var center := _station_center(s)
		if cam_pos.distance_to(center) > camera_reach:
			continue
		var sp := c.unproject_position(center)
		var d := sp.distance_to(screen)
		if d < best_score:
			best_score = d
			best = s
	if best != null and best_score < 320.0:
		return {"collider": best, "position": _station_center(best), "normal": Vector3.UP}

	# Fallback: from the player's chest, along the camera's facing direction.
	var o := _char.global_position + Vector3(0, 1.2, 0)
	var hit := _cast(o, cam_fwd, reach)
	if not hit.is_empty():
		return hit
	# Last resort: straight ahead of the character.
	var fwd := -_char.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001:
		return _cast(_char.global_position + Vector3(0, 1.0, 0), fwd.normalized(), reach)
	return {}

func _station_of(n: Node) -> KitchenStation:
	var cur := n
	while cur:
		if cur is KitchenStation:
			return cur
		cur = cur.get_parent()
	return null

# --- helpers ---

func _interact() -> void:
	var hit := _pick()
	if hit.is_empty():
		GameManager.set_hint("")
		return
	var st := _station_of(hit.collider as Node)
	if st == null:
		GameManager.set_hint("")
		return
	_marker(hit.get("position", st.global_position))
	_use(st, hit)

func _marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	marker.mesh = sm
	marker.global_position = pos
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1, 1, 1, 0.6)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mm
	add_child(marker)
	var t := get_tree().create_timer(0.2)
	t.timeout.connect(marker.queue_free)

func _hold(p: Pizza) -> void:
	p.reparent(_char, false)
	p.position = Vector3(0, 1.15, -0.55)
	p.rotation_degrees = Vector3(-72, 0, 0)

func _show_held(ing: String) -> void:
	_clear_held()
	if ing == "" or _char == null:
		return
	var mi := Pizza.make_ingredient_mesh(ing)
	mi.name = "HeldIngredient"
	# Sit the item in the character's right hand (GLB RHand rests near x0.68, y1.28)
	mi.position = Vector3(0.66, 1.24, -0.10)
	mi.rotation_degrees = Vector3(20, 0, -12)
	_char.add_child(mi)

func _clear_held() -> void:
	if _char == null or not is_instance_valid(_char):
		return
	var old := _char.get_node_or_null("HeldIngredient")
	if old:
		old.queue_free()

func _prep_table() -> KitchenStation:
	for s in _all_stations():
		if s.kind == KitchenStation.Kind.PREP:
			return s
	return null

## The topping station serves whichever topping the current order still needs.
func _next_topping(st: KitchenStation) -> String:
	var g := GameManager
	var table := _prep_table()
	var placed: Pizza = table.placed_pizza if table != null else null
	var have: Array[String] = placed.toppings if placed != null else []
	var needed: Array[String] = []
	for t in g.required:
		if not have.has(t) and not needed.has(t):
			needed.append(t)
	if needed.is_empty():
		return ""
	return needed[0]

func _counter() -> KitchenStation:
	for s in _all_stations():
		if s.kind == KitchenStation.Kind.COUNTER:
			return s
	return null

# --- station use ---

func _use(st: KitchenStation, hit: Dictionary) -> void:
	var g := GameManager
	match st.kind:
		KitchenStation.Kind.DOUGH:
			if g.hands_pizza == null and g.hands_ingredient == "":
				var p := Pizza.new()
				add_child(p)
				g.set_hands_pizza(p)
				_hold(p)
				g.set_hint("Dough in hand. Drop it on the prep table with L.")
			else:
				g.set_hint("Your hands are full.")
		KitchenStation.Kind.SAUCE, KitchenStation.Kind.CHEESE:
			if g.hands_pizza != null:
				g.set_hint("Your hands are full.")
				return
			g.set_hands_ingredient(st.ingredient)
			_show_held(st.ingredient)
			g.set_hint("Holding %s. Drop it on the prep table with L." % st.ingredient.capitalize())
		KitchenStation.Kind.TOPPING:
			if g.hands_pizza != null:
				g.set_hint("Your hands are full.")
				return
			var ing := _next_topping(st)
			if ing == "":
				g.set_hint("No toppings left for this order.")
				return
			g.set_hands_ingredient(ing)
			_show_held(ing)
			g.set_hint("Holding %s. Drop it on the prep table with L." % ing.capitalize())
		KitchenStation.Kind.PREP:
			_prep(st)
		KitchenStation.Kind.OVEN:
			_oven(st)
		KitchenStation.Kind.COUNTER:
			_serve(st)

func _prep(st: KitchenStation) -> void:
	var g := GameManager
	var p := st.placed_pizza
	if g.hands_pizza:
		if p:
			g.set_hint("The prep table is already occupied.")
			return
		g.set_hint("Drop the dough on the table with L.")
		return
	if p == null:
		g.set_hint("Nothing on the table.")
		return
	if g.hands_ingredient == "":
		# Pick the finished (or partly built) pizza back up.
		st.placed_pizza = null
		g.set_hands_pizza(p)
		_hold(p)
		g.set_hint("Pizza in hand.")
		return
	g.set_hint("Drop the %s onto the pizza with L." % g.hands_ingredient.capitalize())

# --- dropping ---

func _drop() -> void:
	var g := GameManager
	if _dropper == null or _dropper.is_busy():
		g.set_hint("Busy.")
		return
	var table := _prep_table()
	if table == null:
		g.set_hint("No prep table found.")
		return

	# Dropping the dough: the pizza itself falls onto the table.
	if g.hands_pizza != null:
		var p := g.hands_pizza
		if table.placed_pizza != null:
			g.set_hint("The prep table is already occupied.")
			return
		g.set_hands_pizza(null)
		_drop_pizza(p, table)
		return

	# Dropping an ingredient: it falls onto whatever is on the table.
	if g.hands_ingredient != "":
		var ing := g.hands_ingredient
		g.set_hands_ingredient("")
		_clear_held()
		_drop_ingredient(ing, table)
		return

	g.set_hint("You are not holding anything.")

func _drop_pizza(p: Pizza, table: KitchenStation) -> void:
	# Free the pizza from the player's hand and let it fall onto the table.
	p.reparent(self, false)
	var target := table.global_position + Vector3(0, 1.6, 0)
	p.global_position = target
	_dropper.drop(p, _surfaces_for(table, null))
	await _dropper.dropped
	var res: Dictionary = _dropper.last_result
	if not res.get("ok", false):
		GameManager.set_hint("Could not drop the dough.")
		return
	table.placed_pizza = p
	p.reparent(table.anchor, false)
	p.position = Vector3.ZERO
	p.rotation_degrees = Vector3.ZERO
	GameManager.set_hint("Dough on the prep table. Now grab the sauce.")

## The surfaces a dropped item can land on: the prep table top, the room floor
## and (when topping the pizza) the pizza's own top layer.
func _surfaces_for(table: KitchenStation, pizza: Pizza) -> Array:
	var out: Array = []
	var top := table.global_position + Vector3(0, 1.1, 0)
	out.append(PhysicsDropper.Surface.box(top, Vector3(1.4, 0.2, 1.4)))
	out.append(PhysicsDropper.Surface.box(Vector3(0, -0.1, 0), Vector3(16, 0.2, 18)))
	if pizza != null:
		# The pizza's own top layer, so toppings land on the cheese.
		var p_top := pizza.global_position + Vector3(0, pizza.top_y(), 0)
		out.append(PhysicsDropper.Surface.cyl(p_top, Pizza.DOUGH_RADIUS, 0.08))
	return out

func _drop_ingredient(ing: String, table: KitchenStation) -> void:
	var p := table.placed_pizza
	if p == null:
		GameManager.set_hint("Put the dough on the table first.")
		return
	# Enforce the intended order.
	if ing == "sauce" and p.stage != Pizza.Stage.DOUGH:
		GameManager.set_hint("Sauce goes on the plain dough.")
		return
	if ing == "cheese" and p.stage != Pizza.Stage.SAUCED:
		GameManager.set_hint("Cheese goes on the sauce.")
		return
	if ing != "sauce" and ing != "cheese" and p.stage != Pizza.Stage.CHEESED:
		GameManager.set_hint("Toppings go on the cheese.")
		return

	var mi := Pizza.make_ingredient_mesh(ing)
	mi.name = "DroppedIngredient"
	add_child(mi)
	# Start the drop just above the pizza so it falls onto the right layer.
	mi.global_position = p.global_position + Vector3(randf_range(-0.12, 0.12), 0.55, randf_range(-0.12, 0.12))
	_dropper.drop(mi, _surfaces_for(table, p))
	await _dropper.dropped
	var res: Dictionary = _dropper.last_result
	if not res.get("ok", false):
		mi.queue_free()
		GameManager.set_hint("Could not drop the %s." % ing)
		return
	var xform: Transform3D = res.get("transform", mi.global_transform)
	mi.queue_free()
	if ing == "sauce":
		p.add_sauce()
		GameManager.set_hint("Sauce on the dough. Now the cheese.")
	elif ing == "cheese":
		p.add_cheese()
		GameManager.set_hint("Cheese on. Now the toppings.")
	else:
		p.attach_topping(ing, xform)
		GameManager.set_hint("%s added. Grab more toppings or bake it." % ing.capitalize())

# --- oven & counter ---

func _oven(st: KitchenStation) -> void:
	var g := GameManager
	if g.hands_pizza:
		var p := g.hands_pizza
		if st.oven_pizza:
			g.set_hint("The oven is busy.")
			return
		if p.stage != Pizza.Stage.TOPPED and p.stage != Pizza.Stage.BAKED and p.stage != Pizza.Stage.BAKING:
			g.set_hint("Add toppings before baking!")
			return
		p.reparent(st.anchor, false)
		p.position = Vector3.ZERO
		p.rotation_degrees = Vector3.ZERO
		st.oven_pizza = p
		g.set_hands_pizza(null)
		g.set_hint("Baking...")
		return
	var o := st.oven_pizza
	if o == null:
		g.set_hint("Nothing to bake.")
		return
	if o.stage == Pizza.Stage.BAKED or o.stage == Pizza.Stage.BURNT:
		st.oven_pizza = null
		g.set_hands_pizza(o)
		_hold(o)
		g.set_hint("Pizza ready! Take it to the counter with G.")
	else:
		g.set_hint("Still baking...")

func _serve(_st: KitchenStation) -> void:
	var g := GameManager
	if g.hands_pizza == null:
		g.set_hint("Bring a baked pizza to the counter.")
		return
	var p := g.hands_pizza
	if p.stage != Pizza.Stage.BAKED and p.stage != Pizza.Stage.BURNT:
		g.set_hint("That isn't baked yet!")
		return
	g.set_hands_pizza(null)
	g.serve(p)
	p.queue_free()
