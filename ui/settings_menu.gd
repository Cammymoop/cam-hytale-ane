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

func _ready() -> void:
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
