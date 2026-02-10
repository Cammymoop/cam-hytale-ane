@tool
extends PanelContainer
class_name NewGNMenu

signal node_type_picked(node_type: String)
signal cancelled
signal closing

@export var auto_confirm_single_type: bool = true

@export var graph_edit: AssetNodeGraphEdit
var schema: AssetNodesSchema

@export var scroll_to_margin: float = 12

@export var scroll_min_height: = 100
var scroll_max_height: = 0

@export_tool_button("Show Preview Content", "Tree") var show_prev: = rebuild_preview_tree

@onready var scroll_container: ScrollContainer = find_child("ScrollContainer")
@onready var scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
@onready var node_list_tree: Tree = scroll_container.get_node("Tree")
@onready var show_all_btn: Button = find_child("ShowAllButton")
@onready var filter_input: CustomLineEdit = find_child("FilterInput")
@onready var resize_dragger: Control = find_child("ResizeDragger")

var cur_filter_is_output: bool = true
var cur_filter_is_neither: bool = false
var cur_filter_value_type: String = ""

var an_types_by_output_value_type: Dictionary[String, Array] = {}
var an_types_by_input_value_type: Dictionary[String, Array] = {}
var an_input_types: Dictionary[String, Array] = {}

var filter_set_single_type: String = ""
var filter_set_single: bool = false

var has_search_filter: bool = false

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

var can_search_filter: bool = true

func _ready() -> void:
    find_popup_menu_root(get_parent())
    show_all_btn.toggled.connect(on_show_all_btn_toggled)
    set_max_popup_height()
    get_window().size_changed.connect(set_max_popup_height)

    node_list_tree.resized.connect(on_tree_size_changed)
    node_list_tree.item_activated.connect(tree_item_chosen)
    node_list_tree.item_mouse_selected.connect(tree_item_mouse_selected)
    
    filter_input.gui_input.connect(on_filter_gui_input)
    filter_input.text_changed.connect(on_filter_text_changed)
    filter_input.text_submitted.connect(on_filter_text_submitted.unbind(1))

    if Engine.is_editor_hint():
        return
    if not graph_edit:
        push_warning("Graph edit is not set, please set it in the inspector")
        print("Graph edit is not set, please set it in the inspector")
    schema = SchemaManager.schema
    
    #rebuild_preview_tree()

    build_lookups()
    build_node_list()
    
    resize_dragger.dragged.connect(on_resize_dragged)
    resize_dragger.drag_ended.connect(on_resize_drag_ended)

func on_resize_dragged(relative_pos: Vector2) -> void:
    var temp_scroll_max_height: = roundi(scroll_max_height + relative_pos.y * 2)
    var extra_height: = roundi(size.y - scroll_container.size.y)
    temp_scroll_max_height = clampi(temp_scroll_max_height, scroll_min_height + extra_height, get_window().size.y)
    var allowed_max: = temp_scroll_max_height - extra_height

    scroll_container.custom_minimum_size.y = clampi(int(node_list_tree.size.y), scroll_min_height, allowed_max)

func on_resize_drag_ended(relative_pos: Vector2) -> void:
    var window_height: = get_window().size.y
    var new_scroll_max_height: = roundi(scroll_max_height + relative_pos.y * 2)
    var extra_height: = roundi(size.y - scroll_container.size.y)
    new_scroll_max_height = clampi(new_scroll_max_height, scroll_min_height + extra_height, window_height)
    var ratio: = new_scroll_max_height / float(window_height)

    ANESettings.new_node_menu_height_ratio = ratio
    ANESettings.update_saved_settings()
    set_max_popup_height()
    on_tree_size_changed()

func on_tree_size_changed() -> void:
    var extra_height: = size.y - scroll_container.size.y
    var allowed_max: = roundi(scroll_max_height - extra_height)
    scroll_container.custom_minimum_size.y = clampi(int(node_list_tree.size.y), scroll_min_height, allowed_max)

func set_max_popup_height() -> void:
    var ratio: = ANESettings.new_node_menu_height_ratio
    if Engine.is_editor_hint():
        scroll_max_height = roundi(ProjectSettings.get_setting("display/window/size/viewport_height") * ratio)
        return
    var window_height: = get_window().size.y
    scroll_max_height = roundi(window_height * ratio)


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
        close_menu()

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

func apply_search_filter_all() -> Array[TreeItem]:
    var visible_items: Array[TreeItem] = []
    for category_parent in node_list_tree.get_root().get_children():
        var visible_count: int = 0
        for child_item in category_parent.get_children():
            if child_item.get_meta("node_type") in NodeFuzzySearcher.search_results:
                child_item.visible = true
                visible_count += 1
                visible_items.append(child_item)
            else:
                child_item.visible = false
        category_parent.visible = visible_count > 0
    return visible_items

func set_filter_output(val_type: String) -> void:
    print("set_filter_output", val_type)
    cur_filter_is_neither = false
    cur_filter_is_output = true
    cur_filter_value_type = val_type
    _type_filter_update()

func set_filter_input(val_type: String) -> void:
    print("set_filter_input", val_type)
    cur_filter_is_neither = false
    cur_filter_is_output = false
    cur_filter_value_type = val_type
    _type_filter_update()

func _type_filter_update() -> void:
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
    if has_search_filter:
        apply_search_filter()

func apply_search_filter_output() -> Array[TreeItem]:
    var visible_items: Array[TreeItem] = []
    for category_item in node_list_tree.get_root().get_children():
        if category_item.get_text(0) != cur_filter_value_type:
            category_item.visible = false
            continue
        category_item.visible = true
        category_item.collapsed = false
        for child_item in category_item.get_children():
            if child_item.get_meta("node_type", "") in NodeFuzzySearcher.search_results:
                child_item.visible = true
                visible_items.append(child_item)
            else:
                child_item.visible = false
    return visible_items


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
    if has_search_filter:
        apply_search_filter()

func apply_search_filter_input() -> Array[TreeItem]:
    var visible_items: Array[TreeItem] = []
    for category_item in node_list_tree.get_root().get_children():
        var visible_count: int = 0
        for child_item in category_item.get_children():
            var item_node_type: = child_item.get_meta("node_type", "") as String
            child_item.visible = cur_filter_value_type in an_input_types[item_node_type]
            child_item.visible = child_item.visible and item_node_type in NodeFuzzySearcher.search_results
            if child_item.visible:
                visible_items.append(child_item)
                visible_count += 1
        category_item.visible = visible_count > 0
    return visible_items

func open_menu(for_left_connection: bool, connection_value_type: String) -> void:
    show_all_btn.set_pressed_no_signal(false)
    show_all_btn.disabled = false
    if for_left_connection:
        set_filter_output(connection_value_type)
    else:
        set_filter_input(connection_value_type)

    if auto_confirm_single_type and filter_set_single:
        node_type_picked.emit(filter_set_single_type)
        close_menu()
        return

    show_search_filter_input()
    visible = true

func open_all_menu() -> void:
    cur_filter_is_neither = true
    cur_filter_value_type = ""
    
    show_all_btn.set_pressed_no_signal(true)
    show_all_btn.disabled = true
    show_all_items()

    show_search_filter_input()
    visible = true

func show_search_filter_input() -> void:
    clear_search_filter()
    if not can_search_filter:
        filter_input.visible = false
        return

    filter_input.visible = true
    filter_input.grab_focus.call_deferred()

func on_show_all_btn_toggled(is_show_all: bool) -> void:
    if has_search_filter:
        apply_search_filter(false)
    else:
        _apply_cur_type_filter(is_show_all)

func _apply_cur_type_filter(show_all: bool) -> void:
    if show_all:
        node_list_tree.scroll_vertical_enabled = true
        show_all_items()
        node_list_tree.scroll_vertical_enabled = false
    else:
        _type_filter_update()
    
func on_search_filter_changed() -> void:
    apply_search_filter()

func apply_search_filter(select_first_visible_result: bool = true) -> void:
    # TODO order items by search ranking, probably need to get rid of categories and display a flat list instead
    # instead I'm just going to use the result ranking to select the best match for now
    if not has_search_filter:
        _apply_cur_type_filter(show_all_btn.is_pressed())
        return
    
    var visible_items: Array[TreeItem] = []
    if cur_filter_is_neither or show_all_btn.is_pressed():
        visible_items = apply_search_filter_all()
    elif cur_filter_is_output:
        visible_items = apply_search_filter_output()
    else:
        visible_items = apply_search_filter_input()
    
    if select_first_visible_result:
        var visible_node_types: Array[StringName] = []
        for visible_item in visible_items:
            visible_node_types.append(visible_item.get_meta("node_type", ""))
        for search_result_type in NodeFuzzySearcher.search_results:
            var found_idx: int = visible_node_types.find(search_result_type)
            if found_idx != -1:
                select_and_scroll_to(visible_items[found_idx])
                return
    

func select_first_result() -> void:
    for category_parent in node_list_tree.get_root().get_children():
        if not category_parent.visible:
            prints("skipping invisible category", category_parent.get_text(0))
            continue
        for child_item in category_parent.get_children():
            if not child_item.visible:
                continue
            if category_parent.collapsed:
                category_parent.collapsed = false
            select_and_scroll_to(child_item)
            return
    prints("no visible items found to select")

func move_selection(delta: int) -> void:
    var cur_selected: = node_list_tree.get_selected()
    if not cur_selected:
        prints("no current selected item, selecting first result")
        select_first_result()
        return
    var next_visible_item: TreeItem = find_next_visible_item(cur_selected, delta)
    if not next_visible_item:
        return
    select_and_scroll_to(next_visible_item)
    node_list_tree.queue_redraw()

## Skip non-selectable items
func find_next_visible_item(cur_item: TreeItem, delta: int) -> TreeItem:
    prints("finding next visible item from", cur_item.get_text(0), "delta", delta)
    var next_item: TreeItem = _find_next_visible_item(cur_item, delta)
    while next_item and not next_item.is_selectable(0):
        prints("item", next_item.get_text(0), "is not selectable, looking for next again")
        next_item = _find_next_visible_item(next_item, delta)
    return next_item

func _find_next_visible_item(cur_item: TreeItem, delta: int) -> TreeItem:
    if delta > 0:
        return cur_item.get_next_visible()
    else:
        return cur_item.get_prev_visible()

func tree_item_mouse_selected(_mouse_pos: Vector2, _buton_index: int) -> void:
    tree_item_chosen()

func tree_item_chosen() -> void:
    var tree_item: TreeItem = node_list_tree.get_selected()
    prints("tree_item_chosen: %s" % tree_item.get_text(0))
    await get_tree().process_frame
    tree_item = node_list_tree.get_selected()
    prints("tree_item_chosen after frame: %s" % tree_item.get_text(0))
    if not tree_item:
        print_debug("Tree item chosen but no tree item selected")
        return
    choose_item(tree_item)

func choose_item(tree_item: TreeItem) -> void:
    if not tree_item.has_meta("node_type"):
        print_debug("Tree item chosen but no node type meta found: ", tree_item.get_text(0))
        cancelled.emit()
        close_menu()
        return

    node_type_picked.emit(tree_item.get_meta("node_type"))
    close_menu()

func select_and_scroll_to(tree_item: TreeItem) -> void:
    print("selecting and scrolling to", tree_item.get_text(0))
    var category_parent: TreeItem = tree_item.get_parent()
    if category_parent and category_parent.collapsed:
        category_parent.collapsed = false
    node_list_tree.set_selected(tree_item, 0)

    await get_tree().process_frame
    prints("scrolling", get_scroll_view_rect(), scroll_bar.value, scroll_bar.page, node_list_tree.get_item_area_rect(tree_item).get_center())
    var list_pos: Vector2 = node_list_tree.get_item_area_rect(tree_item).get_center()
    scroll_to_list_pos(list_pos)

func on_filter_gui_input(event: InputEvent) -> void:
    if event is InputEventKey:
        key_gui_input(event)

func key_gui_input(event: InputEventKey) -> void:
    if Input.is_action_just_pressed_by_event("ui_up", event):
        move_selection(-1)
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed_by_event("ui_down", event):
        move_selection(1)
        get_viewport().set_input_as_handled()

func on_filter_text_changed(new_text: String) -> void:
    if new_text and not new_text.strip_edges():
        new_text = ""
    if new_text:
        NodeFuzzySearcher.search(new_text)
    has_search_filter = new_text.length() > 0
    on_search_filter_changed()

func clear_search_filter() -> void:
    has_search_filter = false
    filter_input.text = ""

func on_filter_text_submitted() -> void:
    var selected_item: TreeItem = node_list_tree.get_selected()
    if not selected_item:
        return
    choose_item(selected_item)


## For Testing
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

func get_scroll_view_rect() -> Rect2:
    var view_rect: = Rect2(Vector2.ZERO, scroll_container.size)
    view_rect.position.y = scroll_bar.value
    return view_rect

func is_list_pos_visible(list_pos: Vector2, margin: float = -1) -> bool:
    if margin < 0:
        margin = scroll_to_margin
    var view_rect: = get_scroll_view_rect().grow_individual(0, -margin, 0, -margin)
    prints("in view check rect", view_rect, list_pos)
    return view_rect.has_point(list_pos)

func scroll_to_list_pos(list_pos: Vector2) -> void:
    if is_list_pos_visible(list_pos):
        return
    var view_rect: = get_scroll_view_rect()
    if list_pos.y > view_rect.end.y - scroll_to_margin:
        var scroll_amt: = list_pos.y - (view_rect.end.y - scroll_to_margin)
        prints("scrolling down", scroll_amt)
        scroll_bar.value += scroll_amt
    elif list_pos.y < view_rect.position.y + scroll_to_margin:
        var scroll_amt: = view_rect.position.y + scroll_to_margin - list_pos.y
        prints("scrolling up", scroll_amt)
        scroll_bar.value -= scroll_amt

# Deselect all itmes to prevent bug where multiple items can be selected if they are hidden which causes the wrong one
# to be retrieved by get_selected()
func close_menu() -> void:
    node_list_tree.deselect_all()
    closing.emit()