extends CustomLineEdit
class_name GNNumberEdit

signal val_changed(new_value: float)

@export var is_int: = false
@export var custom_decimal_places: = -1
var value: float = 0.0

var text_dirty: = false

func _init() -> void:
    super._init()
    alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _ready() -> void:
    super._ready()
    focus_exited.connect(on_focus_out)
    text_submitted.connect(text_change_done.unbind(1))
    text_changed.connect(on_text_changed)
    redisplay_value()
    
func update_tooltip_text() -> void:
    if is_int:
        tooltip_text = "%d" % int(value)
    else:
        tooltip_text = "%s" % value


func set_value_directly(new_value: float) -> void:
    if is_int:
        value = roundf(new_value)
    else:
        value = new_value
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
    if not text.is_valid_float():
        print_debug("Trying to use non-numeric text as an expression: %s" % text)
        get_value_from_expression(text)
        return

    if is_int:
        value = int(float(text))
    else:
        value = float(text)

func get_value_from_expression(expr_text: String) -> void:
    # if the expression is invalid or fails to execute, don't update the value at all
    # the text will return to the last valid value
    if not ExpressionHelper.is_valid_expression(expr_text):
        return
    var result: = ExpressionHelper.get_expression_numerical_value(expr_text)
    if not result[0]:
        return

    if is_int:
        value = int(result[1])
    else:
        value = result[1]

func value_updated() -> void:
    redisplay_value()
    val_changed.emit(value)

func get_decimal_places() -> int:
    if custom_decimal_places != -1:
        return custom_decimal_places
    return ANESettings.display_decimal_places

func get_snap_float() -> float:
    var snap_float: = 1.0 / pow(10, get_decimal_places())
    #print_debug("snap_float: %s" % snap_float)
    return snap_float

func redisplay_value() -> void:
    text_dirty = false
    update_tooltip_text()
    if is_int:
        text = str(int(value))
        return

    var rounded_val: = snappedf(value, get_snap_float())
    if is_equal_approx(rounded_val, int(rounded_val)):
        text = str(int(rounded_val))
    else:
        text = str(rounded_val)
