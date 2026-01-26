extends SceneTree

const TEST_FILES = [
	"test_files/example_biomes/Basic_.json",
	"test_files/example_biomes/Basic.json",
	"test_files/asset_node_test_data/all_densities.json",
	"test_files/asset_node_test_data/all_positions_curves_vectors.json",
	"test_files/asset_node_test_data/all_materials_and_props.json",
	"test_files/asset_node_test_data/biome_and_misc.json",
]

var schema: AssetNodesSchema
var errors: Array[String] = []

func _init():
	print("Testing schema against %d files..." % TEST_FILES.size())
	
	# Load schema
	schema = load("res://model/asset_nodes_schema.gd").new()
	
	# Run all validation checks
	validate_value_types_complete()
	validate_output_value_types()
	validate_workspace_root_types()
	
	# Validate JSON files
	for file_path in TEST_FILES:
		validate_json_file(file_path)
	
	# Print results
	if errors.is_empty():
		print("PASSED: All tests passed!")
		quit(0)
	else:
		print("\nFAILED: %d errors found" % errors.size())
		quit(1)

## Check that all value_types referenced in connections exist in value_types array
func validate_value_types_complete():
	for node_name in schema.node_schema:
		var node_def = schema.node_schema[node_name]
		if node_def.has("connections"):
			for conn_name in node_def["connections"]:
				var conn_def = node_def["connections"][conn_name]
				var value_type = conn_def["value_type"]
				if not schema.value_types.has(value_type):
					add_error("Value type '%s' referenced in node '%s' connection '%s' but not in value_types array" % [value_type, node_name, conn_name])

func validate_output_value_types():
	"""Check that output_value_type matches the inferred type from node_types"""
	for type_key in schema.node_types:
		var parts = type_key.split("|")
		if parts.size() != 2:
			continue
		
		var expected_output = parts[0]
		var node_name = schema.node_types[type_key]
		
		if not schema.node_schema.has(node_name):
			add_error("Node '%s' in node_types but not in node_schema" % node_name)
			continue
		
		var node_def = schema.node_schema[node_name]
		if not node_def.has("output_value_type"):
			add_error("Node '%s' missing output_value_type field" % node_name)
			continue
		
		var actual_output = node_def["output_value_type"]
		if actual_output != expected_output:
			add_error("Node '%s' has output_value_type '%s' but node_types implies '%s'" % [node_name, actual_output, expected_output])

## Check that workspace_root_types reference valid node types
func validate_workspace_root_types():
	for workspace_id in schema.workspace_root_types:
		var node_type = schema.workspace_root_types[workspace_id]
		if not schema.node_schema.has(node_type):
			add_error("Workspace type '%s' maps to missing node type '%s'" % [workspace_id, node_type])

## Validate all nodes in a JSON file
func validate_json_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		add_error("Cannot open file '%s'" % file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		add_error("JSON parse error in file '%s': %s" % [file_path, json.get_error_message()])
		return
	
	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		add_error("Root of JSON file '%s' is not a dictionary" % file_path)
		return
	
	# Validate root node
	var workspace_id = root.get("$NodeEditorMetadata", {}).get("$WorkspaceID", "")
	var root_type = infer_node_type_root(root, workspace_id)
	validate_node(root, root_type, file_path)
	
	# Walk all nodes recursively, tracking their parent connection types
	walk_node_recursive(root, root_type, file_path)

## Recursively walk all nodes and their connections
func walk_node_recursive(node: Variant, parent_type: String, file_path: String):
	if typeof(node) != TYPE_DICTIONARY:
		return
	
	# Get the node schema to know what connections to expect
	var node_schema_def = null
	if schema.node_schema.has(parent_type):
		node_schema_def = schema.node_schema[parent_type]
	
	for key in node:
		var value = node[key]
		
		# Skip metadata
		if key.begins_with("$"):
			continue
		
		# Determine if this is a connection or setting
		var is_connection = false
		var expected_value_type = ""
		if node_schema_def != null and node_schema_def.has("connections"):
			if node_schema_def["connections"].has(key):
				is_connection = true
				expected_value_type = node_schema_def["connections"][key]["value_type"]
		
		if is_connection:
			# This is a connection - recurse into child nodes
			if typeof(value) == TYPE_DICTIONARY:
				if value.has("$NodeId"):
					var child_type = infer_node_type(value, expected_value_type)
					validate_node(value, child_type, file_path)
					walk_node_recursive(value, child_type, file_path)
			elif typeof(value) == TYPE_ARRAY:
				for item in value:
					if typeof(item) == TYPE_DICTIONARY and item.has("$NodeId"):
						var child_type = infer_node_type(item, expected_value_type)
						validate_node(item, child_type, file_path)
						walk_node_recursive(item, child_type, file_path)

## Validate a single node
func validate_node(node: Dictionary, node_type: String, file_path: String):
	var node_id = node.get("$NodeId", "UNKNOWN")
	
	if node_type == "":
		add_error("Cannot infer type for node '%s' in file '%s'" % [node_id, file_path])
		return
	
	# Get the node schema
	if not schema.node_schema.has(node_type):
		add_error("Node '%s' (type '%s') not found in schema in file '%s'" % [node_id, node_type, file_path])
		return
	
	var node_def = schema.node_schema[node_type]
	
	# Check all properties
	for prop_name in node:
		# Skip metadata properties and Type (used for inference)
		if prop_name.begins_with("$") or prop_name == "Type":
			continue
		
		var prop_value = node[prop_name]
		
		# Check if it's a setting
		var is_setting = node_def.has("settings") and node_def["settings"].has(prop_name)
		
		# Check if it's a connection
		var is_connection = node_def.has("connections") and node_def["connections"].has(prop_name)
		
		if not is_setting and not is_connection:
			add_error("Node '%s' (type '%s') has undocumented property '%s' in file '%s'" % [node_id, node_type, prop_name, file_path])
			continue
		
		# Validate setting types
		if is_setting:
			var expected_type = node_def["settings"][prop_name]["gd_type"]
			var actual_type = typeof(prop_value)
			
			# JSON doesn't distinguish between int and float, so accept float for int fields
			var type_matches = (actual_type == expected_type) or (expected_type == TYPE_INT and actual_type == TYPE_FLOAT)
			
			if not type_matches:
				add_error("Node '%s' (type '%s') property '%s' has wrong type: expected %s, got %s in file '%s'" % [node_id, node_type, prop_name, type_string(expected_type), type_string(actual_type), file_path])

## Infer the type of the root node
func infer_node_type_root(node: Dictionary, workspace_id: String) -> String:
	if workspace_id != "" and schema.workspace_root_types.has(workspace_id):
		return schema.workspace_root_types[workspace_id]
	return ""

## Infer the node type from a JSON node given its parent connection type
func infer_node_type(node: Dictionary, parent_value_type: String) -> String:
	if parent_value_type == "":
		return ""
	
	# Get the Type field value (empty string if not present)
	var type_value = node.get("Type", "")
	
	# Look up in node_types using format "{ValueType}|{Type}"
	var key = "%s|%s" % [parent_value_type, type_value]
	if schema.node_types.has(key):
		return schema.node_types[key]
	
	return ""

## Add an error message
func add_error(message: String):
	print("ERROR: %s" % message)
	errors.append(message)
