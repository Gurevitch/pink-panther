extends Node2D

@onready var background: ColorRect = $Background
@onready var pink_panther: PinkPanther = $PinkPanther
@onready var dialog_system: DialogSystem = $DialogSystem
@onready var ui_label: Label = $UI/Label

func _ready() -> void:
	ui_label.text = "Click to walk | Click characters to talk | 1/2/3: Change time"

	pink_panther.set_dialog_system(dialog_system)

	for node in get_tree().get_nodes_in_group("clickable"):
		if node is ClickableObject:
			node.interaction_requested.connect(_on_object_clicked)
			_setup_npc_dialog(node)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_set_time_of_day(0)
			KEY_2:
				_set_time_of_day(1)
			KEY_3:
				_set_time_of_day(2)


func _set_time_of_day(preset: int) -> void:
	var mat := background.material as ShaderMaterial
	match preset:
		0:
			mat.set_shader_parameter("color_sky_top", Color(0.02, 0.02, 0.08, 1))
			mat.set_shader_parameter("color_sky_bottom", Color(0.08, 0.05, 0.15, 1))
			mat.set_shader_parameter("building_color_1", Color(0.03, 0.03, 0.06, 1))
			mat.set_shader_parameter("building_color_2", Color(0.05, 0.04, 0.08, 1))
			mat.set_shader_parameter("window_color", Color(1.0, 0.9, 0.5, 1))
			mat.set_shader_parameter("star_density", 0.25)
			mat.set_shader_parameter("moon_size", 0.055)
		1:
			mat.set_shader_parameter("color_sky_top", Color(0.15, 0.08, 0.25, 1))
			mat.set_shader_parameter("color_sky_bottom", Color(0.65, 0.32, 0.15, 1))
			mat.set_shader_parameter("building_color_1", Color(0.08, 0.05, 0.12, 1))
			mat.set_shader_parameter("building_color_2", Color(0.12, 0.08, 0.15, 1))
			mat.set_shader_parameter("window_color", Color(1.0, 0.85, 0.4, 1))
			mat.set_shader_parameter("star_density", 0.08)
			mat.set_shader_parameter("moon_size", 0.04)
		2:
			mat.set_shader_parameter("color_sky_top", Color(0.12, 0.15, 0.35, 1))
			mat.set_shader_parameter("color_sky_bottom", Color(0.55, 0.35, 0.25, 1))
			mat.set_shader_parameter("building_color_1", Color(0.06, 0.06, 0.1, 1))
			mat.set_shader_parameter("building_color_2", Color(0.1, 0.08, 0.12, 1))
			mat.set_shader_parameter("window_color", Color(1.0, 0.92, 0.6, 1))
			mat.set_shader_parameter("star_density", 0.12)
			mat.set_shader_parameter("moon_size", 0.05)


func _setup_npc_dialog(npc: ClickableObject) -> void:
	match npc.object_name:
		"Old Vendor":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Good evening! Nice stand you have here.", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Vendor", "text": "Evenin'! Care for the latest news? Or maybe you're lookin' for somethin' else?", "portrait_color": Color(0.9, 0.75, 0.6)},
				{"speaker": "Pink Panther", "text": "Actually, I'm looking for someone. Have you seen anything... unusual around here?", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Vendor", "text": "Unusual? In this city? Ha! There was a suspicious fellow lurking about earlier...", "portrait_color": Color(0.9, 0.75, 0.6)},
				{"speaker": "Pink Panther", "text": "Suspicious, you say? Do tell!", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Vendor", "text": "Wore a trenchcoat, kept mumblin' about some passport. Headed that way!", "portrait_color": Color(0.9, 0.75, 0.6)}
			])


func _on_object_clicked(object: ClickableObject) -> void:
	pink_panther.walk_to_and_interact(object)
