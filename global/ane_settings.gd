extends Node

signal group_settings_updated
signal interface_color_changed

var settings_file_path: String = "user://CHANE_settings.json"

const MENU_ICON_SIZE: = 14

const DEFAULT_GROUP_SIZE: Vector2 = Vector2(460, 300)

const INTERFACE_COLOR_ADAPTIVE: String = ":adaptive"
const INTERFACE_COLOR_RANDOM: String = ":random"
const INTERFACE_COLOR_CAMMY: String = ":cammy's-choice"
const SPECIAL_INTERFACE_COLOR_SETTINGS: Dictionary[String, String] = {
    INTERFACE_COLOR_CAMMY: "Cammy's Choice (Default)",
    INTERFACE_COLOR_RANDOM: "Random",
    INTERFACE_COLOR_ADAPTIVE: "Follow Root Node"
}

@export var display_decimal_places: = 3
@export var custom_display_scale: float = -1

@export var interface_color_setting: String = ":cammy's-choice"
@export var cammys_choice_color: String = "blue-purple"
var current_interface_color: String = ""

@export var default_group_color: String = "blue-purple"
@export var default_is_group_shrinkwrap: bool = true
@export var default_group_size: Vector2 = DEFAULT_GROUP_SIZE
@export var auto_color_imported_nested_groups: bool = true

@export var new_node_menu_height_ratio: = 0.85

@export var select_subtree_is_greedy: bool = false

var detected_display_scale: float = 1.0

const GRAPH_NODE_MARGIN_BOTTOM_EXTRA: int = 6


var is_loading_settings: bool = false

var default_settings: Dictionary = {}

func _ready() -> void:
    default_settings = get_settings_dict()
    if can_detect_display_scale():
        detected_display_scale = DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW)
    load_settings()

func describe_display_scale() -> String:
    if custom_display_scale == -1:
        return "Auto"
    return "%d%%" % roundi(custom_display_scale * 100)

func root_node_changed(root_node_theme_color: String, is_new_session: bool) -> void:
    if not is_special_interface_color():
        return
    _set_special_interface_color(root_node_theme_color, is_new_session)

func get_current_interface_color() -> String:
    return current_interface_color

func is_special_interface_color(setting: String = "") -> bool:
    if setting:
        return setting in SPECIAL_INTERFACE_COLOR_SETTINGS.keys()
    else:
        return interface_color_setting in SPECIAL_INTERFACE_COLOR_SETTINGS.keys()

func set_interface_color(new_interface_color_setting: String) -> void:
    interface_color_setting = new_interface_color_setting
    if not is_special_interface_color() and not ThemeColorVariants.has_theme_color(new_interface_color_setting):
        prints("interface color setting %s not found" % new_interface_color_setting)
        interface_color_setting = INTERFACE_COLOR_CAMMY
    update_saved_settings()
    if is_special_interface_color():
        _apply_special_interface_color()
    else:
        _set_interface_cur_color(new_interface_color_setting)

func _apply_special_interface_color() -> void:
    prints("applying special interface color %s" % interface_color_setting)
    var root_node_theme_color: String = ""
    if interface_color_setting == INTERFACE_COLOR_ADAPTIVE:
        root_node_theme_color = (get_tree().current_scene as CHANE_AssetNodeEditor).get_root_theme_color()
    _set_special_interface_color(root_node_theme_color, true)

func _set_special_interface_color(root_node_theme_color: String, is_new_session: bool) -> void:
    if interface_color_setting == INTERFACE_COLOR_ADAPTIVE and root_node_theme_color:
        _set_interface_cur_color(root_node_theme_color)
    elif interface_color_setting == INTERFACE_COLOR_RANDOM and is_new_session:
        _set_random_interface_color()
    elif interface_color_setting == INTERFACE_COLOR_CAMMY:
        _set_interface_cur_color(cammys_choice_color)

func _set_random_interface_color() -> void:
    var all_colors: Array = ThemeColorVariants.get_theme_colors().keys()
    all_colors.erase(get_current_interface_color())
    _set_interface_cur_color(all_colors.pick_random())

func _set_interface_cur_color(color_name: String) -> void:
    prints("setting interface cur color %s" % color_name)
    if current_interface_color == color_name:
        return
    current_interface_color = color_name
    interface_color_changed.emit()

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

func get_default_group_color() -> String:
    if ThemeColorVariants.has_theme_color(default_group_color):
        return default_group_color
    return TypeColors.fallback_color

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

func set_auto_color_imported_nested_groups(new_auto_color: bool) -> void:
    auto_color_imported_nested_groups = new_auto_color
    update_saved_settings()

func get_settings_dict() -> Dictionary:
    return {
        "display_decimal_places": display_decimal_places,
        "custom_display_scale": custom_display_scale,
        
        "interface_color_setting": interface_color_setting,
        
        "default_group_color": default_group_color,
        "default_is_group_shrinkwrap": default_is_group_shrinkwrap,
        "default_group_size": JSON.from_native(default_group_size),
        "auto_color_imported_nested_groups": auto_color_imported_nested_groups,
        
        "new_node_menu_height": new_node_menu_height_ratio,
        
        "select_subtree_is_greedy": select_subtree_is_greedy,
    }

func reset_to_default_settings() -> void:
    update_saved_settings(default_settings)
    load_settings()

func update_saved_settings(settings_dict: Dictionary = {}) -> void:
    if is_loading_settings:
        return
    if not settings_dict:
        settings_dict = get_settings_dict()
    var file: = FileAccess.open(settings_file_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(settings_dict, "\t", false))
    file.close()

func load_settings() -> void:
    is_loading_settings = true
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
    
    if parsed_settings.has("interface_color_setting"):
        set_interface_color(parsed_settings["interface_color_setting"])
        
    if parsed_settings.has("default_group_color"):
        default_group_color = parsed_settings["default_group_color"]
    if parsed_settings.has("default_is_group_shrinkwrap"):
        default_is_group_shrinkwrap = parsed_settings["default_is_group_shrinkwrap"]
    if parsed_settings.has("default_group_size"):
        default_group_size = JSON.to_native(parsed_settings["default_group_size"])
    if parsed_settings.has("auto_color_imported_nested_groups"):
        auto_color_imported_nested_groups = parsed_settings["auto_color_imported_nested_groups"]
    group_settings_updated.emit()
    
    if parsed_settings.has("new_node_menu_height"):
        new_node_menu_height_ratio = parsed_settings["new_node_menu_height"]
    
    if parsed_settings.has("select_subtree_is_greedy"):
        select_subtree_is_greedy = parsed_settings["select_subtree_is_greedy"]

    is_loading_settings = false