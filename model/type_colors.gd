extends Node

var fallback_color: String = "grey"

@export var type_colors: Dictionary[String, String] = {
    "Density": "purple",
    "Curve": "orange",
    "CurvePoint": "yellow",
    "Positions": "blue",
    "Material": "yellow-brown",
    "MaterialProvider": "brown",
    "VectorProvider": "blue-green",
    "Terrain": "grey",
    "Pattern": "light-purple",
    "Scanner": "light-blue",
    "BlockMask": "yellow-green",
    "BlockSubset": "light-green",
    "Prop": "green",
    "Assignments": "blue-purple",
    "EnvironmentProvider": "light-orange",
    "TintProvider": "light-orange",
    "PCNReturnType": "red",
    "PCNDistanceFunction": "light-blue-green",
    "Point3D": "yellow",
    "PointGenerator": "light-blue",
    "Stripe": "yellow",
    "WeightedMaterial": "light-orange",
    "DelimiterFieldFunctionMP": "grey",
    "DelimiterDensityPCNReturnType": "grey",
    "Runtime": "grey",
    "Directionality": "dark-purple",
    "Condition": "grey",
    "Layer": "grey",
    "WeightedPath": "grey",
    "WeightedProp": "grey",
    "SMDelimiterAssignments": "grey",
    "FFDelimiterAssignments": "grey",
    "DelimiterPattern": "grey",
    "CaseSwitch": "grey",
    "KeyMultiMix": "grey",
    "WeightedAssignment": "grey",
    "WeightedClusterProp": "grey",
    "BlockColumn": "grey",
    "EntryWeightedProp": "grey",
    "RuleBlockMask": "grey",
    "DelimiterEnvironment": "grey",
    "DelimiterTint": "grey",
    "Range": "grey",
}

func get_color_for_type(type_name: String) -> String:
    if type_name not in type_colors:
        return fallback_color
    return type_colors[type_name]

func get_actual_color_for_type(type_name: String) -> Color:
    var color_name: String = get_color_for_type(type_name)
    if color_name not in ThemeColorVariants.theme_colors:
        color_name = fallback_color
    return ThemeColorVariants.theme_colors[color_name]