extends Area2D

@export var sila: float = 800.0
@export var raycast: RayCast2D

var acceleration: float = 1200.0

var bodies_in_zone: Array[CharacterBody2D] = []
var lift_progress: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not raycast:
		return
	
	var wind_direction: Vector2 = raycast.target_position.normalized()
	
	for body in bodies_in_zone:
		if not is_instance_valid(body):
			continue
		
		if not lift_progress.has(body):
			lift_progress[body] = 0.0
		
		lift_progress[body] = minf(lift_progress[body] + acceleration * delta, sila)
		
		var current_force: float = lift_progress[body]
		
		if wind_direction.y != 0:
			body.velocity.y = wind_direction.y * current_force
		
		if wind_direction.x != 0:
			body.velocity.x = wind_direction.x * current_force

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		bodies_in_zone.append(body)
		lift_progress[body] = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		bodies_in_zone.erase(body)
