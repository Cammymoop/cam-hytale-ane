extends RefCounted

const UndoStep: = preload("res://graph_editor/undo_redo/undo_step.gd")

const Fragment: = preload("./asset_node_fragment.gd")
const FragmentRoot: = preload("./fragment_root.gd")

var format_version: int = 1

var fragment_id: String
var is_cut_fragment: bool = false
var source_description: String

var gd_node_tree: FragmentRoot
var gd_nodes_are_for_editor: CHANE_AssetNodeEditor
var serialized_data: String

var context_data: Dictionary[String, Variant] = {}


static func get_new_fragment_id() -> String:
	return Util.random_str(16)

static func new_from_string(fragment_string: String, source_desc: String, with_fragment_id: String = "") -> Fragment:
	var new_fragment: = new()
	new_fragment.fragment_id = with_fragment_id if with_fragment_id else get_new_fragment_id()
	new_fragment.source_description = source_desc
	new_fragment.serialized_data = fragment_string
	return new_fragment

static func new_for_editor(for_editor: CHANE_AssetNodeEditor, with_fragment_id: String = "") -> Fragment:
	var new_fragment: = new()
	new_fragment.fragment_id = with_fragment_id if with_fragment_id else get_new_fragment_id()
	new_fragment.gd_nodes_are_for_editor = for_editor
	new_fragment.source_description = "CamHytaleANE:%s" % Util.get_plain_version()
	return new_fragment

static func new_duplicate_fragment(fragment: Fragment, reroll_ids: bool = true, is_undelete: bool = false) -> Fragment:
	var new_fragment: Fragment
	if fragment.has_node_tree():
		new_fragment = new_for_editor(fragment.gd_nodes_are_for_editor)
		fragment._duplicate_to(new_fragment, reroll_ids, is_undelete)
	else:
		new_fragment = new_from_string(fragment.serialized_data, fragment.source_description)
	return new_fragment

func load_editor_selection(as_cut: bool, from_editor: CHANE_AssetNodeEditor = null) -> bool:
	if from_editor:
		gd_nodes_are_for_editor = from_editor
	var selected_ges: Array[GraphElement] = gd_nodes_are_for_editor.get_selected_ges()
	return load_graph_elements(selected_ges, gd_nodes_are_for_editor.focused_graph, as_cut)
	
func load_graph_elements(graph_elements: Array[GraphElement], from_graph: CHANE_AssetNodeGraphEdit, as_cut: bool, undo_step: UndoStep = null) -> bool:
	if not gd_nodes_are_for_editor:
		push_error("No editor context while loading graph elements into fragment")
		return false
	if has_node_tree() or serialized_data:
		push_error("Fragment alerady has data, create a new fragment to load nodes from editor")
		return false
	if as_cut and not undo_step:
		push_warning("Cutting fragment from editor without undo step, cut an connections will not be saved to undo step")
	var editor: = gd_nodes_are_for_editor

	if graph_elements.size() == 0:
		push_warning("No provided elements to load into new fragment from editor")
		return false

	is_cut_fragment = as_cut
	
	var included_asset_nodes: = editor.get_included_asset_nodes_for_ges(graph_elements)
	context_data["hanging_connections"] = editor.get_hanging_an_connections_for_ges(graph_elements, from_graph)

	# Snapshot original GE names and group memberships before any modifications
	gd_node_tree = FragmentRoot.new()
	var ges_excluding_root: = graph_elements.duplicate()
	ges_excluding_root.erase(editor.root_graph_node)
	gd_node_tree.snapshot_ge_names(ges_excluding_root)
	var ref_group_relations: = from_graph.get_graph_elements_cur_group_relations(ges_excluding_root)
	gd_node_tree.snapshot_group_memberships(ref_group_relations)

	if as_cut:
		gd_node_tree.take_asset_nodes_from_editor(editor, included_asset_nodes, undo_step)
		var was_root_included: = graph_elements.has(editor.root_graph_node)

		editor.remove_graph_elements_from_graphs(ges_excluding_root)
		add_gd_nodes_to_fragment_root(ges_excluding_root)
		if was_root_included:
			var new_root_an: = gd_node_tree.all_asset_nodes[editor.root_asset_node.an_node_id]
			var new_root_graph_node: = gd_nodes_are_for_editor.make_graph_node_for_an(new_root_an, Vector2.ZERO, false, gd_node_tree.asset_node_aux_data)
			new_root_graph_node.name = editor.root_graph_node.name
			add_gd_nodes_to_fragment_root([new_root_graph_node])
	else:
		gd_node_tree.get_duplicate_an_set_from_editor(editor, included_asset_nodes)
		create_new_graph_nodes_in_fragment_root()
		var duplicate_groups: = editor.get_duplicate_group_set(Util.engine_class_filtered(graph_elements, "GraphFrame"))
		add_gd_nodes_to_fragment_root(duplicate_groups)
	
	set_from_graph_pos(gd_node_tree.recenter_graph_elements())
	
	return true

func set_from_graph_pos(from_graph_pos: Vector2) -> void:
	context_data["from_graph_pos"] = JSON.from_native(from_graph_pos)

func get_from_graph_pos() -> Vector2:
	if not has_node_tree():
		push_error("No node tree to get from graph pos from")
		return Vector2.ZERO

	if not context_data.has("from_graph_pos"):
		return Vector2.ZERO
	return JSON.to_native(context_data["from_graph_pos"])

func has_node_tree() -> bool:
	return gd_node_tree != null and is_instance_valid(gd_node_tree)

func get_asset_node_trees() -> Array[HyAssetNode]:
	if not has_node_tree():
		push_error("No node tree to get asset node trees from")
		return []
	return gd_node_tree.get_an_tree_roots()

func get_all_included_asset_nodes() -> Array[HyAssetNode]:
	if not has_node_tree():
		push_error("No node tree to get asset nodes from")
		return []
	return gd_node_tree.get_all_asset_nodes()

## Gets a new set of GraphElement Nodes attached to a FragmentRoot which contains a new set of HyAssetNodes
## If pasting, unless the fragment was a cut and is pasting without being undone or pasted before, the asset node IDs will be rerolled
## Note: The fragment owns the reference to the Godot Nodes and will free them when it's gone, so we only ever return duplicated instances for use elsewhere
func get_gd_nodes_copy(reroll_ids: bool = true, is_undelete: bool = false) -> FragmentRoot:
	if not gd_nodes_are_for_editor:
		push_error("No editor context to get fragment nodes")
		return null

	if not has_node_tree():
		if not _make_nodes(gd_nodes_are_for_editor):
			return null
	
	var duplicate_fragment: = new_duplicate_fragment(self, reroll_ids, is_undelete)
	return duplicate_fragment.gd_node_tree

## Creates a copy with original IDs and renames GEs to their original names using AN ID as the bridge
func get_undelete_nodes() -> FragmentRoot:
	var copy: = get_gd_nodes_copy(false, true)
	if copy:
		_apply_original_names(copy)
	return copy

## Creates a copy with rerolled IDs and counter-based names for paste/duplicate
func get_paste_nodes(prefix: String, counter_start: int) -> FragmentRoot:
	var copy: = get_gd_nodes_copy(true, false)
	if copy:
		var all_ges: = copy.get_all_graph_elements()
		for i in all_ges.size():
			all_ges[i].name = "%s--%d" % [prefix, counter_start + i]
	return copy

func _apply_original_names(frag_root: FragmentRoot) -> void:
	var non_gn_idx: int = 0
	for ge in frag_root.get_all_graph_elements():
		var an_id: String = ge.get_meta("hy_asset_node_id", "")
		if an_id and frag_root.original_gn_names_by_an_id.has(an_id):
			ge.name = frag_root.original_gn_names_by_an_id[an_id]
		elif non_gn_idx < frag_root.original_ge_names.size():
			ge.name = frag_root.original_ge_names[non_gn_idx]
			non_gn_idx += 1

func get_num_gd_nodes() -> int:
	if not gd_nodes_are_for_editor:
		push_error("No editor context to get number of GD nodes from")
		return 0
	if not has_node_tree():
		if not _make_nodes(gd_nodes_are_for_editor):
			return 0
	return gd_node_tree.num_graph_elements()

func get_original_ge_names() -> Array[String]:
	if not has_node_tree():
		return []
	var names: Array[String] = []
	for ge_name in gd_node_tree.original_gn_names_by_an_id.values():
		names.append(ge_name)
	names.append_array(gd_node_tree.original_ge_names)
	return names


func disown_nodes() -> void:
	gd_nodes_are_for_editor = null
	gd_node_tree = null

func discard_nodes() -> void:
	prints("discarding nodes for fragment %s" % fragment_id)
	gd_nodes_are_for_editor = null
	gd_node_tree.queue_free()
	gd_node_tree = null

func _make_nodes(for_editor: CHANE_AssetNodeEditor) -> bool:
	if not serialized_data:
		push_error("No serialized data to create nodes from")
		return false
	if has_node_tree():
		discard_nodes()
	context_data.clear()
	
	gd_nodes_are_for_editor = for_editor
	return _deserialize_data()


func _create_serialized_data(from_editor: CHANE_AssetNodeEditor = null) -> bool:
	if not has_node_tree():
		push_error("No Godot nodes to create serialized data from")
		return false

	if from_editor:
		gd_nodes_are_for_editor = from_editor
	if not gd_nodes_are_for_editor or not is_instance_valid(gd_nodes_are_for_editor):
		push_error("No editor context to create serialized data from")
		return false
	
	var serializer: = gd_nodes_are_for_editor.serializer

	var asset_node_data: Array[Dictionary] = []
	for asset_node in get_asset_node_trees():
		var serialized_an_tree: = serializer.serialize_asset_node_tree(asset_node)
		if serialized_an_tree:
			asset_node_data.append(serialized_an_tree)
		else:
			push_warning("Serialized asset node data for tree with root %s is empty" % asset_node.an_node_id)
	
	var full_data: Dictionary[String, Variant] = {
		"format_version": format_version,
		"what_is_this": "Copied data from Cam Hytale Asset Node Editor",
		"copied_from": source_description,
		"workspace_id": gd_nodes_are_for_editor.hy_workspace_id,
		"asset_node_data": asset_node_data,
		"inlcuded_metadata": _serialize_metadata(),
	}
	serialized_data = JSON.stringify(full_data, "", false)
	
	return true

func _serialize_metadata() -> Dictionary:
	const MetadataKeys: = CHANE_HyAssetNodeSerializer.MetadataKeys
	var serializer: = gd_nodes_are_for_editor.serializer

	var serialized_groups: Array = []
	var included_groups: Array[GraphFrame] = Util.engine_class_filtered(gd_node_tree.get_all_graph_elements(), "GraphFrame")
	if included_groups.size() > 0:
		serialized_groups = serializer.serialize_groups(included_groups)

	var serialized_editor_metadata: Dictionary = {
		MetadataKeys.NodesMeta: serializer.serialize_ans_metadata(get_all_included_asset_nodes(), gd_node_tree.asset_node_aux_data),
		MetadataKeys.Links: {},
		MetadataKeys.Groups: serialized_groups,
		MetadataKeys.WorkspaceId: gd_nodes_are_for_editor.hy_workspace_id,
	}
	
	var included_metadata: Dictionary = {
		MetadataKeys.NodeEditorMetadata: serialized_editor_metadata,
		"hanging_connections": context_data.get("hanging_connections", []),
	}

	return included_metadata

func _deserialize_data() -> bool:
	const MetadataKeys: = CHANE_HyAssetNodeSerializer.MetadataKeys
	assert(gd_nodes_are_for_editor, "Editor context is required to deserialize data")
	var editor: = gd_nodes_are_for_editor

	var json_result: Variant = JSON.parse_string(serialized_data)
	if not json_result or typeof(json_result) != TYPE_DICTIONARY:
		push_error("Failed to parse serialized data as dictionary")
		return false
	
	var data: = json_result as Dictionary
	
	if not check_compatible_workspace(data.get("workspace_id", "")):
		print_debug("Workspace ID %s is not compatible with this editor" % data.get("workspace_id", ""))
		return false
	
	var serializer: = editor.serializer
	var editor_metadata: = data.get("inlcuded_metadata", {}).get(MetadataKeys.NodeEditorMetadata, {}) as Dictionary
	var graph_result: = serializer.deserialize_fragment_as_full_graph(data.get("asset_node_data", []), editor_metadata)
	if not graph_result.success:
		return false

	var all_groups_data: Array = data.get(MetadataKeys.NodeEditorMetadata, {}).get(MetadataKeys.Groups, [])
	var new_groups: Array[GraphFrame] = serializer.deserialize_groups(all_groups_data, editor.get_new_group_name)
	
	gd_node_tree = FragmentRoot.new()
	gd_node_tree.asset_nodes_from_graph_parse_result(graph_result)
	
	create_new_graph_nodes_in_fragment_root()
	add_gd_nodes_to_fragment_root(new_groups)

	return true
	
func create_new_graph_nodes_in_fragment_root() -> Array[GraphElement]:
	var added_graph_elements: Array[GraphElement] = []

	var an_roots: Array[HyAssetNode] = gd_node_tree.get_an_tree_roots()
	
	var editor: = gd_nodes_are_for_editor

	for tree_root in an_roots:
		var tree_new: = editor.new_graph_nodes_for_tree(tree_root, Vector2.ZERO, gd_node_tree.asset_node_aux_data)

		var unique_graph_elements: Array[GraphElement] = []
		for ge in tree_new.values():
			if not unique_graph_elements.has(ge):
				unique_graph_elements.append(ge)
		added_graph_elements.append_array(unique_graph_elements)
	
	add_gd_nodes_to_fragment_root(added_graph_elements)
		
	return added_graph_elements

func add_gd_nodes_to_fragment_root(graph_elements: Array) -> void:
	assert(has_node_tree(), "Fragment root is required to add GD nodes to")
	
	for ge in graph_elements:
		if not ge is GraphElement:
			continue
		gd_node_tree.add_child(ge, true)

func check_compatible_workspace(workspace_id: String) -> bool:
	return gd_nodes_are_for_editor.is_workspace_id_compatible(workspace_id)

func _duplicate_to(other: Fragment, reroll_ids: bool, is_undelete: bool = false) -> void:
	other.source_description = source_description
	other.gd_node_tree = gd_node_tree.get_duplicate(reroll_ids, is_undelete)
	other.create_new_graph_nodes_in_fragment_root()
	var duplicated_groups: = gd_nodes_are_for_editor.get_duplicate_group_set(Util.engine_class_filtered(gd_node_tree.get_all_graph_elements(), "GraphFrame"))
	other.add_gd_nodes_to_fragment_root(duplicated_groups)
	other.context_data = context_data.duplicate(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if gd_node_tree:
			gd_node_tree.queue_free()
			gd_node_tree = null
