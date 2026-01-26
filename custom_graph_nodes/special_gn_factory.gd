extends Node
class_name SpecialGNFactory

var types_with_special_nodes: Array[String] = [
    "ManualCurve",
]

var graph_edit: AssetNodeGraphEdit

func _ready() -> void:
    graph_edit = get_parent() as AssetNodeGraphEdit

func make_special_gn(root_asset_node: HyAssetNode, target_asset_node: HyAssetNode) -> CustomGraphNode:
    if not target_asset_node.an_type in types_with_special_nodes:
        print_debug("Target asset node type %s is not in types_with_special_nodes, cannot make special GN" % target_asset_node.an_type)
        return null
    
    var special_gn: = call("make_special_%s" % target_asset_node.an_type, root_asset_node, target_asset_node) as CustomGraphNode
    special_gn.set_meta("is_special_gn", true)
    return special_gn

func make_special_ManualCurve(_root_asset_node: HyAssetNode, target_asset_node: HyAssetNode) -> CustomGraphNode:
    var new_manual_curve_gn: ManualCurveSpecialGN = preload("res://custom_graph_nodes/manual_curve_special.tscn").instantiate()
    new_manual_curve_gn.set_meta("hy_asset_node_id", target_asset_node.an_node_id)
    new_manual_curve_gn.asset_node = target_asset_node
    new_manual_curve_gn.graph_edit = graph_edit
    new_manual_curve_gn.load_points_from_connection()
    return new_manual_curve_gn as CustomGraphNode