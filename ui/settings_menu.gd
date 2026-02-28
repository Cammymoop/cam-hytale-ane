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

var interface_color_submenu: PopupMenu = null
var display_scale_submenu: PopupMenu = null
var default_group_color_submenu: PopupMenu = null

var display_scale_menu_idx: int = -1
var interface_color_menu_idx: int = -1
var customize_theme_colors_idx: int = -1

var titlebar_doubleclick_is_greedy_idx: int = -1

var default_group_color_menu_idx: int = -1
var reset_group_size_idx: int = -1
var toggle_default_group_shrinkwrap_idx: int = -1
var toggle_auto_color_groups_idx: int = -1

var reset_all_settings_idx: int = -1

var special_interface_color_icons: Dictionary[String, Texture2D] = {
    ANESettings.INTERFACE_COLOR_RANDOM: preload("res://ui/assets/color_stripe_icon.svg"),
    ANESettings.INTERFACE_COLOR_CAMMY: preload("res://ui/assets/cammy_birb_tiny.svg"),
    ANESettings.INTERFACE_COLOR_ADAPTIVE: preload("res://ui/assets/adaptive_color_icon.svg"),
}

func _ready() -> void:
    var popup_menu: = get_popup()
    popup_menu.index_pressed.connect(on_settings_menu_index_pressed)
    about_to_popup.connect(on_about_to_popup)

    setup_interface_settings_items()

    popup_menu.add_separator("Node Editor")
    titlebar_doubleclick_is_greedy_idx = popup_menu.item_count
    popup_menu.add_check_item("Doubleclick to Select Subtree is Greedy", titlebar_doubleclick_is_greedy_idx)
    update_dbl_click_greedy_item()
    
    setup_group_settings_items()
    
    popup_menu.add_separator("Reset")
    var reset_all_settings_confirm_menu: = PopupMenu.new()
    reset_all_settings_confirm_menu.add_separator("Are you sure?")
    reset_all_settings_confirm_menu.add_item("Yes")
    reset_all_settings_confirm_menu.name = "ResetAllSettingsConfirmMenu"
    reset_all_settings_confirm_menu.index_pressed.connect(ANESettings.reset_to_default_settings.unbind(1))
    popup_menu.add_submenu_node_item("Reset All Settings", reset_all_settings_confirm_menu)

func update_dbl_click_greedy_item() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_checked(titlebar_doubleclick_is_greedy_idx, ANESettings.select_subtree_is_greedy)

func on_settings_menu_index_pressed(index: int) -> void:
    if index == titlebar_doubleclick_is_greedy_idx:
        ANESettings.set_subtree_greedy_mode(not ANESettings.select_subtree_is_greedy)
    elif index == reset_group_size_idx:
        ANESettings.reset_default_group_size()
    elif index == toggle_default_group_shrinkwrap_idx:
        ANESettings.set_default_is_group_shrinkwrap(not ANESettings.default_is_group_shrinkwrap)
    elif index == toggle_auto_color_groups_idx:
        ANESettings.set_auto_color_imported_nested_groups(not ANESettings.auto_color_imported_nested_groups)
    elif index == reset_all_settings_idx:
        ANESettings.reset_to_default_settings()

func on_about_to_popup() -> void:
    update_group_options()
    update_dbl_click_greedy_item()
    update_interface_color_main_option()
    update_display_scale_main_option()


# Interface Settings
    
# Interface Color
func setup_interface_settings_items() -> void:
    var popup_menu: = get_popup()
    popup_menu.add_separator("Interface")
    
    setup_display_scale_submenu()

    interface_color_menu_idx = popup_menu.item_count
    interface_color_submenu = PopupMenu.new()
    interface_color_submenu.name = "InterfaceColorSubmenu"
    interface_color_submenu.index_pressed.connect(on_interface_color_submenu_index_pressed)
    interface_color_submenu.about_to_popup.connect(update_interface_color_options)
    popup_menu.add_submenu_node_item("Interface Color", interface_color_submenu)
    update_interface_color_main_option()
    
    # theme editor popup opened by main editor on selected
    customize_theme_colors_idx = popup_menu.item_count
    popup_menu.add_item("Customize Theme Colors", customize_theme_colors_idx)

func on_interface_color_submenu_index_pressed(index: int) -> void:
    var special_color_setting: Variant = interface_color_submenu.get_item_metadata(index)
    var color_setting: String = special_color_setting if special_color_setting else interface_color_submenu.get_item_text(index)
    prints("special color", special_color_setting, "color setting", color_setting)
    ANESettings.set_interface_color(color_setting)
    update_interface_color_main_option()

func update_interface_color_options() -> void:
    interface_color_submenu.clear()
    for special_color_setting in ANESettings.SPECIAL_INTERFACE_COLOR_SETTINGS.keys():
        var item_text: = ANESettings.SPECIAL_INTERFACE_COLOR_SETTINGS[special_color_setting]
        var item_idx: = interface_color_submenu.item_count
        interface_color_submenu.add_icon_item(_get_interface_color_icon(special_color_setting), item_text)
        interface_color_submenu.set_item_as_radio_checkable(item_idx, true)
        interface_color_submenu.set_item_checked(item_idx, special_color_setting == ANESettings.interface_color_setting)
        interface_color_submenu.set_item_metadata(item_idx, special_color_setting)
    interface_color_submenu.add_separator()
    _set_color_menu_options(interface_color_submenu, ANESettings.interface_color_setting)

func update_interface_color_main_option() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_icon(interface_color_menu_idx, _get_interface_color_icon(ANESettings.interface_color_setting))

func _get_interface_color_icon(interface_color_setting: String) -> Texture2D:
    if not ANESettings.is_special_interface_color(interface_color_setting):
        return _get_color_icon(interface_color_setting)
    return special_interface_color_icons[interface_color_setting]

# Display Scale
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
    display_scale_menu_idx = popup_menu.item_count
    popup_menu.add_submenu_node_item("Display Scaling", display_scale_submenu)
    update_display_scale_main_option()

func update_display_scale_main_option() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_text(display_scale_menu_idx, "Display Scaling (%s)" % ANESettings.describe_display_scale())

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


# Group Settings

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
    
    toggle_auto_color_groups_idx = popup_menu.item_count
    popup_menu.add_check_item("Auto Color Nested Groups (file load)", toggle_auto_color_groups_idx)

func update_group_options() -> void:
    var popup_menu: = get_popup()
    popup_menu.set_item_icon(default_group_color_menu_idx, _get_color_icon(ANESettings.default_group_color))
    popup_menu.set_item_checked(toggle_default_group_shrinkwrap_idx, ANESettings.default_is_group_shrinkwrap)
    popup_menu.set_item_checked(toggle_auto_color_groups_idx, ANESettings.auto_color_imported_nested_groups)

func update_group_color_options() -> void:
    default_group_color_submenu.clear()
    _set_color_menu_options(default_group_color_submenu, ANESettings.get_default_group_color())

func on_default_group_color_submenu_index_pressed(index: int) -> void:
    var color_name: String = default_group_color_submenu.get_item_text(index)
    if not ThemeColorVariants.has_theme_color(color_name):
        return
    ANESettings.set_default_group_color(color_name)
    update_group_options()


# Shared Color Picker Menu Stuff

func _get_color_icon(color_name: String) -> Texture2D:
    return Util.get_icon_for_color(ThemeColorVariants.get_theme_color(color_name))

func _set_color_menu_options(the_menu: PopupMenu, cur_color_name: String) -> void:
    for color_name in ThemeColorVariants.get_theme_colors():
        var color_idx: = the_menu.item_count
        the_menu.add_icon_item(_get_color_icon(color_name), color_name)
        the_menu.set_item_as_radio_checkable(color_idx, true)
        if color_name == cur_color_name:
            the_menu.set_item_checked(color_idx, true)