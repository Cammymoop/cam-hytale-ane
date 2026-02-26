## Keeps WeakRef references to created fragments so they can be retrieved by id, but still get freed as soon as they are no longer referenced elsewhere
##
## For example, fragments created by copying nodes that aren't used to paste before another set of nodes is copied will not stick around 
## as they are no longer referenced by the editor nor by any undo/redo action
extends Node

const Fragment: = preload("./asset_node_fragment.gd")

var fragments: Dictionary[String, WeakRef] = {}

func get_fragment_by_id(fragment_id: String) -> Fragment:
    if not fragments.has(fragment_id):
        print_debug("Fragment not found: %s" % fragment_id)
        return null
    return _get_fragment(fragment_id)

func _get_fragment(fragment_id: String) -> Fragment:
    var fragment: Fragment = fragments[fragment_id].get_ref()
    if not fragment:
        fragments.erase(fragment_id)
        return null
    #elif fragment.get_reference_count() == 1:
        #print_debug("Fragment %s has reference count of 1, I think that means it was no longer referenced (until now) but wasn't freed yet")
    return fragment

func has(fragment_id: String) -> bool:
    return fragments.has(fragment_id) and fragments[fragment_id].get_ref() != null

func register_fragment(fragment: Fragment) -> void:
    assert(fragment.fragment_id and not fragments.has(fragment.fragment_id), "Fragment ID must be set and unique")
    fragments[fragment.fragment_id] = weakref(fragment)

func remove_fragment(fragment: Fragment) -> void:
    assert(fragment.fragment_id, "Fragment ID must be set to remove fragment")
    fragments.erase(fragment.fragment_id)

func remove_all_except(keep_fragment_ids: Array[String]) -> void:
    for fragment_id in fragments.keys():
        if not fragment_id in keep_fragment_ids:
            fragments.erase(fragment_id)

func clear() -> void:
    fragments.clear()

