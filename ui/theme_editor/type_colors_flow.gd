extends HFlowContainer

signal colors_changed
signal type_color_changed

const TypeColorButton = preload("res://ui/theme_editor/type_color_button.gd")

var type_color_styleboxes: Dictionary = {}

func _ready() -> void:
    var graph_edit: CHANE_AssetNodeGraphEdit = get_tree().current_scene.find_child("ANGraphEdit")
    assert(graph_edit != null, "Type colors flow: Graph Edit not found")
    setup()

func setup() -> void:
    make_type_color_buttons()

func color_name_color_changed(color_name: String) -> void:
    clear_color_name(color_name)
    get_button_styleboxes(color_name)
    colors_changed.emit()

func make_type_color_buttons() -> void:
    clear_children()
    for type_name in SchemaManager.schema.value_types:
        var type_color_button: = TypeColorButton.new()
        type_color_button.set_type_name(type_name)
        type_color_button.type_color_changed.connect(type_color_changed.emit)
        add_child(type_color_button, true)

func clear_children() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

func get_button_styleboxes(color_name: String) -> Dictionary:
    if color_name not in type_color_styleboxes:
        var theme_color: Color = ThemeColorVariants.get_theme_color(color_name)
        ThemeColorVariants._make_theme_color_variant(color_name, theme_color)
        type_color_styleboxes[color_name] = ThemeColorVariants.get_button_styleboxes(theme_color)
    return type_color_styleboxes[color_name]

func clear_color_name(color_name: String) -> void:
    if color_name in type_color_styleboxes:
        type_color_styleboxes.erase(color_name)
