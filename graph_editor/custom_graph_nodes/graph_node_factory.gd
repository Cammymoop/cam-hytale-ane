extends Node

const SpecialGNFactory = preload("res://graph_editor/custom_graph_nodes/special_gn_factory.gd")

@onready var special_gn_factory: SpecialGNFactory = SpecialGNFactory.new()

var global_gn_counter: int = 0

@export var gn_min_width: = 90

func _ready() -> void:
    special_gn_factory.name = "SpecialGNFactory"
    add_child(special_gn_factory, true)

func reset_global_gn_counter() -> void:
    global_gn_counter = 0

func new_graph_node_name(base_name: String) -> String:
    global_gn_counter += 1
    return "%s--%d" % [base_name, global_gn_counter]

func make_new_graph_node_for_asset_node(asset_node: HyAssetNode, is_newly_created: bool, at_position: Vector2, centered: bool = false) -> CustomGraphNode:
    var graph_node: CustomGraphNode

    var is_special: = special_gn_factory.should_be_special_gn(asset_node)
    if is_special:
        graph_node = special_gn_factory.make_special_gn(asset_node, is_newly_created)
    else:
        graph_node = CustomGraphNode.new()
        graph_node.make_settings_syncer(asset_node)

    graph_node.set_meta("hy_asset_node_id", asset_node.an_node_id)
    
    graph_node.name = new_graph_node_name(graph_node.name if graph_node.name else &"GN")
    
    var node_schema: Dictionary = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        node_schema = SchemaManager.schema.node_schema[asset_node.an_type]
    
    graph_node.resizable = true
    graph_node.size = Vector2(gn_min_width, 0)
    if not graph_node.get_output_value_type():
        graph_node.ignore_invalid_connection_type = true

    graph_node.title = asset_node.title

    graph_node.position_offset = at_position
    
    if not is_special:
        setup_base_output_input_info(graph_node, asset_node, node_schema)
        setup_common_graph_node_controls(graph_node, asset_node, node_schema)

    var theme_var_color: String = TypeColors.get_color_for_type(graph_node.get_theme_value_type())
    if ThemeColorVariants.has_theme_color(theme_var_color):
        graph_node.theme = ThemeColorVariants.get_theme_color_variant(theme_var_color)
    else:
        push_warning("No theme color variant found for color '%s'" % theme_var_color)
        print_debug("No theme color variant found for color '%s'" % theme_var_color)
    
    if centered:
        graph_node.position_offset -= graph_node.size / 2
    
    return graph_node

func setup_base_output_input_info(graph_node: CustomGraphNode, asset_node: HyAssetNode, node_schema: Dictionary) -> void:
    graph_node.slots_start_at_index = 0

    if node_schema and node_schema.get("no_output", false):
        graph_node.num_outputs = 0
    else:
        graph_node.num_outputs = 1
        graph_node.output_connection_list.append("OUT")
        graph_node.output_value_types["OUT"] = node_schema["output_value_type"]
    
    var connection_names: Array
    if node_schema:
        connection_names = node_schema.get("connections", {}).keys()
    else:
        connection_names = asset_node.connection_list.duplicate()
    graph_node.num_inputs = connection_names.size()
    
    for conn_name in connection_names:
        graph_node.input_connection_list.append(conn_name)
        graph_node.input_value_types[conn_name] = node_schema["connections"][conn_name]["value_type"]
        graph_node.input_multi[conn_name] = node_schema["connections"][conn_name].get("multi", true)


func setup_common_graph_node_controls(graph_node: CustomGraphNode, asset_node: HyAssetNode, node_schema: Dictionary) -> void:
    var connection_names: = graph_node.input_connection_list
    
    var setting_names: Array
    if node_schema:
        setting_names = node_schema.get("settings", {}).keys()
    else:
        setting_names = asset_node.settings.keys()
    var num_settings: = setting_names.size()
    
    var num_connection_slots: = maxi(graph_node.num_outputs, graph_node.num_inputs)
    var total_slots: = num_connection_slots + num_settings
    
    for i in num_connection_slots:
        var slot_node: = Label.new()
        slot_node.name = "Slot%d" % i
        slot_node.size_flags_horizontal = Control.SIZE_SHRINK_END
        graph_node.add_child(slot_node, true)
        if i < graph_node.num_outputs:
            pass#graph_node.set_slot_enabled_left(i, true)
        if i < graph_node.num_inputs:
            #graph_node.set_slot_enabled_right(i, true)
            slot_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            slot_node.text = connection_names[i]
    
    for i in range(num_connection_slots, total_slots):
        var setting_name: String = setting_names[i - num_connection_slots]
        if node_schema and node_schema.get("settings", {}).has(setting_name) and node_schema.get("settings", {})[setting_name].get("hidden", false):
            continue

        var s_name: = Label.new()
        s_name.name = "SettingName"
        s_name.text = "%s:" % setting_name
        s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var s_edit: Control
        var setting_value: Variant
        var setting_type: int
        if setting_name in asset_node.settings:
            setting_value = asset_node.settings[setting_name]
        else:
            setting_value = SchemaManager.schema.node_schema[asset_node.an_type]["settings"][setting_name].get("default_value", 0)

        if setting_name in node_schema.get("settings", {}):
            setting_type = node_schema.get("settings", {})[setting_name]["gd_type"]
        else:
            print_debug("Setting type for %s : %s not found in node schema (%s)" % [setting_name, setting_value, asset_node.an_type])
            setting_type = typeof(setting_value) if setting_value else TYPE_STRING
        
        var ui_hint: String = node_schema.get("settings", {})[setting_name].get("ui_hint", "")

        var slot_node: Control = HBoxContainer.new()

        # Standard settings editors, potentially overridden below by custom stuff based on ui_hint etc
        if setting_type == TYPE_BOOL:
            s_edit = CheckBox.new()
            s_edit.button_pressed = setting_value
        elif setting_type == TYPE_FLOAT or setting_type == TYPE_INT:
            s_edit = GNNumberEdit.new()
            s_edit.expand_to_text_length = true
            s_edit.is_int = setting_type == TYPE_INT
            s_edit.set_value_directly(setting_value)
            s_edit.size_flags_horizontal = Control.SIZE_FILL
            s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        else:
            s_edit = CustomLineEdit.new()
            s_edit.expand_to_text_length = true
            s_edit.add_theme_constant_override("minimum_character_width", 4)
            s_edit.text = str(setting_value)
            s_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            s_name.size_flags_horizontal = Control.SIZE_FILL

        # Special settings editors based on type and ui_hint etc
        if ui_hint == "string_enum":
            s_edit = preload("res://ui/custom_controls/exclusive_enum.tscn").instantiate() as GNExclusiveEnumEdit
            var value_set: String = node_schema["settings"][setting_name].get("value_set", "")
            if not value_set:
                print_debug("Value set for %s:%s not found in schema" % [asset_node.an_type, setting_name])
                continue
            if node_schema["settings"][setting_name]["gd_type"] == TYPE_STRING:
                var valid_values: Array[String] = SchemaManager.schema.get_value_set_values(value_set)
                s_edit.set_options(valid_values, setting_value)
            else:
                var valid_values: Array = SchemaManager.schema.get_value_set_values(value_set)
                s_edit.set_numeric_options(valid_values, setting_value)
        elif ui_hint == "enum_as_set":
            slot_node = VBoxContainer.new()
            s_edit = preload("res://ui/custom_controls/toggle_set.tscn").instantiate() as GNToggleSet
            var value_set: String = node_schema["settings"][setting_name].get("value_set", "")
            if not value_set:
                print_debug("Value set for %s:%s not found in schema" % [asset_node.an_type, setting_name])
                continue
            if not setting_type == TYPE_ARRAY:
                print_debug("UI hinted toggle set for %s:%s but the setting is not an array" % [asset_node.an_type, setting_name])
                continue
            var valid_values: Array = SchemaManager.schema.get_value_set_values(value_set)
            var sub_gd_type: int = node_schema["settings"][setting_name]["array_gd_type"]
            if sub_gd_type == TYPE_INT:
                var converted_values: Array = []
                for value in setting_value:
                    converted_values.append(int(value))
                s_edit.setup(valid_values, converted_values)
            else:
                s_edit.setup(valid_values, setting_value)
        elif ui_hint.begins_with("int_range:"):
            var range_parts: = ui_hint.trim_prefix("int_range:").split("_", true)
            if range_parts.size() != 2:
                push_warning("Invalid int range hint %s for %s:%s" % [ui_hint, asset_node.an_type, setting_name])
            else:
                var has_min: = range_parts[0].is_valid_int()
                var has_max: = range_parts[1].is_valid_int()
                var spin: CustomSpinBox = preload("res://ui/custom_controls/spin_box_edit.tscn").instantiate()
                spin.step = 1
                spin.rounded = true
                if has_min and has_max:
                    spin.min_value = int(range_parts[0])
                    spin.max_value = int(range_parts[1])
                elif has_max:
                    spin.max_value = int(range_parts[1])
                    spin.min_value = -spin.max_value
                    spin.allow_lesser = true
                elif has_min:
                    spin.min_value = int(range_parts[0])
                    spin.max_value = 1000000
                    spin.allow_greater = true
                spin.value = int(float(setting_value))
                s_edit = spin
        elif ui_hint == "block_id":
            s_edit.add_theme_constant_override("minimum_character_width", 14)
        elif ui_hint:
            pass#prints("UI hint %s for %s:%s has no handling" % [ui_hint, asset_node.an_type, setting_name])
        

        s_edit.name = "SettingEdit_%s" % setting_name
        s_edit.set_meta("gd_type", setting_type)
        slot_node.name = "Slot%d" % i
        slot_node.add_child(s_name, true)
        slot_node.add_child(s_edit, true)
        graph_node.add_child(slot_node, true)

        #graph_node.settings_syncer.add_watched_setting(setting_name, s_edit, setting_type)
    
    graph_node.get_settings_syncer().auto_add_watched_settings(graph_node)
