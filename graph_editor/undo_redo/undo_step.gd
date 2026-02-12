## A class to hold all information needed to undo/redo actions in the Asset Node Editor
extends RefCounted

const Fragment: = preload("res://graph_editor/asset_node_fragment.gd")
const GraphUndoStep = preload("res://graph_editor/undo_redo/graph_undo_step.gd")

var editor: CHANE_AssetNodeEditor

## For each affected graph, store the graph specific information here
var graph_undo_steps: Dictionary[CHANE_AssetNodeGraphEdit, GraphUndoStep] = {}

var created_asset_node_copies: Array[HyAssetNode] = []
var created_asset_nodes_aux_data: Array[HyAssetNode.AuxData] = []
var deleted_asset_node_copies: Array[HyAssetNode] = []
var deleted_asset_nodes_aux_data: Array[HyAssetNode.AuxData] = []

var used_fragments: Array[Fragment] = []
var created_fragments: Array[Fragment] = []

var pasted_asset_node_ids: Array[String] = []

var added_asset_node_connections: Array[Dictionary] = []
var removed_asset_node_connections: Array[Dictionary] = []

var an_settings_changed: Dictionary[String, Dictionary] = {}

var custom_undo_callbacks: Array[Callable] = []
var custom_redo_callbacks: Array[Callable] = []

var cut_fragment_ids_pasted: Array[String] = []

var has_existing_action: bool = false

var action_name: String = "Action"

var is_uncancelable: bool = false

func set_editor(the_editor: CHANE_AssetNodeEditor) -> void:
	editor = the_editor

func get_history_text() -> String:
	return action_name

func add_graph_undo(graph: CHANE_AssetNodeGraphEdit, undo_step: GraphUndoStep) -> void:
	graph_undo_steps[graph] = undo_step

func get_undo_for_graph(graph: CHANE_AssetNodeGraphEdit) -> GraphUndoStep:
	if not graph_undo_steps.has(graph):
		graph_undo_steps[graph] = GraphUndoStep.new()
		var selected_names: Array[String] = []
		for ge in graph.get_selected_ges():
			selected_names.append(ge.name)
		graph_undo_steps[graph].selected_before_names = selected_names
	return graph_undo_steps[graph]

func register_an_settings_before_change(asset_node: HyAssetNode) -> void:
	register_an_id_settings_before_change(asset_node.an_node_id, asset_node.settings)

func register_an_id_settings_before_change(an_id: String, settings: Dictionary) -> void:
	settings = settings.duplicate_deep()
	if an_id in an_settings_changed:
		return
	var setting_change_info: Dictionary[String, Dictionary] = {}
	for setting_name in settings.keys():
		var before_info: Dictionary[String, Variant] = {
			"before": settings[setting_name],
			"after": settings[setting_name],
		}
		setting_change_info[setting_name] = before_info
	an_settings_changed[an_id] = setting_change_info

func manually_delete_asset_node(asset_node: HyAssetNode) -> void:
	var an_shallow_copy: = asset_node.get_shallow_copy(asset_node.an_node_id)
	var aux_data: = editor.asset_node_aux_data[asset_node.an_node_id].duplicate(false)
	deleted_asset_node_copies.append(an_shallow_copy)
	deleted_asset_nodes_aux_data.append(aux_data)

func manually_create_asset_node(asset_node: HyAssetNode) -> void:
	var an_shallow_copy: = asset_node.get_shallow_copy(asset_node.an_node_id)
	var aux_data: = editor.asset_node_aux_data[asset_node.an_node_id].duplicate(false)
	created_asset_node_copies.append(an_shallow_copy)
	created_asset_nodes_aux_data.append(aux_data)

func paste_fragment(paste_from_fragment: Fragment, into_graph: CHANE_AssetNodeGraphEdit, at_pos_offset: Vector2, with_snap: bool) -> void:
	if not paste_from_fragment in used_fragments:
		used_fragments.append(paste_from_fragment)
	var num_gd_nodes: = paste_from_fragment.get_num_gd_nodes()
	var counter_start: = editor.reserve_global_counter_names(num_gd_nodes)

	var graph_undo_step: = get_undo_for_graph(into_graph)
	var fragment_id: = paste_from_fragment.fragment_id

	graph_undo_step.set_paste_fragment(fragment_id, counter_start, num_gd_nodes, at_pos_offset, with_snap)
	# Paste is performed immediately before commit so we can capture the list of pasted nodes.
	# _insert_fragment_into_graph skips when is_committing_action() to avoid double pasting.
	var new_stuff: = editor._insert_fragment_into_graph(fragment_id, into_graph, at_pos_offset, with_snap, counter_start)
	var pasted_ids: Array[String] = []
	for pasted_an in new_stuff[2]:
		pasted_ids.append(pasted_an.an_node_id)
	pasted_asset_node_ids.append_array(pasted_ids)
	if paste_from_fragment.is_cut_fragment:
		cut_fragment_ids_pasted.append(fragment_id)

func cut_graph_elements_into_fragment(ges_to_cut_orig: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit) -> Fragment:
	var ges_to_cut: = ges_to_cut_orig.duplicate()
	
	var root_gn: = editor.root_graph_node
	ges_to_cut.erase(root_gn)

	var cut_fragment: = Fragment.new_for_editor(editor)
	created_fragments.append(cut_fragment)
	editor.fragment_store.register_fragment(cut_fragment)
	
	var graph_undo_step: = get_undo_for_graph(from_graph)

	# Record external GE connections with original names (no remapping needed)
	var hanging_ge_connections: = editor.get_hanging_ge_connections(ges_to_cut, from_graph)
	graph_undo_step.remove_graph_node_conn_infos(hanging_ge_connections, true)
	
	# Fragment creation snapshots original names and group memberships internally
	cut_fragment.load_graph_elements(ges_to_cut_orig, from_graph, true, self)
	
	# Record group memberships with original names from the fragment's snapshot
	graph_undo_step.removed_group_relations.append_array(cut_fragment.gd_node_tree.original_group_memberships)
	
	var from_pos: = cut_fragment.get_from_graph_pos()
	var original_ge_names: Array[String] = cut_fragment.get_original_ge_names()
	graph_undo_step.set_delete_fragment(cut_fragment.fragment_id, original_ge_names, from_pos)
	return cut_fragment
	
func add_asset_node_connection(from_an: HyAssetNode, from_conn_name: String, to_an: HyAssetNode) -> void:
	var conn_info: = {
		"parent_node": from_an.an_node_id,
		"child_node": to_an.an_node_id,
		"connection_name": from_conn_name,
	}
	add_asset_node_connection_info(conn_info)

func add_asset_node_connection_info(conn_info: Dictionary) -> void:
	added_asset_node_connections.append(conn_info)
	editor._add_unadded_an_connections([conn_info])

func remove_asset_node_connection(from_an: HyAssetNode, from_conn_name: String, to_an: HyAssetNode) -> void:
	var conn_info: = {
		"parent_node": from_an.an_node_id,
		"child_node": to_an.an_node_id,
		"connection_name": from_conn_name,
	}
	remove_asset_node_connection_info(conn_info)

func remove_asset_node_connection_info(conn_info: Dictionary) -> void:
	removed_asset_node_connections.append(conn_info)
	editor._remove_an_connections([conn_info])

func update_changed_asset_node_settings(an: HyAssetNode) -> void:
	var cur_settings: = an.settings.duplicate_deep()
	if not an_settings_changed.has(an.an_node_id):
		print_debug("Updating changed asset node settings for asset node %s, before settings were not registered")
		register_an_id_settings_before_change(an.an_node_id, cur_settings)
	var setting_change_info: Dictionary[String, Dictionary] = an_settings_changed[an.an_node_id]
	for setting_name in cur_settings.keys():
		if not setting_change_info.has(setting_name):
			continue
		setting_change_info[setting_name]["after"] = cur_settings[setting_name]

func commit(undo_redo: UndoRedo, merge_mode_override: int = -1) -> void:
	var merge_mode: = UndoRedo.MERGE_ENDS if has_existing_action else UndoRedo.MERGE_DISABLE
	if merge_mode_override >= 0:
		merge_mode = merge_mode_override as UndoRedo.MergeMode
	_make_action(undo_redo, merge_mode)

func _make_action(undo_redo: UndoRedo, merge_mode: UndoRedo.MergeMode) -> void:
	has_existing_action = true
	undo_redo.create_action(get_history_text(), merge_mode)
	
	# Non-fragment asset node registration (manual curve points, single-node add, etc.)
	undo_redo.add_undo_method(editor._restore_manual_asset_nodes.bind(deleted_asset_node_copies, deleted_asset_nodes_aux_data))
	undo_redo.add_do_method(editor._restore_manual_asset_nodes.bind(created_asset_node_copies, created_asset_nodes_aux_data))
	
	for changed_an_id in an_settings_changed.keys():
		if editor.all_asset_nodes.has(changed_an_id):
			update_changed_asset_node_settings(editor.all_asset_nodes[changed_an_id])
		for setting_name in an_settings_changed[changed_an_id].keys():
			var vals: = an_settings_changed[changed_an_id][setting_name] as Dictionary[String, Variant]
			if vals["before"] == vals["after"]:
				continue
			undo_redo.add_undo_method(editor._set_asset_node_setting.bind(changed_an_id, setting_name, vals["before"]))
			undo_redo.add_do_method(editor._set_asset_node_setting.bind(changed_an_id, setting_name, vals["after"]))
	
	for graph in graph_undo_steps.keys():
		graph_undo_steps[graph].register_action(undo_redo, graph, editor)
	
	if added_asset_node_connections.size() > 0:
		undo_redo.add_do_method(editor._add_an_connections_if_not_commit.bind(added_asset_node_connections))
		undo_redo.add_undo_method(editor._remove_an_connections.bind(added_asset_node_connections))
	if removed_asset_node_connections.size() > 0:
		undo_redo.add_do_method(editor._remove_an_connections_if_not_commit.bind(removed_asset_node_connections))
		undo_redo.add_undo_method(editor._add_an_connections.bind(removed_asset_node_connections))
	
	for callback in custom_undo_callbacks:
		undo_redo.add_undo_method(callback)
	for callback in custom_redo_callbacks:
		undo_redo.add_do_method(callback)

	for graph in graph_undo_steps.keys():
		graph_undo_steps[graph].register_late_actions(undo_redo, graph, editor)

	# Non-fragment asset node cleanup
	if created_asset_node_copies.size() > 0:
		var created_asset_node_ids: Array[String] = []
		for created_asset_node_copy in created_asset_node_copies:
			created_asset_node_ids.append(created_asset_node_copy.an_node_id)
		undo_redo.add_undo_method(editor.remove_asset_node_ids.bind(created_asset_node_ids))
	if deleted_asset_node_copies.size() > 0:
		var deleted_asset_node_ids: Array[String] = []
		for deleted_asset_node_copy in deleted_asset_node_copies:
			deleted_asset_node_ids.append(deleted_asset_node_copy.an_node_id)
		undo_redo.add_do_method(editor.remove_asset_node_ids.bind(deleted_asset_node_ids))

	undo_redo.add_undo_method(editor.remove_asset_node_ids.bind(pasted_asset_node_ids))
	
	if created_fragments.size() > 0:
		for fragment in created_fragments:
			undo_redo.add_undo_reference(fragment)
		created_fragments.clear()
	if used_fragments.size() > 0:
		for fragment in used_fragments:
			undo_redo.add_do_reference(fragment)
		used_fragments.clear()

	if cut_fragment_ids_pasted.size() > 0:
		undo_redo.add_do_method(editor.invalidate_cut_fragments.bind(cut_fragment_ids_pasted))
	
	if an_settings_changed.size() > 0:
		undo_redo.add_do_method(editor.notify_asset_node_settings_changed.bind(an_settings_changed.keys()))
		undo_redo.add_undo_method(editor.notify_asset_node_settings_changed.bind(an_settings_changed.keys()))
	
	undo_redo.commit_action(true)
