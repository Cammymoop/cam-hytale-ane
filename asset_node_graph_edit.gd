extends GraphEdit

@export_file_path("*.json") var test_json_file: String = ""

@export var schema: AssetNodesSchema

var parsed_json_data: Dictionary = {}
var loaded: = false

var hy_workspace_id: String = ""

var all_asset_nodes: Array[HyAssetNode] = []
var floating_tree_roots: Array[HyAssetNode] = []
var root_node: HyAssetNode = null

var asset_node_meta: Dictionary[String, Dictionary] = {}

@export var override_types: Dictionary[String, String] = {
    "BlockSet|BlockSet": "__BlockSubset", 
    "Manual|Points": "Point", 
}

@export var no_left_types: Array[String] = [
    "__BiomeRoot",
]


var typeless_subnode_registry: Dictionary[String, Array] = {}

var gn_lookup: Dictionary[String, GraphNode] = {}
var an_lookup: Dictionary[String, HyAssetNode] = {}

var more_type_names: Dictionary[String, int] = {
    "Single": 1,
    "Multi": 2,
}
var type_id_lookup: Dictionary[String, int] = {}

@export var use_json_positions: = true
var relative_root_position: Vector2 = Vector2(0, 0)

var temp_pos: Vector2 = Vector2(-2200, 600)
@onready var temp_origin: Vector2 = temp_pos
var temp_x_sep: = 200
var temp_y_sep: = 260
var temp_x_elements: = 10 

@export var gn_min_width: = 140
@export var text_field_def_characters: = 12

@export var type_colors: Array[Color] = [
    Color.LIGHT_BLUE,
    Color.RED,
    Color.GREEN,
    Color.BLUE,
    Color.YELLOW,
    Color.PURPLE,
    Color.ORANGE,
    Color.BROWN,
]

@export var verbose: = false

var copied_nodes: Array[GraphNode] = []

func _ready() -> void:
    right_disconnects = true
    #add_valid_left_disconnect_type(1)
    
    connection_request.connect(_connection_request)
    disconnection_request.connect(_disconnection_request)
    
    for extra_type_name in more_type_names.keys():
        type_names[more_type_names[extra_type_name]] = extra_type_name
    for type_id in type_names.keys():
        type_id_lookup[type_names[type_id]] = type_id

    #cut_nodes_request.connect(_cut_nodes)
    if test_json_file:
        var file = FileAccess.open(test_json_file, FileAccess.READ)
        parsed_json_data = JSON.parse_string(file.get_as_text())
        if not parsed_json_data:
            print("Error parsing JSON %s" % test_json_file)
            return
        parse_root_asset_node(parsed_json_data)
        create_graph_from_parsed_data()
        loaded = true
        prints("Loaded %s, Workspace ID: %s" % [test_json_file, hy_workspace_id])
    else:
        print("No test JSON file specified")

func _connection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    #prints("Connection request:", from_gn_name, from_port, to_gn_name, to_port)
    connect_node(from_gn_name, from_port, to_gn_name, to_port)

func _disconnection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    #prints("Disconnection request:", from_gn_name, from_port, to_gn_name, to_port)
    disconnect_node(from_gn_name, from_port, to_gn_name, to_port)

func get_selected_gns() -> Array[GraphNode]:
    var selected_gns: Array[GraphNode] = []
    for c in get_children():
        if c is GraphNode and c.selected:
            selected_gns.append(c)
    return selected_gns

func _cut_nodes() -> void:
    var selected_gns: Array[GraphNode] = get_selected_gns()
    copied_nodes = selected_gns
    for gn in selected_gns:
        remove_child(gn)

func _copy_nodes() -> void:
    copied_nodes = get_selected_gns()

func create_graph_from_parsed_data() -> void:
    await get_tree().create_timer(0.1).timeout
    
    #print("Loaded asset nodes:")
    #print_asset_node_list()
    
    if use_json_positions:
        pass#relative_root_position = get_node_position_from_meta(root_node.an_node_id)
    
    make_graph_stuff()
    
    await get_tree().process_frame
    var root_gn: = gn_lookup[root_node.an_node_id]
    scroll_offset = root_gn.position_offset * zoom
    scroll_offset -= (get_viewport_rect().size / 2) 

func get_node_position_from_meta(node_id: String) -> Vector2:
    var node_meta: Dictionary = asset_node_meta.get(node_id, {}) as Dictionary
    var meta_pos: Dictionary = node_meta.get("$Position", {"$x": relative_root_position.x, "$y": relative_root_position.y - 560})
    return Vector2(meta_pos["$x"], meta_pos["$y"])
    
func print_asset_node_list() -> void:
    var more_than_ten: = all_asset_nodes.size() > 10
    for asset_node in all_asset_nodes.slice(0, 10):
        prints("Asset Node || '%s' (%s)" % [asset_node.an_name, asset_node.an_node_id])
    if more_than_ten:
        prints("... (Total: %d)" % all_asset_nodes.size())
    
    for parent_type in typeless_subnode_registry.keys():
        prints("Typeless subnode registry: %s -> %s" % [parent_type, typeless_subnode_registry[parent_type]])

func parse_asset_node_shallow(asset_node_data: Dictionary) -> HyAssetNode:
    if not asset_node_data:
        print_debug("Asset node data is empty")
        return null
    if not asset_node_data.has("$NodeId"):
        print_debug("Asset node data does not have a $NodeId, it is probably not an asset node")
        return null
    
    var asset_node = HyAssetNode.new()
    asset_node.an_node_id = asset_node_data["$NodeId"]
    
    if an_lookup.has(asset_node.an_node_id):
        print_debug("Warning: Asset node with ID %s already exists in lookup, overriding..." % asset_node.an_node_id)
    an_lookup[asset_node.an_node_id] = asset_node
    
    asset_node.an_name = asset_node_data.get("Name", "<NO NAME>")
    if verbose and not asset_node_data.has("Type"):
        print_debug("Typeless node, keys: %s" % [asset_node_data.keys()])
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

func _inner_parse_asset_node_deep(asset_node_data: Dictionary) -> Dictionary:
    var parsed_node: = parse_asset_node_shallow(asset_node_data)
    var all_nodes: Array[HyAssetNode] = [parsed_node]
    for conn in parsed_node.connections.keys():
        if parsed_node.is_connection_empty(conn):
            continue
        
        var conn_nodes_data: = parsed_node.get_raw_connected_nodes(conn)
        for conn_node_idx in conn_nodes_data.size():
            var sub_parse_result: = _inner_parse_asset_node_deep(conn_nodes_data[conn_node_idx])
            all_nodes.append_array(sub_parse_result["all_nodes"])
            parsed_node.set_connection(conn, conn_node_idx, sub_parse_result["base"])

    parsed_node.has_inner_asset_nodes = true
    
    return {"base": parsed_node, "all_nodes": all_nodes}

func register_typeless_subnodes_for_tree(tree_root: HyAssetNode) -> void:
    for conn in tree_root.connections.keys():
        for sub_index in tree_root.num_connected_asset_nodes(conn):
            var sub_node: = tree_root.get_connected_node(conn, sub_index)
            if sub_node.an_type == "<NO TYPE>":
                var name_pattern: = "%s|%s" % [tree_root.an_type, conn]
                if override_types.has(name_pattern):
                    sub_node.an_type = override_types[name_pattern]
                elif tree_root.an_type == "<NO TYPE>":
                    print_debug("Unable to register typeless subnode for typeless parent: %s | %s" % [tree_root.an_node_id, conn])
                else:
                    register_typeless_subnode(tree_root, conn)
            register_typeless_subnodes_for_tree(sub_node)

func parse_asset_node_deep(asset_node_data: Dictionary) -> Dictionary:
    var res: = _inner_parse_asset_node_deep(asset_node_data)
    register_typeless_subnodes_for_tree(res["base"])
    return res

func parse_root_asset_node(base_node: Dictionary) -> void:
    if not base_node.has("Type"):
        base_node["Type"] = get_fallback_root_type(base_node)
    else:
        prints("Root node has a Type key (unexpected): %s fallback type would be: %s" % [base_node["Type"], get_fallback_root_type(base_node)])

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

func register_typeless_subnode(parent_node: HyAssetNode, connection_name: String) -> void:
    if parent_node.an_type == "<NO TYPE>":
        print("Register typeless subnode failed, parent node has no type :: connection: %s" % [connection_name])
        if verbose:
            prints("Parent node data: %s" % [parent_node.raw_tree_data])
        return
    
    if not typeless_subnode_registry.has(parent_node.an_type):
        var new_array: Array[String] = []
        typeless_subnode_registry[parent_node.an_type] = new_array
    
    if not typeless_subnode_registry[parent_node.an_type].has(connection_name):
        typeless_subnode_registry[parent_node.an_type].append(connection_name)


func make_graph_stuff() -> void:
    if not loaded or not root_node:
        print_debug("Make graph: Not loaded or no root node")
        return
    
    for asset_node in all_asset_nodes:
        var graph_node: = new_graph_node(asset_node)
        if not use_json_positions:
            graph_node.position_offset = Vector2(0, -500)
        add_child(graph_node)
        if graph_node.size.x < gn_min_width:
            graph_node.size.x = gn_min_width
    
    if use_json_positions:
        connect_children(root_node.an_node_id)
    else:
        move_and_connect_children(root_node.an_node_id, Vector2(0, 100))
    
    for floating_root in floating_tree_roots:
        var graph_node: = gn_lookup[floating_root.an_node_id]
        temp_pos.x += temp_x_sep
        if temp_pos.x >= temp_x_sep * temp_x_elements:
            temp_pos.x = temp_origin.x
            temp_pos.y += temp_y_sep

        if use_json_positions:
            connect_children(floating_root.an_node_id)
        else:
            graph_node.position_offset = temp_pos

func connect_children(asset_node_id: String) -> void:
    var graph_node: = gn_lookup[asset_node_id]
    var asset_node: = an_lookup[asset_node_id]
    var connection_names: Array[String] = asset_node.connections.keys()
    for conn_idx in connection_names.size():
        var conn_name: = connection_names[conn_idx]
        for connected_node_idx in asset_node.num_connected_asset_nodes(conn_name):
            var conn_an: = asset_node.get_connected_node(conn_name, connected_node_idx)
            if not conn_an:
                continue
            var conn_gn: = gn_lookup[conn_an.an_node_id]
            connect_node(graph_node.name, conn_idx, conn_gn.name, 0)
            
            if conn_an.connections.size() > 0:
                connect_children(conn_an.an_node_id)

func move_and_connect_children(asset_node_id: String, pos: Vector2) -> int:
    var graph_node: = gn_lookup[asset_node_id]
    var asset_node: = an_lookup[asset_node_id]
    graph_node.position_offset = pos

    var child_pos: = pos + (Vector2.RIGHT * (graph_node.size.x + 40))
    var connection_names: Array[String] = asset_node.connections.keys()

    for conn_idx in connection_names.size():
        var conn_name: = connection_names[conn_idx]
        for connected_node_idx in asset_node.num_connected_asset_nodes(conn_name):
            var conn_an: = asset_node.get_connected_node(conn_name, connected_node_idx)
            if not conn_an:
                continue
            var conn_gn: = gn_lookup[conn_an.an_node_id]
            if not conn_gn:
                print_debug("Warning: Graph Node for Asset Node %s not found" % conn_an.an_node_id)
                continue

            if conn_an.connections.size() > 0:
                child_pos.y = move_and_connect_children(conn_an.an_node_id, child_pos)
            else:
                conn_gn.position_offset = child_pos
                child_pos.y += conn_gn.size.y + 40
            connect_node(graph_node.name, conn_idx, conn_gn.name, 0)
    
    return int(child_pos.y)

func new_graph_node(asset_node: HyAssetNode) -> CustomGraphNode:
    var graph_node: = CustomGraphNode.new()
    graph_node.set_meta("hy_asset_node_id", asset_node.an_node_id)
    gn_lookup[asset_node.an_node_id] = graph_node
    
    graph_node.resizable = true
    graph_node.ignore_invalid_connection_type = true

    if asset_node.an_type == "<NO TYPE>":
        graph_node.title = "()" if asset_node.an_name == "<NO NAME>" else "(%s)" % asset_node.an_name
    else:
        if asset_node.an_name == "<NO NAME>":
            graph_node.title = schema.get_node_type_default_name(asset_node.an_type)
        else:
            graph_node.title = asset_node.an_name
    
    var num_inputs: = 1
    if asset_node.an_type in no_left_types:
        num_inputs = 0
    
    var connection_names: = asset_node.connections.keys()
    var num_outputs: = connection_names.size()
    
    var setting_names: = asset_node.settings.keys()
    var num_settings: = setting_names.size()
    
    var first_setting_slot: = maxi(num_inputs, num_outputs)
    
    for i in maxi(num_inputs, num_outputs) + num_settings:
        if i >= first_setting_slot:
            var slot_node: = HBoxContainer.new()
            slot_node.name = "Slot%d" % i
            var s_name: = Label.new()
            s_name.name = "SettingName"
            s_name.text = "%s:" % setting_names[i - first_setting_slot]
            s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            slot_node.add_child(s_name, true)

            var s_edit: Control
            var setting_value: Variant = asset_node.settings[setting_names[i - first_setting_slot]]
            var setting_type: int = typeof(setting_value)
            if setting_type == TYPE_BOOL:
                s_edit = CheckBox.new()
                s_edit.name = "SettingEdit"
                s_edit.button_pressed = setting_value
            else:
                s_edit = LineEdit.new()
                s_edit.name = "SettingEdit"
                s_edit.text = str(setting_value)
                s_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                s_name.size_flags_horizontal = Control.SIZE_FILL
                if setting_type == TYPE_FLOAT or setting_type == TYPE_INT:
                    s_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
            slot_node.add_child(s_edit, true)
            
            graph_node.add_child(slot_node, true)
        else:
            var slot_node: = Label.new()
            slot_node.name = "Slot%d" % i
            graph_node.add_child(slot_node, true)
            if i < num_inputs:
                graph_node.set_slot_enabled_left(i, true)
                graph_node.set_slot_type_left(i, type_id_lookup["Single"])
            if i < num_outputs:
                graph_node.set_slot_enabled_right(i, true)
                graph_node.set_slot_type_right(i, type_id_lookup["Single"])
                slot_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
                slot_node.text = connection_names[i]
    
    if use_json_positions:
        var meta_pos: = get_node_position_from_meta(asset_node.an_node_id)
        graph_node.position_offset = meta_pos - relative_root_position
    
    return graph_node

func get_fallback_root_type(root_node_data: Dictionary) -> String:
    if not root_node_data.has("$WorkspaceID"):
        return "__Root"
    if not root_node_data["$WorkspaceID"] in workspace_root_types:
        print_debug("Workspace ID %s not found in workspace_root_types overrides" % root_node_data["$WorkspaceID"])
        return "__Root"
    return workspace_root_types[root_node_data["$WorkspaceID"]]