class_name Pizza
extends Node3D
## A pizza under construction: dough, sauce, cheese and toppings, plus baking.

signal knead_progress(done: int, total: int)
signal cheese_progress(done: int, total: int)

enum Stage { DOUGH, SAUCED, CHEESED, TOPPED, BAKING, BAKED, BURNT }

## How many presses of K it takes to work the dough before sauce is allowed.
const KNEADS_REQUIRED := 5
## Cutting the cheese is also a short close-up minigame. Each press of C
## scatters a few thick shreds over the sauced base.
const CHEESE_CUTS_REQUIRED := 8

const TOPPING_COLORS := {
	"pepperoni": Color(0.82, 0.05, 0.07),
	"mushroom": Color(0.86, 0.76, 0.55),
	"olive": Color(0.08, 0.20, 0.05),
}

const DOUGH_RADIUS := 0.35
const SAUCE_RADIUS := 0.30
const CHEESE_RADIUS := 0.285

const DOUGH_TOP := 0.07
## The dough starts as a ball and is flattened into the 0.35 m disc by KNEADS
## presses of K. A sphere scaled down in Y and out in X/Z reads as either.
const DOUGH_BALL_RADIUS := 0.18
const DOUGH_BALL_HEIGHT := 0.36
const SAUCE_TOP := 0.09
const CHEESE_TOP := 0.12

## Toppings are small discs so several of them fit side by side on the base.
const TOPPING_RADIUS := 0.09
const TOPPING_HEIGHT := 0.03
## How far from the middle of the pizza a topping may land.
const TOPPING_SPREAD := 0.21

@export var bake_time := 0.0
@export var bake_target := 7.0
@export var bake_quality := 0.0
@export var toppings: Array[String] = []
## Kneading is a short minigame: the player presses K several times while the
## camera is zoomed in on the dough on the prep table.
var kneads := 0
var kneaded := false
## 0-1 while the player circles the mouse over the dough; 1 when covered.
var sauce_spread := 0.0
var cheese_cuts := 0
var cheese_ready := false
@export var stage: Stage = Stage.DOUGH:
	set(v):
		stage = v
		if is_node_ready():
			_apply_stage()

var _base: MeshInstance3D
var _sauce: MeshInstance3D
var _cheese: MeshInstance3D
var _tops: Node3D
var _cheese_shreds: Node3D
var _melted_layer: MeshInstance3D
## The topping meshes that have been placed on the pizza.
var _placed: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _smoke: GPUParticles3D
var _knead_tween: Tween
var _body: StaticBody3D
var _shape: CollisionShape3D
var _cyl: CylinderShape3D

func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = DOUGH_BALL_RADIUS
	ball.height = DOUGH_BALL_HEIGHT
	_base = _mesh(ball, Color(0.98, 0.88, 0.55), Vector3(0, DOUGH_BALL_HEIGHT * 0.5, 0))
	_tops = Node3D.new()
	_tops.name = "Toppings"
	add_child(_tops)
	_cheese_shreds = Node3D.new()
	_cheese_shreds.name = "CheeseShreds"
	add_child(_cheese_shreds)

	# The pizza carries its own collider so that dropped ingredients land on
	# top of it. The Physics Placer excludes the node it is dropping, so this
	# body never blocks the pizza's own drop.
	_body = StaticBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	_cyl = CylinderShape3D.new()
	_cyl.radius = DOUGH_RADIUS
	_cyl.height = DOUGH_TOP
	_shape = CollisionShape3D.new()
	_shape.shape = _cyl
	_shape.position = Vector3(0, DOUGH_TOP * 0.5, 0)
	_body.add_child(_shape)
	add_child(_body)

	_mat = _base.material_override as StandardMaterial3D

	_smoke = Fx.make_smoke(20, 2.6, 0.2)
	_smoke.position = Vector3(0, 0.2, 0)
	add_child(_smoke)

	_apply_stage()

# --- geometry helpers ---

func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c

func _mesh(m: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.75
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

static func make_ingredient_mesh(type: String) -> MeshInstance3D:
	## Builds the mesh used for a held / dropped ingredient.
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	match type:
		"sauce":
			# A squeeze bottle rather than a plain red cylinder.
			var bottle := CylinderMesh.new()
			bottle.top_radius = 0.055
			bottle.bottom_radius = 0.115
			bottle.height = 0.32
			mi.mesh = bottle
			mat.albedo_color = Color(0.90, 0.06, 0.03)
			var cap := MeshInstance3D.new()
			cap.name = "BottleCap"
			var neck := CylinderMesh.new()
			neck.top_radius = 0.032
			neck.bottom_radius = 0.032
			neck.height = 0.08
			cap.mesh = neck
			cap.position = Vector3(0, 0.20, 0)
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.82, 0.82, 0.84)
			cap_mat.roughness = 0.5
			cap.material_override = cap_mat
			mi.add_child(cap)
		"cheese":
			var block := BoxMesh.new()
			block.size = Vector3(0.24, 0.15, 0.24)
			mi.mesh = block
			mat.albedo_color = Color(1.0, 0.76, 0.0)
		_:
			var disc := CylinderMesh.new()
			disc.top_radius = TOPPING_RADIUS
			disc.bottom_radius = TOPPING_RADIUS
			disc.height = TOPPING_HEIGHT
			mi.mesh = disc
			mat.albedo_color = TOPPING_COLORS.get(type, Color(0.9, 0.85, 0.6))
	mi.material_override = mat
	return mi

# --- layers ---

func top_y() -> float:
	if stage >= Stage.CHEESED:
		return CHEESE_TOP
	if stage >= Stage.SAUCED:
		return SAUCE_TOP
	return DOUGH_TOP

func has_sauce() -> bool:
	return _sauce != null

func has_cheese() -> bool:
	return cheese_ready or _cheese != null

## One press of K. The dough gets smoother with each press and can only be
## sauced once it has been kneaded enough.
func knead() -> void:
	if kneaded:
		return
	kneads = mini(kneads + 1, KNEADS_REQUIRED)
	if kneads >= KNEADS_REQUIRED:
		kneaded = true
	knead_progress.emit(kneads, KNEADS_REQUIRED)
	_shape_dough()

## Each press flattens the ball a little more and spreads it outwards. After
## the last press it is the full, thin base that sauce can sit on.
func _shape_dough() -> void:
	if not is_instance_valid(_base):
		return
	var t := float(kneads) / float(KNEADS_REQUIRED)
	var spread := lerpf(1.0, DOUGH_RADIUS / DOUGH_BALL_RADIUS, t)
	var flatten := lerpf(1.0, DOUGH_TOP / DOUGH_BALL_HEIGHT, t)
	var y := lerpf(DOUGH_BALL_HEIGHT * 0.5, DOUGH_TOP * 0.5, t)
	var target := Vector3(spread, flatten, spread)
	if _knead_tween != null and _knead_tween.is_running():
		_knead_tween.kill()
	_knead_tween = create_tween()
	var tw := _knead_tween
	# Overshoot a little so the press has a visible squash-and-stretch.
	tw.tween_property(_base, "scale", target * Vector3(1.06, 0.80, 1.06), 0.07)
	tw.tween_property(_base, "scale", target, 0.14)
	tw.parallel().tween_property(_base, "position", Vector3(0, y, 0), 0.21)

## Grow the sauce disc as the mouse circles over the dough. Creating it on the
## first call also means the spreading close-up has something to show.
func set_sauce_spread(t: float) -> void:
	if _sauce == null:
		_sauce = _mesh(_cyl_mesh(SAUCE_RADIUS, 0.02), Color(0.88, 0.07, 0.03), Vector3(0, 0.08, 0))
	sauce_spread = clampf(t, 0.0, 1.0)
	# Avoid a zero scale (singular transform); a tiny dot is fine.
	var s := maxf(sauce_spread, 0.02)
	_sauce.scale = Vector3(s, 1.0, s)
	_update_collider()

func add_sauce() -> void:
	set_sauce_spread(1.0)
	stage = Stage.SAUCED

## One press of C scatters a few short, thick cheese shreds over the sauce.
func cut_cheese() -> void:
	if cheese_ready:
		return
	cheese_cuts = mini(cheese_cuts + 1, CHEESE_CUTS_REQUIRED)
	if cheese_cuts >= CHEESE_CUTS_REQUIRED:
		cheese_ready = true
	_add_cheese_shreds(6)
	cheese_progress.emit(cheese_cuts, CHEESE_CUTS_REQUIRED)

func _add_cheese_shreds(count: int) -> void:
	if _cheese_shreds == null:
		return
	for i in count:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 0.024, 0.018)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78, 0.06)
		mat.roughness = 0.75
		mi.material_override = mat
		var ang := randf() * TAU
		# Keep the shreds clustered around the middle of the base.
		var rad := sqrt(randf()) * (DOUGH_RADIUS * 0.45)
		# Sit the shreds just above the sauce (top 0.09) and below the
		# topping plane (0.12), so toppings rest on them instead of sinking in.
		mi.position = Vector3(cos(ang) * rad, CHEESE_TOP - 0.020 + randf() * 0.008, sin(ang) * rad)
		mi.set_meta("base_xz", Vector2(mi.position.x, mi.position.z))
		mi.rotation_degrees = Vector3(randf_range(-12, 12), rad_to_deg(ang) + randf_range(-35, 35), randf_range(-12, 12))
		_cheese_shreds.add_child(mi)

## As the pizza bakes the shreds soften, flatten and spread outwards into a
## glossy melted layer instead of staying as dry little sticks.
func melt_cheese(t: float) -> void:
	if _cheese_shreds == null:
		return
	var k := clampf(t, 0.0, 1.0)
	var spread := lerpf(1.0, 1.6, k)
	var flatten := lerpf(1.0, 0.35, k)
	var radial := lerpf(1.0, 1.10, k)
	var y := lerpf(CHEESE_TOP + 0.008, CHEESE_TOP, k)
	var raw := Color(1.0, 0.78, 0.06)
	var melted := Color(1.0, 0.64, 0.08)
	# A glossy translucent layer forms between the shreds as they soften.
	if k > 0.15:
		if _melted_layer == null:
			_melted_layer = MeshInstance3D.new()
			_melted_layer.name = "MeltedCheese"
			var disc := CylinderMesh.new()
			disc.top_radius = CHEESE_RADIUS
			disc.bottom_radius = CHEESE_RADIUS
			disc.height = 0.014
			_melted_layer.mesh = disc
			var mm := StandardMaterial3D.new()
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mm.roughness = 0.25
			_melted_layer.material_override = mm
			add_child(_melted_layer)
		var s := lerpf(0.6, 0.95, k)
		# Keep the layer thin: a tall disc reads as a hat brim on the pizza.
		_melted_layer.scale = Vector3(s, 0.45, s)
		_melted_layer.position.y = CHEESE_TOP
		var mm2 := _melted_layer.material_override as StandardMaterial3D
		if mm2 != null:
			mm2.albedo_color = Color(1.0, 0.70, 0.10, 0.65 * k)
	for c in _cheese_shreds.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		mi.scale = Vector3(spread, flatten, spread)
		mi.position.y = y
		if mi.has_meta("base_xz"):
			var base: Vector2 = mi.get_meta("base_xz")
			mi.position.x = base.x * radial
			mi.position.z = base.y * radial
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = raw.lerp(melted, k)
			mat.roughness = lerpf(0.75, 0.28, k)

func darken_cheese() -> void:
	if _melted_layer != null:
		var mm := _melted_layer.material_override as StandardMaterial3D
		if mm != null:
			mm.albedo_color = Color(0.52, 0.32, 0.08, 0.85)
	if _cheese_shreds == null:
		return
	for c in _cheese_shreds.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.48, 0.30, 0.08)
			mat.roughness = 0.6

## Finalise the cheese stage (also used by direct callers/tests).
func add_cheese() -> void:
	if cheese_cuts < CHEESE_CUTS_REQUIRED:
		var missing := CHEESE_CUTS_REQUIRED - cheese_cuts
		cheese_cuts = CHEESE_CUTS_REQUIRED
		cheese_ready = true
		_add_cheese_shreds(missing * 5)
	_update_collider()
	stage = Stage.CHEESED

func attach_topping(type: String, world_xform: Transform3D) -> void:
	## Parents a dropped topping onto the pizza, keeping the physics-chosen
	## spot but snapping it flat onto the surface. The raw drop transform can
	## be tilted or a few centimetres high, which made toppings (notably the
	## olive) look like they were floating once the pizza was picked up.
	var mi := Pizza.make_ingredient_mesh(type)
	_tops.add_child(mi)
	var local := to_local(world_xform.origin)
	var offset := Vector2(local.x, local.z)
	var max_r := DOUGH_RADIUS - TOPPING_RADIUS * 0.45
	if offset.length() > max_r:
		offset = offset.limit_length(max_r)
	# Toppings are all flat discs at the same height, so two that land close
	# together intersect (a mushroom dropped on olive/pepperoni used to clip
	# through them). Nudge this one away from its neighbours, staying on the
	# base, until it has its own clear spot.
	var min_gap := TOPPING_RADIUS * 1.5
	for attempt in 6:
		var moved := false
		for other in _placed:
			if not is_instance_valid(other):
				continue
			var diff := offset - Vector2(other.position.x, other.position.z)
			if diff.length() >= min_gap:
				continue
			if diff.length_squared() < 0.000001:
				diff = Vector2(randf() - 0.5, randf() - 0.5).normalized()
			offset += diff.normalized() * (min_gap - diff.length() + 0.004)
			moved = true
		if not moved:
			break
		if offset.length() > max_r:
			offset = offset.limit_length(max_r)
	# Slight height stagger lets several toppings share a crowded spot without
	# z-fighting; every one still rests on the cheese surface.
	var y := top_y() + TOPPING_HEIGHT * 0.5 + float(_placed.size() % 3) * 0.003
	mi.position = Vector3(offset.x, y, offset.y)
	mi.rotation = Vector3.ZERO
	_placed.append(mi)
	# Orders ask for counts, so keep duplicates rather than a unique set.
	toppings.append(type)
	stage = Stage.TOPPED

## The toppings already on the pizza, as drop surfaces, so the next one
## lands on top of them instead of inside them.
func placed_topping_surfaces() -> Array:
	var out: Array = []
	for mi in _placed:
		if not is_instance_valid(mi):
			continue
		out.append({
			"center": mi.global_position,
			"radius": TOPPING_RADIUS,
			"height": TOPPING_HEIGHT,
		})
	return out

func _update_collider() -> void:
	if _cyl == null:
		return
	var h := top_y()
	_cyl.height = h
	_cyl.radius = DOUGH_RADIUS
	_shape.position = Vector3(0, h * 0.5, 0)

func _apply_stage() -> void:
	if _base == null:
		return
	if _mat:
		if stage == Stage.BAKED:
			_mat.albedo_color = Color(0.72, 0.45, 0.17)
		elif stage == Stage.BURNT:
			_mat.albedo_color = Color(0.17, 0.10, 0.06)
		else:
			_mat.albedo_color = Color(0.98, 0.88, 0.55)

# --- baking ---

func bake(delta: float) -> void:
	# A finished pizza stays finished: BAKED and BURNT are terminal states.
	if stage == Stage.BURNT or stage == Stage.DOUGH or stage == Stage.BAKED:
		if _smoke:
			_smoke.emitting = false
		return
	if stage != Stage.BAKING:
		stage = Stage.BAKING
		bake_time = 0.0
		bake_quality = 1.0
		if _mat:
			_mat.emission_enabled = false

	bake_time += delta
	bake_quality = clampf(1.0 - absf(bake_time - bake_target) / bake_target, 0.0, 1.0)
	var t := clampf(bake_time / bake_target, 0.0, 1.0)
	melt_cheese(t)
	# Flatten the sauce as it cooks too, keeping its top surface in place so
	# toppings do not float after the layers thin out.
	if _sauce != null:
		_sauce.scale.y = lerpf(1.0, 0.45, t)
		_sauce.position.y = lerpf(0.08, 0.086, t)

	if _mat:
		var target_color: Color = Color(0.72, 0.45, 0.17) if t > 0.7 else Color(0.98, 0.88, 0.55)
		_mat.albedo_color = Color(0.98, 0.88, 0.55).lerp(target_color, t)
		_mat.emission_enabled = true
		_mat.emission = Color(0.2, 0.1, 0.05) * t

	if bake_time >= bake_target * 1.9:
		stage = Stage.BURNT
		melt_cheese(1.0)
		darken_cheese()
		if _mat:
			_mat.albedo_color = Color(0.17, 0.1, 0.06)
			_mat.emission_enabled = false
		if _smoke:
			_smoke.emitting = true
			if _smoke.process_material:
				_smoke.process_material.emission_color = Color(0.3, 0.3, 0.3)
	elif bake_time >= bake_target:
		stage = Stage.BAKED
		melt_cheese(1.0)
		if _smoke:
			_smoke.emitting = false
		if _mat:
			_mat.emission_enabled = false

func bake_score() -> float:
	if stage == Stage.BURNT:
		return 0.0
	return bake_quality * 100.0
