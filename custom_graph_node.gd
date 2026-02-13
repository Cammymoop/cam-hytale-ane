class_name CustomGraphNode
extends GraphNode

signal was_right_clicked(graph_node: CustomGraphNode)
signal titlebar_double_clicked(graph_node: CustomGraphNode)

var node_type_schema: Dictionary
var settings_syncer: SettingsSyncer = null
@export_storage var theme_color_output_type: String = ""

var is_in_graph_group: bool = false
var in_group_with_theme: Theme = null

# For usage in the inpector at runtime to jump to the asset node easier
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var found_asset_node: HyAssetNode = null
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR)
var find_asset_node: bool = false:
    set(value):
        if not get_meta("hy_asset_node_id", ""):
            return
        var graph_edit: = get_parent() as AssetNodeGraphEdit
        if not graph_edit:
            print_debug("find asset node: no parent or parent is not AssetNodeGraphEdit")
            return
        var an_id: String = get_meta("hy_asset_node_id", "")
        if not an_id in graph_edit.an_lookup:
            print_debug("find asset node: asset node ID %s not found in an_lookup" % an_id)
            return
        found_asset_node = graph_edit.an_lookup[an_id]
        notify_property_list_changed()

func make_settings_syncer(asset_node: HyAssetNode) -> SettingsSyncer:
    settings_syncer = SettingsSyncer.new()
    settings_syncer.name = "SettingsSyncer"
    settings_syncer.set_asset_node(asset_node)
    add_child(settings_syncer, true)
    return settings_syncer

func fix_duplicate_settings_syncer(asset_node: HyAssetNode) -> void:
    settings_syncer = $SettingsSyncer as SettingsSyncer
    assert(settings_syncer != null, "SettingsSyncer not found in duplicate graph node")
    settings_syncer.set_asset_node(asset_node)

func _gui_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton:
        return
    if event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
        prints("right clicked on graph node: %s" % title)
        was_right_clicked.emit(self)
    if event.is_pressed() and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
        if get_titlebar_hbox().get_global_rect().has_point(event.global_position):
            titlebar_double_clicked.emit(self)


func _draw_port(_slot_index: int, port_pos: Vector2i, _left: bool, color: Color) -> void:
    var base_icon: = get_theme_icon("port", "GraphNode") as DPITexture
    
    var p_size: Vector2i = base_icon.get_size() / 2.
    var icon_offset: Vector2i = -(Vector2(p_size / 2.).round())
    
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, p_size + (Vector2i.ONE * 4)), false, color.darkened(0.5))

    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, p_size), false, color)

func set_node_type_schema(schema: Dictionary) -> void:
    node_type_schema = schema

func update_slot_types(type_id_lookup: Dictionary[String, int]) -> void:
    if not node_type_schema:
        return
    if not node_type_schema.get("no_output", false):
        if not is_slot_enabled_left(0):
            prints("Uh oh, output slot 0 is not enabled")
        set_slot_type_left(0, type_id_lookup[node_type_schema.get("output_value_type", "")])

    var conn_names: Array = node_type_schema.get("connections", {}).keys()
    for conn_idx in conn_names.size():
        var conn_slot: int = get_output_port_slot(conn_idx)
        if not is_slot_enabled_right(conn_slot):
            prints("Uh oh, connection %s (slot %d) is not enabled" % [conn_idx, conn_slot])
        var conn_value_type: String = node_type_schema["connections"][conn_names[conn_idx]].get("value_type", "")
        if conn_value_type:
            set_connection_port_type(conn_idx, type_id_lookup[conn_value_type])

func get_current_connection_list() -> Array[String]:
    if not node_type_schema:
        return []
    return Array(node_type_schema.get("connections", {}).keys(), TYPE_STRING, "", null)

func get_current_connection_value_types() -> Array[String]:
    var conn_names: Array = get_current_connection_list()
    var conn_value_types: Array[String] = []
    for conn_name in conn_names:
        conn_value_types.append(node_type_schema["connections"][conn_name].get("value_type", ""))
    return conn_value_types

func update_port_colors() -> void:
    if is_slot_enabled_left(0):
        var output_color: Color = TypeColors.get_actual_color_for_type(theme_color_output_type)
        set_slot_color_left(0, output_color)
    
    var slot_control_nodes: Array[Control] = get_slot_control_nodes()

    if node_type_schema:
        var conn_value_types: Array[String] = get_current_connection_value_types()
        for conn_idx in conn_value_types.size():
            var conn_color: Color = TypeColors.get_actual_color_for_type(conn_value_types[conn_idx])
            set_connection_port_color(conn_idx, conn_color)
            if conn_idx < slot_control_nodes.size() and slot_control_nodes[conn_idx] is Label:
                slot_control_nodes[conn_idx].add_theme_color_override("font_color", TypeColors.get_label_color_for_type(conn_value_types[conn_idx]))
                slot_control_nodes[conn_idx].add_theme_stylebox_override("normal", TypeColors.get_label_stylebox_for_type(conn_value_types[conn_idx]))

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
    # Draw indicator if this node is in a group
    if is_in_graph_group:
        var from_theme: = in_group_with_theme if in_group_with_theme else theme
        if not from_theme:
            from_theme = preload("res://ui/grey_theme.tres")
        var indicator_stylebox: = from_theme.get_stylebox("group_indicator_tab", "GraphNode")

        var gn_top_center: = Vector2(size.x / 2, 0)

        var indicator_width: = maxf(indicator_stylebox.get_minimum_size().x, size.x * 0.5)
        var indicator_height: = indicator_stylebox.get_minimum_size().y

        var indicator_rect: = Rect2(
            gn_top_center.x - (indicator_width / 2), gn_top_center.y - indicator_height,
            indicator_width, indicator_height
        )
        draw_style_box(indicator_stylebox, indicator_rect)
    