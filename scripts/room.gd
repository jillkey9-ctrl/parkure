class_name Room
extends Node2D

enum RoomType { NORMAL, START, END }

@export var room_type: RoomType = RoomType.NORMAL
@export var time_bonus: float = 0.0

@onready var start_point: ConnectionPoint = $Start if has_node("Start") else null
@onready var end_point: ConnectionPoint = $End if has_node("End") else null
@onready var bounds: Area2D = $Bounds if has_node("Bounds") else null
@onready var finish_area: Area2D = $Finish if has_node("Finish") else null

var spawn_points: Array[Node2D] = []

func _ready() -> void:
	if bounds:
		bounds.add_to_group("room_bounds")
	
	if room_type == RoomType.START:
		for child in get_children():
			if child is Node2D and child.name.to_lower() == "spawn":
				spawn_points.append(child)
