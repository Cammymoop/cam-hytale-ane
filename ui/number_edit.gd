extends LineEdit
class_name GNNumberEdit

signal val_changed(new_value: float)

@export var is_int: = false
@export var custom_decimal_places: = -1
var value: float = 0.0

var text_dirty: = false

func _ready() -> void:
    alignment = HORIZONTAL_ALIGNMENT_RIGHT
    focus_exited.connect(on_focus_out)
    text_submitted.connect(text_change_done.unbind(1))
    text_changed.connect(on_text_changed)


func set_value_directly(new_value: float) -> void:
    value = new_value
    text_dirty = false
    redisplay_value()

func on_text_changed(_new_text: String) -> void:
    text_dirty = true

func on_focus_out() -> void:
    if text_dirty:
        get_value_from_text()
        value_updated()

func text_change_done() -> void:
    get_value_from_text()
    value_updated()

func get_value_from_text() -> void:
    value = float(text)
    val_changed.emit(value)

func value_updated() -> void:
    if is_int:
        value = roundf(value)
    text_dirty = false
    redisplay_value()

func get_decimal_places() -> int:
    if custom_decimal_places != -1:
        return custom_decimal_places
    return ANESettings.display_decimal_places

func get_snap_float() -> float:
    var snap_float: = 1.0 / pow(10, get_decimal_places())
    #print_debug("snap_float: %s" % snap_float)
    return snap_float

func redisplay_value() -> void:
    var rounded_val: = snappedf(value, get_snap_float())
    if rounded_val == int(rounded_val):
        text = str(int(rounded_val))
    else:
        text = str(rounded_val)
