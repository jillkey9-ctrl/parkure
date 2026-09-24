extends Area2D

var trapped_player: Node = null
@export var target: Node2D
@export var pull_strength := 1200.0
@export var max_swim_speed := 500.0
@export var drag := 600.0

var trap_radius := 0.0
var trap_center := Vector2.ZERO

func _ready() -> void:
	process_priority = -100
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		trap_radius = collision_shape.shape.radius
		trap_center = global_position + collision_shape.position
	else:
		trap_radius = 100.0
		trap_center = global_position

func _physics_process(delta: float) -> void:
	if trapped_player == null or not is_instance_valid(trapped_player):
		trapped_player = null
		return
	
	if not trapped_player.is_trapped:
		trapped_player = null
		return
	
	var center: Vector2 = target.global_position if target else trap_center
	var player_pos: Vector2 = trapped_player.global_position
	var to_center: Vector2 = center - player_pos
	var dist: float = to_center.length()
	
	if dist > 2.0:
		var pull_dir: Vector2 = to_center.normalized()
		var pull_force: float = pull_strength * (dist / trap_radius)
		trapped_player.velocity += pull_dir * pull_force * delta
	
	trapped_player.velocity = trapped_player.velocity.move_toward(Vector2.ZERO, drag * delta)
	trapped_player.velocity = trapped_player.velocity.limit_length(max_swim_speed)
	
	if dist > trap_radius:
		var clamped_pos: Vector2 = center + (player_pos - center).normalized() * trap_radius
		trapped_player.global_position = clamped_pos
		var outward_dir: Vector2 = (player_pos - center).normalized()
		var outward_vel: float = trapped_player.velocity.dot(outward_dir)
		if outward_vel > 0.0:
			trapped_player.velocity -= outward_dir * outward_vel

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and trapped_player == null:
		trapped_player = body
		if body.has_method("enter_trap"):
			var center: Vector2 = target.global_position if target else trap_center
			body.enter_trap(center, trap_radius)

func _on_body_exited(body: Node) -> void:
	if body == trapped_player:
		trapped_player = null
		if body.has_method("exit_trap"):
			body.exit_trap()
