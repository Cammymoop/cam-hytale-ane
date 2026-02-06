extends OptionButton
class_name GNExclusiveEnumEdit

signal option_changed(option: String)

var options: Array[String] = []
var selected_text: String = ""

func _ready() -> void:
    item_selected.connect(on_option_selected)
    update_options()

func set_options(new_options: Array[String], new_selected_option: String = "") -> void:
    options = new_options
    if new_selected_option:
        selected_text = new_selected_option
    else:
        selected_text = options[0]
    update_options()

func set_numeric_options(new_options: Array, new_selected_option: int) -> void:
    options.clear()
    for opt in new_options:
        options.append(str(opt))
    set_current_option_directly(str(new_selected_option))

func set_current_option_directly(new_option: String) -> void:
    var index: = options.find(new_option)
    if index == -1:
        select(-1)
        selected_text = new_option
        text = selected_text
        return
    
    select(index)

func select_option(new_option: String) -> void:
    set_current_option_directly(new_option)
    option_changed.emit(new_option)

func update_options() -> void:
    clear()
    for opt in options:
        add_item(opt)
    
    if selected_text:
        if selected_text not in options:
            select(-1)
        else:
            select(options.find(selected_text))

func on_option_selected(index: int) -> void:
    selected_text = options[index]
    option_changed.emit(selected_text)