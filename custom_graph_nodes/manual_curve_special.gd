extends CustomGraphNode
class_name ManualCurveSpecialGN

const HToggleButtons = preload("res://ui/h_toggle_buttons.gd")

var graph_edit: AssetNodeGraphEdit
var asset_node: HyAssetNode

var my_points: Array[Vector2] = []

var points_table: GridContainer
var graph_container: Control
@onready var mode_buttons: HToggleButtons = $ModeButtons
@onready var new_point_button: Button = $NewPointButton

const POINTS_CONNECTION_NAME: String = "Points"

func _ready() -> void:
    setup_graph_container()
    mode_buttons.allow_all_off = false
    mode_buttons.option_changed.connect(on_mode_changed)
    new_point_button.pressed.connect(add_new_point)

func get_current_connection_list() -> Array[String]:
    #setup_asset_node()
    return []

func filter_child_connection_nodes(_conn_name: String) -> Array[HyAssetNode]:
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

func get_own_asset_nodes() -> Array[HyAssetNode]:
    var ans: Array[HyAssetNode] = [asset_node]
    ans.append_array(asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME))
    return ans

func setup_points_table() -> void:
    if not points_table:
        points_table = $PointsTable

func setup_graph_container() -> void:
    if not graph_container:
        graph_container = $GraphContainer

func load_points_from_an_connection() -> void:
    my_points.clear()
    for point_asset_node in asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME):
        my_points.append(Vector2(point_asset_node.settings["In"], point_asset_node.settings["Out"]))
    refresh_table_rows()

func remove_point_at(row_idx: int) -> void:
    prints("removing point at %s" % row_idx)
    var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
    asset_node.remove_node_from_connection_at(POINTS_CONNECTION_NAME, row_idx)
    graph_edit.remove_asset_node(point_asset_node)
    load_points_from_an_connection()

func refresh_table_rows() -> void:
    setup_points_table()
    for c in points_table.get_children():
        points_table.remove_child(c)
        c.queue_free()
    
    for row_idx in my_points.size():
        points_table.add_child(get_table_label("in"))
        var in_input_field: = get_table_input_field(str(my_points[row_idx].x))
        in_input_field.val_changed.connect(table_value_changed.bind(row_idx, true))
        points_table.add_child(in_input_field)
        points_table.add_child(get_table_label("out"))
        var out_input_field: = get_table_input_field(str(my_points[row_idx].y))
        out_input_field.val_changed.connect(table_value_changed.bind(row_idx, false))
        points_table.add_child(out_input_field)
        var x_button: = get_table_x_button()
        points_table.add_child(x_button)
        x_button.pressed.connect(table_x_button_pressed.bind(row_idx))
    
    refresh_min_size()

func table_value_changed(new_value: float, row_idx: int, is_in: bool) -> void:
    my_points[row_idx][0 if is_in else 1] = new_value
    update_ans_from_my_points()

func update_ans_from_my_points() -> void:
    for row_idx in my_points.size():
        var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
        point_asset_node.settings["In"] = my_points[row_idx].x
        point_asset_node.settings["Out"] = my_points[row_idx].y

func table_x_button_pressed(row_idx: int) -> void:
    remove_point_at(row_idx)

func get_table_label(with_text: String) -> Label:
    var new_label: = Label.new()
    new_label.text = with_text
    return new_label

func get_table_input_field(with_value: String) -> GNNumberEdit:
    var new_input_field: = GNNumberEdit.new()
    new_input_field.set_value_directly(float(with_value))
    new_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return new_input_field

func get_table_x_button() -> Button:
    var new_button: = Button.new()
    new_button.text = "x"
    return new_button

func on_mode_changed(new_mode_name: String) -> void:
    if new_mode_name.to_lower() == "table":
        points_table.show()
        new_point_button.show()
        graph_container.hide()
        refresh_min_size()
    else:
        points_table.hide()
        new_point_button.hide()
        graph_container.show()
        refresh_min_size()

func add_new_point() -> void:
    var new_curve_point_an: HyAssetNode = graph_edit.get_new_asset_node("CurvePoint")
    var last_point_vec: Vector2 = my_points.back() if my_points else Vector2.ZERO
    new_curve_point_an.settings["In"] = snappedf(last_point_vec.x + 0.01, 0.01)
    new_curve_point_an.settings["Out"] = last_point_vec.y
    asset_node.append_node_to_connection("Points", new_curve_point_an)
    load_points_from_an_connection()

func refresh_min_size() -> void:
    size = Vector2(0, 0)