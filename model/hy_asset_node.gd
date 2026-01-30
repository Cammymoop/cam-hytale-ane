class_name HyAssetNode
extends Resource

signal settings_changed()

@export var an_node_id: String = ""
@export var an_name: String = ""
@export var an_type: String = ""

@export var title: String = ""
@export var comment: String = ""

@export var connections: Dictionary[String, Variant] = {}
@export var connection_list: Array[String] = []
@export var has_inner_asset_nodes: bool = false
@export var connected_asset_nodes: Dictionary[String, HyAssetNode] = {}
@export var connected_node_counts: Dictionary[String, int] = {}

@export var settings: Dictionary = {}

@export var raw_tree_data: Dictionary = {}

@export var other_metadata: Dictionary = {}

static var special_keys: Array[String] = ["Type"]

func is_connection_empty(conn_name: String) -> bool:
    if has_inner_asset_nodes:
        if not connection_list.has(conn_name):
            print_debug("Connection name %s not found in connection list" % conn_name)
            return true
        return connected_node_counts[conn_name] == 0

    if not connections.has(conn_name):
        print_debug("Connection name %s not found in connection names" % conn_name)
        return true
    if connections[conn_name] == null:
        return true
    var conn_type: = typeof(connections[conn_name])
    if conn_type == TYPE_DICTIONARY and connections[conn_name].is_empty():
        return true
    if conn_type == TYPE_ARRAY and connections[conn_name].size() == 0:
        return true
    return false

func num_connected_asset_nodes(conn_name: String) -> int:
    if has_inner_asset_nodes:
        return _num_connected_asset_nodes_full(conn_name)

    var conn_type: = typeof(connections[conn_name])
    if conn_type == TYPE_DICTIONARY:
        return 1
    if conn_type == TYPE_ARRAY:
        return connections[conn_name].size()
    return 0

func update_setting_value(setting_name: String, value: Variant) -> void:
    settings[setting_name] = value
    settings_changed.emit()

func _num_connected_asset_nodes_full(conn_name: String) -> int:
    if not connected_node_counts.has(conn_name):
        return 0
    return connected_node_counts[conn_name]

func get_raw_connected_nodes(conn_name: String) -> Array:
    if typeof(connections[conn_name]) == TYPE_DICTIONARY:
        return [connections[conn_name]]
    elif typeof(connections[conn_name]) == TYPE_ARRAY:
        return connections[conn_name]
    else:
        print_debug("get_raw_connected_nodes: Connection %s is of an unhandled type: %s" % [conn_name, type_string(typeof(connections[conn_name]))])
        return []


func set_connection(conn_name: String, index: int, asset_node: HyAssetNode) -> void:
    if not connection_list.has(conn_name):
        connection_list.append(conn_name)
        connected_node_counts[conn_name] = 1
    var conn_key: String = "%s:%d" % [conn_name, index]
    if connections.has(conn_name) and typeof(connections[conn_name]) == TYPE_DICTIONARY:
        if index > 0:
            print_debug("Index %s is greater than 0 on a single connection! (%s)" % [index, conn_name])
            return
    connected_asset_nodes[conn_key] = asset_node

func set_connection_count(conn_name: String, count: int) -> void:
    if not connection_list.has(conn_name):
        connection_list.append(conn_name)
    connected_node_counts[conn_name] = count


func append_node_to_connection(conn_name: String, asset_node: HyAssetNode) -> void:
    if not has_inner_asset_nodes:
        print_debug("Trying to append node to a shallow asset node (%s)" % an_node_id)
        return
    if not connected_asset_nodes.has("%s:0" % conn_name):
        if not connection_list.has(conn_name):
            connection_list.append(conn_name)
        connected_asset_nodes["%s:0" % conn_name] = asset_node
        connected_node_counts[conn_name] = 1
    else:
        var next_index: int = connected_node_counts[conn_name]
        connected_asset_nodes["%s:%d" % [conn_name, next_index]] = asset_node
        connected_node_counts[conn_name] = next_index + 1

func append_nodes_to_connection(conn_name: String, asset_nodes: Array[HyAssetNode]) -> void:
    if not has_inner_asset_nodes:
        print_debug("Trying to append nodes to a shallow asset node (%s)" % an_node_id)
        return
    if not connection_list.has(conn_name):
        connection_list.append(conn_name)
    for i in asset_nodes.size():
        connected_asset_nodes["%s:%d" % [conn_name, i]] = asset_nodes[i]
    connected_node_counts[conn_name] = asset_nodes.size()

func remove_node_from_connection(conn_name: String, asset_node: HyAssetNode) -> void:
    if not has_inner_asset_nodes:
        print_debug("Trying to remove node from a shallow asset node (%s)" % an_node_id)
        return
    var found_at_idx: int = -1
    for i in range(connected_node_counts[conn_name]):
        if connected_asset_nodes["%s:%d" % [conn_name, i]] == asset_node:
            found_at_idx = i
            break
    if found_at_idx < 0:
        print_debug("Node %s not found in connection %s" % [asset_node.an_node_id, conn_name])
        return

    remove_node_from_connection_at(conn_name, found_at_idx)

func remove_node_from_connection_at(conn_name: String, at_index: int) -> void:
    if not has_inner_asset_nodes:
        print_debug("Trying to remove node from a shallow asset node (%s) at index %s" % [an_node_id, at_index])
        return
    if at_index < 0 or at_index >= connected_node_counts[conn_name]:
        print_debug("Index %s is out of range for connection %s" % [at_index, conn_name])
        return

    remove_indices_from_connection(conn_name, [at_index])

func insert_node_into_connection_at(conn_name: String, at_index: int, asset_node: HyAssetNode) -> void:
    if at_index < 0 or at_index > connected_node_counts[conn_name]:
        print_debug("Index %s is out of range for connection %s" % [at_index, conn_name])
        return
    if connected_node_counts[conn_name] == at_index:
        append_node_to_connection(conn_name, asset_node)
    else:
        _reindex_connection(conn_name, -1, {at_index: asset_node})

func remove_indices_from_connection(conn_name: String, indices: Array[int]) -> void:
    for idx in indices:
        connected_asset_nodes.erase("%s:%d" % [conn_name, idx])
    _reindex_connection(conn_name)

func _reindex_connection(conn_name: String, max_index: int = -1, insert_nodes: Dictionary[int, HyAssetNode] = {}) -> void:
    if max_index < 0:
        max_index = connected_node_counts[conn_name]
    
    var new_list: Array[HyAssetNode] = []
    for old_index in range(max_index):
        if connected_asset_nodes.has("%s:%d" % [conn_name, old_index]):
            new_list.append(connected_asset_nodes["%s:%d" % [conn_name, old_index]])
    
    var insert_at_indices = insert_nodes.keys()
    insert_at_indices.sort()
    for insert_idx in insert_at_indices:
        new_list.insert(insert_idx, insert_nodes[insert_idx])
    
    connected_node_counts[conn_name] = new_list.size()
    for new_index in max_index:
        if new_index < new_list.size():
            connected_asset_nodes["%s:%d" % [conn_name, new_index]] = new_list[new_index]
        else:
            connected_asset_nodes.erase("%s:%d" % [conn_name, new_index])

    

func get_connected_node(conn_name: String, index: int) -> HyAssetNode:
    if not has_inner_asset_nodes:
        print_debug("Trying to retrieve inner nodes of a shallow asset node (%s)" % an_node_id)
        return null
    if not connection_list.has(conn_name):
        print_debug("Connection name %s not found in connection list" % conn_name)
        return null
    return connected_asset_nodes["%s:%d" % [conn_name, index]]

func get_all_connected_nodes(conn_name: String) -> Array[HyAssetNode]:
    if not has_inner_asset_nodes:
        print_debug("Trying to retrieve inner nodes of a shallow asset node (%s)" % an_node_id)
        return []
    if not connection_list.has(conn_name):
        print_debug("Connection name %s not found in connection list" % conn_name)
        return []

    return _get_connected_node_list(conn_name)

func _get_connected_node_list(conn_name: String) -> Array[HyAssetNode]:
    var node_list: Array[HyAssetNode] = []
    for i in range(connected_node_counts[conn_name]):
        node_list.append(connected_asset_nodes["%s:%d" % [conn_name, i]])
    return node_list

func sort_connections_by_gn_pos(gn_lookup: Dictionary[String, GraphNode]) -> void:
    var sort_by_gn_pos: = func (a: HyAssetNode, b: HyAssetNode) -> bool:
        var a_gn: = gn_lookup.get(a.an_node_id, null) as GraphNode
        var b_gn: = gn_lookup.get(b.an_node_id, null) as GraphNode
        if not a_gn or not b_gn:
            return a_gn != null
        elif a_gn.position_offset.y != b_gn.position_offset.y:
            return a_gn.position_offset.y < b_gn.position_offset.y
        else:
            return a_gn.position_offset.x < b_gn.position_offset.x
    
    var conn_names: Array[String] = connection_list
    for conn_name in conn_names:
        var sorted_nodes: Array[HyAssetNode] = get_all_connected_nodes(conn_name)
        if sorted_nodes.size() < 2:
            continue
        sorted_nodes.sort_custom(sort_by_gn_pos)
        for i in range(sorted_nodes.size()):
            connected_asset_nodes["%s:%d" % [conn_name, i]] = sorted_nodes[i]


func serialize_me(schema: AssetNodesSchema, gn_lookup: Dictionary[String, GraphNode]) -> Dictionary:
    if not has_inner_asset_nodes:
        print_debug("Serializing unpopulated asset node (%s)" % an_node_id)
        return raw_tree_data.duplicate(true)
    
    var serialized_data: Dictionary = {"$NodeId": an_node_id}
    if comment:
        serialized_data["$Comment"] = comment
    
    for other_key in other_metadata.keys():
        serialized_data[other_key] = other_metadata[other_key]
    
    if not an_type or an_type == "Unknown" or not schema.node_schema.has(an_type):
        print_debug("Warning: Serializing an asset node with unknown type: %s (%s)" % [an_type, an_node_id])
        serialized_data["no_schema"] = true
        if "Type" in raw_tree_data:
            serialized_data["Type"] = raw_tree_data["Type"]
        for setting_key in settings.keys():
            serialized_data[setting_key] = settings[setting_key]
        for conn_name in connection_list:
            var num_connected: = num_connected_asset_nodes(conn_name)
            if num_connected == 0:
                continue

            if num_connected > 1:
                serialized_data[conn_name] = []
                for connected_an in get_all_connected_nodes(conn_name):
                    serialized_data[conn_name].append(connected_an.serialize_me(schema, gn_lookup))
            else:
                serialized_data[conn_name] = get_connected_node(conn_name, 0).serialize_me(schema, gn_lookup)
    else:
        var node_schema: = schema.node_schema[an_type]
        var serialized_type_key: Variant = schema.node_types.find_key(an_type)
        if serialized_type_key and serialized_type_key.split("|", false).size() > 1:
            serialized_data["Type"] = serialized_type_key.split("|")[1]
        for setting_key in node_schema.get("settings", {}).keys():
            if node_schema["settings"][setting_key]["gd_type"] == TYPE_STRING:
                if not settings[setting_key]:
                    continue
            elif node_schema["settings"][setting_key]["gd_type"] == TYPE_INT:
                if settings.has(setting_key):
                    if typeof(settings[setting_key]) == TYPE_FLOAT:
                        settings[setting_key] = roundi(settings[setting_key])
                    elif typeof(settings[setting_key]) == TYPE_STRING:
                        settings[setting_key] = roundi(float(settings[setting_key]))
            serialized_data[setting_key] = settings[setting_key]
        for conn_name in node_schema.get("connections", {}).keys():
            var num_connected: = num_connected_asset_nodes(conn_name)
            if num_connected == 0:
                continue
            var is_multi: bool = node_schema["connections"][conn_name].get("multi", false)
            if is_multi:
                serialized_data[conn_name] = []
                for connected_an in get_all_connected_nodes(conn_name):
                    serialized_data[conn_name].append(connected_an.serialize_me(schema, gn_lookup))
            else:
                serialized_data[conn_name] = get_connected_node(conn_name, 0).serialize_me(schema, gn_lookup)

    return serialized_data