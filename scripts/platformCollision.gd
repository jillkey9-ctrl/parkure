extends Area2D

@export var static_body: StaticBody2D
@export var check_offset: float = 5.0

var player_inside := false
var player_ref: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if not player_inside or not player_ref:
		return
	
	var shape := static_body.get_node_or_null("CollisionShape2D")
	if not shape:
		return
	
	var player_above := player_ref.global_position.y < (global_position.y - check_offset)
	shape.disabled = not player_above

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		player_ref = null
