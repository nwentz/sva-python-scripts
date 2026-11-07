class_name KitchenBuilder
extends Node3D
## Helper to build the kitchen scene structure using the toolkit.

func build_room() -> void:
	_make_box(Vector3(0, -0.1, 0), Vector3(16, 0.2, 12), Color(0.44, 0.38, 0.31))
	_make_box(Vector3(0, 4, 0), Vector3(16, 0.2, 12), Color(0.86, 0.86, 0.89))
	_make_box(Vector3(0, 2, -6), Vector3(16, 4, 3), Color(0.79, 0.8, 0.83))
	_make_box(Vector3(0, 2, 6), Vector3(16, 4, 3), Color(0.79, 0.8, 0.83))
	_make_box(Vector3(-8, 2, 0), Vector3(0.3, 4, 12), Color(0.73, 0.75, 0.79))
	_make_box(Vector3(8, 2, 0), Vector3(0.3, 4, 12), Color(0.73, 0.75, 0.79))

func _make_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	b.add_child(m)
	var c := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = size
	c.shape = cs
	b.add_child(c)
	add_child(b)
