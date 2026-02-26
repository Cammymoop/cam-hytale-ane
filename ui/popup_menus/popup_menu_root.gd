extends Control
class_name PopupMenuRoot

signal popup_menu_opened
signal popup_menu_all_closed

@export var focus_stop: Control
@export var non_focus_stop: Control
@export var new_gn_menu: NewGNMenu
@export var theme_editor_menu: Control
@export var save_confirm: Control
@export var new_file_type_chooser: Control

@onready var all_menus: Array[Control] = [
    new_gn_menu,
    theme_editor_menu,
    save_confirm,
    new_file_type_chooser,
]

var new_gn_menu_filter_is_output: bool = true
var new_gn_menu_filter_value_type: String = ""

func _ready() -> void:
    for menu in all_menus:
        if menu.has_signal("closing"):
            menu.closing.connect(close_all)
    hide_all_menus()

func show_theme_editor() -> void:
    hide_all_menus()
    focus_stop.show()
    theme_editor_menu.show()
    after_menu_shown()

func show_save_confirm(prompt_text: String, can_save_to_cur: bool, after_save_callback: Callable) -> void:
    hide_all_menus()
    focus_stop.show()

    save_confirm.set_can_save_to_cur_filename(can_save_to_cur)
    save_confirm.set_prompt_text(prompt_text)
    save_confirm.set_after_save_callback(after_save_callback)
    save_confirm.show()
    after_menu_shown()

func show_new_file_type_chooser() -> void:
    hide_all_menus()
    non_focus_stop.show()
    new_file_type_chooser.show()
    after_menu_shown()

func show_filtered_new_gn_menu(is_filter_output: bool, filter_value_type: String) -> void:
    new_gn_menu_filter_is_output = is_filter_output
    new_gn_menu_filter_value_type = filter_value_type
    show_new_gn_menu(false)

func show_new_gn_menu(unfiltered: bool = true) -> void:
    hide_all_menus()
    non_focus_stop.show()
    if unfiltered:
        new_gn_menu.open_all_menu()
    else:
        new_gn_menu.open_menu(new_gn_menu_filter_is_output, new_gn_menu_filter_value_type)
    after_menu_shown()

func is_menu_visible() -> bool:
    return focus_stop.visible or non_focus_stop.visible

func close_all() -> void:
    hide_all_menus()
    popup_menu_all_closed.emit()

func hide_all_menus() -> void:
    focus_stop.hide()
    non_focus_stop.hide()
    for menu in all_menus:
        menu.hide()

func after_menu_shown() -> void:
    popup_menu_opened.emit()


func _unhandled_input(event: InputEvent) -> void:
    if not is_menu_visible():
        return
    
    if Input.is_action_just_pressed_by_event("ui_close_dialog", event):
        accept_event()
        var focused_window: Window = Window.get_focused_window()
        if get_window() == focused_window:
            close_all()

func _process(_delta: float) -> void:
    if is_menu_visible():
        var submenus_visible: int = 0
        for menu in all_menus:
            if menu.visible:
                submenus_visible += 1
        assert(submenus_visible > 0, "No submenu visible but one of the roots is")