class_name CHANE_AssetNodeEditor
extends Control

const AssetNodeFileHelper = preload("./asset_node_file_helper.gd")

const SpecialGNFactory = preload("res://graph_editor/custom_graph_nodes/special_gn_factory.gd")
const GraphNodeFactory = preload("res://graph_editor/custom_graph_nodes/graph_node_factory.gd")

const Fragment: = preload("res://graph_editor/asset_node_fragment.gd")
const FragmentRoot: = preload("res://graph_editor/fragment_root.gd")
const FragmentStore: = preload("res://graph_editor/fragment_store.gd")

const UndoManager = preload("res://graph_editor/undo_redo/undo_manager.gd")
const UndoStep = preload("res://graph_editor/undo_redo/undo_step.gd")

const SettingsMenu = preload("res://ui/settings_menu.gd")

enum ContextMenuItems {
    COPY_NODES = 1,
    CUT_NODES,
    CUT_NODES_DEEP,
    PASTE_NODES,
    DUPLICATE_NODES,

    DELETE_NODES,
    DELETE_NODES_DEEP,
    DELETE_GROUPS_ONLY,
    DISSOLVE_NODES,
    BREAK_CONNECTIONS,
    
    EDIT_TITLE,
    EDIT_GROUP_TITLE,
    
    CHANGE_GROUP_COLOR,
    SET_GROUP_SHRINKWRAP,
    SET_GROUP_NO_SHRINKWRAP,

    SELECT_SUBTREE,
    SELECT_SUBTREE_GREEDY,
    SELECT_GROUP_NODES,
    SELECT_GROUPS_NODES,
    SELECT_ALL,
    DESELECT_ALL,
    INVERT_SELECTION,
    
    CREATE_NEW_NODE,
    CREATE_NEW_GROUP,
    
    SET_GROUP_SIZE_AS_DEFAULT,
    
    NEW_FILE,
}

const DEFAULT_HY_WORKSPACE_ID: String = "HytaleGenerator - Biome"
var hy_workspace_id: String = ""

var graphs: Array[CHANE_AssetNodeGraphEdit] = []
var focused_graph: CHANE_AssetNodeGraphEdit = null

var serializer: = CHANE_HyAssetNodeSerializer.new()

@export var popup_menu_root: PopupMenuRoot

@export var save_formatted_json: = true

@export var use_json_positions: = true
@export var json_positions_scale: Vector2 = Vector2(0.6, 0.6)

@onready var graph_node_factory: GraphNodeFactory = GraphNodeFactory.new()
@onready var special_gn_factory: SpecialGNFactory = graph_node_factory.special_gn_factory

var undo_manager: UndoManager = UndoManager.new()

var current_copied_fragment: Fragment = null
var current_copied_fragment_ge_count: int = 0
var fragment_store: = FragmentStore.new()

var cur_drop_info: Dictionary = {}

var root_asset_node: HyAssetNode = null
var root_graph_node: CustomGraphNode = null
var all_asset_nodes: Dictionary[String, HyAssetNode] = {}
var asset_node_aux_data: Dictionary[String, HyAssetNode.AuxData] = {}

var gn_lookup: Dictionary[String, CustomGraphNode] = {}

var raw_metadata: Dictionary = {}

var is_loaded: = false

var file_helper: = AssetNodeFileHelper.new()
var file_history_version: int = -10 

var _skip_load: = false
var _skip_loaded_path: String = ""

func _ready() -> void:
    serializer.name = "HyAssetNodeSerializer"
    add_child(serializer, true)
    undo_manager.set_editor(self)

    fragment_store.name = "FragmentStore"
    add_child(fragment_store, true)

    file_helper.name = "FileHelper"
    file_helper.after_saved.connect(on_after_file_saved)
    add_child(file_helper, true)

    get_window().files_dropped.connect(on_files_dropped)

    FileDialogHandler.requested_open_file.connect(_on_requested_open_file)
    FileDialogHandler.requested_save_file.connect(_on_requested_save_file)
    
    ANESettings.interface_color_changed.connect(on_interface_color_changed)
    on_interface_color_changed()
    
    popup_menu_root.new_gn_menu.node_type_picked.connect(on_new_node_type_picked)
    popup_menu_root.new_gn_menu.cancelled.connect(on_new_node_menu_cancelled)
    popup_menu_root.popup_menu_opened.connect(on_popup_menu_opened)
    
    popup_menu_root.new_file_type_chooser.file_type_chosen.connect(_on_new_file_type_chosen)

    for child in get_children():
        if child is CHANE_AssetNodeGraphEdit:
            child.set_editor(self)
            graphs.append(child)
    if graphs.size() > 0:
        focused_graph = graphs[0]

    await get_tree().process_frame
    if not is_loaded:
        popup_menu_root.show_new_file_type_chooser()
    
    graph_node_factory.name = "GraphNodeFactory"
    add_child(graph_node_factory, true)

func is_different_from_file_version() -> bool:
    return undo_manager.undo_redo.get_version() != file_history_version

func an_aux_position_sort_func(a: HyAssetNode, b: HyAssetNode) -> bool:
    var aux_a: = asset_node_aux_data[a.an_node_id]
    var aux_b: = asset_node_aux_data[b.an_node_id]
    if aux_a.position.y == aux_b.position.y:
        return aux_a.position.x <= aux_b.position.x
    return aux_a.position.y < aux_b.position.y

func on_after_file_saved() -> void:
    file_history_version = undo_manager.undo_redo.get_version()
    undo_manager.prevent_merges()

func connect_new_request(drop_info: Dictionary) -> void:
    cur_drop_info = drop_info
    popup_menu_root.show_filtered_new_gn_menu(drop_info["is_right"], drop_info["connection_value_type"])

func on_new_node_type_picked(node_type: String) -> void:
    var undo_step: = undo_manager.start_undo_step("Add New Node")

    var new_an: HyAssetNode = get_new_asset_node(node_type)
    add_undo_step_created_asset_node(new_an, undo_step)

    var dropping_in_graph: CHANE_AssetNodeGraphEdit = cur_drop_info.get("dropping_in_graph", null)
    var dropping_at_pos_offset: Vector2 = cur_drop_info.get("at_pos_offset", Vector2.ZERO)
    var pos_is_centered: bool = not cur_drop_info.get("connection_info", {})
    if not cur_drop_info.get("has_position", false):
        dropping_at_pos_offset = dropping_in_graph.get_center_pos_offset()
    var new_gn: = make_new_default_graph_node_for_an(new_an, dropping_at_pos_offset, pos_is_centered)

    var skip_connection: bool = true
    var connection_info: Dictionary = {}
    if cur_drop_info.get("connection_info", {}):
        var conn_value_type: String = cur_drop_info.get("connection_value_type", "")
        connection_info = cur_drop_info["connection_info"]
        skip_connection = not can_connect_dropped_node(connection_info, new_an.an_type, conn_value_type)

        if connection_info.has("from_node"):
            connection_info["to_node"] = new_gn.name
            connection_info["to_port"] = 0
            new_gn.position_offset += dropping_in_graph.get_drop_offset_for_output_port()
        else:
            connection_info["from_node"] = new_gn.name
            # start at top right corner
            new_gn.position_offset.x -= new_gn.size.x
            # "from_port" already set by can_connect_dropped_node()
            new_gn.position_offset += dropping_in_graph.get_drop_offset_for_input_port(connection_info["from_port"])

    var added_connections: Array[Dictionary] = []
    if not skip_connection:
        added_connections.append(connection_info)
        undo_step.add_asset_node_connection_info(new_graph_connection_to_asset_node_conn_info(dropping_in_graph, connection_info, new_gn))
        
    var added_group_relations: Array[Dictionary] = []
    if cur_drop_info.get("into_group", null):
        added_group_relations.append({ "group": cur_drop_info["into_group"].name, "member": new_gn.name })
    
    dropping_in_graph.add_graph_node_child(new_gn, true)

    var graph_undo_step: = undo_step.get_undo_for_graph(dropping_in_graph)
    graph_undo_step.add_new_default_graph_node_for(new_an.an_node_id, new_gn.name, new_gn.position_offset, added_connections, added_group_relations)
    
    undo_manager.commit_current_undo_step()

func _readd_new_default_graph_node_for(graph: CHANE_AssetNodeGraphEdit, new_an_id: String, new_gn_name: String, at_pos_offset: Vector2) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    var the_an: = all_asset_nodes[new_an_id]
    var new_gn: CustomGraphNode = make_new_default_graph_node_for_an(the_an, at_pos_offset, false)
    new_gn.name = new_gn_name
    graph.add_graph_node_child(new_gn, true)

## Also updates dropped_conn_info["from_port"] if it found a valid input port for a left connect
func can_connect_dropped_node(dropped_conn_info: Dictionary, dropped_node_type: String, conn_value_type: String) -> bool:
    if dropped_conn_info.has("from_node"):
        var num_outputs: int = SchemaManager.schema.get_num_output_connections(dropped_node_type)
        if num_outputs == 0:
            return false
        var output_type: String = SchemaManager.schema.get_output_value_type(dropped_node_type)
        return conn_value_type == "" or conn_value_type == output_type
    else:
        var input_value_types: Array[String] = SchemaManager.schema.get_input_conn_value_types_list(dropped_node_type)
        var first_with_type_idx: = input_value_types.find(conn_value_type)
        if first_with_type_idx >= 0:
            dropped_conn_info["from_port"] = first_with_type_idx
        return first_with_type_idx >= 0


func on_new_node_menu_cancelled() -> void:
    clear_cur_drop_info()

func clear_cur_drop_info() -> void:
    cur_drop_info.clear()

func on_file_menu_index_pressed(index: int, file_menu: PopupMenu, _graph: CHANE_AssetNodeGraphEdit) -> void:
    var menu_item_text: = file_menu.get_item_text(index)
    match menu_item_text:
        "Open":
            FileDialogHandler.show_open_file_dialog()
        "Save":
            if file_helper.has_saved_to_cur_file:
                resave_current_file()
            else:
                FileDialogHandler.show_save_file_dialog(file_helper.get_cur_file_name(), file_helper.get_cur_file_directory())
        "Save As ...":
            FileDialogHandler.show_save_file_dialog()
        "New":
            popup_menu_root.show_new_file_type_chooser()
        "Print File Diff":
            _skip_load = true
            FileDialogHandler.show_open_file_dialog()
            await FileDialogHandler.requested_open_file
            var curr_data: Dictionary = get_serialized_data_for_save()
            print("---")
            prints("Diffing current file with: %s" % _skip_loaded_path)
            _skip_load = false
            var loaded_data: Dictionary = file_helper.get_file_data(_skip_loaded_path)
            Util.print_plain_data_diff(curr_data, loaded_data)
            print("---")


func on_settings_menu_index_pressed(index: int, settings_menu: SettingsMenu) -> void:
    if index == settings_menu.customize_theme_colors_idx:
        popup_menu_root.show_theme_editor()

func on_popup_menu_opened() -> void:
    for graph in graphs:
        if graph.has_focus():
            prints("popup menu opened, graph %s had focus" % [graph.get_path()])
            graph.release_focus()

# TODO: This should be outside the context of a single editor if multiple editors are supported
func on_files_dropped(dragged_files: PackedStringArray) -> void:
    var json_files: Array[String] = []
    for dragged_file in dragged_files:
        if dragged_file.get_extension() == "json":
            json_files.append(dragged_file)
    if json_files.size() == 0:
        return
    var json_file_path: String = json_files[0]
    prompt_and_load_file(json_file_path)

func are_shortcuts_allowed() -> bool:
    return not popup_menu_root.is_menu_visible()

func _pre_serialize() -> void:
    update_all_aux_positions()
    sort_all_asset_nodes_connections()
    #for graph in graphs:
        #graph.sort_all_an_connections()
    update_all_aux_positions()

func update_all_aux_positions() -> void:
    for graph in graphs:
        update_all_aux_for_graph(graph)

func update_all_aux_for_graph(graph: CHANE_AssetNodeGraphEdit) -> void:
    for graph_node in graph.get_all_graph_nodes():
        graph_node.update_aux_positions(asset_node_aux_data)

func update_asset_nodes_aux_positions(asset_nodes: Array[HyAssetNode]) -> void:
    var all_owning_gns: Array[CustomGraphNode] = get_all_owning_gns_for_asset_node_set(asset_nodes)
    for the_gn in all_owning_gns:
        the_gn.update_aux_positions(asset_node_aux_data)

func debug_print_asset_node_trees() -> void:
    var an_roots: = get_an_roots_within_registered_set(all_asset_nodes.values())
    for an_root in an_roots:
        print_an_tree(an_root)

func print_an_tree(an_root: HyAssetNode) -> void:
    prints("an tree root: %s" % an_root.an_node_id)
    print_an_tree_recurse(an_root, 1)

func print_an_tree_recurse(an_root: HyAssetNode, depth: int) -> void:
    for child_an in an_root.get_all_connected_nodes():
        prints("%s- %s" % ["  ".repeat(depth), child_an.an_node_id])
        print_an_tree_recurse(child_an, depth + 1)

## Update the aux positions of the set of asset nodes and resorts their parent's asset node connections
## if inclusive is true, also updates the positions of direct children and sorts the connections of the leaf nodes in the set
func update_and_sort_asset_nodes_connections(asset_nodes: Array[HyAssetNode], inclusive: bool = true) -> void:
    var ans_to_sort: Array[HyAssetNode] = include_asset_nodes_direct_parents(asset_nodes)
    var ans_to_update: Array[HyAssetNode] = asset_nodes
    if inclusive:
        ans_to_update = include_asset_nodes_direct_children(ans_to_update)
    else:
        ans_to_sort = exclude_leaf_asset_nodes(ans_to_sort)
    update_asset_nodes_aux_positions(ans_to_update)
    sort_asset_nodes_connected(ans_to_sort)

func sort_asset_nodes_connected(asset_nodes: Array[HyAssetNode]) -> void:
    for asset_node in asset_nodes:
        asset_node.sort_connected_nodes_with_sort_func(an_aux_position_sort_func)

func sort_all_asset_nodes_connections() -> void:
    for asset_node in all_asset_nodes.values():
        asset_node.sort_connected_nodes_with_sort_func(an_aux_position_sort_func)

func sort_an_connected_for_moved_gns(moved_graph_elements: Array) -> void:
    var all_included_asset_nodes: Array[HyAssetNode] = []
    for moved_ge in moved_graph_elements:
        if moved_ge is CustomGraphNode:
            all_included_asset_nodes.append_array(get_gn_own_asset_nodes(moved_ge))
    update_and_sort_asset_nodes_connections(all_included_asset_nodes, false)

func sort_an_connected_for_moved_ge_names(ge_names: Array[String]) -> void:
    var all_included_asset_nodes: Array[HyAssetNode] = []
    for ge_name in ge_names:
        for graph in graphs:
            var ge: = graph.get_node_or_null(NodePath(ge_name))
            if ge and ge is CustomGraphNode:
                all_included_asset_nodes.append_array(get_gn_own_asset_nodes(ge))
                break
    update_and_sort_asset_nodes_connections(all_included_asset_nodes, false)

func get_all_top_level_graph_nodes() -> Array[CustomGraphNode]:
    var top_level_gns: Array[CustomGraphNode] = []
    for graph in graphs:
        top_level_gns.append_array(graph.get_top_level_graph_nodes())
    return top_level_gns

func get_owner_gn_of_asset_node(asset_node: HyAssetNode) -> CustomGraphNode:
    for graph in graphs:
        for graph_node in graph.get_all_graph_nodes():
            if graph_node.get_meta("hy_asset_node_id", "") == asset_node.an_node_id:
                return graph_node
            elif gn_is_special(graph_node) and graph_node.get_own_asset_nodes().has(asset_node):
                return graph_node
    return null

func get_top_level_asset_node_from_asset_node(asset_node: HyAssetNode) -> HyAssetNode:
    var current_an: = asset_node
    var safety: int = 100000
    while true:
        var parent_an: = get_parent_an(current_an)
        if not parent_an:
            return current_an
        current_an = parent_an
        
        safety -= 1
        if safety <= 0:
            push_error("get_top_level_asset_node_from_asset_node: Safety limit reached, aborting")
            return null
    return null

func get_all_owning_gns_for_asset_node_set(asset_nodes: Array[HyAssetNode]) -> Array[CustomGraphNode]:
    #prints("get_all_owning_gns_for_asset_node_set: asset nodes: %s" % asset_nodes.map(func(an): return an.an_node_id))
    var owning_gns: Array[CustomGraphNode] = []
    var all_top_level_gns: Array[CustomGraphNode] = get_all_top_level_graph_nodes()
    var local_an_roots: = get_an_roots_within_registered_set(asset_nodes)
    for local_an_root in local_an_roots:
        var global_an_root: = get_top_level_asset_node_from_asset_node(local_an_root)
        var gn_tree_root: CustomGraphNode = null
        for top_level_gn in all_top_level_gns:
            if global_an_root == get_gn_main_asset_node(top_level_gn):
                gn_tree_root = top_level_gn
                break
        if not gn_tree_root:
            push_error("get_all_owning_gns_for_asset_node_set: Could not find gn tree root for asset node %s" % local_an_root.an_node_id)
            continue
        
        var in_graph: = gn_tree_root.get_parent() as CHANE_AssetNodeGraphEdit
        var gn_tree: = in_graph.get_graph_node_subtree(gn_tree_root)
        var gn_subtree_root: = _find_owning_gn_in_subtree(local_an_root, gn_tree, gn_tree_root)
        if not gn_subtree_root:
            push_error("get_all_owning_gns_for_asset_node_set: Could not find gn subtree root for asset node %s" % local_an_root.an_node_id)
            continue
        
        for gn in enumerate_gn_subtree(gn_tree, gn_subtree_root):
            for owned_an in get_gn_own_asset_nodes(gn):
                if owned_an in asset_nodes:
                    owning_gns.append(gn)
                    break

    return owning_gns

func enumerate_gn_subtree(subtree: Dictionary[CustomGraphNode, Array], at_gn: CustomGraphNode) -> Array[CustomGraphNode]:
    var enumerated_gns: Array[CustomGraphNode] = [at_gn]
    for child_gn in subtree.get(at_gn, []):
        enumerated_gns.append_array(enumerate_gn_subtree(subtree, child_gn))
    return enumerated_gns

func _filter_an_subtree(asset_nodes: Array[HyAssetNode], subtree_root: HyAssetNode) -> Array[HyAssetNode]:
    var filtered_ans: Array[HyAssetNode] = [subtree_root]
    for connected_an in subtree_root.get_all_connected_nodes():
        if connected_an in asset_nodes:
            filtered_ans.append_array(_filter_an_subtree(asset_nodes, connected_an))
    return filtered_ans

func _find_owning_gn_in_subtree(asset_node: HyAssetNode, subtree: Dictionary[CustomGraphNode, Array], at_gn: CustomGraphNode) -> CustomGraphNode:
    if get_gn_own_asset_nodes(at_gn).has(asset_node):
        return at_gn
    for child_gn in subtree.get(at_gn, []):
        var found_gn: = _find_owning_gn_in_subtree(asset_node, subtree, child_gn)
        if found_gn:
            return found_gn
    return null

func _on_new_file_type_chosen(workspace_id: String) -> void:
    prompt_and_make_new_file(workspace_id)

func prompt_and_make_new_file(workspace_id: String) -> void:
    if is_different_from_file_version() or all_asset_nodes.size() <= 1:
        _make_new_file_with_workspace_id(workspace_id)
    else:
        var prompt_text: = "Do you want to save the current file before creating a new file?"
        popup_menu_root.show_save_confirm(prompt_text, file_helper.has_cur_file(), _make_new_file_with_workspace_id.bind(workspace_id))

func _make_new_file_with_workspace_id(workspace_id: String) -> void:
    setup_new_graph(workspace_id)


func setup_new_graph(workspace_id: String = DEFAULT_HY_WORKSPACE_ID) -> void:
    clear_loaded_graph()
    hy_workspace_id = workspace_id
    # just set the normal raw metadata keys and the workspace id, everything else should be created on the fly
    raw_metadata = CHANE_HyAssetNodeSerializer.get_empty_editor_metadata()
    raw_metadata[CHANE_HyAssetNodeSerializer.MetadataKeys.WorkspaceId] = workspace_id

    var root_node_type: = SchemaManager.schema.resolve_root_asset_node_type(workspace_id, {}) as String
    var new_root_node: HyAssetNode = get_new_asset_node(root_node_type)
    var screen_center_pos: Vector2 = get_viewport_rect().size / 2
    var new_gn: CustomGraphNode = make_and_add_graph_node(focused_graph, new_root_node, screen_center_pos, true, true)
    _set_root_nodes(new_root_node, new_gn)

    focused_graph.scroll_to_graph_element(new_gn)
    #gn_lookup[new_root_node.an_node_id] = new_gn
    is_loaded = true
    file_helper.editing_new_file()
    
    file_history_version = undo_manager.undo_redo.get_version()
    
    new_session_started()

func _on_requested_open_file(path: String) -> void:
    if _skip_load:
        _skip_loaded_path = path
        return
    prompt_and_load_file(path)

func _on_requested_save_file(path: String) -> void:
    await get_tree().process_frame
    if not focused_graph:
        print_debug("No graphs to save")
        return
    file_helper.save_to_json_file(get_serialized_for_save(), path)

func resave_current_file() -> void:
    file_helper.resave_current_file(get_serialized_for_save())

func get_serialized_for_save() -> String:
    var serialized_data: Dictionary = get_serialized_data_for_save()
    var json_str: = JSON.stringify(serialized_data, "  " if save_formatted_json else "", false)
    if not json_str:
        push_error("Error creating json string for node graph")
        return ""
    return json_str

func get_serialized_data_for_save() -> Dictionary:
    serializer.serialized_pos_scale = json_positions_scale
    serializer.serialized_pos_offset = Vector2.ZERO
    return serializer.serialize_entire_graph_as_asset(self)

func prompt_and_load_file(json_file_path: String) -> void:
    if is_different_from_file_version() or all_asset_nodes.size() <= 1:
        file_helper.load_json_file(json_file_path, on_got_loaded_data)
    else:
        var prompt_text: = "Do you want to save the current file before loading '%s'?" % json_file_path
        var has_cur: = file_helper.has_cur_file()
        popup_menu_root.show_save_confirm(prompt_text, has_cur, file_helper.load_json_file.bind(json_file_path, on_got_loaded_data))

func on_got_loaded_data(graph_data: Dictionary) -> void:
    if is_loaded:
        clear_loaded_graph()
    serializer.serialized_pos_scale = json_positions_scale
    serializer.serialized_pos_offset = Vector2.ZERO
    var parse_graph_result: = serializer.deserialize_entire_graph(graph_data) as CHANE_HyAssetNodeSerializer.EntireGraphParseResult
    if not parse_graph_result.success:
        file_helper.editing_new_file()
        push_error("Failed to deserialize graph")
        CHANE_HyAssetNodeSerializer.debug_dump_tree_results(parse_graph_result.root_tree_result)
        GlobalToaster.show_toast_message("Something went wrong loading the file :(")
        return
    
    setup_edited_graph_from_parse_result(parse_graph_result)
    
    new_session_started()
    
func new_session_started() -> void:
    ANESettings.root_node_changed(get_root_theme_color(), true)

func change_root_node_to_gn(new_root_graph_node: CustomGraphNode) -> void:
    _set_root_nodes(get_gn_main_asset_node(new_root_graph_node), new_root_graph_node)
    ANESettings.root_node_changed(get_root_theme_color(), false)

func setup_edited_graph_from_parse_result(parse_graph_result: CHANE_HyAssetNodeSerializer.EntireGraphParseResult) -> void:
    hy_workspace_id = parse_graph_result.hy_workspace_id
    use_json_positions = parse_graph_result.has_positions
    _register_asset_nodes_from_graph_result(parse_graph_result)

    raw_metadata = parse_graph_result.editor_metadata
    create_loaded_graph_elements(parse_graph_result)
    
    focused_graph.deselect_all()
    
    # I'm currently accidentally creating undo steps during file load but whatever
    undo_manager.clear()
    is_loaded = true

func create_loaded_graph_elements(graph_result: CHANE_HyAssetNodeSerializer.EntireGraphParseResult) -> void:
    var an_roots: Array[HyAssetNode] = [graph_result.root_node]
    an_roots.append_array(graph_result.floating_tree_roots.values())

    add_graph_nodes_for_loaded_asset_node_trees(focused_graph, an_roots)
    focused_graph.make_json_groups(Array(graph_result.editor_metadata.get("$Groups", []), TYPE_DICTIONARY, &"", null), true)

    var graph_node_roots: Array[CustomGraphNode] = []
    for graph in graphs:
        graph_node_roots.append_array(graph.get_top_level_graph_nodes())
    var found_root_graph_node: CustomGraphNode = null
    for graph_node in graph_node_roots:
        if graph_node.get_meta("hy_asset_node_id", "") == graph_result.root_node.an_node_id:
            found_root_graph_node = graph_node
            break
    if not found_root_graph_node:
        push_error("create_loaded_graph_elements: Could not find root graph node asset node id: %s" % graph_result.root_node.an_node_id)
        clear_loaded_graph()
        return
    _set_root_nodes(graph_result.root_node, found_root_graph_node)
    
    if ANESettings.auto_color_imported_nested_groups:
        for graph in graphs:
            graph.auto_color_nested_groups()
            graph.refresh_graph_elements_in_frame_status()
    
    focused_graph.scroll_to_pos_offset(asset_node_aux_data[root_asset_node.an_node_id].position)

## Does not interact with undo system, only for newly loaded file
func add_graph_nodes_for_loaded_asset_node_trees(graph: CHANE_AssetNodeGraphEdit, tree_roots: Array[HyAssetNode], offset_pos: Vector2 = Vector2.ZERO) -> Array[GraphElement]:
    if graph.snapping_enabled:
        offset_pos = offset_pos.snapped(Vector2.ONE * graph.snapping_distance)
    
    var all_new_ges: Array[GraphElement] = []
    var all_new_connections: Array[Dictionary] = []
    for tree_root_node in tree_roots:
        var new_ans_to_gns: = new_graph_nodes_for_tree(tree_root_node, offset_pos)
        for new_gn in new_ans_to_gns.values():
            if new_gn not in all_new_ges:
                all_new_ges.append(new_gn)

        all_new_connections.append_array(get_new_gn_tree_connections(new_ans_to_gns[tree_root_node], new_ans_to_gns))
    graph.add_graph_element_children(all_new_ges, true)
    graph.undo_redo_add_connections(all_new_connections)
    
    return all_new_ges

func _register_asset_nodes_from_graph_result(graph_result: CHANE_HyAssetNodeSerializer.EntireGraphParseResult) -> void:
    all_asset_nodes = graph_result.all_nodes
    asset_node_aux_data = graph_result.asset_node_aux_data.duplicate()
    update_aux_parents_for_tree(graph_result.root_node)
    for floating_root_an in graph_result.floating_tree_roots.values():
        update_aux_parents_for_tree(floating_root_an)

func update_aux_parents_for_tree(subtree_root: HyAssetNode) -> void:
    var child_ans: Array[HyAssetNode] = subtree_root.get_all_connected_nodes()
    for child_an in child_ans:
        var an_id: = child_an.an_node_id
        asset_node_aux_data[an_id].output_to_node_id = subtree_root.an_node_id
        update_aux_parents_for_tree(child_an)

func register_asset_node(asset_node: HyAssetNode, aux_data: HyAssetNode.AuxData = null) -> void:
    assert(asset_node.an_node_id, "Cannot register an asset node with no ID")
    if OS.has_feature("debug") and all_asset_nodes.has(asset_node.an_node_id):
        print_debug("Re-registering asset node with existing ID %s" % asset_node.an_node_id)
    _register_asset_node(asset_node, aux_data)

func _register_asset_node(asset_node: HyAssetNode, aux_data: HyAssetNode.AuxData = null) -> void:
    all_asset_nodes[asset_node.an_node_id] = asset_node
    if aux_data:
        asset_node_aux_data[asset_node.an_node_id] = aux_data
    else:
        asset_node_aux_data[asset_node.an_node_id] = HyAssetNode.AuxData.new()

func register_asset_nodes(asset_nodes: Array, aux_data: Array) -> void:
    for i in asset_nodes.size():
        _register_asset_node(asset_nodes[i], aux_data[i])

func register_asset_node_at(asset_node: HyAssetNode, node_pos: Vector2, with_parent_id: String = "") -> void:
    var aux_data: HyAssetNode.AuxData = HyAssetNode.AuxData.new()
    aux_data.position = node_pos
    aux_data.output_to_node_id = with_parent_id
    register_asset_node(asset_node, aux_data)

func register_duplicate_asset_node(new_asset_node: HyAssetNode, duplicated_from_id: String, with_parent_id: String = "") -> void:
    var duplicate_aux_data: = asset_node_aux_data[duplicated_from_id].duplicate_with_parent(with_parent_id)
    register_asset_node(new_asset_node, duplicate_aux_data)

func _restore_manual_asset_nodes(asset_node_copies: Array[HyAssetNode], aux_data: Array[HyAssetNode.AuxData]) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    for i in asset_node_copies.size():
        var restored_an: = asset_node_copies[i].get_shallow_copy(asset_node_copies[i].an_node_id)
        _register_asset_node(restored_an, aux_data[i].duplicate(false))

func remove_asset_node_id(asset_node_id: String) -> void:
    print_stack()
    all_asset_nodes.erase(asset_node_id)
    asset_node_aux_data.erase(asset_node_id)

func remove_asset_node_ids(asset_node_ids: Array[String]) -> void:
    for asset_node_id in asset_node_ids:
        remove_asset_node_id(asset_node_id)

func remove_asset_node(asset_node: HyAssetNode) -> void:
    assert(asset_node.an_node_id, "Cannot remove an asset node with no ID")
    remove_asset_node_id(asset_node.an_node_id)

func remove_asset_nodes(asset_nodes: Array[HyAssetNode]) -> void:
    for asset_node in asset_nodes:
        remove_asset_node_id(asset_node.an_node_id)

## Create duplicates of all nodes in the given set, maintaining connections between nodes within the set
## Returns the list of new subtree roots if return_roots = true, otherwise returns the list of all new asset nodes
## Also register the new asset nodes and add them to the current undo step if register = true
## If register = false, duplicate aux data will be created and added into out_aux
func create_duplicate_filtered_an_set(asset_node_set: Array[HyAssetNode], return_roots: bool, register: bool = true, new_ids: bool = true, out_aux: Dictionary[String, HyAssetNode.AuxData] = {}) -> Array[HyAssetNode]:
    var ret: Array[HyAssetNode] = []
    if asset_node_set.size() == 0:
        return ret
    var set_roots: Array[HyAssetNode] = get_an_roots_within_registered_set(asset_node_set)

    for set_root in set_roots:
        var new_duplicate_ans: = create_duplicate_filtered_an_tree(set_root, asset_node_set, register, new_ids, out_aux)
        if return_roots:
            ret.append(new_duplicate_ans[0])
        else:
            ret.append_array(new_duplicate_ans)
    return ret

## Create duplicates of all nodes reachable from the given root node while only passing through nodes in the given set
## Maintains connections within the subtree
## Also register the new asset nodes and add them to the current undo step if register = true
## If register = false, duplicate aux data will be created and added into out_aux
## If asset_node_set is empty, no filter is applied, all nodes in the subtree are duplicated
func create_duplicate_filtered_an_tree(tree_root: HyAssetNode, asset_node_set: Array[HyAssetNode], register: bool = true, new_ids: bool = true, out_aux: Dictionary[String, HyAssetNode.AuxData] = {}) -> Array[HyAssetNode]:
    var root_duplicate_an: HyAssetNode = get_duplicate_asset_node(tree_root, new_ids)
    if register:
        register_duplicate_asset_node(root_duplicate_an, tree_root.an_node_id, "")
    else:
        out_aux[root_duplicate_an.an_node_id] = asset_node_aux_data[tree_root.an_node_id].duplicate(false)
    var all_new_ans: Array[HyAssetNode] = [root_duplicate_an]
    prints("starting to duplicate filtered an tree, root: %s, asset node set: %s" % [tree_root.an_node_id, asset_node_set.map(func(an): return an.an_node_id)])
    _duplicate_filtered_an_tree_recurse(root_duplicate_an, tree_root, asset_node_set, register, new_ids, all_new_ans, out_aux)
    return all_new_ans

func _duplicate_filtered_an_tree_recurse(new_an: HyAssetNode, old_an: HyAssetNode, asset_node_set: Array[HyAssetNode], register: bool, new_ids: bool, all_new_ans: Array[HyAssetNode], out_aux: Dictionary[String, HyAssetNode.AuxData]) -> void:
    for conn_name in old_an.connection_list:
        for connected_an in old_an.get_all_connected_nodes(conn_name):
            if asset_node_set.size() > 0 and not connected_an in asset_node_set:
                continue
            var new_duplicate_an: = get_duplicate_asset_node(connected_an, new_ids)
            all_new_ans.append(new_duplicate_an)
            if register:
                register_duplicate_asset_node(new_duplicate_an, connected_an.an_node_id, new_an.an_node_id)
            else:
                out_aux[new_duplicate_an.an_node_id] = asset_node_aux_data[connected_an.an_node_id].duplicate_with_parent(new_an.an_node_id)
            new_an.append_node_to_connection(conn_name, new_duplicate_an)
            _duplicate_filtered_an_tree_recurse(new_duplicate_an, connected_an, asset_node_set, register, new_ids, all_new_ans, out_aux)

func get_duplicate_asset_node(asset_node: HyAssetNode, reroll_id: bool = true) -> HyAssetNode:
    if reroll_id:
        var new_id: = CHANE_HyAssetNodeSerializer.reroll_an_id(asset_node.an_node_id)
        return asset_node.get_shallow_copy(new_id)
    else:
        return asset_node.get_shallow_copy(asset_node.an_node_id)

func create_single_duplicate_asset_node(asset_node: HyAssetNode) -> HyAssetNode:
    var new_an: HyAssetNode = get_duplicate_asset_node(asset_node)
    register_duplicate_asset_node(new_an, asset_node.an_node_id)
    return new_an

func get_an_roots_within_registered_set(asset_node_set: Array[HyAssetNode]) -> Array[HyAssetNode]:
    return get_an_roots_within_set(asset_node_set, asset_node_aux_data)

static func get_an_roots_within_set_no_aux(asset_node_set: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var temp_aux: Dictionary[String, HyAssetNode.AuxData] = {}
    for asset_node in asset_node_set:
        temp_aux[asset_node.an_node_id] = HyAssetNode.AuxData.new()
    for asset_node in asset_node_set:
        for child_an in asset_node.get_all_connected_nodes():
            temp_aux[child_an.an_node_id].output_to_node_id = asset_node.an_node_id
    return get_an_roots_within_set(asset_node_set, temp_aux)

static func get_an_roots_within_set(asset_node_set: Variant, associated_aux: Dictionary[String, HyAssetNode.AuxData]) -> Array[HyAssetNode]:
    var root_ans: Array[HyAssetNode] = []
    var asset_nodes: Array = []
    if typeof(asset_node_set) == TYPE_ARRAY:
        asset_nodes = asset_node_set
    elif typeof(asset_node_set) == TYPE_DICTIONARY:
        asset_nodes = asset_node_set.values()
    else:
        push_error("Invalid asset node set type: %s" % [type_string(typeof(asset_node_set))])
    var asset_nodes_ids: Array = asset_nodes.map(func(an): return an.an_node_id)

    for asset_node in asset_nodes:
        var parent_an_id: = associated_aux[asset_node.an_node_id].output_to_node_id
        if not parent_an_id or not asset_nodes_ids.has(parent_an_id):
            root_ans.append(asset_node)
    return root_ans

## Get rid of all fragments not referenced after the current edited asset is unloaded and history is cleared, this is just the current copied fragment
func cleanup_fragment_store() -> void:
    var referenced_fragment_ids: Array[String] = []
    if current_copied_fragment:
        referenced_fragment_ids.append(current_copied_fragment.fragment_id)
    fragment_store.remove_all_except(referenced_fragment_ids)

## Unload the current edited asset and (hopefully) cleanup all allocated objects that would now be orphaned
func clear_loaded_graph() -> void:
    # If the current fragment is a cut fragment, first turn it into a copy
    invalidate_current_cut_fragment()
    cleanup_fragment_store()
    
    graph_node_factory.reset_global_gn_counter()

    # Removes and frees all currently added GraphElement Nodes
    for graph in graphs:
        graph.clear_graph()
    
    # Frees orphaned Godot Nodes that were kept around to be re-added or un-deleted
    undo_manager.clear()

    # Asset Nodes and Aux Data are RefCounted
    all_asset_nodes.clear()
    asset_node_aux_data.clear()
    _set_root_nodes(null, null)
    raw_metadata.clear()
    is_loaded = false

func _set_root_nodes(new_root_asset_node: HyAssetNode, new_root_graph_node: CustomGraphNode) -> void:
    root_asset_node = new_root_asset_node
    root_graph_node = new_root_graph_node

func get_new_asset_node(asset_node_type: String, id_prefix: String = "") -> HyAssetNode:
    asset_node_type = SchemaManager.schema.normalize_asset_node_type(asset_node_type)
    if id_prefix == "":
        id_prefix = SchemaManager.schema.get_id_prefix_for_node_type(asset_node_type)

    var new_asset_node: = HyAssetNode.new()
    new_asset_node.an_node_id = CHANE_HyAssetNodeSerializer.get_unique_an_id(id_prefix)
    new_asset_node.an_type = asset_node_type
    initial_asset_node_setup(new_asset_node)
    register_asset_node(new_asset_node)
    return new_asset_node

func initial_asset_node_setup(asset_node: HyAssetNode) -> void:
    var type_schema: = SchemaManager.schema.node_schema.get(asset_node.an_type, {}) as Dictionary
    if not type_schema:
        print_debug("Warning: Asset node type is unknown or empty")

    asset_node.default_title = SchemaManager.schema.get_node_type_default_name(asset_node.an_type)
    asset_node.title = asset_node.default_title
    
    var connections_schema: Dictionary = type_schema.get("connections", {})
    for conn_name in connections_schema.keys():
        asset_node.connection_list.append(conn_name)
        asset_node.connected_node_counts[conn_name] = 0
    
    var settings_schema: Dictionary = type_schema.get("settings", {})
    for setting_name in settings_schema.keys():
        asset_node.settings[setting_name] = settings_schema[setting_name].get("default_value", null)
    asset_node.shallow = false

func _shortcut_input(event: InputEvent) -> void:
    if Input.is_action_just_pressed_by_event("open_file_shortcut", event, true):
        accept_event()
        if popup_menu_root.is_menu_visible():
            popup_menu_root.close_all()
        FileDialogHandler.show_open_file_dialog()
    elif Input.is_action_just_pressed_by_event("save_file_shortcut", event, true):
        accept_event()
        if file_helper.has_saved_to_cur_file:
            file_helper.resave_current_file(get_serialized_for_save())
        else:
            if popup_menu_root.is_menu_visible():
                popup_menu_root.close_all()
            FileDialogHandler.show_save_file_dialog(file_helper.get_cur_file_name(), file_helper.get_cur_file_directory())
    elif Input.is_action_just_pressed_by_event("save_as_shortcut", event, true):
        accept_event()
        if popup_menu_root.is_menu_visible():
            popup_menu_root.close_all()
        FileDialogHandler.show_save_file_dialog()
    elif Input.is_action_just_pressed_by_event("new_file_shortcut", event, true):
        accept_event()
        popup_menu_root.show_new_file_type_chooser()

    if not popup_menu_root.is_menu_visible():
        if Input.is_action_just_pressed_by_event("graph_select_all_nodes", event, true):
            accept_event()
            focused_graph.select_all()
        elif Input.is_action_just_pressed_by_event("graph_deselect_all_nodes", event, true):
            accept_event()
            focused_graph.deselect_all()
        elif Input.is_action_just_pressed_by_event("cut_inclusive_shortcut", event, true):
            accept_event()
            focused_graph.cut_selected_nodes_inclusive()
        elif Input.is_action_just_pressed_by_event("delete_inclusive_shortcut", event, true):
            accept_event()
            focused_graph.delete_selected_nodes_inclusive()

func _unhandled_key_input(event: InputEvent) -> void:
    # These shortcuts have priority even when a non-exclusive popup is open
    # but they will not be triggered if another control has keyboard focus and accepts the event (e.g. if space is show_new_node_menu, typing a space into a LineEdit will not trigger it)
    if Input.is_action_just_pressed_by_event("show_new_node_menu", event, true):
        if not popup_menu_root.is_menu_visible():
            accept_event()
            if is_loaded:
                show_new_asset_node_menu()
            else:
                popup_menu_root.show_new_file_type_chooser()

    if Input.is_action_just_pressed_by_event("ui_redo", event, true):
        accept_event()
        if undo_manager.has_redo():
            prints("Redoing:", undo_manager.get_redo_action_name())
            undo_manager.redo()
        else:
            GlobalToaster.show_toast_message("Nothing to Redo")
    elif Input.is_action_just_pressed_by_event("ui_undo", event, true):
        accept_event()
        if undo_manager.has_undo():
            prints("Undoing:", undo_manager.get_undo_action_name())
            undo_manager.undo()
        else:
            GlobalToaster.show_toast_message("Nothing to Undo")

func show_new_asset_node_menu() -> void:
    clear_cur_drop_info()
    cur_drop_info = {
        "dropping_in_graph": focused_graph,
        "has_position": false,
    }
    popup_menu_root.show_new_gn_menu()

func show_new_node_menu_for_pos(at_pos_offset: Vector2, from_graph: CHANE_AssetNodeGraphEdit, in_group: GraphFrame = null) -> void:
    clear_cur_drop_info()
    cur_drop_info = {
        "dropping_in_graph": from_graph,
        "at_pos_offset": at_pos_offset,
    }
    if in_group:
        cur_drop_info["into_group"] = in_group
    popup_menu_root.show_new_gn_menu()

func get_gn_main_asset_node(graph_node: CustomGraphNode) -> HyAssetNode:
    if not graph_node or not graph_node.get_meta("hy_asset_node_id", ""):
        return null
    return all_asset_nodes.get(graph_node.get_meta("hy_asset_node_id", ""), null)

func get_gn_input_port_asset_node(graph_node: CustomGraphNode, port_idx: int) -> HyAssetNode:
    if not gn_is_special(graph_node):
        return get_gn_main_asset_node(graph_node)
    var current_connections: Dictionary[String, Array] = graph_node.get_all_connections()
    return graph_node.get_parent_an_for_connection(current_connections.keys()[port_idx])

func _get_splice_left_conn(old_conn_info: Dictionary, insert_gn: CustomGraphNode) -> Dictionary:
    return {
        "from_node": old_conn_info["from_node"],
        "from_port": old_conn_info["from_port"],
        "to_node": insert_gn.name,
        "to_port": 0,
    }

func _get_splice_right_conn(old_conn_info: Dictionary, insert_gn: CustomGraphNode, in_idx: int) -> Dictionary:
    return {
        "from_node": insert_gn.name,
        "from_port": in_idx,
        "to_node": old_conn_info["to_node"],
        "to_port": old_conn_info["to_port"],
    }

func splice_graph_node_into_connection(graph: CHANE_AssetNodeGraphEdit, insert_gn: CustomGraphNode, conn_info: Dictionary) -> void:
    if undo_manager.is_creating_undo_step():
        if undo_manager.active_undo_step.action_name == "Move Nodes":
            undo_manager.rename_current_undo_step("Splice Node into Connection")
    else:
        undo_manager.start_undo_step("Splice Node into Connection")
    
    disconnect_graph_nodes([conn_info], graph)

    var value_type: String = graph.get_conn_info_value_type(conn_info)
    if value_type == "":
        push_warning("Splice: Value type of connection is not known")
    
    connect_graph_nodes([_get_splice_left_conn(conn_info, insert_gn)], graph)
    
    var insert_an: = get_gn_main_asset_node(insert_gn)
    if not insert_an:
        push_error("Splice: Insert asset node not found")
        return

    var insert_on_input_idx: = SchemaManager.schema.get_input_conn_value_types_list(insert_an.an_type).find(value_type)
    var should_connect: bool = value_type == "" or insert_on_input_idx >= 0
    if insert_gn.num_outputs == 0:
        should_connect = false
    
    if should_connect:
        insert_on_input_idx = maxi(0, insert_on_input_idx)
        connect_graph_nodes([_get_splice_right_conn(conn_info, insert_gn, insert_on_input_idx)], graph)
    
    undo_manager.commit_current_undo_step()
    

func connect_graph_nodes(conn_infos: Array[Dictionary], graph: CHANE_AssetNodeGraphEdit) -> void:
    if conn_infos.size() == 0:
        return
    var undo_step: = undo_manager.start_or_continue_undo_step("Connect Nodes")
    var graph_undo_step: = undo_step.get_undo_for_graph(graph)
    var is_new_step: = undo_manager.is_new_step
    if not is_new_step and undo_step.action_name == "Add New Node":
        undo_manager.rename_current_undo_step("Add New Node to Connection")
    
    # Add all the raw connections even if there are missing asset nodes
    graph_undo_step.add_graph_node_conn_infos(conn_infos)

    for conn_info in conn_infos:
        var from_gn: = get_graph_gn(graph, conn_info["from_node"])
        var from_an: = get_gn_main_asset_node(from_gn)
        var to_gn: = get_graph_gn(graph, conn_info["to_node"])
        var to_an: = get_gn_main_asset_node(to_gn)
        
        # if outputting asset node found, only allow one output connection
        if to_an:
            disconnect_graph_nodes(graph.raw_out_connections(to_gn), graph)

        if not from_an or not to_an:
            push_warning("From or to asset node not found")
            print_debug("Warning: From or to asset node not found")
            continue

        var from_conn_name: String = SchemaManager.schema.get_input_conn_name_for_idx(from_an.an_type, conn_info["from_port"])
        var from_is_multi: bool = SchemaManager.schema.get_input_conn_is_multi_for_name(from_an.an_type, from_conn_name, true)
        # If asset nodes found and not a multi connection, only allow one input connection
        if not from_is_multi:
            var in_port_connections: = graph.raw_in_port_connections(from_gn, conn_info["from_port"])
            disconnect_graph_nodes(in_port_connections, graph)
        
        # Add the asset node connection to the undo step
        undo_step.add_asset_node_connection(from_an, from_conn_name, to_an)
    
    if is_new_step:
        undo_manager.commit_current_undo_step()

func disconnect_graph_nodes(conn_infos: Array[Dictionary], graph: CHANE_AssetNodeGraphEdit) -> void:
    if conn_infos.size() == 0:
        return
    var undo_step: = undo_manager.start_or_continue_undo_step("Disconnect Nodes")
    var graph_undo_step: = undo_step.get_undo_for_graph(graph)
    var is_new_step: = undo_manager.is_new_step
    
    # Remove all the raw connections even if there are missing asset nodes
    graph_undo_step.remove_graph_node_conn_infos(conn_infos)
    graph_undo_step.remove_graph_node_conn_infos(conn_infos)
    graph_undo_step.remove_graph_node_conn_infos(conn_infos)

    for conn_info in conn_infos:
        var from_an: = get_gn_main_asset_node(get_graph_gn(graph, conn_info["from_node"]))
        var to_an: = get_gn_main_asset_node(get_graph_gn(graph, conn_info["to_node"]))
        if not from_an or not to_an:
            push_warning("From or to asset node not found")
            print_debug("From or to asset node not found")
            continue
        
        var from_conn_name: String = SchemaManager.schema.get_input_conn_name_for_idx(from_an.an_type, conn_info["from_port"])
        undo_step.remove_asset_node_connection(from_an, from_conn_name, to_an)
    
    if is_new_step:
        undo_manager.commit_current_undo_step()

func _connect_asset_node(parent_id: String, child_id: String, connection_name: String) -> void:
    var parent_an: = all_asset_nodes[parent_id]
    var child_an: = all_asset_nodes[child_id]
    _append_an_to_connection(parent_an, connection_name, child_an)

func _add_an_connections(an_connections: Array[Dictionary]) -> void:
    for an_connection in an_connections:
        _connect_asset_node(an_connection["parent_node"], an_connection["child_node"], an_connection["connection_name"])

func _add_an_connections_if_not_commit(an_connections: Array[Dictionary]) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    _add_an_connections(an_connections)

func _add_unadded_an_connections(an_connections: Array[Dictionary]) -> void:
    for an_connection in an_connections:
        assert(all_asset_nodes.has(an_connection["parent_node"]), "Parent asset node %s not found" % an_connection["parent_node"])
        assert(all_asset_nodes.has(an_connection["child_node"]), "Child asset node %s not found" % an_connection["child_node"])
        var connection_exists: bool = false
        var child_parent_id: = asset_node_aux_data[an_connection["child_node"]].output_to_node_id
        if child_parent_id and all_asset_nodes[child_parent_id] == all_asset_nodes[an_connection["parent_node"]]:
            if all_asset_nodes[an_connection["parent_node"]].get_all_connected_nodes(an_connection["connection_name"]).find(all_asset_nodes[an_connection["child_node"]]) >= 0:
                connection_exists = true
        if not connection_exists:
            _connect_asset_node(an_connection["parent_node"], an_connection["child_node"], an_connection["connection_name"])

func _disconnect_asset_node(parent_id: String, child_id: String, connection_name: String) -> void:
    var parent_an: = all_asset_nodes[parent_id]
    var child_an: = all_asset_nodes[child_id]
    parent_an.remove_node_from_connection(connection_name, child_an)
    var child_aux: = asset_node_aux_data[child_id]
    child_aux.output_to_node_id = ""

func _remove_an_connections(an_connections: Array[Dictionary]) -> void:
    for an_connection in an_connections:
        _disconnect_asset_node(an_connection["parent_node"], an_connection["child_node"], an_connection["connection_name"])

func _clear_an_connection(asset_node: HyAssetNode, connection_name: String) -> void:
    for child_an in asset_node.get_all_connected_nodes(connection_name):
        asset_node_aux_data[child_an.an_node_id].output_to_node_id = ""
    asset_node.clear_connection(connection_name)

func _clear_all_an_connections(asset_node: HyAssetNode) -> void:
    for child_an in asset_node.get_all_connected_nodes():
        asset_node_aux_data[child_an.an_node_id].output_to_node_id = ""
    asset_node.clear_all_connections()

func _remove_an_connections_if_not_commit(an_connections: Array[Dictionary]) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    _remove_an_connections(an_connections)

func _find_and_disconnect_asset_node(parent_an: HyAssetNode, child_an: HyAssetNode) -> void:
    for conn_name in parent_an.connection_list:
        var at_idx: = parent_an.get_all_connected_nodes(conn_name).find(child_an)
        if at_idx >= 0:
            parent_an.remove_node_from_connection_at(conn_name, at_idx)
            return

func _disconnect_all_asset_nodes_from(disconnecting_from_an: HyAssetNode) -> void:
    _clear_all_an_connections(disconnecting_from_an)

func _disconnect_all_asset_nodes_from_ans(asset_nodes: Array[HyAssetNode]) -> void:
    for asset_node in asset_nodes:
        _clear_all_an_connections(asset_node)

func _filter_disconnect_asset_node(whitelist: bool, asset_node: HyAssetNode, asset_nodes: Array[HyAssetNode]) -> Array[Dictionary]:
    var previously_connected_nodes: Dictionary[String, Array] = {}
    for conn_name in asset_node.connection_list:
        previously_connected_nodes[conn_name] = asset_node.get_all_connected_nodes(conn_name)
    var removed_connections: Array[Dictionary] = []
    if whitelist:
        asset_node.filter_connected_nodes_within(asset_nodes)
    else:
        asset_node.remove_node_set_from_connections(asset_nodes)
    for still_connected_node in asset_node.get_all_connected_nodes():
        for conn_name in previously_connected_nodes.keys():
            if still_connected_node in previously_connected_nodes[conn_name]:
                previously_connected_nodes[conn_name].erase(still_connected_node)
    
    for conn_name in previously_connected_nodes.keys():
        for disconnected_node in previously_connected_nodes[conn_name]:
            removed_connections.append({
                "parent_node": asset_node.an_node_id,
                "child_node": disconnected_node.an_node_id,
                "connection_name": conn_name,
            })
            asset_node_aux_data[disconnected_node.an_node_id].output_to_node_id = ""
    return removed_connections

func _append_an_to_connection(asset_node: HyAssetNode, connection_name: String, appended_node: HyAssetNode) -> void:
    asset_node.append_node_to_connection(connection_name, appended_node)
    asset_node_aux_data[appended_node.an_node_id].output_to_node_id = asset_node.an_node_id

func _disconnect_an_set_external_connections(asset_nodes: Array[HyAssetNode]) -> Array[Dictionary]:
    var removed_connections: Array[Dictionary] = []
    var external_parents: = get_external_parent_asset_nodes(asset_nodes)
    for external_parent in external_parents:
        removed_connections.append_array(_filter_disconnect_asset_node(false, external_parent, asset_nodes))

    var leaf_ans: = get_leaf_asset_nodes(asset_nodes)
    for leaf in leaf_ans:
        removed_connections.append_array(get_asset_node_in_connections(leaf))
        leaf.clear_all_connections()

    var psuedo_leaf_ans: = get_psuedo_leaf_asset_nodes(asset_nodes)
    for psuedo_leaf in psuedo_leaf_ans:
        if psuedo_leaf in leaf_ans:
            continue
        removed_connections.append_array(_filter_disconnect_asset_node(true, psuedo_leaf, asset_nodes))
    return removed_connections

func get_graph_gn(graph: CHANE_AssetNodeGraphEdit, gn_name: String) -> CustomGraphNode:
    return graph.get_node(NodePath(gn_name)) as CustomGraphNode

func get_parent_an(asset_node: HyAssetNode) -> HyAssetNode:
    var parent_an_id: = get_parent_an_id(asset_node.an_node_id)
    if not parent_an_id or not all_asset_nodes.has(parent_an_id):
        return null
    return all_asset_nodes[parent_an_id]

func get_parent_an_id(asset_node_id: String) -> String:
    if not asset_node_aux_data.has(asset_node_id):
        print_debug("Asset node %s not found in aux data" % asset_node_id)
    return asset_node_aux_data[asset_node_id].output_to_node_id

func get_all_groups() -> Array[GraphFrame]:
    var all_groups: Array[GraphFrame] = []
    for graph in graphs:
        all_groups.append_array(graph.get_all_groups())
    return all_groups

func gn_is_special(graph_node: CustomGraphNode) -> bool:
    return graph_node.get_meta("is_special_gn", false)

func make_new_default_graph_node_for_an(asset_node: HyAssetNode, at_pos_offset: Vector2, centered: bool = false) -> CustomGraphNode:
    var new_gn: CustomGraphNode = graph_node_factory.make_new_graph_node_for_asset_node(asset_node, true, at_pos_offset, centered)
    asset_node_aux_data[asset_node.an_node_id].position = new_gn.position_offset
    return new_gn

func make_graph_node_for_an(asset_node: HyAssetNode, at_pos_offset: Vector2, centered: bool = false, aux_data_dict: Dictionary[String, HyAssetNode.AuxData] = {}) -> CustomGraphNode:
    if not aux_data_dict:
        aux_data_dict = asset_node_aux_data
    var new_gn: CustomGraphNode = graph_node_factory.make_new_graph_node_for_asset_node(asset_node, false, at_pos_offset, centered)
    aux_data_dict[asset_node.an_node_id].position = new_gn.position_offset
    return new_gn

func make_and_add_graph_node(in_graph: CHANE_AssetNodeGraphEdit, asset_node: HyAssetNode, at_pos_offset: Vector2, centered: bool = false, snap_now: bool = false) -> CustomGraphNode:
    var new_gn: CustomGraphNode = make_graph_node_for_an(asset_node, at_pos_offset, centered)
    in_graph.add_graph_node_child(new_gn, snap_now)
    return new_gn

func get_gn_own_asset_nodes(graph_node: CustomGraphNode) -> Array[HyAssetNode]:
    if gn_is_special(graph_node):
        return graph_node.get_own_asset_nodes()
    else:
        return [get_gn_main_asset_node(graph_node)]

func connect_pasted_ges(pasted_ges: Array[GraphElement], asset_nodes: Array[HyAssetNode], graph: CHANE_AssetNodeGraphEdit) -> void:
    var ans_to_gns: Dictionary[HyAssetNode, CustomGraphNode] = {}
    for pasted_ge in pasted_ges:
        if not pasted_ge is CustomGraphNode:
            continue
        for owned_an in get_gn_own_asset_nodes(pasted_ge):
            ans_to_gns[owned_an] = pasted_ge
    
    var an_tree_roots: = get_an_roots_within_registered_set(asset_nodes)
    var all_new_connections: Array[Dictionary] = []
    for an_root in an_tree_roots:
        all_new_connections.append_array(get_new_gn_tree_connections(ans_to_gns[an_root], ans_to_gns))
    graph.undo_redo_add_connections(all_new_connections)

func get_connections_for_newly_added_ges(new_ges: Array[GraphElement], new_asset_nodes: Array[HyAssetNode]) -> Array[Dictionary]:
    var connection_infos: Array[Dictionary] = []
    var ans_to_gns: Dictionary[HyAssetNode, CustomGraphNode] = {}
    for new_gn in new_ges:
        if not new_gn is CustomGraphNode:
            continue
        for owned_an in get_gn_own_asset_nodes(new_gn):
            ans_to_gns[owned_an] = new_gn

    var new_an_roots: = get_an_roots_within_registered_set(new_asset_nodes)
    for an_root in new_an_roots:
        connection_infos.append_array(get_new_gn_tree_connections(ans_to_gns[an_root], ans_to_gns))
    return connection_infos
    
func get_new_gn_tree_connections(cur_gn: CustomGraphNode, ans_to_gns: Dictionary) -> Array[Dictionary]:
    var connection_infos: Array[Dictionary] = []
    _get_new_gn_conn_recurse(cur_gn, ans_to_gns, connection_infos)
    return connection_infos

func _get_new_gn_conn_recurse(cur_gn: CustomGraphNode, ans_to_gns: Dictionary, connection_infos: Array[Dictionary]) -> void:
    var cur_an: = get_gn_main_asset_node(cur_gn)
    var excluded_conn_names: Array[String] = cur_gn.get_excluded_connection_names()
    var current_connection_names: Array[String] = cur_an.connection_list.filter(func(conn_name): return not conn_name in excluded_conn_names)
    for conn_idx in current_connection_names.size():
        var conn_name: = current_connection_names[conn_idx]
        var connected_ans: = cur_an.get_all_connected_nodes(conn_name)
        for connected_an in connected_ans:
            var connected_gn: = ans_to_gns.get(connected_an, null) as CustomGraphNode
            if not connected_gn:
                continue
            connection_infos.append({
                "from_node": cur_gn.name,
                "from_port": conn_idx,
                "to_node": connected_gn.name,
                "to_port": 0,
            })
            _get_new_gn_conn_recurse(connected_gn, ans_to_gns, connection_infos)

func new_graph_nodes_for_tree(tree_root_node: HyAssetNode, offset_pos: Vector2 = Vector2.ZERO, aux_data_dict: Dictionary[String, HyAssetNode.AuxData] = {}) -> Dictionary[HyAssetNode, CustomGraphNode]:
    if not aux_data_dict:
        aux_data_dict = asset_node_aux_data
    var new_gns_by_an: Dictionary[HyAssetNode, CustomGraphNode] = {}
    _recursive_new_graph_nodes(tree_root_node, offset_pos, new_gns_by_an, aux_data_dict)
    return new_gns_by_an

func _recursive_new_graph_nodes(at_asset_node: HyAssetNode, offset_pos: Vector2, new_gns_by_an: Dictionary[HyAssetNode, CustomGraphNode], aux_data_dict: Dictionary[String, HyAssetNode.AuxData]) -> void:
    var aux: = aux_data_dict[at_asset_node.an_node_id]
    var this_gn: = make_graph_node_for_an(at_asset_node, aux.position + offset_pos, false, aux_data_dict)
    new_gns_by_an[at_asset_node] = this_gn

    var modified_connections: = get_gn_modified_connections(this_gn, at_asset_node)
    for conn_name in modified_connections:
        for connected_asset_node in modified_connections[conn_name]:
            _recursive_new_graph_nodes(connected_asset_node, offset_pos, new_gns_by_an, aux_data_dict)

func get_gn_modified_connected_ans_for_connection(the_gn: CustomGraphNode, the_an: HyAssetNode, conn_name: String) -> Array[HyAssetNode]:
    if gn_is_special(the_gn):
        return the_gn.get_all_nodes_on_connection(conn_name)
    else:
        return the_an.get_all_connected_nodes(conn_name)

func get_gn_modified_connections(the_gn: CustomGraphNode, the_an: HyAssetNode) -> Dictionary[String, Array]:
    if gn_is_special(the_gn):
        return the_gn.get_all_connections()
    else:
        var mod_connections: Dictionary[String, Array] = {}
        for conn_name in the_an.connection_list:
            mod_connections[conn_name] = the_an.get_all_connected_nodes(conn_name)
        return mod_connections

func get_duplicate_ge_name(old_ge_name: String) -> String:
    var base_name: = old_ge_name.split("--")[0]
    return graph_node_factory.new_graph_node_name(base_name)

func get_all_asset_nodes() -> Array[HyAssetNode]:
    return Array(all_asset_nodes.values(), TYPE_OBJECT, &"Resource", HyAssetNode)

func is_workspace_id_compatible(workspace_id: String) -> bool:
    if not workspace_id:
        # Allow trying with unknown workspaces
        return true

    var possible_workspaces: = SchemaManager.schema.workspace_root_output_types.keys()
    possible_workspaces.append_array(SchemaManager.schema.workspace_no_output_types.keys())
    
    return possible_workspaces.has(workspace_id)

func get_gn_included_asset_nodes(gn: CustomGraphNode) -> Array[HyAssetNode]:
    if gn_is_special(gn):
        return gn.get_own_asset_nodes()
    else:
        return [get_gn_main_asset_node(gn)]

func get_included_asset_nodes_for_ges(ges: Array[GraphElement]) -> Array[HyAssetNode]:
    var included_asset_nodes: Array[HyAssetNode] = []
    for ge in ges:
        if ge is CustomGraphNode:
            included_asset_nodes.append_array(get_gn_included_asset_nodes(ge))
    return included_asset_nodes

func remove_graph_elements_from_graphs(ges: Array[GraphElement]) -> void:
    for ge in ges:
        ge.get_parent().remove_child(ge)

func get_new_group_name() -> String:
    return graph_node_factory.new_graph_node_name("Group")

func make_duplicate_group(group: GraphFrame) -> GraphFrame:
    var serialized_group: = serializer.serialize_group(group)
    var copy: = serializer.deserialize_group(serialized_group, get_new_group_name)
    copy.autoshrink_enabled = group.autoshrink_enabled
    copy.resizable = not copy.autoshrink_enabled
    copy.name = graph_node_factory.new_graph_node_name("Group")
    return copy

func get_duplicate_group_set(groups: Array) -> Array[GraphFrame]:
    var serialized_groups: = serializer.serialize_groups(groups)
    var groups_copy: = serializer.deserialize_groups(serialized_groups, get_new_group_name)
    for group_idx in groups_copy.size():
        groups_copy[group_idx].autoshrink_enabled = groups[group_idx].autoshrink_enabled
        groups_copy[group_idx].resizable = not groups_copy[group_idx].autoshrink_enabled
        groups_copy[group_idx].name = graph_node_factory.new_graph_node_name("Group")
    return groups_copy

func get_fragment_by_id(fragment_id: String) -> Fragment:
    return fragment_store.get_fragment_by_id(fragment_id)

func paste_cur_copied_fragment_centered(with_snap: bool, into_graph: CHANE_AssetNodeGraphEdit = null) -> void:
    if not current_copied_fragment:
        push_warning("No fragment to paste")
        return
    if not into_graph:
        into_graph = focused_graph
    var graph_view_center: = into_graph.get_center_pos_offset()
    undo_manager.start_undo_step("Paste Nodes")
    var is_new_step: = undo_manager.is_new_step

    _paste_from_fragment_at(current_copied_fragment, graph_view_center, with_snap, into_graph)

    if is_new_step:
        undo_manager.commit_current_undo_step()

func paste_cur_copied_fragment_at_pos(at_pos_offset: Vector2, with_snap: bool, into_graph: CHANE_AssetNodeGraphEdit = null) -> void:
    if not current_copied_fragment:
        push_warning("No fragment to paste")
        return
    undo_manager.start_undo_step("Paste Nodes")
    var is_new_step: = undo_manager.is_new_step

    _paste_from_fragment_at(current_copied_fragment, at_pos_offset, with_snap, into_graph)
    
    if is_new_step:
        undo_manager.commit_current_undo_step()

func _paste_from_fragment_at(paste_from_fragment: Fragment, at_pos_offset: Vector2, with_snap: bool, into_graph: CHANE_AssetNodeGraphEdit = null) -> void:
    var undo_step: = undo_manager.active_undo_step
    if not into_graph:
        into_graph = focused_graph
    
    # Unlike most undo actions, the paste is performed immediately before the undo step is committed
    undo_step.paste_fragment(paste_from_fragment, into_graph, at_pos_offset, with_snap)

func _actual_do_paste_from_fragment(fragment_id: String, at_pos_offset: Vector2, with_snap: bool, into_graph: CHANE_AssetNodeGraphEdit) -> Array[Array]:
    var new_stuff: = _insert_fragment_into_graph(fragment_id, into_graph, at_pos_offset, with_snap)
    return new_stuff

func _actual_do_paste_from_fragments(fragment_infos: Array[Dictionary], into_graph: CHANE_AssetNodeGraphEdit) -> void:
    for fragment_info in fragment_infos:
        _actual_do_paste_from_fragment(fragment_info["fragment_id"], fragment_info["at_pos_offset"], fragment_info["with_snap"], into_graph)

## Paste mode: inserts a fragment with rerolled IDs and counter-based names
func _insert_fragment_into_graph(fragment_id: String, graph: CHANE_AssetNodeGraphEdit, at_pos_offset: Vector2, with_snap: bool, name_counter_start: int = -1) -> Array[Array]:
    if undo_manager.undo_redo.is_committing_action():
        return []
    var fragment: = fragment_store.get_fragment_by_id(fragment_id)
    var fragment_root: FragmentRoot
    if name_counter_start >= 0:
        fragment_root = fragment.get_paste_nodes("FrGE", name_counter_start)
    else:
        fragment_root = fragment.get_gd_nodes_copy(not fragment.is_cut_fragment, false)
    return _add_fragment_root_to_graph(fragment_root, graph, at_pos_offset, with_snap)

## Undelete mode: inserts a fragment with original IDs and original names
func _undelete_fragment(fragment_id: String, graph: CHANE_AssetNodeGraphEdit, at_pos_offset: Vector2) -> void:
    var fragment: = fragment_store.get_fragment_by_id(fragment_id)
    var fragment_root: FragmentRoot = fragment.get_undelete_nodes()
    _add_fragment_root_to_graph(fragment_root, graph, at_pos_offset, false, true)

func _add_fragment_root_to_graph(fragment_root: FragmentRoot, graph: CHANE_AssetNodeGraphEdit, at_pos_offset: Vector2, with_snap: bool, is_undelete: bool = false) -> Array[Array]:
    var all_fragment_ans: Array = fragment_root.all_asset_nodes.values()
    register_asset_nodes(all_fragment_ans, fragment_root.asset_node_aux_data.values())
    var new_graph_elements: Array[GraphElement] = []
    var new_groups: Array[GraphFrame] = []
    for child in fragment_root.get_children():
        if not child is GraphElement:
            continue
        fragment_root.remove_child(child)
        child.position_offset += at_pos_offset
        new_graph_elements.append(child)
        if child is GraphFrame:
            new_groups.append(child)
    graph.add_graph_element_children(new_graph_elements, with_snap)
    connect_pasted_ges(new_graph_elements, all_fragment_ans, graph)
    if not is_undelete:
        graph.add_nodes_inside_to_groups(new_groups, new_graph_elements, false)
    graph.small_groups_to_top()
    var new_group_relations: = graph.get_groups_cur_relations(new_groups)
    var new_connections: = get_connections_for_newly_added_ges(new_graph_elements, all_fragment_ans)
    return [new_graph_elements, new_groups, all_fragment_ans, new_group_relations, new_connections]

func cut_graph_elements_into_fragment(ges: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit) -> void:
    _delete_or_cut_graph_elements_into_fragment(ges, from_graph, true)

func delete_graph_elements(ges: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit) -> void:
    _delete_or_cut_graph_elements_into_fragment(ges, from_graph, false)

func _delete_or_cut_graph_elements_into_fragment(ges: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit, is_cut: bool) -> void:
    var undo_step: = undo_manager.start_or_continue_undo_step("Cut Nodes" if is_cut else "Delete Nodes")
    var is_new_step: = undo_manager.is_new_step
    
    var new_fragment: = undo_step.cut_graph_elements_into_fragment(ges, from_graph)
    if is_cut:
        current_copied_fragment = new_fragment
        current_copied_fragment_ge_count = ges.size()
    if is_new_step:
        undo_manager.commit_current_undo_step()

func copy_graph_elements_into_fragment(ges: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit) -> void:
    prints("copying %d graph elements into fragment: %s" % [ges.size(), ges.map(func(ge): return ge.name)])
    var copy_fragment: = Fragment.new_for_editor(self)
    fragment_store.register_fragment(copy_fragment)
    copy_fragment.load_graph_elements(ges, from_graph, false)
    current_copied_fragment = copy_fragment
    current_copied_fragment_ge_count = ges.size()

func duplicate_graph_elements(ges: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit, with_offset: Vector2, with_snap: bool) -> void:
    var dup_fragment: = Fragment.new_for_editor(self)
    fragment_store.register_fragment(dup_fragment)
    dup_fragment.load_graph_elements(ges, from_graph, false)
    var dup_from_pos: = dup_fragment.get_from_graph_pos()
    dup_from_pos += with_offset
    
    undo_manager.start_or_continue_undo_step("Duplicate Nodes")
    var is_new_step: = undo_manager.is_new_step

    _paste_from_fragment_at(dup_fragment, dup_from_pos, with_snap, from_graph)
    
    if is_new_step:
        undo_manager.commit_current_undo_step()


# As soon as a cut fragment is pasted replace it with a non-cut fragment that rolls new asset node IDs every paste
func invalidate_cut_fragments(fragment_ids: Array[String]) -> void:
    var cur_copied_id: = current_copied_fragment.fragment_id
    if cur_copied_id in fragment_ids:
        invalidate_current_cut_fragment()

func invalidate_current_cut_fragment() -> void:
    if not current_copied_fragment or not current_copied_fragment.is_cut_fragment:
        return
    var as_non_cut_fragment: = Fragment.new_duplicate_fragment(current_copied_fragment)
    fragment_store.register_fragment(as_non_cut_fragment)
    current_copied_fragment = as_non_cut_fragment

func _delete_graph_elements_ans_if_not_committing(ges_to_remove: Array[GraphElement], _from_graph: CHANE_AssetNodeGraphEdit) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    var included_asset_nodes: = get_included_asset_nodes_for_ges(ges_to_remove)
    remove_asset_nodes(included_asset_nodes)

func get_selected_ges() -> Array[GraphElement]:
    return focused_graph.get_selected_ges()

func reserve_global_counter_names(num_names: int) -> int:
    var counter_starts_at: = graph_node_factory.global_gn_counter + 1
    graph_node_factory.global_gn_counter += num_names
    return counter_starts_at

func get_an_conn_info_from_graph_conn_info(graph: CHANE_AssetNodeGraphEdit, graph_conn_info: Dictionary) -> Dictionary:
    var output_from_gn: = graph.get_node(NodePath(graph_conn_info["to_node"])) as CustomGraphNode
    var output_to_gn: = graph.get_node(NodePath(graph_conn_info["from_node"])) as CustomGraphNode
    return _get_an_conn_info_from_graph_conn_info(graph_conn_info, output_from_gn, output_to_gn)

func _get_an_conn_info_from_graph_conn_info(graph_conn_info: Dictionary, from_gn: CustomGraphNode, to_gn: CustomGraphNode) -> Dictionary:
    var output_from_an: = get_gn_main_asset_node(from_gn)
    var output_to_an: = get_gn_input_port_asset_node(to_gn, graph_conn_info["from_port"])
    var output_to_conn_name: String = get_gn_modified_connections(to_gn, output_to_an).keys()[graph_conn_info["from_port"]]
    return {
        "parent_node": output_to_an.an_node_id,
        "child_node": output_from_an.an_node_id,
        "connection_name": output_to_conn_name,
    }

func new_graph_connection_to_asset_node_conn_info(graph: CHANE_AssetNodeGraphEdit, graph_conn_info: Dictionary, new_graph_node: CustomGraphNode) -> Dictionary:
    var is_right: bool = graph_conn_info["to_node"] == new_graph_node.name
    var output_from_gn: CustomGraphNode
    var output_to_gn: CustomGraphNode
    if is_right:
        output_from_gn = new_graph_node
        output_to_gn = graph.get_node(NodePath(graph_conn_info["from_node"])) as CustomGraphNode
    else:
        output_from_gn = graph.get_node(NodePath(graph_conn_info["to_node"])) as CustomGraphNode
        output_to_gn = new_graph_node
    return _get_an_conn_info_from_graph_conn_info(graph_conn_info, output_from_gn, output_to_gn)


func get_hanging_ge_connections(ges: Array[GraphElement], graph: CHANE_AssetNodeGraphEdit) -> Array[Dictionary]:
    return graph.get_external_connections_for_ges(ges)

func get_hanging_an_connections_for_ges(ges: Array[GraphElement], graph: CHANE_AssetNodeGraphEdit) -> Array[Dictionary]:
    var graph_conn_infos: Array[Dictionary] = graph.get_external_connections_for_ges(ges)
    var ge_names: Array = ges.map(func(ge): return ge.name)
    
    var hanging_an_connections: Array[Dictionary] = []
    for graph_conn_info in graph_conn_infos:
        var an_connection_info: = get_an_conn_info_from_graph_conn_info(graph, graph_conn_info)
        if graph_conn_info["from_node"] in ge_names:
            an_connection_info["parent_node"] = ""
            an_connection_info["connection_name"] = ""
        else:
            an_connection_info["child_node"] = ""
        hanging_an_connections.append(an_connection_info)
    return hanging_an_connections

func _remove_asset_node_connections(asset_node_conns: Array[Dictionary]) -> void:
    for asset_node_conn in asset_node_conns:
        var parent_an: = all_asset_nodes[asset_node_conn["parent_node"]]
        var conn_name: String = asset_node_conn["connection_name"]
        var connected_ans: = parent_an.get_all_connected_nodes(conn_name)
        for i in connected_ans.size():
            if connected_ans[i].an_node_id == asset_node_conn["child_node"]:
                parent_an.remove_node_from_connection_at(conn_name, i)
                break

func _add_asset_node_connections(asset_node_conns: Array[Dictionary]) -> void:
    var parent_ans: Array[HyAssetNode] = []
    for asset_node_conn in asset_node_conns:
        var parent_an: = all_asset_nodes[asset_node_conn["parent_node"]]
        if not parent_an in parent_ans:
            parent_ans.append(parent_an)
        var conn_name: String = asset_node_conn["connection_name"]
        var child_an: = all_asset_nodes[asset_node_conn["child_node"]]
        _append_an_to_connection(parent_an, conn_name, child_an)
    sort_asset_nodes_connected(parent_ans)

func include_asset_nodes_direct_children(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var inclusive_ans: Array[HyAssetNode] = asset_nodes.duplicate()
    for asset_node in asset_nodes:
        for connected_an in asset_node.get_all_connected_nodes():
            if not connected_an in inclusive_ans:
                inclusive_ans.append(connected_an)
    return inclusive_ans

func include_asset_nodes_direct_parents(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var inclusive_ans: Array[HyAssetNode] = asset_nodes.duplicate()
    inclusive_ans.append_array(get_external_parent_asset_nodes(asset_nodes))
    return inclusive_ans

func get_external_parent_asset_nodes(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var external_parents: Array[HyAssetNode] = []
    for asset_node in asset_nodes:
        var parent_an: = get_parent_an(asset_node)
        if parent_an and not parent_an in asset_nodes:
            external_parents.append(parent_an)
    return external_parents

func get_psuedo_leaf_asset_nodes(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var psuedo_leaf_ans: Array[HyAssetNode] = []
    for asset_node in asset_nodes:
        if asset_node.total_connected_nodes() == 0:
            psuedo_leaf_ans.append(asset_node)
            continue
        for connected_an in asset_node.get_all_connected_nodes():
            if connected_an not in asset_nodes:
                psuedo_leaf_ans.append(asset_node)
                break
    return psuedo_leaf_ans

func get_leaf_asset_nodes(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var leaf_ans: Array[HyAssetNode] = asset_nodes.duplicate()
    for asset_node in asset_nodes:
        if asset_node.total_connected_nodes() == 0:
            continue
        for connected_an in asset_node.get_all_connected_nodes():
            if connected_an in asset_nodes:
                leaf_ans.erase(asset_node)
                break
    return leaf_ans

func exclude_leaf_asset_nodes(asset_nodes: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var exclusive_ans: Array[HyAssetNode] = asset_nodes.duplicate()
    for asset_node in asset_nodes:
        var has_included_child: = false
        for connected_an in asset_node.get_all_connected_nodes():
            if connected_an in asset_nodes:
                has_included_child = true
                break
        if not has_included_child:
            exclusive_ans.erase(asset_node)
    return exclusive_ans

func _set_asset_node_setting(asset_node_id: String, setting_name: String, value: Variant) -> void:
    if undo_manager.undo_redo.is_committing_action():
        return
    var asset_node: = all_asset_nodes[asset_node_id]
    asset_node.settings[setting_name] = value

func set_asset_node_setting_with_undo(asset_node_id: String, setting_name: String, value: Variant) -> void:
    var undo_step: = undo_manager.start_or_continue_undo_step("Edit %s" % setting_name)

    var asset_node: = all_asset_nodes[asset_node_id]
    undo_step.register_an_settings_before_change(asset_node)
    asset_node.settings[setting_name] = value
    
    undo_manager.commit_if_new()

func notify_asset_node_settings_changed(asset_node_ids: Array[String]) -> void:
    for asset_node_id in asset_node_ids:
        if all_asset_nodes.has(asset_node_id):
            all_asset_nodes[asset_node_id].settings_changed.emit()

func current_copied_fragment_has_multiple() -> bool:
    if not current_copied_fragment:
        return true
    return current_copied_fragment_ge_count > 1

func check_if_can_paste() -> bool:
    if current_copied_fragment:
        return true
    return false

func add_undo_step_created_asset_node(asset_node: HyAssetNode, undo_step: UndoStep) -> void:
    assert(all_asset_nodes.has(asset_node.an_node_id), "Asset node not registered before adding to undo step %s" % asset_node.an_node_id)
    undo_step.manually_create_asset_node(asset_node)

func get_floating_an_tree_roots() -> Array[HyAssetNode]:
    var floating_tree_roots: Array[HyAssetNode] = get_an_roots_within_registered_set(all_asset_nodes.values())
    floating_tree_roots.erase(root_asset_node)
    return floating_tree_roots

func get_asset_node_in_connections(asset_node: HyAssetNode) -> Array[Dictionary]:
    var in_connections: Array[Dictionary] = []
    for conn_name in asset_node.connection_list:
        for connected_an in asset_node.get_all_connected_nodes(conn_name):
            in_connections.append({
                "parent_node": asset_node.an_node_id,
                "child_node": connected_an.an_node_id,
                "connection_name": conn_name,
            })
    return in_connections

func _set_gn_title(graph_node: CustomGraphNode, new_title: String) -> void:
    var the_an: = get_gn_main_asset_node(graph_node)
    the_an.title = new_title
    graph_node.title = new_title

func update_all_ges_themes() -> void:
    for graph in graphs:
        graph.update_all_ges_themes()

func get_root_theme_color() -> String:
    if not is_loaded or not root_graph_node:
        return TypeColors.fallback_color
    return TypeColors.get_color_for_type(root_graph_node.get_theme_value_type())

func on_interface_color_changed() -> void:
    var interface_color: = ANESettings.get_current_interface_color()
    theme = ThemeColorVariants.get_theme_color_variant(interface_color)