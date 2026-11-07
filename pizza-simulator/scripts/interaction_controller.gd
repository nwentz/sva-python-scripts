class_name InteractionController
extends Node3D
## Raycasts the world, routes E / left-click to the station being looked at.

var reach := 6.0
var _char: PhysicsBody3D
var scatter_count := 3

func setup(c: PhysicsBody3D) -> void:
	_char = c

func _unhandled_input(e: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E:
		_interact()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_interact()

func _pick() -> Dictionary:
	var c := get_viewport().get_camera_3d()
	if c == null or _char == null:
		return {}
	var o := c.global_position
	var d := -c.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + d * reach)
	q.exclude = [_char.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _station_of(n: Node) -> KitchenStation:
	var cur := n
	while cur:
		if cur is KitchenStation:
			return cur
		cur = cur.get_parent()
	return null

func _interact() -> void:
	var hit := _pick()
	if hit.is_empty():
		GameManager.set_hint("")
		return
	var st := _station_of(hit.collider as Node)
	if st == null:
		GameManager.set_hint("")
		return

	# Add a little visual feedback
	if hit.has("position"):
		var c := get_viewport().get_camera_3d()
		if c:
			var marker := ColorRect.new()
			marker.size = Vector2(0.15, 0.15)
			marker.global_position = c.project(hit["position"])
			marker.modulate = Color(1, 1, 1, 0.5)
			marker.z_index = 100
			add_child(marker)
			marker.queue_free()
			await get_tree().process_frame
			await get_tree().create_timer(0.1).timeout
			marker.queue_free()

	_use(st, hit)

func _hold(p: Pizza) -> void:
	p.reparent(_char, false)
	p.position = Vector3(0, 1.15, -0.55)
	p.rotation_degrees = Vector3(-72, 0, 0)

func _use(st: KitchenStation, hit: Dictionary) -> void:
	var g := GameManager
	match st.kind:
		KitchenStation.Kind.DOUGH:
			if g.hands_pizza == null and g.hands_ingredient == "":
				var p := Pizza.new()
				add_child(p)
				g.set_hands_pizza(p)
				_hold(p)
				g.set_hint("Dough in hand - take it to the prep table and press E to stretch.")
			else:
				g.set_hint("Your hands are full.")
		KitchenStation.Kind.SAUCE, KitchenStation.Kind.CHEESE, KitchenStation.Kind.TOPPING:
			g.set_hands_ingredient(st.ingredient)
			g.set_hint("Grabbed %s. Use it on the pizza at the prep table." % st.ingredient.capitalize())
		KitchenStation.Kind.PREP:
			_prep(st, hit)
		KitchenStation.Kind.OVEN:
			_oven(st)
		KitchenStation.Kind.COUNTER:
			_serve(st)

func _prep(st: KitchenStation, hit: Dictionary) -> void:
	var g := GameManager
	var p := st.placed_pizza
	if g.hands_pizza:
		if p:
			g.set_hint("The prep table is already occupied.")
			return
		var hp := g.hands_pizza
		hp.reparent(st.anchor, false)
		hp.position = Vector3.ZERO
		hp.rotation_degrees = Vector3.ZERO
		st.placed_pizza = hp
		g.set_hands_pizza(null)
		g.set_hint("Pizza down. Press E on it to stretch, or grab an ingredient.")
		return
	if p == null:
		g.set_hint("Nothing on the table.")
		return
	if p.stage == Pizza.Stage.DOUGH:
		if g.hands_ingredient != "":
			g.set_hint("Clear your hands first.")
			return
		p.stage = Pizza.Stage.STRETCHED
		g.set_hint("Dough stretched! Grab the sauce next.")
		return
	if g.hands_ingredient == "":
		st.placed_pizza = null
		g.set_hands_pizza(p)
		_hold(p)
		g.set_hint("Pizza in hand.")
		return
	_apply(p, hit)

func _apply(p: Pizza, hit: Dictionary) -> void:
	var g := GameManager
	var ing := g.hands_ingredient
	match ing:
		"sauce":
			if p.stage == Pizza.Stage.STRETCHED:
				p.stage = Pizza.Stage.SAUCED
				g.set_hands_ingredient("")
				g.set_hint("Sauce spread. Now the cheese.")
			else:
				g.set_hint("Stretch the dough first.")
		"cheese":
			if p.stage == Pizza.Stage.SAUCED:
				p.stage = Pizza.Stage.CHEESED
				g.set_hands_ingredient("")
				g.set_hint("Cheese on. Now add toppings.")
			else:
				g.set_hint("Sauce goes first.")
		_:
			if p.stage == Pizza.Stage.CHEESED or p.stage == Pizza.Stage.TOPPED:
				for i in range(p.scatter_count):
					p.add_topping(ing, p.to_local(hit.position))
				p.stage = Pizza.Stage.TOPPED
				g.set_hint("Added %s - click again for more, then bake it." % ing)
			else:
				g.set_hint("Cheese first.")

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
		g.set_hint("Pizza ready! Take it to the counter with E.")
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
