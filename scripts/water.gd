extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not body.is_in_water:
		body.enter_water()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.is_in_water:
		body.exit_water()
