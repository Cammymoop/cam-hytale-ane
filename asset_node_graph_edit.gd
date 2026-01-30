extends GraphEdit
class_name AssetNodeGraphEdit

@export var save_formatted_json: = true
@export_file_path("*.json") var test_json_file: String = ""

@export var schema: AssetNodesSchema

@export var new_node_menu: NewGNMenu

var parsed_json_data: Dictionary = {}
var loaded: = false

var global_gn_counter: int = 0

const DEFAULT_HY_WORKSPACE_ID: String = "HytaleGenerator - Biome"
var hy_workspace_id: String = ""

var all_asset_nodes: Array[HyAssetNode] = []
var all_asset_node_ids: Array[String] = []
var floating_tree_roots: Array[HyAssetNode] = []
var root_node: HyAssetNode = null

@onready var special_gn_factory: SpecialGNFactory = $SpecialGNFactory
@onready var dialog_handler: DialogHandler = get_parent().get_node("DialogHandler")

var asset_node_meta: Dictionary[String, Dictionary] = {}
var all_meta: Dictionary = {}

enum NodeContextMenu {
    DELETE_NODE = 1,
    DISSOLVE_NODE = 2,
}

@export var no_left_types: Array[String] = [
    "BiomeRoot",
]


var gn_lookup: Dictionary[String, GraphNode] = {}
var an_lookup: Dictionary[String, HyAssetNode] = {}

var more_type_names: Array[String] = [
    "Single",
    "Multi",
]
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

@export var verbose: = false

@onready var cur_zoom_level: = zoom
@onready var grid_logical_enabled: = show_grid

var copied_nodes: Array[GraphNode] = []

var context_menu_gn: GraphNode = null
var context_menu_movement_acc: = 0.0
var context_menu_ready: bool = false

var dropping_new_node_at: Vector2 = Vector2.ZERO
var next_drop_has_connection: Dictionary = {}
var next_drop_conn_value_type: String = ""

var output_port_drop_offset: Vector2 = Vector2(2, -34)
var input_port_drop_first_offset: Vector2 = Vector2(-2, -34)
var input_port_drop_additional_offset: Vector2 = Vector2(0, -19)

var undo_manager: UndoRedo = UndoRedo.new()
var multi_connection_change: bool = false
var cur_connection_added_gns: Array[GraphNode] = []
var cur_added_connections: Array[Dictionary] = []
var cur_removed_connections: Array[Dictionary] = []
var moved_nodes_positions: Dictionary[GraphNode, Vector2] = {}

var file_menu_btn: MenuButton = null
var file_menu_menu: PopupMenu = null

func _ready() -> void:
    if not new_node_menu:
        push_warning("New node menu is not set, please set it in the inspector")
        print("New node menu is not set, please set it in the inspector")
    else:
        new_node_menu.node_type_picked.connect(on_new_node_type_picked)
        new_node_menu.cancelled.connect(on_new_node_menu_cancelled)
    
    setup_file_menu()

    #add_valid_left_disconnect_type(1)
    begin_node_move.connect(on_begin_node_move)
    end_node_move.connect(on_end_node_move)
    
    connection_request.connect(_connection_request)
    disconnection_request.connect(_disconnection_request)

    duplicate_nodes_request.connect(_duplicate_request)
    copy_nodes_request.connect(_copy_nodes)
    cut_nodes_request.connect(_cut_nodes)
    paste_nodes_request.connect(_paste_request)
    delete_nodes_request.connect(_delete_request)
    
    connection_to_empty.connect(_connect_right_request)
    connection_from_empty.connect(_connect_left_request)
    
    var menu_hbox: = get_menu_hbox()
    var grid_toggle_btn: = menu_hbox.get_child(4) as Button
    grid_toggle_btn.toggled.connect(on_grid_toggled.bind(grid_toggle_btn))
    
    for val_type_name in schema.value_types:
        var val_type_idx: = type_names.size()
        type_names[val_type_idx] = val_type_name
        add_valid_connection_type(val_type_idx, val_type_idx)
        #add_valid_left_disconnect_type(val_type_idx)

    for extra_type_name in more_type_names:
        var type_idx: = type_names.size()
        type_names[type_idx] = extra_type_name
        #add_valid_left_disconnect_type(type_idx)

    for type_id in type_names.keys():
        type_id_lookup[type_names[type_id]] = type_id

    #cut_nodes_request.connect(_cut_nodes)
    #if test_json_file:
        #load_json_file(test_json_file)
    #else:
        #print("No test JSON file specified")
    setup_new_graph()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ui_undo"):
        print("Undo pressed")
        if undo_manager.has_undo():
            print("Undoing")
            undo_manager.undo()
    if Input.is_action_just_pressed("ui_redo"):
        print("Redo pressed")
        if undo_manager.has_redo():
            undo_manager.redo()
    if Input.is_action_just_pressed("show_new_node_menu"):
        if not new_node_menu.visible:
            clear_next_drop()
            new_node_menu.open_all_menu()
    
    if cur_zoom_level != zoom:
        on_zoom_changed()
    
func setup_file_menu() -> void:
    file_menu_btn = preload("res://ui/file_menu.tscn").instantiate()
    file_menu_menu = file_menu_btn.get_popup()
    var menu_hbox: = get_menu_hbox()
    var sep: = VSeparator.new()
    menu_hbox.add_child(sep)
    menu_hbox.move_child(sep, 0)
    menu_hbox.add_child(file_menu_btn)
    menu_hbox.move_child(file_menu_btn, 0)
    
    file_menu_menu.id_pressed.connect(on_file_menu_id_pressed)

func on_file_menu_id_pressed(id: int) -> void:
    var menu_item_text: = file_menu_menu.get_item_text(file_menu_menu.get_item_index(id))
    match menu_item_text:
        "Open":
            dialog_handler.show_open_file_dialog()
        "Save":
            dialog_handler.show_save_file_dialog()
        "New":
            setup_new_graph()

func setup_new_graph() -> void:
    clear_graph()
    hy_workspace_id = DEFAULT_HY_WORKSPACE_ID
    var new_root_node: HyAssetNode = get_new_asset_node("BiomeRoot")
    root_node = new_root_node
    var screen_center_pos: Vector2 = get_viewport_rect().size / 2
    var new_gn: CustomGraphNode = make_and_add_graph_node(new_root_node, screen_center_pos)
    gn_lookup[new_root_node.an_node_id] = new_gn

func is_mouse_wheel_event(event: InputEvent) -> bool:
    return event is InputEventMouseButton and (
        event.button_index == MOUSE_BUTTON_WHEEL_UP
        or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
        or event.button_index == MOUSE_BUTTON_WHEEL_LEFT
        or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
    )
    
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouse:
        if is_mouse_wheel_event(event):
            return
        handle_mouse_event(event as InputEventMouse)

func _connection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    prints("Connection request:", from_gn_name, from_port, to_gn_name)
    _add_connection(from_gn_name, from_port, to_gn_name, to_port)

func add_multiple_connections(conns_to_add: Array[Dictionary], with_undo: bool = true) -> void:
    prints("adding multiple connections (%d) undoable: %s" % [conns_to_add.size(), with_undo])
    var self_multi: = not multi_connection_change
    multi_connection_change = true
    for conn_to_add in conns_to_add:
        add_connection(conn_to_add, with_undo)

    if self_multi:
        if with_undo:
            create_undo_connection_change_step()
        multi_connection_change = false

func add_connection(connection_info: Dictionary, with_undo: bool = true) -> void:
    _add_connection(connection_info["from_node"], connection_info["from_port"], connection_info["to_node"], connection_info["to_port"], with_undo)

func _add_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int, with_undo: bool = true) -> void:
    prints("Adding connection:", from_gn_name, from_port, to_gn_name, "undoable:", with_undo)
    var from_gn: GraphNode = get_node(NodePath(from_gn_name))
    var to_gn: GraphNode = get_node(NodePath(to_gn_name))
    var from_an: HyAssetNode = an_lookup.get(from_gn.get_meta("hy_asset_node_id", ""))
    var to_an: HyAssetNode = an_lookup.get(to_gn.get_meta("hy_asset_node_id", ""))
    if from_an.an_type not in schema.node_schema:
        print_debug("Warning: From node type %s not found in schema" % from_an.an_type)
        connect_node(from_gn_name, from_port, to_gn_name, to_port)
        return

    var conn_name: String = from_an.connection_list[from_port]
    var connect_is_multi: bool = schema.node_schema[from_an.an_type]["connections"][conn_name].get("multi", false)
    if connect_is_multi or from_an.num_connected_asset_nodes(conn_name) == 0:
        from_an.append_node_to_connection(conn_name, to_an)
    else:
        var prev_connected_node: HyAssetNode = from_an.get_connected_node(conn_name, 0)
        var was_removed: bool = false
        if prev_connected_node and gn_lookup.has(prev_connected_node.an_node_id):
            was_removed = true
            _remove_connection(from_gn_name, from_port, gn_lookup[prev_connected_node.an_node_id].name, 0)
        from_an.append_node_to_connection(conn_name, to_an)
        if was_removed:
            var connected_node_keys: Array[String] = from_an.connected_asset_nodes.keys()
            var pretty_print: Dictionary = {}
            for conn_key in connected_node_keys:
                pretty_print[conn_key] = from_an.connected_asset_nodes[conn_key].an_node_id
            print("new an connections: %s)" % [pretty_print])
    
    if to_an in floating_tree_roots:
        floating_tree_roots.erase(to_an)

    if with_undo:
        cur_added_connections.append({
            "from_node": from_gn_name,
            "from_port": from_port,
            "to_node": to_gn_name,
            "to_port": to_port,
        })
    connect_node(from_gn_name, from_port, to_gn_name, to_port)
    if with_undo and not multi_connection_change:
        print("with undo and not multi_connection_change, now creating undo connection change step")
        create_undo_connection_change_step()

func _disconnection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    prints("Disconnection request:", from_gn_name, from_port, to_gn_name)
    _remove_connection(from_gn_name, from_port, to_gn_name, to_port)

func remove_multiple_connections(conns_to_remove: Array[Dictionary], with_undo: bool = true) -> void:
    var self_multi: = not multi_connection_change
    multi_connection_change = true
    for conn_to_remove in conns_to_remove:
        remove_connection(conn_to_remove, with_undo)

    if self_multi:
        if with_undo:
            create_undo_connection_change_step()
        multi_connection_change = false

func remove_connection(connection_info: Dictionary, with_undo: bool = true) -> void:
    _remove_connection(connection_info["from_node"], connection_info["from_port"], connection_info["to_node"], connection_info["to_port"], with_undo)

func _remove_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int, with_undo: bool = true) -> void:
    prints("Removing connection:", from_gn_name, from_port, to_gn_name)
    disconnect_node(from_gn_name, from_port, to_gn_name, to_port)

    var from_gn: GraphNode = get_node(NodePath(from_gn_name))
    var to_gn: GraphNode = get_node(NodePath(to_gn_name))
    var from_an: HyAssetNode = an_lookup.get(from_gn.get_meta("hy_asset_node_id", ""))
    var from_connection_name: String = from_an.connection_list[from_port]
    var to_an: HyAssetNode = an_lookup.get(to_gn.get_meta("hy_asset_node_id", ""))
    from_an.remove_node_from_connection(from_connection_name, to_an)
    
    if with_undo:
        cur_removed_connections.append({
            "from_node": from_gn_name,
            "from_port": from_port,
            "to_node": to_gn_name,
            "to_port": to_port,
        })
    floating_tree_roots.append(to_an)
    if with_undo and not multi_connection_change:
        create_undo_connection_change_step()

func remove_asset_node(asset_node: HyAssetNode) -> void:
    _erase_asset_node(asset_node)
    an_lookup.erase(asset_node.an_node_id)
    gn_lookup.erase(asset_node.an_node_id)

func _erase_asset_node(asset_node: HyAssetNode) -> void:
    all_asset_nodes.erase(asset_node)
    all_asset_node_ids.erase(asset_node.an_node_id)

func _register_asset_node(asset_node: HyAssetNode) -> void:
    if asset_node in all_asset_nodes:
        print_debug("Asset node %s already registered" % asset_node.an_node_id)
    else:
        all_asset_nodes.append(asset_node)
    if asset_node.an_node_id in all_asset_node_ids:
        print_debug("Asset node ID %s already registered" % asset_node.an_node_id)
    else:
        all_asset_node_ids.append(asset_node.an_node_id)

func _delete_request(delete_gn_names: Array[StringName]) -> void:
    return
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

func _connect_right_request(from_gn_name: StringName, from_port: int, dropped_pos: Vector2) -> void:
    prints("Connect right request:", from_gn_name, from_port, dropped_pos)
    dropping_new_node_at = dropped_pos
    next_drop_has_connection = {
        "from_node": from_gn_name,
        "from_port": from_port,
        "to_port": 0,
    }
    var from_an: HyAssetNode = an_lookup.get(get_node(NodePath(from_gn_name)).get_meta("hy_asset_node_id", ""), null)
    if from_an:
        var from_node_schema: Dictionary = schema.node_schema[from_an.an_type]
        next_drop_conn_value_type = from_node_schema["connections"][from_an.connection_list[from_port]].get("value_type", "")
        new_node_menu.open_menu(true, next_drop_conn_value_type)
    else:
        print_debug("Connect right request: From asset node not found")

func _connect_left_request(to_gn_name: StringName, to_port: int, dropped_pos: Vector2) -> void:
    prints("Connect left request:", to_gn_name, dropped_pos)
    dropping_new_node_at = dropped_pos
    next_drop_has_connection = {
        "to_node": to_gn_name,
        "to_port": to_port,
    }
    var to_an: HyAssetNode = an_lookup.get(get_node(NodePath(to_gn_name)).get_meta("hy_asset_node_id", ""), null)
    if to_an:
        var to_node_schema: Dictionary = schema.node_schema[to_an.an_type]
        next_drop_conn_value_type = to_node_schema["output_value_type"]
        new_node_menu.open_menu(false, next_drop_conn_value_type)
    else:
        print_debug("Connect left request: To asset node not found")

func on_new_node_menu_cancelled() -> void:
    clear_next_drop()

func clear_next_drop() -> void:
    dropping_new_node_at = Vector2.ZERO
    next_drop_has_connection = {}
    next_drop_conn_value_type = ""

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
    new_asset_node.an_name = schema.get_node_type_default_name(asset_node_type)
    _register_asset_node(new_asset_node)
    an_lookup[new_asset_node.an_node_id] = new_asset_node
    init_asset_node(new_asset_node)
    new_asset_node.has_inner_asset_nodes = true

    return new_asset_node

func get_selected_gns() -> Array[GraphNode]:
    var selected_gns: Array[GraphNode] = []
    for c in get_children():
        if c is GraphNode and c.selected:
            selected_gns.append(c)
    return selected_gns

func _duplicate_request() -> void:
    pass

func _cut_request() -> void:
    pass

func _cut_nodes() -> void:
    var selected_gns: Array[GraphNode] = get_selected_gns()
    copied_nodes = selected_gns
    for gn in selected_gns:
        remove_child(gn)

func _copy_request() -> void:
    pass

func _copy_nodes() -> void:
    copied_nodes = get_selected_gns()

func _paste_request() -> void:
    pass

func clear_graph() -> void:
    all_asset_nodes.clear()
    all_asset_node_ids.clear()
    floating_tree_roots.clear()
    root_node = null
    gn_lookup.clear()
    an_lookup.clear()
    asset_node_meta.clear()
    for child in get_children():
        if child is GraphNode:
            remove_child(child)
            child.queue_free()
    global_gn_counter = 0
    undo_manager.clear_history()

func create_graph_from_parsed_data() -> void:
    await get_tree().create_timer(0.1).timeout
    
    if use_json_positions:
        pass#relative_root_position = get_node_position_from_meta(root_node.an_node_id)
    
    make_graph_stuff()
    
    await get_tree().process_frame
    var root_gn: = gn_lookup[root_node.an_node_id]
    scroll_offset = root_gn.position_offset * zoom
    scroll_offset -= (get_viewport_rect().size / 2) 
    
    await get_tree().process_frame
    dropping_new_node_at = root_gn.global_position + Vector2.UP * 120

func get_node_position_from_meta(node_id: String) -> Vector2:
    var node_meta: Dictionary = asset_node_meta.get(node_id, {}) as Dictionary
    var meta_pos: Dictionary = node_meta.get("$Position", {"$x": relative_root_position.x, "$y": relative_root_position.y - 560})
    return Vector2(meta_pos["$x"], meta_pos["$y"])
    
func parse_asset_node_shallow(old_style: bool, asset_node_data: Dictionary, output_value_type: String = "", known_node_type: String = "") -> HyAssetNode:
    if not asset_node_data:
        print_debug("Asset node data is empty")
        return null

    if old_style and not known_node_type:
        var type_key_val: String = asset_node_data.get("Type", "NO_TYPE_KEY")
        var inferred_node_type: String = schema.resolve_asset_node_type(type_key_val, output_value_type)
        if not inferred_node_type or inferred_node_type == "Unknown":
            print_debug("Old-style inferring node type failed, returning null")
            push_error("Old-style inferring node type failed, returning null")
            return null
        else:
            asset_node_data["$NodeId"] = get_unique_id(schema.get_id_prefix_for_node_type(inferred_node_type))
    elif not asset_node_data.has("$NodeId"):
        print_debug("Asset node data does not have a $NodeId, it is probably not an asset node")
        return null
    
    
    var asset_node = HyAssetNode.new()
    asset_node.an_node_id = asset_node_data["$NodeId"]
    
    if asset_node_data.has("$Comment"):
        asset_node.comment = asset_node_data["$Comment"]
    
    if an_lookup.has(asset_node.an_node_id):
        print_debug("Warning: Asset node with ID %s already exists in lookup, overriding..." % asset_node.an_node_id)
    an_lookup[asset_node.an_node_id] = asset_node
    

    if known_node_type != "":
        asset_node.an_type = known_node_type
        print("Known node type: %s" % asset_node.an_type)
    elif output_value_type != "ROOT":
        asset_node.an_type = schema.resolve_asset_node_type(asset_node_data.get("Type", "NO_TYPE_KEY"), output_value_type, asset_node.an_node_id)
    
    var node_schema: Dictionary = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        node_schema = schema.node_schema.get(asset_node.an_type, {})
        if not node_schema:
            print_debug("Warning: Node schema not found for node type: %s" % asset_node.an_type)
    
    asset_node.raw_tree_data = asset_node_data.duplicate(true)
    init_asset_node(asset_node)

    # fill out stuff in data even if it isn't in the schema
    for other_key in asset_node_data.keys():
        if other_key.begins_with("$") or HyAssetNode.special_keys.has(other_key):
            continue
        
        var connected_data = check_for_asset_nodes(old_style, asset_node_data[other_key])
        if other_key in asset_node.connection_list or connected_data != null:
            if connected_data == null:
                if asset_node.an_type != "Unknown" and node_schema["connections"][other_key].get("multi", false):
                    connected_data = []
                else:
                    connected_data = {}
            if verbose:
                var short_data: = str(connected_data).substr(0, 12) + "..."
                prints("Node '%s' (%s) Connection '%s' has connected nodes: %s" % [asset_node.an_name, asset_node.an_type, other_key, short_data])
            asset_node.connections[other_key] = connected_data
        else:
            if verbose:
                var short_data: = str(asset_node_data[other_key])
                short_data = short_data.substr(0, 50) + ("..." if short_data.length() > 50 else "")
                prints("Node '%s' (%s) Connection '%s' is just data: %s" % [asset_node.an_name, asset_node.an_type, other_key, short_data])
            var parsed_value: Variant = asset_node_data[other_key]
            if node_schema and node_schema.get("settings", {}).has(other_key):
                var expected_gd_type: int = node_schema["settings"][other_key]["gd_type"]
                if expected_gd_type == TYPE_INT:
                    parsed_value = roundi(float(parsed_value))
                elif expected_gd_type == TYPE_FLOAT:
                    parsed_value = float(parsed_value)
                elif expected_gd_type == TYPE_STRING:
                    if not typeof(parsed_value) == TYPE_STRING:
                        print_debug("Warning: Setting %s is expected to be a string, but is not: %s" % [other_key, parsed_value])
            asset_node.settings[other_key] = parsed_value
    
    return asset_node

func check_for_asset_nodes(old_style: bool, val: Variant) -> Variant:
    var test_dict: Dictionary
    if val is Dictionary:
        test_dict = val
    elif val is Array:
        if val.size() == 0:
            return val
        test_dict = val[0]
    elif val != null:
        return null
    
    if old_style:
        if test_dict.is_empty() or test_dict.has("$Position"):
            return val
    else:
        if test_dict.is_empty() or test_dict.has("$NodeId"):
            return val
    return null

func init_asset_node(asset_node: HyAssetNode) -> void:
    var type_schema: = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        type_schema = schema.node_schema[asset_node.an_type]
    else:
        print_debug("Warning: Asset node type is unknown or empty")

    asset_node.an_name = schema.get_node_type_default_name(asset_node.an_type)
    if asset_node_meta and asset_node_meta.has(asset_node.an_node_id) and asset_node_meta[asset_node.an_node_id].has("$Title"):
        asset_node.an_name = asset_node_meta[asset_node.an_node_id]["$Title"]
        asset_node.title = asset_node.an_name
    
    var connections_schema: Dictionary = type_schema.get("connections", {})
    for conn_name in connections_schema.keys():
        asset_node.connection_list.append(conn_name)
        asset_node.connected_node_counts[conn_name] = 0
        if connections_schema[conn_name].get("multi", false):
            asset_node.connections[conn_name] = []
        else:
            asset_node.connections[conn_name] = null
    
    var settings_schema: Dictionary = type_schema.get("settings", {})
    for setting_name in settings_schema.keys():
        asset_node.settings[setting_name] = settings_schema[setting_name].get("default_value", null)

func _inner_parse_asset_node_deep(old_style: bool, asset_node_data: Dictionary, output_value_type: String = "", base_node_type: String = "") -> Dictionary:
    var parsed_node: = parse_asset_node_shallow(old_style, asset_node_data, output_value_type, base_node_type)
    var all_nodes: Array[HyAssetNode] = [parsed_node]
    for conn in parsed_node.connection_list:
        if parsed_node.is_connection_empty(conn):
            continue
        
        var conn_nodes_data: = parsed_node.get_raw_connected_nodes(conn)
        for conn_node_idx in conn_nodes_data.size():
            var conn_value_type: = "Unknown"
            if parsed_node.an_type != "Unknown":
                conn_value_type = schema.node_schema[parsed_node.an_type]["connections"][conn]["value_type"]

            var sub_parse_result: = _inner_parse_asset_node_deep(old_style, conn_nodes_data[conn_node_idx], conn_value_type)
            all_nodes.append_array(sub_parse_result["all_nodes"])
            parsed_node.set_connection(conn, conn_node_idx, sub_parse_result["base"])
        parsed_node.set_connection_count(conn, conn_nodes_data.size())

    parsed_node.has_inner_asset_nodes = true
    
    return {"base": parsed_node, "all_nodes": all_nodes}

func parse_asset_node_deep(old_style: bool, asset_node_data: Dictionary, output_value_type: String = "", base_node_type: String = "") -> Dictionary:
    var res: = _inner_parse_asset_node_deep(old_style, asset_node_data, output_value_type, base_node_type)
    return res

func parse_root_asset_node(base_node: Dictionary) -> void:
    hy_workspace_id = "NONE"
    var parsed_node_count: = 0
    var old_style_format: = false
    if base_node.has("$WorkspaceID"):
        old_style_format = true
        hy_workspace_id = base_node["$WorkspaceID"]
        
    elif not base_node.get("$NodeEditorMetadata", {}):
        print_debug("Not old-style but Root node does not have $NodeEditorMetadata")
        push_error("Not old-style but Root node does not have $NodeEditorMetadata")
        return
    else:
        hy_workspace_id = base_node["$NodeEditorMetadata"].get("$WorkspaceID", "NONE")
    
    if not hy_workspace_id or hy_workspace_id == "NONE":
        print_debug("No workspace ID found in root node or editor metadata")
        push_error("No workspace ID found in root node or editor metadata")
        return

    var root_node_type: String = schema.resolve_asset_node_type(base_node.get("Type", "NO_TYPE_KEY"), "ROOT|%s" % hy_workspace_id, base_node.get("$NodeId", ""))

    if old_style_format and not base_node.get("$NodeId", ""):
        base_node["$NodeId"] = get_unique_id(schema.get_id_prefix_for_node_type(root_node_type))

    if not old_style_format:
        var meta_data: = base_node["$NodeEditorMetadata"] as Dictionary
        all_meta = meta_data.duplicate(true)

        for node_id in meta_data.get("$Nodes", {}).keys():
            asset_node_meta[node_id] = meta_data["$Nodes"][node_id]

        for floating_tree in meta_data.get("$FloatingNodes", []):
            var floating_parse_result: = parse_asset_node_deep(false, floating_tree)
            floating_tree_roots.append(floating_parse_result["base"])
            parsed_node_count += floating_parse_result["all_nodes"].size()
            #print("Floating tree parsed, %d nodes" % floating_parse_result["all_nodes"].size(), " (total: %d)" % parsed_node_count)
            all_asset_nodes.append_array(floating_parse_result["all_nodes"])
            for an in floating_parse_result["all_nodes"]:
                all_asset_node_ids.append(an.an_node_id)
        
        hy_workspace_id = meta_data.get("$WorkspaceID", "NONE")

    if hy_workspace_id == "NONE":
        print_debug("No workspace ID found in root node or editor metadata")
        push_error("No workspace ID found in root node or editor metadata")
        return

    var parse_result: = parse_asset_node_deep(old_style_format, base_node, "", root_node_type)
    root_node = parse_result["base"]
    all_asset_nodes.append_array(parse_result["all_nodes"])
    parsed_node_count += parse_result["all_nodes"].size()
    #print("Root node parsed, %d nodes" % parse_result["all_nodes"].size(), " (total: %d)" % parsed_node_count)
    for an in parse_result["all_nodes"]:
        all_asset_node_ids.append(an.an_node_id)
    
    if old_style_format:
        all_meta = {}
        collect_node_positions_old_style_recursive(base_node)
        all_meta["$Nodes"] = asset_node_meta.duplicate(true)
        all_meta["$FloatingNodes"] = []
        all_meta["$Groups"] = base_node.get("$Groups", [])
        all_meta["$Comments"] = base_node.get("$Comments", [])
        all_meta["$Links"] = base_node.get("$Links", {})
        
    loaded = true

func collect_node_positions_old_style_recursive(cur_node_data: Dictionary) -> void:
    if not cur_node_data.has("$NodeId"):
        print_debug("Old style node does not have a $NodeID, exiting branch")
        return
    var cur_node_meta: = {}
    if cur_node_data.has("$Position"):
        cur_node_meta["$Position"] = cur_node_data["$Position"]
    if cur_node_data.has("$Title"):
        cur_node_meta["$Title"] = cur_node_data["$Title"]
    asset_node_meta[cur_node_data["$NodeId"]] = cur_node_meta
    
    for key in cur_node_data.keys():
        if key.begins_with("$") or typeof(cur_node_data[key]) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
            continue
        if typeof(cur_node_data[key]) == TYPE_DICTIONARY:
            if cur_node_data[key].get("$NodeId", ""):
                collect_node_positions_old_style_recursive(cur_node_data[key])
        elif cur_node_data[key].size() > 0 and typeof(cur_node_data[key][0]) == TYPE_DICTIONARY and cur_node_data[key][0].get("$NodeId", ""):
            for i in cur_node_data[key].size():
                collect_node_positions_old_style_recursive(cur_node_data[key][i])


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
            add_child(new_gn, true)
            if not use_json_positions:
                new_gn.position_offset = Vector2(0, -500)
            new_gn.was_right_clicked.connect(_on_graph_node_right_clicked)
            if new_gn.size.x < gn_min_width:
                new_gn.size.x = gn_min_width
        
        if use_json_positions:
            connect_children(new_graph_nodes[0])
        else:
            var last_y: int = move_and_connect_children(tree_root_node.an_node_id, base_tree_pos)
            base_tree_pos.y = last_y + 40

func make_and_add_graph_node(asset_node: HyAssetNode, at_global_pos: Vector2) -> CustomGraphNode:
    var new_gn: CustomGraphNode = new_graph_node(asset_node, asset_node, true)
    add_child(new_gn, true)
    new_gn.position_offset = (scroll_offset + at_global_pos) / zoom
    return new_gn
    
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

    var this_gn: = new_graph_node(at_asset_node, root_asset_node, false)
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

func new_graph_node(asset_node: HyAssetNode, root_asset_node: HyAssetNode, newly_created: bool) -> CustomGraphNode:
    var graph_node: CustomGraphNode = null
    var is_special: = should_be_special_gn(asset_node)
    var settings_syncer: SettingsSyncer = null
    if is_special:
        graph_node = special_gn_factory.make_special_gn(root_asset_node, asset_node, newly_created)
    else:
        graph_node = CustomGraphNode.new()
        settings_syncer = SettingsSyncer.new()
        settings_syncer.set_asset_node(asset_node)
        graph_node.add_child(settings_syncer, true)
    
    graph_node.name = get_graph_node_name(graph_node.name if graph_node.name else &"GN")
    
    var output_type: String = schema.node_schema[asset_node.an_type].get("output_value_type", "")
    var theme_var_color: String = TypeColors.get_color_for_type(output_type)
    if ThemeColorVariants.theme_colors.has(theme_var_color):
        graph_node.theme = ThemeColorVariants.get_theme_color_variant(theme_var_color)
    else:
        push_warning("No theme color variant found for color '%s'" % theme_var_color)
        print("No theme color variant found for color '%s'" % theme_var_color)

    graph_node.set_meta("hy_asset_node_id", asset_node.an_node_id)
    gn_lookup[asset_node.an_node_id] = graph_node
    
    graph_node.resizable = true
    if not output_type:
        graph_node.ignore_invalid_connection_type = true

    graph_node.title = asset_node.an_name
    
    if is_special:
        pass
    else:
        var num_inputs: = 1
        if asset_node.an_type in no_left_types:
            num_inputs = 0
        
        var node_schema: Dictionary = {}
        if asset_node.an_type and asset_node.an_type != "Unknown":
            node_schema = schema.node_schema[asset_node.an_type]
        
        var connection_names: Array
        var connection_types: Array[int]
        if node_schema:
            var type_connections: Dictionary = node_schema.get("connections", {})
            connection_names = type_connections.keys()
            for conn_name in connection_names:
                connection_types.append(type_id_lookup[type_connections[conn_name]["value_type"]])
        else:
            connection_names = asset_node.connections.keys()
            connection_types.resize(connection_names.size())
            connection_types.fill(type_id_lookup["Single"])
        var num_outputs: = connection_names.size()
        
        var setting_names: Array
        if node_schema:
            setting_names = node_schema.get("settings", {}).keys()
        else:
            setting_names = asset_node.settings.keys()
        var num_settings: = setting_names.size()
        
        var first_setting_slot: = maxi(num_inputs, num_outputs)
        
        for i in maxi(num_inputs, num_outputs) + num_settings:
            if i >= first_setting_slot:
                var setting_name: String = setting_names[i - first_setting_slot]

                var slot_node: = HBoxContainer.new()
                slot_node.name = "Slot%d" % i
                var s_name: = Label.new()
                s_name.name = "SettingName"
                s_name.text = "%s:" % setting_name
                s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                slot_node.add_child(s_name, true)

                var s_edit: Control
                var setting_value: Variant
                var setting_type: int
                if setting_name in asset_node.settings:
                    setting_value = asset_node.settings[setting_name]
                else:
                    setting_value = schema.node_schema[asset_node.an_type]["settings"][setting_name].get("default_value", 0)
                if setting_name in node_schema.get("settings", {}):
                    setting_type = node_schema.get("settings", {})[setting_name]["gd_type"]
                else:
                    print("Setting type for %s : %s not found in node schema (%s)" % [setting_name, setting_value, asset_node.an_type])
                    setting_type = typeof(setting_value) if setting_value else TYPE_STRING

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
                settings_syncer.add_watched_setting(setting_name, s_edit, setting_type)
                
                graph_node.add_child(slot_node, true)
            else:
                var slot_node: = Label.new()
                slot_node.name = "Slot%d" % i
                graph_node.add_child(slot_node, true)
                if i < num_inputs:
                    graph_node.set_slot_enabled_left(i, true)
                    graph_node.set_slot_type_left(i, type_id_lookup[output_type])
                if i < num_outputs:
                    graph_node.set_slot_enabled_right(i, true)
                    graph_node.set_slot_type_right(i, connection_types[i])
                    slot_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
                    slot_node.text = connection_names[i]
    
    graph_node.update_port_colors(self, asset_node)
    
    if use_json_positions:
        var meta_pos: = get_node_position_from_meta(asset_node.an_node_id) * json_positions_scale
        graph_node.position_offset = meta_pos - relative_root_position
    
    return graph_node


var connection_cut_active: = false
var connection_cut_start_point: Vector2 = Vector2(0, 0)
var connection_cut_line: Line2D = null
var max_connection_cut_points: = 100000

func start_connection_cut(at_global_pos: Vector2) -> void:
    prints("Starting connection cut")
    connection_cut_active = true
    connection_cut_start_point = at_global_pos
    
    connection_cut_line = preload("res://ui/connection_cutting_line.tscn").instantiate() as Line2D
    connection_cut_line.clear_points()
    connection_cut_line.add_point(Vector2.ZERO)
    connection_cut_line.z_index = 10
    get_parent().add_child(connection_cut_line)
    connection_cut_line.global_position = at_global_pos

func add_connection_cut_point(at_global_pos: Vector2) -> void:
    if not connection_cut_line or connection_cut_line.points.size() >= max_connection_cut_points:
        return
    connection_cut_line.add_point(at_global_pos - connection_cut_start_point)

func cancel_connection_cut() -> void:
    connection_cut_active = false
    if connection_cut_line:
        get_parent().remove_child(connection_cut_line)
        connection_cut_line = null


func do_connection_cut() -> void:
    prints("cutting connections (%d points)" % connection_cut_line.points.size())
    const cut_radius: = 5.0
    const MAX_CUTS_PER_STEP: = 50
    
    #var check_point_visualizer: Control
    #if _first_cut_:
    #    check_point_visualizer = ColorRect.new()
    #    check_point_visualizer.color = Color.LAVENDER
    #    check_point_visualizer.z_index = 10
    #    check_point_visualizer.size = Vector2(4, 4)
    
    multi_connection_change = true
    
    var num_cut: = 0

    var vp_rect: = get_viewport_rect()
    var prev_cut_point: = connection_cut_start_point
    for cut_point in connection_cut_line.points:
        var cut_global_pos: = connection_cut_line.to_global(cut_point)
        var check_points: = [cut_global_pos]

        var iteration_dist: = (cut_global_pos - prev_cut_point).length()
        if iteration_dist > cut_radius:
            var interpolation_steps: = int(iteration_dist / cut_radius)
            
            for i in interpolation_steps:
                check_points.append(prev_cut_point.lerp(cut_global_pos, (i + 1) / float(interpolation_steps)))
        
        for check_point in check_points:
            if not vp_rect.has_point(check_point):
                continue
            #if _first_cut_:
            #    var copy: = check_point_visualizer.duplicate()
            #    get_parent().add_child(copy)
            #    copy.global_position = check_point
            for i in MAX_CUTS_PER_STEP:
                var connection_at_point: = get_closest_connection_at_point(check_point, cut_radius + 0.5)
                if not connection_at_point:
                    break
                num_cut += 1
                remove_connection(connection_at_point)
                #disconnect_node(connection_at_point.from_node, connection_at_point.from_port, connection_at_point.to_node, connection_at_point.to_port)
        prev_cut_point = cut_global_pos
    
    if num_cut > 0:
        create_undo_connection_change_step()
        multi_connection_change = false

    #if _first_cut_:
    #    _first_cut_ = false
    cancel_connection_cut()


var mouse_panning: = false

func handle_mouse_event(event: InputEventMouse) -> void:
    var mouse_btn_event: = event as InputEventMouseButton
    var mouse_motion_event: = event as InputEventMouseMotion
    
    if mouse_btn_event:
        if new_node_menu.visible and mouse_btn_event.is_pressed():
            prints("Hiding new node menu because of mouse button: %s" % mouse_btn_event.button_index)
            new_node_menu.hide()
            if mouse_btn_event.button_index == MOUSE_BUTTON_LEFT:
                return

        if mouse_btn_event.button_index == MOUSE_BUTTON_RIGHT:
            if context_menu_ready and not mouse_btn_event.is_pressed():
                actually_right_click_gn(context_menu_gn)

            if mouse_btn_event.is_pressed():
                if mouse_btn_event.ctrl_pressed:
                    start_connection_cut(mouse_btn_event.global_position)
                else:
                    mouse_panning = true
            elif mouse_panning:
                mouse_panning = false
            elif connection_cut_active:
                cancel_context_menu()
                do_connection_cut()
        elif mouse_btn_event.button_index == MOUSE_BUTTON_LEFT:
            if connection_cut_active and mouse_btn_event.is_pressed():
                cancel_connection_cut()
                get_viewport().set_input_as_handled()
    if mouse_motion_event:
        if context_menu_ready:
            context_menu_movement_acc -= mouse_motion_event.relative.length()
            if context_menu_movement_acc <= 0:
                cancel_context_menu()

        if connection_cut_active:
            add_connection_cut_point(mouse_motion_event.global_position)
        elif mouse_panning:
            scroll_offset -= mouse_motion_event.relative

func on_zoom_changed() -> void:
    cur_zoom_level = zoom
    var menu_hbox: = get_menu_hbox()
    var grid_toggle_btn: = menu_hbox.get_child(4) as Button
    if zoom < 0.1:
        grid_toggle_btn.disabled = true
        show_grid = false
    else:
        grid_toggle_btn.disabled = false
        show_grid = grid_logical_enabled

func on_grid_toggled(grid_is_enabled: bool, grid_toggle_btn: Button) -> void:
    if grid_toggle_btn.disabled:
        return
    grid_logical_enabled = grid_is_enabled

#func _notification(what: int) -> void:
    #if what == NOTIFICATION_WM_MOUSE_EXIT:
        #mouse_panning = false

func load_json_file(file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        print("Error opening JSON file %s" % file_path)
        return
    load_json(file.get_as_text())

func load_json(json_data: String) -> void:
    parsed_json_data = JSON.parse_string(json_data)
    if not parsed_json_data:
        print("Error parsing JSON")
        return

    prints("Loading JSON data")
    if loaded:
        clear_graph()
        loaded = false
    parse_root_asset_node(parsed_json_data)
    create_graph_from_parsed_data()
    loaded = true
    prints("New data loaded from json")
    if OS.has_feature("debug"):
        test_reserialize_to_file(parsed_json_data)

func _requested_open_file(path: String) -> void:
    prints("Requested open file:", path)
    load_json_file(path)

func on_begin_node_move() -> void:
    moved_nodes_positions.clear()
    var selected_nodes: Array[GraphNode] = get_selected_gns()
    for gn in selected_nodes:
        moved_nodes_positions[gn] = gn.position_offset

func on_end_node_move() -> void:
    create_move_nodes_undo_step(get_selected_gns())

func _set_gns_offsets(new_positions: Dictionary[GraphNode, Vector2]) -> void:
    for gn in new_positions.keys():
        gn.position_offset = new_positions[gn]

func create_move_nodes_undo_step(moved_nodes: Array[GraphNode]) -> void:
    prints("Creating move nodes (%d) undo step" % moved_nodes.size())
    if moved_nodes.size() == 0:
        return
    var new_positions: Dictionary[GraphNode, Vector2] = {}
    for gn in moved_nodes:
        new_positions[gn] = gn.position_offset
    undo_manager.create_action("Move Nodes")
    undo_manager.add_do_method(_set_gns_offsets.bind(new_positions))
    undo_manager.add_undo_method(_set_gns_offsets.bind(moved_nodes_positions.duplicate_deep()))
    undo_manager.commit_action(false)

func create_undo_connection_change_step() -> void:
    prints("Creating undo connection change step")
    print(cur_connection_added_gns)
    var added_gns: Array[GraphNode] = cur_connection_added_gns.duplicate_deep()
    var added_conns: Array[Dictionary] = cur_added_connections.duplicate_deep()
    var removed_conns: Array[Dictionary] = cur_removed_connections.duplicate_deep()
    cur_connection_added_gns.clear()
    cur_added_connections.clear()
    cur_removed_connections.clear()
    
    var undo_step_name: = "Connection Change"
    if added_gns.size() > 0:
        undo_step_name = "Add Nodes With Connections"
    undo_manager.create_action(undo_step_name)
    if added_gns.size() > 0:
        var the_ans: Dictionary[GraphNode, HyAssetNode] = {}
        for the_gn in added_gns:
            if the_gn.get_meta("hy_asset_node_id", ""):
                var the_an: HyAssetNode = an_lookup.get(the_gn.get_meta("hy_asset_node_id", ""))
                the_ans[the_gn] = the_an
        undo_manager.add_do_method(redo_add_gns.bind(added_gns, the_ans))
    if added_conns.size() > 0:
        undo_manager.add_do_method(add_multiple_connections.bind(added_conns, false))
    if removed_conns.size() > 0:
        undo_manager.add_do_method(remove_multiple_connections.bind(removed_conns, false))
    
    if added_conns.size() > 0:
        undo_manager.add_undo_method(remove_multiple_connections.bind(added_conns, false))
    if removed_conns.size() > 0:
        undo_manager.add_undo_method(add_multiple_connections.bind(removed_conns, false))
    if added_gns.size() > 0:
        undo_manager.add_undo_method(undo_add_gns.bind(added_gns))
    
    undo_manager.commit_action(false)

func create_add_new_gn_undo_step(the_new_gn: GraphNode) -> void:
    undo_manager.create_action("Add New GN")
    var the_asset_node: HyAssetNode = null
    if the_new_gn.get_meta("hy_asset_node_id", ""):
        the_asset_node = an_lookup[the_new_gn.get_meta("hy_asset_node_id")]

    undo_manager.add_do_method(redo_add_graph_node.bind(the_new_gn, the_asset_node))
    
    undo_manager.add_undo_method(undo_add_graph_node.bind(the_new_gn))

    undo_manager.commit_action(false)

func redo_add_gns(the_gns: Array[GraphNode], the_ans: Dictionary[GraphNode, HyAssetNode]) -> void:
    for the_gn in the_gns:
        redo_add_graph_node(the_gn, the_ans[the_gn])

func redo_add_graph_node(the_graph_node: GraphNode, the_asset_node: HyAssetNode) -> void:
    _register_asset_node(the_asset_node)
    an_lookup[the_asset_node.an_node_id] = the_asset_node
    gn_lookup[the_asset_node.an_node_id] = the_graph_node
    add_child(the_graph_node, true)

func undo_add_gns(the_gns: Array[GraphNode]) -> void:
    for the_gn in the_gns:
        undo_add_graph_node(the_gn)

func undo_add_graph_node(the_graph_node: GraphNode) -> void:
    if the_graph_node.get_meta("hy_asset_node_id", ""):
        var the_asset_node: HyAssetNode = an_lookup[the_graph_node.get_meta("hy_asset_node_id", "")]
        _erase_asset_node(the_asset_node)
        an_lookup.erase(the_asset_node.an_node_id)
        gn_lookup.erase(the_asset_node.an_node_id)
    remove_child(the_graph_node)

func on_requested_save_file(file_path: String) -> void:
    save_to_json_file(file_path)

func save_to_json_file(file_path: String) -> void:
    var json_str: = get_asset_node_graph_json_str()
    var file: = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("Error opening JSON file for writing: %s" % file_path)
        return
    file.store_string(json_str)
    file.close()
    prints("Saved asset node graph to JSON file: %s" % file_path)

func find_parent_asset_node(an: HyAssetNode) -> HyAssetNode:
    if an == root_node:
        return null
    var main_tree_result: = _find_parent_asset_node_in_tree(root_node, an)
    if main_tree_result[0]:
        return main_tree_result[1]
    for floating_tree_root in floating_tree_roots:
        if floating_tree_root == an:
            return null
        var floating_tree_result: = _find_parent_asset_node_in_tree(floating_tree_root, an)
        if floating_tree_result[0]:
            return floating_tree_result[1]
    return null

func _find_parent_asset_node_in_tree(current_an: HyAssetNode, looking_for_an: HyAssetNode) -> Array:
    if current_an == looking_for_an:
        return [true, null]
    
    var conn_names: Array[String] = current_an.connection_list
    for conn_name in conn_names:
        for connected_an in current_an.get_all_connected_nodes(conn_name):
            var branch_result: = _find_parent_asset_node_in_tree(connected_an, looking_for_an)
            if branch_result[0]:
                if not branch_result[1]:
                    return [true, current_an]
                return branch_result
    
    return [false, null]

func get_asset_node_graph_json_str() -> String:
    var serialized_data: Dictionary = serialize_asset_node_graph()
    var json_str: = JSON.stringify(serialized_data, "  " if save_formatted_json else "", false)
    if not json_str:
        push_error("Error serializing asset node graph")
        return ""
    return json_str

func serialize_asset_node_graph() -> Dictionary:
    for an in all_asset_nodes:
        an.sort_connections_by_gn_pos(gn_lookup)

    var serialized_data: Dictionary = root_node.serialize_me(schema, gn_lookup)
    serialized_data["$NodeEditorMetadata"] = serialize_node_editor_metadata()
    
    return serialized_data

func _set_child_sorting_metadata(an: HyAssetNode) -> void:
    var conn_names: Array[String] = an.connection_list
    for conn_name in conn_names:
        var connected_nodes: Array[HyAssetNode] = an.get_all_connected_nodes(conn_name)
        for idx_local in connected_nodes.size():
            connected_nodes[idx_local].set_meta("metadata_parent", an)
            connected_nodes[idx_local].set_meta("metadata_index_local", idx_local)
            _set_child_sorting_metadata(connected_nodes[idx_local])

func serialize_node_editor_metadata() -> Dictionary:
    var serialized_metadata: Dictionary = {}
    serialized_metadata["$Nodes"] = {}
    var root_gn: = gn_lookup.get(root_node.an_node_id, null) as GraphNode
    if not root_gn:
        push_error("Serialize Node Editor Metadata: Root node graph node not found")
        return {}
    var fallback_pos: = ((root_gn.position_offset - Vector2(200, 200)) / json_positions_scale).round()

    var roots: Array[HyAssetNode] = [root_node]
    roots.append_array(floating_tree_roots)
    for root in roots:
        root.set_meta("metadata_index_local", 0)
        _set_child_sorting_metadata(root)

    for an in all_asset_nodes:
        var gn: = gn_lookup.get(an.an_node_id, null) as GraphNode
        var gn_pos: Vector2 = fallback_pos
        if gn:
            gn_pos = (gn.position_offset / json_positions_scale).round()
        else:
            var parent_an: HyAssetNode = an
            var parent_gn: GraphNode = null
            while parent_gn == null and parent_an != null:
                parent_an = parent_an.get_meta("metadata_parent", null)
                parent_gn = gn_lookup.get(parent_an.an_node_id, null) as GraphNode
            if parent_gn:
                var my_idx_local: int = an.get_meta("metadata_index_local", 0)
                var unadjusted_pos: = parent_gn.position_offset + Vector2(parent_gn.size.x + 100, 0)
                unadjusted_pos += Vector2.ONE * 10 * my_idx_local
                gn_pos = (unadjusted_pos / json_positions_scale).round()
        var node_meta_stuff: Dictionary = {
            "$Position": {
                "$x": gn_pos.x,
                "$y": gn_pos.y,
            },
        }
        if an.title:
            node_meta_stuff["$Title"] = an.title
        serialized_metadata["$Nodes"][an.an_node_id] = node_meta_stuff

    var floating_trees_serialized: Array[Dictionary] = []
    for floating_tree_root_an in floating_tree_roots:
        floating_trees_serialized.append(floating_tree_root_an.serialize_me(schema, gn_lookup))
    serialized_metadata["$FloatingNodes"] = floating_trees_serialized
    serialized_metadata["$WorkspaceID"] = hy_workspace_id
    
    for other_key in all_meta.keys():
        if serialized_metadata.has(other_key):
            continue
        serialized_metadata[other_key] = all_meta[other_key]
    return serialized_metadata

func test_reserialize_to_file(data_from_json: Dictionary) -> void:
    var file_path: = "user://test_reserialize.json"
    var file: = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        print_debug("Error opening JSON file for writing (test reserialize): %s" % file_path)
        return
    file.store_string(JSON.stringify(data_from_json, "  ", false))
    file.close()

func on_new_node_type_picked(node_type: String) -> void:
    prints("New node type picked: %s" % node_type)
    var new_an: HyAssetNode = get_new_asset_node(node_type)
    var new_gn: CustomGraphNode = null
    if next_drop_has_connection:
        if next_drop_has_connection.has("from_node"):
            new_gn = make_and_add_graph_node(new_an, dropping_new_node_at)
            new_gn.position_offset += output_port_drop_offset
            next_drop_has_connection["to_node"] = new_gn.name
            next_drop_has_connection["to_port"] = 0
        else:
            new_gn = make_and_add_graph_node(new_an, dropping_new_node_at)
            new_gn.position_offset.x -= new_gn.size.x

            next_drop_has_connection["from_node"] = new_gn.name
            var new_an_schema: Dictionary = schema.node_schema[new_an.an_type]
            var input_conn_index: int = -1
            var conn_names: Array = new_an_schema.get("connections", {}).keys()
            for conn_idx in conn_names.size():
                if new_an_schema["connections"][conn_names[conn_idx]].get("value_type", "") == next_drop_conn_value_type:
                    input_conn_index = conn_idx
                    break
            if input_conn_index == -1:
                print_debug("New node type picked: No input connection found for value type: %s" % next_drop_conn_value_type)
                input_conn_index = 0

            next_drop_has_connection["from_port"] = input_conn_index
            new_gn.position_offset += input_port_drop_first_offset + (input_port_drop_additional_offset * input_conn_index)
        cur_connection_added_gns.append(new_gn)
        add_connection(next_drop_has_connection)
    else:
        var screen_center_pos: = get_viewport().get_visible_rect().size / 2
        new_gn = make_and_add_graph_node(new_an, screen_center_pos)
        new_gn.position_offset -= new_gn.size / 2
        create_add_new_gn_undo_step(new_gn)


func can_dissolve_gn(graph_node: GraphNode) -> bool:
    if not graph_node.get_meta("hy_asset_node_id", ""):
        return false
    
    var all_gn_connections: Array[Dictionary] = get_connection_list_from_node(graph_node.name)
    var has_output_connection: bool = false
    var output_gn: GraphNode = null
    var output_port_idx: int = -1
    var in_ports_connected: Array[int] = []
    var in_port_connection_count: Dictionary[int, int] = {}
    for conn_info in all_gn_connections:
        if conn_info["from_node"] == graph_node.name:
            if not in_ports_connected.has(conn_info["from_port"]):
                in_ports_connected.append(conn_info["from_port"])
                in_port_connection_count[conn_info["from_port"]] = 1
            else:
                in_port_connection_count[conn_info["from_port"]] += 1
        elif conn_info["to_node"] == graph_node.name:
            has_output_connection = true
            output_gn = get_node(NodePath(conn_info["to_node"]))
            output_port_idx = conn_info["to_port"]
    
    if not has_output_connection or in_ports_connected.size() == 0:
        return true
    elif in_ports_connected.size() > 1:
        return false

    var only_in_port_idx: = in_ports_connected[0]
    var needs_multi_port: bool = in_port_connection_count[only_in_port_idx] > 1

    var asset_node: HyAssetNode = an_lookup.get(graph_node.get_meta("hy_asset_node_id"), null)
    if not asset_node or not asset_node.an_type or not schema.node_schema.has(asset_node.an_type):
        print_debug("Can dissolve GN: Asset node not found or AN type not found")
        return false
    
    var type_schema: Dictionary = schema.node_schema[asset_node.an_type]
    var output_value_type: String = type_schema.get("output_value_type", "")

    var connection_name: String = asset_node.connection_list[only_in_port_idx]
    var input_value_type: String = type_schema.get("connections", {})[connection_name].get("value_type", "")
    
    if output_value_type != input_value_type:
        return false
    
    if needs_multi_port:
        var out_an: HyAssetNode = an_lookup.get(output_gn.get_meta("hy_asset_node_id", ""))
        if not out_an or not out_an.an_type or not schema.node_schema.has(out_an.an_type):
            return false
        var out_type_schema: Dictionary = schema.node_schema[out_an.an_type]
        var out_connection_name: String = out_an.connection_list[output_port_idx]
        var out_is_multi: bool = out_type_schema.get("connections", {})[out_connection_name].get("multi", false)
        if not out_is_multi:
            return false
    
    return true

func _on_graph_node_right_clicked(graph_node: CustomGraphNode) -> void:
    print("Graph node right clicked: %s" % graph_node.name)
    if connection_cut_active:
        return
    if not graph_node.selectable:
        return
    context_menu_movement_acc = 24
    context_menu_gn = graph_node
    context_menu_ready = true

func cancel_context_menu() -> void:
    context_menu_gn = null
    context_menu_ready = false

func actually_right_click_gn(graph_node: CustomGraphNode) -> void:
    context_menu_gn = null
    context_menu_ready = false
    if not graph_node.selected:
        set_selected(graph_node)
    var context_menu: PopupMenu = PopupMenu.new()
    context_menu.name = "NodeContextMenu"
    context_menu.add_item("Delete Node", NodeContextMenu.DELETE_NODE)
    context_menu.add_item("Dissolve Node", NodeContextMenu.DISSOLVE_NODE)
    context_menu.id_pressed.connect(on_node_context_menu_id_pressed.bind(graph_node))
    add_child(context_menu, true)

    var window: = get_window()
    context_menu.position = get_global_mouse_position()
    if not window.gui_embed_subwindows:
        context_menu.position += window.position
    context_menu.popup()

func on_node_context_menu_id_pressed(node_context_menu_id: NodeContextMenu, on_gn: GraphNode) -> void:
    match node_context_menu_id:
        NodeContextMenu.DELETE_NODE:
            _delete_request([on_gn.name])
        NodeContextMenu.DISSOLVE_NODE:
            if can_dissolve_gn(on_gn):
                pass#dissolve_node(on_gn)

func get_graph_node_name(base_name: String) -> String:
    global_gn_counter += 1
    return "%s--%d" % [base_name, global_gn_counter]