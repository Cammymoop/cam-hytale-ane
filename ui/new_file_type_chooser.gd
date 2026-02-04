extends PanelContainer

signal file_type_chosen(workspace_id: String)
signal closing

@onready var button_container: Control = find_child("ButtonContainer")

func _ready() -> void:
    create_buttons()

func clear_buttons() -> void:
    for child in button_container.get_children():
        button_container.remove_child(child)
        child.queue_free()

func create_buttons() -> void:
    clear_buttons()
    var workspace_ids: Array[String] = []
    workspace_ids.append_array(SchemaManager.schema.workspace_no_output_types.keys())
    workspace_ids.append_array(SchemaManager.schema.workspace_root_output_types.keys())
    
    for workspace_id in workspace_ids:
        var choose_type_btn: Button = Button.new()
        choose_type_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        choose_type_btn.name = "Btn_%s" % workspace_id.capitalize()
        choose_type_btn.text = workspace_id
        choose_type_btn.pressed.connect(choose_type_btn_pressed.bind(workspace_id))
        button_container.add_child(choose_type_btn, true)

func choose_type_btn_pressed(workspace_id: String) -> void:
    file_type_chosen.emit(workspace_id)
    closing.emit()

func _on_cancel_btn_pressed() -> void:
    closing.emit()