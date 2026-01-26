class_name CustomGraphNode
extends GraphNode

func _draw_port(_slot_index: int, port_pos: Vector2i, _left: bool, color: Color) -> void:
    var base_icon: = get_theme_icon("port", "GraphNode")
    
    var icon_offset: Vector2i = -((base_icon.get_size() / 2).round())
    
    draw_texture_rect(base_icon, Rect2(port_pos - (Vector2i.ONE * 2) + icon_offset, base_icon.get_size() + (Vector2.ONE * 4)), false, color.darkened(0.5))

    draw_texture_rect(base_icon, Rect2(port_pos + icon_offset, base_icon.get_size()), false, color)