extends SpinBox
class_name GNSpinBox

signal val_changed(new_value: float)

@export var is_int: = false
@export var custom_decimal_places: = -1

func _ready() -> void:
    pass

func set_value_directly(new_value: float) -> void:
    set_value_no_signal(new_value)

