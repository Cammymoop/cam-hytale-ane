extends Node
class_name CHANE_HyAssetNodeSerializer


class MetadataKeys:
    const NodeId: String = "$NodeId"
    
    const NodeEditorMetadata: String = "$NodeEditorMetadata"

    const NodeMetaPosition: String = "$Position"
    const NodeMetaPosX: String = "$x"
    const NodeMetaPosY: String = "$y"
    const NodeMetaTitle: String = "$Title"

    const NodeComment: String = "$Comment"

    const NodesMeta: String = "$Nodes"
    const WorkspaceId: String = "$WorkspaceID"
    const Groups: String = "$Groups"
    const Comments: String = "$Comments"
    const Links: String = "$Links"
    const FloatingRoots: String = "$FloatingNodes"
    
    const GroupName: String = "$name"
    const GroupPosition: String = "$Position"
    const GroupPosX: String = "$x"
    const GroupPosY: String = "$y"
    const GroupWidth: String = "$width"
    const GroupHeight: String = "$height"
    # CHANE custom
    const CHANEGroupAccentColor: String = "$AccentColor"
    
    const CHANE: String = "$CHANE"

class SingleParseResult:
    var asset_node: HyAssetNode = null
    var success: bool = true
    var is_existing_node_id: bool = true
    var old_style_metadata: Dictionary = {}

class TreeParseResult:
    var from_old_style_data: bool = false
    var root_node: HyAssetNode = null
    var first_failure_at: SingleParseResult = null
    var all_nodes_results: Array[SingleParseResult] = []
    var all_nodes: Array[HyAssetNode] = []
    var success: bool = true
    
    func add_root(parse_result: SingleParseResult) -> void:
        all_nodes_results.append(parse_result)
        all_nodes.append(parse_result.asset_node)
        root_node = parse_result.asset_node
        if not parse_result.success:
            success = false
    
    func merge_results(other_result: TreeParseResult) -> void:
        all_nodes_results.append_array(other_result.all_nodes_results)
        all_nodes.append_array(other_result.all_nodes)
        if not other_result.success:
            success = false
            if not first_failure_at and other_result.first_failure_at:
                first_failure_at = other_result.first_failure_at
    
    func get_node_meta_from_old_style() -> Dictionary[String, Dictionary]:
        var node_meta: Dictionary[String, Dictionary] = {}
        for node_result in all_nodes_results:
            if not node_result.success or not node_result.old_style_metadata:
                continue
            node_meta[node_result.asset_node.an_node_id] = node_result.old_style_metadata
        return node_meta
    
    func get_an_id_list() -> Array[String]:
        var an_id_list: Array[String] = []
        for node_result in all_nodes_results:
            an_id_list.append(node_result.asset_node.an_node_id)
        return an_id_list

class EntireGraphParseResult:
    var success: bool = true
    var hy_workspace_id: String = ""
    var was_old_style_format: bool = false
    var has_positions: bool = false

    var root_node: HyAssetNode = null
    var root_tree_result: TreeParseResult = null
    var all_nodes: Dictionary[String, HyAssetNode] = {}
    var floating_tree_roots: Dictionary[String, HyAssetNode] = {}
    var floating_tree_results: Dictionary[String, TreeParseResult] = {}
    var editor_metadata: Dictionary = {}
    var asset_node_aux_data: Dictionary[String, HyAssetNode.AuxData] = {}
    
    func _add_result_nodes(parse_result: TreeParseResult) -> void:
        for node in parse_result.all_nodes:
            all_nodes[node.an_node_id] = node
    
    func add_root_result(parse_result: TreeParseResult) -> void:
        root_tree_result = parse_result
        root_node = parse_result.root_node
        _add_result_nodes(parse_result)
        if not parse_result.success:
            success = false
    
    func add_floating_result(parse_result: TreeParseResult) -> void:
        var tree_key: String = parse_result.root_node.an_node_id if parse_result.root_node else "1"
        while floating_tree_results.has(tree_key):
            tree_key = str(int(tree_key) + 1)
        floating_tree_results[tree_key] = parse_result
        floating_tree_roots[tree_key] = parse_result.root_node
        _add_result_nodes(parse_result)

var serialized_pos_scale: Vector2 = Vector2.ONE
var serialized_pos_offset: Vector2 = Vector2.ZERO

var remove_all_point_zero: bool = true

static func get_unique_an_id(prefix: String) -> String:
    return "%s-%s" % [prefix, Util.unique_id_string()]

static func reroll_an_id(an_id: String) -> String:
    return get_unique_an_id(an_id.split("-")[0])

func get_new_id_for_type(asset_node_type: String) -> String:
    return get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(asset_node_type))

func get_new_id_for_schemaless_node() -> String:
    return get_unique_an_id("GenericAssetNode")

func single_failed_result() -> SingleParseResult:
    var result: = SingleParseResult.new()
    result.success = false
    return result

func failed_leaf_result(single_result: SingleParseResult) -> TreeParseResult:
    var result: TreeParseResult = TreeParseResult.new()
    result.success = false
    if not single_result.asset_node:
        single_result.asset_node = HyAssetNode.new()
    result.add_root(single_result)
    result.first_failure_at = single_result
    return result

# Deserializing

func get_deserialize_scaled_pos(data_pos: Vector2) -> Vector2:
    return data_pos * serialized_pos_scale

func get_deserialize_offset_scaled_pos(data_pos: Vector2) -> Vector2:
    return get_deserialize_scaled_pos(data_pos) + serialized_pos_offset

func _discover_workspace_id_from_root_node(graph_data: Dictionary) -> String:
    var node_id: String = graph_data.get(MetadataKeys.NodeId, "")
    if not node_id:
        print_debug("No metadata and root node has no NodeId, aborting")
        push_error("No metadata and root node has no NodeId, aborting")
        return ""

    if node_id.begins_with(SchemaManager.schema.get_id_prefix_for_node_type("Biome")):
        print("no workspace but found Biome node, setting workspace to Biome")
        return "HytaleGenerator - Biome"
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
                    return SchemaManager.schema.workspace_root_output_types.find_key(output_value_type)

        print_debug("Was not able to discover workspace ID from root node id")
        push_warning("Was not able to discover workspace ID from root node id")
        return ""

static func get_empty_editor_metadata() -> Dictionary:
    return {
        MetadataKeys.NodesMeta: {},
        MetadataKeys.FloatingRoots: [],
        MetadataKeys.Groups: [],
        MetadataKeys.Comments: [],
        MetadataKeys.Links: {},
        MetadataKeys.WorkspaceId: "",
    }


func deserialize_entire_graph(graph_data: Dictionary) -> EntireGraphParseResult:
    var result: = EntireGraphParseResult.new()
    result.hy_workspace_id = ""
    result.was_old_style_format = false
    result.has_positions = true

    if graph_data.has(MetadataKeys.WorkspaceId) or graph_data.has(MetadataKeys.NodeMetaPosition):
        result.was_old_style_format = true
        result.editor_metadata = get_empty_editor_metadata()
        # Old style has some metadata in the root node directly, use what we can
        for editor_meta_key in result.editor_metadata.keys():
            if editor_meta_key == MetadataKeys.NodesMeta:
                continue
            if editor_meta_key == MetadataKeys.FloatingRoots:
                # Floating nodes dont seem to be present in the old style format, better to avoid that edge case entirely just in case
                continue

            if editor_meta_key in graph_data:
                var val_type: = typeof(graph_data[editor_meta_key])
                if val_type == TYPE_ARRAY or val_type == TYPE_DICTIONARY:
                    result.editor_metadata[editor_meta_key] = graph_data[editor_meta_key].duplicate(true)
                else:
                    result.editor_metadata[editor_meta_key] = graph_data[editor_meta_key]

        if graph_data.get(MetadataKeys.WorkspaceId, ""):
            result.hy_workspace_id = graph_data[MetadataKeys.WorkspaceId]
        else:
            # Old style format doesn't use node IDs so inferring the type of the root node without a workspace ID is janky at best
            # not even trying for now. since the old style format isn't even saved by any known editor there's probably no reason to do this anyway.
            print_debug("Old style format with missing workspace ID, aborting")
            push_error("Old style format with missing workspace ID, aborting")
            result.success = false
            return result
    elif not graph_data.get(MetadataKeys.NodeEditorMetadata, {}):
        print_debug("Root node (not old-style) does not have editor metadata")
        push_warning("Root node (not old-style) does not have editor metadata")
        result.has_positions = false
        result.editor_metadata = get_empty_editor_metadata()
        result.hy_workspace_id = _discover_workspace_id_from_root_node(graph_data)
    else:
        result.editor_metadata = graph_data[MetadataKeys.NodeEditorMetadata].duplicate(true)
        result.hy_workspace_id = result.editor_metadata.get(MetadataKeys.WorkspaceId, "")

    if not result.hy_workspace_id:
        print_debug("Missing workspace ID and Unable to infer workspace from file data, aborting")
        push_error("Missing workspace ID and Unable to infer workspace from file data, aborting")
        result.success = false
        return result
    else:
        result.editor_metadata[MetadataKeys.WorkspaceId] = result.hy_workspace_id

    var root_node_type: String = SchemaManager.schema.resolve_root_asset_node_type(result.hy_workspace_id, graph_data)

    if result.was_old_style_format:
        graph_data[MetadataKeys.NodeId] = get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(root_node_type))
    
    # Old style format doesn't use node IDs, so we need to create node aux data after parsing the nodes (which automatically sets the node IDs into graph_data)
    # for new style it's better to create aux data first though, it has the titles which would otherwise need to be patched into the asset nodes later
    var aux_data: Dictionary[String, HyAssetNode.AuxData] = {}
    if not result.was_old_style_format:
        var node_meta: = result.editor_metadata.get(MetadataKeys.NodesMeta, {}) as Dictionary
        aux_data = create_node_aux_data_from_node_meta(node_meta)
        result.asset_node_aux_data = aux_data
    
    var an_id_list: Array[String] = []

    var root_infer_hints: Dictionary = { "asset_node_type": root_node_type }
    var root_parse_result: = parse_asset_node_tree(result.was_old_style_format, graph_data, root_infer_hints, result.asset_node_aux_data)
    result.add_root_result(root_parse_result)
    if not root_parse_result.success:
        push_error("Failed to parse asset node root tree")
        result.success = false
        return result
    
    an_id_list.append_array(root_parse_result.get_an_id_list())

    # Now create the node aux data for the old style format
    if result.was_old_style_format:
        var node_meta_from_root_tree: Dictionary = root_parse_result.get_node_meta_from_old_style()
        if node_meta_from_root_tree.size() > 0:
            result.editor_metadata[MetadataKeys.NodesMeta] = node_meta_from_root_tree
            aux_data = create_node_aux_data_from_node_meta(node_meta_from_root_tree)
            result.asset_node_aux_data = aux_data

    # Parse floating node trees (note: old style has no floating node trees)
    var flt_data: = result.editor_metadata.get(MetadataKeys.FloatingRoots, []) as Array
    for floating_tree in flt_data:
        if not floating_tree.get(MetadataKeys.NodeId, ""):
            push_warning("Floating node does not have a NodeId, skipping")
            continue
        var floating_root_id: String = floating_tree[MetadataKeys.NodeId]
        if floating_root_id in an_id_list:
            print_debug("Floating root node %s exists in another tree, assuming it was mistakenly added to floating tree roots, skipping" % floating_root_id)
            #continue
        
        # No inference hints for floating tree roots
        var floating_parse_result: = parse_asset_node_tree(false, floating_tree, {}, aux_data)
        if not floating_parse_result.success:
            push_warning("Failed to parse floating tree root at index %d" % flt_data.find(floating_tree))

        result.add_floating_result(floating_parse_result)
        an_id_list.append_array(floating_parse_result.get_an_id_list())
    
    result.success = true
    return result

func create_node_aux_data_from_node_meta(node_meta: Dictionary) -> Dictionary[String, HyAssetNode.AuxData]:
    var aux_data: Dictionary[String, HyAssetNode.AuxData] = {}
    for node_id in node_meta.keys():
        aux_data[node_id] = create_node_aux_data(node_meta[node_id])
    return aux_data

func create_node_aux_data(node_meta: Dictionary) -> HyAssetNode.AuxData:
    var node_aux_data: = HyAssetNode.AuxData.new()
    node_aux_data.position = deserialize_node_position(node_meta)
    node_aux_data.title = node_meta.get(MetadataKeys.NodeMetaTitle, "")
    return node_aux_data


func parse_asset_node_tree_with_node_meta(asset_node_data: Dictionary, inference_hints: Dictionary, node_meta: Dictionary) -> TreeParseResult:
    var aux_data: Dictionary[String, HyAssetNode.AuxData] = create_node_aux_data_from_node_meta(node_meta)
    return parse_asset_node_tree(false, asset_node_data, inference_hints, aux_data)

func parse_asset_node_tree(old_style: bool, asset_node_data: Dictionary, inference_hints: Dictionary, aux_data: Dictionary[String, HyAssetNode.AuxData] = {}) -> TreeParseResult:
    var root_node_aux: HyAssetNode.AuxData = aux_data.get(asset_node_data.get(MetadataKeys.NodeId, ""), null)

    var single_result: = parse_asset_node_shallow(old_style, asset_node_data, inference_hints, root_node_aux)
    if not single_result.success:
        print_debug("Failed to parse asset node %s" % asset_node_data.get(MetadataKeys.NodeId, ""))
        push_error("Failed to parse asset node %s" % asset_node_data.get(MetadataKeys.NodeId, ""))
        return failed_leaf_result(single_result)

    var cur_result: = TreeParseResult.new()
    cur_result.add_root(single_result)
    cur_result.root_node.shallow = false

    for conn_name in cur_result.root_node.connection_list:
        if cur_result.root_node.is_raw_connection_empty(conn_name):
            continue
        
        for conn_node_data in cur_result.root_node.get_raw_connected_nodes(conn_name):
            var conn_value_type: = SchemaManager.schema.get_an_connection_value_type(cur_result.root_node, conn_name)
            var infer_hints: Dictionary = { "output_value_type": conn_value_type }
            var branch_result: = parse_asset_node_tree(old_style, conn_node_data, infer_hints, aux_data)

            cur_result.merge_results(branch_result)
            if branch_result.root_node:
                cur_result.root_node.append_node_to_connection(conn_name, branch_result.root_node)
    
    return cur_result

func parse_asset_node_shallow(old_style: bool, asset_node_data: Dictionary, inference_hints: Dictionary, node_aux: HyAssetNode.AuxData) -> SingleParseResult:
    if not asset_node_data:
        print_debug("Asset node data is empty")
        return single_failed_result()
    
    var result: SingleParseResult = SingleParseResult.new()
    result.is_existing_node_id = true

    if old_style and not inference_hints.get("asset_node_type", ""):
        var type_key_val: String = asset_node_data.get("Type", "NO_TYPE_KEY")
        var hinted_output_value_type: String = inference_hints.get("output_value_type", "")
        if not hinted_output_value_type:
            print_debug("Old-style inferring node, no hinted output type, cannot infer type")
            push_warning("Old-style inferring node, no hinted output type, cannot infer type")
            return single_failed_result()

        var inferred_node_type: String = SchemaManager.schema.resolve_asset_node_type(type_key_val, hinted_output_value_type)
        if not inferred_node_type or inferred_node_type == "Unknown":
            print_debug("Old-style inferring node type failed, returning null")
            push_error("Old-style inferring node type failed, returning null")
            return single_failed_result()
        else:
            result.is_existing_node_id = false
            asset_node_data[MetadataKeys.NodeId] = get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(inferred_node_type))
    
    var asset_node_type: String = inference_hints.get("asset_node_type", "")
    if not asset_node_type:
        if not asset_node_data.get(MetadataKeys.NodeId, ""):
            result.is_existing_node_id = false
            var type_key: String = asset_node_data.get("Type", "NO_TYPE_KEY")
            var output_value_type: String = inference_hints.get("output_value_type", "")
            asset_node_type = SchemaManager.schema.resolve_asset_node_type(type_key, output_value_type)
            if not asset_node_type or asset_node_type == "Unknown":
                push_warning("No %s from node data, fallback using output value type and 'Type' key also failed, the node will have an Unknown type" % MetadataKeys.NodeId)
                return parse_schemaless_asset_node(asset_node_data, node_aux)

            asset_node_data[MetadataKeys.NodeId] = get_unique_an_id(SchemaManager.schema.get_id_prefix_for_node_type(asset_node_type))
        else:
            asset_node_type = SchemaManager.schema.infer_asset_node_type_from_id(asset_node_data[MetadataKeys.NodeId])

    if asset_node_type == "Unknown":
        return parse_schemaless_asset_node(asset_node_data, node_aux)
    
    assert(asset_node_data.get(MetadataKeys.NodeId, ""), "NodeId is required (should have been implicitly set if is old-style)")
    
    if old_style:
        result.old_style_metadata = {
            MetadataKeys.NodeMetaPosition: asset_node_data.get(MetadataKeys.NodeMetaPosition, {}).duplicate(),
        }
        if asset_node_data.get(MetadataKeys.NodeMetaTitle, ""):
            result.old_style_metadata[MetadataKeys.NodeMetaTitle] = asset_node_data.get(MetadataKeys.NodeMetaTitle, "")
    
    result.asset_node = HyAssetNode.new()
    var asset_node: = result.asset_node
    asset_node.an_node_id = asset_node_data[MetadataKeys.NodeId]
    if asset_node_type:
        asset_node.an_type = asset_node_type
    else:
        asset_node.an_type = SchemaManager.schema.infer_asset_node_type_from_id(asset_node_data[MetadataKeys.NodeId])
    
    var an_schema: Dictionary = {}
    if asset_node.an_type and asset_node.an_type != "Unknown":
        an_schema = SchemaManager.schema.node_schema.get(asset_node.an_type, {})
        if not an_schema:
            push_warning("Node schema not found for node type: %s" % asset_node.an_type)
            print_debug("Warning: Node schema not found for node type: %s" % asset_node.an_type)
    
    asset_node.raw_tree_data = asset_node_data.duplicate()
    
    setup_base_info_and_settings(asset_node, asset_node_data, an_schema, node_aux)
    var connection_names: Array[String] = get_connection_like_keys(asset_node_data, an_schema)
    for setting_name in asset_node.settings.keys():
        if setting_name in connection_names:
            connection_names.erase(setting_name)
    # fill out stuff in the data as settings even if it isn't in the schema
    add_unknown_settings(asset_node, asset_node_data, connection_names, an_schema)
    
    for conn_name in connection_names:
        if not asset_node.connection_list.has(conn_name):
            asset_node.connection_list.append(conn_name)
            asset_node.connected_node_counts[conn_name] = 0
    
    result.success = true
    return result

func parse_schemaless_asset_node(asset_node_data: Dictionary, node_aux: HyAssetNode.AuxData) -> SingleParseResult:
    var result: SingleParseResult = SingleParseResult.new()
    var asset_node = HyAssetNode.new()
    asset_node.raw_tree_data = asset_node_data.duplicate()
    result.asset_node = asset_node

    asset_node.an_node_id = asset_node_data.get(MetadataKeys.NodeId, "")
    if not asset_node.an_node_id:
        asset_node.an_node_id = get_new_id_for_schemaless_node()
        result.is_existing_node_id = false
    else:
        result.is_existing_node_id = true
    asset_node.an_type = "Unknown"
    
    setup_base_info_and_settings(asset_node, asset_node_data, {}, node_aux)
    
    var connection_like_keys: Array[String] = get_connection_like_keys(asset_node_data, {})
    add_unknown_settings(asset_node, asset_node_data, connection_like_keys, {})
    
    for conn_name in connection_like_keys:
        asset_node.connection_list.append(conn_name)
        asset_node.connected_node_counts[conn_name] = 0
    
    return result


func setup_base_info_and_settings(asset_node: HyAssetNode, node_data: Dictionary, an_schema: Dictionary, node_aux: HyAssetNode.AuxData = null) -> void:
    if asset_node.an_type == "Unknown":
        asset_node.default_title = "Generic Node"
    else:
        asset_node.default_title = SchemaManager.schema.get_node_type_default_name(asset_node.an_type)

    if node_aux:
        asset_node.title = node_aux.title
    elif node_data.get(MetadataKeys.NodeMetaTitle, ""):
        # old style format needs to set the title using the in-node metadata
        asset_node.title = str(node_data[MetadataKeys.NodeMetaTitle])

    if not asset_node.title:
        asset_node.title = asset_node.default_title
    
    if node_data.get(MetadataKeys.NodeComment, ""):
        # note: yes comments are stored in the node data not editor metadata
        asset_node.comment = str(node_data[MetadataKeys.NodeComment])
    
    var connections_schema: Dictionary = an_schema.get("connections", {})
    for conn_name in connections_schema.keys():
        asset_node.connection_list.append(conn_name)
        asset_node.connected_node_counts[conn_name] = 0
    
    var settings_schema: Dictionary = an_schema.get("settings", {})
    for setting_name in settings_schema.keys():
        asset_node.settings[setting_name] = settings_schema[setting_name].get("default_value", null)
        
        if node_data.has(setting_name):
            var gd_type: int = settings_schema[setting_name]["gd_type"]
            if gd_type == TYPE_ARRAY:
                var sub_gd_type: int = settings_schema[setting_name]["array_gd_type"]
                asset_node.settings[setting_name] = parse_individual_setting_data(node_data[setting_name], gd_type, sub_gd_type)
            else:
                asset_node.settings[setting_name] = parse_individual_setting_data(node_data[setting_name], gd_type)

func deserialize_group(group_data: Dictionary, new_name_func: Callable = Callable()) -> GraphFrame:
    var new_group: = GraphFrame.new()

    var raw_size: = Vector2(group_data.get(MetadataKeys.GroupWidth, 0), group_data.get(MetadataKeys.GroupHeight, 0))
    new_group.size = get_deserialize_scaled_pos(raw_size)

    var pos_meta: Dictionary = group_data.get(MetadataKeys.GroupPosition, {})
    var raw_pos: Vector2 = Vector2(pos_meta.get(MetadataKeys.GroupPosX, 0), pos_meta.get(MetadataKeys.GroupPosY, 0))
    new_group.position_offset = get_deserialize_offset_scaled_pos(raw_pos)

    new_group.title = group_data.get(MetadataKeys.GroupName, "Group")
    new_group.tooltip_text = new_group.title
    
    new_group.set_meta("has_custom_color", false)
    var chane_data: Dictionary = group_data.get(MetadataKeys.CHANE, {})
    if chane_data and chane_data.has(MetadataKeys.CHANEGroupAccentColor):
        new_group.set_meta("has_custom_color", true)
        new_group.set_meta("custom_color_name", chane_data[MetadataKeys.CHANEGroupAccentColor])
    
    if new_name_func.is_valid():
        new_group.name = new_name_func.call()
    return new_group

func deserialize_groups(from_metadata: Array, new_name_func: Callable = Callable()) -> Array[GraphFrame]:
    var groups: Array[GraphFrame] = []
    for group_data in from_metadata:
        groups.append(deserialize_group(group_data, new_name_func))
    return groups

func deserialize_node_position(node_metadata: Dictionary) -> Vector2:
    var pos_meta: Dictionary = node_metadata.get(MetadataKeys.NodeMetaPosition, {})
    var raw_pos: = Vector2(pos_meta.get(MetadataKeys.NodeMetaPosX, 0), pos_meta.get(MetadataKeys.NodeMetaPosY, 0))
    return get_deserialize_offset_scaled_pos(raw_pos)

func parse_individual_setting_data(raw_value: Variant, gd_type: int, sub_gd_type: int = -1) -> Variant:
    if gd_type == TYPE_INT:
        return roundi(float(raw_value))
    elif gd_type == TYPE_FLOAT:
        return float(raw_value)
    elif gd_type == TYPE_BOOL:
        return bool(raw_value)
    elif gd_type == TYPE_STRING:
        if not typeof(raw_value) == TYPE_STRING:
            print_debug("Warning: Setting is expected to be a string, but is not: %s" % [raw_value])
            push_warning("Setting is expected to be a string, but is not: %s" % [raw_value])
        return str(raw_value)
    elif gd_type == TYPE_ARRAY:
        if typeof(raw_value) != TYPE_ARRAY:
            push_error("Setting is expected to be an array, but is not: %s" % [raw_value])
            return []
        var array_val: Array = []
        for sub_raw_val in raw_value:
            array_val.append(parse_individual_setting_data(sub_raw_val, sub_gd_type))
        return array_val
    else:
        push_error("Unhandled setting gd type: %s" % [type_string(gd_type)])
        print_debug("Unhandled setting gd type: %s" % [type_string(gd_type)])
        return null

## Add other data that may be a setting but the node is schemaless or the setting isn't in the schema
func add_unknown_settings(asset_node: HyAssetNode, node_data: Dictionary, conn_keys: Array[String], an_schema: Dictionary) -> void:
    var settings_schema: Dictionary = an_schema.get("settings", {})
    
    for raw_key in node_data.keys():
        if raw_key.begins_with("$"):
            continue
        if asset_node.settings.has(raw_key) or settings_schema.has(raw_key) or conn_keys.has(raw_key):
            continue
        if an_schema.get("connections", {}).has(raw_key):
            continue

        asset_node.settings[raw_key] = node_data[raw_key]

func is_data_asset_node_like(data: Variant) -> bool:
    # TODO: do the proper checks here
    var data_type: int = typeof(data)
    if data_type == TYPE_DICTIONARY:
        return true
    elif data_type == TYPE_ARRAY:
        return true
    return false

func get_connection_like_keys(node_data: Dictionary, an_schema: Dictionary) -> Array[String]:
    var connection_like_keys: Array[String] = []
    connection_like_keys.append_array(an_schema.get("connections", {}).keys())
    
    for key in node_data.keys():
        if key.begins_with("$"):
            continue
        if is_data_asset_node_like(node_data[key]):
            connection_like_keys.append(key)
    return connection_like_keys

static func debug_dump_tree_results(tree_result: TreeParseResult) -> void:
    if not OS.has_feature("debug"):
        return
    if tree_result.success:
        print_debug("Tree results: All nodes succeeded")
        return
    
    print_debug("Failed parse asset node tree, results:")
    if tree_result.first_failure_at:
        print("  First failure at: %s (%s :: %s)" % [tree_result.first_failure_at.asset_node, tree_result.first_failure_at.asset_node.an_node_id, tree_result.first_failure_at.asset_node.an_type])
        print("    Is existing node ID: %s" % tree_result.first_failure_at.is_existing_node_id)

    var failure_count: int = 0
    for result in tree_result.all_nodes_results:
        if not result.success:
            failure_count += 1
    print("All Failures (%d):" % failure_count)
    for result in tree_result.all_nodes_results:
        if result.success:
            continue
        print("  Failed Node: %s (%s :: %s)" % [result.asset_node, result.asset_node.an_node_id, result.asset_node.an_type])
        print("    Is existing node ID: %s" % result.is_existing_node_id)


# Serializing

func clean_float_strictness(data: Dictionary) -> void:
    if not remove_all_point_zero:
        return
    enforce_int_for_integers(data)

func enforce_int_for_integers(data: Dictionary) -> void:
    for key in data.keys():
        if typeof(data[key]) == TYPE_FLOAT and is_integer_float(data[key]):
            data[key] = int(data[key])
        elif typeof(data[key]) == TYPE_ARRAY:
            enforce_int_for_integers_arr(data[key])
        elif typeof(data[key]) == TYPE_DICTIONARY:
            enforce_int_for_integers(data[key])

func enforce_int_for_integers_arr(data: Array) -> void:
    for i in data.size():
        if typeof(data[i]) == TYPE_FLOAT and is_integer_float(data[i]):
            data[i] = int(data[i])
        elif typeof(data[i]) == TYPE_ARRAY:
            enforce_int_for_integers_arr(data[i])
        elif typeof(data[i]) == TYPE_DICTIONARY:
            enforce_int_for_integers(data[i])

func is_integer_float(value: float) -> bool:
    return is_zero_approx(value - int(value))

func _node_meta_position(pos: Vector2) -> Dictionary:
    return { MetadataKeys.NodeMetaPosX: pos.x, MetadataKeys.NodeMetaPosY: pos.y, }

func get_serialize_scaled_pos(graph_pos: Vector2) -> Vector2:
    return (graph_pos / serialized_pos_scale).round()

func get_serialize_offset_scaled_pos(graph_pos: Vector2) -> Vector2:
    return get_serialize_scaled_pos(graph_pos - serialized_pos_offset)


func serialize_an_metadata_into(asset_node: HyAssetNode, graph_pos: Vector2, into_dict: Dictionary) -> void:
    into_dict[asset_node.an_node_id] = serialize_an_metadata(asset_node, graph_pos)

func serialize_an_metadata(asset_node: HyAssetNode, graph_pos: Vector2) -> Dictionary:
    var an_meta: = {
        MetadataKeys.NodeMetaPosition: _node_meta_position(get_serialize_offset_scaled_pos(graph_pos)),
    }
    if asset_node.title and asset_node.title != asset_node.default_title:
        an_meta[MetadataKeys.NodeMetaTitle] = asset_node.title
    return an_meta

## Creates plain dictionary data in the hytale asset json format, mimicking the format used by the official asset node editor
func serialize_entire_graph_as_asset(editor: CHANE_AssetNodeEditor) -> Dictionary:
    if editor.root_asset_node == null or editor.all_asset_nodes.size() == 0:
        print_debug("Serialize entire graph as asset: No root asset node or no asset nodes")
        return {}
    editor._pre_serialize()
    # Make sure the reference position and scale is set up
    serialized_pos_scale = editor.json_positions_scale
    serialized_pos_offset = Vector2.ZERO
    # The root asset node is also the root dictionary of the asset json format
    var serialized_data: Dictionary = serialize_asset_node_tree(editor.root_asset_node)
    # Floating trees are included in the node editor metadata
    serialized_data[MetadataKeys.NodeEditorMetadata] = serialize_node_editor_metadata(editor)
    clean_float_strictness(serialized_data)
    return serialized_data

func serialize_multiple_an_trees(an_trees: Array[HyAssetNode]) -> Array[Dictionary]:
    var serialized_an_trees: Array[Dictionary] = []
    for tree_root in an_trees:
        serialized_an_trees.append(serialize_asset_node_tree(tree_root))
    return serialized_an_trees

func serialize_node_editor_metadata(editor: CHANE_AssetNodeEditor) -> Dictionary:
    var root_an_pos: = editor.asset_node_aux_data[editor.root_asset_node.an_node_id].position
    var fallback_pos: = get_serialize_offset_scaled_pos(root_an_pos - Vector2(200, 200))

    var serialized_node_meta: Dictionary = serialize_ans_metadata(editor.get_all_asset_nodes(), editor.asset_node_aux_data, fallback_pos)
    var serialized_metadata: Dictionary = { MetadataKeys.NodesMeta: serialized_node_meta }

    serialized_metadata[MetadataKeys.FloatingRoots] = serialize_multiple_an_trees(editor.get_floating_an_tree_roots())
    
    serialized_metadata[MetadataKeys.Groups] = serialize_graph_edit_groups(editor)

    serialized_metadata[MetadataKeys.WorkspaceId] = editor.hy_workspace_id
    
    # include other metadata we found in the file but don't do anything with
    for other_key in editor.raw_metadata.keys():
        if serialized_metadata.has(other_key):
            continue
        serialized_metadata[other_key] = editor.raw_metadata[other_key]
    return serialized_metadata

func serialize_ans_metadata(asset_nodes: Array[HyAssetNode], asset_node_aux_data: Dictionary, fallback_pos: Vector2 = Vector2.ZERO) -> Dictionary:
    var serialized_metadata: Dictionary = {}
    for an in asset_nodes:
        var an_id: = an.an_node_id
        if not asset_node_aux_data.has(an_id):
            push_warning("No aux data for asset node %s, using fallback position" % an_id)
            serialized_metadata[an_id] = serialize_an_metadata(an, fallback_pos)
            continue
        
        var aux: = asset_node_aux_data[an_id] as HyAssetNode.AuxData
        assert(aux, "Unexpected value in aux_data for asset node %s : %s" % [an_id, asset_node_aux_data[an_id]])
        serialized_metadata[an_id] = serialize_an_metadata(an, aux.position)
    return serialized_metadata

func serialize_graph_edit_groups(editor: CHANE_AssetNodeEditor) -> Array[Dictionary]:
    return serialize_groups(editor.get_all_groups())

func serialize_groups(the_groups: Array[GraphFrame]) -> Array[Dictionary]:
    var serialized_groups: Array[Dictionary] = []
    for group in the_groups:
        serialized_groups.append(serialize_group(group))
    return serialized_groups

func serialize_group(group: GraphFrame) -> Dictionary:
    var adjusted_size: = get_serialize_scaled_pos(group.size)
    var adjusted_pos: = get_serialize_offset_scaled_pos(group.position_offset)

    var serialized_group: Dictionary = {
        MetadataKeys.GroupName: group.title,
        MetadataKeys.GroupPosition: {
            MetadataKeys.GroupPosX: adjusted_pos.x,
            MetadataKeys.GroupPosY: adjusted_pos.y,
        },
        MetadataKeys.GroupWidth: adjusted_size.x,
        MetadataKeys.GroupHeight: adjusted_size.y,
    }
    if group.get_meta("has_custom_color", false) and group.get_meta("custom_color_name", ""):
        serialized_group[MetadataKeys.CHANE] = {
            MetadataKeys.CHANEGroupAccentColor: group.get_meta("custom_color_name")
        }
    return serialized_group

## Creates plain dictionary data for saving to json of the limited asset node tree from the given node passing through only nodes included in the included_asset_nodes set
## returns an empty dictionary if the given asset node is not in the set
func serialize_asset_node_tree_within_set(asset_node: HyAssetNode, included_asset_nodes: Array[HyAssetNode]) -> Dictionary:
    if asset_node not in included_asset_nodes:
        return {}
    
    return serialize_asset_node_tree(asset_node, included_asset_nodes)

## Creates plain dictionary data for saving to json including the entire asset node tree from the given node
## if included_asset_nodes is provided, the tree will stop at any nodes not included in the set and that subtree will be omitted
func serialize_asset_node_tree(asset_node: HyAssetNode, included_asset_nodes: Array[HyAssetNode] = []) -> Dictionary:
    if asset_node.shallow:
        push_warning("Serializing unpopulated asset node (%s)" % asset_node.an_node_id)
        print_debug("Serializing unpopulated asset node (%s)" % asset_node.an_node_id)
        return asset_node.raw_tree_data.duplicate(true)
    
    var serialized_data: Dictionary = {MetadataKeys.NodeId: asset_node.an_node_id}
    if asset_node.comment:
        serialized_data[MetadataKeys.NodeComment] = asset_node.comment
    
    for other_key in asset_node.other_metadata.keys():
        serialized_data[other_key] = asset_node.other_metadata[other_key]
    
    var an_type: String = asset_node.an_type
    
    if not an_type or an_type == "Unknown" or not SchemaManager.schema.node_schema.has(an_type):
        print_debug("Warning: Serializing an asset node with unknown type: %s (%s)" % [an_type, asset_node.an_node_id])
        push_warning("Warning: Serializing an asset node with unknown type: %s (%s)" % [an_type, asset_node.an_node_id])
        serialized_data[MetadataKeys.CHANE] = { "no_schema": true }
        # handling "Type" key
        if "Type" in asset_node.raw_tree_data:
            serialized_data["Type"] = asset_node.raw_tree_data["Type"]
        # settings
        for setting_key in asset_node.settings.keys():
            serialized_data[setting_key] = asset_node.settings[setting_key]
        # subtree
        for conn_name in asset_node.connection_list:
            var num_connected: = asset_node.num_connected_asset_nodes(conn_name)
            if num_connected == 0:
                continue

            if num_connected > 1:
                serialized_data[conn_name] = []
                for connected_an in asset_node.get_all_connected_nodes(conn_name):
                    if not included_asset_nodes or connected_an in included_asset_nodes:
                        serialized_data[conn_name].append(serialize_asset_node_tree(connected_an, included_asset_nodes))
            else:
                var connected_an: = asset_node.get_connected_node(conn_name, 0)
                if not included_asset_nodes or connected_an in included_asset_nodes:
                    serialized_data[conn_name] = serialize_asset_node_tree(connected_an, included_asset_nodes)
    else:
        var an_schema: = SchemaManager.schema.node_schema[an_type]
        
        # handling "Type" key
        var serialized_type_key: Variant = SchemaManager.schema.connection_type_node_type_lookup.find_key(an_type)
        if serialized_type_key and serialized_type_key.split("|", false).size() > 1:
            serialized_data["Type"] = serialized_type_key.split("|")[1]

        # settings
        var an_settings: = asset_node.settings
        for setting_key in an_schema.get("settings", {}).keys():
            var gd_type: int = an_schema["settings"][setting_key]["gd_type"]
            var sub_gd_type: int = an_schema["settings"][setting_key].get("array_gd_type", -1)
            var serialized_value: Variant = serialize_individual_setting_data(an_settings[setting_key], gd_type, sub_gd_type)
            if serialized_value != null:
                serialized_data[setting_key] = serialized_value

        # subtree
        for conn_name in an_schema.get("connections", {}).keys():
            var num_connected: = asset_node.num_connected_asset_nodes(conn_name)
            if num_connected == 0:
                # default behavior is to not include empty connections as keys
                continue
            var connected_nodes: Array[Dictionary] = []
            for connected_an in asset_node.get_all_connected_nodes(conn_name):
                if not included_asset_nodes or connected_an in included_asset_nodes:
                    connected_nodes.append(serialize_asset_node_tree(connected_an, included_asset_nodes))

            if an_schema["connections"][conn_name].get("multi", false):
                serialized_data[conn_name] = connected_nodes
            else:
                serialized_data[conn_name] = connected_nodes[0]

    return serialized_data

func serialize_individual_setting_data(raw_value: Variant, gd_type: int, sub_gd_type: int = -1) -> Variant:
    if gd_type == TYPE_STRING:
        if str(raw_value) == "":
            return null
    elif gd_type == TYPE_BOOL:
        return bool(raw_value)
    elif gd_type == TYPE_INT:
        if typeof(raw_value) == TYPE_FLOAT:
            return roundi(raw_value)
        elif typeof(raw_value) == TYPE_STRING:
            return roundi(float(raw_value))
    elif gd_type == TYPE_ARRAY:
        if sub_gd_type == TYPE_INT and typeof(raw_value) == TYPE_ARRAY:
            var arr: Array[int] = []
            for i in raw_value.size():
                if typeof(raw_value[i]) == TYPE_INT:
                    arr.append(raw_value[i])
                else:
                    arr.append(roundi(float(raw_value[i])))
            return arr

    return raw_value


# Helpers for working with fragments

func deserialize_fragment_as_full_graph(asset_node_data: Array[Dictionary], editor_metadata: Dictionary) -> EntireGraphParseResult:
    var result: = EntireGraphParseResult.new()
    var node_meta: Dictionary = editor_metadata.get(MetadataKeys.NodesMeta, {})
    result.asset_node_aux_data = create_node_aux_data_from_node_meta(node_meta)

    for tree_root_data in asset_node_data:
        var inference_hints: = {
            "asset_node_type": tree_root_data.get(MetadataKeys.CHANE, {}).get("asset_node_type", "")
        }
        var root_parse_result: = parse_asset_node_tree(result.was_old_style_format, tree_root_data, inference_hints, result.asset_node_aux_data)
        result.add_floating_result(root_parse_result)
        if not root_parse_result.success:
            push_error("Failed to parse asset node tree root")
            result.success = false
            return result
        HyAssetNode.AuxData.update_aux_parents_for_tree(root_parse_result.root_node, result.asset_node_aux_data)
    return result