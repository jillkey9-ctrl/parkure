extends Camera2D

@export var max_speed: float = 500.0
@export var acceleration: float = 8.0
@export var deceleration: float = 6.0

var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.limit_length()

	var wish_vel := input_dir.normalized() * max_speed if input_dir.length() > 0.1 else Vector2.ZERO

	var current_accel := acceleration if input_dir.length() > 0.1 else deceleration
	velocity = velocity.lerp(wish_vel, 1.0 - exp(-current_accel * delta))

	position += velocity * delta
