extends GraphEdit

@export_file_path("*.json") var test_json_file: String = ""

var parsed_data: Dictionary = {}
var loaded: = false

var hy_workspace_id: String = ""

var all_asset_nodes: Array[HyAssetNode] = []
var floating_tree_roots: Array[HyAssetNode] = []
var root_node: HyAssetNode = null

var asset_node_meta: Dictionary[String, Dictionary] = {}

@export var verbose: = false

func _ready() -> void:
    if test_json_file:
        var file = FileAccess.open(test_json_file, FileAccess.READ)
        parsed_data = JSON.parse_string(file.get_as_text())
        if not parsed_data:
            print("Error parsing JSON %s" % test_json_file)
            return
        parse_root_asset_node(parsed_data)
        create_graph_from_parsed_data()
        loaded = true
    else:
        print("No test JSON file specified")

func create_graph_from_parsed_data() -> void:
    await get_tree().create_timer(0.1).timeout
    
    for asset_node in all_asset_nodes:
        prints("Asset Node || '%s' (%s)" % [asset_node.an_name, asset_node.an_node_id])

func parse_asset_node_shallow(asset_node_data: Dictionary) -> HyAssetNode:
    if not asset_node_data:
        print_debug("Asset node data is empty")
        return null
    if not asset_node_data.has("$NodeId"):
        print_debug("Asset node data does not have a $NodeId, it is probably not an asset node")
        return null

    var asset_node = HyAssetNode.new()
    asset_node.an_node_id = asset_node_data["$NodeId"]
    
    asset_node.an_name = asset_node_data.get("Name", "<NO NAME>")
    if not asset_node_data.has("Type"):
        print_debug("Asset node has no Type key, keys: %s" % [asset_node_data.keys()])
    asset_node.an_type = asset_node_data.get("Type", "<NO TYPE>")
    asset_node.raw_tree_data = asset_node_data.duplicate(true)
    
    for other_key in asset_node_data.keys():
        if HyAssetNode.special_keys.has(other_key) or other_key.begins_with("$"):
            continue
        
        var connected_data = check_for_asset_nodes(asset_node_data[other_key])
        if connected_data != null:
            if verbose:
                var short_data: = str(connected_data).substr(0, 12) + "..."
                prints("Node '%s' (%s) Connection '%s' has connected nodes: %s" % [asset_node.an_name, asset_node.an_type, other_key, short_data])
            asset_node.connections[other_key] = connected_data
        else:
            if verbose:
                var short_data: = str(asset_node_data[other_key])
                short_data = short_data.substr(0, 50) + ("..." if short_data.length() > 50 else "")
                prints("Node '%s' (%s) Connection '%s' is just data: %s" % [asset_node.an_name, asset_node.an_type, other_key, short_data])
            asset_node.settings[other_key] = asset_node_data[other_key]
    
    return asset_node

func parse_asset_node_deep(asset_node_data: Dictionary) -> Dictionary:
    var parsed_node: = parse_asset_node_shallow(asset_node_data)
    var all_nodes: Array[HyAssetNode] = [parsed_node]
    for conn in parsed_node.connections.keys():
        if parsed_node.is_connection_empty(conn):
            continue
        
        var conn_nodes_data: = parsed_node.get_raw_connected_nodes(conn)
        for conn_node_idx in conn_nodes_data.size():
            var sub_parse_result: = parse_asset_node_deep(conn_nodes_data[conn_node_idx])
            all_nodes.append_array(sub_parse_result["all_nodes"])
            parsed_node.set_connection(conn, conn_node_idx, sub_parse_result["base"])
    parsed_node.has_inner_asset_nodes = true
    
    return {"base": parsed_node, "all_nodes": all_nodes}

func parse_root_asset_node(base_node: Dictionary) -> void:
    if not base_node.has("Type"):
        print_debug("Root node has no Type key (expected)")
        base_node["Type"] = "_ROOT_"
    else:
        prints("Root node has a Type key (unexpected): %s" % base_node["Type"])

    var parse_result: = parse_asset_node_deep(base_node)
    root_node = parse_result["base"]
    all_asset_nodes = parse_result["all_nodes"]
    
    if not root_node.raw_tree_data.has("$NodeEditorMetadata") or not root_node.raw_tree_data["$NodeEditorMetadata"] is Dictionary:
        print_debug("Root node does not have $NodeEditorMetadata")
    else:
        var meta_data: = root_node.raw_tree_data["$NodeEditorMetadata"] as Dictionary

        for node_id in meta_data.get("$Nodes", {}).keys():
            asset_node_meta[node_id] = meta_data["$Nodes"][node_id]

        for floating_tree in meta_data.get("$FloatingNodes", []):
            var floating_parse_result: = parse_asset_node_deep(floating_tree)
            floating_tree_roots.append(floating_parse_result["base"])
            all_asset_nodes.append_array(floating_parse_result["all_nodes"])
        
        hy_workspace_id = meta_data.get("$WorkspaceID", "NONE")
    
    loaded = true

func check_for_asset_nodes(val: Variant) -> Variant:
    if val is Dictionary:
        if val.is_empty() or val.has("$NodeId"):
            return val
    elif val is Array:
        if val.size() == 0 or val[0] is Dictionary and val[0].has("$NodeId"):
            return val
    return null