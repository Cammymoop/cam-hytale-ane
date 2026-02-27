extends MenuButton

var display_scales: Array[Dictionary] = [
    {"scale": 0.5, "text": "50%"},
    {"scale": 0.75, "text": "75%"},
    {"scale": 1.0, "text": "100%"},
    {"scale": 1.25, "text": "125%"},
    {"scale": 1.50, "text": "150%"},
    {"scale": 1.75, "text": "175%"},
    {"scale": 2.0, "text": "200%"},
]

var display_scale_submenu: PopupMenu = null
var default_group_color_submenu: PopupMenu = null

var titlebar_doubleclick_is_greedy_idx: int = -1

var default_group_color_menu_idx: int = -1
var reset_group_size_idx: int = -1
var toggle_default_group_shrinkwrap_idx: int = -1

func _ready() -> void:
    var popup_menu: = get_popup()
    popup_menu.index_pressed.connect(on_settings_menu_index_pressed)
    about_to_popup.connect(on_about_to_popup)
    
    titlebar_doubleclick_is_greedy_idx = popup_menu.item_count
    popup_menu.add_check_item("Doubleclick to Select Subtree is Greedy", titlebar_doubleclick_is_greedy_idx)
    
    setup_display_scale_submenu()
    setup_group_settings_items()

func on_settings_menu_index_pressed(index: int) -> void:
    if index == titlebar_doubleclick_is_greedy_idx:
        ANESettings.set_subtree_greedy_mode(not ANESettings.select_subtree_is_greedy)
    elif index == reset_group_size_idx:
        ANESettings.reset_default_group_size()
    elif index == toggle_default_group_shrinkwrap_idx:
        ANESettings.set_default_is_group_shrinkwrap(not ANESettings.default_is_group_shrinkwrap)

func on_about_to_popup() -> void:
    update_group_options()
    
func setup_display_scale_submenu() -> void:
    var popup_menu: = get_popup()
    display_scale_submenu = PopupMenu.new()
    display_scale_submenu.name = "DisplayScaleSubmenu"
    var cur_display_scale_idx: = get_cur_display_scale_idx()

    for idx in display_scales.size():
        display_scale_submenu.add_radio_check_item(display_scales[idx]["text"], idx == cur_display_scale_idx)
    if ANESettings.can_detect_display_scale():
        var auto_idx: = display_scales.size()
        var detected_scale_text: = "100%"
        for disp_scale in display_scales:
            if is_equal_approx(disp_scale["scale"], snappedf(ANESettings.detected_display_scale, 0.25)):
                detected_scale_text = disp_scale["text"]
                break
        display_scale_submenu.add_separator()
        display_scale_submenu.add_radio_check_item("Auto (%s)" % detected_scale_text, auto_idx == cur_display_scale_idx)

    display_scale_submenu.index_pressed.connect(on_display_scale_submenu_index_pressed)
    display_scale_submenu.about_to_popup.connect(update_cur_display_scale_selected)
    popup_menu.add_submenu_node_item("Display Scale", display_scale_submenu)

func update_cur_display_scale_selected() -> void:
    var cur_display_scale_idx: = get_cur_display_scale_idx()
    for idx in display_scale_submenu.get_item_count():
        display_scale_submenu.set_item_checked(idx, idx == cur_display_scale_idx)

func get_cur_display_scale_idx() -> int:
    if not ANESettings.has_custom_display_scale():
        return display_scales.size() + 1
    var cur_display_scale: = snappedf(get_window().content_scale_factor, 0.25)
    for i in range(display_scales.size()):
        if is_equal_approx(display_scales[i]["scale"], cur_display_scale):
            return i

    return 2 # default 100%

func on_display_scale_submenu_index_pressed(index: int) -> void:
    if index == display_scales.size() + 1:
        ANESettings.set_custom_display_scale(-1)
        return
    var display_scale: = display_scales[index]
    update_cur_display_scale_selected()
    ANESettings.set_custom_display_scale(display_scale["scale"])


func setup_group_settings_items() -> void:
    var popup_menu: = get_popup()

    popup_menu.add_separator("Group Settings")
    default_group_color_submenu = PopupMenu.new()
    default_group_color_submenu.name = "DefaultGroupColorSubmenu"
    default_group_color_submenu.index_pressed.connect(on_default_group_color_submenu_index_pressed)
    default_group_color_submenu.about_to_popup.connect(update_group_color_options)

    default_group_color_menu_idx = popup_menu.item_count
    var item_text: = "Default Group Color"
    popup_menu.add_submenu_node_item(item_text, default_group_color_submenu)
    
    toggle_default_group_shrinkwrap_idx = popup_menu.item_count
    popup_menu.add_check_item("Shrinkwrap New Groups By Default", toggle_default_group_shrinkwrap_idx)
    popup_menu.set_item_checked(toggle_default_group_shrinkwrap_idx, ANESettings.default_is_group_shrinkwrap)
    
    reset_group_size_idx = popup_menu.item_count
    popup_menu.add_item("Reset New Group Default Size", reset_group_size_idx)
    

func _get_color_icon(color_name: String) -> Texture2D:
    return Util.get_icon_for_color(ThemeColorVariants.get_theme_color(color_name))

func update_group_options() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_checked(toggle_default_group_shrinkwrap_idx, ANESettings.default_is_group_shrinkwrap)
    update_group_color_main_option()

func update_group_color_main_option() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_icon(default_group_color_menu_idx, _get_color_icon(ANESettings.default_group_color))

func update_group_color_options() -> void:
    default_group_color_submenu.clear()
    for color_name in ThemeColorVariants.get_theme_colors():
        var color_idx: = default_group_color_submenu.item_count
        default_group_color_submenu.add_icon_item(_get_color_icon(color_name), color_name)
        default_group_color_submenu.set_item_as_radio_checkable(color_idx, true)
        if color_name == ANESettings.default_group_color:
            default_group_color_submenu.set_item_checked(color_idx, true)

func on_default_group_color_submenu_index_pressed(index: int) -> void:
    var color_name: String = default_group_color_submenu.get_item_text(index)
    if not ThemeColorVariants.has_theme_color(color_name):
        return
    ANESettings.set_default_group_color(color_name)
    update_group_color_main_option()