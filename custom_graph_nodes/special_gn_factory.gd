extends Node
class_name SpecialGNFactory

var types_with_special_nodes: Array[String] = [
    "ManualCurve",
]

var graph_edit: AssetNodeGraphEdit

func _ready() -> void:
    graph_edit = get_parent() as AssetNodeGraphEdit

func make_duplicate_special_gn(special_gn: CustomGraphNode, asset_node_set: Array[HyAssetNode]) -> CustomGraphNode:
    var main_asset_node: HyAssetNode = graph_edit.safe_get_an_from_gn(special_gn, asset_node_set)
    if not main_asset_node or not main_asset_node.an_type in types_with_special_nodes:
        print_debug("Main asset node not found or not in types_with_special_nodes, cannot make duplicate special GN")
        push_warning("Main asset node not found or not in types_with_special_nodes, cannot make duplicate special GN")
        return null

    if OS.has_feature("debug"):
        for owned_asset_node in graph_edit.get_gn_own_asset_nodes(special_gn):
            assert(owned_asset_node in asset_node_set, "Owned asset node %s not in the set of duplicatable asset nodes" % owned_asset_node.an_node_id)

    var new_main_an = graph_edit.duplicate_and_add_filtered_an_tree(main_asset_node, asset_node_set)
    var new_special_gn: CustomGraphNode = call("make_special_%s" % main_asset_node.an_type, new_main_an, false) as CustomGraphNode
    new_special_gn.set_meta("is_special_gn", true)
    return new_special_gn
    

func make_special_gn(target_asset_node: HyAssetNode, is_new: bool = false) -> CustomGraphNode:
    if not target_asset_node.an_type in types_with_special_nodes:
        print_debug("Target asset node type %s is not in types_with_special_nodes, cannot make special GN" % target_asset_node.an_type)
        return null
    
    var special_gn: = call("make_special_%s" % target_asset_node.an_type, target_asset_node, is_new) as CustomGraphNode
    special_gn.set_meta("is_special_gn", true)
    return special_gn

func make_special_ManualCurve(target_asset_node: HyAssetNode, is_new: bool) -> CustomGraphNode:
    var new_manual_curve_gn: ManualCurveSpecialGN = preload("res://custom_graph_nodes/manual_curve_special.tscn").instantiate()
    new_manual_curve_gn.set_meta("hy_asset_node_id", target_asset_node.an_node_id)
    new_manual_curve_gn.asset_node = target_asset_node
    new_manual_curve_gn.graph_edit = graph_edit

    if not is_new:
        new_manual_curve_gn.load_points_from_an_connection()
    else:
        for i in 2:
            var new_curve_point_an: HyAssetNode = graph_edit.get_new_asset_node("CurvePoint")
            new_curve_point_an.settings["In"] = float(i)
            new_curve_point_an.settings["Out"] = float(i)
            target_asset_node.append_node_to_connection("Points", new_curve_point_an)
        new_manual_curve_gn.load_points_from_an_connection()

    return new_manual_curve_gn as CustomGraphNode