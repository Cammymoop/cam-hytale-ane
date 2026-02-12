extends PanelContainer

signal closing

@onready var prompt: Label = find_child("Prompt")

@onready var save_btn: Button = find_child("SaveBtn")
@onready var save_spacer: Control = find_child("SaveSpacer")
@onready var save_as_btn: Button = find_child("SaveAsBtn")

var after_save_callback: Callable = Callable()

func _ready() -> void:
    visibility_changed.connect(on_visibility_changed)

func on_visibility_changed() -> void:
    if not visible:
        after_save_callback = Callable()
        prompt.text = ""

func set_can_save_to_cur_filename(can_save: bool) -> void:
    save_btn.visible = can_save
    save_spacer.visible = can_save
    save_as_btn.text = "Save As ..." if can_save else "Save"

func set_prompt_text(prompt_text: String) -> void:
    prompt.text = prompt_text

func set_after_save_callback(new_callback: Callable) -> void:
    if new_callback.is_valid():
        after_save_callback = new_callback
    else:
        after_save_callback = Callable()

func on_cancel() -> void:
    after_save_callback = Callable()
    closing.emit()

func on_ignore_save_chosen() -> void:
    if after_save_callback.is_valid():
        after_save_callback.call()
    after_save_callback = Callable()
    closing.emit()

func show_save_dialog(save_as_current: bool) -> void:
    var editor: = get_tree().current_scene as CHANE_AssetNodeEditor
    assert(editor, "AssetNodeEditor not found")
    var use_directory: = ""
    var use_file_name: = ""
    if save_as_current:
        if editor:
            use_file_name = editor.file_helper.cur_file_name
            use_directory = editor.file_helper.cur_file_directory
    FileDialogHandler.show_save_file_dialog(use_file_name, use_directory)
    if not FileDialogHandler.requested_save_file.is_connected(current_was_saved):
        FileDialogHandler.requested_save_file.connect(current_was_saved.unbind(1).bind(editor), CONNECT_ONE_SHOT)

func current_was_saved(editor: CHANE_AssetNodeEditor) -> void:
    await editor.file_helper.after_saved
    if after_save_callback.is_valid():
        after_save_callback.call()
    after_save_callback = Callable()
    closing.emit()
