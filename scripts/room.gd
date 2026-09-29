class_name Room
extends Node2D

@onready var start_point: ConnectionPoint = $Start if has_node("Start") else null
@onready var end_point: ConnectionPoint = $End if has_node("End") else null
@onready var bounds: Area2D = $Bounds if has_node("Bounds") else null

func _ready() -> void:
	if bounds:
		bounds.add_to_group("room_bounds")
