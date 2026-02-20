extends Area2D
class_name ClickableObject

signal clicked(object: ClickableObject)
signal interaction_requested(object: ClickableObject)

@export var object_name: String = "Object"
@export var hover_color: Color = Color(1.2, 1.2, 1.2, 1.0)
@export var interaction_distance: float = 100.0

# Dialog data - array of dictionaries with "speaker" and "text" keys
@export var dialog_lines: Array[Dictionary] = []

var is_hovered: bool = false
var original_modulate: Color = Color.WHITE
var visual_node: Node2D = null

func _ready() -> void:
	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# Find visual node (first child that's a Polygon2D or Sprite2D)
	for child in get_children():
		if child is Polygon2D or child is Sprite2D or child is Node2D:
			visual_node = child
			original_modulate = child.modulate
			break

func _on_mouse_entered() -> void:
	is_hovered = true
	if visual_node:
		visual_node.modulate = hover_color
	# Change cursor
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited() -> void:
	is_hovered = false
	if visual_node:
		visual_node.modulate = original_modulate
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(self)
			interaction_requested.emit(self)
			# Consume input so PinkPanther doesn't also walk-to-click
			get_viewport().set_input_as_handled()

func get_dialog() -> Array:
	# Return dialog lines, or default dialog if none set
	if dialog_lines.is_empty():
		return [
			{"speaker": "Pink Panther", "text": "Hmm, interesting...", "portrait_color": Color(1.0, 0.42, 0.71)},
			{"speaker": object_name, "text": "...", "portrait_color": Color(0.5, 0.5, 0.5)}
		]
	return dialog_lines

func set_dialog(lines: Array) -> void:
	dialog_lines.clear()
	for line in lines:
		dialog_lines.append(line)
