extends CustomGraphNode
class_name ManualCurveSpecialGN

var graph_edit: AssetNodeGraphEdit
var asset_node: HyAssetNode

var my_points: Array[Vector2] = []

const POINTS_CONNECTION_NAME: String = "Points"

func get_current_connection_list() -> Array[String]:
    #setup_asset_node()
    return []

func filter_child_connection_nodes(conn_name: String) -> Array[HyAssetNode]:
    #setup_asset_node()
    return []

func setup(the_graph_edit: AssetNodeGraphEdit) -> void:
    graph_edit = the_graph_edit
    setup_asset_node()

func setup_asset_node() -> void:
    if not graph_edit:
        graph_edit = get_parent() as AssetNodeGraphEdit
    if not asset_node:
        var an_id: String = get_meta("hy_asset_node_id", "")
        if an_id not in graph_edit.an_lookup:
            print_debug("Asset node with ID %s not found in lookup" % an_id)
            return
        asset_node = graph_edit.an_lookup[an_id]

func load_points_from_connection() -> void:
    my_points.clear()
    for point_asset_node in asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME):
        my_points.append(Vector2(point_asset_node.settings["In"], point_asset_node.settings["Out"]))
    _points_changed()

func _points_changed() -> void:
    pass