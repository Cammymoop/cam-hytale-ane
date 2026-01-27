extends Node

var base_theme: Theme = preload("res://ui/main_theme.tres")
var base_theme_base_color: Color

@export var theme_colors: Dictionary[String, Color] = {
    "green": Color(0.147, 0.474, 0.242),
}

var color_variants: Dictionary = {
    "green": base_theme,
}

func _ready() -> void:
    base_theme_base_color = base_theme.get_stylebox("normal", "LineEdit").bg_color
    theme_colors.green = base_theme_base_color
    _make_all_theme_color_variants()

func get_theme_color_variant(color_name: String) -> Theme:
    if color_name not in theme_colors:
        print_debug("Color variant %s not found" % color_name)
    return color_variants[color_name]

func _make_all_theme_color_variants() -> void:
    for color_name in theme_colors:
        if color_name not in color_variants:
            _make_theme_color_variant(color_name, theme_colors[color_name])

func _make_theme_color_variant(color_name: String, color_color: Color) -> void:
    theme_colors[color_name] = color_color
    var new_theme: Theme = base_theme.duplicate()
    
    var base_theme_base_color_l: float = base_theme_base_color.ok_hsl_l
    var base_theme_base_color_s: float = base_theme_base_color.ok_hsl_s
    var new_h: float = color_color.ok_hsl_h
    var new_s: float = color_color.ok_hsl_s
    var new_l: float = color_color.ok_hsl_l
    
    var make_colored_duplicate_sb_flat: = func(sb_name: String, sb_class: String, do_bg_col: bool = true, do_border_col: bool = false) -> void:
        var colored_sb: StyleBoxFlat = base_theme.get_stylebox(sb_name, sb_class).duplicate()
        if do_bg_col:
            var shade_ratio: float = colored_sb.bg_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.bg_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.bg_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l)
        if do_border_col:
            var shade_ratio: float = colored_sb.border_color.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = colored_sb.border_color.ok_hsl_s / base_theme_base_color_s
            colored_sb.border_color = Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l)
        new_theme.set_stylebox(sb_name, sb_class, colored_sb)
    
    var make_recolors: = func(color_names: Array[String], theme_class: String) -> void:
        for col_name in color_names:
            var base_theme_version: Color = base_theme.get_color(col_name, theme_class)
            var shade_ratio: float = base_theme_version.ok_hsl_l / base_theme_base_color_l
            var sat_ratio: float = base_theme_version.ok_hsl_s / base_theme_base_color_s
            new_theme.set_color(col_name, theme_class, Color.from_ok_hsl(new_h, sat_ratio * new_s, shade_ratio * new_l))
    
    make_colored_duplicate_sb_flat.call("panel", "GraphNode", true)
    make_colored_duplicate_sb_flat.call("panel_selected", "GraphNode", true, true)
    make_colored_duplicate_sb_flat.call("titlebar", "GraphNode", true)
    make_colored_duplicate_sb_flat.call("titlebar_selected", "GraphNode", true, true)
    
    for btn_class in ["Button", "ButtonOptLeft", "ButtonOptRight"]:
        make_colored_duplicate_sb_flat.call("normal", btn_class, true, true)
        make_colored_duplicate_sb_flat.call("hover", btn_class, true, true)
        make_colored_duplicate_sb_flat.call("pressed", btn_class, true, true)
        make_recolors.call(["font_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"], btn_class)
    
    make_recolors.call(["checkbox_checked_color", "checkbox_unchecked_color"], "CheckBox")
    
    make_colored_duplicate_sb_flat.call("normal", "LineEdit", true)
    make_colored_duplicate_sb_flat.call("read_only", "LineEdit", true)
