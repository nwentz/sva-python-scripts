class_name Pizza
extends Node3D
## A pizza under construction: dough, sauce, cheese and toppings, plus baking.

enum Stage { DOUGH, SAUCED, CHEESED, TOPPED, BAKING, BAKED, BURNT }

const TOPPING_COLORS := {
	"pepperoni": Color(0.82, 0.05, 0.07),
	"mushroom": Color(0.86, 0.76, 0.55),
	"olive": Color(0.08, 0.20, 0.05),
}

const DOUGH_RADIUS := 0.35
const SAUCE_RADIUS := 0.30
const CHEESE_RADIUS := 0.285

const DOUGH_TOP := 0.07
const SAUCE_TOP := 0.09
const CHEESE_TOP := 0.12

@export var bake_time := 0.0
@export var bake_target := 7.0
@export var bake_quality := 0.0
@export var toppings: Array[String] = []
@export var stage: Stage = Stage.DOUGH:
	set(v):
		stage = v
		if is_node_ready():
			_apply_stage()

var _base: MeshInstance3D
var _sauce: MeshInstance3D
var _cheese: MeshInstance3D
var _tops: Node3D
var _mat: StandardMaterial3D
var _smoke: GPUParticles3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _cyl: CylinderShape3D

func _ready() -> void:
	_base = _mesh(_cyl_mesh(DOUGH_RADIUS, 0.07), Color(0.98, 0.88, 0.55), Vector3(0, 0.035, 0))
	_tops = Node3D.new()
	_tops.name = "Toppings"
	add_child(_tops)

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

	_smoke = GPUParticles3D.new()
	_smoke.amount = 20
	_smoke.process_material = ParticleProcessMaterial.new()
	_smoke.process_material.gravity = Vector3(0, -1, 0)
	_smoke.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_smoke.process_material.emission_sphere_radius = 0.08
	_smoke.emitting = false
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
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.10
			cyl.bottom_radius = 0.12
			cyl.height = 0.30
			mi.mesh = cyl
			mat.albedo_color = Color(0.90, 0.06, 0.03)
		"cheese":
			var block := BoxMesh.new()
			block.size = Vector3(0.24, 0.15, 0.24)
			mi.mesh = block
			mat.albedo_color = Color(1.0, 0.76, 0.0)
		_:
			var disc := CylinderMesh.new()
			disc.top_radius = 0.13
			disc.bottom_radius = 0.13
			disc.height = 0.035
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
	return _cheese != null

func add_sauce() -> void:
	if _sauce == null:
		_sauce = _mesh(_cyl_mesh(SAUCE_RADIUS, 0.02), Color(0.88, 0.07, 0.03), Vector3(0, 0.08, 0))
	_update_collider()
	stage = Stage.SAUCED

func add_cheese() -> void:
	if _cheese == null:
		_cheese = _mesh(_cyl_mesh(CHEESE_RADIUS, 0.03), Color(1.0, 0.76, 0.02), Vector3(0, 0.105, 0))
	_update_collider()
	stage = Stage.CHEESED

func attach_topping(type: String, world_xform: Transform3D) -> void:
	## Parents a dropped topping mesh onto the pizza, keeping its world pose.
	var mi := Pizza.make_ingredient_mesh(type)
	_tops.add_child(mi)
	mi.global_transform = world_xform
	if not toppings.has(type):
		toppings.append(type)
	stage = Stage.TOPPED

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
		_smoke.emitting = false
		return
	if stage != Stage.BAKING:
		stage = Stage.BAKING
		bake_time = 0.0
		bake_quality = 1.0
		if _mat:
			_mat.emissive = Color(0, 0, 0, 0)

	bake_time += delta
	bake_quality = clampf(1.0 - absf(bake_time - bake_target) / bake_target, 0.0, 1.0)
	var t := clampf(bake_time / bake_target, 0.0, 1.0)

	if _mat:
		var target_color: Color = Color(0.72, 0.45, 0.17) if t > 0.7 else Color(0.98, 0.88, 0.55)
		_mat.albedo_color = Color(0.98, 0.88, 0.55).lerp(target_color, t)
		_mat.emissive = Color(0.2, 0.1, 0.05) * t

	if bake_time >= bake_target * 1.9:
		stage = Stage.BURNT
		if _mat:
			_mat.albedo_color = Color(0.17, 0.1, 0.06)
			_mat.emissive = Color(0, 0, 0, 0)
		_smoke.emitting = true
		_smoke.process_material.emission_color = Color(0.3, 0.3, 0.3)
	elif bake_time >= bake_target:
		stage = Stage.BAKED
		_smoke.emitting = false
		if _mat:
			_mat.emissive = Color(0, 0, 0, 0)

func bake_score() -> float:
	if stage == Stage.BURNT:
		return 0.0
	return bake_quality * 100.0
