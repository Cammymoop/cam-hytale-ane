extends Node

const GraphNodeFactory = preload("res://graph_editor/custom_graph_nodes/graph_node_factory.gd")

var types_with_special_nodes: Array[String] = [
    "ManualCurve",
]

var editor: CHANE_AssetNodeEditor

func _enter_tree() -> void:
    editor = get_parent() as CHANE_AssetNodeEditor
    if not editor:
        editor = get_parent().get_parent() as CHANE_AssetNodeEditor

func make_special_gn(target_asset_node: HyAssetNode, is_new: bool = false) -> CustomGraphNode:
    if not target_asset_node.an_type in types_with_special_nodes:
        print_debug("Target asset node type %s is not in types_with_special_nodes, cannot make special GN" % target_asset_node.an_type)
        return null
    
    var special_gn: = call("make_special_%s" % target_asset_node.an_type, target_asset_node, is_new) as CustomGraphNode
    special_gn.set_meta("is_special_gn", true)
    return special_gn

func make_special_ManualCurve(target_asset_node: HyAssetNode, is_new: bool) -> CustomGraphNode:
    var new_manual_curve_gn: ManualCurveSpecialGN = preload("res://graph_editor/custom_graph_nodes/manual_curve_special.tscn").instantiate()
    new_manual_curve_gn.set_meta("hy_asset_node_id", target_asset_node.an_node_id)
    new_manual_curve_gn.asset_node = target_asset_node
    new_manual_curve_gn.editor = editor
    
    var node_schema: Dictionary = SchemaManager.schema.node_schema[target_asset_node.an_type]
    (get_parent() as GraphNodeFactory).setup_base_output_input_info(new_manual_curve_gn, target_asset_node, node_schema)
    new_manual_curve_gn.num_inputs = 0

    if not is_new:
        new_manual_curve_gn.load_points_from_an_connection(true)
    else:
        new_manual_curve_gn.replace_points([Vector2(0, 1), Vector2(1, 0)])
        new_manual_curve_gn.load_points_from_an_connection()

    return new_manual_curve_gn as CustomGraphNode

func should_be_special_gn(asset_node: HyAssetNode) -> bool:
    return types_with_special_nodes.has(asset_node.an_type)