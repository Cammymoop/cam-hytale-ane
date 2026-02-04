class_name CustomGraphNode
extends GraphNode

signal was_right_clicked(graph_node: CustomGraphNode)

var node_type_schema: Dictionary

var settings_syncer: SettingsSyncer = null

var theme_color_output_type: String = ""

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
        was_right_clicked.emit(self)

func _draw_port(_slot_index: int, port_pos: Vector2i, _left: bool, color: Color) -> void:
    var base_icon: = get_theme_icon("port", "GraphNode") as DPITexture
    
    var p_size: Vector2i = base_icon.get_size() / 4.
    var icon_offset: Vector2i = -(Vector2(p_size / 2.).round())
    
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, p_size + (Vector2i.ONE * 4)), false, color.darkened(0.5))

    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, p_size), false, color)

func set_node_type_schema(schema: Dictionary) -> void:
    node_type_schema = schema

func update_port_colors() -> void:
    if is_slot_enabled_left(0):
        var output_color: Color = TypeColors.get_actual_color_for_type(theme_color_output_type)
        set_slot_color_left(0, output_color)
    
    var slot_control_nodes: Array[Control] = get_slot_control_nodes()

    if node_type_schema:
        var conn_names: Array = node_type_schema.get("connections", {}).keys()
        for conn_idx in conn_names.size():
            var conn_value_type: String = node_type_schema["connections"][conn_names[conn_idx]].get("value_type", "")
            var conn_color: Color = TypeColors.get_actual_color_for_type(conn_value_type)
            set_slot_color_right(conn_idx, conn_color)
            if conn_idx < slot_control_nodes.size() and slot_control_nodes[conn_idx] is Label:
                slot_control_nodes[conn_idx].add_theme_color_override("font_color", TypeColors.get_label_color_for_type(conn_value_type))
                slot_control_nodes[conn_idx].add_theme_stylebox_override("normal", TypeColors.get_label_stylebox_for_type(conn_value_type))

func get_slot_control_nodes() -> Array[Control]:
    var slot_control_nodes: Array[Control] = []
    for child in get_children():
        if not child is Control:
            continue
        slot_control_nodes.append(child)
    return slot_control_nodes