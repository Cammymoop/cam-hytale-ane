extends Node
class_name SpecialGNFactory

var types_with_special_nodes: Array[String] = [
    "ManualCurve",
]

var graph_edit: AssetNodeGraphEdit

func _ready() -> void:
    graph_edit = get_parent() as AssetNodeGraphEdit

func make_special_gn(root_asset_node: HyAssetNode, target_asset_node: HyAssetNode, is_new: bool = false) -> CustomGraphNode:
    if not target_asset_node.an_type in types_with_special_nodes:
        print_debug("Target asset node type %s is not in types_with_special_nodes, cannot make special GN" % target_asset_node.an_type)
        return null
    
    var special_gn: = call("make_special_%s" % target_asset_node.an_type, root_asset_node, target_asset_node, is_new) as CustomGraphNode
    special_gn.set_meta("is_special_gn", true)
    return special_gn

func make_special_ManualCurve(_root_asset_node: HyAssetNode, target_asset_node: HyAssetNode, is_new: bool) -> CustomGraphNode:
    var new_manual_curve_gn: ManualCurveSpecialGN = preload("res://custom_graph_nodes/manual_curve_special.tscn").instantiate()
    new_manual_curve_gn.set_meta("hy_asset_node_id", target_asset_node.an_node_id)
    new_manual_curve_gn.asset_node = target_asset_node
    new_manual_curve_gn.graph_edit = graph_edit

    if not is_new:
        new_manual_curve_gn.load_points_from_connection()
    else:
        for i in 2:
            var new_curve_point_an: HyAssetNode = graph_edit.get_new_asset_node("CurvePoint")
            new_curve_point_an.settings["In"] = float(i)
            new_curve_point_an.settings["Out"] = float(i)
            target_asset_node.append_connection("Points", new_curve_point_an)
        new_manual_curve_gn.load_points_from_connection()

    return new_manual_curve_gn as CustomGraphNode