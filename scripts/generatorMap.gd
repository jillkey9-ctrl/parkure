extends Node2D

@export var locations: Array[Location] = []
@export var generation_delay: float = 0.02
@export var max_locations_to_pick: int = 5
@export var generation_button: Button
@export var player_scene: PackedScene
@export var camera: Camera2D
@export var time_label: Label
@export var progress_bar: ColorRect
@export var next_scene: PackedScene

var rooms_container: Node2D
var placed_rooms: Array[Dictionary] = []
var path_stack: Array[Node2D] = []
var current_player: Node2D = null
var finish_area: Area2D = null
var start_position: Vector2 = Vector2.ZERO
var finish_position: Vector2 = Vector2.ZERO
var original_progress_width: float = 0.0
var time_remaining: float = 0.0
var time_total: float = 0.0
var is_game_active: bool = false
var max_distance_reached: float = 0.0

func _ready() -> void:
	rooms_container = Node2D.new()
	rooms_container.name = "RoomsContainer"
	add_child(rooms_container)
	if generation_button:
		generation_button.pressed.connect(_on_generation_button_pressed)
	
	if progress_bar:
		original_progress_width = progress_bar.size.x
		progress_bar.size.x = 0.0

func _on_generation_button_pressed() -> void:
	if generation_button:
		generation_button.hide()
	_build_location_chain()

func _build_location_chain() -> void:
	if locations.is_empty():
		return

	var levels_map: Dictionary = {}
	for loc: Location in locations:
		if not levels_map.has(loc.level):
			levels_map[loc.level] = []
		levels_map[loc.level].append(loc)

	var sorted_levels: Array = levels_map.keys()
	sorted_levels.sort()

	var picked: Array[Location] = []
	
	for level in sorted_levels:
		var level_locations: Array = levels_map[level]
		level_locations.shuffle()
		
		for loc: Location in level_locations:
			picked.append(loc)
			if picked.size() >= max_locations_to_pick:
				break
				
		if picked.size() >= max_locations_to_pick:
			break

	placed_rooms.clear()
	path_stack.clear()
	finish_area = null
	time_remaining = 0.0
	time_total = 0.0
	max_distance_reached = 0.0
	is_game_active = false

	var start_room: Room = null
	var end_room: Room = null

	for i in picked.size():
		var location: Location = picked[i]
		if location.starting_room == null:
			continue

		var room_instance: Node2D = _spawn_room(location.starting_room)
		room_instance.global_position = Vector2.ZERO
		var start_bounds: Rect2 = _get_room_bounds(room_instance)
		placed_rooms.append({"room": room_instance, "bounds": start_bounds})
		path_stack.append(room_instance)

		if i == 0:
			start_room = room_instance as Room

		var target_rooms: int = randi_range(location.min_rooms, location.max_rooms)
		var rooms_placed: int = 0
		var failed_attempts: int = 0

		while rooms_placed < target_rooms:
			await _wait_frame()
			var room: Node2D = _try_place_next_room(location)

			if room != null:
				path_stack.append(room)
				rooms_placed += 1
				failed_attempts = 0
			else:
				failed_attempts += 1
				if failed_attempts > 10:
					if path_stack.size() > 1:
						_backtrack()
					else:
						break

		if location.ending_room != null:
			await _wait_frame()
			var end_room_instance: Node2D = _try_place_ending_room(location.ending_room)
			if end_room_instance == null:
				if _try_replace_penultimate_for_ending(location, location.ending_room):
					if path_stack.size() > 0:
						end_room = path_stack.back() as Room
			else:
				path_stack.append(end_room_instance)
				end_room = end_room_instance as Room

	_calculate_total_time()
	time_remaining = time_total

	if start_room and player_scene:
		await _wait_frame()
		_spawn_player_at_start(start_room)
		
	if end_room and end_room.has_node("Finish"):
		finish_area = end_room.get_node("Finish")
		finish_position = finish_area.global_position
		finish_area.body_entered.connect(_on_finish_body_entered)
		
	if current_player:
		start_position = current_player.global_position
		is_game_active = true

func _calculate_total_time() -> void:
	time_total = 0.0
	for placed: Dictionary in placed_rooms:
		var room: Node2D = placed["room"]
		if room is Room:
			time_total += room.time_bonus

func _spawn_player_at_start(start_room: Room) -> void:
	if start_room.spawn_points.is_empty():
		return
	
	var spawn_point: Node2D = start_room.spawn_points[randi() % start_room.spawn_points.size()]
	current_player = player_scene.instantiate()
	current_player.global_position = spawn_point.global_position
	add_child(current_player)
	
	if camera:
		camera.target = current_player

func _process(delta: float) -> void:
	if not is_game_active or not current_player:
		return

	time_remaining -= delta
	
	if time_label:
		time_label.text = "%.2f" % maxf(time_remaining, 0.0)

	update_progress_bar()

	if time_remaining <= 0.0:
		is_game_active = false
		if next_scene:
			get_tree().change_scene_to_packed(next_scene)

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
		
		if progress_bar and original_progress_width > 0.0:
			progress_bar.size.x = original_progress_width
		
		if next_scene:
			call_deferred("_change_scene")

func _change_scene() -> void:
	get_tree().change_scene_to_packed(next_scene)

func _spawn_room(scene: PackedScene) -> Node2D:
	var instance: Node2D = scene.instantiate()
	rooms_container.add_child(instance)
	return instance

func _try_place_next_room(location: Location) -> Node2D:
	var current_room: Node2D = path_stack.back()
	if not current_room.has_node("End"):
		return null

	var end_point: ConnectionPoint = current_room.get_node("End")
	var end_global_pos: Vector2 = end_point.global_position
	var end_direction: int = end_point.direction

	var available_rooms: Array[PackedScene] = location.rooms.duplicate()
	available_rooms.shuffle()

	for scene: PackedScene in available_rooms:
		var room: Node2D = _spawn_room(scene)
		if _orient_and_position_room(room, end_global_pos, end_direction):
			var bounds: Rect2 = _get_room_bounds(room)
			if not _check_bounds_collision(bounds, room):
				placed_rooms.append({"room": room, "bounds": bounds})
				return room
		_remove_room(room)
	return null

func _try_place_ending_room(scene: PackedScene) -> Node2D:
	var current_room: Node2D = path_stack.back()
	if not current_room.has_node("End"):
		return null

	var end_point: ConnectionPoint = current_room.get_node("End")
	var end_global_pos: Vector2 = end_point.global_position
	var end_direction: int = end_point.direction

	var room: Node2D = _spawn_room(scene)
	if _orient_and_position_room_fixed(room, end_global_pos, end_direction):
		var bounds: Rect2 = _get_room_bounds(room)
		if not _check_bounds_collision(bounds, room):
			placed_rooms.append({"room": room, "bounds": bounds})
			return room
	_remove_room(room)
	return null

func _try_replace_penultimate_for_ending(location: Location, ending_scene: PackedScene) -> bool:
	if path_stack.size() < 2:
		return false

	var penultimate: Node2D = path_stack.back()
	var previous: Node2D = path_stack[path_stack.size() - 2]

	if not previous.has_node("End"):
		return false

	var prev_end: ConnectionPoint = previous.get_node("End")

	var ending_probe: Node2D = ending_scene.instantiate()
	if not ending_probe.has_node("Start"):
		ending_probe.queue_free()
		return false

	var ending_start: ConnectionPoint = ending_probe.get_node("Start")
	var required_penultimate_end_dir: int = _get_opposite_direction(ending_start.direction)
	ending_probe.queue_free()

	var candidates: Array[PackedScene] = location.rooms.duplicate()
	candidates.shuffle()

	for scene: PackedScene in candidates:
		var candidate: Node2D = _spawn_room(scene)
		if not candidate.has_node("Start") or not candidate.has_node("End"):
			_remove_room(candidate)
			continue

		var c_start: ConnectionPoint = candidate.get_node("Start")
		var c_end: ConnectionPoint = candidate.get_node("End")

		if c_end.direction != required_penultimate_end_dir:
			_remove_room(candidate)
			continue

		var required_start_dir: int = _get_opposite_direction(prev_end.direction)
		if c_start.direction != required_start_dir:
			_remove_room(candidate)
			continue

		if not _orient_and_position_room(candidate, prev_end.global_position, prev_end.direction):
			_remove_room(candidate)
			continue

		var bounds: Rect2 = _get_room_bounds(candidate)
		if _check_bounds_collision_excluding(bounds, candidate, penultimate):
			_remove_room(candidate)
			continue

		_remove_room(penultimate)
		for j in range(placed_rooms.size() - 1, -1, -1):
			if placed_rooms[j]["room"] == penultimate:
				placed_rooms.remove_at(j)
				break
		path_stack.pop_back()

		path_stack.append(candidate)
		placed_rooms.append({"room": candidate, "bounds": bounds})

		var end_room: Node2D = _try_place_ending_room(ending_scene)
		if end_room != null:
			path_stack.append(end_room)
			return true

		_remove_room(candidate)
		for j in range(placed_rooms.size() - 1, -1, -1):
			if placed_rooms[j]["room"] == candidate:
				placed_rooms.remove_at(j)
				break
		path_stack.pop_back()

		path_stack.append(penultimate)
		placed_rooms.append({"room": penultimate, "bounds": _get_room_bounds(penultimate)})
		return false

	return false

func _orient_and_position_room(room: Node2D, target_pos: Vector2, target_direction: int) -> bool:
	if not room.has_node("Start"):
		return false

	var start_point: ConnectionPoint = room.get_node("Start")
	var required_dir: int = _get_opposite_direction(target_direction)
	var required_angle: float = _direction_to_angle(required_dir)
	var start_angle: float = start_point.get_direction_angle()

	room.rotation = required_angle - start_angle

	var start_global_pos: Vector2 = start_point.global_position
	room.global_position += (target_pos - start_global_pos)
	return true

func _orient_and_position_room_fixed(room: Node2D, target_pos: Vector2, target_direction: int) -> bool:
	if not room.has_node("Start"):
		return false

	var start_point: ConnectionPoint = room.get_node("Start")
	var required_dir: int = _get_opposite_direction(target_direction)

	if start_point.direction != required_dir:
		return false

	room.rotation = 0.0
	var start_global_pos: Vector2 = start_point.global_position
	room.global_position += (target_pos - start_global_pos)
	return true

func _get_opposite_direction(dir: int) -> int:
	match dir:
		ConnectionPoint.Direction.UP: return ConnectionPoint.Direction.DOWN
		ConnectionPoint.Direction.DOWN: return ConnectionPoint.Direction.UP
		ConnectionPoint.Direction.LEFT: return ConnectionPoint.Direction.RIGHT
		ConnectionPoint.Direction.RIGHT: return ConnectionPoint.Direction.LEFT
	return dir

func _direction_to_angle(dir: int) -> float:
	match dir:
		ConnectionPoint.Direction.UP: return -PI / 2
		ConnectionPoint.Direction.RIGHT: return 0.0
		ConnectionPoint.Direction.DOWN: return PI / 2
		ConnectionPoint.Direction.LEFT: return PI
	return 0.0

func _get_room_bounds(room: Node2D) -> Rect2:
	if room.has_node("Bounds"):
		var bounds: Area2D = room.get_node("Bounds")
		for child: Node in bounds.get_children():
			if child is CollisionShape2D:
				var shape_node: CollisionShape2D = child
				if shape_node.shape == null:
					continue
				if shape_node.shape is RectangleShape2D:
					var rect_shape: RectangleShape2D = shape_node.shape
					var size: Vector2 = rect_shape.size * shape_node.scale.abs()
					var center: Vector2 = shape_node.global_position
					return Rect2(center - size / 2, size)
				elif shape_node.shape is CircleShape2D:
					var circle_shape: CircleShape2D = shape_node.shape
					var radius: float = circle_shape.radius * maxf(abs(shape_node.scale.x), abs(shape_node.scale.y))
					var center: Vector2 = shape_node.global_position
					return Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
				elif shape_node.shape is CapsuleShape2D:
					var capsule_shape: CapsuleShape2D = shape_node.shape
					var height: float = capsule_shape.height * abs(shape_node.scale.y)
					var radius: float = capsule_shape.radius * maxf(abs(shape_node.scale.x), abs(shape_node.scale.y))
					var center: Vector2 = shape_node.global_position
					var size: Vector2 = Vector2(radius * 2, height)
					return Rect2(center - size / 2, size)
				elif shape_node.shape is ConvexPolygonShape2D:
					var poly_shape: ConvexPolygonShape2D = shape_node.shape
					var points: PackedVector2Array = poly_shape.points
					if points.size() > 0:
						var min_x: float = points[0].x
						var min_y: float = points[0].y
						var max_x: float = points[0].x
						var max_y: float = points[0].y
						for point: Vector2 in points:
							var transformed_point: Vector2 = point * shape_node.scale + shape_node.position
							min_x = minf(min_x, transformed_point.x)
							min_y = minf(min_y, transformed_point.y)
							max_x = maxf(max_x, transformed_point.x)
							max_y = maxf(max_y, transformed_point.y)
						return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return Rect2(room.global_position - Vector2(100, 100), Vector2(200, 200))

func _check_bounds_collision(bounds: Rect2, room: Node2D) -> bool:
	for placed: Dictionary in placed_rooms:
		var placed_room: Node2D = placed["room"]
		var placed_bounds: Rect2 = placed["bounds"]
		if placed_room == room:
			continue
		if bounds.intersects(placed_bounds):
			return true
	return false

func _check_bounds_collision_excluding(bounds: Rect2, room: Node2D, excluded: Node2D) -> bool:
	for placed: Dictionary in placed_rooms:
		var placed_room: Node2D = placed["room"]
		var placed_bounds: Rect2 = placed["bounds"]
		if placed_room == room or placed_room == excluded:
			continue
		if bounds.intersects(placed_bounds):
			return true
	return false

func _backtrack() -> void:
	if path_stack.size() <= 1:
		return
	var room: Node2D = path_stack.pop_back()
	for i in range(placed_rooms.size() - 1, -1, -1):
		var placed_room: Node2D = placed_rooms[i]["room"]
		if placed_room == room:
			placed_rooms.remove_at(i)
			break
	_remove_room(room)

func _remove_room(room: Node2D) -> void:
	if room.get_parent():
		room.get_parent().remove_child(room)
	room.queue_free()

func _wait_frame() -> void:
	if generation_delay > 0.0:
		await get_tree().create_timer(generation_delay).timeout
	else:
		await get_tree().process_frame
