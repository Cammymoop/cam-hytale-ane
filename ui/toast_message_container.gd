extends Control

@onready var toast_message_label: Label = find_child("ToastMessageLabel")
@onready var toast_animator: AnimationPlayer = find_child("ToastAnimator")

@export var message_queue_max_size: = 12 
@export var message_queue_clip_end_time: = 0.3

var message_queue: Array[String] = []

func show_toast_message(message: String) -> void:
    if message_queue and message_queue.front() == message:
        return
    if message_queue.size() >= message_queue_max_size:
        message_queue.pop_back()
    message_queue.append(message)
    
func do_show_message(message: String) -> void:
    toast_message_label.text = message
    toast_animator.play("show")

func is_anim_playing() -> bool:
    return toast_animator.is_playing() and not toast_animator.current_animation == "RESET"

func cur_anim_time_left() -> float:
    return toast_animator.current_animation_length - toast_animator.current_animation_position

func _process(_delta: float) -> void:
    if message_queue.size() > 0:
        if is_anim_playing():
            if cur_anim_time_left() < message_queue_clip_end_time:
                toast_animator.play("RESET")
            return
        do_show_message(message_queue.pop_front())