extends GraphEdit
class_name AssetNodeGraphEdit

signal finished_saving
signal zoom_changed(new_zoom: float)

@export var save_formatted_json: = true
@export_file_path("*.json") var test_json_file: String = ""

var parsed_json_data: Dictionary = {}
var parsed_has_no_positions: = false
var loaded: = false

var cur_file_name: = ""
var cur_file_path: = ""
var has_saved_to_cur_file: = false

var global_gn_counter: int = 0

const DEFAULT_HY_WORKSPACE_ID: String = "HytaleGenerator - Biome"
var hy_workspace_id: String = ""

var all_asset_nodes: Array[HyAssetNode] = []
var all_asset_node_ids: Array[String] = []
var floating_tree_roots: Array[HyAssetNode] = []
var root_node: HyAssetNode = null

@export var popup_menu_root: PopupMenuRoot
@onready var special_gn_factory: SpecialGNFactory = $SpecialGNFactory

var asset_node_meta: Dictionary[String, Dictionary] = {}
var all_meta: Dictionary = {}

enum ContextMenuItems {
    COPY_NODES = 1,
    CUT_NODES,
    PASTE_NODES,
    DUPLICATE_NODES,

    DELETE_NODES,
    DISSOLVE_NODES,
    BREAK_CONNECTIONS,

}


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
var copied_node_reference_offset: Vector2 = Vector2.ZERO
var copied_from_screen_center_pos: Vector2 = Vector2.ZERO
var copied_nodes_internal_connections: Array[Array] = []
var copied_nodes_ans: Array[HyAssetNode] = []
var clipboard_was_from_cut: bool = false
var clipboard_was_from_external: bool = false
var copied_external_ans: Array[HyAssetNode] = []
var in_graph_copy_id: String = ""

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
var cur_connection_removed_gns: Array[GraphNode] = []
var cur_added_connections: Array[Dictionary] = []
var cur_removed_connections: Array[Dictionary] = []
var moved_nodes_positions: Dictionary[GraphNode, Vector2] = {}

var file_menu_btn: MenuButton = null
var file_menu_menu: PopupMenu = null

var settings_menu_btn: MenuButton = null
var settings_menu_menu: PopupMenu = null

var unedited: = true

func get_plain_version() -> String:
    return "v%s" % ProjectSettings.get_setting("application/config/version")

func get_version_number_string() -> String:
    var prerelease_string: = " Alpha"
    if OS.has_feature("debug"):
        prerelease_string = " Alpha (Debug)"
    return get_plain_version() + prerelease_string

func _ready() -> void:
    get_window().files_dropped.connect(on_files_dropped)
    assert(popup_menu_root != null, "Popup menu root is not set, please set it in the inspector")
    popup_menu_root.new_gn_menu.node_type_picked.connect(on_new_node_type_picked)
    popup_menu_root.new_gn_menu.cancelled.connect(on_new_node_menu_cancelled)
    
    focus_exited.connect(on_focus_exited)
    
    popup_menu_root.new_file_type_chooser.file_type_chosen.connect(on_new_file_type_chosen)
    popup_menu_root.popup_menu_opened.connect(on_popup_menu_opened)
    popup_menu_root.popup_menu_all_closed.connect(on_popup_menu_all_closed)
    
    FileDialogHandler.requested_open_file.connect(_on_requested_open_file)
    FileDialogHandler.requested_save_file.connect(_on_requested_save_file)
    
    setup_menus()

    #add_valid_left_disconnect_type(1)
    begin_node_move.connect(on_begin_node_move)
    end_node_move.connect(on_end_node_move)
    
    connection_request.connect(_connection_request)
    disconnection_request.connect(_disconnection_request)

    duplicate_nodes_request.connect(_duplicate_request)
    copy_nodes_request.connect(_copy_request)
    cut_nodes_request.connect(_cut_request)
    paste_nodes_request.connect(_paste_request)
    delete_nodes_request.connect(_delete_request)
    
    connection_to_empty.connect(_connect_right_request)
    connection_from_empty.connect(_connect_left_request)
    
    var menu_hbox: = get_menu_hbox()
    var grid_toggle_btn: = menu_hbox.get_child(4) as Button
    grid_toggle_btn.toggled.connect(on_grid_toggled.bind(grid_toggle_btn))
    
    var last_menu_hbox_item: = menu_hbox.get_child(menu_hbox.get_child_count() - 1)
    var version_label: = Label.new()
    version_label.text = ""
    version_label.add_theme_color_override("font_color", Color.WHITE.darkened(0.5))
    version_label.add_theme_font_size_override("font_size", 12)
    version_label.grow_horizontal = Control.GROW_DIRECTION_END
    version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    version_label.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
    version_label.text = "Cam Hytale ANE %s" % get_version_number_string()
    last_menu_hbox_item.add_child(version_label)
    version_label.offset_left = 12
    
    type_names[type_names.size()] = "Unknown"
    
    for val_type_name in SchemaManager.schema.value_types:
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
    await get_tree().process_frame
    popup_menu_root.show_new_file_type_chooser()

func on_files_dropped(dragged_files: PackedStringArray) -> void:
    var json_files: Array[String] = []
    for dragged_file in dragged_files:
        if dragged_file.get_extension() == "json":
            json_files.append(dragged_file)
    if json_files.size() == 0:
        return
    var json_file_path: String = json_files[0]
    open_file_with_prompt(json_file_path)

func on_focus_exited() -> void:
    if connection_cut_active:
        cancel_connection_cut()
    mouse_panning = false

func on_popup_menu_opened() -> void:
    prints("popup menu opened, releasing focus", has_focus())
    release_focus()

func on_popup_menu_all_closed() -> void:
    grab_focus()

func on_new_file_type_chosen(workspace_id: String) -> void:
    new_file_with_prompt(workspace_id)

func new_file_with_prompt(workspace_id: String) -> void:
    if unedited or all_asset_nodes.size() < 2:
        new_file_real(workspace_id)
    else:
        var prompt_text: = "Do you want to save the current file before creating a new file?"
        var has_cur: = cur_file_name != ""
        popup_menu_root.show_save_confirm(prompt_text, has_cur, new_file_real.bind(workspace_id))

func new_file_real(workspace_id: String) -> void:
    setup_new_graph(workspace_id)

func open_file_with_prompt(json_file_path: String) -> void:
    if unedited or all_asset_nodes.size() < 2:
        load_file_real(json_file_path)
    else:
        var prompt_text: = "Do you want to save the current file before loading '%s'?" % json_file_path
        var has_cur: = cur_file_name != ""
        popup_menu_root.show_save_confirm(prompt_text, has_cur, load_file_real.bind(json_file_path))

func load_file_real(json_file_path: String) -> void:
    cur_file_name = json_file_path.get_file()
    cur_file_path = json_file_path.get_base_dir()
    has_saved_to_cur_file = false
    FileDialogHandler.last_file_dialog_directory = json_file_path.get_base_dir()
    load_json_file(json_file_path)

func _shortcut_input(event: InputEvent) -> void:
    if Input.is_action_just_pressed_by_event("open_file_shortcut", event):
        accept_event()
        if popup_menu_root.is_menu_visible():
            popup_menu_root.close_all()
        FileDialogHandler.show_open_file_dialog()
    elif Input.is_action_just_pressed_by_event("save_file_shortcut", event):
        accept_event()
        if has_saved_to_cur_file:
            save_to_json_file(cur_file_path + "/" + cur_file_name)
            unedited = true
        else:
            if popup_menu_root.is_menu_visible():
                popup_menu_root.close_all()
            FileDialogHandler.show_save_file_dialog(cur_file_name != "")
    elif Input.is_action_just_pressed_by_event("save_as_shortcut", event):
        accept_event()
        if popup_menu_root.is_menu_visible():
            popup_menu_root.close_all()
        FileDialogHandler.show_save_file_dialog(false)
    elif Input.is_action_just_pressed("new_file_shortcut"):
        accept_event()
        popup_menu_root.show_new_file_type_chooser()

    if not popup_menu_root.is_menu_visible():
        if Input.is_action_just_pressed_by_event("graph_select_all_nodes", event):
            accept_event()
            select_all()
        elif Input.is_action_just_pressed_by_event("graph_deselect_all_nodes", event):
            prints("deselecting all nodes")
            accept_event()
            deselect_all()

func _process(_delta: float) -> void:
    if cur_zoom_level != zoom:
        on_zoom_changed()

func setup_menus() -> void:
    # reverse order so they can just move themselves to the start
    setup_settings_menu()
    setup_file_menu()

    var menu_hbox: = get_menu_hbox()
    var sep: = VSeparator.new()
    menu_hbox.add_child(sep)
    menu_hbox.move_child(sep, settings_menu_btn.get_index() + 1)
    
func setup_file_menu() -> void:
    file_menu_btn = preload("res://ui/file_menu.tscn").instantiate()
    file_menu_menu = file_menu_btn.get_popup()
    var menu_hbox: = get_menu_hbox()
    menu_hbox.add_child(file_menu_btn)
    menu_hbox.move_child(file_menu_btn, 0)
    
    file_menu_menu.id_pressed.connect(on_file_menu_id_pressed)

func on_file_menu_id_pressed(id: int) -> void:
    var menu_item_text: = file_menu_menu.get_item_text(file_menu_menu.get_item_index(id))
    match menu_item_text:
        "Open":
            FileDialogHandler.show_open_file_dialog()
        "Save":
            if has_saved_to_cur_file:
                save_to_json_file(cur_file_path + "/" + cur_file_name)
                unedited = true
            else:
                FileDialogHandler.show_save_file_dialog(cur_file_name != "")
        "Save As ...":
            FileDialogHandler.show_save_file_dialog(false)
        "New":
            popup_menu_root.show_new_file_type_chooser()

func setup_settings_menu() -> void:
    settings_menu_btn = preload("res://ui/settings_menu.tscn").instantiate()
    settings_menu_menu = settings_menu_btn.get_popup()
    var menu_hbox: = get_menu_hbox()
    menu_hbox.add_child(settings_menu_btn)
    menu_hbox.move_child(settings_menu_btn, 0)
    settings_menu_menu.index_pressed.connect(on_settings_menu_index_pressed)

func on_settings_menu_index_pressed(index: int) -> void:
    var menu_item_text: = settings_menu_menu.get_item_text(index)
    match menu_item_text:
        "Customize Theme Colors":
            popup_menu_root.show_theme_editor()

func setup_new_graph(workspace_id: String = DEFAULT_HY_WORKSPACE_ID) -> void:
    cur_file_name = ""
    cur_file_path = FileDialogHandler.last_file_dialog_directory
    has_saved_to_cur_file = false
    clear_graph()
    hy_workspace_id = workspace_id
    new_file_metadata_setup()
    var root_node_type: = SchemaManager.schema.resolve_root_asset_node_type(workspace_id, {}) as String
    var new_root_node: HyAssetNode = get_new_asset_node(root_node_type)
    set_root_node(new_root_node)
    var screen_center_pos: Vector2 = get_viewport_rect().size / 2
    var new_gn: CustomGraphNode = make_and_add_graph_node(new_root_node, screen_center_pos, true, true)
    gn_lookup[new_root_node.an_node_id] = new_gn
    unedited = true
    loaded = true

func new_file_metadata_setup() -> void:
    asset_node_meta.clear()
    all_meta = {
        "$Nodes": {},
        "$FloatingNodes": [],
        "$Groups": [],
        "$Comments": [],
        "$Links": {},
        "$WorkspaceID": hy_workspace_id,
    }

func set_root_node(new_root_node: HyAssetNode) -> void:
    root_node = new_root_node
    if root_node in floating_tree_roots:
        floating_tree_roots.erase(root_node)

func snap_gn(gn: GraphNode) -> void:
    if snapping_enabled:
        gn.position_offset = gn.position_offset.snapped(Vector2.ONE * snapping_distance)

func snap_gns(gns: Array) -> void:
    if not snapping_enabled:
        return
    for gn in gns:
        snap_gn(gn)

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
        return
    
    if Input.is_action_just_pressed_by_event("show_new_node_menu", event):
        if not loaded:
            popup_menu_root.show_new_file_type_chooser()
        elif not popup_menu_root.is_menu_visible():
            clear_next_drop()
            popup_menu_root.show_new_gn_menu()
            get_viewport().set_input_as_handled()

    if Input.is_action_just_pressed_by_event("ui_redo", event):
        if undo_manager.has_redo():
            print("Redoing")
            undo_manager.redo()
        else:
            GlobalToaster.show_toast_message("Nothing to Redo")
    # NOTE we do need this to be elif, because pressing ctr+shift+z registers as a ctr+z action being pressed too
    elif Input.is_action_just_pressed_by_event("ui_undo", event):
        if undo_manager.has_undo():
            print("Undoing")
            # undoing could mean that the previously cut nodes are now back in the graph, assume we need to treat the cut like a copy now
            if copied_nodes and clipboard_was_from_cut:
                clipboard_was_from_cut = false
            undo_manager.undo()
            #if not undo_manager.has_undo():
            #    unedited = true
        else:
            %ToastMessageContainer.show_toast_message("Nothing to Undo")
        

func _connection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    _add_connection(from_gn_name, from_port, to_gn_name, to_port)

func add_multiple_connections(conns_to_add: Array[Dictionary], with_undo: bool = true) -> void:
    var self_multi: = not multi_connection_change
    multi_connection_change = true
    for conn_to_add in conns_to_add:
        add_connection(conn_to_add, with_undo)

    if self_multi:
        if with_undo:
            create_undo_connection_change_step()
        multi_connection_change = false

func get_an_set_for_graph_nodes(gns: Array[GraphNode]) -> Array[HyAssetNode]:
    var ans: Array[HyAssetNode] = []
    for gn in gns:
        ans.append_array(get_gn_own_asset_nodes(gn))
    return ans

func add_connection(connection_info: Dictionary, with_undo: bool = true) -> void:
    _add_connection(connection_info["from_node"], connection_info["from_port"], connection_info["to_node"], connection_info["to_port"], with_undo)

func _add_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int, with_undo: bool = true) -> void:
    var old_multi_conn_change: = multi_connection_change
    # set multi_connection_change so removed connections get added as part of the same undo step
    multi_connection_change = true

    var from_gn: GraphNode = get_node(NodePath(from_gn_name))
    var to_gn: GraphNode = get_node(NodePath(to_gn_name))
    var from_an: HyAssetNode = an_lookup.get(from_gn.get_meta("hy_asset_node_id", ""))
    var to_an: HyAssetNode = an_lookup.get(to_gn.get_meta("hy_asset_node_id", ""))
    
    
    var existing_output_conn_infos: = raw_out_connections(to_gn)
    for existing_output in existing_output_conn_infos:
        remove_connection(existing_output)
    
    if not from_an or not to_an:
        print_debug("Warning: From or to asset node not found")
        connect_node(from_gn_name, from_port, to_gn_name, to_port)
        return

    if from_an.an_type not in SchemaManager.schema.node_schema:
        print_debug("Warning: From node type %s not found in schema" % from_an.an_type)
        var conn_name: String = from_an.connection_list[from_port]
        from_an.append_node_to_connection(conn_name, to_an)
    else:
        var conn_name: String = from_an.connection_list[from_port]
        var connect_is_multi: bool = SchemaManager.schema.node_schema[from_an.an_type]["connections"][conn_name].get("multi", false)
        if connect_is_multi or from_an.num_connected_asset_nodes(conn_name) == 0:
            from_an.append_node_to_connection(conn_name, to_an)
        else:
            var prev_connected_node: HyAssetNode = from_an.get_connected_node(conn_name, 0)
            if prev_connected_node and gn_lookup.has(prev_connected_node.an_node_id):
                _remove_connection(from_gn_name, from_port, gn_lookup[prev_connected_node.an_node_id].name, 0)
            from_an.append_node_to_connection(conn_name, to_an)
    
    if to_an in floating_tree_roots:
        floating_tree_roots.erase(to_an)

    if with_undo:
        cur_added_connections.append({
            "from_node": from_gn_name,
            "from_port": from_port,
            "to_node": to_gn_name,
            "to_port": to_port,
        })

    # restore multi_connection_change to whatever it was in the outer context
    multi_connection_change = old_multi_conn_change
    connect_node(from_gn_name, from_port, to_gn_name, to_port)
    if with_undo and not multi_connection_change:
        create_undo_connection_change_step()

func _disconnection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
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

func disconnect_connection_info(conn_info: Dictionary) -> void:
    disconnect_node(conn_info["from_node"], conn_info["from_port"], conn_info["to_node"], conn_info["to_port"])

func _remove_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int, with_undo: bool = true) -> void:
    disconnect_node(from_gn_name, from_port, to_gn_name, to_port)

    var from_gn: GraphNode = get_node(NodePath(from_gn_name))
    var to_gn: GraphNode = get_node(NodePath(to_gn_name))
    var from_an: HyAssetNode = an_lookup.get(from_gn.get_meta("hy_asset_node_id", ""))
    var from_connection_name: String = from_an.connection_list[from_port]
    var to_an: HyAssetNode = an_lookup.get(to_gn.get_meta("hy_asset_node_id", ""))

    if from_an and to_an:
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
    if asset_node in floating_tree_roots:
        floating_tree_roots.erase(asset_node)

func duplicate_and_add_asset_node(asset_node: HyAssetNode, new_gn: GraphNode = null) -> HyAssetNode:
    var id_prefix: String = SchemaManager.schema.get_id_prefix_for_node_type(asset_node.an_type)
    if not asset_node.an_node_id:
        push_warning("The asset node being duplicated had no ID")
        asset_node.an_node_id = get_unique_an_id(id_prefix)
    
    var new_id_for_copy: = get_unique_an_id(id_prefix)
    var asset_node_copy: = asset_node.get_shallow_copy(new_id_for_copy)
    _register_asset_node(asset_node_copy)
    floating_tree_roots.append(asset_node_copy)
    an_lookup[asset_node_copy.an_node_id] = asset_node_copy
    if new_gn:
        gn_lookup[asset_node_copy.an_node_id] = new_gn
        new_gn.set_meta("hy_asset_node_id", asset_node_copy.an_node_id)
    return asset_node_copy

func duplicate_and_add_filtered_an_tree(root_asset_node: HyAssetNode, asset_node_set: Array[HyAssetNode]) -> HyAssetNode:
    var new_root_an: HyAssetNode = duplicate_and_add_asset_node(root_asset_node)
    var conn_names: Array[String] = root_asset_node.connection_list.duplicate()
    for conn_name in conn_names:
        for connected_an in root_asset_node.get_all_connected_nodes(conn_name):
            if connected_an not in asset_node_set:
                continue
            var new_an: HyAssetNode = duplicate_and_add_filtered_an_tree(connected_an, asset_node_set)
            floating_tree_roots.erase(new_an)
            new_root_an.append_node_to_connection(conn_name, new_an)
    
    return new_root_an

func add_existing_asset_node(asset_node: HyAssetNode, gn: GraphNode = null) -> void:
    all_asset_nodes.append(asset_node)
    all_asset_node_ids.append(asset_node.an_node_id)
    if not asset_node.an_node_id:
        push_warning("Trying to add existing asset node with no ID")
    else:
        an_lookup[asset_node.an_node_id] = asset_node
        if gn:
            gn_lookup[asset_node.an_node_id] = gn

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
    var gns_to_remove: Array[GraphNode] = []
    for gn_name in delete_gn_names:
        var gn: GraphNode = get_node_or_null(NodePath(gn_name))
        if gn:
            gns_to_remove.append(gn)
    _delete_request_refs(gns_to_remove)
    
func _delete_request_refs(delete_gns: Array[GraphNode]) -> void:
    var root_gn: GraphNode = get_root_gn()
    if root_gn in delete_gns:
        delete_gns.erase(root_gn)
    if delete_gns.size() == 0:
        return
    remove_gns_with_connections_and_undo(delete_gns)

func _connect_right_request(from_gn_name: StringName, from_port: int, dropped_pos: Vector2) -> void:
    dropping_new_node_at = dropped_pos
    next_drop_has_connection = {
        "from_node": from_gn_name,
        "from_port": from_port,
        "to_port": 0,
    }
    var from_an: HyAssetNode = an_lookup.get(get_node(NodePath(from_gn_name)).get_meta("hy_asset_node_id", ""), null)
    if from_an:
        var from_node_schema: Dictionary = SchemaManager.schema.node_schema[from_an.an_type]
        next_drop_conn_value_type = from_node_schema["connections"][from_an.connection_list[from_port]].get("value_type", "")
        popup_menu_root.show_filtered_new_gn_menu(true, next_drop_conn_value_type)
    else:
        print_debug("Connect right request: From asset node not found")

func _connect_left_request(to_gn_name: StringName, to_port: int, dropped_pos: Vector2) -> void:
    dropping_new_node_at = dropped_pos
    next_drop_has_connection = {
        "to_node": to_gn_name,
        "to_port": to_port,
    }
    var to_an: HyAssetNode = an_lookup.get(get_node(NodePath(to_gn_name)).get_meta("hy_asset_node_id", ""), null)
    if to_an:
        var to_node_schema: Dictionary = SchemaManager.schema.node_schema[to_an.an_type]
        next_drop_conn_value_type = to_node_schema["output_value_type"]
        popup_menu_root.show_filtered_new_gn_menu(false, next_drop_conn_value_type)
    else:
        print_debug("Connect left request: To asset node not found")

func on_new_node_menu_cancelled() -> void:
    clear_next_drop()

func clear_next_drop() -> void:
    dropping_new_node_at = Vector2.ZERO
    next_drop_has_connection = {}
    next_drop_conn_value_type = ""

func get_unique_an_id(id_prefix: String = "") -> String:
    return "%s-%s" % [id_prefix, Util.unique_id_string()]

func get_new_asset_node(asset_node_type: String, id_prefix: String = "") -> HyAssetNode:
    if id_prefix == "" and asset_node_type and asset_node_type != "Unknown":
        id_prefix = SchemaManager.schema.get_id_prefix_for_node_type(asset_node_type)
    elif id_prefix == "":
        print_debug("New asset node: No ID prefix provided, and asset node type is unknown or empty")
        return null

    var new_asset_node: = HyAssetNode.new()
    new_asset_node.an_node_id = get_unique_an_id(id_prefix)
    new_asset_node.an_type = asset_node_type
    new_asset_node.an_name = SchemaManager.schema.get_node_type_default_name(asset_node_type)
    _register_asset_node(new_asset_node)
    floating_tree_roots.append(new_asset_node)
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

func select_all() -> void:
    for c in get_children():
        if c is GraphNode:
            c.selected = true

func deselect_all() -> void:
    set_selected(null)
    #for c in get_children():
        #if c is GraphNode:
            #c.selected = false

func select_gns(gns: Array[CustomGraphNode]) -> void:
    deselect_all()
    for gn in gns:
        gn.selected = true

func _duplicate_request() -> void:
    duplicate_selected_gns()

func duplicate_selected_gns() -> void:
    # TODO: dont clobber the clipboard
    _copy_request()
    _paste_request()

func discard_copied_nodes() -> void:
    copied_nodes.clear()
    copied_nodes_ans.clear()
    copied_nodes_internal_connections.clear()
    clipboard_was_from_external = false

    for an in copied_external_ans:
        if an and an.an_node_id and an.an_node_id not in all_asset_node_ids:
            if an.an_node_id in asset_node_meta:
                asset_node_meta.erase(an.an_node_id)
    copied_external_ans.clear()
    in_graph_copy_id = ""

func get_root_gn() -> GraphNode:
    return gn_lookup[root_node.an_node_id]

func _cut_request() -> void:
    var selected_gns: Array[GraphNode] = get_selected_gns()
    var root_gn: GraphNode = get_root_gn()
    if root_gn in selected_gns:
        selected_gns.erase(root_gn)
    if selected_gns.size() == 0:
        return
    _copy_or_cut_gns(selected_gns)
    # this gets set to false if we ever undo. so that we never try to re-use the cut nodes while they actually exist in the graph
    clipboard_was_from_cut = true
    # do the removal and create the undo step for removing them (separate from clipboard)
    remove_gns_with_connections_and_undo(copied_nodes)

func _copy_request() -> void:
    var selected_gns: Array[GraphNode] = get_selected_gns()
    var selected_gn_names: Array[String] = []
    for gn in selected_gns:
        selected_gn_names.append(gn.name)
    prints("selected gns: %s" % [selected_gn_names])
    _copy_or_cut_gns(selected_gns)
    clipboard_was_from_cut = false

func _copy_or_cut_gns(gns: Array[GraphNode]) -> void:
    if copied_nodes:
        discard_copied_nodes()
    copied_nodes = gns
    save_copied_nodes_internal_connections()
    save_copied_nodes_an_references()
    copied_from_screen_center_pos = scroll_offset + (get_viewport_rect().size / (2 * zoom))
    in_graph_copy_id = Util.random_str(16)
    ClipboardManager.send_copied_nodes_to_clipboard(self)

func save_copied_nodes_internal_connections() -> void:
    var copied_nodes_names: Array[String] = []
    for gn in copied_nodes:
        copied_nodes_names.append(gn.name)

    copied_nodes_internal_connections.clear()
    for gn_idx in copied_nodes.size():
        var gn: GraphNode = copied_nodes[gn_idx]
        var this_internal_connections: Array[Dictionary] = []
        var gn_connections: = raw_connections(gn)
        for conn_info in gn_connections:
            if conn_info["from_node"] != gn.name:
                continue
            var index_of_to_node: int = copied_nodes_names.find(conn_info["to_node"])
            if index_of_to_node == -1:
                continue
            this_internal_connections.append({
                "from_port": conn_info["from_port"],
                "to_port": 0,
                "to_node": index_of_to_node,
            })
        copied_nodes_internal_connections.append(this_internal_connections)

func save_copied_nodes_an_references() -> void:
    copied_nodes_ans.clear()
    for gn in copied_nodes:
        copied_nodes_ans.append_array(get_gn_own_asset_nodes(gn))

func _paste_request() -> void:
    ClipboardManager.load_copied_nodes_from_clipboard(self)
    
    if clipboard_was_from_external:
        paste_from_external()

    if not copied_nodes:
        return
    deselect_all()
    
    var destination_offset: = Vector2.ZERO
    var new_screen_center_pos: Vector2 = scroll_offset + (get_viewport_rect().size / (2 * zoom))
    var delta_offset: = new_screen_center_pos - copied_from_screen_center_pos
    if delta_offset.length() < 30:
        destination_offset = Vector2(0, 40)
        copied_from_screen_center_pos += destination_offset
    else:
        destination_offset = delta_offset
    
    var pasted_nodes: = _add_pasted_nodes(copied_nodes, copied_nodes_ans, not clipboard_was_from_cut)
    var new_connections_needed: Array[Dictionary] = []
    for gn_idx in copied_nodes.size():
        var copied_input_connections: Array[Dictionary] = copied_nodes_internal_connections[gn_idx]
        for input_conn_idx in copied_input_connections.size():
            var new_conn_info: Dictionary = copied_input_connections[input_conn_idx].duplicate()
            new_conn_info["from_node"] = pasted_nodes[gn_idx].name
            new_conn_info["to_node"] = pasted_nodes[new_conn_info["to_node"]].name
            new_connections_needed.append(new_conn_info)
    
    for pasted_gn in pasted_nodes:
        pasted_gn.position_offset += destination_offset
        snap_gn(pasted_gn)
        pasted_gn.selected = true
    add_multiple_connections(new_connections_needed, false)
    
    cur_added_connections = new_connections_needed
    cur_connection_added_gns = pasted_nodes
    create_undo_connection_change_step()

func paste_from_external() -> void:
    var old_json_scale: = json_positions_scale
    json_positions_scale = Vector2.ONE
    var screen_center_pos: Vector2 = global_pos_to_position_offset(get_viewport_rect().size / 2)
    var an_roots: Array[HyAssetNode] = get_an_roots_within_set(copied_external_ans)
    floating_tree_roots.append_array(an_roots)
    var added_gns: = make_and_position_graph_nodes_for_trees(an_roots, false, screen_center_pos)
    json_positions_scale = old_json_scale

    select_gns(added_gns)
    
    cur_added_connections = get_internal_connections_for_gns(added_gns)
    cur_connection_added_gns.assign(added_gns)
    create_undo_connection_change_step()
    discard_copied_nodes()
    


func _add_pasted_nodes(gns: Array[GraphNode], asset_node_set: Array[HyAssetNode], make_duplicates: bool) -> Array[GraphNode]:
    var pasted_gns: Array[GraphNode] = []
    if not make_duplicates:
        var pasted_an_roots: Array[HyAssetNode] = get_an_roots_within_set(asset_node_set)
        floating_tree_roots.append_array(pasted_an_roots)
        pasted_gns = gns
        for gn in gns:
            var owned_ans: Array[HyAssetNode] = get_gn_own_asset_nodes(gn, asset_node_set)
            for owned_an in owned_ans:
                if owned_an not in all_asset_nodes:
                    add_existing_asset_node(owned_an)
            if gn.get_meta("hy_asset_node_id", ""):
                gn_lookup[gn.get_meta("hy_asset_node_id", "")] = gn
            add_child(gn, true)
    else:
        for gn in gns:
            var duplicate_gn: = duplicate_graph_node(gn, asset_node_set)
            add_child(duplicate_gn, true)
            pasted_gns.append(duplicate_gn)
    return pasted_gns

func duplicate_graph_node(gn: CustomGraphNode, allowed_an_list: Array[HyAssetNode] = []) -> CustomGraphNode:
    var duplicate_gn: CustomGraphNode
    if gn.get_meta("is_special_gn", false):
        if not allowed_an_list:
            allowed_an_list = get_gn_own_asset_nodes(gn)
        duplicate_gn = special_gn_factory.make_duplicate_special_gn(gn, allowed_an_list)
    else:
        if not gn.get_meta("hy_asset_node_id", ""):
            duplicate_gn = gn.duplicate()
        else:
            var old_an: HyAssetNode = safe_get_an_from_gn(gn, allowed_an_list)
            duplicate_gn = _duplicate_synced_graph_node(gn, old_an)
    init_duplicate_graph_node(duplicate_gn, gn)
    return duplicate_gn

func _duplicate_synced_graph_node(gn: CustomGraphNode, old_an: HyAssetNode) -> CustomGraphNode:
    var duplicate_gn: CustomGraphNode = gn.duplicate()
    var new_an: = duplicate_and_add_asset_node(old_an, duplicate_gn)
    duplicate_gn.fix_duplicate_settings_syncer(new_an)
    return duplicate_gn

func safe_get_an_from_gn(gn: CustomGraphNode, extra_an_list: Array[HyAssetNode] = []) -> HyAssetNode:
    var an_id: String = gn.get_meta("hy_asset_node_id", "")
    if not an_id:
        return null
    if an_id in an_lookup:
        return an_lookup[an_id]
    for an in extra_an_list:
        if an.an_node_id == an_id:
            return an
    return null

func clear_graph() -> void:
    prints("clearing graph")
    all_asset_nodes.clear()
    all_asset_node_ids.clear()
    floating_tree_roots.clear()
    root_node = null
    gn_lookup.clear()
    an_lookup.clear()
    asset_node_meta.clear()
    all_meta.clear()
    for child in get_children():
        if child is GraphNode:
            remove_child(child)
            child.queue_free()
    
    cancel_connection_cut()

    undo_manager.clear_history()
    discard_copied_nodes()

    global_gn_counter = 0

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
        var inferred_node_type: String = SchemaManager.schema.resolve_asset_node_type(type_key_val, output_value_type)
        if not inferred_node_type or inferred_node_type == "Unknown":
            print_debug("Old-style inferring node type failed, returning null")
            push_error("Old-style inferring node type failed, returning null")
            return null
        else:
            asset_node_data["$NodeId"] = get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(inferred_node_type))
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
    elif output_value_type != "ROOT":
        asset_node.an_type = SchemaManager.schema.resolve_asset_node_type(asset_node_data.get("Type", "NO_TYPE_KEY"), output_value_type, asset_node.an_node_id)
    
    var node_schema: Dictionary = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        node_schema = SchemaManager.schema.node_schema.get(asset_node.an_type, {})
        if not node_schema:
            print_debug("Warning: Node schema not found for node type: %s" % asset_node.an_type)
    
    asset_node.raw_tree_data = asset_node_data.duplicate(true)
    init_asset_node(asset_node)

    # fill out stuff in data even if it isn't in the schema
    for other_key in asset_node_data.keys():
        if other_key.begins_with("$"):
            continue
        if other_key in HyAssetNode.special_keys:
            # Type is a special key but PCNDistanceFunction uses it differently, hence the special case
            if not node_schema or (not node_schema.get("settings", {}).has(other_key)):
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
        elif typeof(val[0]) == TYPE_DICTIONARY:
            test_dict = val[0]
        else:
            return null
    elif val != null:
        return null
    
    if old_style:
        if test_dict.is_empty() or test_dict.has("$Position"):
            return val
    else:
        if test_dict.is_empty() or test_dict.has("$NodeId"):
            return val
    return null

func init_asset_node(asset_node: HyAssetNode, with_meta_data: bool = false, meta_data: Dictionary = {}) -> void:
    if not with_meta_data:
        meta_data = asset_node_meta

    var type_schema: = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        type_schema = SchemaManager.schema.node_schema[asset_node.an_type]
    else:
        print_debug("Warning: Asset node type is unknown or empty")

    asset_node.an_name = SchemaManager.schema.get_node_type_default_name(asset_node.an_type)
    if meta_data.has(asset_node.an_node_id) and meta_data[asset_node.an_node_id].has("$Title"):
        asset_node.an_name = meta_data[asset_node.an_node_id]["$Title"]
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

func parse_asset_node_deep(old_style: bool, asset_node_data: Dictionary, output_value_type: String = "", base_node_type: String = "") -> Dictionary:
    var parsed_node: = parse_asset_node_shallow(old_style, asset_node_data, output_value_type, base_node_type)
    var all_nodes: Array[HyAssetNode] = [parsed_node]
    for conn in parsed_node.connection_list:
        if parsed_node.is_connection_empty(conn):
            continue
        
        var conn_nodes_data: = parsed_node.get_raw_connected_nodes(conn)
        for conn_node_idx in conn_nodes_data.size():
            var conn_value_type: = "Unknown"
            if parsed_node.an_type != "Unknown":
                conn_value_type = SchemaManager.schema.node_schema[parsed_node.an_type]["connections"][conn]["value_type"]

            var sub_parse_result: = parse_asset_node_deep(old_style, conn_nodes_data[conn_node_idx], conn_value_type)
            all_nodes.append_array(sub_parse_result["all_nodes"])
            parsed_node.set_connection(conn, conn_node_idx, sub_parse_result["base"])
        parsed_node.set_connection_count(conn, conn_nodes_data.size())

    parsed_node.has_inner_asset_nodes = true
    
    return {"base": parsed_node, "all_nodes": all_nodes}

func parse_root_asset_node(base_node: Dictionary) -> void:
    hy_workspace_id = ""
    var old_style_format: = false
    parsed_has_no_positions = false

    if base_node.has("$WorkspaceID"):
        old_style_format = true
        hy_workspace_id = base_node["$WorkspaceID"]
    elif not base_node.get("$NodeEditorMetadata", {}):
        print_debug("Not old-style but Root node does not have $NodeEditorMetadata")
        push_error("Not old-style but Root node does not have $NodeEditorMetadata")
        var node_id: String = base_node.get("$NodeId", "")
        if not node_id:
            print_debug("No metadata and rot node has no NodeId, aborting")
            push_error("No metadata and root node has no NodeId, aborting")
            return

        if node_id.begins_with("Biome-"):
            print("no workspace but found Biome node, setting workspace to Biome")
            hy_workspace_id = "HytaleGenerator - Biome"
        else:
            var possible_output_types: Array[String] = SchemaManager.schema.workspace_root_output_types.values()
            var node_type_by_output_type: Dictionary[String, Array] = {}
            for node_type in SchemaManager.schema.node_schema:
                var schm: Dictionary = SchemaManager.schema.node_schema[node_type]
                var output_value_type: String = schm["output_value_type"]
                if output_value_type in possible_output_types:
                    if not node_type_by_output_type.has(output_value_type):
                        node_type_by_output_type[output_value_type] = []
                    node_type_by_output_type[output_value_type].append(node_type)
            
            
            for output_value_type in node_type_by_output_type.keys():
                for node_type in node_type_by_output_type[output_value_type]:
                    var id_prefix: = SchemaManager.schema.get_id_prefix_for_node_type(node_type) as String
                    if not id_prefix:
                        continue
                    if node_id.begins_with(id_prefix + "-"):
                        print("discovered workspace by finding root node type: %s" % node_type)
                        hy_workspace_id = SchemaManager.schema.workspace_root_output_types.find_key(output_value_type)
                        break
                if hy_workspace_id:
                    break
            if not hy_workspace_id:
                print_debug("Was not able to discover workspace ID from root node id")
                push_warning("Was not able to discover workspace ID from root node id")
                return
        parsed_has_no_positions = true
    else:
        hy_workspace_id = base_node["$NodeEditorMetadata"].get("$WorkspaceID", "")
    
    if not hy_workspace_id:
        print_debug("No workspace ID found in root node or editor metadata")
        push_warning("No workspace ID found in root node or editor metadata")
        return

    var root_node_type: String = SchemaManager.schema.resolve_root_asset_node_type(hy_workspace_id, base_node)

    if old_style_format and not base_node.get("$NodeId", ""):
        base_node["$NodeId"] = get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(root_node_type))

    @warning_ignore("unused_variable") var parsed_node_count: = 0

    if not old_style_format:
        var meta_data: = base_node["$NodeEditorMetadata"] as Dictionary
        all_meta = meta_data.duplicate(true)

        for node_id in meta_data.get("$Nodes", {}).keys():
            asset_node_meta[node_id] = meta_data["$Nodes"][node_id]


    var parse_result: = parse_asset_node_deep(old_style_format, base_node, "", root_node_type)
    set_root_node(parse_result["base"])
    all_asset_nodes.append_array(parse_result["all_nodes"])
    parsed_node_count += parse_result["all_nodes"].size()
    #print("Root node parsed, %d nodes" % parse_result["all_nodes"].size(), " (total: %d)" % parsed_node_count)
    for an in parse_result["all_nodes"]:
        all_asset_node_ids.append(an.an_node_id)

    if not old_style_format:
        for floating_tree in base_node["$NodeEditorMetadata"].get("$FloatingNodes", []):
            if not floating_tree.has("$NodeId"):
                push_warning("Floating node does not have a $NodeId, skipping")
                continue
            var floating_root_id: String = floating_tree["$NodeId"]
            if floating_root_id in an_lookup:
                print_debug("Floating root node %s exists in another tree, assuming it was mistakenly added to floating tree roots, skipping" % floating_root_id)
                continue

            var floating_parse_result: = parse_asset_node_deep(false, floating_tree)
            floating_tree_roots.append(floating_parse_result["base"])
            parsed_node_count += floating_parse_result["all_nodes"].size()
            #print("Floating tree parsed, %d nodes" % floating_parse_result["all_nodes"].size(), " (total: %d)" % parsed_node_count)
            all_asset_nodes.append_array(floating_parse_result["all_nodes"])
            for an in floating_parse_result["all_nodes"]:
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
    make_and_position_graph_nodes_for_trees(all_root_nodes, true)
    
func make_and_position_graph_nodes_for_trees(an_roots: Array[HyAssetNode], positions_as_loaded: bool, add_offset: Vector2 = Vector2.ZERO) -> Array[CustomGraphNode]:
    var manually_position: bool = positions_as_loaded and not use_json_positions
    var base_tree_pos: = Vector2(0, 100)
    var all_added_gns: Array[CustomGraphNode] = []
    for tree_root_node in an_roots:
        var new_graph_nodes: Array[CustomGraphNode] = new_graph_nodes_for_tree(tree_root_node)
        all_added_gns.append_array(new_graph_nodes)
        for new_gn in new_graph_nodes:
            add_child(new_gn, true)
            if manually_position:
                new_gn.position_offset = Vector2(0, -500)
            if add_offset:
                new_gn.position_offset += add_offset
            if new_gn.size.x < gn_min_width:
                new_gn.size.x = gn_min_width
        
        if manually_position:
            var last_y: int = move_and_connect_children(tree_root_node.an_node_id, base_tree_pos)
            base_tree_pos.y = last_y + 40
        else:
            connect_children(new_graph_nodes[0])
        
        if not positions_as_loaded:
            snap_gns(new_graph_nodes)
    return all_added_gns

func make_and_add_graph_node(asset_node: HyAssetNode, at_global_pos: Vector2, centered: bool = false, snap_now: bool = false) -> CustomGraphNode:
    var new_gn: CustomGraphNode = new_graph_node(asset_node, true)
    add_child(new_gn, true)
    new_gn.position_offset = global_pos_to_position_offset(at_global_pos)
    if centered:
        new_gn.position_offset -= new_gn.size / 2
    if snap_now:
        snap_gn(new_gn)
    return new_gn

func global_pos_to_position_offset(the_global_pos: Vector2) -> Vector2:
    return (scroll_offset + the_global_pos) / zoom
    
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

    var this_gn: = new_graph_node(at_asset_node, false)
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

func get_gn_own_asset_nodes(graph_node: CustomGraphNode, extra_asset_nodes: Array[HyAssetNode] = []) -> Array[HyAssetNode]:
    if graph_node.get_meta("is_special_gn", false):
        return graph_node.get_own_asset_nodes()
    else:
        return [safe_get_an_from_gn(graph_node, extra_asset_nodes)]

func get_internal_connections_for_gns(gns: Array[CustomGraphNode]) -> Array[Dictionary]:
    var internal_connections: Array[Dictionary] = []
    for gn in gns:
        for conn_info in raw_connections(gn):
            if conn_info["from_node"] == gn.name:
                var to_gn: = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
                if to_gn in gns:
                    internal_connections.append(conn_info)
    return internal_connections


func get_an_roots_within_set(asset_node_set: Array[HyAssetNode]) -> Array[HyAssetNode]:
    var root_ans: Array[HyAssetNode] = asset_node_set.duplicate()
    for parent_an in asset_node_set:
        for child_an in parent_an.connected_asset_nodes.values():
            if child_an in root_ans:
                root_ans.erase(child_an)
    return root_ans

func get_graph_connected_graph_nodes(graph_node: CustomGraphNode, conn_name: String) -> Array[GraphNode]:
    var connected_asset_nodes: Array[HyAssetNode] = get_graph_connected_asset_nodes(graph_node, conn_name)
    var connected_graph_nodes: Array[GraphNode] = []
    for connected_asset_node in connected_asset_nodes:
        connected_graph_nodes.append(gn_lookup[connected_asset_node.an_node_id])
    return connected_graph_nodes


func should_be_special_gn(asset_node: HyAssetNode) -> bool:
    return special_gn_factory.types_with_special_nodes.has(asset_node.an_type)

func init_duplicate_graph_node(duplicate_gn: CustomGraphNode, original_gn: CustomGraphNode) -> void:
    if original_gn.theme:
        duplicate_gn.theme = original_gn.theme
    if original_gn.node_type_schema:
        duplicate_gn.set_node_type_schema(original_gn.node_type_schema)
    duplicate_gn.ignore_invalid_connection_type = original_gn.ignore_invalid_connection_type
    duplicate_gn.was_right_clicked.connect(_on_graph_node_right_clicked)
    duplicate_gn.resizable = original_gn.resizable
    duplicate_gn.title = original_gn.title
    duplicate_gn.name = get_duplicate_gn_name(original_gn.name)

    #if not duplicate_gn.get_meta("is_special_gn", false) and duplicate_gn.get_meta("hy_asset_node_id", ""):
        #setup_synchers_for_duplicate_graph_node(duplicate_gn)
    
    duplicate_gn.update_port_colors()

func get_child_node_of_class(parent: Node, class_names: Array[String]) -> Node:
    if parent.get_class() in class_names:
        return parent
    
    for child in parent.get_children():
        var found_node: = get_child_node_of_class(child, class_names)
        if found_node:
            return found_node
    return null

func update_all_gns_themes() -> void:
    for child in get_children():
        if child is CustomGraphNode:
            update_gn_theme(child)
            child.update_port_colors()

func update_gn_theme(graph_node: CustomGraphNode) -> void:
    var output_type: String = graph_node.theme_color_output_type
    if not output_type:
        return
    
    var theme_var_color: String = TypeColors.get_color_for_type(output_type)
    if ThemeColorVariants.has_theme_color(theme_var_color):
        graph_node.theme = ThemeColorVariants.get_theme_color_variant(theme_var_color)

func new_graph_node(asset_node: HyAssetNode, newly_created: bool) -> CustomGraphNode:
    var graph_node: CustomGraphNode = null
    var is_special: = should_be_special_gn(asset_node)
    var settings_syncer: SettingsSyncer = null
    if is_special:
        graph_node = special_gn_factory.make_special_gn(asset_node, newly_created)
    else:
        graph_node = CustomGraphNode.new()
        settings_syncer = graph_node.make_settings_syncer(asset_node)
    
    graph_node.name = new_graph_node_name(graph_node.name if graph_node.name else &"GN")
    
    var output_type: String = SchemaManager.schema.node_schema[asset_node.an_type].get("output_value_type", "")
    graph_node.theme_color_output_type = output_type
    var theme_var_color: String = TypeColors.get_color_for_type(output_type)
    if ThemeColorVariants.has_theme_color(theme_var_color):
        graph_node.theme = ThemeColorVariants.get_theme_color_variant(theme_var_color)
    else:
        push_warning("No theme color variant found for color '%s'" % theme_var_color)
        print_debug("No theme color variant found for color '%s'" % theme_var_color)

    graph_node.set_meta("hy_asset_node_id", asset_node.an_node_id)
    gn_lookup[asset_node.an_node_id] = graph_node
    
    graph_node.resizable = true
    if not output_type:
        graph_node.ignore_invalid_connection_type = true

    graph_node.title = asset_node.an_name
    
    graph_node.was_right_clicked.connect(_on_graph_node_right_clicked)
    
    var node_schema: Dictionary = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        node_schema = SchemaManager.schema.node_schema[asset_node.an_type]
        graph_node.set_node_type_schema(node_schema)
    
    # NOTE: dumb hack
    get_parent().add_child(graph_node)

    if is_special:
        pass
    else:
        
        var num_inputs: = 1
        if node_schema and node_schema.get("no_output", false):
            num_inputs = 0
        
        var connection_names: Array
        if node_schema:
            var type_connections: Dictionary = node_schema.get("connections", {})
            connection_names = type_connections.keys()
        else:
            connection_names = asset_node.connections.keys()
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
                if node_schema and node_schema.get("settings", {}).has(setting_name) and node_schema.get("settings", {})[setting_name].get("hidden", false):
                    continue

                var s_name: = Label.new()
                s_name.name = "SettingName"
                s_name.text = "%s:" % setting_name
                s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

                var s_edit: Control
                var setting_value: Variant
                var setting_type: int
                if setting_name in asset_node.settings:
                    setting_value = asset_node.settings[setting_name]
                else:
                    setting_value = SchemaManager.schema.node_schema[asset_node.an_type]["settings"][setting_name].get("default_value", 0)

                if setting_name in node_schema.get("settings", {}):
                    setting_type = node_schema.get("settings", {})[setting_name]["gd_type"]
                else:
                    print_debug("Setting type for %s : %s not found in node schema (%s)" % [setting_name, setting_value, asset_node.an_type])
                    setting_type = typeof(setting_value) if setting_value else TYPE_STRING
                
                var ui_hint: String = node_schema.get("settings", {})[setting_name].get("ui_hint", "")

                var slot_node: Control = HBoxContainer.new()

                # Standard settings editors, potentially overridden below by custom stuff based on ui_hint etc
                if setting_type == TYPE_BOOL:
                    s_edit = CheckBox.new()
                    s_edit.button_pressed = setting_value
                elif setting_type == TYPE_FLOAT or setting_type == TYPE_INT:
                    s_edit = GNNumberEdit.new()
                    s_edit.expand_to_text_length = true
                    s_edit.is_int = setting_type == TYPE_INT
                    s_edit.set_value_directly(setting_value)
                    s_edit.size_flags_horizontal = Control.SIZE_FILL
                    s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                else:
                    s_edit = CustomLineEdit.new()
                    s_edit.expand_to_text_length = true
                    s_edit.add_theme_constant_override("minimum_character_width", 4)
                    s_edit.text = str(setting_value)
                    s_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                    s_name.size_flags_horizontal = Control.SIZE_FILL

                # Special settings editors based on type and ui_hint etc
                if ui_hint == "string_enum":
                    s_edit = preload("res://ui/data_editors/exclusive_enum.tscn").instantiate() as GNExclusiveEnumEdit
                    var value_set: String = node_schema["settings"][setting_name].get("value_set", "")
                    if not value_set:
                        print_debug("Value set for %s:%s not found in schema" % [asset_node.an_type, setting_name])
                        continue
                    if node_schema["settings"][setting_name]["gd_type"] == TYPE_STRING:
                        var valid_values: Array[String] = SchemaManager.schema.get_value_set_values(value_set)
                        s_edit.set_options(valid_values, setting_value)
                    else:
                        var valid_values: Array = SchemaManager.schema.get_value_set_values(value_set)
                        s_edit.set_numeric_options(valid_values, setting_value)
                elif ui_hint == "enum_as_set":
                    slot_node = VBoxContainer.new()
                    s_edit = preload("res://ui/data_editors/toggle_set.tscn").instantiate() as GNToggleSet
                    var value_set: String = node_schema["settings"][setting_name].get("value_set", "")
                    if not value_set:
                        print_debug("Value set for %s:%s not found in schema" % [asset_node.an_type, setting_name])
                        continue
                    if not setting_type == TYPE_ARRAY:
                        print_debug("UI hinted toggle set for %s:%s but the setting is not an array" % [asset_node.an_type, setting_name])
                        continue
                    var valid_values: Array = SchemaManager.schema.get_value_set_values(value_set)
                    var sub_gd_type: int = node_schema["settings"][setting_name]["array_gd_type"]
                    if sub_gd_type == TYPE_INT:
                        var converted_values: Array = []
                        for value in setting_value:
                            converted_values.append(int(value))
                        s_edit.setup(valid_values, converted_values)
                    else:
                        s_edit.setup(valid_values, setting_value)
                elif ui_hint.begins_with("int_range:"):
                    var range_parts: = ui_hint.trim_prefix("int_range:").split("_", true)
                    if range_parts.size() != 2:
                        push_warning("Invalid int range hint %s for %s:%s" % [ui_hint, asset_node.an_type, setting_name])
                    else:
                        var has_min: = range_parts[0].is_valid_int()
                        var has_max: = range_parts[1].is_valid_int()
                        var spin: CustomSpinBox = preload("res://ui/data_editors/spin_box_edit.tscn").instantiate()
                        spin.step = 1
                        spin.rounded = true
                        if has_min and has_max:
                            spin.min_value = int(range_parts[0])
                            spin.max_value = int(range_parts[1])
                        elif has_max:
                            spin.max_value = int(range_parts[1])
                            spin.min_value = -spin.max_value
                            spin.allow_lesser = true
                        elif has_min:
                            spin.min_value = int(range_parts[0])
                            spin.max_value = 1000000
                            spin.allow_greater = true
                        spin.value = int(float(setting_value))
                        s_edit = spin
                elif ui_hint == "block_id":
                    s_edit.add_theme_constant_override("minimum_character_width", 14)
                elif ui_hint:
                    pass#prints("UI hint %s for %s:%s has no handling" % [ui_hint, asset_node.an_type, setting_name])
                

                s_edit.name = "SettingEdit_%s" % setting_name
                slot_node.name = "Slot%d" % i
                slot_node.add_child(s_name, true)
                slot_node.add_child(s_edit, true)
                graph_node.add_child(slot_node, true)

                settings_syncer.add_watched_setting(setting_name, s_edit, setting_type)
            else:
                var slot_node: = Label.new()
                slot_node.name = "Slot%d" % i
                slot_node.size_flags_horizontal = Control.SIZE_SHRINK_END
                graph_node.add_child(slot_node, true)
                if i < num_inputs:
                    graph_node.set_slot_enabled_left(i, true)
                if i < num_outputs:
                    graph_node.set_slot_enabled_right(i, true)
                    slot_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
                    slot_node.text = connection_names[i]

        # seting up the slot types after all the slot nodes are added so it doesn't complain
        if node_schema:
            graph_node.update_slot_types(type_id_lookup)

    graph_node.update_port_colors()
    
    # NOTE: dumb hack
    get_parent().remove_child(graph_node)
    
    if use_json_positions:
        var meta_pos: = get_node_position_from_meta(asset_node.an_node_id) * json_positions_scale
        graph_node.position_offset = meta_pos - relative_root_position
    
    return graph_node


var connection_cut_active: = false
var connection_cut_start_point: Vector2 = Vector2(0, 0)
var connection_cut_line: Line2D = null
var max_connection_cut_points: = 100000

func start_connection_cut(at_global_pos: Vector2) -> void:
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
        if popup_menu_root.new_gn_menu.visible and mouse_btn_event.is_pressed():
            prints("Hiding new node menu because of mouse button: %s" % mouse_btn_event.button_index)
            popup_menu_root.close_all()
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
    zoom_changed.emit(zoom)

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
        push_error("Error opening JSON file %s" % file_path)
        return
    load_json(file.get_as_text())

func load_json(json_data: String) -> void:
    parsed_json_data = JSON.parse_string(json_data)
    if not parsed_json_data:
        push_error("Error parsing JSON")
        return

    if loaded:
        clear_graph()
        loaded = false
    parse_root_asset_node(parsed_json_data)
    use_json_positions = not parsed_has_no_positions
    create_graph_from_parsed_data()
    loaded = true
    print("")
    

func _on_requested_open_file(path: String) -> void:
    open_file_with_prompt(path)

func on_begin_node_move() -> void:
    moved_nodes_positions.clear()
    var selected_nodes: Array[GraphNode] = get_selected_gns()
    for gn in selected_nodes:
        moved_nodes_positions[gn] = gn.position_offset

func on_end_node_move() -> void:
    var selected_nodes: Array[GraphNode] = get_selected_gns()
    # For now I'm keeping the undo step of moving and inserting into the connection separate
    create_move_nodes_undo_step(selected_nodes)
    if selected_nodes.size() == 1 and selected_nodes[0] is CustomGraphNode:
        var gn_rect: = selected_nodes[0].get_global_rect().grow(-8)
        var connections_overlapped: = get_connections_intersecting_with_rect(gn_rect)
        if try_inserting_graph_node_into_connections(selected_nodes[0], connections_overlapped):
            return

func try_inserting_graph_node_into_connections(gn: CustomGraphNode, connections_overlapped: Array[Dictionary]) -> bool:
    if gn.node_type_schema.get("no_output", false):
        return false
    
    # Dont try to patch in if you already have an output connection
    if raw_out_connections(gn).size() > 0:
        return false

    var gn_output_type: String = gn.node_type_schema.get("output_value_type", "")
    var first_valid_input_port: int = -1

    var schema_connections: Dictionary = gn.node_type_schema.get("connections", {})

    for conn_idx in schema_connections.size():
        if schema_connections.values()[conn_idx]["value_type"] == gn_output_type:
            first_valid_input_port = conn_idx
            break
    if first_valid_input_port == -1:
        return false
    
    for conn_info in connections_overlapped:
        # ignore my own connections
        if conn_info["to_node"] == gn.name or conn_info["from_node"] == gn.name:
            continue
        var conn_value_type: String = get_conn_info_value_type(conn_info)
        if conn_value_type != gn_output_type:
            continue
        
        # Now actually do the connection change
        multi_connection_change = true
        remove_connection(conn_info)
        add_connection({"to_node": gn.name, "to_port": 0}.merged(conn_info))
        add_connection({"from_node": gn.name, "from_port": first_valid_input_port}.merged(conn_info))
        multi_connection_change = false
        create_undo_connection_change_step()
        return true
    return false
    
func get_conn_info_value_type(conn_info: Dictionary) -> String:
    var to_gn: = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
    if not to_gn:
        push_error("get_conn_info_value_type: to node %s not found or is not CustomGraphNode" % conn_info["to_node"])
    return to_gn.node_type_schema["output_value_type"]

func _set_gns_offsets(new_positions: Dictionary[GraphNode, Vector2]) -> void:
    for gn in new_positions.keys():
        gn.position_offset = new_positions[gn]

func create_move_nodes_undo_step(moved_nodes: Array[GraphNode]) -> void:
    unedited = false
    if moved_nodes.size() == 0:
        return
    var new_positions: Dictionary[GraphNode, Vector2] = {}
    for gn in moved_nodes:
        new_positions[gn] = gn.position_offset
    undo_manager.create_action("Move Nodes")
    undo_manager.add_do_method(_set_gns_offsets.bind(new_positions))
    undo_manager.add_undo_method(_set_gns_offsets.bind(moved_nodes_positions.duplicate_deep()))
    undo_manager.commit_action(false)

## Undo/Redo registering for actions which add or remove nodes and connections between nodes
## This method does not do any adding or removing itself, so that still needs to be done before or after calling
## before calling, set cur_added_connections, cur_removed_connections, cur_connection_added_gns, and cur_connection_removed_gns
## does not currently support adding and removing graph nodes during the same step
func create_undo_connection_change_step() -> void:
    unedited = false
    var added_gns: Array[GraphNode] = cur_connection_added_gns.duplicate_deep()
    var removed_gns: Array[GraphNode] = cur_connection_removed_gns.duplicate_deep()
    var added_conns: Array[Dictionary] = cur_added_connections.duplicate_deep()
    var removed_conns: Array[Dictionary] = cur_removed_connections.duplicate_deep()
    cur_connection_added_gns.clear()
    cur_connection_removed_gns.clear()
    cur_added_connections.clear()
    cur_removed_connections.clear()
    
    if added_gns.size() > 0 and removed_gns.size() > 0:
        print_debug("Trying to add and remove graph nodes in the same undo step")
        return
    
    var undo_step_name: = "Connection Change"
    if added_gns.size() > 0:
        undo_step_name = "Add Nodes With Connections"
    elif removed_gns.size() > 0:
        undo_step_name = "Remove Nodes (With Connections)"

    undo_manager.create_action(undo_step_name)
    
    # careful of the order of operations
    # we make sure to add relevant nodes before trying to connect them, and remove them after removing their connections
    # REDOS
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

    if removed_gns.size() > 0:
        undo_manager.add_do_method(redo_remove_gns.bind(removed_gns))
    
    # UNDOS
    if removed_gns.size() > 0:
        var the_ans: Dictionary[GraphNode, HyAssetNode] = {}
        for the_gn in removed_gns:
            print("collecting asset nodes for gn being removed: %s" % the_gn.name)
            print("gn asset node id: %s" % the_gn.get_meta("hy_asset_node_id", ""))
            if the_gn.get_meta("hy_asset_node_id", ""):
                var the_an: HyAssetNode = an_lookup.get(the_gn.get_meta("hy_asset_node_id", ""))
                print("asset node: %s" % the_an)
                the_ans[the_gn] = the_an
        undo_manager.add_undo_method(undo_remove_gns.bind(removed_gns, the_ans))

    if added_conns.size() > 0:
        undo_manager.add_undo_method(remove_multiple_connections.bind(added_conns, false))
    if removed_conns.size() > 0:
        undo_manager.add_undo_method(add_multiple_connections.bind(removed_conns, false))

    if added_gns.size() > 0:
        undo_manager.add_undo_method(undo_add_gns.bind(added_gns))
    
    undo_manager.commit_action(false)

func remove_gns_with_connections_and_undo(gns_to_remove: Array[GraphNode]) -> void:
    if (cur_connection_added_gns.size() > 0 or
        cur_connection_removed_gns.size() > 0 or
        cur_added_connections.size() > 0 or
        cur_removed_connections.size() > 0):
            push_error("Trying to remove graph nodes during a pending undo step")
            return

    var connections_needing_removal: Array[Dictionary] = []
    for gn in gns_to_remove:
        var gn_connections: Array[Dictionary] = raw_connections(gn)
        for conn_info in gn_connections:
            if conn_info["from_node"] == gn.name:
                # exclude outgoing connections to other removed nodes (they would be duplicates of the below case)
                var to_gn: = get_node(NodePath(conn_info["to_node"])) as GraphNode
                if to_gn in gns_to_remove:
                    continue
                connections_needing_removal.append(conn_info)
            elif conn_info["to_node"] == gn.name:
                connections_needing_removal.append(conn_info)
            else:
                print_debug("connection neither from nor to the node it was retreived by? node: %s, connection info: %s" % [gn.name, conn_info])

    if not connections_needing_removal:
        remove_unconnected_gns_with_undo(gns_to_remove)
    else:
        cur_connection_removed_gns.append_array(gns_to_remove)
        cur_removed_connections.append_array(connections_needing_removal)
        remove_multiple_connections(connections_needing_removal, false)
        create_undo_connection_change_step()
    remove_multiple_gns_without_undo(gns_to_remove)

func remove_multiple_gns_without_undo(gns_to_remove: Array[GraphNode]) -> void:
    for gn in gns_to_remove:
        remove_graph_node_without_undo(gn)

func remove_graph_node_without_undo(gn: GraphNode) -> void:
    var an_id: String = gn.get_meta("hy_asset_node_id", "")
    if an_id:
        var asset_node: HyAssetNode = an_lookup.get(an_id, null)
        if asset_node:
            remove_asset_node(asset_node)
    remove_child(gn)

func remove_unconnected_gns_with_undo(gns_to_remove: Array[GraphNode]) -> void:
    unedited = false
    undo_manager.create_action("Remove Graph Nodes")
    var removed_asset_nodes: Dictionary[GraphNode, HyAssetNode] = {}
    for the_gn in gns_to_remove:
        if the_gn.get_meta("hy_asset_node_id", ""):
            removed_asset_nodes[the_gn] = an_lookup[the_gn.get_meta("hy_asset_node_id")]
    
    var removed_gn_list: = gns_to_remove.duplicate()

    undo_manager.add_do_method(redo_remove_gns.bind(removed_gn_list))
    
    undo_manager.add_undo_method(undo_remove_gns.bind(removed_gn_list, removed_asset_nodes))

    undo_manager.commit_action(false)

func create_add_new_gn_undo_step(the_new_gn: GraphNode) -> void:
    create_add_new_gns_undo_step([the_new_gn])

func create_add_new_gns_undo_step(new_gns: Array[GraphNode]) -> void:
    unedited = false
    undo_manager.create_action("Add New Graph Node")
    var added_asset_nodes: Dictionary[GraphNode, HyAssetNode] = {}
    for the_gn in new_gns:
        if the_gn.get_meta("hy_asset_node_id", ""):
            added_asset_nodes[the_gn] = an_lookup[the_gn.get_meta("hy_asset_node_id")]

    undo_manager.add_do_method(redo_add_gns.bind(new_gns, added_asset_nodes))
    
    undo_manager.add_undo_method(undo_add_gns.bind(new_gns))

    undo_manager.commit_action(false)

func undo_remove_gns(the_gns: Array[GraphNode], the_ans: Dictionary[GraphNode, HyAssetNode]) -> void:
    for the_gn in the_gns:
        print_debug("Undo remove GN: %s" % the_gn.name)
        _undo_remove_gn(the_gn, the_ans[the_gn])

func _undo_remove_gn(the_graph_node: GraphNode, the_asset_node: HyAssetNode) -> void:
    _undo_redo_add_gn_and_an(the_graph_node, the_asset_node)

func redo_add_gns(the_gns: Array[GraphNode], the_ans: Dictionary[GraphNode, HyAssetNode]) -> void:
    for the_gn in the_gns:
        redo_add_graph_node(the_gn, the_ans[the_gn])

func redo_add_graph_node(the_graph_node: GraphNode, the_asset_node: HyAssetNode) -> void:
    _undo_redo_add_gn_and_an(the_graph_node, the_asset_node)

func _undo_redo_add_gn_and_an(the_graph_node: GraphNode, the_asset_node: HyAssetNode) -> void:
    _register_asset_node(the_asset_node)
    an_lookup[the_asset_node.an_node_id] = the_asset_node
    gn_lookup[the_asset_node.an_node_id] = the_graph_node
    add_child(the_graph_node, true)

func redo_remove_gns(the_gns: Array[GraphNode]) -> void:
    for the_gn in the_gns:
        _redo_remove_gn(the_gn)

func _redo_remove_gn(the_graph_node: GraphNode) -> void:
    _undo_redo_remove_gn(the_graph_node)

func undo_add_gns(the_gns: Array[GraphNode]) -> void:
    for the_gn in the_gns:
        undo_add_graph_node(the_gn)

func undo_add_graph_node(the_graph_node: GraphNode) -> void:
    _undo_redo_remove_gn(the_graph_node)

func _undo_redo_remove_gn(the_graph_node: GraphNode) -> void:
    if the_graph_node.get_meta("hy_asset_node_id", ""):
        var the_asset_node: HyAssetNode = an_lookup[the_graph_node.get_meta("hy_asset_node_id", "")]
        remove_asset_node(the_asset_node)
    remove_child(the_graph_node)


func _on_requested_save_file(file_path: String) -> void:
    await get_tree().process_frame
    cur_file_name = file_path.get_file()
    cur_file_path = file_path.get_base_dir()
    print("now saving to file %s" % file_path)
    save_to_json_file(file_path)
    has_saved_to_cur_file = true
    unedited = true

func save_to_json_file(file_path: String) -> void:
    _save_to_json_file(file_path)
    %ToastMessageContainer.show_toast_message("Saved")

func _save_to_json_file(file_path: String) -> void:
    var json_str: = get_asset_node_graph_json_str()
    var file: = FileAccess.open(file_path, FileAccess.WRITE)
    if not file:
        push_error("Error opening JSON file for writing: %s" % file_path)
        return
    file.store_string(json_str)
    file.close()
    prints("Saved asset node graph to JSON file: %s" % file_path)
    finished_saving.emit()

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

    var serialized_data: Dictionary = root_node.serialize_me(SchemaManager.schema, gn_lookup)
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
                if not parent_an:
                    parent_gn = null
                    break
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
        floating_trees_serialized.append(floating_tree_root_an.serialize_me(SchemaManager.schema, gn_lookup))
    serialized_metadata["$FloatingNodes"] = floating_trees_serialized
    serialized_metadata["$WorkspaceID"] = hy_workspace_id
    
    for other_key in all_meta.keys():
        if serialized_metadata.has(other_key):
            continue
        serialized_metadata[other_key] = all_meta[other_key]
    return serialized_metadata

func get_metadata_for_gns(gns: Array[GraphNode], scaled_positions: bool, relative_to_offset: Vector2 = Vector2.ZERO) -> Dictionary:
    var node_metadata: Dictionary = {}
    for main_gn in gns:
        var owned_ans: Array[HyAssetNode] = get_gn_own_asset_nodes(main_gn)
        for owned_an in owned_ans:
            node_metadata[owned_an.an_node_id] = single_node_metadata(scaled_positions, owned_an, main_gn, relative_to_offset)
    return node_metadata

func single_node_metadata(scaled_positions: bool, an: HyAssetNode, owning_gn: GraphNode = null, relative_to_offset: Vector2 = Vector2.ZERO) -> Dictionary:
    var metadata: Dictionary = {}
    if an.title:
        metadata["$Title"] = an.title

    var gn: = gn_lookup.get(an.an_node_id, null) as GraphNode
    var position_offset: Vector2 = Vector2.ZERO
    if gn:
        position_offset = gn.position_offset
    elif owning_gn:
        position_offset = owning_gn.position_offset + Vector2(owning_gn.size.x + 100, 0)

    position_offset -= relative_to_offset
    if scaled_positions:
        position_offset /= json_positions_scale
    position_offset = position_offset.round()
    metadata["$Position"] = { "$x": position_offset.x, "$y": position_offset.y }
    return metadata

func on_new_node_type_picked(node_type: String) -> void:
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
            var new_an_schema: Dictionary = SchemaManager.schema.node_schema[new_an.an_type]
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

        snap_gn(new_gn)
        cur_connection_added_gns.append(new_gn)
        add_connection(next_drop_has_connection)
    else:
        var screen_center_pos: = get_viewport().get_visible_rect().size / 2
        new_gn = make_and_add_graph_node(new_an, screen_center_pos)
        new_gn.position_offset -= new_gn.size / 2
        snap_gn(new_gn)
        create_add_new_gn_undo_step(new_gn)

    
func get_dissolve_info(graph_node: GraphNode) -> Dictionary:
    var in_ports_connected: Array[int] = []
    var in_port_connection_count: Dictionary[int, int] = {}
    var dissolve_info: Dictionary = {
        "has_output_connection": false,
        "output_to_gn_name": "",
        "output_to_port_idx": -1,
        "in_ports_connected": in_ports_connected,
        "in_port_connection_count": in_port_connection_count,
    }

    var all_gn_connections: Array[Dictionary] = raw_connections(graph_node)
    for conn_info in all_gn_connections:
        if conn_info["from_node"] == graph_node.name:
            if not in_ports_connected.has(conn_info["from_port"]):
                in_ports_connected.append(conn_info["from_port"])
                in_port_connection_count[conn_info["from_port"]] = 1
            else:
                in_port_connection_count[conn_info["from_port"]] += 1
        elif conn_info["to_node"] == graph_node.name:
            dissolve_info["has_output_connection"] = true
            dissolve_info["output_to_gn_name"] = conn_info["from_node"]
            dissolve_info["output_to_port_idx"] = conn_info["from_port"]
    return dissolve_info

func can_dissolve_gn(graph_node: CustomGraphNode) -> bool:
    if not graph_node.get_meta("hy_asset_node_id", ""):
        return false
    
    var dissolve_info: = get_dissolve_info(graph_node)
    if not dissolve_info["has_output_connection"] or dissolve_info["in_ports_connected"].size() == 0:
        return false
    
    var output_value_type: String = graph_node.node_type_schema.get("output_value_type", "")
    if not output_value_type:
        return true
    
    var connected_connections_types: Array[String] = []
    for conn_idx in dissolve_info["in_ports_connected"]:
        var conn_type: String = graph_node.node_type_schema["connections"].values()[conn_idx].get("value_type", "")
        connected_connections_types.append(conn_type)
    
    return output_value_type in connected_connections_types

func dissolve_gn_with_undo(graph_node: CustomGraphNode) -> void:
    var dissolve_info: = get_dissolve_info(graph_node)
    if not graph_node.get_meta("hy_asset_node_id", "") or not dissolve_info["has_output_connection"]:
        print_debug("Dissolve: node %s is not an asset node or has no output connection" % graph_node.name)
        _delete_request([graph_node.name])
        return
    
    var cur_schema: = graph_node.node_type_schema
    var val_type: String = cur_schema.get("output_value_type", "")
    var output_to_gn: = get_node(NodePath(dissolve_info["output_to_gn_name"])) as CustomGraphNode
    if not output_to_gn:
        push_error("Dissolve: output to node %s not found or is not CustomGraphNode" % dissolve_info["output_to_gn_name"])
        _delete_request([graph_node.name])
        return
    
    prints("dissovling", graph_node.name, "with dissolve info", dissolve_info)
    
    assert(output_to_gn.node_type_schema, "Dissolve: output to node %s has no schema set" % output_to_gn.name)
    
    var out_to_connection_schema: Dictionary = output_to_gn.node_type_schema.get("connections", {})
    var out_conn_idx: int = dissolve_info["output_to_port_idx"]
    var is_multi: bool = out_to_connection_schema.values()[out_conn_idx].get("multi", false)
    
    var cur_asset_node: HyAssetNode = an_lookup.get(graph_node.get_meta("hy_asset_node_id", ""), null)
    assert(cur_asset_node, "Dissolve: current asset node not found")
    # Sort asset node connections so the first one found if the out target isn't a multi connect is deterministic
    cur_asset_node.sort_connections_by_gn_pos(gn_lookup)
    
    multi_connection_change = true
    for in_port_idx in dissolve_info["in_ports_connected"]:
        prints("dissolving node input port %d (%s)" % [in_port_idx, cur_asset_node.connection_list[in_port_idx]])
        var conn_schema: Dictionary = cur_schema.get("connections", {}).values()[in_port_idx]
        var in_val_type: String = conn_schema["value_type"]
        if val_type and in_val_type != val_type:
            prints("connection (%s) isn't the right value type, skipping" % in_val_type)
            continue
        
        var conn_name: = cur_asset_node.connection_list[in_port_idx]
        var connected_graph_nodes: Array[GraphNode] = get_graph_connected_graph_nodes(graph_node, conn_name)
        prints("connected graph nodes on this port: %s" % [connected_graph_nodes])
        var connected_one: bool = false
        for in_gn in connected_graph_nodes:
            connected_one = true
            prints("removing connection from %s to %s" % [graph_node.name, in_gn.name])
            _remove_connection(graph_node.name, in_port_idx, in_gn.name, 0)
            prints("adding connection from %s to %s" % [graph_node.name, in_gn.name])
            _add_connection(output_to_gn.name, out_conn_idx, in_gn.name, 0)
            if not is_multi:
                break
        if not is_multi and connected_one:
            prints("stopping after connecting one")
            break
    
    var leftover_connections: = raw_connections(graph_node)
    prints("leftover connections: %s" % [leftover_connections])
    remove_multiple_connections(leftover_connections)
    
    multi_connection_change = false

    cur_connection_removed_gns.append(graph_node)
    create_undo_connection_change_step()
    remove_graph_node_without_undo(graph_node)



func _on_graph_node_right_clicked(graph_node: CustomGraphNode) -> void:
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
    var multiple_selected: bool = false
    if not graph_node.selected:
        deselect_all()
        set_selected(graph_node)
    elif get_selected_gns().size() > 1:
        multiple_selected = true
    
    var is_asset_node: bool = graph_node.get_meta("hy_asset_node_id", "") != ""

    var context_menu: PopupMenu = PopupMenu.new()

    context_menu.name = "NodeContextMenu"
    
    var plural_s: = "s" if multiple_selected else ""
    
    context_menu.add_item("Copy Node" + plural_s, ContextMenuItems.COPY_NODES)
    context_menu.add_item("Cut Node" + plural_s, ContextMenuItems.COPY_NODES)

    context_menu.add_item("Delete Node" + plural_s, ContextMenuItems.DELETE_NODES)
    if not can_delete_gn(graph_node):
        var delete_idx: int = context_menu.get_item_index(ContextMenuItems.DELETE_NODES)
        context_menu.set_item_disabled(delete_idx, true)
    
    if is_asset_node:
        context_menu.add_item("Dissolve Node", ContextMenuItems.DISSOLVE_NODES)
        if not can_dissolve_gn(graph_node):
            var dissolve_idx: int = context_menu.get_item_index(ContextMenuItems.DISSOLVE_NODES)
            context_menu.set_item_disabled(dissolve_idx, true)
        context_menu.id_pressed.connect(on_node_context_menu_id_pressed.bind(graph_node))
    
    context_menu.add_item("Duplicate Node" + plural_s, ContextMenuItems.DUPLICATE_NODES)

    add_child(context_menu, true)

    context_menu.position = Util.get_context_menu_pos(get_global_mouse_position())
    context_menu.popup()

func on_node_context_menu_id_pressed(node_context_menu_id: ContextMenuItems, on_gn: GraphNode) -> void:
    match node_context_menu_id:
        ContextMenuItems.DELETE_NODES:
            _delete_request_refs(get_selected_gns())
        ContextMenuItems.DISSOLVE_NODES:
            dissolve_gn_with_undo(on_gn as CustomGraphNode)
        ContextMenuItems.DUPLICATE_NODES:
            duplicate_selected_gns()


func get_duplicate_gn_name(old_gn_name: String) -> String:
    var base_name: = old_gn_name.split("--")[0]
    return new_graph_node_name(base_name)

func new_graph_node_name(base_name: String) -> String:
    global_gn_counter += 1
    return "%s--%d" % [base_name, global_gn_counter]

func raw_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    assert(is_same(graph_node.get_parent(), self), "raw_connections: Graph node %s is not a direct child of the graph edit" % graph_node.name)

    # Workaround to avoid erronious error from trying to get connection list of nodes whose connections have never been touched yet
    # this triggers the connection_map having an entry for this node name
    is_node_connected(graph_node.name, 0, graph_node.name, 0)

    return get_connection_list_from_node(graph_node.name)

func raw_out_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    var raw_gn_connections: = raw_connections(graph_node)
    var out_conn_infos: Array[Dictionary] = []
    for conn_info in raw_gn_connections:
        if conn_info["to_node"] == graph_node.name:
            out_conn_infos.append(conn_info)
    return out_conn_infos

func raw_in_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    var raw_gn_connections: = raw_connections(graph_node)
    var in_conn_infos: Array[Dictionary] = []
    for conn_info in raw_gn_connections:
        if conn_info["from_node"] == graph_node.name:
            in_conn_infos.append(conn_info)
    return in_conn_infos

func can_delete_gn(graph_node: CustomGraphNode) -> bool:
    if graph_node == get_root_gn():
        return false
    return true