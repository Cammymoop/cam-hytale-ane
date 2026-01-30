extends Resource
class_name AssetNodesSchema

var full_id_prefix_lookup: Dictionary[String, String] = {}

func load_full_id_prefix_lookup() -> void:
    for node_type in node_schema.keys():
        full_id_prefix_lookup[get_id_prefix_for_node_type(node_type)] = node_type

func get_node_type_default_name(node_type: String) -> String:
    if node_type == "Unknown":
        return "[Unknown]"
    if not node_schema.has(node_type):
        return node_type
    return node_schema[node_type]["display_name"]

func resolve_asset_node_type(type_key: String, output_value_type: String, node_id: String = "") -> String:
    if output_value_type == "":
        if node_id == "":
            print_debug("No output type provided, and no node ID provided, cannot infer type")
            return "Unknown"
        else:
            return _unknown_output_type_inference(node_id)
    if output_value_type.begins_with("ROOT"):
        var parts: = output_value_type.split("|")
        if parts.size() != 2:
            print_debug("Invalid root node type key: %s" % output_value_type)
            return "Unknown"
        if parts[1] not in workspace_root_types:
            print_debug("Invalid root node type lookup (workspace id): %s" % parts[1])
            return "Unknown"
        return workspace_root_types[parts[1]]
    else:
        if type_key == "NO_TYPE_KEY":
            type_key = ""
        var type_inference_key: = "%s|%s" % [output_value_type, type_key]
        if not node_types.has(type_inference_key):
            print_debug("Type inference key not found: %s" % type_inference_key)
            return "Unknown"
        return node_types[type_inference_key]

## Needed for floating node roots in the current format
func _unknown_output_type_inference(node_id: String) -> String:
    if not full_id_prefix_lookup:
        load_full_id_prefix_lookup()
    var id_prefix: = node_id.substr(0, node_id.find("-"))
    var node_type: String = full_id_prefix_lookup.get(id_prefix, "Unknown")
    if node_type == "Unknown":
        print_debug("Unknown node type for ID prefix: %s" % id_prefix)
    return node_type

func get_id_prefix_for_node_type(node_type: String) -> String:
    if node_type == "Unknown" or node_type not in node_schema:
        print_debug("Unknown node type, no ID prefix")
        return ""

    return node_schema[node_type].get("id_prefix_override", node_type)

@export var value_types: Array[String] = [
    "Density",
    "Curve",
    "CurvePoint",
    "Positions",
    "Material",
    "MaterialProvider",
    "VectorProvider",
    "Terrain",
    "Pattern",
    "Scanner",
    "BlockMask",
    "BlockSubset",
    "Prop",
    "Assignments",
    "EnvironmentProvider",
    "TintProvider",
    "PCNReturnType",
    "PCNDistanceFunction",
    "Point3D",
    "Point3DInt",
    "PointGenerator",
    "Stripe",
    "WeightedMaterial",
    "DelimiterFieldFunctionMP",
    "DelimiterDensityPCNReturnType",
    "Runtime",
    "Directionality",
    "Condition",
    "Layer",
    "WeightedPath",
    "WeightedProp",
    "SMDelimiterAssignments",
    "FFDelimiterAssignments",
    "DelimiterPattern",
    "CaseSwitch",
    "KeyMultiMix",
    "WeightedAssignment",
    "WeightedClusterProp",
    "BlockColumn",
    "EntryWeightedProp",
    "RuleBlockMask",
    "DelimiterEnvironment",
    "DelimiterTint",
    "Range",
]

@export var node_types: Dictionary[String, String] = {
    # Density nodes
    "Density|Constant": "ConstantDensity",
    "Density|Sum": "SumDensity",
    "Density|Max": "MaxDensity",
    "Density|Min": "MinDensity",
    "Density|Multiplier": "MultiplierDensity",
    "Density|SimplexNoise2D": "SimplexNoise2DDensity",
    "Density|SimplexNoise3D": "SimplexNoise3DDensity",
    "Density|CellNoise2D": "CellNoise2DDensity",
    "Density|CellNoise3D": "CellNoise3DDensity",
    "Density|CurveMapper": "CurveMapperDensity",
    "Density|BaseHeight": "BaseHeightDensity",
    "Density|PositionsCellNoise": "PositionsCellNoiseDensity",
    "Density|VectorWarp": "VectorWarpDensity",
    "Density|GradientWarp": "GradientWarpDensity",
    "Density|FastGradientWarp": "FastGradientWarpDensity",
    "Density|Anchor": "AnchorDensity",
    "Density|Axis": "AxisDensity",
    "Density|Plane": "PlaneDensity",
    "Density|YValue": "YValueDensity",
    "Density|XValue": "XValueDensity",
    "Density|ZValue": "ZValueDensity",
    "Density|YOverride": "YOverrideDensity",
    "Density|XOverride": "XOverrideDensity",
    "Density|ZOverride": "ZOverrideDensity",
    "Density|Inverter": "InverterDensity",
    "Density|Normalizer": "NormalizerDensity",
    "Density|Imported": "ImportedDensity",
    "Density|Cache": "CacheDensity",
    "Density|Shell": "ShellDensity",
    "Density|Clamp": "ClampDensity",
    "Density|SmoothClamp": "SmoothClampDensity",
    "Density|Floor": "FloorDensity",
    "Density|Ceiling": "CeilingDensity",
    "Density|SmoothFloor": "SmoothFloorDensity",
    "Density|SmoothCeiling": "SmoothCeilingDensity",
    "Density|SmoothMax": "SmoothMaxDensity",
    "Density|SmoothMin": "SmoothMinDensity",
    "Density|Abs": "AbsDensity",
    "Density|Sqrt": "SqrtDensity",
    "Density|Pow": "PowDensity",
    "Density|Rotator": "RotatorDensity",
    "Density|Scale": "ScaleDensity",
    "Density|Slider": "SliderDensity",
    "Density|PositionsPinch": "PositionsPinchDensity",
    "Density|PositionsTwist": "PositionsTwistDensity",
    "Density|Ellipsoid": "EllipsoidDensity",
    "Density|Cuboid": "CuboidDensity",
    "Density|Cube": "CubeDensity",
    "Density|Cylinder": "CylinderDensity",
    "Density|Distance": "DistanceDensity",
    "Density|SwitchState": "SwitchStateDensity",
    "Density|Switch": "SwitchDensity",
    "Density|Mix": "MixDensity",
    "Density|MultiMix": "MultiMixDensity",
    "Density|Angle": "AngleDensity",
    "Density|DistanceToBiomeEdge": "DistanceToBiomeEdgeDensity",
    "Density|Terrain": "TerrainDensity",
    "Density|Exported": "ExportedDensity",
    
    # Curve nodes
    "Curve|Manual": "ManualCurve",
    "Curve|DistanceExponential": "DistanceExponentialCurve",
    "Curve|Constant": "ConstantCurve",
    "Curve|Sum": "SumCurve",
    "Curve|Multiplier": "MultiplierCurve",
    
    # Material Provider nodes
    "MaterialProvider|Constant": "ConstantMaterialProvider",
    "MaterialProvider|Solidity": "SolidityMaterialProvider",
    "MaterialProvider|Queue": "QueueMaterialProvider",
    "MaterialProvider|Striped": "StripedMaterialProvider",
    "MaterialProvider|Weighted": "WeightedMaterialProvider",
    "MaterialProvider|FieldFunction": "FieldFunctionMaterialProvider",
    "MaterialProvider|SimpleHorizontal": "SimpleHorizontalMaterialProvider",
    "MaterialProvider|SpaceAndDepth": "SpaceAndDepthMaterialProvider",
    "MaterialProvider|Imported": "ImportedMaterialProvider",
    
    # Positions nodes
    "Positions|Mesh2D": "Mesh2DPositions",
    "Positions|Occurrence": "OccurrencePositions",
    "Positions|Imported": "ImportedPositions",
    "Positions|Offset": "OffsetPositions",
    "Positions|List": "ListPositions",
    
    # Pattern nodes
    "Pattern|Floor": "FloorPattern",
    "Pattern|Ceiling": "CeilingPattern",
    "Pattern|BlockType": "BlockTypePattern",
    "Pattern|BlockSet": "BlockSetPattern",
    "Pattern|Not": "NotPattern",
    "Pattern|Or": "OrPattern",
    "Pattern|And": "AndPattern",
    "Pattern|Offset": "OffsetPattern",
    "Pattern|Imported": "ImportedPattern",
    "Pattern|Wall": "WallPattern",
    "Pattern|Surface": "SurfacePattern",
    "Pattern|Cuboid": "CuboidPattern",
    "Pattern|FieldFunction": "FieldFunctionPattern",
    
    # Scanner nodes
    "Scanner|ColumnLinear": "ColumnLinearScanner",
    "Scanner|ColumnRandom": "ColumnRandomScanner",
    "Scanner|Origin": "OriginScanner",
    "Scanner|Area": "AreaScanner",
    "Scanner|Imported": "ImportedScanner",
    
    # Prop nodes
    "Prop|Box": "BoxProp",
    "Prop|Density": "DensityProp",
    "Prop|Column": "ColumnProp",
    "Prop|Prefab": "PrefabProp",
    "Prop|Cluster": "ClusterProp",
    "Prop|Union": "UnionProp",
    "Prop|Offset": "OffsetProp",
    "Prop|Weighted": "WeightedProp",
    "Prop|Queue": "QueueProp",
    "Prop|PondFiller": "PondFillerProp",
    "Prop|Imported": "ImportedProp",
    
    # Assignments nodes
    "Assignments|Constant": "ConstantAssignments",
    "Assignments|Sandwich": "SandwichAssignments",
    "Assignments|Weighted": "WeightedAssignments",
    "Assignments|Imported": "ImportedAssignments",
    "Assignments|FieldFunction": "FieldFunctionAssignments",
    
    # Environment/Tint Provider nodes
    "EnvironmentProvider|Constant": "ConstantEnvironmentProvider",
    "EnvironmentProvider|DensityDelimited": "DensityDelimitedEnvironmentProvider",
    "TintProvider|Constant": "ConstantTintProvider",
    "TintProvider|DensityDelimited": "DensityDelimitedTintProvider",
    
    # PCN ReturnType nodes
    "PCNReturnType|Density": "DensityPCNReturnType",
    "PCNReturnType|CellValue": "CellValuePCNReturnType",
    "PCNReturnType|Distance": "DistancePCNReturnType",
    "PCNReturnType|Distance2": "Distance2PCNReturnType",
    "PCNReturnType|Distance2Add": "Distance2AddPCNReturnType",
    "PCNReturnType|Distance2Sub": "Distance2SubPCNReturnType",
    "PCNReturnType|Distance2Mul": "Distance2MulPCNReturnType",
    "PCNReturnType|Distance2Div": "Distance2DivPCNReturnType",
    "PCNReturnType|Curve": "CurvePCNReturnType",
    
    # Single-node value types (no Type field - empty string after |)
    "CurvePoint|": "CurvePoint",
    "Material|": "Material",
    "Point3D|": "Point3D",
    "Point3DInt|": "Point3DInt",
    "BlockMask|": "BlockMask",
    "BlockSubset|": "BlockSubset",
    "Stripe|": "Stripe",
    "WeightedMaterial|": "WeightedMaterial",
    "DelimiterFieldFunctionMP|": "DelimiterFieldFunctionMP",
    "DelimiterDensityPCNReturnType|": "DelimiterDensityPCNReturnType",
    "CaseSwitch|": "CaseSwitch",
    "KeyMultiMix|": "KeyMultiMix",
    "WeightedAssignment|": "WeightedAssignment",
    "SMDelimiterAssignments|": "SMDelimiterAssignments",
    "FFDelimiterAssignments|": "FFDelimiterAssignments",
    "DelimiterPattern|": "DelimiterPattern",
    "WeightedPath|": "WeightedPath",
    "WeightedClusterProp|": "WeightedClusterProp",
    "DelimiterEnvironment|": "DelimiterEnvironment",
    "DelimiterTint|": "DelimiterTint",
    "Range|": "Range",
    "BlockColumn|": "BlockColumn",
    "EntryWeightedProp|": "EntryWeightedProp",
    "RuleBlockMask|": "RuleBlockMask",
    
    # PointGenerator nodes
    "PointGenerator|Mesh": "MeshPointGenerator",
    
    # PCNDistanceFunction nodes
    "PCNDistanceFunction|Euclidean": "EuclideanPCNDistanceFunction",
    "PCNDistanceFunction|Manhattan": "ManhattanPCNDistanceFunction",
    
    # Directionality nodes
    "Directionality|Static": "StaticDirectionality",
    "Directionality|Random": "RandomDirectionality",
    "Directionality|Imported": "ImportedDirectionality",
    
    # VectorProvider nodes
    "VectorProvider|Constant": "ConstantVectorProvider",
    
    # Condition nodes (for SpaceAndDepth)
    "Condition|AlwaysTrueCondition": "AlwaysTrueCondition",
    "Condition|OrCondition": "OrCondition",
    "Condition|AndCondition": "AndCondition",
    "Condition|NotCondition": "NotCondition",
    "Condition|EqualsCondition": "EqualsCondition",
    "Condition|GreaterThanCondition": "GreaterThanCondition",
    "Condition|SmallerThanCondition": "SmallerThanCondition",
    
    # Layer nodes (for SpaceAndDepth)
    "Layer|WeightedThickness": "WeightedThicknessLayer",
    "Layer|ConstantThickness": "ConstantThicknessLayer",
    "Layer|RangeThickness": "RangeThicknessLayer",
    "Layer|NoiseThickness": "NoiseThicknessLayer",
    
    # Terrain nodes
    "Terrain|DAOTerrain": "DAOTerrain",
    
    # Runtime nodes (no Type field)
    "Runtime|": "Runtime",
}

@export var workspace_root_types: Dictionary[String, String] = {
    "HytaleGenerator - Biome": "BiomeRoot",
}

@export var node_schema: Dictionary[String, Dictionary] = {
    "BiomeRoot": {
		"id_prefix_override": "Biome",
        "display_name": "Biome",
        "output_value_type": "__ROOT_ONLY",
        "settings": {
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Terrain": { "value_type": "Terrain", "multi": false },
            "MaterialProvider": { "value_type": "MaterialProvider", "multi": false },
            "Props": { "value_type": "Runtime", "multi": true },
            "EnvironmentProvider": { "value_type": "EnvironmentProvider", "multi": false },
            "TintProvider": { "value_type": "TintProvider", "multi": false },
        }
    },
    
    # Density nodes
    "ConstantDensity": {
		"id_prefix_override": "ConstantDensityNode",
        "display_name": "Constant Density",
        "output_value_type": "Density",
        "settings": {
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "SumDensity": {
		"id_prefix_override": "SumDensityNode",
        "display_name": "Sum Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "MaxDensity": {
		"id_prefix_override": "MaxDensityNode",
        "display_name": "Max Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "MultiplierDensity": {
		"id_prefix_override": "MultiplierDensityNode",
        "display_name": "Multiplier Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SimplexNoise2DDensity": {
		"id_prefix_override": "SimplexNoise2DDensityNode",
        "display_name": "Simplex Noise 2D Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Lacunarity": { "gd_type": TYPE_FLOAT, "default_value": 2.0 },
            "Persistence": { "gd_type": TYPE_FLOAT, "default_value": 0.5 },
            "Octaves": { "gd_type": TYPE_INT, "default_value": 1 },
            "Scale": { "gd_type": TYPE_FLOAT, "default_value": 50.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "SimplexNoise3DDensity": {
		"id_prefix_override": "SimplexNoise3DDensityNode",
        "display_name": "Simplex Noise 3D Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Lacunarity": { "gd_type": TYPE_FLOAT, "default_value": 2.0 },
            "Persistence": { "gd_type": TYPE_FLOAT, "default_value": 0.5 },
            "Octaves": { "gd_type": TYPE_INT, "default_value": 1 },
            "ScaleXZ": { "gd_type": TYPE_FLOAT, "default_value": 50.0 },
            "ScaleY": { "gd_type": TYPE_FLOAT, "default_value": 12.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        }
    },
    "CurveMapperDensity": {
		"id_prefix_override": "CurveMapper.Density",
        "display_name": "Curve Mapper Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    "BaseHeightDensity": {
		"id_prefix_override": "BaseHeight.Density",
        "display_name": "Base Height Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "BaseHeightName": { "gd_type": TYPE_STRING, "default_value": "Base" },
            "Distance": { "gd_type": TYPE_BOOL, "default_value": true },
        }
    },
    # Positions Cell Noise Density
    "PositionsCellNoiseDensity": {
		"id_prefix_override": "PositionsCellNoiseDensityNode",
        "display_name": "Positions Cell Noise Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "MaxDistance": { "gd_type": TYPE_FLOAT, "default_value": 120.0 },
        },
        "connections": {
            "Positions": { "value_type": "Positions", "multi": false },
            "ReturnType": { "value_type": "PCNReturnType", "multi": false },
            "DistanceFunction": { "value_type": "PCNDistanceFunction", "multi": false },
        }
    },
    "VectorWarpDensity": {
		"id_prefix_override": "VectorWarp.Density",
        "display_name": "Vector Warp Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "WarpFactor": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
        },
        "connections": {
            "WarpVector": { "value_type": "Point3D", "multi": false },
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "AnchorDensity": {
		"id_prefix_override": "Anchor.Density",
        "display_name": "Anchor Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Reversed": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "AxisDensity": {
		"id_prefix_override": "Axis.Density",
        "display_name": "Axis Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "IsAnchored": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Axis": { "value_type": "Point3D", "multi": false },
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    "YValueDensity": {
		"id_prefix_override": "YValue.Density",
        "display_name": "Y Value Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "XValueDensity": {
		"id_prefix_override": "XValue.Density",
        "display_name": "X Value Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "YOverrideDensity": {
		"id_prefix_override": "YOverride.Density",
        "display_name": "Y Override Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "XOverrideDensity": {
		"id_prefix_override": "XOverride.Density",
        "display_name": "X Override Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "ZOverrideDensity": {
		"id_prefix_override": "ZOverride.Density",
        "display_name": "Z Override Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "InverterDensity": {
		"id_prefix_override": "InverterDensityNode",
        "display_name": "Inverter Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "NormalizerDensity": {
		"id_prefix_override": "NormalizerDensityNode",
        "display_name": "Normalizer Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "FromMin": { "gd_type": TYPE_FLOAT, "default_value": -1.0 },
            "FromMax": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "ToMin": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "ToMax": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "ImportedDensity": {
		"id_prefix_override": "ImportedDensityNode",
        "display_name": "Imported Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "CacheDensity": {
		"id_prefix_override": "Cache.Density",
        "display_name": "Cache Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "Capacity": { "gd_type": TYPE_INT, "default_value": 3 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "ShellDensity": {
		"id_prefix_override": "Shell.Density",
        "display_name": "Shell Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Mirror": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Axis": { "value_type": "Point3D", "multi": false },
            "AngleCurve": { "value_type": "Curve", "multi": false },
            "DistanceCurve": { "value_type": "Curve", "multi": false },
        }
    },
    "ClampDensity": {
		"id_prefix_override": "ClampDensityNode",
        "display_name": "Clamp Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "WallA": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "WallB": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "RotatorDensity": {
		"id_prefix_override": "Rotator.Density",
        "display_name": "Rotator Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "SpinAngle": { "gd_type": TYPE_FLOAT, "default_value": 180.0 },
        },
        "connections": {
            "NewYAxis": { "value_type": "Point3D", "multi": false },
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "MinDensity": {
		"id_prefix_override": "MinDensityNode",
        "display_name": "Min Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "CellNoise2DDensity": {
		"id_prefix_override": "CellNoise2DDensityNode",
        "display_name": "Cell Noise 2D Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ScaleX": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "ScaleZ": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "Jitter": { "gd_type": TYPE_FLOAT, "default_value": 0.3 },
            "CellType": { "gd_type": TYPE_STRING, "default_value": "Distance2Div" },
            "Octaves": { "gd_type": TYPE_INT, "default_value": 1 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        }
    },
    "CellNoise3DDensity": {
		"id_prefix_override": "CellNoise3DDensityNode",
        "display_name": "Cell Noise 3D Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "ScaleX": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "ScaleY": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "ScaleZ": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "Jitter": { "gd_type": TYPE_FLOAT, "default_value": 0.3 },
            "CellType": { "gd_type": TYPE_STRING, "default_value": "Distance2Div" },
            "Octaves": { "gd_type": TYPE_INT, "default_value": 1 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        }
    },
    "SmoothMaxDensity": {
		"id_prefix_override": "SmoothMaxDensityNode",
        "display_name": "Smooth Max Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SmoothMinDensity": {
		"id_prefix_override": "SmoothMinDensityNode",
        "display_name": "Smooth Min Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "FloorDensity": {
		"id_prefix_override": "FloorDensityNode",
        "display_name": "Floor Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Limit": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "CeilingDensity": {
		"id_prefix_override": "CeilingDensityNode",
        "display_name": "Ceiling Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Limit": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SmoothClampDensity": {
		"id_prefix_override": "SmoothClampDensityNode",
        "display_name": "Smooth Clamp Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "WallA": { "gd_type": TYPE_FLOAT, "default_value": -1.0 },
            "WallB": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SmoothFloorDensity": {
		"id_prefix_override": "SmoothFloorDensityNode",
        "display_name": "Smooth Floor Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
            "Limit": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SmoothCeilingDensity": {
		"id_prefix_override": "SmoothCeilingDensityNode",
        "display_name": "Smooth Ceiling Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 0.2 },
            "Limit": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "AbsDensity": {
		"id_prefix_override": "AbsDensityNode",
        "display_name": "Abs Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SqrtDensity": {
		"id_prefix_override": "SqrtDensityNode",
        "display_name": "Sqrt Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "PowDensity": {
		"id_prefix_override": "PowDensityNode",
        "display_name": "Pow Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Exponent": { "gd_type": TYPE_FLOAT, "default_value": 2.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "ScaleDensity": {
		"id_prefix_override": "Scale.Density",
        "display_name": "Scale Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ScaleX": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "ScaleY": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "ScaleZ": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SliderDensity": {
		"id_prefix_override": "Slider.Density",
        "display_name": "Slider Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "SlideX": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "SlideY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "SlideZ": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "GradientWarpDensity": {
		"id_prefix_override": "GradientWarp.Density",
        "display_name": "Gradient Warp Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "SampleRange": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "WarpFactor": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "2D": { "gd_type": TYPE_BOOL, "default_value": false },
            "YFor2D": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "FastGradientWarpDensity": {
		"id_prefix_override": "FastGradientWarp.Density",
        "display_name": "Fast Gradient Warp Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "WarpScale": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "WarpPersistence": { "gd_type": TYPE_FLOAT, "default_value": 0.5 },
            "WarpLacunarity": { "gd_type": TYPE_FLOAT, "default_value": 2.0 },
            "WarpOctaves": { "gd_type": TYPE_INT, "default_value": 1 },
            "WarpFactor": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "PositionsPinchDensity": {
		"id_prefix_override": "PositionsPinch.Density",
        "display_name": "Positions Pinch Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "MaxDistance": { "gd_type": TYPE_FLOAT, "default_value": 10.0 },
            "NormalizeDistance": { "gd_type": TYPE_BOOL, "default_value": true },
            "PositionsMaxY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "PositionsMinY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "HorizontalPinch": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Positions": { "value_type": "Positions", "multi": false },
            "PinchCurve": { "value_type": "Curve", "multi": false },
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "PositionsTwistDensity": {
		"id_prefix_override": "PositionsTwist.Density",
        "display_name": "Positions Twist Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "MaxDistance": { "gd_type": TYPE_FLOAT, "default_value": 10.0 },
            "ZeroPositionsY": { "gd_type": TYPE_BOOL, "default_value": false },
            "NormalizeDistance": { "gd_type": TYPE_BOOL, "default_value": true },
        },
        "connections": {
            "Positions": { "value_type": "Positions", "multi": false },
            "TwistAxis": { "value_type": "Point3D", "multi": false },
            "TwistCurve": { "value_type": "Curve", "multi": false },
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "EllipsoidDensity": {
		"id_prefix_override": "Ellipsoid.Density",
        "display_name": "Ellipsoid Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Spin": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Curve": { "value_type": "Curve", "multi": false },
            "Scale": { "value_type": "Point3D", "multi": false },
            "NewYAxis": { "value_type": "Point3D", "multi": false },
        }
    },
    "CuboidDensity": {
		"id_prefix_override": "Cuboid.Density",
        "display_name": "Cuboid Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Spin": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Curve": { "value_type": "Curve", "multi": false },
            "Scale": { "value_type": "Point3D", "multi": false },
            "NewYAxis": { "value_type": "Point3D", "multi": false },
        }
    },
    "CubeDensity": {
		"id_prefix_override": "Cube.Density",
        "display_name": "Cube Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    "CylinderDensity": {
		"id_prefix_override": "Cylinder.Density",
        "display_name": "Cylinder Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Spin": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "RadialCurve": { "value_type": "Curve", "multi": false },
            "AxialCurve": { "value_type": "Curve", "multi": false },
            "NewYAxis": { "value_type": "Point3D", "multi": false },
        }
    },
    "DistanceDensity": {
		"id_prefix_override": "Distance.Density",
        "display_name": "Distance Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    "PlaneDensity": {
		"id_prefix_override": "Plane.Density",
        "display_name": "Plane Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "IsAnchored": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "PlaneNormal": { "value_type": "Point3D", "multi": false },
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    "SwitchStateDensity": {
		"id_prefix_override": "SwitchState.Density",
        "display_name": "Switch State Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "SwitchState": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "SwitchDensity": {
		"id_prefix_override": "Switch.Density",
        "display_name": "Switch Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "SwitchCases": { "value_type": "CaseSwitch", "multi": true },
        }
    },
    "MixDensity": {
		"id_prefix_override": "Mix.Density",
        "display_name": "Mix Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    "MultiMixDensity": {
		"id_prefix_override": "MultiMix.Density",
        "display_name": "Multi Mix Density",
        "output_value_type": "Density",
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
            "Keys": { "value_type": "KeyMultiMix", "multi": true },
        }
    },
    "ZValueDensity": {
		"id_prefix_override": "ZValue.Density",
        "display_name": "Z Value Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "AngleDensity": {
		"id_prefix_override": "Angle.Density",
        "display_name": "Angle Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "IsAxis": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Vector": { "value_type": "Point3D", "multi": false },
            "VectorProvider": { "value_type": "VectorProvider", "multi": false },
        }
    },
    "DistanceToBiomeEdgeDensity": {
		"id_prefix_override": "DistanceToBiomeEdge.Density",
        "display_name": "Distance To Biome Edge Density",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "TerrainDensity": {
		"id_prefix_override": "Terrain.Density",
        "display_name": "Terrain Density (Reference)",
        "output_value_type": "Density",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    "ExportedDensity": {
        "id_prefix_override": "Exported.Density",
        "display_name": "Exported Density",
        "output_value_type": "Density",
        "settings": {
            "ExportAs":	{ "gd_type": TYPE_STRING, "default_value": "" },
            "SingleInstance": { "gd_type": TYPE_BOOL, "default_value": true },
            "Skip":	{ "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Inputs": { "value_type": "Density", "multi": true },
        }
    },
    
    # CurvePoint (single-node value type)
    "CurvePoint": {
        "display_name": "Curve Point",
        "output_value_type": "CurvePoint",
        "settings": {
            "In": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Out": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        }
    },
    
    # Curve nodes
    "ManualCurve": {
        "display_name": "Manual Curve",
        "output_value_type": "Curve",
        "connections": {
            "Points": { "value_type": "CurvePoint", "multi": true },
        }
    },
    "DistanceExponentialCurve": {
        "display_name": "Distance Exponential Curve",
        "output_value_type": "Curve",
        "settings": {
            "Exponent": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 6.0 },
        }
    },
    "ConstantCurve": {
		"id_prefix_override": "Constant.Curve",
        "display_name": "Constant Curve",
        "output_value_type": "Curve",
        "settings": {
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        }
    },
    "SumCurve": {
        "display_name": "Sum Curve",
        "output_value_type": "Curve",
        "connections": {
            "Curves": { "value_type": "Curve", "multi": true },
        }
    },
    "MultiplierCurve": {
        "display_name": "Multiplier Curve",
        "output_value_type": "Curve",
        "connections": {
            "Curves": { "value_type": "Curve", "multi": true },
        }
    },
    
    # Material (single-node value type)
    "Material": {
        "display_name": "Material",
        "output_value_type": "Material",
        "settings": {
            "Solid": { "gd_type": TYPE_STRING, "default_value": "" },
            "Fluid": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    
    # Material Provider nodes
    "ConstantMaterialProvider": {
        "display_name": "Constant Material Provider",
        "output_value_type": "MaterialProvider",
        "connections": {
            "Material": { "value_type": "Material", "multi": false },
        }
    },
    "SolidityMaterialProvider": {
        "display_name": "Solidity Material Provider",
        "output_value_type": "MaterialProvider",
        "connections": {
            "Solid": { "value_type": "MaterialProvider", "multi": false },
            "Empty": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    "QueueMaterialProvider": {
        "display_name": "Queue Material Provider",
        "output_value_type": "MaterialProvider",
        "connections": {
            "Queue": { "value_type": "MaterialProvider", "multi": true },
        }
    },
    "StripedMaterialProvider": {
        "display_name": "Striped Material Provider",
        "output_value_type": "MaterialProvider",
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
            "Stripes": { "value_type": "Stripe", "multi": true },
        }
    },
    "WeightedMaterialProvider": {
        "display_name": "Weighted Material Provider",
        "output_value_type": "MaterialProvider",
        "settings": {
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
            "SkipChance": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "WeightedMaterials": { "value_type": "WeightedMaterial", "multi": true },
        }
    },
    "FieldFunctionMaterialProvider": {
        "display_name": "Field Function Material Provider",
        "output_value_type": "MaterialProvider",
        "connections": {
            "FieldFunction": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "DelimiterFieldFunctionMP", "multi": true },
        }
    },
    
    # Point3D (single-node value type)
    "Point3D": {
        "display_name": "Point 3D",
        "output_value_type": "Point3D",
        "settings": {
            "X": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Y": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Z": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        }
    },
    "Point3DInt": {
        "display_name": "Point 3D (Integer)",
        "output_value_type": "Point3DInt",
        "settings": {
            "X": { "gd_type": TYPE_INT, "default_value": 0 },
            "Y": { "gd_type": TYPE_INT, "default_value": 0 },
            "Z": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    
    # PointGenerator nodes
    "MeshPointGenerator": {
        "display_name": "Mesh Point Generator",
        "output_value_type": "PointGenerator",
        "settings": {
            "Jitter": { "gd_type": TYPE_FLOAT, "default_value": 0.25 },
            "ScaleX": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "ScaleY": { "gd_type": TYPE_FLOAT, "default_value": 40.0 },
            "ScaleZ": { "gd_type": TYPE_FLOAT, "default_value": 20.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        }
    },
    
    # Positions nodes
    "Mesh2DPositions": {
        "display_name": "Mesh 2D Positions",
        "output_value_type": "Positions",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "PointsY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "PointGenerator": { "value_type": "PointGenerator", "multi": false },
        }
    },
    "OccurrencePositions": {
        "display_name": "Occurrence Positions",
        "output_value_type": "Positions",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "FieldFunction": { "value_type": "Density", "multi": false },
            "Positions": { "value_type": "Positions", "multi": false },
        }
    },
    "ImportedPositions": {
        "display_name": "Imported Positions",
        "output_value_type": "Positions",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "OffsetPositions": {
        "display_name": "Offset Positions",
        "output_value_type": "Positions",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "OffsetX": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "OffsetY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "OffsetZ": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Positions": { "value_type": "Positions", "multi": false },
        }
    },
    "ListPositions": {
        "display_name": "List Positions",
        "output_value_type": "Positions",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Positions": { "value_type": "Point3D", "multi": true },
        }
    },
    
    # BlockSubset (single-node value type)
    "BlockSubset": {
		"id_prefix_override": "BlockSet.BlockMask",
        "display_name": "Block Subset",
        "output_value_type": "BlockSubset",
        "settings": {
            "Inclusive": { "gd_type": TYPE_BOOL, "default_value": true },
        },
        "connections": {
            "Materials": { "value_type": "Material", "multi": true },
        }
    },
    
    # BlockMask (single-node value type)
    "BlockMask": {
        "display_name": "Block Mask",
        "output_value_type": "BlockMask",
        "connections": {
            "DontPlace": { "value_type": "BlockSubset", "multi": false },
            "DontReplace": { "value_type": "BlockSubset", "multi": false },
            "Advanced": { "value_type": "RuleBlockMask", "multi": true },
        }
    },
    
    # Pattern nodes
    "FloorPattern": {
		"id_prefix_override": "Floor.Pattern",
        "display_name": "Floor Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Origin": { "value_type": "Pattern", "multi": false },
            "Floor": { "value_type": "Pattern", "multi": false },
        }
    },
    "BlockTypePattern": {
		"id_prefix_override": "BlockType.Pattern",
        "display_name": "Block Type Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Material": { "value_type": "Material", "multi": false },
        }
    },
    "BlockSetPattern": {
		"id_prefix_override": "BlockSet.Pattern",
        "display_name": "Block Set Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "BlockSet": { "value_type": "BlockSubset", "multi": false },
        }
    },
    "NotPattern": {
		"id_prefix_override": "Not.Pattern",
        "display_name": "Not Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Pattern": { "value_type": "Pattern", "multi": false },
        }
    },
    
    # Stripe (single-node value type)
    "Stripe": {
		"id_prefix_override": "StripeStripedMP",
        "display_name": "Material Stripe",
        "output_value_type": "Stripe",
        "settings": {
            "TopY": { "gd_type": TYPE_INT, "default_value": 0 },
            "BottomY": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    
    # WeightedMaterial (single-node value type)
    "WeightedMaterial": {
        "display_name": "Weighted Material",
        "output_value_type": "WeightedMaterial",
        "settings": {
            "Weight": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    
    # DelimiterFieldFunctionMP (single-node value type)
    "DelimiterFieldFunctionMP": {
        "display_name": "Delimiter",
        "output_value_type": "DelimiterFieldFunctionMP",
        "settings": {
            "From": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "To": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    
    # Delimiter for Positions Cell Noise Density Return Type (single-node value type)
    "DelimiterDensityPCNReturnType": {
		"id_prefix_override": "Delimiter.DensityPCNReturnType",
        "display_name": "Delimiter",
        "output_value_type": "DelimiterDensityPCNReturnType",
        "settings": {
            "From": { "gd_type": TYPE_FLOAT, "default_value": -1.0 },
            "To": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
        }
    },
    
    # Scanner nodes
    "ColumnLinearScanner": {
		"id_prefix_override": "ColumnLinear.Scanner",
        "display_name": "Column Linear Scanner",
        "output_value_type": "Scanner",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "MaxY": { "gd_type": TYPE_INT, "default_value": 320 },
            "MinY": { "gd_type": TYPE_INT, "default_value": 0 },
            "RelativeToPosition": { "gd_type": TYPE_BOOL, "default_value": false },
            "BaseHeightName": { "gd_type": TYPE_STRING, "default_value": "Base" },
            "TopDownOrder": { "gd_type": TYPE_BOOL, "default_value": true },
            "ResultCap": { "gd_type": TYPE_INT, "default_value": 1 },
        }
    },
    "OriginScanner": {
		"id_prefix_override": "Origin.Scanner",
        "display_name": "Origin Scanner",
        "output_value_type": "Scanner",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        }
    },
    
    # Prop nodes
    "BoxProp": {
        "display_name": "Box Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "BoxBlockType": { "gd_type": TYPE_STRING, "default_value": "BoxBlockType" },
        },
        "connections": {
            "Range": { "value_type": "Point3DInt", "multi": false },
            "Material": { "value_type": "Material", "multi": false },
            "Pattern": { "value_type": "Pattern", "multi": false },
            "Scanner": { "value_type": "Scanner", "multi": false },
        }
    },
    "DensityProp": {
		"id_prefix_override": "Density.Prop",
        "display_name": "Density Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Pattern": { "value_type": "Pattern", "multi": false },
            "Scanner": { "value_type": "Scanner", "multi": false },
            "Material": { "value_type": "MaterialProvider", "multi": false },
            "Density": { "value_type": "Density", "multi": false },
            "PlacementMask": { "value_type": "BlockMask", "multi": false },
            "Range": { "value_type": "Point3DInt", "multi": false },
        }
    },
    
    # Assignments nodes
    "ConstantAssignments": {
		"id_prefix_override": "Constant.Assignments",
        "display_name": "Constant Assignments",
        "output_value_type": "Assignments",
        "settings": {
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Prop": { "value_type": "Prop", "multi": false },
        }
    },
    
    # Positions Cell Noise Distance Function nodes
    "EuclideanPCNDistanceFunction": {
		"id_prefix_override": "PCNDistanceFunction",
        "display_name": "Euclidean",
        "output_value_type": "PCNDistanceFunction",
    },
    "ManhattanPCNDistanceFunction": {
		"id_prefix_override": "PCNDistanceFunction",
        "display_name": "Manhattan",
        "output_value_type": "PCNDistanceFunction",
    },
    
    # Environment/Tint Provider nodes
    "ConstantEnvironmentProvider": {
		"id_prefix_override": "Constant.EnvironmentProvider",
        "display_name": "Constant Environment Provider",
        "output_value_type": "EnvironmentProvider",
        "settings": {
            "Environment": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "DensityDelimitedEnvironmentProvider": {
		"id_prefix_override": "DensityDelimited.EnvironmentProvider",
        "display_name": "Density Delimited Env",
        "output_value_type": "EnvironmentProvider",
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "DelimiterEnvironment", "multi": true },
        }
    },
    "ConstantTintProvider": {
		"id_prefix_override": "Constant.TintProvider",
        "display_name": "Constant Tint Provider",
        "output_value_type": "TintProvider",
        "settings": {
            "Color": { "gd_type": TYPE_STRING, "default_value": "#FFFFFF" },
        }
    },
    "DensityDelimitedTintProvider": {
		"id_prefix_override": "DensityDelimited.TintProvider",
        "display_name": "Density Delimited Tint",
        "output_value_type": "TintProvider",
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "DelimiterTint", "multi": true },
        }
    },
    
    # Positions Cell Noise Return Type nodes
    "DensityPCNReturnType": {
        "display_name": "Density Cell Noise",
        "output_value_type": "PCNReturnType",
        "settings": {
            "DefaultValue": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "ChoiceDensity": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "DelimiterDensityPCNReturnType", "multi": true },
        }
    },
    "CellValuePCNReturnType": {
        "display_name": "Cell Value Cell Noise",
        "output_value_type": "PCNReturnType",
        "settings": {
            "DefaultValue": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
        }
    },
    "DistancePCNReturnType": {
        "display_name": "Distance Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "Distance2PCNReturnType": {
        "display_name": "Distance2 Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "Distance2AddPCNReturnType": {
        "display_name": "Distance2Add Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "Distance2SubPCNReturnType": {
        "display_name": "Distance2Sub Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "Distance2MulPCNReturnType": {
        "display_name": "Distance2Mul Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "Distance2DivPCNReturnType": {
        "display_name": "Distance2Div Cell Noise",
        "output_value_type": "PCNReturnType",
    },
    "CurvePCNReturnType": {
        "display_name": "Curve Cell Noise",
        "output_value_type": "PCNReturnType",
        "connections": {
            "Curve": { "value_type": "Curve", "multi": false },
        }
    },
    
    # Terrain nodes
    "DAOTerrain": {
		"id_prefix_override": "Terrain",
        "display_name": "DAO Terrain",
        "output_value_type": "Terrain",
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
        }
    },
    
    # Runtime nodes (no Type field)
    "Runtime": {
        "display_name": "Runtime",
        "output_value_type": "Runtime",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Runtime": { "gd_type": TYPE_INT, "default_value": 0 },
        },
        "connections": {
            "Positions": { "value_type": "Positions", "multi": false },
            "Assignments": { "value_type": "Assignments", "multi": false },
        }
    },
    
    # Additional Material Providers
    "SimpleHorizontalMaterialProvider": {
        "display_name": "Simple Horizontal Material Provider",
        "output_value_type": "MaterialProvider",
        "settings": {
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "TopY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "TopBaseHeight": { "gd_type": TYPE_STRING, "default_value": "" },
            "BottomY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "BottomBaseHeight": { "gd_type": TYPE_STRING, "default_value": "" },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    "SpaceAndDepthMaterialProvider": {
        "display_name": "Space And Depth Material Provider",
        "output_value_type": "MaterialProvider",
        "settings": {
            "LayerContext": { "gd_type": TYPE_STRING, "default_value": "DEPTH_INTO_FLOOR" },
            "MaxExpectedDepth": { "gd_type": TYPE_INT, "default_value": 3 },
        },
        "connections": {
            "Condition": { "value_type": "Condition", "multi": false },
            "Layers": { "value_type": "Layer", "multi": true },
        }
    },
    "ImportedMaterialProvider": {
        "display_name": "Imported Material Provider",
        "output_value_type": "MaterialProvider",
        "settings": {
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    
    # Additional Patterns
    "CeilingPattern": {
		"id_prefix_override": "Ceiling.Pattern",
        "display_name": "Ceiling Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Origin": { "value_type": "Pattern", "multi": false },
            "Ceiling": { "value_type": "Pattern", "multi": false },
        }
    },
    "OrPattern": {
		"id_prefix_override": "Or.Pattern",
        "display_name": "Or Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Patterns": { "value_type": "Pattern", "multi": true },
        }
    },
    "AndPattern": {
		"id_prefix_override": "And.Pattern",
        "display_name": "And Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Patterns": { "value_type": "Pattern", "multi": true },
        }
    },
    "OffsetPattern": {
		"id_prefix_override": "Offset.Pattern",
        "display_name": "Offset Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Pattern": { "value_type": "Pattern", "multi": false },
            "Offset": { "value_type": "Point3D", "multi": false },
        }
    },
    "ImportedPattern": {
		"id_prefix_override": "Imported.Pattern",
        "display_name": "Imported Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "WallPattern": {
		"id_prefix_override": "Wall.Pattern",
        "display_name": "Wall Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Directions": { "gd_type": TYPE_ARRAY, "default_value": [] },
            "RequireAllDirections": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Origin": { "value_type": "Pattern", "multi": false },
            "Wall": { "value_type": "Pattern", "multi": false },
        }
    },
    "SurfacePattern": {
		"id_prefix_override": "Surface.Pattern",
        "display_name": "Surface Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "SurfaceRadius": { "gd_type": TYPE_INT, "default_value": 1 },
            "MediumRadius": { "gd_type": TYPE_INT, "default_value": 1 },
            "SurfaceGap": { "gd_type": TYPE_INT, "default_value": 0 },
            "MediumGap": { "gd_type": TYPE_INT, "default_value": 0 },
            "Facings": { "gd_type": TYPE_ARRAY, "default_value": [] },
            "RequireAllFacings": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Surface": { "value_type": "Pattern", "multi": false },
            "Medium": { "value_type": "Pattern", "multi": false },
        }
    },
    "CuboidPattern": {
		"id_prefix_override": "Cuboid.Pattern",
        "display_name": "Cuboid Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Max": { "value_type": "Point3D", "multi": false },
            "Min": { "value_type": "Point3D", "multi": false },
            "SubPattern": { "value_type": "Pattern", "multi": false },
        }
    },
    "FieldFunctionPattern": {
		"id_prefix_override": "FieldFunction.Pattern",
        "display_name": "Field Function Pattern",
        "output_value_type": "Pattern",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "FieldFunction": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "DelimiterPattern", "multi": true },
        }
    },
    
    # Additional Scanners
    "ColumnRandomScanner": {
		"id_prefix_override": "ColumnRandom.Scanner",
        "display_name": "Column Random Scanner",
        "output_value_type": "Scanner",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "MaxY": { "gd_type": TYPE_INT, "default_value": 320 },
            "MinY": { "gd_type": TYPE_INT, "default_value": 0 },
            "Strategy": { "gd_type": TYPE_STRING, "default_value": "DART_THROW" },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
            "RelativeToPosition": { "gd_type": TYPE_BOOL, "default_value": false },
            "BaseHeightName": { "gd_type": TYPE_STRING, "default_value": "Base" },
            "ResultCap": { "gd_type": TYPE_INT, "default_value": 1 },
        }
    },
    "AreaScanner": {
		"id_prefix_override": "Area.Scanner",
        "display_name": "Area Scanner",
        "output_value_type": "Scanner",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ScanRange": { "gd_type": TYPE_INT, "default_value": 3 },
            "ScanShape": { "gd_type": TYPE_STRING, "default_value": "CIRCLE" },
            "ResultCap": { "gd_type": TYPE_INT, "default_value": 1 },
        },
        "connections": {
            "ChildScanner": { "value_type": "Scanner", "multi": false },
        }
    },
    "ImportedScanner": {
		"id_prefix_override": "Imported.Scanner",
        "display_name": "Imported Scanner",
        "output_value_type": "Scanner",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    
    # Additional Props
    "ColumnProp": {
		"id_prefix_override": "Column.Prop",
        "display_name": "Column Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "ColumnBlocks": { "value_type": "BlockColumn", "multi": true },
            "Directionality": { "value_type": "Directionality", "multi": false },
            "Scanner": { "value_type": "Scanner", "multi": false },
        }
    },
    "PrefabProp": {
		"id_prefix_override": "Prefab.Prop",
        "display_name": "Prefab Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "LegacyPath": { "gd_type": TYPE_BOOL, "default_value": false },
            "LoadEntities": { "gd_type": TYPE_BOOL, "default_value": false },
            "MoldingDirection": { "gd_type": TYPE_STRING, "default_value": "NONE" },
            "MoldingChildren": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "WeightedPrefabPaths": { "value_type": "WeightedPath", "multi": true },
            "Directionality": { "value_type": "Directionality", "multi": false },
            "Scanner": { "value_type": "Scanner", "multi": false },
            "BlockMask": { "value_type": "BlockMask", "multi": false },
            "MoldingScanner": { "value_type": "Scanner", "multi": false },
            "MoldingPattern": { "value_type": "Pattern", "multi": false },
        }
    },
    "ClusterProp": {
		"id_prefix_override": "Cluster.Prop",
        "display_name": "Cluster Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Range": { "gd_type": TYPE_FLOAT, "default_value": 10.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "DistanceCurve": { "value_type": "Curve", "multi": false },
            "WeightedProps": { "value_type": "WeightedClusterProp", "multi": true },
            "Scanner": { "value_type": "Scanner", "multi": false },
        }
    },
    "UnionProp": {
		"id_prefix_override": "Union.Prop",
        "display_name": "Union Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Props": { "value_type": "Prop", "multi": true },
        }
    },
    "OffsetProp": {
		"id_prefix_override": "Offset.Prop",
        "display_name": "Offset Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Offset": { "value_type": "Point3D", "multi": false },
            "Prop": { "value_type": "Prop", "multi": false },
        }
    },
    "WeightedProp": {
		"id_prefix_override": "Weighted.Prop",
        "display_name": "Weighted Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "Entries": { "value_type": "EntryWeightedProp", "multi": true },
        }
    },
    "QueueProp": {
		"id_prefix_override": "Queue.Prop",
        "display_name": "Queue Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "Queue": { "value_type": "Prop", "multi": true },
        }
    },
    "PondFillerProp": {
		"id_prefix_override": "PondFiller.Prop",
        "display_name": "Pond Filler Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
        },
        "connections": {
            "BoundingMin": { "value_type": "Point3D", "multi": false },
            "BoundingMax": { "value_type": "Point3D", "multi": false },
            "BarrierBlockSet": { "value_type": "BlockSubset", "multi": false },
            "FillMaterial": { "value_type": "MaterialProvider", "multi": false },
            "Pattern": { "value_type": "Pattern", "multi": false },
            "Scanner": { "value_type": "Scanner", "multi": false },
        }
    },
    "ImportedProp": {
		"id_prefix_override": "Imported.Prop",
        "display_name": "Imported Prop",
        "output_value_type": "Prop",
        "settings": {
            "Skip": { "gd_type": TYPE_BOOL, "default_value": false },
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    
    # Additional Assignments
    "SandwichAssignments": {
		"id_prefix_override": "Sandwich.Assignments",
        "display_name": "Sandwich Assignments",
        "output_value_type": "Assignments",
        "connections": {
            "Delimiters": { "value_type": "SMDelimiterAssignments", "multi": true },
        }
    },
    "WeightedAssignments": {
		"id_prefix_override": "Weighted.Assignments",
        "display_name": "Weighted Assignments",
        "output_value_type": "Assignments",
        "settings": {
            "SkipChance": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "WeightedAssignments": { "value_type": "WeightedAssignment", "multi": true },
        }
    },
    "ImportedAssignments": {
		"id_prefix_override": "Imported.Assignments",
        "display_name": "Imported Assignments",
        "output_value_type": "Assignments",
        "settings": {
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    "FieldFunctionAssignments": {
		"id_prefix_override": "FieldFunction.Assignments",
        "display_name": "Field Function Assignments",
        "output_value_type": "Assignments",
        "connections": {
            "FieldFunction": { "value_type": "Density", "multi": false },
            "Delimiters": { "value_type": "FFDelimiterAssignments", "multi": true },
        }
    },
    
    # Directionality
    "StaticDirectionality": {
		"id_prefix_override": "Static.Directionality",
        "display_name": "Static Directionality",
        "output_value_type": "Directionality",
        "settings": {
            "ExportAs": { "gd_type": TYPE_STRING, "default_value": "" },
            "Rotation": { "gd_type": TYPE_INT, "default_value": 0 },
        },
        "connections": {
            "Pattern": { "value_type": "Pattern", "multi": false },
        }
    },
    "RandomDirectionality": {
		"id_prefix_override": "Random.Directionality",
        "display_name": "Random Directionality",
        "output_value_type": "Directionality",
        "settings": {
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "Pattern": { "value_type": "Pattern", "multi": false },
        }
    },
    "ImportedDirectionality": {
		"id_prefix_override": "Imported.Directionality",
        "display_name": "Imported Directionality",
        "output_value_type": "Directionality",
        "settings": {
            "Name": { "gd_type": TYPE_STRING, "default_value": "" },
        }
    },
    
    # VectorProvider
    "ConstantVectorProvider": {
		"id_prefix_override": "Constant.VectorProvider",
        "display_name": "Constant Vector Provider",
        "output_value_type": "VectorProvider",
        "connections": {
            "Vector": { "value_type": "Point3D", "multi": false },
        }
    },
    
    # Conditions (for SpaceAndDepth)
    "AlwaysTrueCondition": {
		"id_prefix_override": "AlwaysTrueConditionSADMP",
        "display_name": "Always True Condition",
        "output_value_type": "Condition",
    },
    "OrCondition": {
		"id_prefix_override": "OrConditionSADMP",
        "display_name": "Or Condition",
        "output_value_type": "Condition",
        "connections": {
            "Conditions": { "value_type": "Condition", "multi": true },
        }
    },
    "AndCondition": {
		"id_prefix_override": "AndConditionSADMP",
        "display_name": "And Condition",
        "output_value_type": "Condition",
        "connections": {
            "Conditions": { "value_type": "Condition", "multi": true },
        }
    },
    "NotCondition": {
		"id_prefix_override": "NotConditionSADMP",
        "display_name": "Not Condition",
        "output_value_type": "Condition",
        "connections": {
            "Conditions": { "value_type": "Condition", "multi": false },
        }
    },
    "EqualsCondition": {
		"id_prefix_override": "EqualsConditionSADMP",
        "display_name": "Equals Condition",
        "output_value_type": "Condition",
        "settings": {
            "ContextToCheck": { "gd_type": TYPE_STRING, "default_value": "" },
            "Value": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    "GreaterThanCondition": {
		"id_prefix_override": "GreaterThanConditionSADMP",
        "display_name": "Greater Than Condition",
        "output_value_type": "Condition",
        "settings": {
            "ContextToCheck": { "gd_type": TYPE_STRING, "default_value": "" },
            "Threshold": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    "SmallerThanCondition": {
		"id_prefix_override": "SmallerThanConditionSADMP",
        "display_name": "Smaller Than Condition",
        "output_value_type": "Condition",
        "settings": {
            "ContextToCheck": { "gd_type": TYPE_STRING, "default_value": "" },
            "Threshold": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    
    # Layers (for SpaceAndDepth)
    "WeightedThicknessLayer": {
		"id_prefix_override": "WeightedThicknessLayerSADMP",
        "display_name": "Weighted Thickness Layer",
        "output_value_type": "Layer",
        "settings": {
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    "ConstantThicknessLayer": {
		"id_prefix_override": "ConstantThicknessLayerSADMP",
        "display_name": "Constant Thickness Layer",
        "output_value_type": "Layer",
        "settings": {
            "Thickness": { "gd_type": TYPE_INT, "default_value": 1 },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    "RangeThicknessLayer": {
		"id_prefix_override": "RangeThicknessLayerSADMP",
        "display_name": "Range Thickness Layer",
        "output_value_type": "Layer",
        "settings": {
            "RangeMax": { "gd_type": TYPE_INT, "default_value": 3 },
            "RangeMin": { "gd_type": TYPE_INT, "default_value": 1 },
            "Seed": { "gd_type": TYPE_STRING, "default_value": "A" },
        },
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
        }
    },
    "NoiseThicknessLayer": {
		"id_prefix_override": "NoiseThicknessLayerSADMP",
        "display_name": "Noise Thickness Layer",
        "output_value_type": "Layer",
        "connections": {
            "Material": { "value_type": "MaterialProvider", "multi": false },
            "ThicknessFunctionXZ": { "value_type": "Density", "multi": false },
        }
    },
    
    # Nested types
    "CaseSwitch": {
		"id_prefix_override": "Case.Switch.Density",
        "display_name": "Switch Case",
        "output_value_type": "CaseSwitch",
        "settings": {
            "CaseState": { "gd_type": TYPE_STRING, "default_value": "Default" },
        },
        "connections": {
            "Density": { "value_type": "Density", "multi": false },
        }
    },
    "KeyMultiMix": {
		"id_prefix_override": "Key.MultiMix.Density",
        "display_name": "Multi Mix Key",
        "output_value_type": "KeyMultiMix",
        "settings": {
            "Value": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "DensityIndex": { "gd_type": TYPE_INT, "default_value": 0 },
        }
    },
    "WeightedAssignment": {
		"id_prefix_override": "Weight.Weighted.Assignments",
        "display_name": "Weighted Assignment",
        "output_value_type": "WeightedAssignment",
        "settings": {
            "Weight": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Assignments": { "value_type": "Assignments", "multi": false },
        }
    },
    "SMDelimiterAssignments": {
		"id_prefix_override": "Delimiter.Sandwich.Assignments",
        "display_name": "Delimiter",
        "output_value_type": "SMDelimiterAssignments",
        "settings": {
            "MaxY": { "gd_type": TYPE_FLOAT, "default_value": 100.0 },
            "MinY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Max": { "gd_type": TYPE_FLOAT, "default_value": 100.0 },
            "Min": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Assignments": { "value_type": "Assignments", "multi": false },
        }
    },
    "FFDelimiterAssignments": {
		"id_prefix_override": "Delimiter.FieldFunction.Assignments",
        "display_name": "Delimiter",
        "output_value_type": "FFDelimiterAssignments",
        "settings": {
            "MaxY": { "gd_type": TYPE_FLOAT, "default_value": 100.0 },
            "MinY": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Max": { "gd_type": TYPE_FLOAT, "default_value": 100.0 },
            "Min": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
        },
        "connections": {
            "Assignments": { "value_type": "Assignments", "multi": false },
        }
    },
    "DelimiterEnvironment": {
		"id_prefix_override": "Delimiter.DensityDelimited.EnvironmentProvider",
        "display_name": "Delimiter",
        "output_value_type": "DelimiterEnvironment",
        "connections": {
            "Environment": { "value_type": "EnvironmentProvider", "multi": false },
            "Range": { "value_type": "Range", "multi": false },
        }
    },
    "DelimiterTint": {
		"id_prefix_override": "Delimiter.DensityDelimited.TintProvider",
        "display_name": "Delimiter",
        "output_value_type": "DelimiterTint",
        "connections": {
            "Tint": { "value_type": "TintProvider", "multi": false },
            "Range": { "value_type": "Range", "multi": false },
        }
    },
    "Range": {
		"id_prefix_override": "Decimal.Range",
        "display_name": "Range",
        "output_value_type": "Range",
        "settings": {
            "MinInclusive": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "MaxExclusive": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        }
    },
    "DelimiterPattern": {
		"id_prefix_override": "Delimiter.FieldFunction.Pattern",
        "display_name": "Delimiter",
        "output_value_type": "DelimiterPattern",
        "settings": {
            "Min": { "gd_type": TYPE_FLOAT, "default_value": 0.0 },
            "Max": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        }
    },
    "WeightedPath": {
		"id_prefix_override": "WeightedPath.Prefab.Prop",
        "display_name": "Weighted Path",
        "output_value_type": "WeightedPath",
        "settings": {
            "Path": { "gd_type": TYPE_STRING, "default_value": "" },
            "Weight": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        }
    },
    "WeightedClusterProp": {
		"id_prefix_override": "Weighted.Cluster.Prop",
        "display_name": "Weighted Cluster Prop",
        "output_value_type": "WeightedClusterProp",
        "settings": {
            "Weight": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "ColumnProp": { "value_type": "Prop", "multi": false },
        }
    },
    "BlockColumn": {
		"id_prefix_override": "Block.Column.Prop",
        "display_name": "Block Column",
        "output_value_type": "BlockColumn",
        "settings": {
            "Y": { "gd_type": TYPE_INT, "default_value": 0 },
        },
        "connections": {
            "Material": { "value_type": "Material", "multi": false },
        }
    },
    "EntryWeightedProp": {
		"id_prefix_override": "Entry.Weighted.Prop",
        "display_name": "Entry Weighted Prop",
        "output_value_type": "EntryWeightedProp",
        "settings": {
            "Weight": { "gd_type": TYPE_FLOAT, "default_value": 1.0 },
        },
        "connections": {
            "Prop": { "value_type": "Prop", "multi": false },
        }
    },
    "RuleBlockMask": {
		"id_prefix_override": "Rule.BlockMask",
        "display_name": "Rule (Block Mask)",
        "output_value_type": "RuleBlockMask",
        "connections": {
            "Source": { "value_type": "BlockSubset", "multi": false },
            "CanReplace": { "value_type": "BlockSubset", "multi": false },
        }
    },
}
