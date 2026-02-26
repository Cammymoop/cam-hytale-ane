## GraphEdit-specific parts of an undo step -- all GE references are by name (String), never direct object refs
extends RefCounted

var created_names_to_select: Array[String] = []
var new_default_graph_nodes_info: Dictionary[String, Dictionary] = {}

var added_connections: Array[Dictionary] = []
var removed_connections: Array[Dictionary] = []
var no_commit_removed_connections: Array[Dictionary] = []

var added_group_relations: Array[Dictionary] = []
var removed_group_relations: Array[Dictionary] = []

var moved_ges_from: Dictionary[String, Vector2] = {}
var resized_ges_from: Dictionary[String, Vector2] = {}

var group_shrinkwrap_from: Dictionary[String, bool] = {}
var group_shrinkwrap_to: Dictionary[String, bool] = {}

var group_accent_colors_from: Dictionary[String, String] = {}
var group_accent_colors_to: Dictionary[String, String] = {}

var ge_titles_from: Dictionary[String, String] = {}
var ge_titles_to: Dictionary[String, String] = {}

var pasted_fragment_infos: Array[Dictionary] = []

var delete_fragment_infos: Array[Dictionary] = []

var selected_before_names: Array[String] = []

func add_graph_node_conn_infos(conn_infos: Array[Dictionary]) -> void:
	added_connections.append_array(conn_infos)
	added_connections = Util.unique_conn_infos(added_connections)

func remove_graph_node_conn_infos(conn_infos: Array[Dictionary], skip_on_commit: bool = false) -> void:
	if skip_on_commit:
		no_commit_removed_connections.append_array(conn_infos)
		no_commit_removed_connections = Util.unique_conn_infos(no_commit_removed_connections)
	else:
		removed_connections.append_array(conn_infos)
		removed_connections = Util.unique_conn_infos(removed_connections)

func add_graph_node_connection(from_gn_name: String, from_port: int, to_gn_name: String, to_port: int) -> void:
	added_connections.append({
		"from_node": from_gn_name,
		"from_port": from_port,
		"to_node": to_gn_name,
		"to_port": to_port,
	})

func remove_graph_node_connection(from_gn_name: String, from_port: int, to_gn_name: String, to_port: int) -> void:
	removed_connections.append({
		"from_node": from_gn_name,
		"from_port": from_port,
		"to_node": to_gn_name,
		"to_port": to_port,
	})

func set_paste_fragment(fragment_id: String, counter_start: int, num_ges: int, at_pos_offset: Vector2, with_snap: bool) -> void:
	pasted_fragment_infos.append({
		"fragment_id": fragment_id,
		"counter_start": counter_start,
		"num_ges": num_ges,
		"at_pos_offset": at_pos_offset,
		"with_snap": with_snap,
	})
	created_names_to_select.append(range(counter_start, counter_start + num_ges).map(func(i): return "FrGE--%d" % [i]))

func set_delete_fragment(fragment_id: String, original_ge_names: Array[String], at_pos_offset: Vector2) -> void:
	delete_fragment_infos.append({
		"fragment_id": fragment_id,
		"at_pos_offset": at_pos_offset,
		"original_ge_names": original_ge_names,
	})

## Adds info needed to recreate and add a new default graph node for a new asset node
func add_new_default_graph_node_for(new_an_id: String, new_gn_name: String, new_gn_position_offset: Vector2, new_connections: Array[Dictionary] = [], new_group_relations: Array[Dictionary] = []) -> void:
	created_names_to_select.append(new_gn_name)
	new_default_graph_nodes_info[new_gn_name] = {
		"an_id": new_an_id,
		"at_pos_offset": new_gn_position_offset,
	}
	added_connections.append_array(new_connections)
	add_group_relations(new_group_relations)

func add_group_relations(group_relations: Array[Dictionary]) -> void:
	for group_relation in group_relations:
		added_group_relations.append({
			"group": group_relation["group"].name as String,
			"member": group_relation["member"].name as String,
		})

func add_ges_into_group(ges_to_include: Array[GraphElement], group: GraphFrame) -> void:
	for ge in ges_to_include:
		added_group_relations.append({
			"group": group.name as String,
			"member": ge.name as String,
		})

func remove_ges_from_group(ges_to_remove: Array[GraphElement], group: GraphFrame) -> void:
	for ge in ges_to_remove:
		removed_group_relations.append({
			"group": group.name as String,
			"member": ge.name as String,
		})

func remove_group_relations(group_relations: Array[Dictionary]) -> void:
	for group_relation in group_relations:
		removed_group_relations.append({
			"group": group_relation["group"].name as String,
			"member": group_relation["member"].name as String,
		})

func register_action(undo_redo: UndoRedo, graph: CHANE_AssetNodeGraphEdit, editor: CHANE_AssetNodeEditor) -> void:
	var refresh_group_membership_and_colors: bool = false
	
	# Snapshot current positions/sizes for the "to" state at commit time
	var moved_ges_to: Dictionary[String, Vector2] = {}
	for ge_name in moved_ges_from.keys():
		var ge: = graph.get_node_or_null(NodePath(ge_name)) as GraphElement
		if ge:
			moved_ges_to[ge_name] = ge.position_offset
	var resized_ges_to: Dictionary[String, Vector2] = {}
	for ge_name in resized_ges_from.keys():
		var ge: = graph.get_node_or_null(NodePath(ge_name)) as GraphElement
		if ge:
			resized_ges_to[ge_name] = ge.size
	
	# Nodes created as a new default by selecting a new asset node
	for new_gn_name in new_default_graph_nodes_info.keys():
		var for_an_id: String = new_default_graph_nodes_info[new_gn_name]["an_id"]
		var at_pos_offset: Vector2 = new_default_graph_nodes_info[new_gn_name]["at_pos_offset"]
		undo_redo.add_do_method(editor._readd_new_default_graph_node_for.bind(graph, for_an_id, new_gn_name, at_pos_offset))
	
	# Fragment paste (redo = insert fragment, undo = delete by counter names)
	if pasted_fragment_infos.size() > 0:
		for finfo in pasted_fragment_infos:
			undo_redo.add_do_method(editor._insert_fragment_into_graph.bind(finfo["fragment_id"], graph, finfo["at_pos_offset"], finfo["with_snap"], finfo["counter_start"]))
	
	# Fragment delete (undo = undelete fragment, redo = redelete by original names)
	if delete_fragment_infos.size() > 0:
		for finfo in delete_fragment_infos:
			undo_redo.add_undo_method(editor._undelete_fragment.bind(finfo["fragment_id"], graph, finfo["at_pos_offset"]))
	
	if removed_group_relations.size() > 0:
		refresh_group_membership_and_colors = true
		undo_redo.add_do_method(graph._break_named_group_relations.bind(removed_group_relations))
		undo_redo.add_undo_method(graph._assign_named_group_relations.bind(removed_group_relations))
	if added_group_relations.size() > 0:
		refresh_group_membership_and_colors = true
		undo_redo.add_undo_method(graph._break_named_group_relations.bind(added_group_relations))
		undo_redo.add_do_method(graph._assign_named_group_relations.bind(added_group_relations))

	if moved_ges_from.size() > 0 or resized_ges_from.size() > 0:
		undo_redo.add_undo_method(graph.undo_redo_set_offsets_and_sizes.bind(moved_ges_from.duplicate(), resized_ges_from.duplicate()))
		undo_redo.add_do_method(graph.undo_redo_set_offsets_and_sizes.bind(moved_ges_to, resized_ges_to))
	
	if removed_connections.size() > 0:
		undo_redo.add_undo_method(graph.undo_redo_add_connections.bind(removed_connections))
		undo_redo.add_do_method(graph.undo_redo_remove_connections.bind(removed_connections))
	if no_commit_removed_connections.size() > 0:
		undo_redo.add_undo_method(graph.undo_redo_add_connections.bind(no_commit_removed_connections))
		undo_redo.add_do_method(graph.undo_redo_remove_connections.bind(no_commit_removed_connections, true))
	if added_connections.size() > 0:
		undo_redo.add_undo_method(graph.undo_redo_remove_connections.bind(added_connections))
		undo_redo.add_do_method(graph.undo_redo_add_connections.bind(added_connections))
	
	if ge_titles_from.size() > 0:
		undo_redo.add_undo_method(graph._set_ge_titles.bind(ge_titles_from))
		undo_redo.add_do_method(graph._set_ge_titles.bind(ge_titles_to))
	
	if group_shrinkwrap_from.size() > 0:
		undo_redo.add_undo_method(graph._set_groups_shrinkwrap.bind(group_shrinkwrap_from))
		undo_redo.add_do_method(graph._set_groups_shrinkwrap.bind(group_shrinkwrap_to))
	
	if group_accent_colors_from.size() > 0:
		refresh_group_membership_and_colors = true
		undo_redo.add_undo_method(graph._set_groups_accent_colors.bind(group_accent_colors_from))
		undo_redo.add_do_method(graph._set_groups_accent_colors.bind(group_accent_colors_to))
	
	# Paste undo = delete pasted GEs by counter names
	if pasted_fragment_infos.size() > 0:
		for finfo in pasted_fragment_infos:
			undo_redo.add_undo_method(graph.undo_redo_delete_fragment_ges.bind(finfo["counter_start"], finfo["num_ges"]))
	
	# New default GNs undo = delete by name
	for new_ge_name in new_default_graph_nodes_info.keys():
		undo_redo.add_undo_method(graph.undo_redo_delete_ge_names.bind([new_ge_name]))
	
	undo_redo.add_undo_method(graph.select_ges_by_names.bind(selected_before_names))

	var selected_after_names: Array[String] = []
	if created_names_to_select.size() > 0:
		selected_after_names = created_names_to_select
	else:
		for ge in graph.get_selected_ges():
			selected_after_names.append(ge.name)
	undo_redo.add_do_method(graph.select_ges_by_names.bind(selected_after_names))
	
	if refresh_group_membership_and_colors:
		undo_redo.add_do_method(graph.refresh_graph_elements_in_frame_status)
		undo_redo.add_undo_method(graph.refresh_graph_elements_in_frame_status)

func register_late_actions(undo_redo: UndoRedo, graph: CHANE_AssetNodeGraphEdit, editor: CHANE_AssetNodeEditor) -> void:
	if moved_ges_from.size() > 0:
		var moved_names: Array[String] = []
		moved_names.assign(moved_ges_from.keys())
		undo_redo.add_undo_method(editor.sort_an_connected_for_moved_ge_names.bind(moved_names))
		undo_redo.add_do_method(editor.sort_an_connected_for_moved_ge_names.bind(moved_names))
	
	if delete_fragment_infos.size() > 0:
		for finfo in delete_fragment_infos:
			undo_redo.add_do_method(graph._redelete_by_names.bind(finfo["original_ge_names"]))
