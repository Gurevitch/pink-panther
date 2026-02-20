extends Node2D

@onready var pink_panther: PinkPanther = $PinkPanther
@onready var dialog_system: DialogSystem = $DialogSystem
@onready var ui_label: Label = $UI/Label
@onready var transition: Node = $SceneTransition

func _ready() -> void:
	ui_label.text = "Click to walk | Click objects to interact | Click door to exit"
	pink_panther.set_dialog_system(dialog_system)

	# Wait one frame so RoomBuilder children are fully in the tree
	await get_tree().process_frame

	for node in get_tree().get_nodes_in_group("clickable"):
		if node is ClickableObject:
			node.interaction_requested.connect(_on_object_clicked)
			_setup_dialog(node)

	# Connect the door exit
	for node in get_tree().get_nodes_in_group("exit"):
		if node is Area2D:
			node.input_event.connect(_on_exit_input.bind(node))


func _setup_dialog(npc: ClickableObject) -> void:
	match npc.object_name:
		"British Man":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Good day! Cozy cottage you have here.", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "British Man", "text": "Ah yes! Been in the family for generations. Do come in, won't you?", "portrait_color": Color(0.3, 0.4, 0.8)},
				{"speaker": "Pink Panther", "text": "Actually, I'm looking for someone... a rather suspicious character?", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "British Man", "text": "Suspicious? My good fellow, the only suspicious thing here is the professor's experiments upstairs!", "portrait_color": Color(0.3, 0.4, 0.8)},
				{"speaker": "Pink Panther", "text": "A professor, you say? Interesting...", "portrait_color": Color(1.0, 0.42, 0.71)},
			])
		"Old Professor":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Excuse me, Professor? I couldn't help but notice your... interesting collection.", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Professor", "text": "Ah! A visitor! Yes, yes — specimens from my travels. Each one tells a story!", "portrait_color": Color(0.6, 0.75, 0.5)},
				{"speaker": "Pink Panther", "text": "Have you seen anything unusual lately? Strange visitors perhaps?", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Professor", "text": "Unusual? My boy, I catalogued a three-toed mud beetle last Tuesday. But if you mean PEOPLE... there was a chap sneaking about the garden.", "portrait_color": Color(0.6, 0.75, 0.5)},
				{"speaker": "Pink Panther", "text": "The garden! That's just what I needed. Thank you, Professor!", "portrait_color": Color(1.0, 0.42, 0.71)},
				{"speaker": "Old Professor", "text": "Do be careful! And don't step on any beetles!", "portrait_color": Color(0.6, 0.75, 0.5)},
			])
		"Stone Bust":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Hmm, a bust of someone important... or at least someone who thinks they're important.", "portrait_color": Color(1.0, 0.42, 0.71)},
			])
		"Framed Painting":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Nice mountain scene. Reminds me of my vacation in Switzerland... before the avalanche.", "portrait_color": Color(1.0, 0.42, 0.71)},
			])
		"Display Case":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Colorful trinkets behind glass. I wonder what they're worth... to a panther of refined taste.", "portrait_color": Color(1.0, 0.42, 0.71)},
			])
		"British Flag":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "God save the... panther?", "portrait_color": Color(1.0, 0.42, 0.71)},
			])
		"Door Exit":
			npc.set_dialog([
				{"speaker": "Pink Panther", "text": "Time to head outside and check that garden...", "portrait_color": Color(1.0, 0.42, 0.71)},
			])


func _on_object_clicked(object: ClickableObject) -> void:
	# If it's the door exit, walk to it then trigger scene change
	if object.object_name == "Door Exit":
		pink_panther.walk_to_and_interact(object)
		# After dialog finishes, transition to the other scene
		if not dialog_system.dialog_finished.is_connected(_on_door_dialog_done):
			dialog_system.dialog_finished.connect(_on_door_dialog_done, CONNECT_ONE_SHOT)
	else:
		pink_panther.walk_to_and_interact(object)


func _on_door_dialog_done() -> void:
	# Fade out music
	var music := $BGMusic as AudioStreamPlayer
	if music:
		var tween := create_tween()
		tween.tween_property(music, "volume_db", -40.0, 0.6)

	# Transition to main scene (or another scene)
	transition.change_scene("res://scenes/main.tscn", "Heading outside...")


func _on_exit_input(_viewport: Node, event: InputEvent, _shape_idx: int, _area: Area2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_on_door_dialog_done()
