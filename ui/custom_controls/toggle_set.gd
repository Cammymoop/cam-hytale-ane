extends HBoxContainer
class_name GNToggleSet

var labeled_check_box_scn: PackedScene = preload("res://ui/custom_controls/labeled_check_box.tscn")

signal members_changed(members: Array)

@export var potential_members: Array = []

func _ready() -> void:
    update_display()

func setup(new_potential_members: Array, current_members: Array) -> void:
    _set_potential_members(new_potential_members)
    set_members_directly(current_members)

func _set_potential_members(new_potential_members: Array) -> void:
    potential_members = new_potential_members
    update_display()

func add_member(member: Variant) -> void:
    var member_idx: = potential_members.find(member)
    if member_idx > -1:
        get_child(member_idx).button_pressed = true
    notify_members_changed()

func remove_member(member: Variant) -> void:
    var member_idx: = potential_members.find(member)
    if member_idx > -1:
        get_child(member_idx).button_pressed = false
    notify_members_changed()

func notify_members_changed() -> void:
    members_changed.emit(_get_current_members())

func _get_current_members() -> Array:
    var members: Array = []
    for member_idx in potential_members.size():
        if member_idx >= get_child_count():
            return members
        var member_val: Variant = potential_members[member_idx]
        if get_child(member_idx).button_pressed:
            members.append(member_val)
    return members

func set_current_members(members: Array) -> void:
    set_members_directly(members)
    members_changed.emit(members)

func set_members_directly(members: Array) -> void:
    for member_idx in potential_members.size():
        var member_val: Variant = potential_members[member_idx]
        var check_box: = get_child(member_idx) as LabeledCheckBox

        check_box.set_pressed_no_signal(member_val in members)

func clear_children() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

func update_display() -> void:
    var old_members: Array = _get_current_members()
    clear_children()
    
    for member_idx in potential_members.size():
        var member_name: String = str(potential_members[member_idx])
        var check_box: = labeled_check_box_scn.instantiate() as LabeledCheckBox
        check_box.text = member_name
        check_box.toggled.connect(on_member_toggled.bind(member_idx))
        add_child(check_box)
    
    set_members_directly(old_members)

func on_member_toggled(is_pressed: bool, member_idx: int) -> void:
    if is_pressed:
        add_member(potential_members[member_idx])
    else:
        remove_member(potential_members[member_idx])
