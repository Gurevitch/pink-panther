extends CanvasLayer
class_name SceneTransition

## Handles scene transitions with fade-to-black and optional text.
## Add this as an autoload singleton named "Transition" in Project Settings,
## or instance it in each scene that needs transitions.

signal transition_finished

@onready var fade_rect: ColorRect = $FadeRect
@onready var location_label: Label = $LocationLabel

var is_transitioning: bool = false
var fade_duration: float = 0.8


func _ready() -> void:
	layer = 100  # always on top
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_label.visible = false


## Call this to transition to a new scene with a fade effect.
func change_scene(target_scene: String, location_text: String = "") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # block input during fade

	# Fade to black
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)

	# Show location text during black
	if location_text != "":
		tween.tween_callback(func():
			location_label.text = location_text
			location_label.visible = true
			location_label.modulate.a = 0.0
		)
		tween.tween_property(location_label, "modulate:a", 1.0, 0.4)
		tween.tween_interval(1.2)
		tween.tween_property(location_label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func(): location_label.visible = false)

	# Change scene
	tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene)
	)

	# Fade from black (runs after new scene loads)
	tween.tween_interval(0.15)
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		transition_finished.emit()
	)
