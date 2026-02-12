@tool
extends EditorScript
class_name VersionCheckIncrement

class RefHolder extends Node:
    var ref: EditorScript
    func _init(the_ref: EditorScript) -> void:
        ref = the_ref
        name = "RefHolder"

var ref_holder: RefHolder
var shown_dialogs: Array[Window] = []

func _run() -> void:
    if not check_for_git_on_path():
        return
    
    var tag_version: String = get_latest_tag_version().trim_prefix("v")
    var project_ver: String = get_project_version()

    if not tag_version:
        return
    
    ref_holder = RefHolder.new(self)
    EditorInterface.get_base_control().add_child(ref_holder, true)

    if tag_version != project_ver:
        version_mismatch(tag_version, project_ver)
    else:
        version_match(tag_version)

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if ref_holder:
            ref_holder.queue_free()
            ref_holder = null

func end_script() -> void:
    if ref_holder:
        ref_holder.queue_free()
        ref_holder = null

func version_match(cur_version: String) -> void:
    var prompt_text: = "The latest version tag is v%s, which matches the project version. Do you want to increment the version?" % [cur_version]
    show_confirm_with_callback(prompt_text, incrementing_project_version.bind(cur_version), "Project Version Check")

func version_mismatch(tag_version: String, project_ver: String) -> void:
    var compare_result: = version_compare(tag_version, project_ver)
    if compare_result <= -100:
        show_error_dialog("Failed to compare versions")
        return

    if compare_result > 0:
        var prompt_text: = "The latest version tag is v%s, wich is behind the project version: %s. Do you want to tag version %s?" % [tag_version, project_ver, project_ver]
        show_confirm_with_callback(prompt_text, tagging_new_version.bind(project_ver, project_ver), "Project Version Check")
    else:
        var prompt_text: = "The latest version tag is v%s, which is ahead of the project version: %s. Do you want to set the project version to the tag version?" % [tag_version, project_ver]
        var callback: = replacing_project_version.bind(tag_version)
        show_confirm_with_callback(prompt_text, callback, "Project Version Check")


func replacing_project_version(tag_version: String) -> void:
    if replace_project_version(tag_version):
        if not check_for_remote_tag(tag_version):
            ask_to_push_tag(tag_version)

func incrementing_project_version(cur_version: String) -> void:
    if is_uncommitted_changes():
        show_confirm_with_callback("There are uncommitted changes, Do you want to commit all changes and increment the version?", incrementing_confirmed.bind(cur_version), "Uncommitted Changes")
    else:
        incrementing_confirmed(cur_version)

func incrementing_confirmed(cur_version: String) -> void:
    var new_version: = apply_version_increment(cur_version, cur_version)
    if new_version:
        ask_to_push_tag(new_version)

func tagging_new_version(cur_project_version: String, new_version: String) -> void:
    if is_uncommitted_changes():
        var prompt_text: = "There are uncommitted changes, Do you want to commit all changes and tag version %s?" % [new_version]
        show_confirm_with_callback(prompt_text, tagging_new_version_confirmed.bind(cur_project_version, new_version), "Tag Version")
    else:
        tagging_new_version_confirmed(cur_project_version, new_version)

func tagging_new_version_confirmed(cur_project_version: String, new_version: String) -> void:
    var result_version: = apply_version_increment(cur_project_version, "", new_version)
    if result_version:
        ask_to_push_tag(result_version)


func ask_to_push_tag(latest_ver: String) -> void:
    var prompt_text: = "Project version updated to %s. Do you want to push the git tag to trigger a release build?" % [latest_ver]
    show_confirm_with_callback(prompt_text, pushing_tag, "Push Tag")

func pushing_tag() -> void:
    if push_tag():
        show_info_dialog("Tag pushed successfully")


# dialogs

func show_info_dialog(info_text: String) -> void:
    var info_dialog: AcceptDialog = AcceptDialog.new()
    info_dialog.title = "Info"
    info_dialog.dialog_text = info_text
    _show_dialog(info_dialog)

func show_error_dialog(error_text: String) -> void:
    var error_dialog: AcceptDialog = AcceptDialog.new()
    error_dialog.get_ok_button().text = "RIP"
    error_dialog.title = "Error"
    error_dialog.dialog_text = error_text
    _show_dialog(error_dialog)

func show_confirm_with_callback(prompt_text: String, callback: Callable, title: String = "Confirm") -> void:
    var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
    confirm_dialog.get_cancel_button().text = "No"
    confirm_dialog.get_ok_button().text = "Yes"
    confirm_dialog.title = title
    confirm_dialog.dialog_text = prompt_text
    confirm_dialog.get_cancel_button().pressed.connect(confirm_dialog.queue_free)
    confirm_dialog.confirmed.connect(callback)
    confirm_dialog.confirmed.connect(print.bind("confirmed"))
    _show_dialog(confirm_dialog)

func _show_dialog(dialog: Window) -> void:
    dialog.set_unparent_when_invisible(true)
    dialog.tree_exited.connect(dialog.queue_free)
    dialog.tree_exited.connect(_on_dialog_tree_exited)
    dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
    shown_dialogs.append(dialog)
    EditorInterface.popup_dialog_centered(dialog)

func _on_dialog_tree_exited() -> void:
    for dialog in shown_dialogs:
        if not is_instance_valid(dialog) or dialog.is_queued_for_deletion() or not dialog.is_inside_tree():
            shown_dialogs.erase(dialog)
    
    if shown_dialogs.size() == 0:
        end_script()


# details

func get_latest_tag_version() -> String:
    var output: Array = []
    var exec_code: = OS.execute("git", ["describe", "--tags", "--abbrev=0"], output)
    if exec_code != 0:
        show_error_dialog("Failed to get latest tag version")
        return ""
    for line: String in output[0].split("\n"):
        if line.strip_edges().begins_with("v") and line.contains("."):
            return line.strip_edges()
    show_error_dialog("Did not find a version-like tag")
    return ""

func check_for_git_on_path() -> bool:
    var exec_code: = OS.execute("git", ["--version"], [])
    if exec_code != 0:
        show_error_dialog("Git is not on the path")
        return false
    return true

func get_project_version() -> String:
    var project_settings: = ConfigFile.new()
    project_settings.load("res://project.godot")
    return project_settings.get_value("application", "config/version")

func version_compare(version_a: String, version_b: String) -> int:
    version_a = version_a.strip_edges().trim_prefix("v")
    version_b = version_b.strip_edges().trim_prefix("v")
    if version_a == version_b:
        return 0
    var version_a_parts: PackedStringArray = version_a.split(".")
    var version_b_parts: PackedStringArray = version_b.split(".")
    if version_a_parts.size() != version_b_parts.size():
        show_error_dialog("Version strings with different number of parts: %s and %s" % [version_a, version_b])
        return -100
    
    for part_i in version_a_parts.size():
        if int(version_a_parts[part_i]) != int(version_b_parts[part_i]):
            return -signi(int(version_a_parts[part_i]) - int(version_b_parts[part_i]))
    return 0

func increment_version(version_str: String, target_version: String) -> String:
    var compare_result: = version_compare(version_str, target_version)
    if compare_result <= -100:
        return version_str
    
    if compare_result < 0:
        pass
        

    var version_parts: Array[String] = version_str.split(".")
    var patch: = int(version_parts[2])
    patch += 1
    version_parts[2] = str(patch)
    return ".".join(version_parts)

func replace_project_version(new_version: String) -> bool:
    var project_settings: = ConfigFile.new()
    var load_error: = project_settings.load("res://project.godot")
    if load_error != OK:
        show_error_dialog("Failed to load project.godot as config file")
        return false
    project_settings.set_value("application", "config/version", new_version)
    var error: = project_settings.save("res://project.godot")
    if error != OK:
        show_error_dialog("Failed to save project.godot")
        return false
    return true

func apply_version_increment(cur_project_version: String, cur_tag_version: String, target_version: String = "") -> String:
    var new_version: = target_version
    if target_version == "":
        new_version = increment_version(cur_project_version, target_version)
        if new_version == cur_project_version:
            show_error_dialog("Failed to increment version")
            return ""

    if cur_project_version != new_version:
        var project_settings: = ConfigFile.new()
        project_settings.load("res://project.godot")
        project_settings.set_value("application", "config/version", new_version)
        project_settings.save("res://project.godot")
    
    if cur_tag_version != new_version:
        var output: Array[String] = []
        var exec_code: = OS.execute("git", ["add", "."], output)
        if exec_code != 0:
            show_error_dialog("Failed executing git to add project.godot")
            print("git errot output: %s" % output[0])
            return ""

        var commit_message: = "Increment version to %s" % new_version
        if is_uncommitted_changes():
            commit_message += " (with pending changes)"
        exec_code = OS.execute("git", ["commit", "-m", commit_message], output)
        if exec_code != 0:
            show_error_dialog("Failed executing git to commit project.godot")
            print("git errot output: %s" % output[0])
            return ""

        exec_code = OS.execute("git", ["tag", "-a", "v%s" % new_version, "-m", "Version %s" % new_version], output)
        if exec_code != 0:
            show_error_dialog("Failed executing git to create version tag")
            print("git errot output: %s" % output[0])
            return ""

    return new_version

func is_uncommitted_changes() -> bool:
    var output: Array[String] = []
    var exec_code: = OS.execute("git", ["status", "--porcelain"], output)
    if exec_code != 0:
        show_error_dialog("Failed executing git to check for uncommitted changes")
        return true
    var line_count: = 0
    for line: String in output[0].split("\n"):
        if line.strip_edges().length() > 0:
            line_count += 1
    return line_count > 0

func push_tag() -> bool:
    var output: Array[String] = []
    var exec_code: = OS.execute("git", ["push", "--tags"], output)
    if exec_code != 0:
        show_error_dialog("Failed executing git to push tags")
        return false
    return true

func check_for_remote_tag(tag_version: String) -> bool:
    var output: Array[String] = []
    var search_string: = "refs/tags/v%s" % tag_version

    var exec_code: = OS.execute("git", ["ls-remote", "--tags"], output)
    if exec_code != 0:
        show_error_dialog("Failed executing git to check for remote tags")
        print("git error output: %s" % output[0])
        return false
    for line: String in output:
        if line.contains(search_string):
            print("remote tag found: %s" % line)
            return true
    print("remote tag '%s' not found: %s" % [search_string, output[0]])
    return false