extends AnimatableBody2D

@export var line_path: Line2D
@export var weight: float = 1.0

var move_speed := 200.0
var return_speed := 150.0

var start_pos := Vector2.ZERO
var end_pos := Vector2.ZERO
var current_velocity := Vector2.ZERO

var player_on_platform := false
var area: Area2D = null
var player_ref: CharacterBody2D = null

func _ready() -> void:
	if not line_path or line_path.points.size() < 2:
		return
	
	start_pos = line_path.to_global(line_path.points[0])
	end_pos = line_path.to_global(line_path.points[-1])
	global_position = start_pos
	
	area = get_node_or_null("Area2D")
	if area:
		area.monitoring = true
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	var target_pos: Vector2
	var speed: float
	
	if player_on_platform:
		target_pos = end_pos
		speed = move_speed / maxf(weight, 0.1)
	else:
		target_pos = start_pos
		speed = return_speed
	
	var prev_pos = global_position
	global_position = global_position.move_toward(target_pos, speed * delta)
	current_velocity = (global_position - prev_pos) / delta if delta > 0.0 else Vector2.ZERO
	
	if player_on_platform and player_ref and is_instance_valid(player_ref):
		player_ref.velocity.y += current_velocity.y

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_platform = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_platform = false
		player_ref = null
