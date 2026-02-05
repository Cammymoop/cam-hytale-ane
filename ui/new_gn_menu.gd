@tool
extends PanelContainer
class_name NewGNMenu

signal node_type_picked(node_type: String)
signal cancelled
signal closing

@export var auto_confirm_single_type: bool = true

@export var graph_edit: AssetNodeGraphEdit
var schema: AssetNodesSchema

@export var scroll_min_height: = 100
@export var scroll_max_height_ratio: = 0.85
var scroll_max_height: = 0

@export_tool_button("Show Preview Content", "Tree") var show_prev: = rebuild_preview_tree

@onready var scroll_container: ScrollContainer = find_child("ScrollContainer")
@onready var node_list_tree: Tree = scroll_container.get_node("Tree")
@onready var show_all_btn: Button = find_child("ShowAllButton")

var cur_filter_is_output: bool = true
var cur_filter_is_neither: bool = false
var cur_filter_value_type: String = ""

var an_types_by_output_value_type: Dictionary[String, Array] = {}
var an_types_by_input_value_type: Dictionary[String, Array] = {}
var an_input_types: Dictionary[String, Array] = {}

var filter_set_single_type: String = ""
var filter_set_single: bool = false

var test_filters: Array = [
    true, "Density",
    false, "Density",
    true, "CurvePoint",
    false, "CurvePoint",
    true, "KeyMultiMix",
    false, "KeyMultiMix",
    true, "Material",
    false, "Material",
]
var test_filter_idx: int = -1

var popup_menu_root: PopupMenuRoot = null

func _ready() -> void:
    find_popup_menu_root(get_parent())
    show_all_btn.toggled.connect(on_show_all_btn_toggled)
    set_max_popup_height()
    get_window().size_changed.connect(set_max_popup_height)

    node_list_tree.resized.connect(on_tree_size_changed)
    node_list_tree.item_activated.connect(tree_item_chosen)
    node_list_tree.item_mouse_selected.connect(tree_item_mouse_selected)

    if Engine.is_editor_hint():
        return
    if not graph_edit:
        push_warning("Graph edit is not set, please set it in the inspector")
        print("Graph edit is not set, please set it in the inspector")
    schema = SchemaManager.schema
    
    #rebuild_preview_tree()

    build_lookups()
    build_node_list()

func find_popup_menu_root(from_node: Node) -> void:
    var the_parent: Node = from_node.get_parent()
    if not the_parent:
        return
    if the_parent is PopupMenuRoot:
        popup_menu_root = the_parent
    else:
        find_popup_menu_root(the_parent)

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if not visible:
        return
    
    if Input.is_action_just_pressed("ui_cancel"):
        cancelled.emit()
        closing.emit()

    if Input.is_action_just_pressed("_debug_next_filter") and OS.has_feature("debug"):
        test_filter_idx += 1
        if test_filter_idx >= floori(test_filters.size() / 2.):
            test_filter_idx = 0
        open_menu(test_filters[test_filter_idx * 2], test_filters[test_filter_idx * 2 + 1])

func build_lookups() -> void:
    an_types_by_input_value_type.clear()
    an_types_by_output_value_type.clear()
    an_input_types.clear()
    for val_type in schema.value_types:
        an_types_by_output_value_type[val_type] = Array([], TYPE_STRING, "", null)
        an_types_by_input_value_type[val_type] = Array([], TYPE_STRING, "", null)
    
    for node_type in schema.node_schema.keys():
        an_input_types[node_type] = Array([], TYPE_STRING, "", null)

    for an_type in schema.node_schema.keys():
        var output_value_type: String = schema.node_schema[an_type].get("output_value_type", "")
        if output_value_type and output_value_type in schema.value_types:
            an_types_by_output_value_type[output_value_type].append(an_type)
        
        for conn_name in schema.node_schema[an_type].get("connections", {}).keys():
            var conn_value_type: String = schema.node_schema[an_type]["connections"][conn_name]["value_type"]
            an_types_by_input_value_type[conn_value_type].append(an_type)
            an_input_types[an_type].append(conn_value_type)

func build_node_list() -> void:
    if not schema:
        print("No schema, cannot build node list")
        return
    node_list_tree.clear()
    var root_item: = node_list_tree.create_item(null)
    for val_type in schema.value_types:
        var type_category_item: = root_item.create_child()
        type_category_item.set_text(0, val_type)
        type_category_item.set_selectable(0, false)
        type_category_item.set_custom_color(0, Color.WHITE)
        type_category_item.set_custom_bg_color(0, TypeColors.get_actual_color_for_type(val_type))
    
    for category_parent in root_item.get_children():
        var val_type: = category_parent.get_text(0)
        for node_type in an_types_by_output_value_type[val_type]:
            var node_type_item: = category_parent.create_child()
            var display_name: String = schema.node_schema[node_type].get("display_name", node_type)
            node_type_item.set_text(0, display_name)
            node_type_item.set_meta("node_type", node_type)
            node_type_item.set_tooltip_text(0, "%s (%s)" % [display_name, node_type])

func hide_all_categories() -> void:
    for category_item in node_list_tree.get_root().get_children():
        category_item.collapsed = false
        category_item.visible = false

func set_category_items_visible(type_category: String, to_visible: bool) -> void:
    for category_item in node_list_tree.get_root().get_children():
        category_item.collapsed = false
        if category_item.get_text(0) == type_category:
            for child_item in category_item.get_children():
                child_item.visible = to_visible

func show_all_items() -> void:
    for category_item in node_list_tree.get_root().get_children():
        category_item.visible = true
        category_item.collapsed = false
        for child_item in category_item.get_children():
            child_item.visible = true

func set_filter_output(val_type: String) -> void:
    cur_filter_is_neither = false
    cur_filter_is_output = true
    cur_filter_value_type = val_type
    _filter_update()

func set_filter_input(val_type: String) -> void:
    cur_filter_is_neither = false
    cur_filter_is_output = false
    cur_filter_value_type = val_type
    _filter_update()

func _filter_update() -> void:
    if cur_filter_is_neither:
        return
    if cur_filter_is_output:
        _filter_update_output()
    else:
        _filter_update_input()

func _filter_update_output() -> void:
    filter_set_single = false
    hide_all_categories()
    for category_item in node_list_tree.get_root().get_children():
        if category_item.get_text(0) == cur_filter_value_type:
            category_item.visible = true
            set_category_items_visible(category_item.get_text(0), true)
            var category_count: int = category_item.get_child_count()
            if category_count == 1:
                filter_set_single = true
                filter_set_single_type = category_item.get_child(0).get_meta("node_type", "") as String

func _filter_update_input() -> void:
    filter_set_single = false
    var more_than_one: bool = false
    hide_all_categories()
    for category_item in node_list_tree.get_root().get_children():
        for child_item in category_item.get_children():
            var item_node_type: = child_item.get_meta("node_type", "") as String
            if cur_filter_value_type in an_input_types[item_node_type]:
                if not category_item.visible:
                    category_item.visible = true
                    set_category_items_visible(category_item.get_text(0), false)
                child_item.visible = true

                if not filter_set_single and not more_than_one:
                    filter_set_single = true
                    filter_set_single_type = item_node_type
                elif filter_set_single:
                    more_than_one = true
                    filter_set_single = false

func open_menu(for_left_connection: bool, connection_value_type: String) -> void:
    show_all_btn.set_pressed_no_signal(false)
    show_all_btn.disabled = false
    if for_left_connection:
        set_filter_output(connection_value_type)
    else:
        set_filter_input(connection_value_type)

    if auto_confirm_single_type and filter_set_single:
        node_type_picked.emit(filter_set_single_type)
        return

    popup_menu_root.show_new_gn_menu()

func open_all_menu() -> void:
    cur_filter_is_neither = true
    cur_filter_value_type = ""
    _filter_update()
    
    show_all_btn.set_pressed_no_signal(true)
    show_all_btn.disabled = true
    show_all_items()
    popup_menu_root.show_new_gn_menu()

func on_show_all_btn_toggled(is_show_all: bool) -> void:
    if is_show_all:
        node_list_tree.scroll_vertical_enabled = true
        show_all_items()
        node_list_tree.scroll_vertical_enabled = false
    else:
        _filter_update()
    

func rebuild_preview_tree() -> void:
    if not is_inside_tree():
        return
    scroll_container = find_child("ScrollContainer")
    node_list_tree = scroll_container.get_node("Tree")
    if not schema:
        schema = SchemaManager.schema
    if not an_types_by_input_value_type:
        build_lookups()
    build_node_list()
    set_filter_input("Material")

func on_tree_size_changed() -> void:
    scroll_container.custom_minimum_size.y = clampi(int(node_list_tree.size.y), scroll_min_height, scroll_max_height)

func set_max_popup_height() -> void:
    var window_height: = get_window().size.y
    scroll_max_height = roundi(window_height * scroll_max_height_ratio)

func tree_item_mouse_selected(_mouse_pos: Vector2, _buton_index: int) -> void:
    tree_item_chosen()

func tree_item_chosen() -> void:
    var tree_item: TreeItem = node_list_tree.get_selected()
    if not tree_item:
        print_debug("Tree item chosen but no tree item selected")
        return
    choose_item(tree_item)

func choose_item(tree_item: TreeItem) -> void:
    if not tree_item.has_meta("node_type"):
        print_debug("Tree item chosen but no node type meta found: ", tree_item.get_text(0))
        cancelled.emit()
        closing.emit()
        return

    node_type_picked.emit(tree_item.get_meta("node_type"))
    closing.emit()
    