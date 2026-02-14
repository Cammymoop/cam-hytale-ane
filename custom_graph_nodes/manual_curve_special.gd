extends CustomGraphNode
class_name ManualCurveSpecialGN

const HToggleButtons = preload("res://ui/h_toggle_buttons.gd")

var graph_edit: AssetNodeGraphEdit
var asset_node: HyAssetNode

var my_points: Array[Vector2] = []

var next_adjust_is_new: bool = true

var points_table: GridContainer
var graph_container: MarginContainer
@onready var mode_buttons: HToggleButtons = find_child("ModeButtons")
@onready var extra_settings_menu_btn: MenuButton = find_child("ExtraSettingsBtn")
@onready var extra_settings_menu: PopupMenu = extra_settings_menu_btn.get_popup()
@onready var new_point_button: Button = $NewPointButton
@onready var export_as_edit: CustomLineEdit = find_child("SettingEdit_ExportAs")

@export var curve_plot: CurvePlot

const POINTS_CONNECTION_NAME: String = "Points"

@export var cur_mode: String = "table"
var last_size: Dictionary = {
    "table": Vector2.ZERO,
    "graph": Vector2.ZERO,
}

func _notification(what: int) -> void:
    # get references to children here, this allows calling methods which use these references
    # immediately after the manual curve node scene is instantiated before adding to the scene tree
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
    mode_buttons.set_text_pressed(cur_mode)

    new_point_button.pressed.connect(add_new_point_auto)
    
    extra_settings_menu_btn.about_to_popup.connect(update_extra_settings_menu)
    extra_settings_menu.index_pressed.connect(on_extra_settings_menu_index_pressed)

    _set_mode_to(cur_mode)
    #last_size[cur_mode] = size
    if not resized.is_connected(on_resized):
        resized.connect(on_resized)
    
    curve_plot.set_as_manual_curve()
    curve_plot.points_changed.connect(replace_points)
    curve_plot.points_adjusted.connect(adjust_points)
    curve_plot.points_adjustment_ended.connect(points_adjustment_ended)
    curve_plot.delete_point.connect(remove_point_at)
    
    make_settings_syncer(asset_node)
    settings_syncer.updated_from_asset_node.connect(on_settings_syncer_updated_from_asset_node)
    settings_syncer.add_watched_setting("ExportAs", export_as_edit, TYPE_STRING)

    if not asset_node.settings.get("ExportAs", ""):
        export_as_edit.get_parent().hide()
    export_as_edit.focus_exited.connect(check_show_export_as)

# REQUIRED METHODS FOR SPECIAL GRAPH NODES::

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

# end REQUIRED METHODS FOR SPECIAL GRAPH NODES::


func on_resized() -> void:
    last_size[cur_mode] = size

func on_zoom_changed(new_zoom: float) -> void:
    curve_plot.cur_zoom = new_zoom
    if graph_container.visible:
        curve_plot.queue_redraw()

func load_points_from_an_connection() -> void:
    my_points.clear()
    for point_asset_node in asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME):
        my_points.append(Vector2(point_asset_node.settings["In"], point_asset_node.settings["Out"]))
    refresh_points_displayed()

func refresh_points_displayed() -> void:
    if cur_mode == "table":
        refresh_table_rows()
    elif cur_mode == "graph":
        curve_plot.update_curve(my_points)

## Creates undo step
func remove_point_at(row_idx: int) -> void:
    var old_points: = my_points.duplicate()
    var asset_node_count: = asset_node.num_connected_asset_nodes(POINTS_CONNECTION_NAME)
    if row_idx < 0 or row_idx >= asset_node_count:
        push_warning("manual curve special: remove point index %s is out of range %s-%s" % [row_idx, 0, asset_node_count - 1])
    var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
    asset_node.remove_node_from_connection_at(POINTS_CONNECTION_NAME, row_idx)
    graph_edit.remove_asset_node(point_asset_node)
    load_points_from_an_connection()
    
    create_points_change_undo_step(old_points)

func get_table_should_shrink() -> bool:
    var cur_minimum_height: float = get_combined_minimum_size().y
    var should_shrink: = false
    if cur_mode == "table":
        should_shrink = cur_minimum_height >= minf(size.y, last_size[cur_mode].y)
    return should_shrink

func refresh_table_rows() -> void:
    var should_shrink: = get_table_should_shrink()

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


## Creates undo step
func table_value_changed(new_value: float, row_idx: int, is_in: bool) -> void:
    var old_points: = my_points.duplicate()
    my_points[row_idx][0 if is_in else 1] = new_value
    update_ans_from_my_points()
    
    create_points_change_undo_step(old_points)

## Creates undo step if with_undo = true (default)
func replace_points(new_points: Array[Vector2], with_undo: bool = true) -> void:
    var old_points: = my_points.duplicate()
    my_points = new_points
    if not with_undo:
        prints("replacing points, old: %s, new: %s" % [old_points, new_points])
    update_ans_from_my_points()
    if not with_undo:
        prints("refreshing displayed points")
    refresh_points_displayed()
    
    if with_undo:
        create_points_change_undo_step(old_points)

## Creates undo step that collapses with repeated calls
func adjust_points(new_points: Array[Vector2]) -> void:
    var old_points: = my_points.duplicate()
    my_points = new_points
    update_ans_from_my_points()
    create_points_adj_undo_step(old_points)
    next_adjust_is_new = false

func points_adjustment_ended() -> void:
    next_adjust_is_new = true

func update_ans_from_my_points() -> void:
    resize_ans_from_my_points()
    for row_idx in my_points.size():
        var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
        point_asset_node.settings["In"] = my_points[row_idx].x
        point_asset_node.settings["Out"] = my_points[row_idx].y

func resize_ans_from_my_points() -> void:
    var cur_an_count: int = asset_node.num_connected_asset_nodes(POINTS_CONNECTION_NAME)
    if cur_an_count == my_points.size():
        return
    if cur_an_count < my_points.size():
        for i in my_points.size() - cur_an_count:
            _add_new_point_unchecked()
    else:
        for i in cur_an_count - my_points.size():
            _pop_asset_node_point()

func table_x_button_pressed(row_idx: int) -> void:
    remove_point_at(row_idx)

func get_table_label(with_text: String) -> Label:
    var new_label: = Label.new()
    new_label.text = with_text
    return new_label

func get_table_input_field(with_value: String) -> GNNumberEdit:
    var new_input_field: = GNNumberEdit.new()
    new_input_field.expand_to_text_length = true
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
    _set_mode_to(new_mode_name)
    
func _set_mode_to(new_mode_name: String) -> void:
    if cur_mode == "graph":
        curve_plot.hiding()
    
    cur_mode = new_mode_name
    show_nodes_for_mode(new_mode_name)
    size = last_size[new_mode_name]
    
    refresh_points_displayed()

func show_nodes_for_mode(the_mode: String) -> void:
    if the_mode == "table":
        points_table.show()
        new_point_button.show()
        graph_container.hide()
    else:
        points_table.hide()
        new_point_button.hide()
        graph_container.show()

## Creates undo step if refresh_view = true
func add_new_point_auto(refresh_view: bool = true) -> void:
    var new_point_pos: Vector2 = Vector2.ZERO
    if my_points.size() == 1:
        new_point_pos = Vector2(snappedf(my_points[0].x + 0.01, 0.01), my_points[0].y)
    elif my_points.size() > 1:
        var last_point_pos: Vector2 = my_points[my_points.size() - 1]
        var prev_point_pos: Vector2 = my_points[my_points.size() - 2]
        if absf(last_point_pos.x - prev_point_pos.x) < 0.2:
            new_point_pos = Vector2(snappedf(last_point_pos.x + 1, 0.01), last_point_pos.y)
        else:
            new_point_pos = Vector2(snappedf(last_point_pos.x + 0.01, 0.01), last_point_pos.y)

    _add_new_point_unchecked(new_point_pos)

    if refresh_view:
        var old_points: = my_points.duplicate()
        load_points_from_an_connection()
        create_points_change_undo_step(old_points)

func _add_new_point_unchecked(with_pos: Vector2 = Vector2.ZERO) -> HyAssetNode:
    var new_curve_point_an: HyAssetNode = graph_edit.get_new_asset_node("CurvePoint")
    new_curve_point_an.settings["In"] = with_pos.x
    new_curve_point_an.settings["Out"] = with_pos.y
    asset_node.append_node_to_connection("Points", new_curve_point_an)
    return new_curve_point_an

func _pop_asset_node_point() -> void:
    var popped_node: HyAssetNode = asset_node.pop_node_from_connection(POINTS_CONNECTION_NAME)
    graph_edit.remove_asset_node(popped_node)


func undo_redo_change_points(points_to_restore: Array[Vector2]) -> void:
    replace_points(points_to_restore, false)

func create_points_change_undo_step(old_points: Array[Vector2]) -> void:
    graph_edit.undo_manager.create_action("Change Manual Curve Points")

    graph_edit.undo_manager.add_do_method(undo_redo_change_points.bind(my_points.duplicate()))

    graph_edit.undo_manager.add_undo_method(undo_redo_change_points.bind(old_points.duplicate()))

    graph_edit.undo_manager.commit_action(false)

func create_points_adj_undo_step(old_points: Array[Vector2]) -> void:
    var merge_mode: = UndoRedo.MERGE_DISABLE if next_adjust_is_new else UndoRedo.MERGE_ENDS
    graph_edit.undo_manager.create_action("Move Manual Curve Points", merge_mode)

    graph_edit.undo_manager.add_do_method(undo_redo_change_points.bind(my_points.duplicate()))

    graph_edit.undo_manager.add_undo_method(undo_redo_change_points.bind(old_points.duplicate()))

    graph_edit.undo_manager.commit_action(false)


func update_extra_settings_menu() -> void:
    for i in extra_settings_menu.item_count:
        if extra_settings_menu.is_item_separator(i):
            continue
        var item_text: = extra_settings_menu.get_item_text(i)
        if item_text == "ExportAs":
            extra_settings_menu.set_item_checked(i, asset_node.settings.get("ExportAs", "") != "")

func on_extra_settings_menu_index_pressed(index: int) -> void:
    var pressed_text: = extra_settings_menu.get_item_text(index)
    if pressed_text == "ExportAs":
        var cur_export_as: String = asset_node.settings.get("ExportAs", "")
        if cur_export_as:
            asset_node.update_setting_value("ExportAs", "")
        else:
            export_as_edit.get_parent().show()
            export_as_edit.grab_focus()
        
func on_settings_syncer_updated_from_asset_node() -> void:
    check_show_export_as()

func check_show_export_as() -> void:
    if asset_node.settings.get("ExportAs", ""):
        export_as_edit.get_parent().show()
    else:
        export_as_edit.get_parent().hide()