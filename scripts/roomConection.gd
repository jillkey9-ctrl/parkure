class_name ConnectionPoint
extends Node2D

enum Direction { UP, RIGHT, DOWN, LEFT }

@export var direction: Direction = Direction.RIGHT

func get_direction_angle() -> float:
	match direction:
		Direction.UP: return -PI / 2
		Direction.RIGHT: return 0.0
		Direction.DOWN: return PI / 2
		Direction.LEFT: return PI
	return 0.0

func get_opposite_direction() -> int:
	match direction:
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
	return direction
