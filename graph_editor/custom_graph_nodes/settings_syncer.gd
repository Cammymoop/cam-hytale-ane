extends Node
class_name SettingsSyncer

const UndoStep = preload("res://graph_editor/undo_redo/undo_step.gd")

signal updated_from_asset_node()

var asset_node: HyAssetNode
@export var watched_settings: Dictionary[String, NodePath] = {}
@export var setting_gd_types: Dictionary[String, int] = {}

var last_string_change_undo_step: UndoStep = null

func _ready() -> void:
    bind_signals()

func bind_signals(for_setting: String = "") -> void:
    for setting_name in watched_settings.keys():
        if for_setting and setting_name != for_setting:
            continue
        var input_control: = get_node(watched_settings[setting_name]) as Control
        if input_control is GNNumberEdit:
            if not input_control.val_changed.is_connected(on_value_changed):
                input_control.val_changed.connect(on_value_changed.bind(setting_name))
        elif input_control is GNExclusiveEnumEdit:
            if not input_control.option_changed.is_connected(on_value_changed):
                input_control.option_changed.connect(on_value_changed.bind(setting_name))
        elif input_control is Range:
            if not input_control.value_changed.is_connected(on_value_changed):
                input_control.value_changed.connect(on_value_changed.bind(setting_name))
        elif input_control is GNToggleSet:
            if not input_control.members_changed.is_connected(on_value_changed):
                input_control.members_changed.connect(on_value_changed.bind(setting_name))
        elif input_control is LineEdit:
            if not input_control.text_changed.is_connected(on_value_changed):
                input_control.text_changed.connect(on_value_changed.bind(setting_name))
        elif input_control is BaseButton and input_control.toggle_mode:
            if not input_control.toggled.is_connected(on_value_changed):
                input_control.toggled.connect(on_value_changed.bind(setting_name))
        else:
            print_debug("Warning: Setting %s has an unknown type of input control: %s" % [setting_name, input_control.get_class()])

func set_asset_node(the_asset_node: HyAssetNode) -> void:
    if asset_node:
        if asset_node.settings_changed.is_connected(update_from_asset_node):
            asset_node.settings_changed.disconnect(update_from_asset_node)
    asset_node = the_asset_node
    asset_node.settings_changed.connect(update_from_asset_node)
    #update_from_asset_node()

func auto_add_watched_settings(graph_node: CustomGraphNode = null) -> void:
    if not graph_node:
        graph_node = get_parent() as CustomGraphNode
    if not graph_node:
        push_error("SettingsSyncer auto add watched settings: No parent graph node")
        return
    for child_control in Util.enumerate_children(graph_node, "Control"):
        if child_control.name.begins_with("SettingEdit_"):
            var setting_name: = child_control.name.trim_prefix("SettingEdit_")
            var setting_gd_type: int = child_control.get_meta("gd_type")
            add_watched_setting(setting_name, child_control, setting_gd_type)

func add_watched_setting(setting_name: String, input_control: Control, setting_gd_type: int = -1) -> void:
    watched_settings[setting_name] = get_path_to(input_control)
    setting_gd_types[setting_name] = setting_gd_type if setting_gd_type >= 0 else TYPE_STRING
    
    bind_signals(setting_name)

func on_value_changed(value: Variant, setting_name: String) -> void:
    assert(asset_node != null, "SettingsSyncer: Asset node is not set")

    var editor: = get_parent().get_parent().editor as CHANE_AssetNodeEditor
    var undo_action_name: = "Edit %s" % setting_name
    var undo_step: UndoStep = null
    var is_new_step: bool = false
    var is_reuse_step: bool = false
    
    var setting_gd_type: int = setting_gd_types[setting_name]
    
    var last_undo_step_matches: bool = editor.undo_manager.get_last_committed_undo_step() == last_string_change_undo_step
    last_undo_step_matches = last_undo_step_matches and last_string_change_undo_step != null

    if setting_gd_type == TYPE_STRING and not editor.undo_manager.is_creating_undo_step() and last_undo_step_matches:
        undo_step = last_string_change_undo_step
        is_reuse_step = true
    else:
        undo_step = editor.undo_manager.start_or_continue_undo_step(undo_action_name)
        is_new_step = editor.undo_manager.is_new_step
        if setting_gd_type == TYPE_STRING:
            last_string_change_undo_step = undo_step
        else:
            last_string_change_undo_step = null

        undo_step.register_an_settings_before_change(asset_node)

    if setting_gd_type == TYPE_STRING:
        asset_node.settings[setting_name] = str(value)
    elif setting_gd_type == TYPE_FLOAT:
        asset_node.settings[setting_name] = float(value)
    elif setting_gd_type == TYPE_INT:
        asset_node.settings[setting_name] = int(value)
    elif setting_gd_type == TYPE_BOOL:
        asset_node.settings[setting_name] = bool(value)
    elif setting_gd_type == TYPE_ARRAY:
        if not asset_node.settings.has(setting_name):
            asset_node.settings[setting_name] = []
        asset_node.settings[setting_name].assign(value)
    else:
        print_debug("Warning: Setting %s has gd type %s, which is not expected" % [setting_name, type_string(setting_gd_types[setting_name])])
    
    if is_new_step:
        editor.undo_manager.commit_current_undo_step()
    elif is_reuse_step:
        editor.undo_manager.recommit_undo_step(undo_step)

func update_from_asset_node() -> void:
    for setting_name in watched_settings.keys():
        var input_control: = get_node(watched_settings[setting_name]) as Control
        if input_control is GNNumberEdit:
            input_control.set_value_directly(float(asset_node.settings[setting_name]))
        elif input_control is GNExclusiveEnumEdit:
            input_control.set_current_option_directly(str(asset_node.settings[setting_name]))
        elif input_control is Range:
            if input_control.has_method("set_value_directly"):
                input_control.set_value_directly(float(asset_node.settings[setting_name]))
            else:
                input_control.set_value_no_signal(float(asset_node.settings[setting_name]))
        elif input_control is GNToggleSet:
            input_control.set_members_directly(asset_node.settings[setting_name])
        elif input_control is LineEdit:
            if input_control.text != str(asset_node.settings[setting_name]):
                input_control.text = str(asset_node.settings[setting_name])
        elif input_control is BaseButton and input_control.toggle_mode:
            input_control.set_pressed_no_signal(bool(asset_node.settings[setting_name]))
    updated_from_asset_node.emit()

