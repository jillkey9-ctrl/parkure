extends AnimatableBody2D

@export var line_path: Line2D
@export var move_speed := 150.0

var jump_push_multiplier := 0.4
var side_bounce_force := 400.0

var path_points := []
var segment_lengths := []
var total_length := 0.0
var distance_traveled := 0.0
var current_velocity := Vector2.ZERO
var is_loop := false

var progress := 0.0
var state := 0
var pause_timer := 0.0
var pause_duration := 0.2

func _ready() -> void:
	if not line_path or line_path.points.size() < 2:
		return
	
	path_points.clear()
	for point in line_path.points:
		path_points.append(line_path.to_global(point))
	
	calculate_segments()
	is_loop = path_points[0].distance_to(path_points[-1]) < 1.0
	global_position = path_points[0]

func calculate_segments() -> void:
	segment_lengths.clear()
	total_length = 0.0
	for i in range(path_points.size() - 1):
		var dist = path_points[i].distance_to(path_points[i+1])
		segment_lengths.append(dist)
		total_length += dist

func _physics_process(delta: float) -> void:
	if path_points.size() < 2 or total_length == 0.0:
		return

	var prev_pos = global_position
	var target_pos := Vector2.ZERO
	
	if is_loop:
		distance_traveled = fmod(distance_traveled + move_speed * delta, total_length)
		target_pos = get_position_at_distance(distance_traveled)
	else:
		match state:
			0:
				progress += (move_speed / total_length) * delta
				if progress >= 1.0:
					progress = 1.0
					state = 1
					pause_timer = pause_duration
			1:
				pause_timer -= delta
				if pause_timer <= 0.0:
					state = 2
			2:
				progress -= (move_speed / total_length) * delta
				if progress <= 0.0:
					progress = 0.0
					state = 3
					pause_timer = pause_duration
			3:
				pause_timer -= delta
				if pause_timer <= 0.0:
					state = 0

		target_pos = get_position_at_distance(smoothstep(0.0, 1.0, progress) * total_length)

	global_position = target_pos
	current_velocity = (global_position - prev_pos) / delta if delta > 0.0 else Vector2.ZERO

func get_position_at_distance(d: float) -> Vector2:
	var remaining = d
	for i in range(segment_lengths.size()):
		if remaining <= segment_lengths[i]:
			var t = remaining / segment_lengths[i] if segment_lengths[i] > 0.0 else 0.0
			return path_points[i].lerp(path_points[i+1], t)
		remaining -= segment_lengths[i]
	return path_points[-1]

func get_platform_velocity() -> Vector2:
	return current_velocity

func _on_top_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.velocity.y < 0.0:
		body.velocity.x += current_velocity.x * jump_push_multiplier

func _on_left_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.velocity.x = -side_bounce_force

func _on_right_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.velocity.x = side_bounce_force
