extends Node3D
## A customer sitting at the serve table. Poses the shared low-poly rig with
## its arms resting and its legs bent for the chair, then plays a short eating
## animation when a pizza is served.

const THIGH_L := "DEF-thigh.L"
const THIGH_R := "DEF-thigh.R"
const SHIN_L := "DEF-shin.L"
const SHIN_R := "DEF-shin.R"
const UPPER_ARM_L := "DEF-upper_arm.L"
const UPPER_ARM_R := "DEF-upper_arm.R"
const FOREARM_L := "DEF-forearm.L"
const FOREARM_R := "DEF-forearm.R"
const HEAD := "DEF-spine.006"

const BITES := 6
const BITE_TIME := 0.8

var _sk: Skeleton3D
var _bones := {}
var _rest := {}
var _mount: Node3D
var _pizza: Pizza = null
var _eating := false
var _eat_t := 0.0

func setup() -> void:
	var skels := find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_sk = skels[0] as Skeleton3D
	for i in _sk.get_bone_count():
		var n := String(_sk.get_bone_name(i))
		_bones[n] = i
		_rest[n] = _sk.get_bone_rest(i).basis.get_rotation_quaternion()
	_mount = Node3D.new()
	_mount.name = "PizzaMount"
	add_child(_mount)
	_apply_pose(0.0, 0.0)

func _add(d: Dictionary, bone: String, axis: Vector3, angle: float) -> void:
	if not _bones.has(bone):
		return
	if not d.has(bone):
		d[bone] = Quaternion()
	d[bone] = d[bone] * Quaternion(axis, angle)

## Rest pose, seated legs, and (while eating) an arm lifting the pizza to the
## mouth plus a small chewing nod.
func _apply_pose(arm_lift: float, chew: float) -> void:
	if _sk == null:
		return
	var d := {}
	_add(d, THIGH_L, Vector3.RIGHT, -1.45)
	_add(d, THIGH_R, Vector3.RIGHT, -1.45)
	_add(d, SHIN_L, Vector3.RIGHT, 1.45)
	_add(d, SHIN_R, Vector3.RIGHT, 1.45)
	# Both hands come up to hold the pizza while eating.
	_add(d, UPPER_ARM_L, Vector3.RIGHT, 0.95 * arm_lift)
	_add(d, FOREARM_L, Vector3.RIGHT, 0.70 * arm_lift)
	# The right arm's rest offset has the opposite sign, so its lift does too.
	_add(d, UPPER_ARM_R, Vector3.RIGHT, -1.05 * arm_lift)
	_add(d, FOREARM_R, Vector3.RIGHT, -0.75 * arm_lift)
	_add(d, HEAD, Vector3.RIGHT, 0.10 * chew)
	for name in _bones:
		var q: Quaternion = _rest[name]
		# A slightly shallower rest angle than the chef's arms: when seated,
		# the hands would otherwise sink into the chair seat.
		if name == UPPER_ARM_L:
			q = q * Quaternion(Vector3.BACK, -0.72)
		elif name == UPPER_ARM_R:
			q = q * Quaternion(Vector3.BACK, 0.72)
		if d.has(name):
			q = q * d[name]
		_sk.set_bone_pose_rotation(_bones[name], q)

## Called by the interaction controller instead of deleting the served pizza.
func eat(p: Pizza) -> void:
	if _sk == null or p == null:
		if p != null and is_instance_valid(p):
			p.queue_free()
		return
	if _pizza != null and is_instance_valid(_pizza):
		_pizza.queue_free()
	_pizza = p
	_eating = true
	_eat_t = 0.0
	p.reparent(_mount, false)
	p.position = Vector3.ZERO
	p.rotation_degrees = Vector3(-20, 0, 0)
	p.scale = Vector3.ONE
	_mount.position = Vector3(0, 1.52, 0.42)

func _process(delta: float) -> void:
	if not _eating:
		return
	_eat_t += delta
	var bite := int(_eat_t / BITE_TIME)
	if bite >= BITES:
		if _pizza != null and is_instance_valid(_pizza):
			_pizza.queue_free()
		_pizza = null
		_eating = false
		_mount.position = Vector3(0, 1.52, 0.42)
		_apply_pose(0.0, 0.0)
		return
	var phase := (_eat_t - float(bite) * BITE_TIME) / BITE_TIME
	# Lift toward the mouth, chew, then lower for the next bite.
	var raise := clampf(phase / 0.3, 0.0, 1.0) * (1.0 - clampf((phase - 0.65) / 0.35, 0.0, 1.0))
	_mount.position.y = lerpf(1.52, 1.80, raise)
	_mount.position.z = lerpf(0.42, 0.20, raise)
	if _pizza != null and is_instance_valid(_pizza):
		var remain := 1.0 - (float(bite) + 1.0) / float(BITES)
		_pizza.scale = Vector3(remain, remain, remain)
	_apply_pose(raise, sin(phase * TAU * 3.0))
