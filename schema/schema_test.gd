extends SceneTree

const TEST_FILES = [
	"schema/test_files/example_biomes/Basic_.json",
	"schema/test_files/example_biomes/Basic.json",
	"schema/test_files/asset_node_test_data/all_densities.json",
	"schema/test_files/asset_node_test_data/all_positions_curves_vectors.json",
	"schema/test_files/asset_node_test_data/all_materials_and_props.json",
	"schema/test_files/asset_node_test_data/biome_and_misc.json",
	"schema/test_files/asset_node_test_data/new_stuff_added.json",
]

var schema: AssetNodesSchema
var errors: Array[String] = []

func _init():
	print("Testing schema against %d files..." % TEST_FILES.size())
	
	# Load schema
	schema = load("res://schema/asset_nodes_schema.gd").new()
	
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
				if not conn_def.get("value_type", ""):
					add_error("Node '%s' connection '%s' missing value_type field" % [node_name, conn_name])
				var value_type = conn_def["value_type"]
				if not schema.value_types.has(value_type):
					add_error("Value type '%s' referenced in node '%s' connection '%s' but not in value_types array" % [value_type, node_name, conn_name])

## Check that output_value_type matches the inferred type from connection_type_node_type_lookup
func validate_output_value_types():
	for type_key in schema.connection_type_node_type_lookup:
		var parts = type_key.split("|")
		if parts.size() != 2:
			continue
		
		var expected_output = parts[0]
		var node_name = schema.connection_type_node_type_lookup[type_key]
		
		if not schema.node_schema.has(node_name):
			add_error("Node '%s' in connection_type_node_type_lookup but not in node_schema" % node_name)
			continue
		
		var node_def = schema.node_schema[node_name]
		if not node_def.has("output_value_type"):
			add_error("Node '%s' missing output_value_type field" % node_name)
			continue
		
		var actual_output = node_def["output_value_type"]
		if actual_output != expected_output:
			add_error("Node '%s' has output_value_type '%s' but connection_type_node_type_lookup implies '%s'" % [node_name, actual_output, expected_output])

## Check that workspace_root_types reference valid node types
func validate_workspace_root_types():
	for workspace_id in schema.workspace_no_output_types:
		var node_type = schema.workspace_no_output_types[workspace_id]
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
	
	var root_data = json.data
	if typeof(root_data) != TYPE_DICTIONARY:
		add_error("Root of JSON file '%s' is not a dictionary" % file_path)
		return
	
	# Validate root node
	var workspace_id = root_data.get("$NodeEditorMetadata", {}).get("$WorkspaceID", "")
	if workspace_id == "":
		workspace_id = root_data.get("$WorkspaceID", "")
	if workspace_id == "":
		add_error("No workspace ID found in root node or editor metadata in file '%s'" % file_path)

	var root_type = schema.resolve_root_asset_node_type(workspace_id, root_data)
	validate_node(root_data, root_type, "NO_OUTPUT_TYPE", file_path)
	
	# Walk all nodes recursively, tracking their parent connection types
	walk_node_recursive(root_data, root_type, file_path)

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
					var child_type = schema.resolve_asset_node_type(value.get("Type", "NO_TYPE_KEY"), expected_value_type)
					validate_node(value, child_type, expected_value_type, file_path)
					walk_node_recursive(value, child_type, file_path)
			elif typeof(value) == TYPE_ARRAY:
				for item in value:
					if typeof(item) == TYPE_DICTIONARY and item.has("$NodeId"):
						var child_type = schema.resolve_asset_node_type(item.get("Type", "NO_TYPE_KEY"), expected_value_type)
						validate_node(item, child_type, expected_value_type, file_path)
						walk_node_recursive(item, child_type, file_path)

## Validate a single node
func validate_node(node: Dictionary, node_type: String, expected_value_type: String, file_path: String):
	var node_id = node.get("$NodeId", "UNKNOWN")
	
	if node_type == "Unknown":
		add_error("Cannot infer type for node '%s' in file '%s' with expected value type '%s'" % [node_id, file_path, expected_value_type])
	else:
		var id_prefix = schema.get_id_prefix_for_node_type(node_type)
		if not node_id.begins_with("%s-" % id_prefix):
			add_error("Node of type '%s' has incorrect ID prefix: expected '%s-', id was: '%s'" % [node_type, id_prefix, node_id])
			add_error("<<%s::%s>>" % [node_type, node_id.substr(0, node_id.find("-"))])
	
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
		
		# Validate connection multi property
		if is_connection:
			var conn_def = node_def["connections"][prop_name]
			var is_multi = conn_def.get("multi", false)
			var is_array = typeof(prop_value) == TYPE_ARRAY
			
			if is_array and not is_multi:
				add_error("Node '%s' (type '%s') connection '%s' is an array but schema doesn't mark it as multi: true in file '%s'" % [node_id, node_type, prop_name, file_path])
			elif not is_array and is_multi and typeof(prop_value) == TYPE_DICTIONARY:
				add_error("Node '%s' (type '%s') connection '%s' is marked as multi: true but contains a single node (should be array) in file '%s'" % [node_id, node_type, prop_name, file_path])

## Add an error message
func add_error(message: String):
	print("ERROR: %s" % message)
	errors.append(message)
