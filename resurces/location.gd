class_name Location
extends Resource

@export var level: int = 1
@export var min_rooms: int = 3
@export var max_rooms: int = 6
@export var starting_room: PackedScene
@export var ending_room: PackedScene
@export var rooms: Array[PackedScene] = []
