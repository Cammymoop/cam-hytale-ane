extends Node

func unique_id_string() -> String:
    return "%s-%s-%s-%s-%s" % [random_str(8), random_str(4), random_str(4), random_str(4), random_str(12)]

func rect2_clamp_point(rect: Rect2, point: Vector2) -> Vector2:
    return point.max(rect.position).min(rect.end)

func rect2_clamp_rect2_pos(limit_rect: Rect2, rect: Rect2) -> Vector2:
    if rect.size.x > limit_rect.size.x and rect.size.y > limit_rect.size.y:
        return limit_rect.position

    var clamp_start_pos: = rect2_clamp_point(limit_rect, rect.position)
    var final_clamped: = rect2_clamp_point(limit_rect, rect.end) - rect.size
    if rect.size.x > limit_rect.size.x or rect.position.x < limit_rect.position.x:
        final_clamped.x = clamp_start_pos.x
    if rect.size.y > limit_rect.size.y or rect.position.y < limit_rect.position.y:
        final_clamped.y = clamp_start_pos.y
    
    return final_clamped

func get_plain_version() -> String:
    return "v%s" % ProjectSettings.get_setting("application/config/version")

func get_version_number_string() -> String:
    var prerelease_string: = " Beta"
    if OS.has_feature("debug"):
        prerelease_string = " Beta (Debug)"
    return get_plain_version() + prerelease_string

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

func get_popup_window_pos(mouse_pos: Vector2i) -> Vector2i:
    var window: = get_window()
    if not window.gui_embed_subwindows:
        return mouse_pos + window.position
    return mouse_pos

func clamp_popup_pos_inside_window(popup_pos: Vector2i, popup_size: Vector2, parent_window: Window) -> Vector2i:
    if not parent_window.gui_embed_subwindows:
        var window_in_screen_rect: = parent_window.get_visible_rect()
        window_in_screen_rect.position = Vector2(parent_window.position)
        return Vector2i(rect2_clamp_rect2_pos(window_in_screen_rect, Rect2(popup_pos, popup_size)))
    
    var global_pos_rect: = Rect2(Vector2.ZERO, parent_window.size)
    return Vector2i(rect2_clamp_rect2_pos(global_pos_rect, Rect2(popup_pos, popup_size)))

func is_ctrl_cmd_pressed() -> bool:
    var ctrl_keycode: = KEY_CTRL
    if OS.has_feature("macos"):
        ctrl_keycode = KEY_META
    return Input.is_key_pressed(ctrl_keycode)

func is_shift_pressed() -> bool:
    return Input.is_key_pressed(KEY_SHIFT)

func get_icon_for_color(icon_color: Color) -> Texture2D:
    var icon_size: = ANESettings.MENU_ICON_SIZE
    var img: = Image.create(icon_size, icon_size, false, Image.FORMAT_RGB8)
    img.fill(icon_color)
    return ImageTexture.create_from_image(img)

func out_connections(conn_infos: Array[Dictionary], graph_node_name: String, only_at_port: int = -1) -> Array[Dictionary]:
    var out_conn_infos: Array[Dictionary] = []
    for conn_info in conn_infos:
        if conn_info.get("to_node", "") == graph_node_name:
            if only_at_port == -1 or conn_info.get("to_port", -1) == only_at_port:
                out_conn_infos.append(conn_info)
    return out_conn_infos

func in_connections(conn_infos: Array[Dictionary], graph_node_name: String, only_at_port: int = -1) -> Array[Dictionary]:
    var in_conn_infos: Array[Dictionary] = []
    for conn_info in conn_infos:
        if conn_info.get("from_node", "") == graph_node_name:
            if only_at_port == -1 or conn_info.get("from_port", -1) == only_at_port:
                in_conn_infos.append(conn_info)
    return in_conn_infos

func str_empty_or_match(str_a: String, str_b: String) -> bool:
    return str_a == "" or str_b == "" or str_a == str_b

func script_type_filtered(arr: Array, narrowing_script: Script) -> Array:
    var filtered_arr: Array = Array([], TYPE_OBJECT, narrowing_script.get_class(), narrowing_script)
    for item in arr:
        if item and typeof(item) == TYPE_OBJECT and is_instance_of(item, narrowing_script):
            filtered_arr.append(item)
    return filtered_arr

func engine_class_filtered(arr: Array, engine_class: StringName) -> Array:
    var filtered_arr: Array = Array([], TYPE_OBJECT, engine_class, null)
    for item in arr:
        if item and typeof(item) == TYPE_OBJECT and ClassDB.is_parent_class(item.get_class(), engine_class):
            filtered_arr.append(item)
    return filtered_arr

func enumerate_children(node: Node, engine_class_filter: StringName = "") -> Array[Node]:
    var children: Array[Node] = []
    for child in node.get_children():
        if engine_class_filter and not ClassDB.is_parent_class(child.get_class(), engine_class_filter):
            continue
        children.append(child)
        children.append_array(enumerate_children(child, engine_class_filter))
    return children

func append_array_unique(into_arr: Array, new_items: Array) -> void:
    for item in new_items:
        if not item in into_arr:
            into_arr.append(item)

func print_plain_data_diff(data_a: Dictionary, data_b: Dictionary) -> void:
    var diff: Dictionary = get_plain_data_diff(data_a, data_b)
    if diff.has("No Differences"):
        print("No Differences")
    else:
        print(JSON.stringify(diff, " ", false))

func get_plain_data_diff(data_a: Dictionary, data_b: Dictionary) -> Dictionary:
    var diff: Variant = _plain_data_diff(data_a, data_b)
    if diff == null:
        return {"No Differences": true}
    elif typeof(diff) != TYPE_DICTIONARY:
        return {"type:": type_string(typeof(diff)), "value": diff}
    return diff

func _plain_data_diff(sub_data_a: Variant, sub_data_b: Variant, desorted: bool = false) -> Variant:
    if typeof(sub_data_a) != typeof(sub_data_b):
        return ["MISMATCHED_TYPES", type_string(typeof(sub_data_a)), type_string(typeof(sub_data_b))]
    
    var val_type: = typeof(sub_data_a)
    if val_type == TYPE_DICTIONARY:
        var ret: Dictionary = {}
        var both_keys: Array = sub_data_a.keys()
        append_array_unique(both_keys, sub_data_b.keys())
        for key in both_keys:
            if not sub_data_a.has(key) or not sub_data_b.has(key):
                var present_val: Variant = sub_data_a[key] if sub_data_a.has(key) else sub_data_b[key]
                if typeof(present_val) in [TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY] and not present_val:
                    if sub_data_a.has(CHANE_HyAssetNodeSerializer.MetadataKeys.NodeId):
                        continue
                    else:
                        ret[key] = "FALSEY_MISSING:%s" % [("A" if not sub_data_a.has(key) else "B") + " is missing"]
                else:
                    ret[key] = "MISSING_KEY:%s" % [("A" if not sub_data_a.has(key) else "B") + " is missing"]
                continue
            # Skip Curve Point metadata since Special Manual Curve graph node automatically positions children
            if key.begins_with("CurvePoint-"):
                continue
            var val_diff: Variant = _single_value_plain_data_diff(sub_data_a[key], sub_data_b[key])
            if val_diff != null:
                ret[key] = val_diff
        if ret.is_empty():
            return null
        return ret
    elif val_type == TYPE_ARRAY:
        var ret: Array = []
        var is_dict_vals: bool = sub_data_a.size() > 0 and typeof(sub_data_a[0]) == TYPE_DICTIONARY
        if is_dict_vals and not desorted:
            return _plain_data_diff_desort_dict_arr(sub_data_a, sub_data_b)
        var common_size: = mini(sub_data_a.size(), sub_data_b.size())
        var has_diff: bool = false
        for i in common_size:
            var val_diff: Variant = _single_value_plain_data_diff(sub_data_a[i], sub_data_b[i])
            if val_diff == null:
                ret.append("NO_CHANGE")
            else:
                has_diff = true
                ret.append(val_diff)
        if not has_diff:
            ret.clear()
        if maxi(sub_data_a.size(), sub_data_b.size()) > common_size:
            var a_larger: bool = sub_data_a.size() > common_size
            var extra_size: int = maxi(sub_data_a.size(), sub_data_b.size()) - common_size
            ret.append("LENGTH: %s has %d extra elements" % ["A" if a_larger else "B", extra_size])
        if ret.size() == 0:
            return null
        return ret
    else:
        return "NOT ARRAY OR DICT"

func _single_value_plain_data_diff(sub_data_a: Variant, sub_data_b: Variant) -> Variant:
    var a_is_num: = typeof(sub_data_a) in [TYPE_INT, TYPE_FLOAT]
    var b_is_num: = typeof(sub_data_b) in [TYPE_INT, TYPE_FLOAT]
    if a_is_num and b_is_num:
        if float(sub_data_a) != float(sub_data_b):
            return "MISMATCHED_NUMBERS:%s:%s" % [sub_data_a, sub_data_b]
    elif typeof(sub_data_a) != typeof(sub_data_b):
        return "MISMATCHED_TYPES:%s:%s" % [type_string(typeof(sub_data_a)), type_string(typeof(sub_data_b))]
    elif typeof(sub_data_a) == TYPE_DICTIONARY or typeof(sub_data_a) == TYPE_ARRAY:
        return _plain_data_diff(sub_data_a, sub_data_b)
    
    if sub_data_a == sub_data_b:
        return null
    return ["!=", sub_data_a, sub_data_b]

func _plain_data_diff_desort_dict_arr(sub_data_a: Array, sub_data_b: Array) -> Variant:
    if sub_data_a.size() > 0 and typeof(sub_data_a[0]) == TYPE_DICTIONARY and sub_data_a[0].has("$name"):
        return _group_sorted_dict_arr(sub_data_a, sub_data_b)
    var non_dict_vals: Array[Variant] = []

    var a_dicts: Array[Dictionary] = []
    for i in sub_data_a.size():
        if typeof(sub_data_a[i]) == TYPE_DICTIONARY:
            a_dicts.append(sub_data_a[i])
        else:
            non_dict_vals.append(sub_data_a[i])
    var b_dicts: Array[Dictionary] = []
    for i in sub_data_b.size():
        if typeof(sub_data_b[i]) == TYPE_DICTIONARY:
            b_dicts.append(sub_data_b[i])
        else:
            non_dict_vals.append(sub_data_b[i])
    
    var unmatched_a_indices: Array = []
    var unmatched_b_indices: Array = range(b_dicts.size())
    var sorted_a: Array[Dictionary] = []
    var sorted_b: Array[Dictionary] = []
    for a_idx in a_dicts.size():
        var a_dict: Dictionary = a_dicts[a_idx]
        var was_matched: bool = false
        for b_idx in b_dicts.size():
            if _loose_dict_match(a_dict, b_dicts[b_idx], 1):
                was_matched = true
                unmatched_b_indices.erase(b_idx)
                sorted_a.append(a_dict)
                sorted_b.append(b_dicts[b_idx])
                break
        if not was_matched:
            unmatched_a_indices.append(a_idx)
    
    for a_idx in unmatched_a_indices:
        sorted_a.append(a_dicts[a_idx])
    for b_idx in unmatched_b_indices:
        sorted_b.append(b_dicts[b_idx])

    return _plain_data_diff(sorted_a, sorted_b, true)

func _group_sorted_dict_arr(sub_data_a: Array, sub_data_b: Array) -> Variant:
    var groups_a: Array[Dictionary] = []
    for i in sub_data_a.size():
        if typeof(sub_data_a[i]) == TYPE_DICTIONARY and sub_data_a[i].has("$name"):
            var unpositioned_group: Dictionary = sub_data_a[i].duplicate()
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupPosition)
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupHeight)
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupWidth)
            groups_a.append(unpositioned_group)
        else:
            return "NON_GROUP_DICT_VAL_IN_GROUP_LIST"
    var groups_b: Array[Dictionary] = []
    for i in sub_data_b.size():
        if typeof(sub_data_b[i]) == TYPE_DICTIONARY and sub_data_b[i].has("$name"):
            var unpositioned_group: Dictionary = sub_data_b[i].duplicate()
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupPosition)
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupHeight)
            unpositioned_group.erase(CHANE_HyAssetNodeSerializer.MetadataKeys.GroupWidth)
            groups_b.append(unpositioned_group)
        else:
            return "NON_GROUP_DICT_VAL_IN_GROUP_LIST"
    
    var group_sorter: = func(a: Dictionary, b: Dictionary) -> bool: return a["$name"] < b["$name"]
    groups_a.sort_custom(group_sorter)
    groups_b.sort_custom(group_sorter)
    
    return _plain_data_diff(groups_a, groups_b, true)

func _loose_dict_match(dict_a: Dictionary, dict_b: Dictionary, depth: int) -> bool:
    if depth > 1000:
        return true
    if dict_a == dict_b:
        return true
    
    for key_a in dict_a.keys():
        if not dict_b.has(key_a):
            return false
        var val_a: Variant = dict_a[key_a]
        var a_is_num: = typeof(val_a) in [TYPE_INT, TYPE_FLOAT]
        var b_is_num: = typeof(dict_b[key_a]) in [TYPE_INT, TYPE_FLOAT]
        if a_is_num and b_is_num:
            if float(val_a) != float(dict_b[key_a]):
                return false
        elif typeof(val_a) != typeof(dict_b[key_a]):
            return false
        elif typeof(val_a) in [TYPE_STRING, TYPE_BOOL]:
            if val_a != dict_b[key_a]:
                return false
        elif typeof(val_a) == TYPE_DICTIONARY:
            var is_match: = _loose_dict_match(val_a, dict_b[key_a], depth + 1)
            if not is_match:
                return false
        # ignore arrays
    return true

func unique_conn_infos(conn_infos: Array[Dictionary]) -> Array[Dictionary]:
    var stringified: Array[String] = []
    for conn_info in conn_infos:
        var stringified_info: String = JSON.stringify(conn_info, "", false)
        if stringified_info in stringified:
            continue
        stringified.append(stringified_info)
    var unstringified: Array[Dictionary] = []
    for stringified_info in stringified:
        unstringified.append(JSON.parse_string(stringified_info))
    return unstringified