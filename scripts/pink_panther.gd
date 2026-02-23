extends Node2D
class_name PinkPanther

signal arrived_at_target
signal interaction_complete

# =========================================================
#  ANIMATION TUNING — 3D-on-2D cinematic feel
# =========================================================

@export var idle_bob_amount: float = 1.8
@export var idle_bob_speed: float = 1.3
@export var breathing_scale: float = 0.014
@export var tail_swing_amount: float = 20.0
@export var tail_swing_speed: float = 1.8
@export var blink_interval: float = 3.5
@export var blink_duration: float = 0.12
@export var head_sway_amount: float = 2.5

@export var walk_speed: float = 110.0
@export var street_y: float = 420.0
@export var min_x: float = 50.0
@export var max_x: float = 910.0

const SM_FAST: float = 14.0
const SM_MED: float = 8.0
const SM_SLOW: float = 4.5
const SM_XSLOW: float = 2.5

var target_position: Vector2
var is_walking: bool = false
var facing_right: bool = true
var pending_interaction: ClickableObject = null
var dialog_system: DialogSystem = null

var time: float = 0.0
var blink_timer: float = 0.0
var is_blinking: bool = false
var walk_phase: float = 0.0
var walk_blend: float = 0.0
var talk_blend: float = 0.0
var velocity_x: float = 0.0

# Smooth animation targets
var _body_py: float = 0.0
var _body_px: float = 0.0
var _body_rot: float = 0.0
var _body_sx: float = 1.0
var _body_sy: float = 1.0
var _neck_px: float = 0.0
var _neck_py: float = 0.0
var _head_rot: float = 0.0
var _head_px: float = 0.0
var _tail_rot: float = 0.0
var _left_arm_rot: float = 0.0
var _right_arm_rot: float = 0.0
var _left_leg_rot: float = 0.0
var _right_leg_rot: float = 0.0
var _left_ear_rot: float = 0.0
var _right_ear_rot: float = 0.0
var _snout_rot: float = 0.0
var _shadow_sx: float = 1.0
var _shadow_sy: float = 1.0
var _mouth_open: float = 0.0
var _lean: float = 0.0
var _hip_sway: float = 0.0

# Fidget system
var _fidget_timer: float = 5.0
var _fidget_type: int = -1
var _fidget_t: float = 0.0

# Node references
@onready var body: Polygon2D = $Body
@onready var neck: Polygon2D = $Body/Neck
@onready var head: Polygon2D = $Body/Neck/Head
@onready var snout: Polygon2D = $Body/Neck/Head/Snout
@onready var left_eye: Polygon2D = $Body/Neck/Head/LeftEye
@onready var right_eye: Polygon2D = $Body/Neck/Head/RightEye
@onready var left_ear: Polygon2D = $Body/Neck/Head/LeftEar
@onready var right_ear: Polygon2D = $Body/Neck/Head/RightEar
@onready var tail: Polygon2D = $Body/Tail
@onready var left_arm: Polygon2D = $Body/LeftArm
@onready var right_arm: Polygon2D = $Body/RightArm
@onready var left_leg: Polygon2D = $Body/LeftLeg
@onready var right_leg: Polygon2D = $Body/RightLeg
@onready var shadow: Polygon2D = $Shadow
@onready var mouth_line: Line2D = $Body/Neck/Head/Snout/Mouth
@onready var left_brow: Line2D = $Body/Neck/Head/LeftEyebrow
@onready var right_brow: Line2D = $Body/Neck/Head/RightEyebrow

var original_positions: Dictionary = {}
var original_rotations: Dictionary = {}
var original_scales: Dictionary = {}
var _orig_mouth_pts: PackedVector2Array


func _ready() -> void:
	global_position.y = street_y
	target_position = global_position
	_store_original_transforms()
	if mouth_line:
		_orig_mouth_pts = mouth_line.points.duplicate()
	blink_timer = randf_range(1.0, blink_interval)
	_fidget_timer = randf_range(4.0, 8.0)
	var nk: Vector2 = original_positions.get("Neck", Vector2.ZERO)
	_neck_py = nk.y
	_hand_drawn_pass()


func _store_original_transforms() -> void:
	for child in get_all_polygon_children(self):
		original_positions[child.name] = child.position
		original_rotations[child.name] = child.rotation
		original_scales[child.name] = child.scale


func get_all_polygon_children(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Polygon2D:
			result.append(child)
		result.append_array(get_all_polygon_children(child))
	return result


# =========================================================
#  MAIN PROCESS
# =========================================================

func _process(delta: float) -> void:
	time += delta

	var is_talking := dialog_system != null and dialog_system.is_active()
	walk_blend = lerp(walk_blend, 1.0 if is_walking else 0.0, delta * SM_MED)
	talk_blend = lerp(talk_blend, 1.0 if is_talking else 0.0, delta * SM_MED)

	_update_blink(delta)

	if is_walking:
		_process_walking(delta)
	else:
		velocity_x = lerp(velocity_x, 0.0, delta * 3.0)

	_compute_idle_targets(delta)

	if is_walking:
		_compute_walk_targets(delta)

	if talk_blend > 0.05:
		_compute_talk_targets(delta)

	_compute_3d_depth(delta)
	_update_fidgets(delta)
	_apply_smooth_transforms(delta)
	_update_eyes(delta)
	_update_mouth(delta)
	_update_shadow(delta)


# =========================================================
#  BLINK
# =========================================================

func _update_blink(delta: float) -> void:
	blink_timer -= delta
	if blink_timer <= 0:
		if is_blinking:
			is_blinking = false
			blink_timer = randf_range(2.0, blink_interval)
		else:
			is_blinking = true
			blink_timer = blink_duration


# =========================================================
#  IDLE — organic breathing, overlapping action, weight shift
# =========================================================

func _compute_idle_targets(delta: float) -> void:
	var idle_w := (1.0 - walk_blend) * (1.0 - talk_blend * 0.3)

	var breath_phase := time * idle_bob_speed
	var bob := sin(breath_phase) * idle_bob_amount
	var breath_sx := 1.0 + sin(breath_phase) * breathing_scale
	var breath_sy := 1.0 + cos(breath_phase) * breathing_scale * 0.7

	var body_base: Vector2 = original_positions.get("Body", Vector2.ZERO)
	_body_py = lerp(_body_py, body_base.y + bob * idle_w, delta * SM_MED)
	_body_px = lerp(_body_px, body_base.x, delta * SM_SLOW)
	_body_sx = lerp(_body_sx, lerp(1.0, breath_sx, idle_w), delta * SM_MED)
	_body_sy = lerp(_body_sy, lerp(1.0, breath_sy, idle_w), delta * SM_MED)

	var weight_shift := sin(time * 0.3) * deg_to_rad(1.5) * idle_w
	if not is_walking:
		_body_rot = lerp(_body_rot, weight_shift, delta * SM_XSLOW)

	# Tail — elegant pendulum with secondary wave
	var tail_base: float = original_rotations.get("Tail", 0.0)
	var ts := tail_swing_speed
	var tail_main := sin(time * ts) * deg_to_rad(tail_swing_amount)
	var tail_secondary := sin(time * ts * 2.3 + 0.8) * deg_to_rad(4.0)
	var tail_tertiary := sin(time * ts * 0.6 - 1.2) * deg_to_rad(6.0)
	var tail_idle := tail_base + (tail_main + tail_secondary + tail_tertiary) * idle_w
	if not is_walking:
		_tail_rot = tail_idle

	# Head sway with overlapping delay from body
	var sway := sin(time * idle_bob_speed * 0.6 - 0.5) * head_sway_amount
	var neck_base: Vector2 = original_positions.get("Neck", Vector2.ZERO)
	var head_base: Vector2 = original_positions.get("Head", Vector2.ZERO)

	if not is_walking:
		_neck_px = lerp(_neck_px, neck_base.x + sway * 0.3 * idle_w, delta * SM_SLOW)
		_neck_py = lerp(_neck_py, neck_base.y, delta * SM_MED)
		_head_px = lerp(_head_px, head_base.x + sway * 0.5 * idle_w, delta * SM_SLOW)
		_head_rot = lerp(_head_rot, sin(time * idle_bob_speed * 0.4 - 0.7) * deg_to_rad(3.0) * idle_w, delta * SM_SLOW)

	_snout_rot = lerp(_snout_rot, sin(time * idle_bob_speed * 0.4 - 1.2) * deg_to_rad(2.0) * idle_w, delta * SM_XSLOW)

	# Ear twitches
	var ear_base_l: float = original_rotations.get("LeftEar", 0.0)
	var ear_base_r: float = original_rotations.get("RightEar", 0.0)
	if not is_walking:
		if fmod(time, 4.0) < 0.3:
			var twitch := sin(time * 20.0) * deg_to_rad(8.0)
			_left_ear_rot = ear_base_l + twitch
			_right_ear_rot = ear_base_r - twitch * 0.5
		elif fmod(time, 7.0) < 0.2:
			_right_ear_rot = ear_base_r + sin(time * 25.0) * deg_to_rad(6.0)
			_left_ear_rot = ear_base_l
		else:
			var gentle := sin(time * 0.8) * deg_to_rad(1.5)
			_left_ear_rot = lerp(_left_ear_rot, ear_base_l + gentle, delta * SM_SLOW)
			_right_ear_rot = lerp(_right_ear_rot, ear_base_r - gentle * 0.7, delta * SM_SLOW)

	# Arms idle pendulum
	if not is_walking and talk_blend < 0.3:
		var arm_idle := sin(time * idle_bob_speed * 0.7 - 0.3) * deg_to_rad(5.0) * idle_w
		var arm_l_base: float = original_rotations.get("LeftArm", 0.0)
		var arm_r_base: float = original_rotations.get("RightArm", 0.0)
		_left_arm_rot = lerp(_left_arm_rot, arm_l_base + arm_idle, delta * SM_SLOW)
		_right_arm_rot = lerp(_right_arm_rot, arm_r_base - arm_idle, delta * SM_SLOW)

	# Legs idle weight shift
	if not is_walking:
		var leg_shift := sin(time * 0.35) * deg_to_rad(2.0) * idle_w
		var leg_l_base: float = original_rotations.get("LeftLeg", 0.0)
		var leg_r_base: float = original_rotations.get("RightLeg", 0.0)
		_left_leg_rot = lerp(_left_leg_rot, leg_l_base + leg_shift, delta * SM_SLOW)
		_right_leg_rot = lerp(_right_leg_rot, leg_r_base - leg_shift * 0.5, delta * SM_SLOW)


# =========================================================
#  WALK — weight transfer, hip sway, 3D lean
# =========================================================

func _process_walking(delta: float) -> void:
	var dir_to_target: float = sign(target_position.x - global_position.x)
	var dist: float = abs(target_position.x - global_position.x)

	if dist > 8.0:
		var speed_factor := clampf(dist / 50.0, 0.3, 1.0)
		velocity_x = dir_to_target * walk_speed * speed_factor
		global_position.x += velocity_x * delta
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.y = street_y

		if dir_to_target > 0 and not facing_right:
			facing_right = true
			scale.x = abs(scale.x)
		elif dir_to_target < 0 and facing_right:
			facing_right = false
			scale.x = -abs(scale.x)

		walk_phase += delta * 7.0 * speed_factor
	else:
		is_walking = false
		velocity_x = 0.0
		arrived_at_target.emit()
		if pending_interaction:
			_do_interaction(pending_interaction)
			pending_interaction = null


func _compute_walk_targets(delta: float) -> void:
	var w := walk_blend
	var wp := walk_phase

	# Double-bounce body bob (contact points)
	var contact_bob: float = -abs(sin(wp * 2.0)) * 4.0
	var body_base: Vector2 = original_positions.get("Body", Vector2.ZERO)
	_body_py = body_base.y + contact_bob * w

	# Lean into movement direction
	var speed_pct := clampf(abs(velocity_x) / walk_speed, 0.0, 1.0)
	_lean = lerp(_lean, deg_to_rad(-4.0) * speed_pct * w, delta * SM_MED)
	_body_rot = _lean

	# Hip sway counter-rotation
	_hip_sway = sin(wp) * deg_to_rad(3.0) * w
	_body_px = body_base.x + sin(wp) * 1.5 * w

	# Squash/stretch on contact
	var squash := sin(wp * 2.0)
	_body_sx = 1.0 + squash * 0.03 * w
	_body_sy = 1.0 - squash * 0.02 * w

	# Legs — alternating stride
	var leg_swing := sin(wp) * deg_to_rad(35.0) * w
	var ll_base: float = original_rotations.get("LeftLeg", 0.0)
	var rl_base: float = original_rotations.get("RightLeg", 0.0)
	_left_leg_rot = ll_base + leg_swing
	_right_leg_rot = rl_base - leg_swing

	# Arms — counter-swing (overlapping action, phase offset)
	var arm_swing := sin(wp - 0.5) * deg_to_rad(25.0) * w
	var la_base: float = original_rotations.get("LeftArm", 0.0)
	var ra_base: float = original_rotations.get("RightArm", 0.0)
	_left_arm_rot = la_base - arm_swing
	_right_arm_rot = ra_base + arm_swing

	# Tail — momentum delay
	var tail_walk := sin(wp - PI / 2.0) * deg_to_rad(30.0) * w
	var tail_wave := sin(wp * 1.6 - 1.0) * deg_to_rad(6.0) * w
	var tail_base: float = original_rotations.get("Tail", 0.0)
	_tail_rot = tail_base + tail_walk + tail_wave

	# Head look-ahead bob
	var neck_base: Vector2 = original_positions.get("Neck", Vector2.ZERO)
	var head_bob := sin(wp * 2.0 + PI) * 2.0 * w
	_neck_px = neck_base.x + sin(wp * 0.5) * 1.5 * w
	_neck_py = neck_base.y + head_bob * 0.4
	_head_rot = sin(wp - 0.6) * deg_to_rad(5.0) * w
	_head_px = (original_positions.get("Head", Vector2.ZERO) as Vector2).x + 2.0 * w

	_snout_rot = sin(wp * 2.0 + 1.5) * deg_to_rad(2.5) * w

	# Ear bounce
	var ear_bounce := sin(wp * 2.0 + 0.8) * deg_to_rad(5.0) * w
	var el_base: float = original_rotations.get("LeftEar", 0.0)
	var er_base: float = original_rotations.get("RightEar", 0.0)
	_left_ear_rot = el_base + ear_bounce
	_right_ear_rot = er_base - ear_bounce * 0.6

	_shadow_sx = 1.0 + abs(sin(wp)) * 0.12 * w
	_shadow_sy = 1.0 - abs(sin(wp)) * 0.06 * w


# =========================================================
#  TALK — mouth, gestures, head nods, expressions
# =========================================================

func _compute_talk_targets(delta: float) -> void:
	var t := talk_blend
	var typing := dialog_system != null and dialog_system.is_typing

	# Mouth open/close rhythm
	if typing:
		var mouth_cycle := sin(time * 12.0) * 0.5 + 0.5
		var mouth_var := sin(time * 7.3) * 0.3
		_mouth_open = lerp(_mouth_open, clampf(mouth_cycle + mouth_var, 0.0, 1.0) * t, delta * SM_FAST * 2.0)
	else:
		_mouth_open = lerp(_mouth_open, 0.0, delta * SM_FAST)

	# Head nods during speech
	var nod := sin(time * 3.0) * deg_to_rad(4.0) * t
	_head_rot = lerp(_head_rot, nod, delta * SM_MED)

	var hb: Vector2 = original_positions.get("Head", Vector2.ZERO)
	_head_px = lerp(_head_px, hb.x + sin(time * 2.0) * 1.5 * t, delta * SM_SLOW)

	# Right arm gesture (raises periodically while talking)
	var gesture := sin(time * 2.0)
	if gesture > 0.3 and t > 0.5:
		var gesture_amt := (gesture - 0.3) / 0.7
		var ra_base: float = original_rotations.get("RightArm", 0.0)
		_right_arm_rot = lerp(_right_arm_rot, ra_base + deg_to_rad(-35.0) * gesture_amt * t, delta * SM_MED)

	# Left arm slight emphasis counter-gesture
	var counter_gesture := sin(time * 1.6 + PI) * 0.5 + 0.5
	if counter_gesture > 0.6 and t > 0.5:
		var la_base: float = original_rotations.get("LeftArm", 0.0)
		_left_arm_rot = lerp(_left_arm_rot, la_base + deg_to_rad(-15.0) * counter_gesture * t, delta * SM_SLOW)

	# Lean slightly forward when talking
	_body_rot = lerp(_body_rot, deg_to_rad(1.5) * t, delta * SM_SLOW)

	# Body emphasis bob
	var body_base: Vector2 = original_positions.get("Body", Vector2.ZERO)
	_body_py = lerp(_body_py, body_base.y + sin(time * 3.5) * 1.0 * t, delta * SM_MED)


# =========================================================
#  3D DEPTH — foreshortening, near/far limb scaling
# =========================================================

func _compute_3d_depth(delta: float) -> void:
	var speed_ratio := clampf(abs(velocity_x) / walk_speed, 0.0, 1.0)

	if is_walking and speed_ratio > 0.1:
		var near_s := 1.0 + speed_ratio * 0.06
		var far_s := 1.0 - speed_ratio * 0.04
		left_arm.scale = lerp(left_arm.scale, Vector2(far_s, 1.0), delta * SM_MED)
		right_arm.scale = lerp(right_arm.scale, Vector2(near_s, 1.0), delta * SM_MED)
		left_leg.scale = lerp(left_leg.scale, Vector2(far_s, 1.0), delta * SM_MED)
		right_leg.scale = lerp(right_leg.scale, Vector2(near_s, 1.0), delta * SM_MED)
	else:
		var one := Vector2(1.0, 1.0)
		left_arm.scale = lerp(left_arm.scale, one, delta * SM_SLOW)
		right_arm.scale = lerp(right_arm.scale, one, delta * SM_SLOW)
		left_leg.scale = lerp(left_leg.scale, one, delta * SM_SLOW)
		right_leg.scale = lerp(right_leg.scale, one, delta * SM_SLOW)


# =========================================================
#  IDLE FIDGETS — look around, scratch head, tail flick
# =========================================================

func _update_fidgets(delta: float) -> void:
	if is_walking or talk_blend > 0.3:
		_fidget_type = -1
		_fidget_timer = randf_range(3.0, 6.0)
		return

	if _fidget_type < 0:
		_fidget_timer -= delta
		if _fidget_timer <= 0:
			_fidget_type = randi() % 3
			_fidget_t = 0.0
		return

	_fidget_t += delta
	var p := _fidget_t

	match _fidget_type:
		0:
			var look := sin(p * 3.0) * deg_to_rad(12.0) * clampf(1.0 - p / 2.0, 0.0, 1.0)
			_head_rot += look
			if p > 2.0:
				_fidget_type = -1
				_fidget_timer = randf_range(5.0, 10.0)
		1:
			var raise := sin(clampf(p, 0.0, 1.5) * PI / 1.5)
			_right_arm_rot += deg_to_rad(-40.0) * raise
			if p > 2.0:
				_fidget_type = -1
				_fidget_timer = randf_range(6.0, 12.0)
		2:
			var flick := sin(p * 10.0) * deg_to_rad(15.0) * exp(-p * 2.0)
			_tail_rot += flick
			if p > 1.5:
				_fidget_type = -1
				_fidget_timer = randf_range(4.0, 8.0)


# =========================================================
#  APPLY TRANSFORMS — smooth lerp on every part
# =========================================================

func _apply_smooth_transforms(delta: float) -> void:
	body.position.x = lerp(body.position.x, _body_px, delta * SM_MED)
	body.position.y = lerp(body.position.y, _body_py, delta * SM_MED)
	body.rotation = lerp(body.rotation, _body_rot + _hip_sway, delta * SM_MED)
	body.scale.x = lerp(body.scale.x, _body_sx, delta * SM_FAST)
	body.scale.y = lerp(body.scale.y, _body_sy, delta * SM_FAST)

	neck.position.x = lerp(neck.position.x, _neck_px, delta * SM_SLOW)
	neck.position.y = lerp(neck.position.y, _neck_py, delta * SM_MED)
	head.position.x = lerp(head.position.x, _head_px, delta * SM_SLOW)
	head.rotation = lerp(head.rotation, _head_rot, delta * SM_SLOW)

	snout.rotation = lerp(snout.rotation, _snout_rot, delta * SM_XSLOW)

	tail.rotation = lerp(tail.rotation, _tail_rot, delta * SM_SLOW)

	left_arm.rotation = lerp(left_arm.rotation, _left_arm_rot, delta * SM_FAST)
	right_arm.rotation = lerp(right_arm.rotation, _right_arm_rot, delta * SM_FAST)

	left_leg.rotation = lerp(left_leg.rotation, _left_leg_rot, delta * SM_FAST)
	right_leg.rotation = lerp(right_leg.rotation, _right_leg_rot, delta * SM_FAST)

	left_ear.rotation = lerp(left_ear.rotation, _left_ear_rot, delta * SM_MED)
	right_ear.rotation = lerp(right_ear.rotation, _right_ear_rot, delta * SM_MED)

	shadow.scale.x = lerp(shadow.scale.x, _shadow_sx, delta * SM_MED)
	shadow.scale.y = lerp(shadow.scale.y, _shadow_sy, delta * SM_MED)


# =========================================================
#  EYES — blink with squash
# =========================================================

func _update_eyes(delta: float) -> void:
	var target_sy := 0.08 if is_blinking else 1.0
	var speed := SM_FAST * 2.0 if is_blinking else SM_MED
	left_eye.scale.y = lerp(left_eye.scale.y, target_sy, delta * speed)
	right_eye.scale.y = lerp(right_eye.scale.y, target_sy, delta * speed)


# =========================================================
#  MOUTH — animate Line2D points for talk
# =========================================================

func _update_mouth(_delta: float) -> void:
	if not mouth_line or _orig_mouth_pts.size() < 6:
		return
	var open := _mouth_open
	var pts := _orig_mouth_pts.duplicate()
	# Push lower lip points downward when mouth opens
	# Original: (-5,-1), (-3,3), (0,4), (3,3), (5,-1), (8,-3)
	# Indices 1,2,3 are the lower curve
	pts[1].y += open * 6.0
	pts[2].y += open * 8.0
	pts[3].y += open * 6.0
	# Slight upward pull on corners for smile shape
	pts[0].y -= open * 1.0
	pts[4].y -= open * 1.0
	pts[5].y -= open * 1.5
	mouth_line.points = pts


# =========================================================
#  SHADOW
# =========================================================

func _update_shadow(_delta: float) -> void:
	if not is_walking:
		_shadow_sx = 1.0 + sin(time * 1.5) * 0.03
		_shadow_sy = 1.0


# =========================================================
#  MOVEMENT & INTERACTION
# =========================================================

func walk_to(x_pos: float) -> void:
	target_position = Vector2(clamp(x_pos, min_x, max_x), street_y)
	is_walking = true


func walk_to_and_interact(object: ClickableObject) -> void:
	if dialog_system and dialog_system.is_active():
		return
	var target_x := object.global_position.x
	if global_position.x < target_x:
		target_x -= 50
	else:
		target_x += 50
	pending_interaction = object
	walk_to(target_x)


func _do_interaction(object: ClickableObject) -> void:
	if object.global_position.x > global_position.x and not facing_right:
		facing_right = true
		scale.x = abs(scale.x)
	elif object.global_position.x < global_position.x and facing_right:
		facing_right = false
		scale.x = -abs(scale.x)

	if dialog_system and dialog_system.has_method("start_dialog"):
		var dialog := object.get_dialog()
		dialog_system.start_dialog(dialog)


func set_dialog_system(system: DialogSystem) -> void:
	dialog_system = system


# =========================================================
#  HAND-DRAWN PASS — wobble, sketch overlays, color jitter
# =========================================================

func _hand_drawn_pass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1996

	for poly in get_all_polygon_children(self):
		_wobble_polygon(poly, rng)
		_add_sketch_overlay(poly, rng)
		_jitter_color(poly, rng, 0.02)

	for line_node in _get_all_line2d(self):
		var n: String = line_node.name
		if "Outline" in n or "Sketch" in n or "Eyelid" in n:
			continue
		_wobble_line2d(line_node, rng, 1.2)
		_vary_line_width(line_node, rng)


func _wobble_polygon(poly: Polygon2D, rng: RandomNumberGenerator) -> void:
	var verts := poly.polygon
	if verts.size() < 3:
		return
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = Vector2(min(mn.x, v.x), min(mn.y, v.y))
		mx = Vector2(max(mx.x, v.x), max(mx.y, v.y))
	var diag := (mx - mn).length()
	var amount := clampf(diag * 0.018, 0.3, 2.5)

	var wobbled := PackedVector2Array()
	for v in verts:
		wobbled.append(v + Vector2(
			rng.randf_range(-amount, amount),
			rng.randf_range(-amount, amount)
		))
	poly.polygon = wobbled

	for child in poly.get_children():
		if child is Line2D and "Outline" in child.name:
			var pts := wobbled.duplicate()
			pts.append(wobbled[0])
			child.points = pts
			_vary_line_width(child, rng)


func _add_sketch_overlay(poly: Polygon2D, rng: RandomNumberGenerator) -> void:
	var verts := poly.polygon
	if verts.size() < 3:
		return
	var has_outline := false
	for child in poly.get_children():
		if child is Line2D and "Outline" in child.name:
			has_outline = true
			break
	if not has_outline:
		return

	var sketch := Line2D.new()
	sketch.name = "SketchOverlay"
	var pts := PackedVector2Array()
	for v in verts:
		pts.append(v + Vector2(
			rng.randf_range(-1.8, 1.8),
			rng.randf_range(-1.8, 1.8)
		))
	pts.append(pts[0])
	sketch.points = pts
	sketch.width = 1.3
	sketch.default_color = Color(0, 0, 0, 0.22)
	poly.add_child(sketch)


func _jitter_color(poly: Polygon2D, rng: RandomNumberGenerator, amount: float) -> void:
	var col := poly.color
	if col.r < 0.1 and col.g < 0.1 and col.b < 0.1:
		return
	if col.r > 0.95 and col.g > 0.95 and col.b > 0.95:
		return
	poly.color = Color(
		clampf(col.r + rng.randf_range(-amount, amount), 0.0, 1.0),
		clampf(col.g + rng.randf_range(-amount, amount), 0.0, 1.0),
		clampf(col.b + rng.randf_range(-amount, amount), 0.0, 1.0),
		col.a
	)


func _wobble_line2d(line_node: Line2D, rng: RandomNumberGenerator, amount: float) -> void:
	var pts := line_node.points
	if pts.size() < 2:
		return
	var new_pts := PackedVector2Array()
	for p in pts:
		new_pts.append(p + Vector2(
			rng.randf_range(-amount, amount),
			rng.randf_range(-amount, amount)
		))
	line_node.points = new_pts
	_vary_line_width(line_node, rng)


func _vary_line_width(line_node: Line2D, rng: RandomNumberGenerator) -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.82 + rng.randf_range(0.0, 0.3)))
	curve.add_point(Vector2(0.2, 0.90 + rng.randf_range(0.0, 0.25)))
	curve.add_point(Vector2(0.5, 1.0 + rng.randf_range(-0.1, 0.15)))
	curve.add_point(Vector2(0.8, 0.90 + rng.randf_range(0.0, 0.25)))
	curve.add_point(Vector2(1.0, 0.82 + rng.randf_range(0.0, 0.3)))
	line_node.width_curve = curve


func _get_all_line2d(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Line2D:
			result.append(child)
		result.append_array(_get_all_line2d(child))
	return result


func _unhandled_input(event: InputEvent) -> void:
	if dialog_system and dialog_system.is_active():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			walk_to(get_global_mouse_position().x)
