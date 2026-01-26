extends Resource
class_name AssetNodesSchema

@export var value_types: Array[String] = [
    "Density",
    "Curve",
    "CurvePoint",
    "Positions",
    "Material",
    "MaterialID",
    "VectorProvider",
]
@export var node_types: Dictionary[String, String] = {
    "Density|Constant": "ConstantDensity",
    "Density|Sum": "SumDensity",
}
@export var workspace_root_types: Dictionary[String, String] = {
    "HytaleGenerator - Biome": "__BiomeRoot",
}

@export var node_schema: Dictionary[String, Dictionary] = {
    "ConstantDensity": {
        "display_name": "Constant Density",
        "settings": {
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "SumDensity": {
        "display_name": "Sum Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
}
@export var override_types: Dictionary[String, String] = {}
@export var connection_type_schema: Dictionary[String, Dictionary] = {}

func get_node_type_default_name(node_type: String) -> String:
    if not node_schema.has(node_type):
        return node_type
    return node_schema[node_type]["display_name"]