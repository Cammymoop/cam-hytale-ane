extends PanelContainer

signal closing

@export var theme_colors_flow: Control
@export var type_colors_flow: Control

func _ready() -> void:
    theme_colors_flow.color_changed.connect(update_theme)
    type_colors_flow.type_color_changed.connect(update_theme)
    visibility_changed.connect(on_visibility_changed)

func on_visibility_changed() -> void:
    if visible:
        reset_theme_editor()

func reset_theme_editor() -> void:
    theme_colors_flow.setup()
    type_colors_flow.setup()

func update_theme() -> void:
    ThemeColorVariants.recreate_variants()
    update_graph_edit_theme()

func update_graph_edit_theme() -> void:
    var graph_edit: CHANE_AssetNodeGraphEdit = get_tree().current_scene.find_child("ANGraphEdit")
    graph_edit.update_all_ges_themes()

func on_save_custom_theme() -> void:
    TypeColors.save_custom_theme(GlobalToaster.show_toast_message)
    update_theme()

func on_load_custom_theme() -> void:
    TypeColors.load_custom_theme(GlobalToaster.show_toast_message)
    reset_theme_editor()
    update_theme()

func on_reset_theme_to_default() -> void:
    TypeColors.reset_theme_to_default(GlobalToaster.show_toast_message)
    reset_theme_editor()
    update_theme()

func on_close_button_pressed() -> void:
    update_theme()
    closing.emit()
