extends Control
class_name PopupMenuRoot

@export var focus_stop: Control
@export var non_focus_stop: Control
@export var new_gn_menu: Control
@export var theme_editor_menu: Control
@export var save_confirm: Control
@export var new_file_type_chooser: Control

func _ready() -> void:
    save_confirm.closing.connect(hide_all_menus)
    new_file_type_chooser.closing.connect(hide_all_menus)
    hide_all_menus()

func show_theme_editor() -> void:
    hide_all_menus()
    focus_stop.show()
    theme_editor_menu.show()

func show_save_confirm(prompt_text: String, can_save_to_cur: bool, after_save_callback: Callable) -> void:
    hide_all_menus()
    focus_stop.show()

    save_confirm.set_can_save_to_cur_filename(can_save_to_cur)
    save_confirm.set_prompt_text(prompt_text)
    save_confirm.set_after_save_callback(after_save_callback)
    save_confirm.show()

func show_new_file_type_chooser() -> void:
    hide_all_menus()
    non_focus_stop.show()
    new_file_type_chooser.show()

func show_new_gn_menu() -> void:
    hide_all_menus()
    non_focus_stop.show()
    new_gn_menu.show()

func is_menu_visible() -> bool:
    return focus_stop.visible or non_focus_stop.visible

func hide_all_menus() -> void:
    focus_stop.hide()
    non_focus_stop.hide()
    new_gn_menu.hide()
    theme_editor_menu.hide()
    save_confirm.hide()
    new_file_type_chooser.hide()


func _unhandled_input(event: InputEvent) -> void:
    if not is_menu_visible():
        return
    
    if Input.is_action_just_pressed_by_event("ui_close_dialog", event):
        var focused_window: Window = Window.get_focused_window()
        if get_window() == focused_window:
            hide_all_menus()