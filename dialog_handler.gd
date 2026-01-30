extends Node
class_name DialogHandler

signal requested_open_file(path: String)
signal requested_save_file(path: String)

var last_open_from_directory: String = ""

var cur_open_file_dialog: FileDialog = null
var cur_save_file_dialog: FileDialog = null

const LAST_DIR_CACHE_FILE: String = "user://.last_dir"

func _ready() -> void:
    load_last_directory()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("open_file_shortcut"):
        show_open_file_dialog()
    if Input.is_action_just_pressed("save_file_shortcut"):
        show_save_file_dialog()

func show_open_file_dialog() -> void:
    remove_old_open_dialog()
    var file_dialog: FileDialog = FileDialog.new()
    #file_dialog.use_native_dialog = true
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    if last_open_from_directory:
        file_dialog.current_dir = last_open_from_directory
    else:
        file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
        print("Current directory: %s (%s)" % [file_dialog.current_dir, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)])
    file_dialog.filters = ["*.json"]
    
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    
    file_dialog.canceled.connect(on_open_dialog_closed)
    file_dialog.file_selected.connect(on_file_selected)
    
    print("Showing open file dialog")
    
    add_child(file_dialog, true)
    cur_open_file_dialog = file_dialog
    file_dialog.popup_file_dialog()

func on_file_selected(path: String) -> void:
    print("File open location selected: %s" % path)
    last_open_from_directory = path.get_base_dir()
    on_open_dialog_closed()
    requested_open_file.emit(path)
    
    save_last_directory()
    
    remove_old_open_dialog()

func on_open_dialog_closed() -> void:
    remove_old_open_dialog()

func remove_old_open_dialog() -> void:
    if cur_open_file_dialog:
        cur_open_file_dialog.queue_free()
    cur_open_file_dialog = null


func show_save_file_dialog() -> void:
    remove_old_save_dialog()
    var file_dialog: FileDialog = FileDialog.new()
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    #file_dialog.use_native_dialog = true
    if last_open_from_directory:
        file_dialog.current_dir = last_open_from_directory
    else:
        file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

    file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    file_dialog.add_filter("*.json", "JSON files")
    file_dialog.canceled.connect(on_save_dialog_closed)
    file_dialog.file_selected.connect(on_file_save_location_selected)
    
    add_child(file_dialog, true)
    cur_save_file_dialog = file_dialog
    file_dialog.popup_file_dialog()

func remove_old_save_dialog() -> void:
    if cur_save_file_dialog:
        cur_save_file_dialog.queue_free()
    cur_save_file_dialog = null

func on_save_dialog_closed() -> void:
    remove_old_save_dialog()

func on_file_save_location_selected(path: String) -> void:
    last_open_from_directory = path.get_base_dir()
    on_save_dialog_closed()
    requested_save_file.emit(path)
    
    save_last_directory()

    remove_old_save_dialog()


func save_last_directory() -> void:
    var file: = FileAccess.open(LAST_DIR_CACHE_FILE, FileAccess.WRITE)
    if not file:
        print_debug("Error opening last directory cache file for writing: %s" % LAST_DIR_CACHE_FILE)
        return
    file.store_string(last_open_from_directory)
    file.close()

func load_last_directory() -> void:
    if not FileAccess.file_exists(LAST_DIR_CACHE_FILE):
        return
    var file: = FileAccess.open(LAST_DIR_CACHE_FILE, FileAccess.READ)
    if not file:
        return
    last_open_from_directory = file.get_as_text().strip_edges()
    print_debug("Loaded last directory from cache: %s" % last_open_from_directory)
    file.close()