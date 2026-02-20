extends Node2D
class_name PinkPanther

signal arrived_at_target
signal interaction_complete

# =========================================================
#  ANIMATION TUNING — 3D-on-2D feel, smooth & organic
# =========================================================

# Idle
@export var idle_bob_amount: float = 1.5
@export var idle_bob_speed: float = 1.2
@export var breathing_scale: float = 0.012
@export var tail_swing_amount: float = 18.0
@export var tail_swing_speed: float = 2.0
@export var blink_interval: float = 3.5
@export var blink_duration: float = 0.12
@export var head_sway_amount: float = 2.0

# Movement
@export var walk_speed: float = 100.0
@export var street_y: float = 420.0
@export var min_x: float = 50.0
@export var max_x: float = 910.0

# Smoothing — all animations use lerp for buttery motion
const SMOOTH_FAST: float = 12.0   # snappy (legs, arms)
const SMOOTH_MED: float = 7.0    # medium (body, head)
const SMOOTH_SLOW: float = 4.0   # gentle (tail, sway)
const SMOOTH_XSLOW: float = 2.0  # very slow (weight shift, lean)

var target_position: Vector2
var is_walking: bool = false
var facing_right: bool = true
var pending_interaction: ClickableObject = null

# Core animation state
var time: float = 0.0
var blink_timer: float = 0.0
var is_blinking: bool = false
var walk_phase: float = 0.0
var walk_blend: float = 0.0       # 0 = idle, 1 = walking (smooth blend)

# Smooth animation targets (we lerp TOWARD these each frame)
var _body_pos_y: float = 0.0
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

# Dialog system reference
var dialog_system: DialogSystem = null

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

# Original transforms
var original_positions: Dictionary = {}
var original_rotations: Dictionary = {}
var original_scales: Dictionary = {}


func _ready() -> void:
	global_position.y = street_y
	target_position = global_position
	_store_original_transforms()
	blink_timer = randf_range(1.0, blink_interval)
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
#  MAIN PROCESS — smooth animation pipeline
# =========================================================

func _process(delta: float) -> void:
	time += delta

	# Smooth walk/idle blend (0 -> 1 ramp up, 1 -> 0 ramp down)
	var walk_target := 1.0 if is_walking else 0.0
	walk_blend = lerp(walk_blend, walk_target, delta * SMOOTH_MED)

	# Handle blinking
	_update_blink(delta)

	# Compute animation targets
	if is_walking:
		_process_walking(delta)
	_compute_idle_targets(delta)

	# Apply smooth interpolation to ALL parts
	_apply_smooth_transforms(delta)

	# Eye blink (already smooth)
	_update_eyes(delta)

	# Shadow
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
#  IDLE ANIMATION — organic, weighted, overlapping
# =========================================================

func _compute_idle_targets(_delta: float) -> void:
	var idle_w := 1.0 - walk_blend  # weight for idle motion

	# --- Body breathing bob ---
	var bob := sin(time * idle_bob_speed) * idle_bob_amount
	var breath_sx := 1.0 + sin(time * idle_bob_speed) * breathing_scale
	var breath_sy := 1.0 + sin(time * idle_bob_speed) * breathing_scale * 0.5

	# idle targets (blended with walk)
	var body_base_y: float = (original_positions.get("Body", Vector2.ZERO) as Vector2).y
	_body_pos_y = lerp(_body_pos_y, body_base_y + bob * idle_w, 1.0)
	_body_sx = lerp(1.0, breath_sx, idle_w)
	_body_sy = lerp(1.0, breath_sy, idle_w)

	# idle body rotation (slight lean shifts)
	var weight_shift := sin(time * 0.35) * deg_to_rad(1.2) * idle_w
	_body_rot = lerp(_body_rot, weight_shift, 1.0)

	# --- Tail swing (slow, elegant, pendulum) ---
	var tail_base: float = original_rotations.get("Tail", 0.0)
	var tail_swing := sin(time * tail_swing_speed) * deg_to_rad(tail_swing_amount)
	# secondary motion: slight figure-8 wobble
	var tail_wobble := sin(time * tail_swing_speed * 2.3) * deg_to_rad(3.0)
	_tail_rot = tail_base + (tail_swing + tail_wobble) * idle_w + _tail_rot * walk_blend

	# --- Head sway (delayed from body, overlapping action) ---
	var sway := sin(time * idle_bob_speed * 0.7 - 0.4) * head_sway_amount
	var neck_base: Vector2 = original_positions.get("Neck", Vector2.ZERO)
	var head_base: Vector2 = original_positions.get("Head", Vector2.ZERO)
	_neck_px = neck_base.x + sway * 0.25 * idle_w
	_head_px = head_base.x + sway * 0.45 * idle_w
	_head_rot = sin(time * idle_bob_speed * 0.5 - 0.6) * deg_to_rad(2.5) * idle_w

	# --- Snout follows head with slight delay ---
	_snout_rot = sin(time * idle_bob_speed * 0.5 - 1.0) * deg_to_rad(1.5) * idle_w

	# --- Ear twitches (irregular, surprise) ---
	var ear_base_l: float = original_rotations.get("LeftEar", 0.0)
	var ear_base_r: float = original_rotations.get("RightEar", 0.0)
	if fmod(time, 4.0) < 0.25:
		var twitch := sin(time * 22.0) * deg_to_rad(7.0)
		_left_ear_rot = ear_base_l + twitch
		_right_ear_rot = ear_base_r - twitch * 0.6
	elif fmod(time, 6.5) < 0.15:
		_right_ear_rot = ear_base_r + sin(time * 30.0) * deg_to_rad(5.0)
		_left_ear_rot = ear_base_l
	else:
		_left_ear_rot = ear_base_l
		_right_ear_rot = ear_base_r

	# --- Arms idle sway (pendulum, slightly offset) ---
	var arm_idle := sin(time * idle_bob_speed * 0.8 - 0.3) * deg_to_rad(4.0)
	var arm_l: float = original_rotations.get("LeftArm", 0.0) + arm_idle * idle_w
	var arm_r: float = original_rotations.get("RightArm", 0.0) - arm_idle * idle_w
	_left_arm_rot = lerp(_left_arm_rot, arm_l, 1.0)
	_right_arm_rot = lerp(_right_arm_rot, arm_r, 1.0)

	# --- Legs idle (very subtle weight shifting) ---
	var leg_idle := sin(time * 0.4) * deg_to_rad(1.5) * idle_w
	var leg_base_l: float = original_rotations.get("LeftLeg", 0.0)
	var leg_base_r: float = original_rotations.get("RightLeg", 0.0)
	_left_leg_rot = lerp(_left_leg_rot, leg_base_l + leg_idle, 1.0)
	_right_leg_rot = lerp(_right_leg_rot, leg_base_r - leg_idle * 0.5, 1.0)


# =========================================================
#  WALK CYCLE — smooth sine-driven with squash/stretch
# =========================================================

func _process_walking(delta: float) -> void:
	var direction: float = sign(target_position.x - global_position.x)
	var distance: float = abs(target_position.x - global_position.x)

	if distance > 8.0:
		var speed_factor := clampf(distance / 40.0, 0.3, 1.0)
		global_position.x += direction * walk_speed * speed_factor * delta
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.y = street_y

		if direction > 0 and not facing_right:
			facing_right = true
			scale.x = abs(scale.x)
		elif direction < 0 and facing_right:
			facing_right = false
			scale.x = -abs(scale.x)

		walk_phase += delta * 8.0 * speed_factor
		_compute_walk_targets()
	else:
		is_walking = false
		arrived_at_target.emit()
		if pending_interaction:
			_do_interaction(pending_interaction)
			pending_interaction = null


func _compute_walk_targets() -> void:
	var wp := walk_phase
	var w := walk_blend

	var bob: float = -abs(sin(wp * 2.0)) * 3.5
	var walk_body_base: Vector2 = original_positions.get("Body", Vector2.ZERO)
	_body_pos_y = walk_body_base.y + bob * w

	var squash := sin(wp * 2.0)
	_body_sx = 1.0 + squash * 0.025 * w
	_body_sy = 1.0 - squash * 0.018 * w

	_body_rot = deg_to_rad(-3.0) * w

	var leg_swing := sin(wp) * deg_to_rad(32.0) * w
	var w_leg_l: float = original_rotations.get("LeftLeg", 0.0)
	var w_leg_r: float = original_rotations.get("RightLeg", 0.0)
	_left_leg_rot = w_leg_l + leg_swing
	_right_leg_rot = w_leg_r - leg_swing

	var arm_swing := sin(wp - 0.4) * deg_to_rad(22.0) * w
	var w_arm_l: float = original_rotations.get("LeftArm", 0.0)
	var w_arm_r: float = original_rotations.get("RightArm", 0.0)
	_left_arm_rot = w_arm_l - arm_swing
	_right_arm_rot = w_arm_r + arm_swing

	var tail_walk := sin(wp - PI / 2.5) * deg_to_rad(28.0) * w
	var tail_secondary := sin(wp * 1.7 - 1.0) * deg_to_rad(5.0) * w
	var w_tail: float = original_rotations.get("Tail", 0.0)
	_tail_rot = w_tail + tail_walk + tail_secondary

	var head_bob := sin(wp * 2.0 + PI) * 1.8 * w
	var w_neck_base: Vector2 = original_positions.get("Neck", Vector2.ZERO)
	_neck_py = w_neck_base.y + head_bob * 0.3
	_head_rot = sin(wp - 0.5) * deg_to_rad(4.5) * w

	_snout_rot = sin(wp * 2.0 + 1.5) * deg_to_rad(2.0) * w

	var ear_bounce := sin(wp * 2.0 + 0.8) * deg_to_rad(4.0) * w
	var w_ear_l: float = original_rotations.get("LeftEar", 0.0)
	var w_ear_r: float = original_rotations.get("RightEar", 0.0)
	_left_ear_rot = w_ear_l + ear_bounce
	_right_ear_rot = w_ear_r - ear_bounce * 0.7

	_shadow_sx = 1.0 + abs(sin(wp)) * 0.12 * w
	_shadow_sy = 1.0 - abs(sin(wp)) * 0.06 * w


# =========================================================
#  APPLY TRANSFORMS — smooth lerp for every part
# =========================================================

func _apply_smooth_transforms(delta: float) -> void:
	body.position.y = lerp(body.position.y, _body_pos_y, delta * SMOOTH_MED)
	body.rotation = lerp(body.rotation, _body_rot, delta * SMOOTH_XSLOW)
	body.scale.x = lerp(body.scale.x, _body_sx, delta * SMOOTH_FAST)
	body.scale.y = lerp(body.scale.y, _body_sy, delta * SMOOTH_FAST)

	neck.position.x = lerp(neck.position.x, _neck_px, delta * SMOOTH_SLOW)
	neck.position.y = lerp(neck.position.y, _neck_py, delta * SMOOTH_MED)
	head.position.x = lerp(head.position.x, _head_px, delta * SMOOTH_SLOW)
	head.rotation = lerp(head.rotation, _head_rot, delta * SMOOTH_SLOW)

	snout.rotation = lerp(snout.rotation, _snout_rot, delta * SMOOTH_XSLOW)

	tail.rotation = lerp(tail.rotation, _tail_rot, delta * SMOOTH_SLOW)

	left_arm.rotation = lerp(left_arm.rotation, _left_arm_rot, delta * SMOOTH_FAST)
	right_arm.rotation = lerp(right_arm.rotation, _right_arm_rot, delta * SMOOTH_FAST)

	left_leg.rotation = lerp(left_leg.rotation, _left_leg_rot, delta * SMOOTH_FAST)
	right_leg.rotation = lerp(right_leg.rotation, _right_leg_rot, delta * SMOOTH_FAST)

	left_ear.rotation = lerp(left_ear.rotation, _left_ear_rot, delta * SMOOTH_MED)
	right_ear.rotation = lerp(right_ear.rotation, _right_ear_rot, delta * SMOOTH_MED)

	shadow.scale.x = lerp(shadow.scale.x, _shadow_sx, delta * SMOOTH_MED)
	shadow.scale.y = lerp(shadow.scale.y, _shadow_sy, delta * SMOOTH_MED)


# =========================================================
#  EYES — smooth blink with squash
# =========================================================

func _update_eyes(delta: float) -> void:
	var target_sy := 0.08 if is_blinking else 1.0
	var speed := SMOOTH_FAST * 2.0 if is_blinking else SMOOTH_MED
	left_eye.scale.y = lerp(left_eye.scale.y, target_sy, delta * speed)
	right_eye.scale.y = lerp(right_eye.scale.y, target_sy, delta * speed)


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
