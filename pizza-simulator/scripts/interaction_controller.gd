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
const STATION_TOP_HEIGHT := 1.1
## How far (in pixels) the crosshair may be from a station for it to count.
const SCREEN_MAX_DISTANCE := 320.0
## How much closer to the crosshair a station has to be to win over the one
## the interaction ray physically hit.
const SCREEN_TOLERANCE := 40.0

var _char: PhysicsBody3D
var _dropper: PhysicsDropper

func setup(c: PhysicsBody3D) -> void:
	_char = c
	if _dropper == null:
		_dropper = PhysicsDropper.new()
		_dropper.name = "PhysicsDropper"
		add_child(_dropper)

## Plays a character gesture (grab / place / oven / serve).
func _gesture(action: String) -> void:
	if _char != null and is_instance_valid(_char) and _char.has_method("play_action"):
		_char.play_action(action)

func _unhandled_input(e: InputEvent) -> void:
	# ESC is also the escape hatch for any of the close-up minigames, so a
	# player who is stuck in the knead/sauce/cheese view can get back to the
	# normal third-person camera and mouse control.
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if _cancel_closeup():
			return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var spreading := GameManager.spreading_pizza != null
	if spreading and e is InputEventMouseMotion:
		_spread_motion((e as InputEventMouseMotion).relative)
		return
	var kneading := GameManager.kneading_pizza != null
	var cutting := GameManager.cutting_cheese != null
	var busy := kneading or spreading or cutting
	if e is InputEventKey and e.pressed and not e.echo:
		if cutting:
			if e.keycode == KEY_C:
				_cut_cheese()
			else:
				GameManager.set_hint("Press C to cut the cheese.")
			return
		if spreading:
			GameManager.set_hint("Keep moving the mouse in circles to spread the sauce.")
			return
		if e.keycode == KEY_K:
			_knead()
			return
		if kneading and (e.keycode == KEY_G or e.keycode == KEY_L):
			GameManager.set_hint("Finish kneading the dough first - press K.")
			return
		if e.keycode == KEY_G:
			_interact()
		elif e.keycode == KEY_L:
			_drop()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if busy:
			return
		_interact()

## Pressing K works the dough once. When it is kneaded the camera eases back
## out to the normal third-person view and sauce is unlocked.
func _knead() -> void:
	var p := GameManager.kneading_pizza
	if p == null or not is_instance_valid(p) or p.kneaded:
		return
	p.knead()
	if p.kneaded:
		GameManager.finish_knead()
		_set_station_labels(true)
		var rig := _camera_rig()
		if rig != null and rig.has_method("clear_focus"):
			rig.clear_focus()
		_gesture("place")
		GameManager.set_hint("Dough kneaded! Now grab the sauce.")
	else:
		GameManager.set_hint("Knead the dough: %d/%d - press K again." % [p.kneads, Pizza.KNEADS_REQUIRED])

## Spreading sauce is a close-up minigame like kneading: the player moves the
## mouse in a circle over the dough and the sauce disc grows with each turn.
const SPREAD_ROTATIONS := 4
## Keep the virtual cursor near the middle of the dough, not out at the edge.
const SPREAD_STEP := 0.005
const SPREAD_MIN_RADIUS := 0.03
const SPREAD_MAX_RADIUS := 0.16
var _spread_cursor := Vector2.ZERO
var _spread_last_angle := 0.0
var _spread_accum := 0.0
var _spread_turns := 0
var _spread_started := false
var _spreader: MeshInstance3D = null

func _start_spreading() -> void:
	if GameManager.kneading_pizza != null or GameManager.spreading_pizza != null:
		return
	var table := _prep_table()
	if table == null or table.placed_pizza == null:
		GameManager.set_hint("Put the dough on the prep table first.")
		return
	if _char != null and _char.global_position.distance_to(table.global_position) > 2.8:
		GameManager.set_hint("Stand by the prep table to spread the sauce.")
		return
	var p := table.placed_pizza
	if not p.kneaded:
		GameManager.set_hint("Knead the dough first - press K.")
		return
	if p.stage != Pizza.Stage.DOUGH:
		GameManager.set_hint("Sauce goes on the plain dough.")
		return
	GameManager.spreading_pizza = p
	p.set_sauce_spread(0.02)
	_spread_cursor = Vector2.ZERO
	_spread_last_angle = 0.0
	_spread_accum = 0.0
	_spread_turns = 0
	_spread_started = false
	_set_station_labels(false)
	var rig := _camera_rig()
	if rig != null and rig.has_method("focus_on"):
		rig.focus_on(p)
	# A small marker that follows the mouse circle over the dough.
	if _spreader == null:
		_spreader = MeshInstance3D.new()
		_spreader.name = "SauceSpreader"
		var sm := CylinderMesh.new()
		sm.top_radius = 0.05
		sm.bottom_radius = 0.05
		sm.height = 0.016
		_spreader.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.90, 0.06, 0.03)
		_spreader.material_override = mat
		add_child(_spreader)
	_spreader.global_position = p.global_position + Vector3(0, Pizza.SAUCE_TOP + 0.01, 0)
	GameManager.set_hint("USE MOUSE TO SPREAD SAUCE - move in circles (0%%)")

## Accumulate the angle of a virtual cursor driven by mouse-relative motion.
func _spread_motion(rel: Vector2) -> void:
	var p := GameManager.spreading_pizza
	if p == null or not is_instance_valid(p):
		return
	if rel.length() > 60.0:
		return  # pointer warp, not a real movement
	_spread_cursor = (_spread_cursor + rel * SPREAD_STEP).limit_length(SPREAD_MAX_RADIUS)
	if _spreader != null:
		# Sit directly on the sauce layer, not floating above the dough.
		_spreader.global_position = p.global_position + Vector3(_spread_cursor.x, Pizza.SAUCE_TOP + 0.01, _spread_cursor.y)
	if _spread_cursor.length() < SPREAD_MIN_RADIUS:
		return
	var ang := atan2(_spread_cursor.y, _spread_cursor.x)
	if not _spread_started:
		_spread_started = true
		_spread_last_angle = ang
		return
	var d := ang - _spread_last_angle
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	_spread_last_angle = ang
	_spread_accum += d
	while absf(_spread_accum) >= TAU:
		_spread_accum -= signf(_spread_accum) * TAU
		_spread_turns += 1
		p.set_sauce_spread(minf(float(_spread_turns) / float(SPREAD_ROTATIONS), 1.0))
		GameManager.set_hint("USE MOUSE TO SPREAD SAUCE - move in circles (%d%%)" % int(100.0 * p.sauce_spread))
		if _spread_turns >= SPREAD_ROTATIONS:
			_finish_spreading()
			return

func _finish_spreading() -> void:
	var p := GameManager.spreading_pizza
	if p != null and is_instance_valid(p):
		p.add_sauce()
	GameManager.spreading_pizza = null
	if _spreader != null:
		_spreader.queue_free()
		_spreader = null
	_set_station_labels(true)
	var rig := _camera_rig()
	if rig != null and rig.has_method("clear_focus"):
		rig.clear_focus()
	GameManager.set_hands_ingredient("")
	_clear_held()
	_gesture("place")
	GameManager.set_hint("Sauce spread! Now grab the cheese.")

## Cheese gets its own close-up: press C repeatedly to shred it over the
## sauced base. Each press scatters more thick yellow strands.
func _start_cutting() -> void:
	if GameManager.kneading_pizza != null or GameManager.spreading_pizza != null or GameManager.cutting_cheese != null:
		return
	var table := _prep_table()
	if table == null or table.placed_pizza == null:
		GameManager.set_hint("Put the dough on the table first.")
		return
	if _char != null and _char.global_position.distance_to(table.global_position) > 2.8:
		GameManager.set_hint("Stand by the prep table to cut the cheese.")
		return
	var p := table.placed_pizza
	if p.stage != Pizza.Stage.SAUCED:
		GameManager.set_hint("Spread the sauce first.")
		return
	GameManager.cutting_cheese = p
	_set_station_labels(false)
	var rig := _camera_rig()
	if rig != null and rig.has_method("focus_on"):
		rig.focus_on(p)
	_prompt_cheese_cut(p)

func _prompt_cheese_cut(p: Pizza) -> void:
	GameManager.set_hint("PRESS C TO CUT CHEESE - shreds: %d/%d" % [p.cheese_cuts, Pizza.CHEESE_CUTS_REQUIRED])

func _cut_cheese() -> void:
	var p := GameManager.cutting_cheese
	if p == null or not is_instance_valid(p):
		return
	p.cut_cheese()
	if p.cheese_ready:
		_finish_cutting()
	else:
		_prompt_cheese_cut(p)

func _finish_cutting() -> void:
	var p := GameManager.cutting_cheese
	if p != null and is_instance_valid(p):
		p.add_cheese()
	GameManager.cutting_cheese = null
	_set_station_labels(true)
	var rig := _camera_rig()
	if rig != null and rig.has_method("clear_focus"):
		rig.clear_focus()
	GameManager.set_hands_ingredient("")
	_clear_held()
	_gesture("place")
	GameManager.set_hint("Cheese sprinkled. Now add the toppings.")

## Leave whichever close-up is active and restore the normal view.
func _cancel_closeup() -> bool:
	if GameManager.kneading_pizza == null and GameManager.spreading_pizza == null and GameManager.cutting_cheese == null:
		return false
	GameManager.kneading_pizza = null
	GameManager.spreading_pizza = null
	GameManager.cutting_cheese = null
	_set_station_labels(true)
	if _spreader != null:
		_spreader.queue_free()
		_spreader = null
	var rig := _camera_rig()
	if rig != null and rig.has_method("clear_focus"):
		rig.clear_focus()
	GameManager.set_hint("Close-up closed. Press G at the prep table to pick the pizza back up.")
	return true

func _camera_rig() -> Node:
	if _char == null or not is_instance_valid(_char):
		return null
	return _char.get("camera_rig") as Node

## Station name labels are huge in the dough close-up, so hide them while
## kneading and put them back when the normal view returns.
func _set_station_labels(visible: bool) -> void:
	for s in _all_stations():
		var lbl := (s as Node3D).get_node_or_null("Label3D") as Label3D
		if lbl != null:
			lbl.visible = visible

# --- targeting ---

func _cast(o: Vector3, d: Vector3, dist: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(o, o + d * dist)
	q.exclude = _excluded()
	return get_world_3d().direct_space_state.intersect_ray(q)

## Bodies the interaction ray must ignore: the player and everything the
## player is carrying. The carried pizza has its own collider (so toppings
## can land on it) and used to block the ray, which forced the game to fall
## back to screen-space picking and pick the wrong station - usually the
## prep table behind the player.
func _excluded() -> Array[RID]:
	var out: Array[RID] = []
	if _char == null or not is_instance_valid(_char):
		return out
	out.append(_char.get_rid())
	_collect_bodies(_char, out)
	return out

func _collect_bodies(node: Node, out: Array[RID]) -> void:
	for c in node.get_children():
		if c is CollisionObject3D:
			out.append((c as CollisionObject3D).get_rid())
		_collect_bodies(c, out)

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

## The point on a station the player aims at (the top of its counter).
func _station_aim(s: KitchenStation) -> Vector3:
	return s.global_position + Vector3(0, STATION_TOP_HEIGHT, 0)

## Screen distance from the crosshair to every station that is in front of the
## camera. Stations behind the camera are skipped: their mirrored projection
## can land right next to the crosshair and steal the interaction.
func _screen_scores(c: Camera3D, cam_pos: Vector3) -> Dictionary:
	var screen := c.get_viewport().get_visible_rect().size * 0.5
	var out: Dictionary = {}
	for s in _all_stations():
		var st: KitchenStation = s
		var aim := _station_aim(st)
		if cam_pos.distance_to(aim) > camera_reach:
			continue
		if c.is_position_behind(aim):
			continue
		out[st] = c.unproject_position(aim).distance_to(screen)
	return out

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

	# What the crosshair points at.
	var scores := _screen_scores(c, cam_pos)
	var best: KitchenStation = null
	var best_score := 1e20
	for s in scores:
		var st: KitchenStation = s
		var sc: float = scores[st]
		if sc < best_score:
			best_score = sc
			best = st

	# What the ray physically hits.
	var direct := _cast(cam_pos, aim, camera_reach)
	var ray_station: KitchenStation = null
	if not direct.is_empty():
		ray_station = _station_of(direct.get("collider") as Node)

	if ray_station == null:
		# The ray hit the floor or a wall - use the station under the crosshair.
		if best != null and best_score < SCREEN_MAX_DISTANCE:
			return _screen_hit(best)
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

	if best == null or best == ray_station:
		return direct

	# The ray hit a station, but the crosshair is clearly on another one. The
	# stations sit in a row, so the ray often grazes the corner of the nearer
	# counter while the player is aiming at the one behind it.
	var ray_score: float = scores.get(ray_station, 1e20)
	if best_score + SCREEN_TOLERANCE < ray_score:
		return _screen_hit(best)
	return direct

func _screen_hit(st: KitchenStation) -> Dictionary:
	return {"collider": st, "position": _station_aim(st), "normal": Vector3.UP}

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
	# Carried a little in front of the chest and only slightly tilted. The
	# old pose was nearly vertical and low, so the pizza's near edge sank
	# into the serve counter as the player walked up to it. At y 1.40 the
	# lowest point stays above the 1.1 m counter top no matter the station.
	p.position = Vector3(0, 1.40, -0.45)
	p.rotation_degrees = Vector3(-30, 0, 0)
	_gesture("grab")

func _show_held(ing: String) -> void:
	_clear_held()
	if ing == "" or _char == null:
		return
	var mi := Pizza.make_ingredient_mesh(ing)
	mi.name = "HeldIngredient"
	# Sit the item in the character's right hand. The model is turned 180
	# degrees and its arms rest at its sides, so the right hand sits near
	# x -0.22, y 1.05, z -0.09.
	mi.position = Vector3(-0.25, 1.03, -0.15)
	mi.rotation_degrees = Vector3(20, 0, 12)
	_char.add_child(mi)
	_gesture("grab")

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
	var have_counts := {}
	if placed != null:
		for t in placed.toppings:
			have_counts[t] = int(have_counts.get(t, 0)) + 1
	var need_counts := {}
	for t in g.required:
		need_counts[t] = int(need_counts.get(t, 0)) + 1
	# Pick randomly among the types still needed, so the sequence differs from
	# pizza to pizza even when the final counts are the same.
	var options: Array[String] = []
	for t in need_counts:
		if int(have_counts.get(t, 0)) < int(need_counts[t]):
			options.append(str(t))
	if options.is_empty():
		return ""
	return options[randi() % options.size()]

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
			if st.ingredient == "sauce":
				g.set_hint("Sauce bottle in hand. Stand by the prep table and press L, then move the mouse in circles.")
			elif st.ingredient == "cheese":
				g.set_hint("Cheese in hand. Stand by the prep table and press L, then press C to cut it.")
			else:
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
		g.set_hint("You are holding the pizza - take it to the oven and press G (L puts it back on the table).")
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
	if g.hands_ingredient == "sauce":
		g.set_hint("Press L to start spreading, then move the mouse in circles.")
	elif g.hands_ingredient == "cheese":
		g.set_hint("Press L to start cutting, then press C to shred the cheese.")
	else:
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
		_gesture("place")
		_drop_pizza(p, table)
		return

	# Sauce is spread with the mouse, not dropped - it is a bottle, not a
	# topping. L starts the close-up spreading minigame.
	if g.hands_ingredient == "sauce":
		_start_spreading()
		return
	if g.hands_ingredient == "cheese":
		_start_cutting()
		return

	# Dropping an ingredient: it falls onto whatever is on the table.
	if g.hands_ingredient != "":
		var ing := g.hands_ingredient
		g.set_hands_ingredient("")
		_clear_held()
		_gesture("place")
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
	# Only raw dough needs the knead close-up. Putting a pizza that has
	# already been kneaded back down must NOT re-enter that state: K would do
	# nothing, kneading_pizza would never clear, and G/L would stay blocked so
	# the pizza could not be picked up again.
	if not p.kneaded:
		GameManager.start_knead(p)
		_set_station_labels(false)
		var rig := _camera_rig()
		if rig != null and rig.has_method("focus_on"):
			rig.focus_on(p)
		GameManager.set_hint("Press K to knead the dough (0/%d)." % Pizza.KNEADS_REQUIRED)
	else:
		# A finished pizza keeps the normal camera. Leaving the knead close-up
		# active would swallow every input, so it could not be picked back up.
		var rig := _camera_rig()
		if rig != null and rig.has_method("clear_focus"):
			rig.clear_focus()
		GameManager.set_hint("Pizza on the table - press G to pick it up.")

## The surfaces a dropped item can land on. While a pizza is on the table the
## table top is deliberately omitted: its top face sits slightly *above* the
## pizza base, so ingredients could land on the table and then appear to float
## next to (or above) the pizza once it was picked up.
func _surfaces_for(table: KitchenStation, pizza: Pizza) -> Array:
	var out: Array = []
	if pizza == null:
		var top := table.global_position + Vector3(0, 1.1, 0)
		out.append(PhysicsDropper.Surface.box(top, Vector3(1.4, 0.2, 1.4)))
	out.append(PhysicsDropper.Surface.box(Vector3(0, -0.1, 0), Vector3(18, 0.2, 20)))
	if pizza != null:
		# A cylinder's *top face* is centre.y + height/2. Put that face exactly
		# at the pizza's top layer, not centre it there (which used to leave
		# toppings hovering 4 cm in the air after pickup).
		const SURFACE_H := 0.08
		var p_top := pizza.global_position + Vector3(0, pizza.top_y() - SURFACE_H * 0.5, 0)
		out.append(PhysicsDropper.Surface.cyl(p_top, Pizza.DOUGH_RADIUS, SURFACE_H))
		# The toppings that are already on it, so the next one rests on top
		# of them instead of sinking into them.
		for t in pizza.placed_topping_surfaces():
			out.append(PhysicsDropper.Surface.cyl(t["center"], t["radius"], t["height"]))
	return out

func _drop_ingredient(ing: String, table: KitchenStation) -> void:
	var p := table.placed_pizza
	if p == null:
		GameManager.set_hint("Put the dough on the table first.")
		return
	# Enforce the intended order. Kneading comes before any ingredient.
	if not p.kneaded:
		GameManager.set_hint("Knead the dough first - press K.")
		return
	if ing == "sauce" and p.stage != Pizza.Stage.DOUGH:
		GameManager.set_hint("Sauce goes on the plain dough.")
		return
	if ing == "cheese" and p.stage != Pizza.Stage.SAUCED:
		GameManager.set_hint("Cheese goes on the sauce.")
		return
	if ing != "sauce" and ing != "cheese":
		# A pizza can carry several toppings, so both the cheesed stage and
		# the topped stage are allowed here. Requiring CHEESED would refuse
		# every topping after the first one.
		if p.stage != Pizza.Stage.CHEESED and p.stage != Pizza.Stage.TOPPED:
			GameManager.set_hint("Toppings go on the cheese.")
			return

	var mi := Pizza.make_ingredient_mesh(ing)
	mi.name = "DroppedIngredient"
	add_child(mi)
	# Start the drop just above the pizza so it falls onto the right layer.
	# Toppings are scattered over the whole base instead of always landing
	# in the middle, so several of them fit side by side.
	if ing == "sauce" or ing == "cheese":
		mi.global_position = p.global_position + Vector3(0, 0.55, 0)
	else:
		var ang := randf() * TAU
		var rad := sqrt(randf()) * Pizza.TOPPING_SPREAD
		mi.global_position = p.global_position + Vector3(cos(ang) * rad, 0.55, sin(ang) * rad)
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
		_gesture("oven")
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
	_gesture("serve")
	g.serve(p)
	# The customer eats the pizza bite by bite rather than it vanishing. The
	# fallback only applies if no customer rig was built.
	var cust := g.customer_node
	if cust != null and is_instance_valid(cust) and cust.has_method("eat"):
		cust.call("eat", p)
	else:
		p.queue_free()
