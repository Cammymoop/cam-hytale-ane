extends Node

var settings_file_path: String = "user://CHANE_settings.json"

@export var display_decimal_places: = 5
@export var custom_display_scale: float = -1

var detected_display_scale: float = 1.0

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

func has_custom_display_scale() -> bool:
    return custom_display_scale != -1

func get_current_custom_scale() -> float:
    if custom_display_scale == -1:
        return 1.0
    return custom_display_scale

func get_settings_dict() -> Dictionary:
    return {
        "display_decimal_places": display_decimal_places,
        "custom_display_scale": custom_display_scale,
    }

func update_saved_settings() -> void:
    var file: = FileAccess.open(settings_file_path, FileAccess.WRITE)
    var settings_dict: = get_settings_dict()
    file.store_string(JSON.stringify(settings_dict))
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