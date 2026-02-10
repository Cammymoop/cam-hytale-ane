extends PopupPanel

signal new_title_submitted(new_title: String)

var current_title: String = ""

func _ready() -> void:
    var title_edit: = find_child("CustomLineEdit") as CustomLineEdit
    title_edit.text = current_title
    title_edit.placeholder_text = current_title
    title_edit.text_submitted.connect(title_submitted.unbind(1))
    var submit_button: = find_child("SubmitButton")
    submit_button.pressed.connect(on_submit_pressed)
    popup_hide.connect(queue_free)

    title_edit.select_all_on_focus = true
    title_edit.grab_focus()

func on_submit_pressed() -> void:
    title_submitted()

func title_submitted() -> void:
    var title_edit: = find_child("CustomLineEdit") as CustomLineEdit
    new_title_submitted.emit(title_edit.text.strip_edges())
    queue_free()
