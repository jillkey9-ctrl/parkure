class_name SpringPad
extends Area2D

@export var bounce_force := 1800.0
@export var momentum_keep := 0.3
@export var cooldown_time := 0.15
@export var direction_ray: RayCast2D

var _cooldown := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if direction_ray == null:
		direction_ray = get_node_or_null("RayCast2D")

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0:
		return

	if body is Player:
		_cooldown = cooldown_time
		
		var dir := Vector2.UP
		if direction_ray != null:
			dir = direction_ray.target_position.normalized()
		else:
			dir = Vector2.UP.rotated(global_rotation)
		
		var bounce_vel := dir * bounce_force
		if momentum_keep > 0.0:
			bounce_vel += body.velocity * momentum_keep
			
		body.apply_spring_bounce(bounce_vel)
