extends LineEdit
class_name CustomLineEdit

var base_theme_type_variation: = "LineEdit"

func _init() -> void:
    caret_blink = true
    editing_toggled.connect(on_editing_toggled)

func set_base_theme_type(new_base_theme_type: String) -> void:
    base_theme_type_variation = new_base_theme_type
    if not is_editing:
        theme_type_variation = base_theme_type_variation

func _ready() -> void:
    theme_type_variation = base_theme_type_variation

func on_editing_toggled(now_is_editing: bool) -> void:
    if now_is_editing:
        theme_type_variation = "LineEditEditing"
    else:
        theme_type_variation = base_theme_type_variation