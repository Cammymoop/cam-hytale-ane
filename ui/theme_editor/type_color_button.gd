extends MenuButton

signal type_color_changed

const TypeColorsFlow = preload("res://ui/theme_editor/type_colors_flow.gd")

var type_name: String = ""
var is_setup: = false

var popup_menu: PopupMenu = null

func _ready() -> void:
    flat = false
    popup_menu = get_popup()
    popup_menu.index_pressed.connect(on_color_idx_selected)
    if is_setup:
        update_visuals()
    var parent: = get_parent() as TypeColorsFlow
    parent.colors_changed.connect(update_visuals)
    
    pressed.connect(on_pressed)

func set_type_name(new_type_name: String) -> void:
    type_name = new_type_name
    text = type_name
    if not is_setup:
        is_setup = true
    update_visuals()

func update_visuals() -> void:
    if not is_inside_tree():
        await ready
    var parent: = get_parent() as TypeColorsFlow
    text = type_name
    var color_name: String = TypeColors.get_color_for_type(type_name)
    var styleboxes: Dictionary = parent.get_button_styleboxes(color_name)
    
    add_theme_stylebox_override("normal", styleboxes["normal"])
    add_theme_stylebox_override("hover", styleboxes["hover"])
    add_theme_stylebox_override("pressed", styleboxes["pressed"])
    
func on_pressed() -> void:
    update_color_name_options()

func update_color_name_options() -> void:
    popup_menu.clear()
    for color_name in ThemeColorVariants.get_theme_colors():
        popup_menu.add_icon_item(Util.get_icon_for_color(ThemeColorVariants.get_theme_color(color_name)), color_name)

func reset_to_default() -> void:
    TypeColors.custom_color_names.erase(type_name)
    update_visuals()

func on_color_idx_selected(idx: int) -> void:
    var color_name: String = popup_menu.get_item_text(idx)
    if not color_name in ThemeColorVariants.theme_colors:
        return
    TypeColors.custom_color_names[type_name] = color_name
    update_visuals()
    type_color_changed.emit()
    