extends GraphEdit
class_name AssetNodeGraphEdit

@export_file_path("*.json") var test_json_file: String = ""

@export var schema: AssetNodesSchema

var parsed_json_data: Dictionary = {}
var loaded: = false

var hy_workspace_id: String = ""

var all_asset_nodes: Array[HyAssetNode] = []
var floating_tree_roots: Array[HyAssetNode] = []
var root_node: HyAssetNode = null

@onready var special_gn_factory: SpecialGNFactory = $SpecialGNFactory

var asset_node_meta: Dictionary[String, Dictionary] = {}

@export var no_left_types: Array[String] = [
    "BiomeRoot",
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
@export var json_positions_scale: Vector2 = Vector2(0.5, 0.5)
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

var special_handling_types: Array[String] = [
    "ManualCurve",
]

func _ready() -> void:
    right_disconnects = true
    #add_valid_left_disconnect_type(1)
    
    connection_request.connect(_connection_request)
    disconnection_request.connect(_disconnection_request)
    delete_nodes_request.connect(_delete_request)
    
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

func _delete_request(delete_gn_names: Array[StringName]) -> void:
    for gn_name in delete_gn_names:
        var gn: GraphNode = get_node(NodePath(gn_name))
        if gn:
            if gn.get_meta("hy_asset_node_id", ""):
                var an_id: String = gn.get_meta("hy_asset_node_id")
                var asset_node: HyAssetNode = an_lookup.get(an_id, null)
                if asset_node:
                    asset_node.queue_free()
                an_lookup.erase(an_id)
                gn_lookup.erase(an_id)
            gn.queue_free()

func get_unique_id(id_prefix: String = "") -> String:
    return "%s-%s" % [id_prefix, Util.unique_id_string()]

func get_new_asset_node(asset_node_type: String, id_prefix: String = "") -> HyAssetNode:
    if id_prefix == "" and asset_node_type and asset_node_type != "Unknown":
        id_prefix = schema.get_id_prefix_for_node_type(asset_node_type)
    elif id_prefix == "":
        print_debug("New asset node: No ID prefix provided, and asset node type is unknown or empty")
        return null

    var new_asset_node: = HyAssetNode.new()
    new_asset_node.an_node_id = get_unique_id(id_prefix)
    new_asset_node.an_type = asset_node_type
    all_asset_nodes.append(new_asset_node)
    an_lookup[new_asset_node.an_node_id] = new_asset_node
    return new_asset_node

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

func parse_asset_node_shallow(asset_node_data: Dictionary, output_value_type: String = "", known_node_type: String = "") -> HyAssetNode:
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
    

    if known_node_type != "":
        asset_node.an_type = known_node_type
    elif output_value_type != "ROOT":
        asset_node.an_type = schema.resolve_asset_node_type(asset_node_data.get("Type", "NO_TYPE_KEY"), output_value_type, asset_node.an_node_id)
        if output_value_type == "":
            print_debug("No output value type provided, inferred type from ID prefix: %s" % asset_node.an_type)
    
    var type_schema: = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        type_schema = schema.node_schema[asset_node.an_type]

    asset_node.an_name = schema.get_node_type_default_name(asset_node.an_type)
    if asset_node_meta and asset_node_meta.has(asset_node.an_node_id) and asset_node_meta[asset_node.an_node_id].has("$Title"):
        asset_node.an_name = asset_node_meta[asset_node.an_node_id]["$Title"]
    asset_node.raw_tree_data = asset_node_data.duplicate(true)
    
    var connections_schema: Dictionary = type_schema.get("connections", {})
    for conn_name in connections_schema.keys():
        if connections_schema[conn_name].get("multi", false):
            asset_node.connections[conn_name] = []
        else:
            asset_node.connections[conn_name] = null
    
    var settings_schema: Dictionary = type_schema.get("settings", {})
    for setting_name in settings_schema.keys():
        asset_node.settings[setting_name] = settings_schema[setting_name].get("default_value", null)

    # fill out stuff in data even if it isn't in the schema
    for other_key in asset_node_data.keys():
        if other_key.begins_with("$") or HyAssetNode.special_keys.has(other_key):
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

func _inner_parse_asset_node_deep(asset_node_data: Dictionary, output_value_type: String = "", base_node_type: String = "") -> Dictionary:
    var parsed_node: = parse_asset_node_shallow(asset_node_data, output_value_type, base_node_type)
    var all_nodes: Array[HyAssetNode] = [parsed_node]
    for conn in parsed_node.connections.keys():
        if parsed_node.is_connection_empty(conn):
            continue
        
        var conn_nodes_data: = parsed_node.get_raw_connected_nodes(conn)
        for conn_node_idx in conn_nodes_data.size():
            var conn_value_type: = "Unknown"
            if parsed_node.an_type != "Unknown":
                conn_value_type = schema.node_schema[parsed_node.an_type]["connections"][conn]["value_type"]

            var sub_parse_result: = _inner_parse_asset_node_deep(conn_nodes_data[conn_node_idx], conn_value_type)
            all_nodes.append_array(sub_parse_result["all_nodes"])
            parsed_node.set_connection(conn, conn_node_idx, sub_parse_result["base"])
        parsed_node.set_connection_count(conn, conn_nodes_data.size())

    parsed_node.has_inner_asset_nodes = true
    
    return {"base": parsed_node, "all_nodes": all_nodes}

func parse_asset_node_deep(asset_node_data: Dictionary, output_value_type: String = "", base_node_type: String = "") -> Dictionary:
    var res: = _inner_parse_asset_node_deep(asset_node_data, output_value_type, base_node_type)
    return res

func parse_root_asset_node(base_node: Dictionary) -> void:
    hy_workspace_id = "NONE"
    if not base_node.has("$NodeEditorMetadata") or not base_node["$NodeEditorMetadata"] is Dictionary:
        print_debug("Root node does not have $NodeEditorMetadata")
    else:
        var meta_data: = base_node["$NodeEditorMetadata"] as Dictionary

        for node_id in meta_data.get("$Nodes", {}).keys():
            asset_node_meta[node_id] = meta_data["$Nodes"][node_id]

        for floating_tree in meta_data.get("$FloatingNodes", []):
            var floating_parse_result: = parse_asset_node_deep(floating_tree)
            floating_tree_roots.append(floating_parse_result["base"])
            all_asset_nodes.append_array(floating_parse_result["all_nodes"])
        
        hy_workspace_id = meta_data.get("$WorkspaceID", "NONE")

    if hy_workspace_id == "NONE" and base_node.has("$WorkspaceID"):
        hy_workspace_id = base_node["$WorkspaceID"]

    var root_node_type: = "Unknown"
    if hy_workspace_id == "NONE":
        print_debug("No workspace ID found in root node or editor metadata")
    else:
        root_node_type = schema.resolve_asset_node_type(base_node.get("Type", "NO_TYPE_KEY"), "ROOT|%s" % hy_workspace_id, base_node.get("$NodeId", ""))
        print("Root node type: %s" % root_node_type)

    var parse_result: = parse_asset_node_deep(base_node, "", root_node_type)
    root_node = parse_result["base"]
    all_asset_nodes = parse_result["all_nodes"]
        
    
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
    
    var all_root_nodes: Array[HyAssetNode] = [root_node]
    all_root_nodes.append_array(floating_tree_roots)
    
    var base_tree_pos: = Vector2(0, 100)
    for tree_root_node in all_root_nodes:
        var new_graph_nodes: Array[CustomGraphNode] = new_graph_nodes_for_tree(tree_root_node)
        for new_gn in new_graph_nodes:
            if not use_json_positions:
                new_gn.position_offset = Vector2(0, -500)
            add_child(new_gn)
            if new_gn.size.x < gn_min_width:
                new_gn.size.x = gn_min_width
        
        if use_json_positions:
            connect_children(new_graph_nodes[0])
        else:
            var last_y: int = move_and_connect_children(tree_root_node.an_node_id, base_tree_pos)
            base_tree_pos.y = last_y + 40
    
func connect_children(graph_node: CustomGraphNode) -> void:
    var connection_names: Array[String] = get_graph_connections_for(graph_node)
    for conn_idx in connection_names.size():
        var connected_graph_nodes: Array[GraphNode] = get_graph_connected_graph_nodes(graph_node, connection_names[conn_idx])
        for connected_gn in connected_graph_nodes:
            connect_node(graph_node.name, conn_idx, connected_gn.name, 0)
            connect_children(connected_gn)

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

func new_graph_nodes_for_tree(tree_root_node: HyAssetNode) -> Array[CustomGraphNode]:
    return _recursive_new_graph_nodes(tree_root_node, tree_root_node)

func _recursive_new_graph_nodes(at_asset_node: HyAssetNode, root_asset_node: HyAssetNode) -> Array[CustomGraphNode]:
    var new_graph_nodes: Array[CustomGraphNode] = []

    var this_gn: = new_graph_node(at_asset_node, root_asset_node)
    new_graph_nodes.append(this_gn)

    for conn_name in get_graph_connections_for(this_gn):
        var connected_nodes: Array[HyAssetNode] = get_graph_connected_asset_nodes(this_gn, conn_name)
        for connected_asset_node in connected_nodes:
            new_graph_nodes.append_array(_recursive_new_graph_nodes(connected_asset_node, root_asset_node))
    return new_graph_nodes

func get_graph_connections_for(graph_node: CustomGraphNode) -> Array[String]:
    if graph_node.get_meta("is_special_gn", false):
        return graph_node.get_current_connection_list()
    else:
        var asset_node: = an_lookup[graph_node.get_meta("hy_asset_node_id")]
        return asset_node.connection_list

func get_graph_connected_asset_nodes(graph_node: CustomGraphNode, conn_name: String) -> Array[HyAssetNode]:
    if graph_node.get_meta("is_special_gn", false):
        return graph_node.filter_child_connection_nodes(conn_name)
    else:
        var asset_node: = an_lookup[graph_node.get_meta("hy_asset_node_id")]
        return asset_node.get_all_connected_nodes(conn_name)

func get_graph_connected_graph_nodes(graph_node: CustomGraphNode, conn_name: String) -> Array[GraphNode]:
    var connected_asset_nodes: Array[HyAssetNode] = get_graph_connected_asset_nodes(graph_node, conn_name)
    var connected_graph_nodes: Array[GraphNode] = []
    for connected_asset_node in connected_asset_nodes:
        connected_graph_nodes.append(gn_lookup[connected_asset_node.an_node_id])
    return connected_graph_nodes


func should_be_special_gn(asset_node: HyAssetNode) -> bool:
    return special_gn_factory.types_with_special_nodes.has(asset_node.an_type)

func new_graph_node(asset_node: HyAssetNode, root_asset_node: HyAssetNode) -> CustomGraphNode:
    var graph_node: CustomGraphNode = null
    var is_special: = should_be_special_gn(asset_node)
    if is_special:
        print_debug("Making special GN for asset node type %s" % asset_node.an_type)
        graph_node = special_gn_factory.make_special_gn(root_asset_node, asset_node)
    else:
        graph_node = CustomGraphNode.new()

    graph_node.set_meta("hy_asset_node_id", asset_node.an_node_id)
    gn_lookup[asset_node.an_node_id] = graph_node
    
    graph_node.resizable = true
    graph_node.ignore_invalid_connection_type = true

    graph_node.title = asset_node.an_name
    
    if is_special:
        pass
    else:
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
        var meta_pos: = get_node_position_from_meta(asset_node.an_node_id) * json_positions_scale
        graph_node.position_offset = meta_pos - relative_root_position
    
    return graph_node