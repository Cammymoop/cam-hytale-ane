extends Node

var base_theme: Theme = preload("res://ui/assets/theme/default/main_theme.tres")
var base_theme_base_color: Color

@export var theme_colors: Dictionary[String, Color] = {
    "grey": Color(0.44, 0.44, 0.44),
    "light-green": Color(0.147, 0.474, 0.242),
}

var custom_theme_colors: Dictionary[String, Color] = {}

var color_variants: Dictionary = {
    "grey": preload("res://ui/assets/theme/default/grey_theme.tres"),
    "light-green": base_theme,
}

var themes_created: = false

func _ready() -> void:
    base_theme_base_color = base_theme.get_stylebox("normal", "LineEdit").bg_color
    theme_colors["light-green"] = base_theme_base_color
    _make_all_theme_color_variants()

func recreate_variants() -> void:
    themes_created = false
    _make_all_theme_color_variants()

func get_theme_color_variant(color_name: String) -> Theme:
    if not has_theme_color(color_name):
        print_debug("Color variant %s not found" % color_name)
        return color_variants[color_variants.keys()[0]]
    return color_variants[color_name]

func get_theme_colors() -> Dictionary[String, Color]:
    var combined_col: Dictionary[String, Color] = theme_colors.duplicate()
    return combined_col.merged(custom_theme_colors, true)

func get_theme_color(color_name: String) -> Color:
    if color_name in custom_theme_colors:
        return custom_theme_colors[color_name]
    return get_default_color(color_name)

func get_default_color(color_name: String) -> Color:
    if color_name in theme_colors:
        return theme_colors[color_name]
    return Color.WHITE

func has_theme_color(color_name: String) -> bool:
    return color_name in custom_theme_colors or color_name in theme_colors

func add_custom_theme_color(color_name: String, color_color: Color) -> void:
    custom_theme_colors[color_name] = color_color

func remove_custom_theme_color(color_name: String) -> void:
    custom_theme_colors.erase(color_name)

func _make_all_theme_color_variants() -> void:
    if themes_created:
        return
    for color_name in theme_colors:
        if color_name not in color_variants:
            _make_theme_color_variant(color_name, theme_colors[color_name])
    themes_created = true

func _make_theme_color_variant(color_name: String, color_color: Color) -> void:
    theme_colors[color_name] = color_color
    var new_theme: Theme = base_theme.duplicate()
    color_variants[color_name] = new_theme
    
    var base_theme_base_color_l: float = base_theme_base_color.ok_hsl_l
    var base_theme_base_color_s: float = base_theme_base_color.ok_hsl_s
    var new_h: float = color_color.ok_hsl_h
    var new_s: float = color_color.ok_hsl_s
    var new_l: float = color_color.ok_hsl_l
    
    var make_colored_duplicate_sb_flat: = func(sb_name: String, sb_class: String, do_bg_col: bool = true, do_border_col: bool = false) -> void:
        var colored_sb: StyleBoxFlat = base_theme.get_stylebox(sb_name, sb_class).duplicate()
        if do_bg_col:
            var bg_alpha: float = colored_sb.bg_color.a
            var shade_ratio: float = colored_sb.bg_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.bg_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.bg_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l, bg_alpha)
        if do_border_col:
            var border_alpha: float = colored_sb.border_color.a
            var shade_ratio: float = colored_sb.border_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.border_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.border_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l, border_alpha)
        new_theme.set_stylebox(sb_name, sb_class, colored_sb)
    
    var make_recolors: = func(color_names: Array, theme_class: String) -> void:
        for col_name in color_names:
            var base_theme_version: Color = base_theme.get_color(col_name, theme_class)
            var alpha: float = base_theme_version.a
            var shade_ratio: float = base_theme_version.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = base_theme_version.ok_hsl_s / base_theme_base_color_s
            new_theme.set_color(col_name, theme_class, Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l, alpha))
    
    make_colored_duplicate_sb_flat.call("panel", "GraphNode", true)
    make_colored_duplicate_sb_flat.call("panel_selected", "GraphNode", true, true)
    make_colored_duplicate_sb_flat.call("titlebar", "GraphNode", true)
    make_colored_duplicate_sb_flat.call("titlebar_selected", "GraphNode", true, true)
    # custom stylebox for tab showing group membership
    make_colored_duplicate_sb_flat.call("group_indicator_tab", "GraphNode", true, true)

    make_colored_duplicate_sb_flat.call("panel", "GraphFrame", true, true)
    make_colored_duplicate_sb_flat.call("panel_selected", "GraphFrame", true, true)
    make_colored_duplicate_sb_flat.call("titlebar", "GraphFrame", true)
    make_colored_duplicate_sb_flat.call("titlebar_selected", "GraphFrame", true, true)
    
    for btn_class in ["Button", "ButtonOptLeft", "ButtonOptRight"]:
        make_colored_duplicate_sb_flat.call("normal", btn_class, true, true)
        make_colored_duplicate_sb_flat.call("hover", btn_class, true, true)
        make_colored_duplicate_sb_flat.call("pressed", btn_class, true, true)
        make_recolors.call(["font_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"], btn_class)
    
    make_recolors.call(["checkbox_checked_color", "checkbox_unchecked_color"], "CheckBox")
    make_recolors.call(["font_color"], "LabelCheckboxChecked")
    make_recolors.call(["font_color"], "LabelCheckboxUnchecked")
    
    make_colored_duplicate_sb_flat.call("normal", "LineEdit", true)
    make_colored_duplicate_sb_flat.call("read_only", "LineEdit", true)
    make_colored_duplicate_sb_flat.call("focus", "LineEdit", false, true)
    
    make_recolors.call(["font_color", "selection_color", "font_uneditable_color", "caret_color"], "LineEdit")
    make_recolors.call(["font_color"], "LineEditEditing")
    

func get_button_styleboxes(with_color: Color) -> Dictionary:
    var styleboxes: Dictionary = {}
    var base_theme_base_color_l: float = base_theme_base_color.ok_hsl_l
    var base_theme_base_color_s: float = base_theme_base_color.ok_hsl_s
    var new_h: float = with_color.ok_hsl_h
    var new_s: float = with_color.ok_hsl_s
    var new_l: float = with_color.ok_hsl_l
    
    var make_colored_duplicate_sb_flat: = func(sb_name: String, sb_class: String, do_bg_col: bool = true, do_border_col: bool = false) -> StyleBoxFlat:
        var colored_sb: StyleBoxFlat = base_theme.get_stylebox(sb_name, sb_class).duplicate()
        if do_bg_col:
            var shade_ratio: float = colored_sb.bg_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.bg_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.bg_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l)
        if do_border_col:
            var shade_ratio: float = colored_sb.border_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.border_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.border_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l)
        return colored_sb
    
    styleboxes["normal"] = make_colored_duplicate_sb_flat.call("normal", "Button", true, true)
    styleboxes["hover"] = make_colored_duplicate_sb_flat.call("hover", "Button", true, true)
    styleboxes["pressed"] = make_colored_duplicate_sb_flat.call("pressed", "Button", true, true)
    
    return styleboxes

func all_color_names() -> Array[String]:
    var color_names: Array[String] = []
    color_names.append_array(theme_colors.keys())
    for color_name in custom_theme_colors:
        if not color_name in color_names:
            color_names.append(color_name)
    return color_names