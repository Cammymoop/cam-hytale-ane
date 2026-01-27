extends HBoxContainer

signal option_changed(option_name: String)
signal index_changed(index: int)
signal all_off()

@export var allow_all_off: = true
var buttons: Array[BaseButton] = []

func _ready() -> void:
    find_buttons()
    setup_signals()
    if not allow_all_off:
        ensure_one_pressed()

func ensure_one_pressed(repress_index: int = 0) -> void:
    var pressed_count: int = 0
    for b in buttons:
        if b.button_pressed:
            pressed_count += 1

    if pressed_count == 0:
        buttons[repress_index].set_pressed_no_signal(true)
    elif pressed_count > 1:
        var first_pressed: = false
        for b in buttons:
            if b.button_pressed and not first_pressed:
                first_pressed = true
            elif b.button_pressed:
                b.set_pressed_no_signal(false)

func find_buttons() -> void:
    buttons.clear()
    for c in get_children():
        if c is BaseButton:
            c.toggle_mode = true
            buttons.append(c)

func setup_signals() -> void:
    for button in buttons:
        if not button.toggled.is_connected(on_button_toggled):
            button.toggled.connect(on_button_toggled.bind(button))

func on_button_toggled(is_pressed: bool, button: BaseButton) -> void:
    var is_changed: = true
    if is_pressed:
        for b in buttons:
            if not is_same(b, button) and b.button_pressed:
                b.button_pressed = false
    else:
        if not allow_all_off:
            var repress_index: int = buttons.find(button)
            ensure_one_pressed(repress_index)
    
    if is_changed:
        emit_changed_signals()

func emit_changed_signals() -> void:
    var pressed_button: BaseButton = null
    var btn_idx: int = 0
    for b in buttons:
        if b.button_pressed:
            pressed_button = b
            break
        btn_idx += 1

    if pressed_button:
        emit_signal("option_changed", pressed_button.text)
        emit_signal("index_changed", btn_idx)
    else:
        emit_signal("all_off")


