extends Button

@export_file("*.tscn") var target_scene_path: String = ""
@export var transition_delay: float = 0.0


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if target_scene_path.is_empty():
		push_warning("SceneChangerButton: путь к сцене не задан!")
		return

	if not ResourceLoader.exists(target_scene_path):
		push_error("SceneChangerButton: сцена не найдена по пути: %s" % target_scene_path)
		return

	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout

	get_tree().change_scene_to_file(target_scene_path)
