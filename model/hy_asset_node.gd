class_name HyAssetNode
extends Resource

@export var an_node_id: String = ""
@export var an_name: String = ""
@export var an_type: String = ""

@export var connections: Dictionary[String, Variant] = {}
@export var has_inner_asset_nodes: bool = false
@export var connected_asset_nodes: Dictionary[String, HyAssetNode] = {}

@export var settings: Dictionary = {}

@export var raw_tree_data: Dictionary = {}

static var special_keys: Array[String] = ["$NodeId", "Name", "Type"]

func is_connection_empty(conn_name: String) -> bool:
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
    var conn_type: = typeof(connections[conn_name])
    if conn_type == TYPE_DICTIONARY:
        return 1
    if conn_type == TYPE_ARRAY:
        return connections[conn_name].size()
    return 0

func get_raw_connected_nodes(conn_name: String) -> Array[Dictionary]:
    var conn_data: Array[Dictionary] = []
    if typeof(connections[conn_name]) == TYPE_DICTIONARY:
        conn_data.append(connections[conn_name])
    else:
        conn_data.append_array(connections[conn_name])
    return conn_data

func set_connection(conn_name: String, index: int, asset_node: HyAssetNode) -> void:
    var conn_key: String = "%s:%d" % [conn_name, index]
    if connections.has(conn_name) and typeof(connections[conn_name]) == TYPE_DICTIONARY:
        if index > 0:
            print_debug("Index %s is greater than 0 on a single connection! (%s)" % [index, conn_name])
            return
    connected_asset_nodes[conn_key] = asset_node

func get_connected_node(conn_name: String, index: int) -> HyAssetNode:
    if not has_inner_asset_nodes:
        print_debug("Trying to retrieve inner nodes of a shallow asset node (%s)" % an_node_id)
        return null
    return connected_asset_nodes["%s:%d" % [conn_name, index]]