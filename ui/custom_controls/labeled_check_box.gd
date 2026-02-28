extends HBoxContainer
class_name LabeledCheckBox

signal toggled(is_pressed: bool)

@export var text: String = "":
    set(value):
        var label: = get_node("Label")
        label.text = value
    get():
        var label: = get_node("Label")
        return label.text

var button_pressed: bool:
    set(value):
        var check_box: = get_node("CheckBox") as CheckBox
        check_box.button_pressed = value
    get():
        var check_box: = get_node("CheckBox") as CheckBox
        return check_box.button_pressed

var disabled: bool:
    set(value):
        var check_box: = get_node("CheckBox") as CheckBox
        check_box.disabled = value
    get():
        var check_box: = get_node("CheckBox") as CheckBox
        return check_box.disabled

func _ready() -> void:
    var check_box: = get_node("CheckBox") as CheckBox
    check_box.toggled.connect(on_check_box_toggled)
    update_label_theme_type_variation()

func update_label_theme_type_variation() -> void:
    var label: = get_node("Label") as Label
    var check_box: = get_node("CheckBox") as CheckBox
    label.theme_type_variation = "LabelCheckboxChecked" if check_box.button_pressed else "LabelCheckboxUnchecked"

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var check_box: = get_node("CheckBox") as CheckBox
        set_pressed(not check_box.button_pressed)

func on_check_box_toggled(is_pressed: bool) -> void:
    update_label_theme_type_variation()
    toggled.emit(is_pressed)

func set_pressed(is_pressed: bool) -> void:
    var check_box: = get_node("CheckBox") as CheckBox
    check_box.set_pressed(is_pressed)

func set_pressed_no_signal(is_pressed: bool) -> void:
    var check_box: = get_node("CheckBox") as CheckBox
    check_box.set_pressed_no_signal(is_pressed)