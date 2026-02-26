extends Node

var enable_system_clipboard: = true
var pretty_print_json: = true

@onready var NODE_ID_KEY: String = CHANE_HyAssetNodeSerializer.MetadataKeys.NodeId

func _ready() -> void:
    if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
        if enable_system_clipboard:
            push_warning("Clipboard is not supported")
            print("Clipboard is not supported")
        enable_system_clipboard = false
    if not OS.has_feature("editor"):
        pretty_print_json = false

func send_copied_nodes_to_clipboard(graph_edit: CHANE_AssetNodeGraphEdit) -> void:
    if not enable_system_clipboard:
        print("copying but clipboard is not enabled")
        return
    var serialized_data: String = serialize_copied_nodes(graph_edit)
    var data_stamp: String = "[CamHytaleANE_CLIPBOARD]((%s))" % graph_edit.in_graph_copy_id
    DisplayServer.clipboard_set(data_stamp + serialized_data)

func load_copied_nodes_from_clipboard(graph_edit: CHANE_AssetNodeGraphEdit) -> bool:
    if not enable_system_clipboard:
        print("checking for paste but clipboard is not enabled")
        return false
    if not DisplayServer.clipboard_has():
        # No text to paste
        return false
    var raw_clipboard_data: String = DisplayServer.clipboard_get()
    return load_copied_nodes_from_clipboard_str(graph_edit, raw_clipboard_data)

func load_copied_nodes_from_clipboard_str(graph_edit: CHANE_AssetNodeGraphEdit, clipboard_data: String) -> bool:
    if not clipboard_data.begins_with("[CamHytaleANE_CLIPBOARD](("):
        return false

    var parsed_data: Dictionary = parse_clipboard_data(clipboard_data)
    if not parsed_data:
        return false
    if graph_edit.in_graph_copy_id == parsed_data["copy_id"] and not graph_edit.clipboard_was_from_external:
        # This clipboard data is from the graph edit's current internal copy operation
        return false

    if not parsed_data.has("included_metadata") or not parsed_data["included_metadata"].has("node_metadata"):
        print_debug("Clipboard data does not have included node metadata")
        return false
    if not parsed_data.has("asset_node_data") or parsed_data["asset_node_data"].size() == 0:
        print_debug("Clipboard data does not have asset node data")
        return false

    # re-roll all the ids from the clipboard data to ensure that they are unique
    make_incoming_nodeids_unique(parsed_data)
    var all_tree_results: = deserialize_clipboard_data_roots(parsed_data, graph_edit.editor.serializer)

    var all_deserialized_ans: Array[HyAssetNode] = []
    for tree_result in all_tree_results:
        if not tree_result.success:
            push_error("Failed to deserialize clipboard data")
            CHANE_HyAssetNodeSerializer.debug_dump_tree_results(tree_result)
            return false
        graph_edit.register_tree_result_ans(tree_result)
        all_deserialized_ans.append_array(tree_result.all_nodes)

    graph_edit.in_graph_copy_id = parsed_data["copy_id"]
    graph_edit.copied_external_ans = all_deserialized_ans
    graph_edit.copied_external_node_metadata = parsed_data["included_metadata"]["node_metadata"]
    graph_edit.clipboard_was_from_external = true
    
    load_copied_groups(parsed_data["included_metadata"].get("groups", []), graph_edit)
    
    return true

func load_copied_groups(groups: Array, graph_edit: CHANE_AssetNodeGraphEdit) -> void:
    for group in groups:
        graph_edit.copied_external_groups.append(group)

func parse_clipboard_data(clipboard_data: String) -> Dictionary:
    var trimmed: String = clipboard_data.trim_prefix("[CamHytaleANE_CLIPBOARD]((")
    var copy_id_end: int = trimmed.find("))")
    if copy_id_end == -1:
        push_error("Got CHANE clipboard data, but failed to find end of copy id")
        return {}
    var the_copy_id: String = trimmed.substr(0, copy_id_end)
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

func deserialize_clipboard_data_roots(parsed_clipboard: Dictionary, serializer: CHANE_HyAssetNodeSerializer) -> Array[CHANE_HyAssetNodeSerializer.TreeParseResult]:
    var all_tree_results: Array[CHANE_HyAssetNodeSerializer.TreeParseResult] = []
    var clipboard_nodes_meta: Dictionary[String, Dictionary] = {}
    clipboard_nodes_meta.merge(parsed_clipboard["included_metadata"]["node_metadata"])
    for root_data in parsed_clipboard["asset_node_data"]:
        all_tree_results.append(serializer.parse_asset_node_tree_with_node_meta(root_data, clipboard_nodes_meta, {}))
    return all_tree_results

func serialize_copied_nodes(graph_edit: CHANE_AssetNodeGraphEdit) -> String:
    var copied_gns: Array[GraphNode] = []
    var copied_groups: Array[GraphFrame] = []
    for ge in graph_edit.copied_nodes:
        if ge is CustomGraphNode:
            copied_gns.append(ge)
        elif ge is GraphFrame:
            copied_groups.append(ge)

    var center_of_mass: Vector2 = Util.average_graph_element_pos_offset(graph_edit.copied_nodes)
    
    var serializer: = graph_edit.editor.serializer

    serializer.serialized_pos_scale = Vector2.ONE
    serializer.serialized_pos_offset = center_of_mass
    var serialized_groups: Array[Dictionary] = serializer.serialize_groups(copied_groups)
    var serialized_data: Dictionary = {
        "what_is_this": "Clipboard data from Cam Hytale Asset Node Editor",
        "copied_from": "CamHytaleANE:%s" % Util.get_plain_version(),
        "asset_node_data": [],
        "included_metadata": {
            "node_metadata": serializer.serialize_graph_nodes_metadata(copied_gns),
            "hanging_connections": [],
            "links": [],
            "groups": serialized_groups,
            "workspace_id": graph_edit.hy_workspace_id,
        }
    }

    var copied_an_set: Array[HyAssetNode] = graph_edit.get_an_set_for_graph_nodes(copied_gns)
    var copied_an_roots: Array[HyAssetNode] = CHANE_AssetNodeEditor.get_an_roots_within_set_no_aux(copied_an_set)
    for copied_an_root in copied_an_roots:
        var serialized_tree: = serializer.serialize_asset_node_tree_within_set(copied_an_root, copied_an_set)
        serialized_data["asset_node_data"].append(serialized_tree)
    return JSON.stringify(serialized_data, "  " if pretty_print_json else "", false)

func make_incoming_nodeids_unique(parsed_clipboard: Dictionary) -> void:
    for root_data in parsed_clipboard["asset_node_data"]:
        make_nodeid_unique_recursive(root_data, parsed_clipboard["included_metadata"]["node_metadata"])

func make_nodeid_unique_recursive(node_data: Dictionary, metadata_dict: Dictionary) -> void:
    var old_id: String = node_data.get(NODE_ID_KEY, "")
    if not old_id:
        push_error("Clipboard incoming Node data does not have a %s" % NODE_ID_KEY)
        return
    var id_prefix: String = old_id.substr(0, old_id.find("-"))
    var new_id: String = CHANE_HyAssetNodeSerializer.get_unique_an_id(id_prefix)
    node_data[NODE_ID_KEY] = new_id
    if metadata_dict.has(old_id):
        metadata_dict[new_id] = metadata_dict[old_id]
        metadata_dict.erase(old_id)

    for node_data_key in node_data.keys():
        if node_data_key.begins_with("$"):
            continue
        if node_data[node_data_key] is Dictionary:
            make_nodeid_unique_recursive(node_data[node_data_key], metadata_dict)
        elif node_data[node_data_key] is Array:
            for item in node_data[node_data_key]:
                if item is Dictionary:
                    make_nodeid_unique_recursive(item, metadata_dict)
