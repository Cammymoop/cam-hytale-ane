extends Node

const UndoStep: = preload("res://graph_editor/undo_redo/undo_step.gd")

const FragmentRoot: = preload("./fragment_root.gd")

var all_asset_nodes: Dictionary[String, HyAssetNode] = {}
var asset_node_aux_data: Dictionary[String, HyAssetNode.AuxData] = {}

var exclude_from_undelete: Array[String] = []

## Maps asset_node_id -> original GN name (used on undelete to get new Godot Nodes with the same name so undo/redo on them works)
var original_gn_names_by_an_id: Dictionary[String, String] = {}
var original_ge_names: Array[String] = []

var original_group_memberships: Array[Dictionary] = []

func take_asset_nodes_from_editor(editor: CHANE_AssetNodeEditor, take_ans: Array[HyAssetNode], current_undo_step: UndoStep) -> void:
	var editor_root_an: = editor.root_asset_node
	var includes_root: = take_ans.has(editor_root_an)

	var root_excluded_ans: = take_ans.duplicate()
	root_excluded_ans.erase(editor_root_an)

	var root_connections: Dictionary[String, Array] = {}
	if includes_root:
		for conn_name in editor_root_an.connection_list:
			root_connections[conn_name] = []
			for connected_an in editor_root_an.get_all_connected_nodes(conn_name):
				if connected_an in take_ans:
					root_connections[conn_name].append(connected_an)

	var removed_connections: = editor._disconnect_an_set_external_connections(root_excluded_ans)
	if current_undo_step:
		for an_connection in removed_connections:
			current_undo_step.remove_asset_node_connection_info(an_connection)
	all_asset_nodes = {}
	asset_node_aux_data = {}

	for an in root_excluded_ans:
		all_asset_nodes[an.an_node_id] = an
		asset_node_aux_data[an.an_node_id] = editor.asset_node_aux_data[an.an_node_id]
			
		editor.remove_asset_node_id(an.an_node_id)
	if includes_root:
		var duplicate_root: = editor.get_duplicate_asset_node(editor_root_an, false)
		for conn_name in root_connections.keys():
			for connected_an in root_connections[conn_name]:
				duplicate_root.append_node_to_connection(conn_name, connected_an)
		all_asset_nodes[duplicate_root.an_node_id] = duplicate_root
		asset_node_aux_data[duplicate_root.an_node_id] = editor.asset_node_aux_data[editor_root_an.an_node_id].duplicate(false)
		exclude_from_undelete.append(duplicate_root.an_node_id)

func get_duplicate_an_set_from_editor(editor: CHANE_AssetNodeEditor, asset_node_set: Array[HyAssetNode]) -> void:
	all_asset_nodes = {}
	asset_node_aux_data = {}

	var duplicate_ans: = editor.create_duplicate_filtered_an_set(asset_node_set, false, false, false, asset_node_aux_data)

	for an in duplicate_ans:
		all_asset_nodes[an.an_node_id] = an

func snapshot_ge_names(graph_elements: Array[GraphElement]) -> void:
	original_gn_names_by_an_id.clear()
	original_ge_names.clear()
	for ge in graph_elements:
		var an_id: String = ge.get_meta("hy_asset_node_id", "")
		if an_id:
			original_gn_names_by_an_id[an_id] = ge.name
		else:
			original_ge_names.append(ge.name)

func snapshot_group_memberships(group_relations: Array[Dictionary]) -> void:
	original_group_memberships.clear()
	for group_relation in group_relations:
		original_group_memberships.append({
			"group": group_relation["group"].name as String,
			"member": group_relation["member"].name as String,
		})

func reroll_asset_node_ids_with_gns() -> void:
	var ans_to_gns: Dictionary[String, GraphElement] = {}
	for ge in get_all_graph_elements():
		if ge.get_meta("hy_asset_node_id", ""):
			ans_to_gns[ge.get_meta("hy_asset_node_id", "")] = ge

func reroll_asset_node_ids() -> void:
	var new_ids: Dictionary[String, String] = {}

	for old_id in all_asset_nodes.keys():
		new_ids[old_id] = CHANE_HyAssetNodeSerializer.reroll_an_id(old_id)

	for old_id in all_asset_nodes.keys():
		var new_id: = new_ids[old_id]
		all_asset_nodes[old_id].an_node_id = new_id
		all_asset_nodes[new_id] = all_asset_nodes[old_id]
		all_asset_nodes.erase(old_id)
		if asset_node_aux_data[old_id].output_to_node_id:
			asset_node_aux_data[old_id].output_to_node_id = new_ids[asset_node_aux_data[old_id].output_to_node_id]
		asset_node_aux_data[new_id] = asset_node_aux_data[old_id]
		asset_node_aux_data.erase(old_id)

func asset_nodes_from_graph_parse_result(graph_result: CHANE_HyAssetNodeSerializer.EntireGraphParseResult) -> void:
	asset_node_aux_data = graph_result.asset_node_aux_data.duplicate()
	all_asset_nodes = {}
	for floating_root_result in graph_result.floating_tree_results.values():
		append_tree_parse_result_asset_nodes(floating_root_result)

func append_tree_parse_result_asset_nodes(parse_result: CHANE_HyAssetNodeSerializer.TreeParseResult) -> void:
	for node in parse_result.all_nodes:
		all_asset_nodes[node.an_node_id] = node


func get_an_tree_roots() -> Array[HyAssetNode]:
	return CHANE_AssetNodeEditor.get_an_roots_within_set(all_asset_nodes, asset_node_aux_data)

func get_all_asset_nodes() -> Array[HyAssetNode]:
	return Array(all_asset_nodes.values(), TYPE_OBJECT, &"HyAssetNode", null)

func num_asset_nodes() -> int:
	return all_asset_nodes.size()

func get_all_graph_elements() -> Array[GraphElement]:
	var all_graph_elements: Array[GraphElement] = []
	_collect_graph_elements_recurse(self, all_graph_elements)
	return all_graph_elements

func _collect_graph_elements_recurse(at_node: Node, all_graph_elements: Array[GraphElement]) -> void:
	if at_node is GraphElement:
		all_graph_elements.append(at_node)
	for child in at_node.get_children():
		_collect_graph_elements_recurse(child, all_graph_elements)

func recenter_graph_elements() -> Vector2:
	var all_graph_elements: = get_all_graph_elements()
	var avg_center: = Util.average_graph_element_pos_offset(all_graph_elements)
	for ge in all_graph_elements:
		ge.position_offset -= avg_center
		if ge is CustomGraphNode and ge.get_meta("hy_asset_node_id", ""):
			var an_id: String = ge.get_meta("hy_asset_node_id", "")
			asset_node_aux_data[an_id].position = ge.position_offset
	return avg_center

## Gets a duplicate with asset nodes but no graph elements
func get_duplicate(reroll_ids: bool, is_undelete: bool = false) -> FragmentRoot:
	var copy: = FragmentRoot.new()
	copy.all_asset_nodes = all_asset_nodes.duplicate_deep()
	if is_undelete:
		for an_id in exclude_from_undelete:
			copy.all_asset_nodes.erase(an_id)
	for an_id in copy.all_asset_nodes.keys():
		copy.asset_node_aux_data[an_id] = asset_node_aux_data[an_id].duplicate(true)
	copy.original_gn_names_by_an_id = original_gn_names_by_an_id.duplicate()
	copy.original_ge_names = original_ge_names.duplicate()
	copy.original_group_memberships = original_group_memberships.duplicate(true)
	if reroll_ids:
		copy.reroll_asset_node_ids()
	return copy

func num_graph_elements() -> int:
	return get_all_graph_elements().size()
