@tool
extends Node

const CUSTOM_THEME_FILE_PATH: = "user://color_themes/custom.json"

var fallback_color: String = "grey"

@export var type_colors: Dictionary[String, String] = {
    "Density": "purple",
    "Curve": "orange",
    "CurvePoint": "yellow",
    "Positions": "blue",
    "Material": "yellow-brown",
    "MaterialProvider": "brown",
    "VectorProvider": "blue-green",
    "Terrain": "grey",
    "Pattern": "light-purple",
    "Scanner": "light-blue",
    "BlockMask": "yellow-green",
    "BlockSubset": "light-green",
    "Prop": "green",
    "Assignments": "blue-purple",
    "EnvironmentProvider": "light-orange",
    "TintProvider": "light-orange",
    "PCNReturnType": "red",
    "PCNDistanceFunction": "light-blue-green",
    "Point3D": "yellow",
    "Point3DInt": "yellow",
    "PointGenerator": "light-blue",
    "Stripe": "yellow",
    "WeightedMaterial": "light-orange",
    "DelimiterFieldFunctionMP": "grey",
    "DelimiterDensityPCNReturnType": "grey",
    "Runtime": "grey",
    "Directionality": "dark-purple",
    "Condition": "light-blue-green",
    "Layer": "grey",
    "WeightedPath": "grey",
    "WeightedProp": "grey",
    "SMDelimiterAssignments": "grey",
    "FFDelimiterAssignments": "grey",
    "DelimiterPattern": "grey",
    "CaseSwitch": "grey",
    "KeyMultiMix": "grey",
    "WeightedAssignment": "grey",
    "WeightedClusterProp": "grey",
    "BlockColumn": "grey",
    "EntryWeightedProp": "grey",
    "RuleBlockMask": "grey",
    "DelimiterEnvironment": "grey",
    "DelimiterTint": "grey",
    "Range": "yellow",
}

var custom_color_names: Dictionary[String, String] = {}

var base_label_stylebox: StyleBoxFlat = preload("res://ui/base_label_stylebox.tres")
var color_label_styleboxes: Dictionary[String, StyleBoxFlat] = {}

func _ready() -> void:
    load_custom_theme()

func get_color_label_stylebox(color_name: String) -> StyleBoxFlat:
    if color_name not in color_label_styleboxes:
        generate_color_label_stylebox(color_name)
    return color_label_styleboxes[color_name]

func get_color_label_text_color(color_name: String) -> Color:
    var actual_color: Color = get_actual_color(color_name)
    if actual_color.ok_hsl_l < 0.54:
        return Color.WHITE
    return Color.BLACK

func generate_color_label_stylebox(color_name: String) -> void:
    var color_label_stylebox: StyleBoxFlat = base_label_stylebox.duplicate()
    var actual_color: Color = get_actual_color(color_name)
    color_label_stylebox.bg_color = actual_color
    color_label_styleboxes[color_name] = color_label_stylebox

func get_actual_color(color_name: String) -> Color:
    return ThemeColorVariants.get_theme_color(color_name)

func get_color_for_type(type_name: String) -> String:
    if type_name in custom_color_names:
        return custom_color_names[type_name]
    if type_name not in type_colors:
        return fallback_color
    return type_colors[type_name]

func get_default_color_name_for_type(type_name: String) -> String:
    if not type_colors.has(type_name):
        return fallback_color
    return type_colors[type_name]

func get_actual_color_for_type(type_name: String) -> Color:
    var color_name: String = get_color_for_type(type_name)
    if not ThemeColorVariants.has_theme_color(color_name):
        color_name = fallback_color
    return ThemeColorVariants.get_theme_color(color_name)

func get_label_color_for_type(type_name: String) -> Color:
    return get_color_label_text_color(get_color_for_type(type_name))

func get_label_stylebox_for_type(type_name: String) -> StyleBoxFlat:
    return get_color_label_stylebox(get_color_for_type(type_name))

func save_custom_theme(message_callback: Callable) -> void:
    print("saving custom theme")
    if not DirAccess.dir_exists_absolute(CUSTOM_THEME_FILE_PATH.get_base_dir()):
        DirAccess.make_dir_absolute(CUSTOM_THEME_FILE_PATH.get_base_dir())
    var custom_theme_dict: = {
        "custom_theme_colors": {}.merged(ThemeColorVariants.custom_theme_colors),
        "custom_type_colors": custom_color_names,
    }
    for color_name in custom_theme_dict["custom_theme_colors"]:
        var color_str: String = custom_theme_dict["custom_theme_colors"][color_name].to_html()
        custom_theme_dict["custom_theme_colors"][color_name] = color_str

    var file: = FileAccess.open(CUSTOM_THEME_FILE_PATH, FileAccess.WRITE)
    if not file:
        push_error("Error opening custom theme file for writing: %s" % CUSTOM_THEME_FILE_PATH)
        print_debug("Error opening custom theme file for writing: %s" % CUSTOM_THEME_FILE_PATH)
        %ToastMessageContainer.show_toast_message("Error saving custom theme colors")
        return
    file.store_string(JSON.stringify(custom_theme_dict))
    message_callback.call("Custom Colors Saved")

func load_custom_theme(message_callback: Callable = Callable()) -> void:
    if not FileAccess.file_exists(CUSTOM_THEME_FILE_PATH):
        return

    var file: = FileAccess.open(CUSTOM_THEME_FILE_PATH, FileAccess.READ)
    if not file:
        push_error("Error opening custom theme file for reading: %s" % CUSTOM_THEME_FILE_PATH)
        print_debug("Error opening custom theme file for reading: %s" % CUSTOM_THEME_FILE_PATH)

    var parsed_dict: Variant = null
    if file:
        parsed_dict = JSON.parse_string(file.get_as_text())

    if not parsed_dict:
        push_error("Error parsing custom theme file")
        print_debug("Error parsing custom theme file")
    
    if not file or not parsed_dict:
        if message_callback.is_valid():
            message_callback.call("Error loading custom theme colors")
        return
    
    var loaded_custom_theme_colors: Dictionary[String, Color] = {}
    for color_name in parsed_dict["custom_theme_colors"]:
        var color_str: String = parsed_dict["custom_theme_colors"][color_name]
        loaded_custom_theme_colors[color_name] = Color.from_string(color_str, Color.MAGENTA)
    ThemeColorVariants.custom_theme_colors = loaded_custom_theme_colors

    custom_color_names.clear()
    custom_color_names.merge(parsed_dict["custom_type_colors"])
    ThemeColorVariants.recreate_variants()
    if message_callback.is_valid():
        message_callback.call("Custom Colors Loaded")

func reset_theme_to_default(message_callback: Callable) -> void:
    ThemeColorVariants.custom_theme_colors = {}
    custom_color_names = {}
    ThemeColorVariants.recreate_variants()
    message_callback.call("Theme Reset to Defaults")
