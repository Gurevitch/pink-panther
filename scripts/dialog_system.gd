extends CanvasLayer
class_name DialogSystem

signal dialog_finished

@onready var dialog_panel: Panel = $DialogPanel
@onready var dialog_text: RichTextLabel = $DialogPanel/DialogText
@onready var speaker_label: Label = $DialogPanel/SpeakerLabel
@onready var portrait_panel: Panel = $DialogPanel/PortraitPanel
@onready var continue_indicator: Label = $DialogPanel/ContinueIndicator

var dialog_queue: Array = []
var current_dialog_index: int = 0
var is_dialog_active: bool = false
var is_typing: bool = false
var full_text: String = ""
var displayed_text: String = ""
var typing_speed: float = 0.03
var typing_timer: float = 0.0
var char_index: int = 0

# Dialog colors for different speakers
var speaker_colors: Dictionary = {
	"Pink Panther": Color(1.0, 0.42, 0.71),
	"default": Color(1.0, 1.0, 1.0)
}

func _ready() -> void:
	hide_dialog()

func _process(delta: float) -> void:
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			if char_index < full_text.length():
				displayed_text += full_text[char_index]
				dialog_text.text = displayed_text
				char_index += 1
			else:
				is_typing = false
				continue_indicator.visible = true

func _input(event: InputEvent) -> void:
	if not is_dialog_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialog()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance_dialog()
		get_viewport().set_input_as_handled()

func _advance_dialog() -> void:
	if is_typing:
		# Skip to full text
		is_typing = false
		displayed_text = full_text
		dialog_text.text = displayed_text
		continue_indicator.visible = true
	else:
		# Next dialog
		current_dialog_index += 1
		if current_dialog_index < dialog_queue.size():
			_show_current_dialog()
		else:
			hide_dialog()
			dialog_finished.emit()

func start_dialog(dialogs: Array) -> void:
	if dialogs.is_empty():
		return

	dialog_queue = dialogs
	current_dialog_index = 0
	is_dialog_active = true
	dialog_panel.visible = true
	_show_current_dialog()

func _show_current_dialog() -> void:
	var dialog = dialog_queue[current_dialog_index]
	var speaker = dialog.get("speaker", "")
	var text = dialog.get("text", "")
	var portrait_color = dialog.get("portrait_color", Color(0.5, 0.5, 0.5))

	# Set speaker name with color
	speaker_label.text = speaker
	var color = speaker_colors.get(speaker, speaker_colors["default"])
	speaker_label.add_theme_color_override("font_color", color)

	# Set portrait color (placeholder - could be replaced with actual sprites)
	var portrait_style = portrait_panel.get_theme_stylebox("panel").duplicate()
	if portrait_style is StyleBoxFlat:
		portrait_style.bg_color = portrait_color
		portrait_panel.add_theme_stylebox_override("panel", portrait_style)

	# Start typing effect
	full_text = text
	displayed_text = ""
	dialog_text.text = ""
	char_index = 0
	is_typing = true
	continue_indicator.visible = false

func hide_dialog() -> void:
	dialog_panel.visible = false
	is_dialog_active = false
	dialog_queue.clear()
	current_dialog_index = 0

func is_active() -> bool:
	return is_dialog_active
