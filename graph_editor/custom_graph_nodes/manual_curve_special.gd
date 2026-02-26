extends CustomGraphNode
class_name ManualCurveSpecialGN

const HToggleButtons = preload("res://ui/custom_controls/h_toggle_buttons.gd")

const UndoStep: = preload("res://graph_editor/undo_redo/undo_step.gd")

var editor: CHANE_AssetNodeEditor
var asset_node: HyAssetNode

var my_points: Array[Vector2] = []

var next_adjust_is_new: bool = true
var merge_version_check: int = -1

var points_table: GridContainer
var graph_container: MarginContainer
@onready var mode_buttons: HToggleButtons = find_child("ModeButtons")
@onready var extra_settings_menu_btn: MenuButton = find_child("ExtraSettingsBtn")
@onready var extra_settings_menu: PopupMenu = extra_settings_menu_btn.get_popup()
@onready var new_point_button: Button = $NewPointButton
@onready var export_as_edit: CustomLineEdit = find_child("SettingEdit_ExportAs")

@export var curve_plot: CurvePlot

@export var child_position_offset: Vector2 = Vector2(26, 0)
@export var child_position_increment: Vector2 = Vector2(20, 100)

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
    var settings_syncer: = get_settings_syncer()
    settings_syncer.updated_from_asset_node.connect(on_settings_syncer_updated_from_asset_node)
    settings_syncer.add_watched_setting("ExportAs", export_as_edit, TYPE_STRING)

    if not asset_node.settings.get("ExportAs", ""):
        export_as_edit.get_parent().hide()
    export_as_edit.focus_exited.connect(check_show_export_as)

func _enter_tree() -> void:
    var new_graph_edit: = get_parent() as CHANE_AssetNodeGraphEdit
    if new_graph_edit:
        if not new_graph_edit.zoom_changed.is_connected(on_zoom_changed):
            new_graph_edit.zoom_changed.connect(on_zoom_changed)
    setup_ports(new_graph_edit)

func _exit_tree() -> void:
    var old_graph_edit: = get_parent() as CHANE_AssetNodeGraphEdit
    if old_graph_edit:
        if old_graph_edit.zoom_changed.is_connected(on_zoom_changed):
            old_graph_edit.zoom_changed.disconnect(on_zoom_changed)

# Position serialization for all owned asset nodes
func update_aux_positions(aux_data: Dictionary[String, HyAssetNode.AuxData]) -> void:
    aux_data[asset_node.an_node_id].position = position_offset
    var sub_ans: Array[HyAssetNode] = asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME)
    for idx in sub_ans.size():
        var sub_an: HyAssetNode = sub_ans[idx]
        aux_data[sub_an.an_node_id].position = get_phantom_gn_pos(idx)

func get_phantom_gn_pos(phantom_index: int) -> Vector2:
    var base_pos: Vector2 = position_offset + child_position_offset + Vector2(size.x, 0)
    return base_pos + child_position_increment * phantom_index

func setup_ports(cur_graph_edit: CHANE_AssetNodeGraphEdit) -> void:
    # note, don't need to add a child control to enable the first port because there's already multiple children from the scene
    set_slot_enabled_left(0, true)
    set_slot_type_left(0, cur_graph_edit.type_id_lookup["Curve"])

# REQUIRED METHODS FOR SPECIAL GRAPH NODES::

func get_own_asset_nodes() -> Array[HyAssetNode]:
    var ans: Array[HyAssetNode] = [asset_node]
    ans.append_array(asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME))
    return ans

func get_all_connections() -> Dictionary[String, Array]:
    var connections: Dictionary[String, Array] = {}
    return connections

func get_all_nodes_on_connection(_conn_name: String) -> Array[HyAssetNode]:
    var conn_nodes: Array[HyAssetNode] = []
    return conn_nodes

func get_parent_an_for_connection(_conn_name: String) -> HyAssetNode:
    return asset_node

# end REQUIRED METHODS FOR SPECIAL GRAPH NODES::

func get_excluded_connection_names() -> Array[String]:
    return [POINTS_CONNECTION_NAME]

func on_resized() -> void:
    last_size[cur_mode] = size

func on_zoom_changed(new_zoom: float) -> void:
    curve_plot.cur_zoom = new_zoom
    if graph_container.visible:
        curve_plot.queue_redraw()


func load_points_from_an_connection(force_sort: bool = false) -> void:
    my_points.clear()
    for point_asset_node in asset_node.get_all_connected_nodes(POINTS_CONNECTION_NAME):
        my_points.append(Vector2(point_asset_node.settings["In"], point_asset_node.settings["Out"]))
    refresh_points_displayed(force_sort)

func refresh_points_displayed(force_sort: bool = false, undo_step: UndoStep = null) -> void:
    if force_sort:
        my_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
        update_ans_from_my_points(undo_step)
    if cur_mode == "table":
        refresh_table_rows()
    elif cur_mode == "graph":
        curve_plot.update_curve(my_points)

func remove_point_at(row_idx: int) -> void:
    var asset_node_count: = asset_node.num_connected_asset_nodes(POINTS_CONNECTION_NAME)
    if row_idx < 0 or row_idx >= asset_node_count:
        push_error("manual curve special: remove point index %s is out of range %s-%s" % [row_idx, 0, asset_node_count - 1])
        return
    
    var undo_step: = editor.undo_manager.start_or_continue_undo_step("Remove Manual Curve Point")
    var is_new_step: = editor.undo_manager.is_new_step

    var old_points: = my_points.duplicate()
    my_points.remove_at(row_idx)
    update_ans_from_my_points(undo_step)
    
    set_my_points_undo_values(undo_step, old_points)
    if is_new_step:
        editor.undo_manager.commit_current_undo_step()

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


func table_value_changed(new_value: float, row_idx: int, is_in: bool) -> void:
    var undo_step: = editor.undo_manager.start_or_continue_undo_step("Change Manual Curve Point")

    var old_points: = my_points.duplicate()
    my_points[row_idx][0 if is_in else 1] = new_value
    update_ans_from_my_points(undo_step)
    
    set_my_points_undo_values(undo_step, old_points)
    editor.undo_manager.commit_if_new()

func replace_points(new_points: Array[Vector2]) -> void:
    var undo_step: = editor.undo_manager.start_or_continue_undo_step("Change Manual Curve Points")

    var old_points: = my_points.duplicate()

    my_points = new_points
    update_ans_from_my_points(undo_step)
    refresh_points_displayed()
    
    set_my_points_undo_values(undo_step, old_points)
    editor.undo_manager.commit_if_new()

func adjust_points(new_points: Array[Vector2]) -> void:
    var old_points: = my_points.duplicate()
    my_points = new_points
    create_points_adj_undo_step(old_points)

    if not editor.undo_manager.is_creating_undo_step():
        next_adjust_is_new = false
        merge_version_check = editor.undo_manager.undo_redo.get_version()

func points_adjustment_ended() -> void:
    next_adjust_is_new = true

func can_merge_adjust_points() -> bool:
    if next_adjust_is_new or editor.undo_manager.is_creating_undo_step():
        return false
    var at_version: = editor.undo_manager.undo_redo.get_version()
    return at_version == merge_version_check

func create_points_adj_undo_step(old_points: Array[Vector2]) -> void:
    var merge_mode: = UndoRedo.MERGE_DISABLE
    if can_merge_adjust_points():
        merge_mode = UndoRedo.MERGE_ENDS

    var undo_manager: = editor.undo_manager
    var undo_step: = undo_manager.start_or_continue_undo_step("Move Manual Curve Points")

    update_ans_from_my_points(undo_step)

    undo_step.custom_redo_callbacks.append(undo_redo_change_points.bind(my_points.duplicate()))

    undo_step.custom_undo_callbacks.append(undo_redo_change_points.bind(old_points.duplicate()))

    undo_manager.commit_if_new(merge_mode)

func update_ans_from_my_points(undo_step: UndoStep) -> void:
    resize_ans_from_my_points(undo_step)
    for row_idx in my_points.size():
        var point_asset_node: HyAssetNode = asset_node.get_connected_node(POINTS_CONNECTION_NAME, row_idx)
        if undo_step != null:
            undo_step.register_an_settings_before_change(point_asset_node)
        point_asset_node.settings["In"] = my_points[row_idx].x
        point_asset_node.settings["Out"] = my_points[row_idx].y

func resize_ans_from_my_points(undo_step: UndoStep) -> void:
    var cur_an_count: int = asset_node.num_connected_asset_nodes(POINTS_CONNECTION_NAME)
    if cur_an_count == my_points.size():
        return
    if undo_step == null:
        push_error("resize_ans_from_my_points called with incorrect size and null undo_step")
        return

    if cur_an_count < my_points.size():
        for i in my_points.size() - cur_an_count:
            _add_new_point_asset_node(Vector2.ZERO, undo_step)
    else:
        for i in cur_an_count - my_points.size():
            _pop_asset_node(undo_step)

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

func add_new_point_auto() -> void:
    var undo_step: = editor.undo_manager.start_or_continue_undo_step("Add Manual Curve Point")
    
    refresh_points_displayed(true, undo_step)

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

    _add_new_point_asset_node(new_point_pos, undo_step)

    var old_points: = my_points.duplicate()
    load_points_from_an_connection()
    set_my_points_undo_values(undo_step, old_points)

    editor.undo_manager.commit_if_new()

func set_my_points_undo_values(undo_step: UndoStep, old_points: Array[Vector2]) -> void:
    undo_step.custom_undo_callbacks.append(undo_redo_change_points.bind(old_points.duplicate()))
    undo_step.custom_redo_callbacks.append(undo_redo_change_points.bind(my_points.duplicate()))

func _add_new_point_asset_node(with_pos: Vector2, undo_step: UndoStep) -> HyAssetNode:
    var new_curve_point_an: HyAssetNode = editor.get_new_asset_node("CurvePoint")
    new_curve_point_an.settings["In"] = with_pos.x
    new_curve_point_an.settings["Out"] = with_pos.y
    editor.add_undo_step_created_asset_node(new_curve_point_an, undo_step)
    undo_step.add_asset_node_connection(asset_node, POINTS_CONNECTION_NAME, new_curve_point_an)
    return new_curve_point_an

func _pop_asset_node(undo_step: UndoStep) -> HyAssetNode:
    var popped_an: = asset_node.pop_node_from_connection(POINTS_CONNECTION_NAME)
    undo_step.manually_delete_asset_node(popped_an)
    undo_step.remove_asset_node_connection(asset_node, POINTS_CONNECTION_NAME, popped_an)
    return popped_an

func undo_redo_change_points(points_to_restore: Array[Vector2]) -> void:
    my_points = points_to_restore.duplicate()
    refresh_points_displayed()

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
            editor.set_asset_node_setting_with_undo(asset_node.an_node_id, "ExportAs", "")
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