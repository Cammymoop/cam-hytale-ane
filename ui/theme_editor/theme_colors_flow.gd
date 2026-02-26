extends HFlowContainer

signal color_changed

const TypeColorsFlow = preload("res://ui/theme_editor/type_colors_flow.gd")

var theme_color_picker_button_scn: PackedScene = preload("res://ui/theme_editor/theme_color_picker_button.tscn")

@export var type_colors_flow: TypeColorsFlow

var add_color_btn: Button = null
var add_color_popup: PopupPanel = null

func _ready() -> void:
    add_color_btn = $AddColorBtn
    add_color_btn.pressed.connect(add_color_button_pressed)
    add_color_popup = add_color_btn.get_child(0) as PopupPanel
    add_color_popup.exclusive = true
    assert(add_color_popup != null, "Add color popup not found")

    var add_color_line_edit: LineEdit = add_color_popup.find_child("LineEdit")
    add_color_line_edit.text_submitted.connect(add_color_name)
    add_color_line_edit.text_submitted.connect(add_color_popup.hide.unbind(1))

    var add_color_popup_button: Button = add_color_popup.find_child("Button")
    add_color_popup_button.pressed.connect(add_color_add_button_pressed)
    add_color_popup_button.pressed.connect(add_color_popup.hide)
    
    add_color_popup.about_to_popup.connect(add_color_line_edit.set.bind("text", ""))
    add_color_popup.about_to_popup.connect(add_color_line_edit.grab_focus)
    
    setup()

func setup() -> void:
    make_color_picker_buttons()

func make_color_picker_buttons() -> void:
    clear_children()
    for color_name in ThemeColorVariants.get_theme_colors():
        var color_picker_button: ColorPickerButton = theme_color_picker_button_scn.instantiate()
        color_picker_button.name = "Btn_%s" % color_name
        color_picker_button.color = ThemeColorVariants.get_theme_color(color_name)
        if not ThemeColorVariants.theme_colors.has(color_name):
            color_picker_button.default_color = ThemeColorVariants.theme_colors[TypeColors.fallback_color]
        else:
            color_picker_button.default_color = ThemeColorVariants.get_default_color(color_name)
        color_picker_button.set_color_name(color_name)
        color_picker_button.color_changed.connect(theme_color_changed.bind(color_name))
        add_child(color_picker_button, true)
    move_child(add_color_btn, get_child_count() - 1)

func theme_color_changed(new_color: Color, color_name: String) -> void:
    ThemeColorVariants.add_custom_theme_color(color_name, new_color)
    type_colors_flow.color_name_color_changed(color_name)
    color_changed.emit()

func clear_children() -> void:
    for child in get_children():
        if not child is ColorPickerButton:
            continue
        remove_child(child)
        child.queue_free()

func add_color_button_pressed() -> void:
    add_color_popup.popup_centered()

func add_color_add_button_pressed() -> void:
    var color_name: String = add_color_popup.find_child("LineEdit").text
    add_color_name(color_name)

func add_color_name(color_name: String) -> void:
    if ThemeColorVariants.has_theme_color(color_name):
        return
    ThemeColorVariants.add_custom_theme_color(color_name, ThemeColorVariants.theme_colors[TypeColors.fallback_color])
    await get_tree().process_frame
    make_color_picker_buttons()

func remove_color_name(color_name: String) -> void:
    ThemeColorVariants.remove_custom_theme_color(color_name)
    make_color_picker_buttons()