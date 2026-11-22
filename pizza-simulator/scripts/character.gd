extends CharacterBody3D
## Base character controller. WASD move (camera-relative), Shift sprint.

const SPEED := 5.0
const SPRINT_SPEED := 8.0
const ACCELERATION := 10.0

# Keep the character inside the kitchen. The bounds must leave the player
# able to walk up to every station (the outermost counters sit at x = +-6.3
# and their front faces at z = 4.3), but never *into* one. The capsule has a
# radius of 0.3, so the centre has to stop 0.3 short of a counter's edge.
# Without this the controller's own clamp would shove the player back into
# the outer stations while they walk along the side wall. These match
# camera_rig.gd.
## Asymmetric: the serve side (-X) is a round table, so the player can walk
## further out there to stand next to the customer without hitting a counter.
const BOUNDS_X_MIN := -7.2
const BOUNDS_X_MAX := 6.6
const BOUNDS_Z_MIN := -2.9
## Past the serve table there is a gap to the back wall, so the chef can walk
## around the table and the seated customer instead of being stopped short.
const BOUNDS_Z_MAX := 5.5

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var ui_input := Vector2.ZERO

## Set by main.gd. Used to keep room for the camera behind the player.
var camera_rig: Node = null

# --- procedural rig animation ---
# The GLB has a full Mixamo-style skeleton but no baked clips, so the walk
# cycle and the interaction gestures are posed by hand on the Skeleton3D.
var _skel: Skeleton3D = null
var _rig: Node3D = null
var _bone_idx: Dictionary = {}
var _rest_rot: Dictionary = {}
var _pose_deltas: Dictionary = {}
var _walk_phase := 0.0
var _walk_amount := 0.0
var _idle_time := 0.0
var _carry_amount := 0.0
## The GameManager autoload, looked up by path so the character also works
## in scenes that run without the autoload.
var _game_manager: Node = null
var _action := ""
var _action_time := 0.0
var _action_duration := 0.6

## Bone names from the imported GLB.
const B_THIGH_L := "DEF-thigh.L"
const B_THIGH_R := "DEF-thigh.R"
const B_SHIN_L := "DEF-shin.L"
const B_SHIN_R := "DEF-shin.R"
const B_FOOT_L := "DEF-foot.L"
const B_FOOT_R := "DEF-foot.R"
const B_SPINE := "DEF-spine"
const B_UPPER_ARM_L := "DEF-upper_arm.L"
const B_UPPER_ARM_R := "DEF-upper_arm.R"
const B_FOREARM_L := "DEF-forearm.L"
const B_FOREARM_R := "DEF-forearm.R"

## Resting arm pose: the GLB's arms are slightly out in a T-pose, so both
## upper arms are rotated down to hang at the character's sides.
var _base_offsets := {
	B_UPPER_ARM_L: Quaternion(Vector3.BACK, -1.0),
	B_UPPER_ARM_R: Quaternion(Vector3.BACK, 1.0),
}

const ACTIONS := {
	"grab": {"duration": 0.55, "pose": {
		B_UPPER_ARM_R: 0.85, B_FOREARM_R: 0.55, B_UPPER_ARM_L: 0.15, B_SPINE: 0.12}},
	"place": {"duration": 0.65, "pose": {
		B_UPPER_ARM_R: 0.60, B_FOREARM_R: 0.25, B_SPINE: 0.18}},
	"oven": {"duration": 0.85, "pose": {
		B_UPPER_ARM_L: 0.95, B_UPPER_ARM_R: 0.95,
		B_FOREARM_L: 0.45, B_FOREARM_R: 0.45, B_SPINE: 0.22}},
	"serve": {"duration": 0.6, "pose": {
		B_UPPER_ARM_R: 0.70, B_FOREARM_R: 0.30, B_SPINE: 0.10}},
}

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")

## Called by main.gd once the rigged model has been added.
func setup_rig() -> void:
	var model := get_node_or_null("RiggedModel")
	if model == null:
		return
	_rig = model.get_node_or_null("rig")
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_skel = skels[0]
	for i in _skel.get_bone_count():
		var n := String(_skel.get_bone_name(i))
		_bone_idx[n] = i
		_rest_rot[n] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()

## Plays a short one-shot gesture ("grab", "place", "oven", "serve").
func play_action(action: String) -> void:
	if _skel == null or not ACTIONS.has(action):
		return
	_action = action
	_action_time = 0.0
	_action_duration = ACTIONS[action]["duration"]

func _add_pose(bone: String, axis: Vector3, angle: float) -> void:
	if not _bone_idx.has(bone):
		return
	var q := Quaternion(axis, angle)
	if _pose_deltas.has(bone):
		_pose_deltas[bone] = _pose_deltas[bone] * q
	else:
		_pose_deltas[bone] = q

func _update_animation(delta: float) -> void:
	if _skel == null:
		return

	# Reset every bone to its rest pose (with the arms lowered), then layer
	# the walk and the gesture on top.
	for name in _bone_idx:
		var q: Quaternion = _rest_rot[name]
		if _base_offsets.has(name):
			q = q * _base_offsets[name]
		_skel.set_bone_pose_rotation(_bone_idx[name], q)
	_pose_deltas.clear()

	var speed := Vector2(velocity.x, velocity.z).length()
	_walk_amount = move_toward(_walk_amount, clampf(speed / SPEED, 0.0, 1.0), delta * 6.0)
	_walk_phase += delta * 9.0 * _walk_amount

	var ph := _walk_phase
	var swing := sin(ph) * 0.55 * _walk_amount
	var knee_l := (0.20 + 0.60 * maxf(0.0, cos(ph))) * _walk_amount
	var knee_r := (0.20 + 0.60 * maxf(0.0, -cos(ph))) * _walk_amount

	_add_pose(B_THIGH_L, Vector3.RIGHT, swing)
	_add_pose(B_THIGH_R, Vector3.RIGHT, -swing)
	_add_pose(B_SHIN_L, Vector3.RIGHT, knee_l)
	_add_pose(B_SHIN_R, Vector3.RIGHT, knee_r)
	_add_pose(B_FOOT_L, Vector3.RIGHT, -swing * 0.35 - knee_l * 0.25)
	_add_pose(B_FOOT_R, Vector3.RIGHT, swing * 0.35 - knee_r * 0.25)
	_add_pose(B_UPPER_ARM_L, Vector3.RIGHT, -swing * 0.5)
	_add_pose(B_UPPER_ARM_R, Vector3.RIGHT, swing * 0.5)
	_add_pose(B_FOREARM_L, Vector3.RIGHT, (0.22 + 0.12 * sin(ph)) * _walk_amount)
	_add_pose(B_FOREARM_R, Vector3.RIGHT, (0.22 - 0.12 * sin(ph)) * _walk_amount)
	_add_pose(B_SPINE, Vector3.RIGHT, (0.05 + 0.03 * sin(ph * 2.0)) * _walk_amount)
	_add_pose(B_SPINE, Vector3.UP, 0.06 * sin(ph) * _walk_amount)

	# A faint breathing sway so the character is never completely rigid.
	_idle_time += delta
	_add_pose(B_SPINE, Vector3.RIGHT, 0.018 * sin(_idle_time * 2.2))
	_add_pose(B_UPPER_ARM_L, Vector3.RIGHT, 0.02 * sin(_idle_time * 2.2))
	_add_pose(B_UPPER_ARM_R, Vector3.RIGHT, 0.02 * sin(_idle_time * 2.2 + PI))

	# Holding a pizza raises both arms in front of the chest. Gestures take
	# precedence so grabbing/placing still read clearly.
	var carrying := false
	if _game_manager != null and is_instance_valid(_game_manager):
		var hp: Variant = _game_manager.get("hands_pizza")
		carrying = hp != null and is_instance_valid(hp)
	_carry_amount = move_toward(_carry_amount, 1.0 if carrying else 0.0, delta * 6.0)
	if _carry_amount > 0.001 and _action == "":
		var w := _carry_amount
		_add_pose(B_UPPER_ARM_L, Vector3.RIGHT, 0.65 * w)
		_add_pose(B_UPPER_ARM_R, Vector3.RIGHT, 0.65 * w)
		_add_pose(B_FOREARM_L, Vector3.RIGHT, 0.45 * w)
		_add_pose(B_FOREARM_R, Vector3.RIGHT, 0.45 * w)

	# One-shot gesture, faded in and out over its duration.
	if _action != "":
		_action_time += delta
		var t := _action_time / _action_duration
		if t >= 1.0:
			_action = ""
		else:
			var env := sin(PI * t)
			for bone in ACTIONS[_action]["pose"]:
				_add_pose(bone, Vector3.RIGHT, ACTIONS[_action]["pose"][bone] * env)

	for name in _pose_deltas:
		var q: Quaternion = _rest_rot[name]
		if _base_offsets.has(name):
			q = q * _base_offsets[name]
		_skel.set_bone_pose_rotation(_bone_idx[name], q * _pose_deltas[name])

	# Vertical bob so the body actually lifts with the stride.
	if _rig != null:
		_rig.position.y = absf(cos(ph)) * 0.045 * _walk_amount

func _physics_process(delta: float) -> void:
	# During the kneading close-up the player stands still while they work
	# the dough; the camera rig owns the view for that moment.
	if camera_rig != null and is_instance_valid(camera_rig) and camera_rig.get("focus_target") != null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Movement input
	var input := ui_input
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	input = input.limit_length(1.0)

	var dir := Vector3.ZERO
	if input != Vector2.ZERO:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var fwd := -cam.global_basis.z; fwd.y = 0.0
			var right := cam.global_basis.x; right.y = 0.0
			dir = (fwd * -input.y + right * input.x).normalized()
		else:
			dir = Vector3(input.x, 0.0, input.y).normalized()

	# Apply acceleration and friction
	var current_speed := SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed = SPRINT_SPEED

	# Apply horizontal movement with acceleration
	var target_velocity_x = dir.x * current_speed
	var target_velocity_z = dir.z * current_speed

	velocity.x = move_toward(velocity.x, target_velocity_x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity_z, ACCELERATION * delta)

	move_and_slide()

	# Clamp inside the kitchen
	global_position.x = clampf(global_position.x, BOUNDS_X_MIN, BOUNDS_X_MAX)
	global_position.z = clampf(global_position.z, BOUNDS_Z_MIN, BOUNDS_Z_MAX)
	# Leave room for the camera behind the player so it never has to sit
	# inside the character.
	if camera_rig != null and is_instance_valid(camera_rig):
		global_position = camera_rig.clamp_target(global_position)

	if dir != Vector3.ZERO:
		var target := global_position + dir
		target.y = global_position.y
		if global_position.distance_squared_to(target) > 0.0001:
			look_at(target, Vector3.UP)

	_update_animation(delta)
