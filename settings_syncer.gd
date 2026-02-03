extends Node
class_name SettingsSyncer

var asset_node: HyAssetNode
var watched_settings: Dictionary[String, NodePath] = {}
var setting_gd_types: Dictionary[String, int] = {}

func set_asset_node(the_asset_node: HyAssetNode) -> void:
    asset_node = the_asset_node
    asset_node.settings_changed.connect(update_from_asset_node)

func add_watched_setting(setting_name: String, input_control: Control, setting_gd_type: int = -1) -> void:
    watched_settings[setting_name] = get_path_to(input_control)
    setting_gd_types[setting_name] = setting_gd_type if setting_gd_type >= 0 else TYPE_STRING

    if input_control is GNNumberEdit:
        input_control.value_changed.connect(on_value_changed.bind(setting_name))
    elif input_control is LineEdit:
        input_control.text_changed.connect(on_value_changed.bind(setting_name))
    elif input_control is BaseButton and input_control.toggle_mode:
        input_control.toggled.connect(on_value_changed.bind(setting_name))
    else:
        print_debug("Warning: Setting %s has an unknown type of input control: %s" % [setting_name, input_control.get_class()])

func on_value_changed(value: Variant, setting_name: String) -> void:
    assert(asset_node != null, "SettingsSyncer: Asset node is not set")
    if setting_gd_types[setting_name] == TYPE_STRING:
        asset_node.settings[setting_name] = str(value)
    elif setting_gd_types[setting_name] == TYPE_FLOAT:
        asset_node.settings[setting_name] = float(value)
    elif setting_gd_types[setting_name] == TYPE_INT:
        asset_node.settings[setting_name] = int(value)
    elif setting_gd_types[setting_name] == TYPE_BOOL:
        asset_node.settings[setting_name] = bool(value)
    else:
        print_debug("Warning: Setting %s has gd type %s, which is not expected" % [setting_name, type_string(setting_gd_types[setting_name])])

func update_from_asset_node() -> void:
    for setting_name in watched_settings.keys():
        var input_control: = get_node(watched_settings[setting_name]) as Control
        if input_control is GNNumberEdit:
            input_control.set_value_directly(float(asset_node.settings[setting_name]))
        elif input_control is LineEdit:
            input_control.text = str(asset_node.settings[setting_name])
        elif input_control is BaseButton and input_control.toggle_mode:
            input_control.button_pressed = bool(asset_node.settings[setting_name])


