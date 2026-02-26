@tool
extends Range
class_name CustomSpinBox

const SPIN_LEFT_ICON: = preload("res://ui/assets/spin_left_icon.tres")
const SPIN_RIGHT_ICON: = preload("res://ui/assets/spin_right_icon.tres")

var hbox: HBoxContainer
var input_box: GNNumberEdit

var left_button: Button
var right_button: Button

func _init() -> void:
    input_box = GNNumberEdit.new()
    input_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
    input_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    input_box.expand_to_text_length = true
    input_box.add_theme_constant_override("minimum_character_width", 1)
    input_box.val_changed.connect(on_number_edit_changed)
    add_child(input_box, false, INTERNAL_MODE_FRONT)

    hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 10)
    hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hbox, false, INTERNAL_MODE_FRONT)
    
    left_button = Button.new()
    left_button.theme_type_variation = "ButtonSpinLeft"
    left_button.flat = true
    left_button.icon = SPIN_LEFT_ICON
    left_button.pressed.connect(on_spin_pressed.bind(-1))
    hbox.add_child(left_button)
    
    var spacer: Control = Control.new()
    spacer.size_flags_horizontal = SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(spacer)
    
    right_button = Button.new()
    right_button.theme_type_variation = "ButtonSpinRight"
    right_button.flat = true
    right_button.icon = SPIN_RIGHT_ICON
    right_button.pressed.connect(on_spin_pressed.bind(1))
    hbox.add_child(right_button)
    
    value_changed.connect(_update.unbind(1))

func _ready() -> void:
    _update()

func set_value_directly(new_value: float) -> void:
    set_value_no_signal(new_value)
    _update()

func on_number_edit_changed(new_value: float) -> void:
    set_value_directly(new_value)
    _update()

func _update() -> void: 
    update_button_states()
    update_input_box_val()

func update_button_states() -> void:
    left_button.disabled = value <= min_value
    right_button.disabled = value >= max_value

func update_input_box_val() -> void:
    if step == 1:
        input_box.text = str(int(value))
    else:
        input_box.text = str(value)

func _get_minimum_size() -> Vector2:
    var input_box_min_size: = input_box.get_minimum_size()
    var button_min_width: = left_button.get_minimum_size().x
    return Vector2(input_box_min_size.x + button_min_width * 2, input_box_min_size.y)

func on_spin_pressed(direction: int) -> void:
    value = clampf(value + direction * step, min_value, max_value)