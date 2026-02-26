extends GraphEdit
class_name CHANE_AssetNodeGraphEdit

const UndoStep = preload("res://graph_editor/undo_redo/undo_step.gd")
const GraphUndoStep = preload("res://graph_editor/undo_redo/graph_undo_step.gd")

signal zoom_changed(new_zoom: float)

const SpecialGNFactory = preload("res://graph_editor/custom_graph_nodes/special_gn_factory.gd")

var editor: CHANE_AssetNodeEditor = null

## Do not access directly, use get_top_level_graph_nodes()
var _top_level_graph_nodes: Array[CustomGraphNode] = []
var potential_top_level_graph_nodes: Array[CustomGraphNode] = []

@export var popup_menu_root: PopupMenuRoot

var more_type_names: Array[String] = [
    "Test",
]
var type_id_lookup: Dictionary[String, int] = {}

@onready var cur_zoom_level: = zoom
@onready var grid_logical_enabled: = show_grid

var duplicate_offset: Vector2 = Vector2(0, 30)

var context_menu_target_node: Node = null
var context_menu_pos_offset: Vector2 = Vector2.ZERO
var context_menu_movement_acc: = 0.0
var context_menu_ready: bool = false

var output_port_drop_offset: Vector2 = Vector2(2, -34)
var input_port_drop_first_offset: Vector2 = Vector2(-2, -34)
var input_port_drop_additional_offset: Vector2 = Vector2(0, -19)

var moved_nodes_old_positions: Dictionary[GraphElement, Vector2] = {}
var moved_groups_old_sizes: Dictionary[GraphFrame, Vector2] = {}
var cur_move_detached_nodes: = false

var file_menu_btn: MenuButton = null
var file_menu_menu: PopupMenu = null

var settings_menu_btn: MenuButton = null
var settings_menu_menu: PopupMenu = null

func _ready() -> void:
    assert(popup_menu_root != null, "Popup menu root is not set, please set it in the inspector")
    
    focus_exited.connect(on_focus_exited)

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
    
    graph_elements_linked_to_frame_request.connect(_link_to_group_request)
    
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
    version_label.text = "Cam Hytale ANE %s" % Util.get_version_number_string()
    last_menu_hbox_item.add_child(version_label)
    version_label.offset_left = 12
    
    setup_graph_edit_connection_types()

func set_editor(new_editor: CHANE_AssetNodeEditor) -> void:
    editor = new_editor
    
    setup_menus()
    
func setup_graph_edit_connection_types() -> void:
    for extra_type_name in more_type_names:
        var type_idx: = type_names.size()
        type_names[type_idx] = extra_type_name

    var unknown_type_id: = type_names.size()
    type_names[unknown_type_id] = "Unknown"
    add_valid_connection_type(unknown_type_id, unknown_type_id)
    
    for val_type_name in SchemaManager.schema.value_types:
        for i in 2:
            var val_type_idx: = type_names.size()
            type_names[val_type_idx] = val_type_name if i == 0 else val_type_name + "::Single"
            add_valid_connection_type(val_type_idx, val_type_idx - i)
            add_valid_connection_type(val_type_idx, unknown_type_id)
            add_valid_connection_type(unknown_type_id, val_type_idx)
            if i == 1:
                add_valid_left_disconnect_type(val_type_idx)

    for type_id in type_names.keys():
        type_id_lookup[type_names[type_id]] = type_id

func get_name_of_connection_type_id(type_id: int) -> String:
    var type_name: String = type_names[type_id]
    return type_name.replace("::Single", "")

func get_left_type_of_conn_info(connection_info: Dictionary) -> String:
    var unknown_connection_type: int = type_id_lookup["Unknown"]
    var left_gn: GraphNode = get_node(NodePath(connection_info["from_node"]))
    var raw_type: int = left_gn.get_slot_type_right(connection_info["from_port"])
    if raw_type <= unknown_connection_type:
        return ""
    return get_name_of_connection_type_id(raw_type)

func get_right_type_of_conn_info(connection_info: Dictionary) -> String:
    var unknown_connection_type: int = type_id_lookup["Unknown"]
    var right_gn: GraphNode = get_node(NodePath(connection_info["to_node"]))
    var raw_type: int = right_gn.get_slot_type_left(connection_info["to_port"])
    if raw_type <= unknown_connection_type:
        return ""
    return get_name_of_connection_type_id(raw_type)

func get_type_of_conn_info(connection_info: Dictionary) -> String:
    var left_type: String = get_left_type_of_conn_info(connection_info)
    var right_type: String = get_right_type_of_conn_info(connection_info)
    if left_type == "":
        return right_type
    elif right_type == "":
        return left_type
    elif left_type != right_type:
        return ""
    return left_type

func on_focus_exited() -> void:
    if connection_cut_active:
        cancel_connection_cut()
    mouse_panning = false

func _shortcut_input(event: InputEvent) -> void:
    if not editor.are_shortcuts_allowed():
        return

    if Input.is_action_just_pressed_by_event("graph_select_all_nodes", event, true):
        accept_event()
        select_all()
    elif Input.is_action_just_pressed_by_event("graph_deselect_all_nodes", event, true):
        accept_event()
        deselect_all()
    elif Input.is_action_just_pressed_by_event("cut_inclusive_shortcut", event, true):
        accept_event()
        cut_selected_nodes_inclusive()
    elif Input.is_action_just_pressed_by_event("delete_inclusive_shortcut", event, true):
        accept_event()
        delete_selected_nodes_inclusive()

var log_toggle: = true
func _process(_delta: float) -> void:
    if is_moving_nodes() and not cur_move_detached_nodes and Util.is_shift_pressed():
        change_current_node_move_to_detach_mode()
    if is_moving_nodes() and cur_move_detached_nodes and Util.is_shift_pressed():
        if log_toggle:
            prints("shift pressed while moving nodes, already detached")
            log_toggle = false
    if not log_toggle and not is_moving_nodes():
        log_toggle = true
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
    
    if OS.is_debug_build():
        file_menu_menu.add_item("Print File Diff", 4)
    
    file_menu_menu.index_pressed.connect(editor.on_file_menu_index_pressed.bind(file_menu_menu, self))

func setup_settings_menu() -> void:
    settings_menu_btn = preload("res://ui/settings_menu.tscn").instantiate()
    settings_menu_menu = settings_menu_btn.get_popup()
    var menu_hbox: = get_menu_hbox()
    menu_hbox.add_child(settings_menu_btn)
    menu_hbox.move_child(settings_menu_btn, 0)
    settings_menu_menu.index_pressed.connect(on_settings_menu_index_pressed)
    settings_menu_menu.about_to_popup.connect(on_settings_menu_about_to_popup)

func on_settings_menu_about_to_popup() -> void:
    var dbl_click_is_greedy: = ANESettings.select_subtree_is_greedy
    settings_menu_menu.set_item_checked(1, dbl_click_is_greedy)

func on_settings_menu_index_pressed(index: int) -> void:
    editor.on_settings_menu_index_pressed(index, settings_menu_menu)

func snap_ge(ge: GraphElement) -> void:
    if snapping_enabled:
        ge.position_offset = ge.position_offset.snapped(Vector2.ONE * snapping_distance)

func snap_ges(ges: Array) -> void:
    if not snapping_enabled:
        return
    for ge in ges:
        snap_ge(ge)

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

func _connection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    add_connection(from_gn_name, from_port, to_gn_name, to_port)

func add_multiple_connections(conns_to_add: Array[Dictionary]) -> void:
    editor.connect_graph_nodes(conns_to_add, self)

func add_connection_info(connection_info: Dictionary) -> void:
    editor.connect_graph_nodes([connection_info], self)

func add_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    add_connection_info({
        "from_node": from_gn_name,
        "from_port": from_port,
        "to_node": to_gn_name,
        "to_port": to_port,
    })

func _disconnection_request(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    remove_connection(from_gn_name, from_port, to_gn_name, to_port)

func remove_connection(from_gn_name: StringName, from_port: int, to_gn_name: StringName, to_port: int) -> void:
    remove_multiple_connections([{
        "from_node": from_gn_name,
        "from_port": from_port,
        "to_node": to_gn_name,
        "to_port": to_port,
    }])

func remove_connection_info(connection_info: Dictionary) -> void:
    remove_multiple_connections([connection_info])

func remove_multiple_connections(conns_to_remove: Array[Dictionary]) -> void:
    editor.disconnect_graph_nodes(conns_to_remove, self)

func undo_redo_add_connections(conns_to_add: Array[Dictionary]) -> void:
    for conn_to_add in conns_to_add:
        _actually_add_connection(conn_to_add)

func _actually_add_connection(conn_to_add: Dictionary) -> void:
    var to_gn: GraphNode = get_node(NodePath(conn_to_add["to_node"]))
    if to_gn in _top_level_graph_nodes:
        _top_level_graph_nodes.erase(to_gn)
    connect_node(conn_to_add["from_node"], conn_to_add["from_port"], conn_to_add["to_node"], conn_to_add["to_port"])

func undo_redo_remove_connections(conns_to_remove: Array[Dictionary], skip_on_commit: bool = false) -> void:
    if skip_on_commit and editor.undo_manager.undo_redo.is_committing_action():
        return
    for conn_to_remove in conns_to_remove:
        _actually_remove_connection(conn_to_remove)

# Instead of immediately counting remaining connections to determine if the to node is now top level we just add it to a list to lazily check when the list of top level gns is requested
func _actually_remove_connection(conn_to_remove: Dictionary) -> void:
    if not is_node_connected(conn_to_remove["from_node"], conn_to_remove["from_port"], conn_to_remove["to_node"], conn_to_remove["to_port"]):
        return
    var to_gn: GraphNode = get_node(NodePath(conn_to_remove["to_node"]))
    if not to_gn in potential_top_level_graph_nodes and not to_gn in _top_level_graph_nodes:
        potential_top_level_graph_nodes.append(to_gn)
    disconnect_node(conn_to_remove["from_node"], conn_to_remove["from_port"], conn_to_remove["to_node"], conn_to_remove["to_port"])

func _delete_request(delete_ge_names: Array[StringName]) -> void:
    var ges_to_remove: Array[GraphElement] = []
    for ge_name in delete_ge_names:
        var ge: GraphElement = get_node_or_null(NodePath(ge_name))
        if ge:
            ges_to_remove.append(ge)
    delete_ges(ges_to_remove)
    
func delete_ges(ges_to_delete: Array[GraphElement]) -> void:
    var root_gn: GraphNode = editor.root_graph_node
    prints("root gn name: %s" % root_gn.name)
    if root_gn in ges_to_delete:
        ges_to_delete.erase(root_gn)
    if ges_to_delete.size() == 0:
        return
    editor.delete_graph_elements(ges_to_delete, self)

func delete_selected_nodes_inclusive() -> void:
    var inclusive_selected: Array[GraphElement] = get_inclusive_selected_ges() 
    delete_ges(inclusive_selected)

func remove_groups_only_with_undo(groups_to_remove: Array[GraphFrame]) -> void:
    editor.undo_manager.start_or_continue_undo_step("Delete Groups Only")
    var is_new_step: = editor.undo_manager.is_new_step

    var ges_to_remove: Array[GraphElement] = []
    ges_to_remove.append_array(groups_to_remove)
    delete_ges(ges_to_remove)

    if is_new_step:
        editor.undo_manager.commit_if_new()

func get_drop_offset_for_output_port() -> Vector2:
    return output_port_drop_offset

func get_drop_offset_for_input_port(input_port_idx: int) -> Vector2:
    return input_port_drop_first_offset + (input_port_drop_additional_offset * input_port_idx)

func _connect_right_request(from_gn_name: StringName, from_port: int, dropped_local_pos: Vector2) -> void:
    var connection_info: = {
        "from_node": from_gn_name,
        "from_port": from_port,
    }
    _connect_new_request(true, from_gn_name, dropped_local_pos, connection_info)

func _connect_left_request(to_gn_name: StringName, to_port: int, dropped_local_pos: Vector2) -> void:
    var connection_info: = {
        "to_node": to_gn_name,
        "to_port": to_port,
    }
    _connect_new_request(false, to_gn_name, dropped_local_pos, connection_info)

func _connect_new_request(is_right: bool, from_gn_name: String, at_local_pos: Vector2, connection_info: Dictionary) -> void:
    var connecting_from_gn: CustomGraphNode = get_node(from_gn_name)

    var conn_value_type: String = ""
    if is_right:
        var conn_name: String = connecting_from_gn.input_connection_list[connection_info["from_port"]]
        conn_value_type = connecting_from_gn.input_value_types[conn_name]
    else:
        conn_value_type = connecting_from_gn.get_output_value_type()

    var at_pos_offset: = local_pos_to_pos_offset(at_local_pos)
    var cur_drop_info: = {
        "dropping_in_graph": self,
        "at_pos_offset": at_pos_offset,
        "has_position": true,
        "is_right": is_right,
        "connection_info": connection_info,
        "connection_value_type": conn_value_type,
    }
    
    # Add the new node to a group if dropped point is inside it (plus some margin)
    var all_groups: Array[GraphFrame] = get_all_groups()
    for group in all_groups:
        var group_rect: = get_pos_offset_rect(group).grow(8)
        if group_rect.has_point(at_pos_offset):
            cur_drop_info["into_group"] = group
            break

    editor.connect_new_request(cur_drop_info)


func get_all_graph_nodes() -> Array[CustomGraphNode]:
    var all_gns: Array[CustomGraphNode] = []
    for ge in get_children():
        if ge is CustomGraphNode:
            all_gns.append(ge)
    return all_gns

func get_selected_gns() -> Array[GraphNode]:
    var selected_gns: Array[GraphNode] = []
    for c in get_children():
        if c is GraphNode and c.selected:
            selected_gns.append(c)
    return selected_gns

func get_selected_ges() -> Array[GraphElement]:
    var selected_ges: Array[GraphElement] = []
    for ge in get_children():
        if ge is GraphElement and ge.selected:
            selected_ges.append(ge)
    return selected_ges

func get_selected_groups() -> Array[GraphFrame]:
    var selected_groups: Array[GraphFrame] = []
    for ge in get_children():
        if ge is GraphFrame and ge.selected:
            selected_groups.append(ge)
    return selected_groups

## Get all selected graph elements and group members of selected groups including recusively through sub-groups
func get_inclusive_selected_ges() -> Array[GraphElement]:
    var selected_ges: Array[GraphElement] = get_selected_ges()
    for ge in selected_ges:
        if ge is GraphFrame:
            selected_ges.append_array(get_recursive_group_members(ge))
    return selected_ges

func get_group_members(group: GraphFrame) -> Array[GraphElement]:
    var members: Array[GraphElement] = []
    for member_name in get_attached_nodes_of_frame(group.name):
        var ge: = get_node(NodePath(member_name)) as GraphElement
        if ge:
            members.append(ge)
    return members

func get_recursive_group_members(group: GraphFrame) -> Array[GraphElement]:
    var members: Array[GraphElement] = []
    var group_member_names: Array[StringName] = get_attached_nodes_of_frame(group.name)
    for member_name in group_member_names:
        var sub_group: = get_node(NodePath(member_name)) as GraphFrame
        if sub_group:
            members.append_array(get_recursive_group_members(sub_group))
        members.append(get_node(NodePath(member_name)) as GraphElement)
    return members

func get_all_ges() -> Array[GraphElement]:
    var all_ges: Array[GraphElement] = []
    for ge in get_children():
        if ge is GraphElement:
            all_ges.append(ge)
    return all_ges

func select_all() -> void:
    for c in get_children():
        if c is GraphElement:
            c.selected = true

func deselect_all() -> void:
    set_selected(null)

func invert_selection() -> void:
    var selected_ges: Array[GraphElement] = get_selected_ges()
    for ge in get_children():
        if not ge is GraphElement:
            continue
        ge.selected = ge not in selected_ges

func select_gns(gns: Array[CustomGraphNode]) -> void:
    var ges: Array[GraphElement] = []
    ges.assign(gns)
    select_ges(ges)

func select_ges(ges: Array[GraphElement]) -> void:
    deselect_all()
    for ge in ges:
        ge.selected = true

func select_ges_by_names(names: Array[String]) -> void:
    deselect_all()
    for ge_name in names:
        var ge: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if ge:
            ge.selected = true

func select_nodes_in_group(group: GraphFrame, deep: bool = true) -> void:
    var member_ges: Array[GraphElement] = []
    if deep:
        member_ges.append_array(get_recursive_group_members(group))
    else:
        member_ges.append_array(get_attached_nodes_of_frame(group.name))
    for ge in member_ges:
        ge.selected = true

func _duplicate_request() -> void:
    duplicate_selected_ges()

func duplicate_selected_ges() -> void:
    editor.duplicate_graph_elements(get_selected_ges(), self, duplicate_offset, true)

func _cut_request() -> void:
    editor.cut_graph_elements_into_fragment(get_selected_ges(), self)

func cut_selected_nodes_inclusive() -> void:
    editor.cut_graph_elements_into_fragment(get_inclusive_selected_ges(), self)

func _copy_request() -> void:
    copy_selected_ges()

func copy_selected_ges() -> void:
    editor.copy_graph_elements_into_fragment(get_selected_ges(), self)

func _paste_request() -> void:
    paste_copied_fragment_centered()

func paste_copied_fragment_centered() -> void:
    editor.paste_cur_copied_fragment_centered(true, self)

func paste_copied_fragment_at(paste_local_pos: Vector2) -> void:
    editor.paste_cur_copied_fragment_at_pos(paste_local_pos, true, self)

func _group_sorter(a: GraphFrame, b: GraphFrame) -> int:
    return minf(a.size.x, a.size.y) < minf(b.size.x, b.size.y)

func add_nodes_inside_to_groups(groups: Array[GraphFrame], ges: Array[GraphElement], empty_no_shrink: bool = true, save_undo: bool = true) -> void:
    _handle_groups_inside_groups(groups, save_undo)
    var group_rects: Dictionary[GraphFrame, Rect2] = {}
    for group in groups:
        group_rects[group] = get_pos_offset_rect(group)
    var sorted_groups: Array[GraphFrame] = groups.duplicate()
    sorted_groups.sort_custom(_group_sorter)
    
    # TODO: better detection in the case of nested groups
    var added_group_relations: Array[Dictionary] = []
    for graph_element in ges:
        if graph_element is GraphFrame:
            continue
        var ge_rect: Rect2 = get_pos_offset_rect(graph_element)
        for group in sorted_groups:
            var group_rect: Rect2 = group_rects[group]
            if group_rect.has_point(ge_rect.get_center()):
                added_group_relations.append({ "group": group, "member": graph_element })
                group_rects[group].merge(ge_rect)
                break
    for group in groups:
        group.position_offset = group_rects[group].position
        group.size = group_rects[group].size

    if empty_no_shrink:
        for the_group in groups:
            if get_attached_nodes_of_frame(the_group.name).size() == 0:
                _set_group_shrinkwrap(the_group, false)

    if save_undo:
        add_group_relations(added_group_relations, true)
    else:
        _assign_group_relations(added_group_relations)

func _handle_groups_inside_groups(groups: Array[GraphFrame], save_undo: bool) -> void:
    var group_rects: Dictionary[GraphFrame, Rect2] = {}
    for group in groups:
        group_rects[group] = get_pos_offset_rect(group)
    var group_relations: Array[Dictionary] = []
    
    var sorted_groups: Array[GraphFrame] = groups.duplicate()
    sorted_groups.sort_custom(_group_sorter)
    
    for i in sorted_groups.size():
        var cur_group: = sorted_groups[i]
        for j in range(i + 1, sorted_groups.size()):
            var other_group: = sorted_groups[j]
            if group_rects[other_group].encloses(group_rects[cur_group]):
                group_relations.append({ "group": other_group, "member": cur_group })
                break
    if save_undo:
        add_group_relations(group_relations, true)
    else:
        _assign_group_relations(group_relations)

func small_groups_to_top() -> void:
    var group_list: Array[GraphFrame] = get_all_groups()
    group_list.sort_custom(_group_sorter)
    group_list.reverse()
    for group in group_list:
        bring_group_to_front(group)

## Clean up current graph, freeing any Godot Nodes we remove as they would become orphaned otherwise
func clear_graph() -> void:
    _top_level_graph_nodes.clear()
    potential_top_level_graph_nodes.clear()
    cleanup_graph_elements()
    cancel_connection_cut()

func cleanup_graph_elements() -> void:
    for child in get_children():
        if child is GraphElement:
            remove_child(child)
            child.queue_free()

func scroll_to_graph_element(graph_element: GraphElement) -> void:
    var ge_center: Vector2 = get_pos_offset_rect(graph_element).get_center()
    scroll_to_pos_offset(ge_center)

func scroll_to_pos_offset(pos_offset: Vector2) -> void:
    await get_tree().process_frame
    scroll_offset = get_scroll_of_pos_offset_centered(pos_offset)

func get_scroll_of_pos_offset_centered(pos_offset: Vector2) -> Vector2:
    return pos_offset * zoom - (size / 2) 

func make_json_groups(group_datas: Array[Dictionary], add_nodes_inside: bool) -> void:
    var added_groups: Array[GraphFrame] = []
    for group_data in group_datas:
        added_groups.append(deserialize_and_add_group(group_data, true, false))
    if add_nodes_inside:
        add_nodes_inside_to_groups(added_groups, get_all_ges(), false, false)
    small_groups_to_top()
    refresh_graph_elements_in_frame_status()
    
func manually_position_new_graph_node_trees(root_asset_nodes: Array[HyAssetNode], new_graph_nodes: Array[CustomGraphNode], start_at_pos: Vector2) -> void:
    var ans_to_gns: Dictionary[HyAssetNode, CustomGraphNode] = {}
    for new_gn in new_graph_nodes:
        ans_to_gns[editor.get_gn_main_asset_node(new_gn)] = new_gn

    var base_tree_pos: = start_at_pos
    for tree_root_node in root_asset_nodes:
        var last_y: int = auto_move_children(tree_root_node, ans_to_gns, base_tree_pos)
        base_tree_pos.y = last_y + 40
    snap_ges(ans_to_gns.values())

func auto_move_children(asset_node: HyAssetNode, ans_to_gns: Dictionary, pos: Vector2) -> int:
    var graph_node: = ans_to_gns[asset_node] as CustomGraphNode
    graph_node.position_offset = pos

    var child_pos: = pos + (Vector2.RIGHT * (graph_node.size.x + 40))
    var connection_names: Array[String] = asset_node.connection_list

    for conn_idx in connection_names.size():
        var conn_name: = connection_names[conn_idx]
        for connected_an in asset_node.get_all_connected_nodes(conn_name):
            var conn_gn: = ans_to_gns.get(connected_an, null) as CustomGraphNode
            if not conn_gn:
                continue

            if connected_an.connection_list.size() > 0:
                child_pos.y = auto_move_children(connected_an, ans_to_gns, child_pos)
            else:
                conn_gn.position_offset = child_pos
                child_pos.y += conn_gn.size.y + 40
    
    return int(child_pos.y)

func get_graph_connected_asset_nodes(graph_node: CustomGraphNode, conn_name: String) -> Array[HyAssetNode]:
    if editor.gn_is_special(graph_node):
        return graph_node.get_non_owned_connected_asset_nodes(conn_name)
    else:
        var asset_node: = editor.get_gn_main_asset_node(graph_node)
        return asset_node.get_all_connected_nodes(conn_name)

func get_internal_connections_for_gns(gns: Array[CustomGraphNode]) -> Array[Dictionary]:
    var internal_connections: Array[Dictionary] = []
    for gn in gns:
        for conn_info in raw_connections(gn):
            if conn_info["from_node"] == gn.name:
                var to_gn: = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
                if to_gn in gns:
                    internal_connections.append(conn_info)
    return internal_connections

func get_external_connections_for_ges(graph_elements: Array) -> Array[Dictionary]:
    var ges: Array[GraphElement] = Array(graph_elements, TYPE_OBJECT, &"GraphElement", null)
    var ge_names: Array = ges.map(func(ge): return ge.name)

    var external_connections: Array[Dictionary] = []
    for ge in ges:
        if not ge is CustomGraphNode:
            continue
        for conn_info in raw_connections(ge):
            if int(conn_info["from_node"] in ge_names) ^ int(conn_info["to_node"] in ge_names) == 1:
                external_connections.append(conn_info)
    return external_connections

func get_graph_connected_graph_nodes(graph_node: CustomGraphNode, conn_name: String) -> Array[GraphNode]:
    var connected_asset_nodes: Array[HyAssetNode] = get_graph_connected_asset_nodes(graph_node, conn_name)
    var connected_graph_nodes: Array[GraphNode] = []
    for connected_asset_node in connected_asset_nodes:
        connected_graph_nodes.append(editor.gn_lookup[connected_asset_node.an_node_id])
    return connected_graph_nodes

func get_child_node_of_class(parent: Node, class_names: Array[String]) -> Node:
    if parent.get_class() in class_names:
        return parent
    
    for child in parent.get_children():
        var found_node: = get_child_node_of_class(child, class_names)
        if found_node:
            return found_node
    return null

func update_all_ges_themes() -> void:
    for child in get_children():
        if child is CustomGraphNode:
            update_custom_gn_theme(child)
        elif child is GraphFrame:
            update_group_theme(child)

func update_custom_gn_theme(graph_node: CustomGraphNode) -> void:
    var output_type: String = graph_node.theme_color_output_type
    if not output_type:
        return
    
    var theme_var_color: String = TypeColors.get_color_for_type(output_type)
    if ThemeColorVariants.has_theme_color(theme_var_color):
        graph_node.theme = ThemeColorVariants.get_theme_color_variant(theme_var_color)
    graph_node.update_port_colors()

func update_group_theme(_group: GraphFrame) -> void:
    # for now groups dont change themes based on type -> color assignments
    # they just have specific color names set as their accent color
    pass

var connection_cut_active: = false
var connection_cut_start_point: Vector2 = Vector2(0, 0)
var connection_cut_line: Line2D = null
var max_connection_cut_points: = 100000

func start_connection_cut(at_global_pos: Vector2) -> void:
    connection_cut_active = true
    connection_cut_start_point = at_global_pos
    
    connection_cut_line = preload("res://graph_editor/connection_cutting_line.tscn").instantiate() as Line2D
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
    
    editor.undo_manager.start_or_continue_undo_step("Cut Connections")
    var is_new_step: = editor.undo_manager.is_new_step
    
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
                remove_connection_info(connection_at_point)
        prev_cut_point = cut_global_pos
    

    if is_new_step:
        if num_cut == 0:
            editor.undo_manager.cancel_creating_undo_step()
        else:
            editor.undo_manager.commit_current_undo_step()
    cancel_connection_cut()


var mouse_panning: = false

func handle_mouse_event(event: InputEventMouse) -> void:
    var mouse_btn_event: = event as InputEventMouseButton
    var mouse_motion_event: = event as InputEventMouseMotion
    
    if mouse_btn_event:
        if popup_menu_root.new_gn_menu.visible and mouse_btn_event.is_pressed():
            popup_menu_root.close_all()
            if mouse_btn_event.button_index == MOUSE_BUTTON_LEFT:
                return

        if mouse_btn_event.button_index == MOUSE_BUTTON_RIGHT:
            if context_menu_ready and not mouse_btn_event.is_pressed():
                if not context_menu_target_node:
                    actually_right_click_nothing()
                elif context_menu_target_node is CustomGraphNode:
                    actually_right_click_gn(context_menu_target_node)
                elif context_menu_target_node is GraphFrame:
                    actually_right_click_group(context_menu_target_node)

            if mouse_btn_event.is_pressed():
                if mouse_btn_event.ctrl_pressed:
                    start_connection_cut(mouse_btn_event.global_position)
                else:
                    mouse_panning = true
                    if not context_menu_ready:
                        check_for_group_context_menu_click_start(mouse_btn_event)
                        if not context_menu_ready:
                            ready_context_menu_for(null)
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

func check_for_group_context_menu_click_start(mouse_btn_event: InputEventMouseButton) -> void:
    var mouse_pos_offset: = local_pos_to_pos_offset(mouse_btn_event.position)
    for group in get_all_groups():
        var group_rect: = get_pos_offset_rect(group)
        if group_rect.has_point(mouse_pos_offset):
            ready_context_menu_for(group)

func get_all_groups() -> Array[GraphFrame]:
    var groups: Array[GraphFrame] = []
    for child in get_children():
        if child is GraphFrame:
            groups.append(child)
    return groups

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
    

func on_begin_node_move() -> void:
    moved_nodes_old_positions.clear()
    moved_groups_old_sizes.clear()
    var detach_from_groups: bool = Util.is_shift_pressed()
    cur_move_detached_nodes = detach_from_groups
    # Get nodes inclusive recusively of selected group's members (they stay unselected but are moved)
    var selected_for_move: Array[GraphElement] = get_inclusive_selected_ges()
    var moved_nodes: Array[GraphElement] = []

    # Fetch the parent group of all groups because we may need to cascade upwards because moving children updates the parent group's size
    var sel_nodes_groups: Dictionary[GraphElement, GraphFrame] = get_graph_elements_cur_groups(selected_for_move, true)

    var get_all_ancestors_of: = func(base: bool, ge: GraphElement, recurse: Callable) -> Array[GraphElement]:
        if ge not in sel_nodes_groups:
            if base:
                return []
            else:
                return [ge]
        var ret: Array[GraphElement] = []
        if not base:
            ret.append(ge)
        ret.append_array(recurse.call(false, sel_nodes_groups[ge], recurse))
        return ret

    for ge in selected_for_move:
        if not ge in moved_nodes:
            moved_nodes.append(ge)
        # Parent groups count as moved nodes because they may move and change size to expand to accomodate the new arrangement or with autoshrink
        # if the nodes are being detached
        # This needs to include all ancestor groups for the same reason
        if sel_nodes_groups.has(ge):
            for ancestor in get_all_ancestors_of.call(true, ge, get_all_ancestors_of):
                if not ancestor in moved_nodes:
                    moved_nodes.append(ancestor)

    # remember positions and group sizes before breaking group membership, because autoshrink will change sizes immediately
    for ge in moved_nodes:
        moved_nodes_old_positions[ge] = ge.position_offset
        if ge is GraphFrame:
            moved_groups_old_sizes[ge as GraphFrame] = ge.size

    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Move Nodes", self)
    for ge in moved_nodes_old_positions.keys():
        undo_step.moved_ges_from[ge.name as String] = moved_nodes_old_positions[ge]
    for group in moved_groups_old_sizes:
        undo_step.resized_ges_from[group.name as String] = group.size

    # Finally, detach nodes/groups from their direct parent if the direct parent is not included in the selection
    var group_relations_to_break: Array[Dictionary] = []
    for ge in moved_nodes:
        if detach_from_groups and sel_nodes_groups.has(ge):
            var parent_group: GraphFrame = sel_nodes_groups[ge]
            if parent_group not in selected_for_move:
                group_relations_to_break.append({ "group": parent_group, "member": ge, })
    break_group_relations(group_relations_to_break, true)


func change_current_node_move_to_detach_mode() -> void:
    if cur_move_detached_nodes:
        push_warning("not changing to detach mode because already in detach mode")
        return
    if not is_moving_nodes():
        push_warning("change_current_node_move_to_detach_mode: called while not moving nodes")
        return
    cur_move_detached_nodes = true
    var selected_inclusive: Array[GraphElement] = get_inclusive_selected_ges()
    var sel_nodes_groups: Dictionary[GraphElement, GraphFrame] = get_graph_elements_cur_groups(selected_inclusive)
    
    var groups_to_reset_positions: Dictionary[GraphElement, Vector2] = {}
    var group_relations_to_break: Array[Dictionary] = []
    for moved_ge in moved_nodes_old_positions.keys():
        if moved_ge is GraphFrame and not moved_ge in selected_inclusive:
            groups_to_reset_positions[moved_ge] = moved_nodes_old_positions[moved_ge]
        if sel_nodes_groups.has(moved_ge):
            var parent_group: GraphFrame = sel_nodes_groups[moved_ge]
            if parent_group not in selected_inclusive:
                group_relations_to_break.append({ "group": parent_group, "member": moved_ge, })
    break_group_relations(group_relations_to_break, true)
    
    # reset the positions and sizes of any groups that had been moved and resized by the current move to what they were before
    _set_offsets_and_group_sizes(groups_to_reset_positions, moved_groups_old_sizes)

## Do not use this, currently broken
func cancel_current_node_move() -> void:
    # TODO: Vanilla GraphEdit doesn't allow cancelling the current move, in order for this to actually work
    # we might need to prevent vanilla movement entirely and re-implement it inclusing all the snapping behavior etc
    # look into cheating by releasing focus to see if that works
    _set_offsets_and_group_sizes(moved_nodes_old_positions, moved_groups_old_sizes)
    cur_move_detached_nodes = false
    moved_nodes_old_positions.clear()
    moved_groups_old_sizes.clear()

## Return true if currently dragging nodes around with the mouse
func is_moving_nodes() -> bool:
    return moved_nodes_old_positions.size() > 0

func get_graph_elements_cur_groups(ges: Array[GraphElement], include_all_groups: bool = false) -> Dictionary[GraphElement, GraphFrame]:
    if include_all_groups:
        ges = ges.duplicate()
        Util.append_array_unique(ges, get_all_groups())
    var ges_to_groups: Dictionary[GraphElement, GraphFrame] = {}
    for ge in ges:
        var group_of_ge: GraphFrame = get_element_frame(ge.name)
        if group_of_ge:
            ges_to_groups[ge] = group_of_ge
    return ges_to_groups

## Get all member relations of the provided graph elements, including both groups the ges are members of, and the members of groups in the ge list
func get_graph_elements_cur_group_relations(ges: Array[GraphElement]) -> Array[Dictionary]:
    var group_relations: Array[Dictionary] = []
    var the_groups: Array[GraphFrame] = Util.engine_class_filtered(ges, &"GraphFrame")
    group_relations.append_array(get_groups_cur_relations(the_groups))

    var cur_groups_of_ges: = get_graph_elements_cur_groups(ges)
    for ge in cur_groups_of_ges.keys():
        if cur_groups_of_ges[ge] in the_groups:
            # already added by adding all group relations above
            continue
        group_relations.append({ "group": cur_groups_of_ges[ge], "member": ge })
    return group_relations

func get_groups_cur_relations(groups: Array[GraphFrame]) -> Array[Dictionary]:
    var group_relations: Array[Dictionary] = []
    for group in groups:
        for group_member_name in get_attached_nodes_of_frame(group.name):
            var member: = get_node(NodePath(group_member_name)) as GraphElement
            if member:
                group_relations.append({ "group": group, "member": member })
    return group_relations

func on_end_node_move() -> void:
    _end_node_move_deferred.call_deferred(get_selected_ges())

func _end_node_move_deferred(moved_ges: Array[GraphElement]) -> void:
    if moved_ges.size() == 1 and moved_ges[0] is CustomGraphNode:
        var gn_rect: = moved_ges[0].get_global_rect().grow(-8).abs()
        var candidate_conns: = get_connections_intersecting_with_rect(gn_rect)
        if try_splicing_graph_node_into_connections(moved_ges[0], candidate_conns):
            return

    #editor.sort_an_connected_for_moved_gns(moved_ges)
    if not editor.undo_manager.is_creating_undo_step():
        push_error("Node move ended, but there wasn't an active undo step to commit")
    else:
        # Commit the undo step we started when first dragging nodes
        editor.undo_manager.commit_current_undo_step()
    
    moved_nodes_old_positions.clear()
    moved_groups_old_sizes.clear()
    cur_move_detached_nodes = false

func try_splicing_graph_node_into_connections(insert_gn: CustomGraphNode, candidate_conns: Array[Dictionary]) -> bool:
    if insert_gn.num_outputs == 0:
        return false

    var insert_out_type: String = insert_gn.get_output_value_type()
    set_conn_infos_types(candidate_conns)
    
    var in_types: = insert_gn.get_input_value_type_list()
    for in_idx in in_types.size():
        # assume any unknown input types match the output for maximum possible functionality
        if in_types[in_idx] == "" or in_types[in_idx] == "Unknown":
            in_types[in_idx] = insert_out_type
    # if the node has no inputs, or a known output type which isn't in it's inputs, skip checking for valid in-connections
    var no_inputs: bool = in_types.size() == 0 or (insert_out_type != "" and in_types.find(insert_out_type) == -1)
    
    # Try to pick the best option to splice the node into from the candidates
    var chosen_conn_info: = {}
    for conn_info in candidate_conns:
        if conn_info["to_node"] == insert_gn.name or conn_info["from_node"] == insert_gn.name:
            continue
        var out_valid: bool = Util.str_empty_or_match(insert_out_type, conn_info["value_type"])
        if no_inputs:
            if out_valid:
                # Pick the first possible connection, even if not fully validated
                if not chosen_conn_info:
                    chosen_conn_info = conn_info
                # If the types fully validate, ignore previously picked non-fully-validated connection and use this one
                if insert_out_type == "" or conn_info["value_type"] == insert_out_type:
                    chosen_conn_info = conn_info
                    break
            continue
        
        var in_idx: = in_types.find(conn_info["value_type"])
        var in_valid: bool = conn_info["value_type"] == "" or in_idx >= 0
        if out_valid and in_valid:
            # Pick the first possible connection, even if not fully validated
            if not chosen_conn_info:
                chosen_conn_info = conn_info
            # If the types fully validate, ignore previously picked non-fully-validated connection and use this one
            if insert_out_type == "" or (in_idx >= 0 and conn_info["value_type"] == insert_out_type):
                chosen_conn_info = conn_info
                break
    
    if chosen_conn_info:
        editor.splice_graph_node_into_connection(self, insert_gn, chosen_conn_info)
        return true
    return false

    
func get_conn_info_value_type(conn_info: Dictionary) -> String:
    var to_gn: = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
    if not to_gn:
        push_error("get_conn_info_value_type: to node %s not found or is not CustomGraphNode" % conn_info["to_node"])
    return to_gn.get_output_value_type()

func _set_ges_offsets(new_positions: Dictionary[GraphElement, Vector2]) -> void:
    for ge in new_positions.keys():
        ge.position_offset = new_positions[ge]

func _set_offsets_and_group_sizes(ge_positions: Dictionary[GraphElement, Vector2], group_sizes: Dictionary[GraphFrame, Vector2]) -> void:
    _set_ges_offsets(ge_positions)
    #var sorted_for_resize: = _sort_groups_by_heirarchy_reversed(group_sizes.keys())
    for group: GraphFrame in group_sizes.keys():
        if group not in ge_positions:
            continue
        group.position = ge_positions[group as GraphElement]
        group.size = group_sizes[group]
    for group: GraphFrame in group_sizes.keys():
        # This forces the native graph edit code to resize the graph frame inclusing covering group members and autoshrikning if enabled
        # it will still do this without emitting the signal but it will blink out of existence for a frame
        group.autoshrink_changed.emit(group.size)

func undo_redo_set_offsets_and_sizes(move_names: Dictionary[String, Vector2], resize_names: Dictionary[String, Vector2]) -> void:
    var move_ges: Dictionary[GraphElement, Vector2] = {}
    for ge_name in move_names.keys():
        var ge: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if ge:
            move_ges[ge] = move_names[ge_name]
    _set_ges_offsets(move_ges)
    for ge_name in resize_names.keys():
        var ge: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if ge:
            ge.size = resize_names[ge_name]
            if ge is GraphFrame:
                ge.autoshrink_changed.emit(ge.size)

func _sort_groups_by_heirarchy_reversed(group_list: Array) -> Array[GraphFrame]:
    var group_to_parent: = get_graph_elements_cur_groups(Array(group_list, TYPE_OBJECT, &"GraphElement", null))
    
    var safety = 100000
    var unsorted: = group_list.duplicate()
    var sorted_groups: Array[GraphFrame] = []
    while unsorted.size() > 0 and safety > 0:
        for group in unsorted.duplicate():
            if not group_to_parent.has(group) or group_to_parent[group] not in unsorted:
                sorted_groups.push_front(group)
                unsorted.erase(group)
        safety -= 1
    return sorted_groups

func _break_group_relations(group_relations: Array[Dictionary]) -> void:
    for group_relation in group_relations:
        _break_group_relation(group_relation)

func _break_named_group_relations(named_group_relations: Array[Dictionary]) -> void:
    for named_relation in named_group_relations:
        var the_group: = get_node_or_null(NodePath(named_relation["group"])) as GraphFrame
        var the_member: = get_node_or_null(NodePath(named_relation["member"])) as GraphElement
        if not the_group or not the_member:
            continue
        _break_group_relation({
            "group": get_node(NodePath(named_relation["group"])),
            "member": get_node(NodePath(named_relation["member"])),
        })

func break_group_relations(group_relations: Array[Dictionary], immediate: bool = false) -> void:
    if group_relations.size() == 0:
        return
    prints("breaking %d group relations" % group_relations.size(), "immediate: %s" % immediate)
    if immediate:
        _break_group_relations(group_relations)
    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Remove Nodes From Groups", self)
    undo_step.remove_group_relations(group_relations)
    editor.undo_manager.commit_if_new()

func remove_ge_from_group(ge: GraphElement, group: GraphFrame, immediate: bool) -> void:
    var group_relation: = {"group": group, "member": ge}
    if immediate:
        _break_group_relation(group_relation)

    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Remove Node From Group", self)
    undo_step.remove_group_relations([group_relation])
    editor.undo_manager.commit_if_new()

func _break_group_relation(group_relation: Dictionary) -> void:
    var group: = group_relation["group"] as GraphFrame
    var member_graph_element: = group_relation["member"] as GraphElement
    var member_group: GraphFrame = get_element_frame(member_graph_element.name)
    if member_group == group:
        detach_graph_element_from_frame(member_graph_element.name)
        if member_graph_element is CustomGraphNode:
            _set_ge_in_group(member_graph_element, null)

func add_group_relations(group_relations: Array[Dictionary], immediate: bool = false) -> void:
    if immediate:
        _assign_group_relations(group_relations)

    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Add Nodes To Groups", self)
    undo_step.add_group_relations(group_relations)
    editor.undo_manager.commit_if_new()

func _assign_group_relations(group_relations: Array[Dictionary]) -> void:
    for group_relation in group_relations:
        _assign_group_relation(group_relation)

func _assign_named_group_relations(named_group_relations: Array[Dictionary]) -> void:
    for named_relation in named_group_relations:
        _assign_group_relation({
            "group": get_node(NodePath(named_relation["group"])),
            "member": get_node(NodePath(named_relation["member"])),
        })

func add_ge_to_group(ge: GraphElement, group: GraphFrame, with_undo: bool) -> void:
    var group_relation: = {"group": group, "member": ge}
    _assign_group_relation(group_relation)
    if with_undo:
        var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Add Node To Group", self)
        undo_step.remove_group_relations([group_relation])
        editor.undo_manager.commit_if_new()

func add_ges_to_group(ges: Array[GraphElement], group: GraphFrame) -> void:
    var ge_names: Array = []
    for ge in ges:
        ge_names.append(ge.name)
    _attach_ge_names_to_group(ge_names, group.name)

func _attach_ge_names_to_group(ge_names: Array, group_name: StringName) -> void:
    var the_group: = get_node(NodePath(group_name)) as GraphFrame
    for ge_name in ge_names:
        attach_graph_element_to_frame(ge_name, group_name)
        var ge: = get_node(NodePath(ge_name)) as GraphElement
        if ge is CustomGraphNode:
            _set_ge_in_group(ge, the_group)

func _assign_group_relation(group_relation: Dictionary) -> void:
    var group: = group_relation["group"] as GraphFrame
    var member_graph_element: = group_relation["member"] as GraphElement
    attach_graph_element_to_frame(member_graph_element.name, group.name)
    if member_graph_element is CustomGraphNode:
        _set_ge_in_group(member_graph_element, group)

func refresh_graph_elements_in_frame_status(for_ges: Array[GraphElement] = []) -> void:
    if not for_ges:
        for_ges = get_all_ges()
    for ge in for_ges:
        if ge is CustomGraphNode:
            _set_ge_in_group(ge, get_element_frame(ge.name))

func _set_ge_in_group(ge: CustomGraphNode, in_group: GraphFrame) -> void:
    if not in_group:
        ge.update_is_in_graph_group(false)
    else:
        ge.update_is_in_graph_group(true, in_group.theme)

func undo_redo_add_ges(the_ges: Array[GraphElement]) -> void:
    for adding_ge in the_ges:
        add_graph_element_child(adding_ge)

func undo_redo_remove_ges(the_ges: Array[GraphElement]) -> void:
    for removing_ge in the_ges:
        remove_graph_element_child(removing_ge)

## When GraphElements are removed and fresh copies will be created if undone/redone again, free the current versions
func undo_redo_delete_ge_names(ge_names: Array) -> void:
    prints("undo_redo_delete_ge_names: %s" % [ge_names])
    for ge_name in ge_names:
        var ge: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if not ge:
            push_warning("undo_redo_delete_ge_names: graph element %s not found" % ge_name)
            continue
        remove_graph_element_child(ge)
        ge.queue_free()

func undo_redo_delete_fragment_ges(counter_start: int, num_ges: int) -> void:
    if editor.undo_manager.undo_redo.is_committing_action():
        return
    var ge_names: Array[String] = []
    for name_number in range(counter_start, counter_start + num_ges):
        ge_names.append("%s--%d" % ["FrGE", name_number])
    _redelete_by_names(ge_names)

## Finds GEs by name, removes and frees them, and unregisters their asset nodes
func _redelete_by_names(ge_names: Array[String]) -> void:
    if editor.undo_manager.undo_redo.is_committing_action():
        return
    var ges_to_delete: Array[GraphElement] = []
    for ge_name in ge_names:
        var ge_child: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if ge_child:
            ges_to_delete.append(ge_child)
    var included_asset_nodes: = editor.get_included_asset_nodes_for_ges(ges_to_delete)
    editor.remove_asset_nodes(included_asset_nodes)
    for ge in ges_to_delete:
        remove_graph_element_child(ge)
        ge.queue_free()
    
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
    
    var output_value_type: String = graph_node.get_output_value_type()
    if not output_value_type:
        return true
    
    var connected_connections_types: Array[String] = []
    for conn_idx in dissolve_info["in_ports_connected"]:
        var conn_name: String = graph_node.input_connection_list[conn_idx]
        var conn_type: String = graph_node.input_value_types[conn_name]
        connected_connections_types.append(conn_type)
    
    return output_value_type in connected_connections_types

func dissolve_gn_with_undo(graph_node: CustomGraphNode) -> void:
    editor.undo_manager.start_or_continue_undo_step("Dissolve Nodes")
    var is_new_step: = editor.undo_manager.is_new_step
    
    var all_conn_infos: Array[Dictionary] = raw_connections(graph_node)
    set_conn_infos_types(all_conn_infos)
    
    var out_conn_infos: Array[Dictionary] = Util.out_connections(all_conn_infos, graph_node.name)
    if out_conn_infos.size() > 0:
        var in_conn_infos: Array[Dictionary] = Util.in_connections(all_conn_infos, graph_node.name)
        var recovered_connections: = get_recovered_connections_for_dissolve(out_conn_infos[0], in_conn_infos)
        editor.connect_graph_nodes(recovered_connections, self)

    # Also queues removing existing connections
    editor.delete_graph_elements([graph_node], self)

    if is_new_step:
        editor.undo_manager.commit_current_undo_step()

func get_recovered_connections_for_dissolve(old_out_conn_info: Dictionary, old_in_conn_infos: Array[Dictionary]) -> Array[Dictionary]:
    var template_conn_info: = old_out_conn_info.duplicate()
    template_conn_info.erase("to_node")
    template_conn_info.erase("to_port")

    var recovered_connections: Array[Dictionary] = []
    for old_in_conn in old_in_conn_infos:
        if not Util.str_empty_or_match(old_in_conn["value_type"], template_conn_info["value_type"]):
            continue
        recovered_connections.append(template_conn_info.merged(old_in_conn))
    return recovered_connections


func cut_all_connections_with_undo(graph_node: CustomGraphNode) -> void:
    var all_connections: Array[Dictionary] = raw_connections(graph_node)
    remove_multiple_connections(all_connections)

func _on_graph_node_right_clicked(graph_node: CustomGraphNode) -> void:
    if connection_cut_active:
        return
    if not graph_node.selectable:
        return
    ready_context_menu_for(graph_node)

func ready_context_menu_for(for_node: Node) -> void:
    context_menu_movement_acc = 24
    context_menu_target_node = for_node
    context_menu_ready = true

func _on_graph_node_titlebar_double_clicked(graph_node: CustomGraphNode) -> void:
    select_subtree(graph_node, ANESettings.select_subtree_is_greedy)

## Select all nodes connected to the input side of this graph node
## If greedy = false (default) will only select groups if all of it's members were also selected
## If greedy = true will select any group that contains at least one of the nodes in the subtree and will also select all nodes in that group
## Never selects outer groups of the group the root node is in,
## the group the root node is in is only selected if all of it's members (inclusive) are selected even if greedy is true
func select_subtree(root_gn: CustomGraphNode, greedy: bool = false) -> void:
    deselect_all()
    var subtree_gns: Array[CustomGraphNode] = get_subtree_gns(root_gn)
    select_gns(subtree_gns)
    
    # Select any groups that you've selected all the members of
    var all_groups: = get_all_groups()
    var group_of_tree_root: GraphFrame = get_element_frame(root_gn.name)
    for group in all_groups:
        var inclusive_group_members: Array[GraphElement] = get_recursive_group_members(group)
        if inclusive_group_members.size() == 0:
            continue
        var is_outer_group_of_root: bool = false
        for member in inclusive_group_members:
            if member == group_of_tree_root:
                is_outer_group_of_root = true
                break
        if is_outer_group_of_root:
            continue

        var all_selected: bool = true
        var any_selected: bool = false
        for member in inclusive_group_members:
            if member is GraphFrame:
                continue
            if not member.selected:
                all_selected = false
                if not greedy:
                    break
            else:
                any_selected = true
        if group == group_of_tree_root:
            if all_selected:
                group.selected = true
        else:
            if (greedy and any_selected) or (not greedy and all_selected):
                group.selected = true
    
    if greedy:
        for selected_group in get_selected_groups():
            var inclusive_selected_members: Array[GraphElement] = get_recursive_group_members(selected_group)
            for member in inclusive_selected_members:
                if not member.selected:
                    member.selected = true

func get_subtree_gns(graph_node: CustomGraphNode) -> Array[CustomGraphNode]:
    var subtree_gns: Array[CustomGraphNode] = [graph_node]
    var in_connections: Array[Dictionary] = raw_in_connections(graph_node)
    var safety: int = 100000
    while in_connections.size() > 0:
        var old_conns: = in_connections.duplicate()
        in_connections.clear()
        for conn_info in old_conns:
            var subtree_gn: = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
            if not subtree_gn or subtree_gns.has(subtree_gn):
                continue
            subtree_gns.append(subtree_gn)
            in_connections.append_array(raw_in_connections(subtree_gn))
        
        safety -= 1
        if safety <= 0:
            push_error("get_subtree_gns: Safety limit reached, aborting")
            break
    return subtree_gns


func cancel_context_menu() -> void:
    reset_context_menu_target()

func reset_context_menu_target() -> void:
    context_menu_target_node = null
    context_menu_ready = false

func actually_right_click_gn(graph_node: CustomGraphNode) -> void:
    reset_context_menu_target()
    if not graph_node.selected:
        deselect_all()
        set_selected(graph_node)
    
    var is_asset_node: bool = graph_node.get_meta("hy_asset_node_id", "") != ""

    var context_menu: PopupMenu = PopupMenu.new()
    context_menu.id_pressed.connect(on_node_context_menu_id_pressed.bind(graph_node))

    context_menu.name = "NodeContextMenu"
    
    context_menu.add_item("Edit Title", CHANE_AssetNodeEditor.ContextMenuItems.EDIT_TITLE)
    context_menu.add_separator()
    
    set_context_menu_common_options(context_menu)
    
    if is_asset_node:
        context_menu.add_item("Dissolve Node", CHANE_AssetNodeEditor.ContextMenuItems.DISSOLVE_NODES)
        if not can_dissolve_gn(graph_node):
            var dissolve_idx: int = context_menu.get_item_index(CHANE_AssetNodeEditor.ContextMenuItems.DISSOLVE_NODES)
            context_menu.set_item_disabled(dissolve_idx, true)
        
        context_menu.add_item("Cut All Connections", CHANE_AssetNodeEditor.ContextMenuItems.BREAK_CONNECTIONS)
    
    context_menu.add_separator()
    set_context_menu_select_options(context_menu, true, false)

    add_child(context_menu, true)

    context_menu.position = get_popup_pos_at_mouse()
    context_menu_pos_offset = get_mouse_pos_offset()
    context_menu.popup()

func actually_right_click_group(group: GraphFrame) -> void:
    reset_context_menu_target()
    if not group.selected:
        deselect_all()
        group.selected = true
    var context_menu: PopupMenu = PopupMenu.new()
    context_menu.id_pressed.connect(on_node_context_menu_id_pressed.bind(group))
    context_menu.name = "GroupContextMenu"
    
    context_menu.add_item("Edit Group Title", CHANE_AssetNodeEditor.ContextMenuItems.EDIT_GROUP_TITLE)
    var change_group_color_submenu: PopupMenu = get_color_name_menu()
    change_group_color_submenu.index_pressed.connect(on_change_group_color_name_index_pressed.bind(change_group_color_submenu, group))
    context_menu.add_submenu_node_item("Change Group Accent Color", change_group_color_submenu, CHANE_AssetNodeEditor.ContextMenuItems.CHANGE_GROUP_COLOR)

    context_menu.add_separator()
    
    set_context_menu_new_node_options(context_menu)
    var new_group_idx: int = context_menu.get_item_index(CHANE_AssetNodeEditor.ContextMenuItems.CREATE_NEW_GROUP)
    context_menu.set_item_text(new_group_idx, "Create New Inner Group")
    context_menu.add_separator()
    
    set_context_menu_common_options(context_menu)
    
    context_menu.add_separator()
    set_context_menu_select_options(context_menu, false, true)
    
    var multiple_groups_selected: bool = get_selected_groups().size() > 1
    if not multiple_groups_selected:
        var is_shrinkwrap_enabled: bool = group.autoshrink_enabled
        if is_shrinkwrap_enabled:
            context_menu.add_item("Disable Shrinkwrap", CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_NO_SHRINKWRAP)
        else:
            context_menu.add_item("Enable Shrinkwrap", CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_SHRINKWRAP)
    else:
        context_menu.add_item("Enable Shrinkwrap for Selected Groups", CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_SHRINKWRAP)
        context_menu.add_item("Disable Shrinkwrap for Selected Groups", CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_NO_SHRINKWRAP)
    
    add_child(context_menu, true)
    
    context_menu.position = get_popup_pos_at_mouse()
    context_menu_pos_offset = get_mouse_pos_offset()
    context_menu.popup()

func actually_right_click_nothing() -> void:
    reset_context_menu_target()
    var context_menu: PopupMenu = PopupMenu.new()
    context_menu.id_pressed.connect(on_node_context_menu_id_pressed.bind(null))
    context_menu.name = "NothingContextMenu"
    
    if not editor.is_loaded:
        context_menu.add_item("New File", CHANE_AssetNodeEditor.ContextMenuItems.NEW_FILE)
        return
    
    set_context_menu_new_node_options(context_menu)
    context_menu.add_separator()
    
    var paste_plural_s: = "s" if editor.current_copied_fragment_has_multiple() else ""
    context_menu.add_item("Paste Nodes" + paste_plural_s, CHANE_AssetNodeEditor.ContextMenuItems.PASTE_NODES)
    if not editor.check_if_can_paste():
        var paste_idx: int = context_menu.get_item_index(CHANE_AssetNodeEditor.ContextMenuItems.PASTE_NODES)
        context_menu.set_item_disabled(paste_idx, true)
    
    add_child(context_menu, true)
    
    context_menu.add_separator()
    set_context_menu_select_options(context_menu, false, false)
    
    context_menu.position = get_popup_pos_at_mouse()
    context_menu_pos_offset = get_mouse_pos_offset()
    context_menu.popup()

func set_context_menu_common_options(context_menu: PopupMenu) -> void:
    var selected_nodes: Array[GraphElement] = get_selected_ges()

    var multiple_selected: bool = selected_nodes.size() > 1
    
    var num_selected_groups: int = get_selected_groups().size()
    var plural_s: = "s" if multiple_selected else ""

    context_menu.add_item("Copy Node" + plural_s, CHANE_AssetNodeEditor.ContextMenuItems.COPY_NODES)
    context_menu.add_item("Cut Node" + plural_s, CHANE_AssetNodeEditor.ContextMenuItems.CUT_NODES)

    
    var paste_plural_s: = "s" if editor.current_copied_fragment_has_multiple() else ""
    context_menu.add_item("Paste Node" + paste_plural_s, CHANE_AssetNodeEditor.ContextMenuItems.PASTE_NODES)
    if not editor.check_if_can_paste():
        var paste_idx: int = context_menu.get_item_index(CHANE_AssetNodeEditor.ContextMenuItems.PASTE_NODES)
        context_menu.set_item_disabled(paste_idx, true)

    context_menu.add_item("Delete Node" + plural_s, CHANE_AssetNodeEditor.ContextMenuItems.DELETE_NODES)
    if not multiple_selected and not can_delete_ge(selected_nodes[0]):
        var delete_idx: int = context_menu.get_item_index(CHANE_AssetNodeEditor.ContextMenuItems.DELETE_NODES)
        context_menu.set_item_disabled(delete_idx, true)
    
    if num_selected_groups > 0:
        context_menu.add_item("Delete Nodes (Including All Inside Selected Groups)", CHANE_AssetNodeEditor.ContextMenuItems.DELETE_NODES_DEEP)
        context_menu.add_item("Remove Selected Groups (Keeping Nodes Inside)", CHANE_AssetNodeEditor.ContextMenuItems.DELETE_GROUPS_ONLY)
    
    context_menu.add_item("Duplicate Node" + plural_s, CHANE_AssetNodeEditor.ContextMenuItems.DUPLICATE_NODES)

func set_context_menu_select_options(context_menu: PopupMenu, over_graph_node: bool, over_group: bool) -> void:
    context_menu.add_item("Select All", CHANE_AssetNodeEditor.ContextMenuItems.SELECT_ALL)
    context_menu.add_item("Deselect All", CHANE_AssetNodeEditor.ContextMenuItems.DESELECT_ALL)
    context_menu.add_item("Invert Selection", CHANE_AssetNodeEditor.ContextMenuItems.INVERT_SELECTION)
    
    if over_graph_node:
        context_menu.add_item("Select Subtree", CHANE_AssetNodeEditor.ContextMenuItems.SELECT_SUBTREE)
        context_menu.add_item("Select Subtree (Greedy)", CHANE_AssetNodeEditor.ContextMenuItems.SELECT_SUBTREE_GREEDY)
    
    var num_selected_groups: int = get_selected_groups().size()
    if num_selected_groups > 0:
        if over_group:
            context_menu.add_item("Select All Nodes In This Group", CHANE_AssetNodeEditor.ContextMenuItems.SELECT_GROUP_NODES)
        if not over_group or num_selected_groups > 1:
            context_menu.add_item("Select All Nodes In Selected Groups", CHANE_AssetNodeEditor.ContextMenuItems.SELECT_GROUPS_NODES)

func set_context_menu_new_node_options(context_menu: PopupMenu) -> void:
    context_menu.add_item("Create New Node", CHANE_AssetNodeEditor.ContextMenuItems.CREATE_NEW_NODE)
    context_menu.add_item("Create New Group", CHANE_AssetNodeEditor.ContextMenuItems.CREATE_NEW_GROUP)

func on_node_context_menu_id_pressed(node_context_menu_id: CHANE_AssetNodeEditor.ContextMenuItems, on_ge: GraphElement) -> void:
    var is_graph_node: bool = on_ge and on_ge is CustomGraphNode
    var is_group: bool = on_ge and on_ge is GraphFrame

    match node_context_menu_id:
        CHANE_AssetNodeEditor.ContextMenuItems.COPY_NODES:
            _copy_request()
        CHANE_AssetNodeEditor.ContextMenuItems.CUT_NODES:
            _cut_request()
        CHANE_AssetNodeEditor.ContextMenuItems.CUT_NODES_DEEP:
            cut_selected_nodes_inclusive()
        CHANE_AssetNodeEditor.ContextMenuItems.PASTE_NODES:
            paste_copied_fragment_at(context_menu_pos_offset)
        CHANE_AssetNodeEditor.ContextMenuItems.DELETE_NODES:
            delete_ges(get_selected_ges())
        CHANE_AssetNodeEditor.ContextMenuItems.DELETE_NODES_DEEP:
            delete_selected_nodes_inclusive()
        CHANE_AssetNodeEditor.ContextMenuItems.DELETE_GROUPS_ONLY:
            var selected_groups: = get_selected_groups()
            remove_groups_only_with_undo(selected_groups)
        CHANE_AssetNodeEditor.ContextMenuItems.DISSOLVE_NODES:
            if is_graph_node:
                dissolve_gn_with_undo(on_ge)
        CHANE_AssetNodeEditor.ContextMenuItems.BREAK_CONNECTIONS:
            if is_graph_node:
                cut_all_connections_with_undo(on_ge)
        CHANE_AssetNodeEditor.ContextMenuItems.DUPLICATE_NODES:
            duplicate_selected_ges()
        
        CHANE_AssetNodeEditor.ContextMenuItems.EDIT_TITLE:
            if is_graph_node:
                open_gn_title_edit(on_ge)
        CHANE_AssetNodeEditor.ContextMenuItems.EDIT_GROUP_TITLE:
            if is_group:
                open_group_title_edit(on_ge)
        
        CHANE_AssetNodeEditor.ContextMenuItems.SELECT_SUBTREE:
            if is_graph_node:
                select_subtree(on_ge, false)
        CHANE_AssetNodeEditor.ContextMenuItems.SELECT_SUBTREE_GREEDY:
            if is_graph_node:
                select_subtree(on_ge, true)
        CHANE_AssetNodeEditor.ContextMenuItems.SELECT_GROUP_NODES:
            if is_group:
                deselect_all()
                select_nodes_in_group(on_ge)
        CHANE_AssetNodeEditor.ContextMenuItems.SELECT_GROUPS_NODES:
            var selected_groups: Array[GraphFrame] = get_selected_groups()
            deselect_all()
            for group in selected_groups:
                select_nodes_in_group(group)
        CHANE_AssetNodeEditor.ContextMenuItems.SELECT_ALL:
            select_all()
        CHANE_AssetNodeEditor.ContextMenuItems.DESELECT_ALL:
            deselect_all()
        CHANE_AssetNodeEditor.ContextMenuItems.INVERT_SELECTION:
            invert_selection()
        
        CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_SHRINKWRAP:
            var selected_groups: Array[GraphFrame] = get_selected_groups()
            set_groups_shrinkwrap_with_undo(selected_groups, true)
        CHANE_AssetNodeEditor.ContextMenuItems.SET_GROUP_NO_SHRINKWRAP:
            var selected_groups: Array[GraphFrame] = get_selected_groups()
            set_groups_shrinkwrap_with_undo(selected_groups, false)
        CHANE_AssetNodeEditor.ContextMenuItems.CREATE_NEW_NODE:
            var into_group: = on_ge if is_group else null
            editor.show_new_node_menu_for_pos(context_menu_pos_offset, self, into_group)
        CHANE_AssetNodeEditor.ContextMenuItems.CREATE_NEW_GROUP:
            var into_group: = on_ge if is_group else null
            add_new_group_pending_title_undo_step(context_menu_pos_offset, into_group)
        
        CHANE_AssetNodeEditor.ContextMenuItems.NEW_FILE:
            popup_menu_root.show_new_file_type_chooser()

func on_change_group_color_name_index_pressed(index: int, color_name_menu: PopupMenu, group: GraphFrame) -> void:
    var color_name: String = color_name_menu.get_item_text(index)
    if not ThemeColorVariants.has_theme_color(color_name):
        return
    set_group_color_with_undo(group, color_name)

func get_title_edit_popup(current_title: String) -> PopupPanel:
    var title_edit_popup: = preload("res://ui/node_title_edit_popup.tscn").instantiate() as PopupPanel
    title_edit_popup.current_title = current_title
    return title_edit_popup

func open_gn_title_edit(graph_node: CustomGraphNode) -> PopupPanel:
    var title_edit_popup = get_title_edit_popup(graph_node.title)
    title_edit_popup.new_title_submitted.connect(change_ge_title_to.bind(graph_node))
    add_child(title_edit_popup, true)
    title_edit_popup.position = Util.get_popup_window_pos(graph_node.get_global_position())
    title_edit_popup.position -= Vector2i.ONE * 10
    show_exclusive_clamped_popup(title_edit_popup)
    return title_edit_popup

func open_group_title_edit(group: GraphFrame) -> PopupPanel:
    var title_edit_popup = get_title_edit_popup(group.title)
    title_edit_popup.new_title_submitted.connect(change_ge_title_to.bind(group))
    add_child(title_edit_popup, true)
    var group_title_rect: = group.get_titlebar_hbox().get_global_rect()
    var group_title_center: = Vector2(group_title_rect.get_center().x, group_title_rect.position.y)
    title_edit_popup.position = Util.get_popup_window_pos(group_title_center)
    title_edit_popup.position.x -= (title_edit_popup.size / 2.0).x
    show_exclusive_clamped_popup(title_edit_popup)
    return title_edit_popup

func show_exclusive_clamped_popup(the_popup: PopupPanel) -> void:
    the_popup.position = clamp_window_pos_for_popup(the_popup.position, the_popup.size)
    the_popup.exclusive = true
    the_popup.popup()

func clamp_window_pos_for_popup(window_pos: Vector2i, popup_size: Vector2) -> Vector2i:
    return Util.clamp_popup_pos_inside_window(window_pos, popup_size, get_window())

func _set_ge_titles(name_titles: Dictionary[String, String]) -> void:
    for ge_name in name_titles.keys():
        var ge: = get_node_or_null(NodePath(ge_name)) as GraphElement
        if not ge or not "title" in ge:
            continue
        if ge is GraphFrame:
            _set_group_title(ge, name_titles[ge_name])
        elif ge is CustomGraphNode:
            editor._set_gn_title(ge, name_titles[ge_name])
        else:
            ge.title = name_titles[ge_name]

func _set_group_title(group: GraphFrame, new_title: String) -> void:
    group.title = new_title
    group.tooltip_text = new_title

func change_ge_title_to(new_title: String, graph_element: GraphElement) -> void:
    if not "title" in graph_element:
        return
    var action_name: String = "Change Group Title" if graph_element is GraphFrame else "Change Node Title"
    var graph_undo_step: = editor.undo_manager.start_or_continue_graph_undo_step(action_name, self)
    graph_undo_step.ge_titles_from[graph_element.name as String] = graph_element.title
    graph_undo_step.ge_titles_to[graph_element.name as String] = new_title
    editor.undo_manager.commit_if_new()

func raw_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    assert(is_same(graph_node.get_parent(), self), "raw_connections: Graph node %s is not a direct child of the graph edit" % graph_node.name)

    # Workaround to avoid erronious error from trying to get connection list of nodes whose connections have never been touched yet
    # this triggers the connection_map having an entry for this node name
    is_node_connected(graph_node.name, 0, graph_node.name, 0)

    return get_connection_list_from_node(graph_node.name)

func raw_in_port_connections(graph_node: CustomGraphNode, at_port: int) -> Array[Dictionary]:
    return Util.in_connections(raw_connections(graph_node), graph_node.name, at_port)

func raw_out_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    return Util.out_connections(raw_connections(graph_node), graph_node.name)

func raw_in_connections(graph_node: CustomGraphNode) -> Array[Dictionary]:
    return Util.in_connections(raw_connections(graph_node), graph_node.name)

func set_conn_info_type(conn_info: Dictionary) -> void:
    conn_info["value_type"] = get_type_of_conn_info(conn_info)

func set_conn_infos_types(conn_infos: Array[Dictionary]) -> void:
    for conn_info in conn_infos:
        conn_info["value_type"] = get_type_of_conn_info(conn_info)

func typed_conn_infos_for_gn(graph_node: CustomGraphNode) -> Array[Dictionary]:
    var conn_infos: = raw_connections(graph_node)
    for i in conn_infos.size():
        conn_infos[i]["value_type"] = get_type_of_conn_info(conn_infos[i])
    return conn_infos

func can_delete_gn(graph_node: CustomGraphNode) -> bool:
    if graph_node == editor.root_graph_node:
        return false
    return true

func can_delete_ge(graph_element: GraphElement) -> bool:
    if graph_element is CustomGraphNode:
        return can_delete_gn(graph_element)
    elif graph_element is GraphFrame:
        return true
    return false

func _get_deserialized_group(group_data: Dictionary, use_json_pos_scale: bool, relative_to_screen_center: bool) -> GraphFrame:
    editor.serializer.serialized_pos_scale = editor.json_positions_scale if use_json_pos_scale else Vector2.ONE
    editor.serializer.serialized_pos_offset = Vector2.ZERO
    if relative_to_screen_center:
        editor.serializer.serialized_pos_offset = local_pos_to_pos_offset(get_viewport().get_visible_rect().size / 2)
    return editor.serializer.deserialize_group(group_data)
            
func deserialize_and_add_group(group_data: Dictionary, use_json_pos_scale: bool, relative_to_screen_center: bool) -> GraphFrame:
    var new_group: = _get_deserialized_group(group_data, use_json_pos_scale, relative_to_screen_center)
    _set_group_shrinkwrap(new_group, ANESettings.default_is_group_shrinkwrap)
    add_group_child(new_group)
    return new_group

func get_default_group_color_name() -> String:
    if ThemeColorVariants.has_theme_color(ANESettings.default_group_color):
        return ANESettings.default_group_color
    return TypeColors.fallback_color

func set_group_color_with_undo(group: GraphFrame, new_color_name: String) -> void:
    var graph_undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Change Group Accent Color", self)
    var from_color_name: String = group.get_meta("custom_color_name", "")
    if not group.get_meta("has_custom_color", false):
        from_color_name = ""
    graph_undo_step.group_accent_colors_from[group.name as String] = from_color_name
    graph_undo_step.group_accent_colors_to[group.name as String] = new_color_name
    editor.undo_manager.commit_if_new()

func _set_groups_accent_colors(name_colors: Dictionary[String, String]) -> void:
    for group_name in name_colors.keys():
        var group: = get_node_or_null(NodePath(group_name)) as GraphFrame
        if not group:
            continue
        var accent_color_name: String = name_colors[group_name]
        if accent_color_name == "":
            remove_group_accent_color(group)
        else:
            set_group_custom_accent_color(group, accent_color_name)

func set_group_custom_accent_color(the_group: GraphFrame, group_color_name: String, as_custom: bool = true) -> void:
    if not as_custom:
        remove_group_accent_color(the_group)
        return
    if not group_color_name or not ThemeColorVariants.has_theme_color(group_color_name):
        group_color_name = get_default_group_color_name()

    the_group.set_meta("has_custom_color", true)
    the_group.set_meta("custom_color_name", group_color_name)
    the_group.theme = ThemeColorVariants.get_theme_color_variant(group_color_name)

func remove_group_accent_color(group: GraphFrame) -> void:
    group.set_meta("has_custom_color", false)
    group.set_meta("custom_color_name", "")
    group.theme = ThemeColorVariants.get_theme_color_variant(get_default_group_color_name())

func _make_new_group(group_title: String = "Group", group_size: Vector2 = Vector2(100, 100)) -> GraphFrame:
    var new_group: = GraphFrame.new()
    new_group.name = editor.graph_node_factory.new_graph_node_name("Group")
    _set_group_shrinkwrap(new_group, ANESettings.default_is_group_shrinkwrap)
    new_group.size = group_size
    _set_group_title(new_group, group_title)
    
    return new_group

func add_new_group(at_pos_offset: Vector2, with_title: String = "Group", with_size: Vector2 = Vector2.ZERO) -> GraphFrame:
    if with_size == Vector2.ZERO:
        with_size = ANESettings.default_group_size
    var new_group: = _make_new_group(with_title, with_size)

    add_graph_element_child(new_group)
    new_group.position_offset = at_pos_offset
    new_group.set_meta("has_custom_color", false)
    new_group.theme = ThemeColorVariants.get_theme_color_variant(ANESettings.default_group_color)
    new_group.raise_request.emit()
    return new_group

func add_new_colored_group(with_color: String, at_pos_offset: Vector2, with_title: String = "Group", with_size: Vector2 = Vector2.ZERO) -> GraphFrame:
    var new_group: = add_new_group(at_pos_offset, with_title, with_size)
    
    set_group_custom_accent_color(new_group, with_color)
    return new_group

func add_new_group_title_centered(at_pos_offset: Vector2) -> GraphFrame:
    var new_group_size: = ANESettings.default_group_size
    at_pos_offset.x -= new_group_size.x / 2
    at_pos_offset.y -= 6
    return add_new_group(at_pos_offset)

func add_new_group_pending_title_undo_step(at_pos_offset: Vector2, into_group: GraphFrame) -> void:
    var new_group: = add_new_group_title_centered(at_pos_offset)
    await get_tree().process_frame
    if into_group:
        # This adds the group relation to the undo action that should always be committed as soon as the edit title popup is closed
        # regardless of if the default title is changed or not
        add_ge_to_group(new_group, into_group, true)
    var title_edit_popup: = open_group_title_edit(new_group)
    title_edit_popup.tree_exiting.connect(create_new_group_with_undo.bind(new_group, into_group))

func create_new_group_with_undo(new_group: GraphFrame, into_group: GraphFrame) -> void:
    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Add New Group", self)
    undo_step.created_ge_names.append(new_group.name as String)
    if into_group:
        undo_step.add_group_relations([{ "group": into_group, "member": new_group }])
    editor.undo_manager.commit_if_new()

func set_groups_shrinkwrap_with_undo(groups: Array[GraphFrame], shrinkwrap: bool) -> void:
    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Set Group Shrinkwrap", self)
    for group in groups:
        if group.autoshrink_enabled != shrinkwrap:
            undo_step.group_shrinkwrap_from[group.name as String] = group.autoshrink_enabled
            undo_step.group_shrinkwrap_to[group.name as String] = shrinkwrap
    editor.undo_manager.commit_if_new()

func _set_group_shrinkwrap(group: GraphFrame, shrinkwrap: bool) -> void:
    group.autoshrink_enabled = shrinkwrap
    group.resizable = not group.autoshrink_enabled

func _set_groups_shrinkwrap(name_shrinkwraps: Dictionary[String, bool]) -> void:
    for group_name in name_shrinkwraps.keys():
        var group: = get_node_or_null(NodePath(group_name)) as GraphFrame
        if not group:
            continue
        _set_group_shrinkwrap(group, name_shrinkwraps[group_name])

func _link_to_group_request(graph_element_names: Array, group_name: StringName) -> void:
    if cur_move_detached_nodes:
        return
    var undo_step: = editor.undo_manager.start_or_continue_graph_undo_step("Add Nodes to Group", self)
    var the_group: = get_node(NodePath(group_name)) as GraphFrame
    for ge_name in graph_element_names:
        undo_step.add_group_relations([{ "group": the_group, "member": get_node(NodePath(ge_name)) }])
    editor.undo_manager.commit_if_new()

func bring_group_to_front(group: GraphFrame) -> void:
    group.raise_request.emit()

func get_color_name_menu() -> PopupMenu:
    var color_name_menu: PopupMenu = PopupMenu.new()
    for color_name in ThemeColorVariants.get_theme_colors():
        var theme_color: Color = ThemeColorVariants.get_theme_color(color_name)
        color_name_menu.add_icon_item(Util.get_icon_for_color(theme_color), color_name)
    return color_name_menu

func get_pos_offset_rect(graph_element: GraphElement) -> Rect2:
    return Rect2(graph_element.position_offset, graph_element.size)

func get_popup_pos_at_mouse() -> Vector2i:
    return Util.get_popup_window_pos(get_global_mouse_position())

func add_graph_element_children(graph_elements: Array[GraphElement], with_snap: bool = false) -> void:
    for graph_element in graph_elements:
        add_graph_element_child(graph_element, with_snap)

func add_graph_element_child(graph_element: GraphElement, with_snap: bool = false) -> void:
    if graph_element is CustomGraphNode:
        add_graph_node_child(graph_element, with_snap)
    elif graph_element is GraphFrame:
        add_group_child(graph_element, with_snap)
    else:
        add_child(graph_element, true)
        if with_snap:
            snap_ge(graph_element)

func add_graph_node_child(graph_node: CustomGraphNode, with_snap: bool = false) -> void:
    _top_level_graph_nodes.append(graph_node)
    add_child(graph_node, true)
    if with_snap:
        snap_ge(graph_node)

    var an_id: String = graph_node.get_meta("hy_asset_node_id", "")
    if an_id:
        editor.gn_lookup[an_id] = graph_node
    graph_node.update_port_types(type_id_lookup)
    graph_node.update_port_colors()
    graph_node.was_right_clicked.connect(_on_graph_node_right_clicked)
    graph_node.titlebar_double_clicked.connect(_on_graph_node_titlebar_double_clicked)

func add_group_child(the_group: GraphFrame, with_snap: bool = false) -> void:
    the_group.resizable = not the_group.autoshrink_enabled
    add_child(the_group, true)
    if with_snap:
        snap_ge(the_group)
    var custom_color_name: String = the_group.get_meta("custom_color_name", "")
    var has_custom_color: bool = the_group.get_meta("has_custom_color", false)
    set_group_custom_accent_color(the_group, custom_color_name, has_custom_color)
    

    bring_group_to_front(the_group)

func remove_graph_node_child(graph_node: CustomGraphNode) -> void:
    remove_child(graph_node)
    if graph_node.was_right_clicked.is_connected(_on_graph_node_right_clicked):
        graph_node.was_right_clicked.disconnect(_on_graph_node_right_clicked)
    if graph_node.titlebar_double_clicked.is_connected(_on_graph_node_titlebar_double_clicked):
        graph_node.titlebar_double_clicked.disconnect(_on_graph_node_titlebar_double_clicked)
    _top_level_graph_nodes.erase(graph_node)
    potential_top_level_graph_nodes.erase(graph_node)

func remove_graph_element_child(graph_element: GraphElement) -> void:
    if graph_element is CustomGraphNode:
        remove_graph_node_child(graph_element)
    else:
        remove_child(graph_element)

## Get's the position_offset coordinate under the mouse cursor's current position
func get_mouse_pos_offset() -> Vector2:
    return local_pos_to_pos_offset(get_local_mouse_position())

## Get's the position_offset coordinate at the center of the graph edit's current view into the graph
func get_center_pos_offset() -> Vector2:
    return local_pos_to_pos_offset(size / 2)

## Get's the position_offset coordinate that coincides with a given global (godot 2d space) position
func global_pos_to_pos_offset(the_global_pos: Vector2) -> Vector2:
    var local_pos: = get_global_transform().affine_inverse() * the_global_pos
    return local_pos_to_pos_offset(local_pos)

func local_pos_to_pos_offset(the_pos: Vector2) -> Vector2:
    return (scroll_offset + the_pos) / zoom

func position_offset_to_global_pos(the_position_offset: Vector2) -> Vector2:
    return (the_position_offset * zoom) - scroll_offset

func get_all_connections_for_graph_elements(ges: Array[GraphElement]) -> Array[Dictionary]:
    var ge_connections: Array[Dictionary] = []
    var added_gn_names: Array[String] = []
    for ge in ges:
        if not ge is CustomGraphNode:
            continue
        for conn_info in raw_connections(ge):
            if conn_info["from_node"] in added_gn_names or conn_info["to_node"] in added_gn_names:
                continue
            ge_connections.append(conn_info)
        added_gn_names.append(ge.name)
    return ge_connections

# It's easy to remove a graph node from being top level when a connection is added, but removing connections only removes the gn as top level
# if it was the last connection to it, so when we remove connections we just add the gn to this list of potential new top level gns and
# lazily calculate which ones get added once we actually need the list
func _refresh_top_level_graph_nodes() -> void:
    for graph_node in potential_top_level_graph_nodes:
        if graph_node in _top_level_graph_nodes:
            continue
        var gn_conns: = raw_out_connections(graph_node)
        if gn_conns.size() == 0:
            _top_level_graph_nodes.append(graph_node)
    potential_top_level_graph_nodes.clear()

func get_top_level_graph_nodes() -> Array[CustomGraphNode]:
    _refresh_top_level_graph_nodes()
    return _top_level_graph_nodes

func get_graph_node_subtree(graph_node: CustomGraphNode) -> Dictionary[CustomGraphNode, Array]:
    var subtree: Dictionary[CustomGraphNode, Array] = {
        graph_node: []
    }
    var in_connections: Array[Dictionary] = raw_in_connections(graph_node)
    for conn_info in in_connections:
        var to_gn: GraphNode = get_node(NodePath(conn_info["to_node"])) as CustomGraphNode
        if not to_gn:
            continue
        subtree[graph_node].append(to_gn)
        subtree.merge(get_graph_node_subtree(to_gn))
    return subtree

func auto_color_nested_groups() -> void:
    var all_groups: Array[GraphElement] = []
    all_groups.append_array(get_all_groups())
    var groups_parents: = get_graph_elements_cur_groups(all_groups, false)
    
    var nested_level: = func(group: GraphElement, level: int, recurse: Callable) -> int:
        if group in groups_parents:
            return recurse.call(groups_parents[group], level + 1, recurse)
        return level
    
    var group_colors: = ThemeColorVariants.all_color_names() as Array[String]
    group_colors.erase(ANESettings.default_group_color)
    group_colors.push_front(ANESettings.default_group_color)

    for group in all_groups:
        if group.get_meta("has_custom_color", false):
            continue
        var level: int = nested_level.call(group, 0, nested_level)
        if level > 0:
            set_group_custom_accent_color(group, group_colors[level % group_colors.size()])

func _get_tooltip(at_local_position: Vector2) -> String:
    var groups_reversed: = get_all_groups()
    groups_reversed.reverse()
    for group in groups_reversed:
        var group_local_rect: = group.get_rect()
        if group_local_rect.has_point(at_local_position):
            return group.tooltip_text
    return ""