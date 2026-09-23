extends Area2D

var trapped_player: Node = null
var pull_strength := 4500.0
var trap_radius := 180.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and trapped_player == null:
		trapped_player = body
		if body.has_method("enter_trap"):
			body.enter_trap(global_position, trap_radius, pull_strength)

func _on_body_exited(body: Node) -> void:
	if body == trapped_player:
		trapped_player = null
		if body.has_method("exit_trap"):
			body.exit_trap()
