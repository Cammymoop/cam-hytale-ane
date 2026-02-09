extends Node

var enable_system_clipboard: = true
var pretty_print_json: = true

func _ready() -> void:
    if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
        if enable_system_clipboard:
            push_warning("Clipboard is not supported")
            print("Clipboard is not supported")
        enable_system_clipboard = false
    if not OS.has_feature("editor"):
        pretty_print_json = false

func send_copied_nodes_to_clipboard(graph_edit: AssetNodeGraphEdit) -> void:
    if not enable_system_clipboard:
        print("copying but clipboard is not enabled")
        return
    var serialized_data: String = serialize_copied_nodes(graph_edit)
    var data_stamp: String = "[CamHytaleANE_CLIPBOARD]((%s))" % graph_edit.in_graph_copy_id
    DisplayServer.clipboard_set(data_stamp + serialized_data)

func load_copied_nodes_from_clipboard(graph_edit: AssetNodeGraphEdit) -> bool:
    if not enable_system_clipboard or not DisplayServer.clipboard_has():
        print("checking for paste but clipboard is not enabled")
        return false
    var raw_clipboard_data: String = DisplayServer.clipboard_get()
    if not raw_clipboard_data.begins_with("[CamHytaleANE_CLIPBOARD](("):
        return false

    var parsed_data: Dictionary = parse_clipboard_data(raw_clipboard_data, graph_edit.in_graph_copy_id)
    if not parsed_data:
        return false
    if not parsed_data.has("included_metadata") or not parsed_data["included_metadata"].has("node_metadata"):
        print_debug("Clipboard data does not have included node metadata")
        return false
    if not parsed_data.has("asset_node_data") or parsed_data["asset_node_data"].size() == 0:
        print_debug("Clipboard data does not have asset node data")
        return false

    make_incoming_nodeids_unique(parsed_data, graph_edit)
    var all_deserialized_ans: Array[HyAssetNode] = deserialize_clipboard_data_roots(parsed_data, graph_edit)

    var node_metadata: Dictionary = parsed_data["included_metadata"]["node_metadata"]
    for an in all_deserialized_ans:
        graph_edit._register_asset_node(an)
        graph_edit.asset_node_meta[an.an_node_id] = node_metadata.get(an.an_node_id, {})

    graph_edit.in_graph_copy_id = parsed_data["copy_id"]
    graph_edit.copied_external_ans = all_deserialized_ans
    graph_edit.clipboard_was_from_external = true
    
    return true

func parse_clipboard_data(clipboard_data: String, current_copy_id: String) -> Dictionary:
    var trimmed: String = clipboard_data.trim_prefix("[CamHytaleANE_CLIPBOARD]((")
    var copy_id_end: int = trimmed.find("))")
    if copy_id_end == -1:
        return {}
    var the_copy_id: String = trimmed.substr(0, copy_id_end)
    if the_copy_id == current_copy_id:
        # If the copy id matches, there's no need to use the system clipboard data
        return {}
    trimmed = trimmed.substr(copy_id_end + 2)
    var parsed_data: Variant = JSON.parse_string(trimmed)
    if not parsed_data or not typeof(parsed_data) == TYPE_DICTIONARY:
        if not parsed_data:
            push_error("Got CHANE clipboard data, but failed to parse it as JSON")
        else:
            push_error("Got CHANE clipboard data, but JSON parse result isn't a dictionary")
        return {}
    parsed_data["copy_id"] = the_copy_id
    return parsed_data

func deserialize_clipboard_data_roots(parsed_clipboard: Dictionary, graph_edit: AssetNodeGraphEdit) -> Array[HyAssetNode]:
    var all_deserialized_ans: Array[HyAssetNode] = []
    var prev_asset_node_meta: Dictionary = graph_edit.asset_node_meta
    var typed_meta: Dictionary[String, Dictionary] = {}
    typed_meta.merge(parsed_clipboard["included_metadata"]["node_metadata"])
    graph_edit.asset_node_meta = typed_meta
    for root_data in parsed_clipboard["asset_node_data"]:
        var tree_root_type: String = SchemaManager.schema._unknown_output_type_inference(root_data["$NodeId"])
        var node_parse_result: = graph_edit.parse_asset_node_deep(false, root_data, "", tree_root_type)
        all_deserialized_ans.append_array(node_parse_result["all_nodes"])
    graph_edit.asset_node_meta = prev_asset_node_meta
    return all_deserialized_ans

func get_copied_asset_node_set(graph_edit: AssetNodeGraphEdit) -> Array[HyAssetNode]:
    var copied_gns: Array[GraphNode] = graph_edit.copied_nodes.duplicate()
    return graph_edit.get_an_set_for_graph_nodes(copied_gns)


func serialize_copied_nodes(graph_edit: AssetNodeGraphEdit) -> String:
    var center_of_mass: Vector2 = Util.average_graph_node_pos_offset(graph_edit.copied_nodes)
    var serialized_data: Dictionary = {
        "what_is_this": "Clipboard data from Cam Hytale Asset Node Editor",
        "copied_from": "CamHytaleANE:%s" % graph_edit.get_plain_version(),
        "asset_node_data": [],
        "included_metadata": {
            "node_metadata": graph_edit.get_metadata_for_gns(graph_edit.copied_nodes, false, center_of_mass),
            "hanging_connections": [],
            "links": [],
            "groups": [],
        }
    }
    var copied_an_set: Array[HyAssetNode] = get_copied_asset_node_set(graph_edit)
    var copied_an_roots: Array[HyAssetNode] = graph_edit.get_an_roots_within_set(copied_an_set)
    print("serializing %s asset nodes" % copied_an_roots.size())
    for copied_an_root in copied_an_roots:
        var serialized_tree: = copied_an_root.serialize_within_set(SchemaManager.schema, graph_edit.gn_lookup, copied_an_set)
        serialized_data["asset_node_data"].append(serialized_tree)
    return JSON.stringify(serialized_data, "  " if pretty_print_json else "", false)

func make_incoming_nodeids_unique(parsed_clipboard: Dictionary, graph_edit: AssetNodeGraphEdit) -> void:
    for root_data in parsed_clipboard["asset_node_data"]:
        make_nodeid_unique_recursive(root_data, graph_edit, parsed_clipboard["included_metadata"]["node_metadata"])

func make_nodeid_unique_recursive(node_data: Dictionary, graph_edit: AssetNodeGraphEdit, metadata_dict: Dictionary) -> void:
    var old_id: String = node_data.get("$NodeId", "")
    if not old_id:
        push_error("Clipboard incoming Node data does not have a $NodeId")
        return
    var id_prefix: String = old_id.substr(0, old_id.find("-"))
    var new_id: String = graph_edit.get_unique_an_id(id_prefix)
    node_data["$NodeId"] = new_id
    if metadata_dict.has(old_id):
        metadata_dict[new_id] = metadata_dict[old_id]
        metadata_dict.erase(old_id)

    for node_data_key in node_data.keys():
        if node_data_key.begins_with("$"):
            continue
        if node_data[node_data_key] is Dictionary:
            make_nodeid_unique_recursive(node_data[node_data_key], graph_edit, metadata_dict)
        elif node_data[node_data_key] is Array:
            for item in node_data[node_data_key]:
                if item is Dictionary:
                    make_nodeid_unique_recursive(item, graph_edit, metadata_dict)