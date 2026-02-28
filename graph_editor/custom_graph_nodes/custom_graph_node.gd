@tool
class_name CustomGraphNode
extends GraphNode

signal was_right_clicked(graph_node: CustomGraphNode)
signal titlebar_double_clicked(graph_node: CustomGraphNode)

var is_in_graph_group: bool = false
var in_group_with_theme: Theme = null

@export var preview_mode: bool = false

@export_storage var slots_start_at_index: int = 0
@export_storage var num_outputs: int = 0
@export_storage var num_inputs: int = 0

@export_storage var input_connection_list: Array[String] = []
@export_storage var input_value_types: Dictionary[String, String] = {}
@export_storage var input_multi: Dictionary[String, bool] = {}
@export_storage var output_connection_list: Array[String] = []
@export_storage var output_value_types: Dictionary[String, String] = {}

@export_storage var input_port_colors: Array[Color] = []
@export_storage var output_port_colors: Array[Color] = []

func make_settings_syncer(asset_node: HyAssetNode) -> SettingsSyncer:
    if get_settings_syncer():
        var old_settings_syncer: = get_settings_syncer()
        old_settings_syncer.queue_free()
        remove_child(old_settings_syncer)
    var settings_syncer: SettingsSyncer = SettingsSyncer.new()
    settings_syncer.name = "SettingsSyncer"
    settings_syncer.set_asset_node(asset_node)
    add_child(settings_syncer, true)
    return settings_syncer

func get_settings_syncer() -> SettingsSyncer:
    return get_node_or_null("SettingsSyncer") as SettingsSyncer

func get_duplicate_for_asset_node(asset_node: HyAssetNode) -> CustomGraphNode:
    var duplicate_gn: CustomGraphNode = duplicate()
    duplicate_gn.set_meta("hy_asset_node_id", asset_node.an_node_id)
    duplicate_gn.make_settings_syncer(asset_node)
    duplicate_gn.resizable = resizable
    duplicate_gn.size = size
    duplicate_gn.title = title
    duplicate_gn.ignore_invalid_connection_type = ignore_invalid_connection_type
    return duplicate_gn

func settings_input_controls_changed() -> void:
    if not get_settings_syncer():
        return
    var old_settings_syncer: = get_settings_syncer()
    var asset_node: = old_settings_syncer.asset_node
    old_settings_syncer.queue_free()
    make_settings_syncer(asset_node)

func replace_synced_asset_node(new_asset_node: HyAssetNode) -> void:
    var settings_syncer: = get_settings_syncer()
    if not settings_syncer:
        return
    settings_syncer.set_asset_node(new_asset_node)

func _gui_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton:
        return
    if event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
        was_right_clicked.emit(self)
    if event.is_pressed() and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
        if get_titlebar_hbox().get_global_rect().has_point(event.global_position):
            titlebar_double_clicked.emit(self)


func _draw_port(slot_index: int, port_pos: Vector2i, is_left: bool, _connection_color: Color) -> void:
    if Engine.is_editor_hint():
        if preview_mode:
            _draw_preview_port(slot_index, port_pos, is_left)
        return
    var base_icon: = get_theme_icon("port", "GraphNode") as DPITexture
    
    var port_idx: int = 0 if is_left else get_input_port_idx_at_slot(slot_index)
    if port_idx < 0:
        return
    
    var port_color: Color = output_port_colors[port_idx] if is_left else input_port_colors[port_idx]
    
    var p_size: Vector2i = base_icon.get_size() / 2.
    var icon_offset: Vector2i = -(Vector2(p_size / 2.).round())
    
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, p_size + (Vector2i.ONE * 4)), false, port_color.darkened(0.5))

    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, p_size), false, port_color)

func _draw_preview_port(slot_index: int, port_pos: Vector2i, _is_left: bool) -> void:
    var base_icon: = get_theme_icon("port", "GraphNode") as DPITexture
    var p_size: Vector2i = base_icon.get_size() / 2.
    var icon_offset: Vector2i = -(Vector2(p_size / 2.).round())
    var connection_color: Color = get_theme_stylebox("normal", "LineEdit").bg_color
    set_slot_color_right(slot_index, connection_color)
    set_slot_color_left(slot_index, connection_color)
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, p_size + (Vector2i.ONE * 4)), false, connection_color.darkened(0.5))
    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, p_size), false, connection_color)

func get_input_port_idx_at_slot(at_slot_idx: int) -> int:
    var port_idx: int = 0
    for slot_idx in get_slot_control_nodes().size():
        if is_slot_enabled_right(slot_idx):
            if slot_idx == at_slot_idx:
                return port_idx
            port_idx += 1
    return -1


func update_port_types(type_id_lookup: Dictionary[String, int]) -> void:
    update_enabled_slots()
    if num_outputs > 0:
        set_slot_type_left(0, type_id_lookup[output_value_types["OUT"]])

    var connection_list: = get_current_connection_list()
    for conn_idx in connection_list.size():
        var conn_name: String = connection_list[conn_idx]
        var conn_value_type: String = input_value_types[conn_name]
        var zero_if_multi: int = 0 if input_multi[conn_name] else 1
        if not conn_value_type:
            conn_value_type = "Unknown"
            zero_if_multi = 0
        set_connection_port_type(conn_idx, type_id_lookup[conn_value_type] + zero_if_multi)

func get_current_slot_nodes() -> Array[Control]:
    var slot_nodes: Array[Control] = []
    for child in get_children():
        if not child is Control or not child.visible:
            continue
        slot_nodes.append(child)
    return slot_nodes

func update_enabled_slots() -> void:
    var slot_nodes: Array[Control] = get_current_slot_nodes()
    for slot_idx in slot_nodes.size():
        set_slot_enabled_left(slot_idx, slot_idx < num_outputs)
        set_slot_enabled_right(slot_idx, slot_idx < num_inputs)
        slot_idx += 1

func get_output_value_type() -> String:
    return output_value_types.get("OUT", "Unknown")

func get_theme_value_type() -> String:
    var output_value_type: String = get_output_value_type()
    if not output_value_type or output_value_type == "Unknown":
        return ""
    return output_value_type

func get_input_value_type_list() -> Array[String]:
    var value_types: Array[String] = []
    for conn_name in input_connection_list:
        value_types.append(input_value_types[conn_name])
    return value_types

func update_aux_positions(aux_data: Dictionary[String, HyAssetNode.AuxData]) -> void:
    var an_id: String = get_meta("hy_asset_node_id", "")
    if an_id:
        aux_data[an_id].position = position_offset

func get_excluded_connection_names() -> Array[String]:
    return []

func get_current_connection_list() -> Array[String]:
    var conn_names: Array[String] = input_connection_list.duplicate()
    var excluded_conn_names: Array[String] = get_excluded_connection_names()
    for excluded_conn_name in excluded_conn_names:
        conn_names.erase(excluded_conn_name)
    return conn_names

func get_current_in_connection_count() -> int:
    return get_current_connection_list().size()

func get_current_connection_value_types() -> Array[String]:
    var conn_names: Array[String] = get_current_connection_list()
    var conn_value_types: Array[String] = []
    for conn_name in conn_names:
        conn_value_types.append(input_value_types[conn_name])
    return conn_value_types

func update_port_colors() -> void:
    update_enabled_slots()

    var use_port_colors_as_connection_colors: bool = true
    if has_theme_constant("connection_follow_port_color") and get_theme_constant("connection_follow_port_color") != 1:
        use_port_colors_as_connection_colors = false

    output_port_colors.clear()
    if num_outputs > 0:
        var output_value_type: String = get_output_value_type()
        var output_color: Color = TypeColors.get_actual_color_for_type(output_value_type)
        output_port_colors.append(output_color)
        if use_port_colors_as_connection_colors:
            set_slot_color_left(0, output_color)
    
    var slot_control_nodes: Array[Control] = get_slot_control_nodes()

    #var conn_value_types: Array[String] = get_current_connection_value_types()
    input_port_colors.clear()
    for conn_idx in num_inputs:
        var conn_name: String = input_connection_list[conn_idx]
        var conn_color: Color = TypeColors.get_actual_color_for_type(input_value_types[conn_name])
        input_port_colors.append(conn_color)
        if use_port_colors_as_connection_colors:
            set_connection_port_color(conn_idx, conn_color)
        if conn_idx < slot_control_nodes.size() and slot_control_nodes[conn_idx] is Label:
            slot_control_nodes[conn_idx].add_theme_color_override("font_color", TypeColors.get_label_color_for_type(input_value_types[conn_name]))
            slot_control_nodes[conn_idx].add_theme_stylebox_override("normal", TypeColors.get_label_stylebox_for_type(input_value_types[conn_name]))

func set_connection_port_color(conn_idx: int, to_color: Color) -> void:
    set_slot_color_right(get_output_port_slot(conn_idx), to_color)

func set_connection_port_type(conn_idx: int, to_graph_type: int) -> void:
    set_slot_type_right(get_output_port_slot(conn_idx), to_graph_type)

func get_slot_control_nodes() -> Array[Control]:
    var slot_control_nodes: Array[Control] = []
    for child in get_children():
        if not child is Control:
            continue
        slot_control_nodes.append(child)
    return slot_control_nodes

func update_is_in_graph_group(new_value: bool, group_theme: Theme = null) -> void:
    is_in_graph_group = new_value
    in_group_with_theme = group_theme
    queue_redraw()

func _draw() -> void:
    if Engine.is_editor_hint():
        return
    # Draw indicator if this node is in a group
    if is_in_graph_group:
        var from_theme: = in_group_with_theme if in_group_with_theme else theme
        if not from_theme:
            from_theme = preload("res://ui/assets/theme/default/grey_theme.tres")
        var indicator_stylebox: = from_theme.get_stylebox("group_indicator_tab", "GraphNode")

        var gn_top_center: = Vector2(size.x / 2, 0)

        var indicator_width: = maxf(indicator_stylebox.get_minimum_size().x, size.x * 0.5)
        var indicator_height: = indicator_stylebox.get_minimum_size().y

        var indicator_rect: = Rect2(
            gn_top_center.x - (indicator_width / 2), gn_top_center.y - indicator_height,
            indicator_width, indicator_height
        )
        draw_style_box(indicator_stylebox, indicator_rect)

func get_export_import_tooltip() -> String:
    if not get_meta("hy_asset_node_id", ""):
        return ""
    var asset_node: = get_settings_syncer().asset_node
    if asset_node.an_type == "WeightedPath":
        return "Prefab Path: \"%s\"" % asset_node.settings["Path"]
    if asset_node.settings.get("ExportAs", ""):
        var out_value_type: = SchemaManager.schema.get_output_value_type(asset_node.an_type)
        return "Exported %s : %s (%s)" % [out_value_type, asset_node.settings["ExportAs"], title]
    elif asset_node.an_type.begins_with("Imported"):
        var out_value_type: = SchemaManager.schema.get_output_value_type(asset_node.an_type)
        if asset_node.title and asset_node.title != asset_node.default_title:
            return "Imported %s : \"%s\" (%s)" % [out_value_type, asset_node.settings["Name"], title]
        else:
            return "Imported %s : \"%s\"" % [out_value_type, asset_node.settings["Name"]]
    else:
        return ""

func _get_tooltip(_at_position: Vector2) -> String:
    if Engine.is_editor_hint():
        return ""
    var export_import_tooltip: = get_export_import_tooltip()
    return export_import_tooltip if export_import_tooltip else title