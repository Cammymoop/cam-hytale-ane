extends Node

signal after_loaded
signal after_saved

var loaded_file_has_no_positions: = false

var cur_file_name: = ""
var cur_file_path: = ""
var has_saved_to_cur_file: = false

var has_unsaved_changes: = false

var file_history_version: int = 0

func has_cur_file() -> bool:
    return cur_file_name != ""

func editing_new_file() -> void:
    cur_file_name = ""
    cur_file_path = FileDialogHandler.last_file_dialog_directory
    has_saved_to_cur_file = false
    has_unsaved_changes = false

func get_cur_file_directory() -> String:
    if not has_cur_file():
        return ""
    return cur_file_path

func get_cur_file_name() -> String:
    return cur_file_name

func get_cur_file_full_path() -> String:
    if not has_cur_file():
        return ""
    return cur_file_path + "/" + cur_file_name

func resave_current_file(file_data: String) -> void:
    _normal_save(file_data, cur_file_path + "/" + cur_file_name)

func save_to_json_file(file_data: String, file_path: String) -> void:
    cur_file_name = file_path.get_file()
    cur_file_path = file_path.get_base_dir()
    _normal_save(file_data, file_path)

func _normal_save(file_data: String, file_path: String) -> void:
    if not file_data:
        GlobalToaster.show_toast_message("Error creating json file")
        return
    var file: = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("Error opening JSON file for writing: %s" % file_path)
        GlobalToaster.show_toast_message("Could not save to chosen file path")
        return
    _save_to_json_file(file_data, file_path)
    has_saved_to_cur_file = true
    GlobalToaster.show_toast_message("Saved")
    has_unsaved_changes = false
    after_saved.emit()

func _save_to_json_file(file_data: String, file_path: String) -> void:
    var file: = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        return
    file.store_string(file_data)
    file.close()

func load_json_file(json_file_path: String, loaded_callback: Callable) -> void:
    _normal_load(json_file_path, loaded_callback)

func get_file_data(json_file_path: String) -> Dictionary:
    return _load_from_json_file(json_file_path, Callable())

func _normal_load(json_file_path: String, loaded_callback: Callable) -> void:
    FileDialogHandler.last_file_dialog_directory = json_file_path.get_base_dir()
    cur_file_name = json_file_path.get_file()
    cur_file_path = json_file_path.get_base_dir()
    has_saved_to_cur_file = false
    var file = FileAccess.open(json_file_path, FileAccess.READ)
    if not file:
        push_error("Error opening JSON file %s" % json_file_path)
        GlobalToaster.show_toast_message("Could not load file")
        return
    _load_from_json_file(json_file_path, loaded_callback)
    after_loaded.emit()
    has_unsaved_changes = false

func _load_from_json_file(json_file_path: String, loaded_callback: Callable) -> Dictionary:
    var file = FileAccess.open(json_file_path, FileAccess.READ)
    if not file:
        push_error("Error opening JSON file %s" % json_file_path)
        return {}
    var parsed_json_data: Variant = JSON.parse_string(file.get_as_text())
    if not parsed_json_data:
        push_error("Error parsing JSON")
        return {}
    if not typeof(parsed_json_data) == TYPE_DICTIONARY:
        push_error("JSON data is not a dictionary")
        return {}
    if loaded_callback.is_valid():
        loaded_callback.call(parsed_json_data)
    return parsed_json_data as Dictionary