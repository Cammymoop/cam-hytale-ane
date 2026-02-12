extends Node

const UndoStep = preload("res://graph_editor/undo_redo/undo_step.gd")
const GraphUndoStep = preload("res://graph_editor/undo_redo/graph_undo_step.gd")

var editor: CHANE_AssetNodeEditor = null

var undo_redo: UndoRedo = UndoRedo.new()

var active_undo_step: UndoStep = null
var last_committed_undo_step: UndoStep = null
var is_new_step: bool = false

func set_editor(the_editor: CHANE_AssetNodeEditor) -> void:
    editor = the_editor

func clear() -> void:
    undo_redo.clear_history(true)

## Call this when saving to solidify the current step so the exact state where the file was saved is always accessible and not lost in a merge
func prevent_merges() -> void:
    if active_undo_step and active_undo_step.has_existing_action:
        active_undo_step = null

func is_creating_undo_step() -> bool:
    return active_undo_step != null

func get_last_committed_undo_step() -> UndoStep:
    return last_committed_undo_step

func start_undo_step(action_name: String) -> UndoStep:
    if active_undo_step:
        push_error("Starting an undo step '%s' while one is active but not committed ('%s')" % [action_name, active_undo_step.action_name])
        print_debug("Starting an undo step '%s' while one is active but not committed ('%s')" % [action_name, active_undo_step.action_name])
        commit_current_undo_step()

    var new_undo_step: UndoStep = UndoStep.new()
    new_undo_step.action_name = action_name
    new_undo_step.set_editor(editor)
    active_undo_step = new_undo_step
    is_new_step = true
    return new_undo_step

func cancel_creating_undo_step() -> void:
    if not active_undo_step:
        return
    if active_undo_step.is_uncancelable:
        push_error("Trying to cancel an undo step '%s' that is uncancelable" % active_undo_step.action_name)
        print_debug("Trying to cancel an undo step '%s' that is uncancelable" % active_undo_step.action_name)
        return
    active_undo_step = null
    is_new_step = false

func start_undo_graph_step(action_name: String, for_graph: CHANE_AssetNodeGraphEdit) -> GraphUndoStep:
    var undo_step: = start_undo_step(action_name)
    return undo_step.get_undo_for_graph(for_graph)

func start_or_continue_undo_step(action_name: String) -> UndoStep:
    if active_undo_step:
        is_new_step = false
        return active_undo_step
    return start_undo_step(action_name)

func start_or_continue_graph_undo_step(action_name: String, for_graph: CHANE_AssetNodeGraphEdit) -> GraphUndoStep:
    var undo_step: = start_or_continue_undo_step(action_name)
    return undo_step.get_undo_for_graph(for_graph)

func rename_current_undo_step(new_action_name: String) -> void:
    if active_undo_step:
        active_undo_step.action_name = new_action_name

func commit_if_new(merge_mode_override: int = -1) -> void:
    if active_undo_step and is_new_step:
        commit_current_undo_step(merge_mode_override)
    else:
        print_debug("not committing undo step because it is not new")

func commit_current_undo_step(merge_mode_override: int = -1) -> void:
    if not active_undo_step:
        push_error("No active undo step to commit")
        return

    active_undo_step.commit(undo_redo, merge_mode_override)
    last_committed_undo_step = active_undo_step
    active_undo_step = null

func recommit_undo_step(undo_step: UndoStep) -> void:
    if undo_step != last_committed_undo_step:
        push_error("Trying to recommit undo step '%s' that is not the last committed undo step ('%s')" % [undo_step.action_name, last_committed_undo_step.action_name])
        return
    last_committed_undo_step.commit(undo_redo)

func has_undo() -> bool:
    return undo_redo.has_undo()
func has_redo() -> bool:
    return undo_redo.has_redo()
func undo() -> void:
    undo_redo.undo()
func redo() -> void:
    undo_redo.redo()
    
func get_undo_action_name() -> String:
    if not undo_redo.has_undo():
        return ""
    return undo_redo.get_current_action_name()

func get_redo_action_name() -> String:
    if not undo_redo.has_redo():
        return ""
    return undo_redo.get_action_name(undo_redo.get_current_action() + 1)