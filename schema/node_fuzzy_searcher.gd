extends Node

const MAX_FUZZY_LENGTH: int = 80

var node_type_names: Array[StringName] = []

var category_num: int = 0

const MAX_NAME_LENGTH: int = 99
var node_type_display_name_lengths: Dictionary[StringName, int] = {}
var node_type_category_index: Dictionary[StringName, int] = {}

var display_names: Array[String]
var display_name_index: Dictionary[int, StringName] = {}

var alt_keywords: Array[String]
var alt_keyword_index: Dictionary[int, Array] = {}

var search_results: Array[StringName] = []
var search_priorities: Array[String]

func _ready() -> void:
    build_index()

func build_index() -> void:
    var schema: AssetNodesSchema = SchemaManager.schema
    category_num = schema.value_types.size()
    node_type_names.clear()
    display_names.clear()
    display_name_index.clear()
    alt_keywords.clear()
    alt_keyword_index.clear()
    
    for type_name in schema.node_schema:
        node_type_names.append(type_name)
        if not schema.node_schema[type_name].get("no_output", false):
            var output_type: String = schema.node_schema[type_name]["output_value_type"]
            node_type_category_index[type_name] = schema.value_types.find(output_type)
        else:
            node_type_category_index[type_name] = 0
        if schema.node_schema[type_name].has("display_name"):
            var display_name: String = schema.node_schema[type_name]["display_name"].to_lower()
            var idx: int = display_names.find(display_name)
            if idx == -1:
                idx = display_names.size()
                display_names.append(display_name)
            display_name_index[idx] = type_name
            
            node_type_display_name_lengths[type_name] = min(display_name.length(), MAX_NAME_LENGTH)
        else:
            node_type_display_name_lengths[type_name] = min(type_name.length(), MAX_NAME_LENGTH)

        if schema.alt_search_text.has(type_name):
            for alt_keyword in schema.alt_search_text[type_name].split(",", false):
                var alt_keyword_idx: int = alt_keywords.find(alt_keyword)
                if alt_keyword_idx == -1:
                    alt_keyword_idx = alt_keywords.size()
                    alt_keywords.append(alt_keyword)
                    alt_keyword_index[alt_keyword_idx] = Array([], TYPE_STRING, "", null)
                alt_keyword_index[alt_keyword_idx].append(type_name)

func search(query: String) -> void:
    search_results.clear()
    if not query.strip_edges():
        return
    query = query.strip_edges().to_lower()
    var result_scores: Dictionary[StringName, int] = {}
    
    var fuzzy_query: String = query.replace(" ", "").substr(0, MAX_FUZZY_LENGTH)
    var fuzzy_regex_str: = ""
    for i in fuzzy_query.length() - 1:
        fuzzy_regex_str += fuzzy_query[i] + ".*?"
    fuzzy_regex_str += fuzzy_query[fuzzy_query.length() - 1]
    
    var fuz_regex: = RegEx.new()
    fuz_regex.compile(fuzzy_regex_str)
    
    var add_result: = func(matched_string: String, type_name: StringName, level: int, is_fuzzy: bool) -> void:
        if not search_results.has(type_name):
            search_results.append(type_name)
        
        # priorities
        # 1: Typed string is at the start of the matched name
        var is_prefix: bool = matched_string.begins_with(query)
        var match_score: int = 1 + int(is_prefix)
        match_score *= 10
        # 2: Prefer non-fuzzy matches
        match_score += int(not is_fuzzy)
        match_score *= 100
        # 3: Prefer nodes in higher categories in terms of the default listing order
        match_score += category_num - node_type_category_index[type_name]
        match_score *= 10
        # 4: Display name matches rank highest, followed by internal alt keyword, then internal type name
        match_score += level
        match_score *= 100
        # 5: Break ties by shorter display names
        match_score += MAX_NAME_LENGTH - node_type_display_name_lengths[type_name]
        result_scores[type_name] = maxi(result_scores.get(type_name, 0.0), match_score)

    # Search by display name
    for display_name_idx in display_names.size():
        var display_name: String = display_names[display_name_idx]
        if display_name.contains(query):
            add_result.call(display_name, display_name_index[display_name_idx], 3, false)
        elif fuz_regex.search(display_name):
            add_result.call(display_name, display_name_index[display_name_idx], 3, true)
    
    # Search by alt keyword
    for alt_keyword_idx in alt_keywords.size():
        var keyword: String = alt_keywords[alt_keyword_idx]
        if keyword.contains(query):
            for type_name in alt_keyword_index[alt_keyword_idx]:
                add_result.call(keyword, type_name, 2, false)
        elif fuz_regex.search(keyword):
            for type_name in alt_keyword_index[alt_keyword_idx]:
                add_result.call(keyword, type_name, 2, true)

    # Search by internal type name
    for type_name in node_type_names:
        if type_name.contains(query):
            add_result.call(type_name, type_name, 1, false)
        elif fuz_regex.search(type_name):
            add_result.call(type_name, type_name, 1, true)
    
    var result_sorter: = func(a: StringName, b: StringName) -> bool: return result_scores[a] > result_scores[b]
    search_results.sort_custom(result_sorter)
    
    if OS.has_feature("editor"):
        search_priorities.clear()
        for search_result in search_results:
            search_priorities.append("%s :: %s" % [result_scores[search_result], search_result])


