extends Control

signal dragged(relative_pos: Vector2)
signal drag_ended(relative_pos: Vector2)

@onready var bar: ColorRect = find_child("Bar")

@export var bar_highlight_lightness: float = 0.8

var bar_normal_color: Color = Color.BLACK
var bar_highlight_color: Color = Color.WHITE

var drag_start_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false

func _ready() -> void:
    bar_normal_color = bar.color
    bar_highlight_color = bar.color
    bar_highlight_color.ok_hsl_l = bar_highlight_lightness
    mouse_entered.connect(on_mouse_entered)
    mouse_exited.connect(on_mouse_exited)
    visibility_changed.connect(on_visibility_changed)

func on_visibility_changed() -> void:
    if not visible:
        undrag()

func undrag() -> void:
    is_dragging = false
    bar.color = bar_normal_color

func on_mouse_entered() -> void:
    bar.color = bar_highlight_color

func on_mouse_exited() -> void:
    if not is_dragging:
        bar.color = bar_normal_color

func _gui_input(event: InputEvent) -> void:
    var mbe: = event as InputEventMouseButton
    if mbe and mbe.button_index == MOUSE_BUTTON_LEFT:
        if mbe.is_pressed() and not is_dragging:
            drag_start_pos = event.global_position
            is_dragging = true
        elif not mbe.is_pressed() and is_dragging:
            drag_ended.emit(event.global_position - drag_start_pos)
            undrag()
    
    if is_dragging:
        var mme: = event as InputEventMouseMotion
        if mme:
            dragged.emit(mme.global_position - drag_start_pos)


