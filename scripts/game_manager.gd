extends Node2D

@export var player_scene: PackedScene
@export var spawn_points: Array[Node2D]
@export var finish_area: Area2D
@export var time_label: Label
@export var progress_bar: ColorRect

var time_elapsed: float = 0.0
var is_game_active: bool = false
var start_position: Vector2
var finish_position: Vector2
var original_progress_width: float = 0.0
var current_player: Node2D
var max_distance_reached: float = 0.0

func _ready() -> void:
	if progress_bar:
		original_progress_width = progress_bar.size.x
		progress_bar.size.x = 0.0

	if finish_area:
		finish_position = finish_area.global_position
		finish_area.body_entered.connect(_on_finish_body_entered)

	spawn_player()
	is_game_active = true

func spawn_player() -> void:
	if player_scene and spawn_points.size() > 0:
		var random_index = randi() % spawn_points.size()
		var spawn_pos = spawn_points[random_index].global_position
		current_player = player_scene.instantiate()
		current_player.global_position = spawn_pos
		start_position = spawn_pos
		add_child(current_player)

func _process(delta: float) -> void:
	if not is_game_active or not current_player:
		return

	time_elapsed += delta
	
	if time_label:
		time_label.text = "%.2f" % time_elapsed

	update_progress_bar()

func update_progress_bar() -> void:
	if not progress_bar or original_progress_width <= 0.0:
		return

	var total_distance = start_position.distance_to(finish_position)
	if total_distance == 0.0:
		progress_bar.size.x = original_progress_width
		return

	var current_distance = start_position.distance_to(current_player.global_position)
	if current_distance > max_distance_reached:
		max_distance_reached = current_distance

	var progress = clampf(max_distance_reached / total_distance, 0.0, 1.0)
	progress_bar.size.x = original_progress_width * progress

func _on_finish_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_game_active = false
		
		if time_label:
			time_label.text = "%.2f" % time_elapsed
			
		if progress_bar and original_progress_width > 0.0:
			progress_bar.size.x = original_progress_width
