extends CustomGraphNode
class_name ManualCurveSpecialGN

const HToggleButtons = preload("res://ui/h_toggle_buttons.gd")

var graph_edit: AssetNodeGraphEdit
var asset_node: HyAssetNode

var my_points: Array[Vector2] = []

var points_table: GridContainer
var graph_container: MarginContainer
@onready var mode_buttons: HToggleButtons = $ModeButtons
@onready var new_point_button: Button = $NewPointButton

@export var curve_plot: CurvePlot

const POINTS_CONNECTION_NAME: String = "Points"

@export var cur_mode: String = "table"
var last_size: Dictionary = {
    "table": Vector2.ZERO,
    "graph": Vector2.ZERO,
}

func _notification(what: int) -> void:
    if what == NOTIFICATION_SCENE_INSTANTIATED:
        points_table = $PointsTable
        graph_container = $GraphContainer

func _ready() -> void:
    graph_container.add_theme_constant_override("margin_bottom", ANESettings.GRAPH_NODE_MARGIN_BOTTOM_EXTRA)
    setup_ports()
    if not graph_edit.zoom_changed.is_connected(on_zoom_changed):
        graph_edit.zoom_changed.connect(on_zoom_changed)
    mode_buttons.allow_all_off = false
    mode_buttons.option_changed.connect(on_mode_changed)
    new_point_button.pressed.connect(add_new_point)

    show_nodes_for_mode(cur_mode)
    #last_size[cur_mode] = size
    if not resized.is_connected(on_resized):
        resized.connect(on_resized)

func setup_ports() -> void:
    # note, don't need to add a child control to enable the first port because there's already multiple children from the scene
    set_slot_enabled_left(0, true)
    set_slot_type_left(0, graph_edit.type_id_lookup["Curve"])

func get_current_connection_list() -> Array[String]:
    return []

func filter_child_connection_nodes(_conn_name: String) -> Array[HyAssetNode]:
    return []

func get_own_asset_nodes() -> Array[HyAssetNode]:
    var ans: Array[HyAssetNode] = [asset_node]
    ans.append_array(asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME))
    return ans


func on_resized() -> void:
    last_size[cur_mode] = size

func on_zoom_changed(new_zoom: float) -> void:
    curve_plot.cur_zoom = new_zoom
    if graph_container.visible:
        curve_plot.queue_redraw()

func load_points_from_an_connection() -> void:
    var cur_minimum_height: float = get_combined_minimum_size().y
    var should_shrink: = false
    if cur_mode == "table":
        should_shrink = cur_minimum_height >= minf(size.y, last_size[cur_mode].y)
    my_points.clear()
    for point_asset_node in asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME):
        my_points.append(Vector2(point_asset_node.settings["In"], point_asset_node.settings["Out"]))
    refresh_table_rows(should_shrink)

func remove_point_at(row_idx: int) -> void:
    var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
    asset_node.remove_node_from_connection_at(POINTS_CONNECTION_NAME, row_idx)
    graph_edit.remove_asset_node(point_asset_node)
    load_points_from_an_connection()

func refresh_table_rows(should_shrink: bool) -> void:
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
    
    if should_shrink:
        size.y = 0
        if size.y < last_size[cur_mode].y:
            last_size[cur_mode] = size


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
    new_mode_name = new_mode_name.to_lower()
    if new_mode_name == cur_mode:
        return
    
    last_size[cur_mode] = size
    cur_mode = new_mode_name

    show_nodes_for_mode(new_mode_name)
    size = last_size[new_mode_name]

func show_nodes_for_mode(the_mode: String) -> void:
    if the_mode == "table":
        points_table.show()
        new_point_button.show()
        graph_container.hide()
    else:
        points_table.hide()
        new_point_button.hide()
        graph_container.show()
        curve_plot.update_curve(my_points)

func add_new_point() -> void:
    var new_curve_point_an: HyAssetNode = graph_edit.get_new_asset_node("CurvePoint")
    var last_point_vec: Vector2 = my_points.back() if my_points else Vector2.ZERO
    new_curve_point_an.settings["In"] = snappedf(last_point_vec.x + 0.01, 0.01)
    new_curve_point_an.settings["Out"] = last_point_vec.y
    asset_node.append_node_to_connection("Points", new_curve_point_an)
    load_points_from_an_connection()