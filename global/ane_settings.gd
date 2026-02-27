extends Node

signal group_settings_updated()

var settings_file_path: String = "user://CHANE_settings.json"

const MENU_ICON_SIZE: = 14

const DEFAULT_GROUP_SIZE: Vector2 = Vector2(460, 300)

@export var display_decimal_places: = 3
@export var custom_display_scale: float = -1

@export var default_group_color: String = "blue-purple"
@export var default_is_group_shrinkwrap: bool = true
@export var default_group_size: Vector2 = DEFAULT_GROUP_SIZE
@export var auto_color_imported_nested_groups: bool = true

@export var new_node_menu_height_ratio: = 0.85

@export var select_subtree_is_greedy: bool = false

var detected_display_scale: float = 1.0

const GRAPH_NODE_MARGIN_BOTTOM_EXTRA: int = 6

func _ready() -> void:
    if can_detect_display_scale():
        detected_display_scale = DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW)
    load_settings()

    if custom_display_scale == -1:
        get_window().content_scale_factor = detected_display_scale
    else:
        get_window().content_scale_factor = custom_display_scale

func can_detect_display_scale() -> bool:
    return not OS.has_feature("Windows")

func set_custom_display_scale(new_display_scale: float) -> void:
    _update_display_scale(new_display_scale)
    update_saved_settings()

func _update_display_scale(new_display_scale: float) -> void:
    custom_display_scale = new_display_scale
    if new_display_scale == -1:
        get_window().content_scale_factor = detected_display_scale
    else:
        get_window().content_scale_factor = new_display_scale

func set_subtree_greedy_mode(new_is_greedy: bool) -> void:
    select_subtree_is_greedy = new_is_greedy
    update_saved_settings()

func has_custom_display_scale() -> bool:
    return custom_display_scale != -1

func get_current_custom_scale() -> float:
    if custom_display_scale == -1:
        return 1.0
    return custom_display_scale

func set_default_group_color(new_default_group_color: String) -> void:
    default_group_color = new_default_group_color
    group_settings_updated.emit()
    update_saved_settings()

func set_default_is_group_shrinkwrap(new_default_is_group_shrinkwrap: bool) -> void:
    default_is_group_shrinkwrap = new_default_is_group_shrinkwrap
    group_settings_updated.emit()
    update_saved_settings()

func reset_default_group_size() -> void:
    set_default_group_size(DEFAULT_GROUP_SIZE)

func set_default_group_size(new_default_group_size: Vector2) -> void:
    default_group_size = new_default_group_size
    group_settings_updated.emit()
    update_saved_settings()

func get_settings_dict() -> Dictionary:
    return {
        "display_decimal_places": display_decimal_places,
        "custom_display_scale": custom_display_scale,
        
        "default_group_color": default_group_color,
        "default_is_group_shrinkwrap": default_is_group_shrinkwrap,
        "default_group_size": JSON.from_native(default_group_size),
        "auto_color_imported_nested_groups": auto_color_imported_nested_groups,
        
        "new_node_menu_height": new_node_menu_height_ratio,
        
        "select_subtree_is_greedy": select_subtree_is_greedy,
    }

func update_saved_settings() -> void:
    var file: = FileAccess.open(settings_file_path, FileAccess.WRITE)
    var settings_dict: = get_settings_dict()
    file.store_string(JSON.stringify(settings_dict, "\t", false))
    file.close()

func load_settings() -> void:
    if not FileAccess.file_exists(settings_file_path):
        return
    var file: = FileAccess.open(settings_file_path, FileAccess.READ)
    if not file:
        push_warning("Error opening settings file %s" % settings_file_path)
        return
    var parsed_settings: Variant = JSON.parse_string(file.get_as_text())
    if not parsed_settings:
        push_warning("Error parsing settings file %s" % settings_file_path)
        return
    if not parsed_settings is Dictionary:
        push_warning("Settings file %s is not a dictionary" % settings_file_path)
        return

    if parsed_settings.has("display_decimal_places"):
        display_decimal_places = parsed_settings["display_decimal_places"]
    if parsed_settings.has("custom_display_scale"):
        _update_display_scale(parsed_settings["custom_display_scale"])
        
    if parsed_settings.has("default_group_color"):
        default_group_color = parsed_settings["default_group_color"]
    if parsed_settings.has("default_is_group_shrinkwrap"):
        default_is_group_shrinkwrap = parsed_settings["default_is_group_shrinkwrap"]
    if parsed_settings.has("default_group_size"):
        default_group_size = JSON.to_native(parsed_settings["default_group_size"])
    if parsed_settings.has("auto_color_imported_nested_groups"):
        auto_color_imported_nested_groups = parsed_settings["auto_color_imported_nested_groups"]
    
    if parsed_settings.has("new_node_menu_height"):
        new_node_menu_height_ratio = parsed_settings["new_node_menu_height"]
    
    if parsed_settings.has("select_subtree_is_greedy"):
        select_subtree_is_greedy = parsed_settings["select_subtree_is_greedy"]