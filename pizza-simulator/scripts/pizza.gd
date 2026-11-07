class_name Pizza
extends Node3D
## A pizza: assembly stages, toppings, and bake quality.

enum Stage { DOUGH, STRETCHED, SAUCED, CHEESED, TOPPED, BAKING, BAKED, BURNT }

const TOPPING_COLORS := {
	"pepperoni": Color(0.7, 0.16, 0.18),
	"mushroom": Color(0.79, 0.73, 0.63),
	"olive": Color(0.15, 0.17, 0.11),
}

@export var bake_time := 0.0
@export var bake_target := 7.0
@export var bake_quality := 0.0
@export var toppings: Array[String] = []
@export var scatter_count := 3
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

func _ready() -> void:
	_base = _mesh(_cyl(0.35, 0.07), Color(0.95, 0.87, 0.7), Vector3(0, 0.035, 0))
	_sauce = _mesh(_cyl(0.3, 0.02), Color(0.78, 0.17, 0.12), Vector3(0, 0.078, 0))
	_cheese = _mesh(_cyl(0.285, 0.03), Color(0.98, 0.85, 0.42), Vector3(0, 0.098, 0))
	_tops = Node3D.new()
	_tops.name = "Toppings"
	add_child(_tops)

	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 0.16
	cs.shape = shape
	cs.position = Vector3(0, 0.07, 0)
	body.add_child(cs)
	add_child(body)

	_mat = _base.material_override as StandardMaterial3D
	_apply_stage()

	# Create smoke particles
	_smoke = GPUParticles3D.new()
	_smoke.amount = 20
	_smoke.emission_rate = 10
	_smoke.process_material = ParticleProcessMaterial.new()
	_smoke.process_material.gravity = Vector3(0, -1, 0)
	_smoke.emitting = false
	_smoke.position = Vector3(0, 0.2, 0)
	add_child(_smoke)

func _cyl(r: float, h: float) -> CylinderMesh:
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
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _apply_stage() -> void:
	if _base == null:
		return
	_base.scale = Vector3.ONE if stage >= Stage.STRETCHED else Vector3(0.5, 1.8, 0.5)
	_sauce.visible = stage >= Stage.SAUCED
	_cheese.visible = stage >= Stage.CHEESED
	if stage == Stage.DOUGH and _mat:
		_mat.albedo_color = Color(0.95, 0.87, 0.7)

func add_topping(type: String, local: Vector3) -> void:
	# Ensure we are using local space relative to the pizza's center
	var r := Vector2(local.x, local.z)
	# Clamp to the crust area
	if r.length() > 0.23:
		r = r.normalized() * 0.23
	
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.05
	m.bottom_radius = 0.05
	m.height = 0.014
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TOPPING_COLORS.get(type, Color(1, 0, 1))
	mi.material_override = mat
	mi.position = Vector3(r.x, 0.118, r.y)
	_tops.add_child(mi)
	if not toppings.has(type):
		toppings.append(type)

func bake(delta: float) -> void:
	if stage == Stage.BURNT or stage == Stage.DOUGH:
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
		var target_color: Color = Color(0.72, 0.45, 0.17) if t > 0.7 else Color(0.95, 0.87, 0.7)
		_mat.albedo_color = Color(0.95, 0.87, 0.7).lerp(target_color, t)

		# Add subtle glow when baking
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
