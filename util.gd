extends Node

func unique_id_string() -> String:
    return "%s-%s-%s-%s-%s" % [random_str(8), random_str(4), random_str(4), random_str(4), random_str(12)]

func random_str(length: int) -> String:
    var the_str: = ""
    while length > 4:
        length -= 4
        the_str += "%04x" % (randi() & 0xFFFF)
    the_str += ("%04x" % (randi() & 0xFFFF)).substr(0, length)
    return the_str

func average_graph_element_pos_offset(ges: Array[GraphElement]) -> Vector2:
    var offsets: Array[Vector2] = []
    for ge in ges:
        offsets.append(ge.position_offset)
    return average_vector2(offsets)
    
func average_vector2(vectors: Array[Vector2]) -> Vector2:
    if vectors.size() == 0:
        return Vector2.ZERO
    if vectors.size() <= 8:
        return _average_vector2_small(vectors)
    
    var pivot_idx: int = floori(vectors.size() / 2.0)
    var left_avg: Vector2 = average_vector2(vectors.slice(0, pivot_idx))
    var right_avg: Vector2 = average_vector2(vectors.slice(pivot_idx, vectors.size()))
    return (left_avg + right_avg) / 2.0

func _average_vector2_small(vectors: Array[Vector2]) -> Vector2:
    var total: Vector2 = Vector2.ZERO
    for vector in vectors:
        total += vector
    return total / vectors.size()

func get_context_menu_pos(mouse_pos: Vector2i) -> Vector2i:
    var window: = get_window()
    if not window.gui_embed_subwindows:
        return mouse_pos + window.position
    return mouse_pos

func is_ctrl_cmd_pressed() -> bool:
    var ctrl_keycode: = KEY_CTRL
    if OS.has_feature("macos"):
        ctrl_keycode = KEY_META
    return Input.is_key_pressed(ctrl_keycode)

func is_shift_pressed() -> bool:
    return Input.is_key_pressed(KEY_SHIFT)