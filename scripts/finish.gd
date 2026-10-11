extends Area2D

signal finish_reached(time: float)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		finish_reached.emit(0.0)
