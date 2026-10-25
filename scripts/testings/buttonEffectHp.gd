extends Button

@export var effect_name: String = "hp"
@export var effect_amount: float = 10.0

func _ready() -> void:
	set_meta("effect_name", effect_name)
	set_meta("effect_amount", effect_amount)
