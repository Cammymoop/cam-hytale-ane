extends PanelContainer

const ThemeColorsFlow = preload("./theme_colors_flow.gd")
const TypeColorsFlow = preload("./type_colors_flow.gd")

signal closing

@export var theme_colors_flow: ThemeColorsFlow
@export var type_colors_flow: TypeColorsFlow

var custom_theme_has_changes: = false

func _ready() -> void:
    theme_colors_flow.color_changed.connect(update_theme)
    type_colors_flow.type_color_changed.connect(update_theme)
    visibility_changed.connect(on_visibility_changed)

func _shortcut_input(event: InputEvent) -> void:
    if not visible:
        return
    if Input.is_action_just_pressed_by_event("ui_redo", event, true):
        accept_event()
        GlobalToaster.show_toast_message("Can't Undo Theme Changes")
    if Input.is_action_just_pressed_by_event("ui_undo", event, true):
        accept_event()
        GlobalToaster.show_toast_message("Can't Undo Theme Changes")

func on_visibility_changed() -> void:
    if is_visible_in_tree():
        reset_theme_editor()

func reset_theme_editor() -> void:
    theme_colors_flow.setup()
    type_colors_flow.setup()

func update_theme() -> void:
    ThemeColorVariants.recreate_variants()
    update_graph_element_themes()

func update_graph_element_themes() -> void:
    var editor: = get_tree().current_scene as CHANE_AssetNodeEditor
    if not editor:
        push_warning("Theme editor: Editor not found, cannot refresh theme")
    editor.update_all_ges_themes()

func on_save_custom_theme() -> void:
    TypeColors.save_custom_theme(true)
    update_theme()

func on_load_custom_theme() -> void:
    TypeColors.load_custom_theme(true)
    update_theme()
    reset_theme_editor()

func on_reset_theme_to_default() -> void:
    TypeColors.reset_theme_to_default(true)
    update_theme()
    reset_theme_editor()

func on_close_button_pressed() -> void:
    update_theme()
    closing.emit()