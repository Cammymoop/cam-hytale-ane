extends Node

signal requested_open_file(path: String)
signal requested_save_file(path: String)

var last_file_dialog_directory: String = ""

const LAST_DIR_CACHE_FILE: String = "user://.last_dir"
const FAVORITES_FILE: String = "user://.favorite_dirs"
const RECENT_DIRS_FILE: String = "user://.recent_dirs"

func _ready() -> void:
    load_file_dialog_recents_cache()

func remove_old_dialogs() -> void:
    for child in get_children():
        if child is FileDialog:
            child.queue_free()

func show_open_file_dialog() -> void:
    remove_old_dialogs()
    var file_dialog: FileDialog = FileDialog.new()
    #file_dialog.use_native_dialog = true
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    if last_file_dialog_directory:
        file_dialog.current_dir = last_file_dialog_directory
    else:
        file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
    file_dialog.filters = ["*.json"]
    
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    
    file_dialog.canceled.connect(on_open_dialog_closed.bind(file_dialog))
    file_dialog.file_selected.connect(on_file_selected.bind(file_dialog))
    
    #print("Showing open file dialog")
    
    add_child(file_dialog, true)
    file_dialog.popup_file_dialog()

func on_file_selected(path: String, file_dialog: FileDialog) -> void:
    #print("File open location selected: %s" % path)
    requested_open_file.emit(path)
    
    save_favorite_and_recent(path)
    file_dialog.queue_free()

func on_open_dialog_closed(file_dialog: FileDialog) -> void:
    save_favorite_and_recent()
    file_dialog.queue_free()


func show_save_file_dialog(use_file_name: String = "", use_directory: String = "") -> void:
    remove_old_dialogs()
    var file_dialog: FileDialog = FileDialog.new()
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    #file_dialog.use_native_dialog = true
    if use_directory:
        file_dialog.current_dir = use_directory
    elif last_file_dialog_directory:
        file_dialog.current_dir = last_file_dialog_directory
    else:
        file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)    

    if use_file_name:
        file_dialog.current_file = use_file_name

    file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    file_dialog.add_filter("*.json", "JSON files")
    file_dialog.canceled.connect(on_save_dialog_closed.bind(file_dialog))
    file_dialog.file_selected.connect(on_file_save_location_selected.bind(file_dialog))
    
    add_child(file_dialog, true)
    file_dialog.popup_file_dialog()

func on_save_dialog_closed(file_dialog: FileDialog) -> void:
    save_favorite_and_recent()
    file_dialog.queue_free()

func on_file_save_location_selected(path: String, file_dialog: FileDialog) -> void:
    requested_save_file.emit(path)
    
    save_favorite_and_recent(path)
    file_dialog.queue_free()


func load_file_dialog_recents_cache() -> void:
    _load_last_directory_cache()
    _load_favorite_cache()
    _load_recent_cache()

func _load_last_directory_cache() -> void:
    if not FileAccess.file_exists(LAST_DIR_CACHE_FILE):
        return
    var file: = FileAccess.open(LAST_DIR_CACHE_FILE, FileAccess.READ)
    if not file:
        return
    last_file_dialog_directory = file.get_as_text().strip_edges()
    #print_debug("Loaded last directory from cache: %s" % last_open_from_directory)
    file.close()

func _load_favorite_cache() -> void:
    if not FileAccess.file_exists(FAVORITES_FILE):
        return
    var fav_file: = FileAccess.open(FAVORITES_FILE, FileAccess.READ)
    if not fav_file:
        push_warning("Error opening favorites file for reading: %s" % FAVORITES_FILE)
        return
    # favorites list is automatically shared across dialogs
    FileDialog.set_favorite_list(fav_file.get_as_text().split("\n", false).slice(0, 100))
    fav_file.close()

func _load_recent_cache() -> void:
    if not FileAccess.file_exists(RECENT_DIRS_FILE):
        return
    var recent_file: = FileAccess.open(RECENT_DIRS_FILE, FileAccess.READ)
    if not recent_file:
        push_warning("Error opening recent directories file for reading: %s" % RECENT_DIRS_FILE)
        return
    # recents list is automatically shared across dialogs
    FileDialog.set_recent_list(recent_file.get_as_text().split("\n", false).slice(0, 100))
    recent_file.close()

func save_last_directory(last_path: String) -> void:
    var file: = FileAccess.open(LAST_DIR_CACHE_FILE, FileAccess.WRITE)
    if not file:
        print_debug("Error opening last directory cache file for writing: %s" % LAST_DIR_CACHE_FILE)
        return
    last_file_dialog_directory = last_path.get_base_dir()
    file.store_string(last_file_dialog_directory)
    file.close()

func save_favorite_and_recent(last_path: String = "") -> void:
    if last_path:
        save_last_directory(last_path)

    var fav_file: = FileAccess.open(FAVORITES_FILE, FileAccess.WRITE)
    if not fav_file:
        print_debug("Error opening favorites file for writing: %s" % FAVORITES_FILE)
    else:
        fav_file.store_string("\n".join(FileDialog.get_favorite_list()))
        fav_file.close()
    
    var recent_file: = FileAccess.open(RECENT_DIRS_FILE, FileAccess.WRITE)
    if not recent_file:
        print_debug("Error opening recent directories file for writing: %s" % RECENT_DIRS_FILE)
    else:
        recent_file.store_string("\n".join(FileDialog.get_recent_list()))
        recent_file.close()