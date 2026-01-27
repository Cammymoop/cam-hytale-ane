class_name CustomGraphNode
extends GraphNode

func _draw_port(_slot_index: int, port_pos: Vector2i, _left: bool, color: Color) -> void:
    var base_icon: = get_theme_icon("port", "GraphNode")
    
    var icon_offset: Vector2i = -((base_icon.get_size() / 2).round())
    
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, base_icon.get_size() + (Vector2.ONE * 4)), false, color.darkened(0.5))

    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, base_icon.get_size()), false, color)

func update_port_colors(graph_edit: AssetNodeGraphEdit, asset_node: HyAssetNode) -> void:
    if is_slot_enabled_left(0):
        var my_output_type_color_name: Variant = ThemeColorVariants.color_variants.find_key(theme)
        if my_output_type_color_name == null:
            my_output_type_color_name = TypeColors.fallback_color

        var output_color: Color = ThemeColorVariants.theme_colors[my_output_type_color_name]
        set_slot_color_left(0, output_color)

    var connection_list: Array[String] = asset_node.connection_list
    for conn_idx in connection_list.size():
        var conn_value_type: String = graph_edit.schema.node_schema[asset_node.an_type]["connections"][connection_list[conn_idx]].get("value_type", "")
        var conn_color: Color = TypeColors.get_actual_color_for_type(conn_value_type)
        set_slot_color_right(conn_idx, conn_color)