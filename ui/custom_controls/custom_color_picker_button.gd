extends ColorPickerButton

static var has_updated_stylebox: = false

@export var name_padding: = 16

var default_color: = Color.WHITE
@onready var name_label: Label = find_child("Label")

var context_menu: PopupMenu = null

func _ready() -> void:
    picker_created.connect(setup_picker)
    color_changed.connect(on_color_changed)
    set_color_name(name_label.text)
    on_color_changed(color)

func set_color_name(new_name: String) -> void:
    if not is_inside_tree():
        await ready
    custom_minimum_size.x = 0
    name_label.text = new_name
    await get_tree().process_frame
    custom_minimum_size.x = name_label.size.x + name_padding

func on_color_changed(new_color: Color) -> void:
    if new_color.ok_hsl_l < 0.54:
        name_label.add_theme_color_override("font_color", Color.WHITE)
    else:
        name_label.add_theme_color_override("font_color", Color.BLACK)

func setup_picker() -> void:
    var picker: = get_picker()
    picker.presets_visible = false
    picker.deferred_mode = true
    
    if not has_updated_stylebox:
        has_updated_stylebox = true
        var popup_panel: = get_popup()
        var popup_panel_stylebox: = popup_panel.get_theme_stylebox("panel") as StyleBoxFlat
        popup_panel_stylebox.bg_color = Color.WHITE

func _gui_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT:
        return
    if not event.is_pressed():
        open_context_menu()

func open_context_menu() -> void:
    if not context_menu:
        context_menu = PopupMenu.new()
        context_menu.name = "ColorPickerRightClickMenu"
        context_menu.index_pressed.connect(reset_to_default.unbind(1))
        add_child(context_menu, true)
    context_menu.clear()
    context_menu.add_item("Reset to Default")
    if not name_label.text in ThemeColorVariants.theme_colors:
        context_menu.add_item("Remove Color")
    context_menu.position = Util.get_popup_window_pos(get_global_mouse_position())
    context_menu.popup()

func on_context_menu_index_pressed(idx: int) -> void:
    if idx == 0:
        reset_to_default()
    else:
        get_parent().remove_color_name(name_label.text)

func reset_to_default() -> void:
    color = default_color
    color_changed.emit(color)
