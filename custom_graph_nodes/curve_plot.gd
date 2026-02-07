extends Control
class_name CurvePlot

@export var curve_point_icon: Texture2D = preload("res://ui/assets/draggable_point.tres")

@export var line_color: Color = Color.RED
@export var y_axis_color: Color = Color.GREEN
@export var x_axis_color: Color = Color.PINK
@export var area_highlight_color: Color = Color(Color.WHITE, 0.12)
@export var point_color: Color = Color.GREEN

@export var constant_icon_scale: bool = false
@export var constant_icon_scale_factor: float = 2.0

var minimum_icon_scale_factor: float = 0.5

var min_pixels_per_step: float = 40.0

# if not is_using_curve then we're plotting an exponential distance curve
var is_using_curve: = true
var is_curve_linear: = true
var is_curve_points_editable: = true

var curve_show_region: = true

var plot_curve: Curve = Curve.new()

# if is_exponent_s_curve then we're plotting an S curve otherwise just a straight power curve
# we're doing distance curves though, so compared to a regular y = x^exp, we're using y=(1-x)^exp
var exponent: float = 1.0
var exponent_b: float = 1.0
var is_exponent_s_curve: = true

var visualizer_line: Line2D

# vertical range to plot in the curve domain
# if v_center, plot from +vertical_range/2 to -vertical_range/2 so the entire height in curve domain is still vertical_range
var vertical_range: float = 1
var v_center: bool = false
# plot vertically from 0 to -vertical_range
var v_negative: bool = false

# horizontal start and end to plot in the curve domain
var horizontal_min: float = 0.0
var horizontal_max: float = 1.0

var horizontal_margin: float = 1/8.
var vertical_margin: float = 1/8.

var visualizer_line_base_thickness: float = 1.0
var cur_zoom: float = 1.0

var point_icon_base_scale: = Vector2(2, 2)

func _ready() -> void:
    visualizer_line = Line2D.new()
    visualizer_line.name = "VisualizerLine"
    visualizer_line.width = 1
    visualizer_line.default_color = line_color
    visualizer_line.z_index = 1
    add_child(visualizer_line, true)

func set_as_manual_curve() -> void:
    is_curve_linear = true
    is_curve_points_editable = true

func update_curve(linear_points: Array[Vector2]) -> void:
    is_using_curve = true
    var sorted_points: Array[Vector2] = linear_points.duplicate()
    var sort_func: = func(a: Vector2, b: Vector2) -> bool: return a.x < b.x
    sorted_points.sort_custom(sort_func)
    
    plot_curve.clear_points()
    
    var min_x: float = sorted_points[0].x
    var max_x: float = sorted_points[0].x
    var min_y: float = sorted_points[0].y
    var max_y: float = sorted_points[0].y

    for point in sorted_points:
        min_x = minf(min_x, point.x)
        max_x = maxf(max_x, point.x)
        min_y = minf(min_y, point.y)
        max_y = maxf(max_y, point.y)

    # Need to set the Curve's domain and value or added points will be clamped into the old values
    plot_curve.min_domain = min_x
    plot_curve.max_domain = max_x
    plot_curve.min_value = min_y
    plot_curve.max_value = max_y
    
    for point in sorted_points:
        plot_curve.add_point(Vector2(point.x, point.y), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
    
    horizontal_min = min_x
    horizontal_max = max_x
    if horizontal_max - horizontal_min < 1:
        horizontal_max = horizontal_min + 1
    
    if signf(min_y) != signf(max_y):
        v_center = true
        vertical_range = maxf(absf(min_y), absf(max_y)) * 2
    else:
        v_negative = min_y < 0
        v_center = false
        vertical_range = maxf(absf(min_y), absf(max_y))
    vertical_range = maxf(1, vertical_range)
    
    #prints(plot_curve.point_count, "viewport x range", horizontal_min, horizontal_max, "vertical span", vertical_range, "v center", v_center)
    var pts: Array = []
    for point_idx in plot_curve.point_count:
        pts.append(plot_curve.get_point_position(point_idx))

func update_exponent(new_exponent: float, new_exponent_b: float = 1.0, is_s_curve: bool = false) -> void:
    is_using_curve = false
    is_exponent_s_curve = is_s_curve
    exponent = new_exponent
    exponent_b = new_exponent_b

func exp_sample(x: float) -> float:
    if is_exponent_s_curve:
        var is_beg: = x < 0.5
        return ease(1 - x, exponent if is_beg else exponent_b)
    else:
        return pow(1 - x, exponent)

func draw_curve(domain_to_output: Transform2D) -> void:
    visualizer_line.width = visualizer_line_base_thickness / cur_zoom
    visualizer_line.position = domain_to_output.origin
    #visualizer_line.position = Vector2(0, 0)
    var output_scale: = domain_to_output.get_scale()
   
    if is_using_curve:
        if is_curve_linear:
            visualize_curve_exact(output_scale)
        else:
            visualize_curve_sampled(output_scale)
    else:
        visualize_exp(output_scale)

func visualize_curve_sampled(output_scale: Vector2) -> void:
    visualizer_line.clear_points()
    var scaled_start: float = plot_curve.sample_baked(plot_curve.min_domain) * output_scale.y
    visualizer_line.add_point(Vector2(-visualizer_line.position.x, scaled_start))
    
    var domain_size: float = plot_curve.max_domain - plot_curve.min_domain
    
    var last_sample_y: float = 0
    var total_samples: = floori(size.x / 2.0) + 1
    for sample in total_samples:
        var x_ratio: float = sample / float(total_samples - 1)
        var x: float = plot_curve.min_domain + x_ratio * domain_size
        var y_sample: = plot_curve.sample_baked(x)
        last_sample_y = y_sample
        
        visualizer_line.add_point(Vector2(x, y_sample) * output_scale)
        
    var scaled_end: float = last_sample_y * output_scale.y
    visualizer_line.add_point(Vector2(size.x - visualizer_line.position.x, scaled_end))

func visualize_curve_exact(output_scale: Vector2) -> void:
    visualizer_line.clear_points()
    var scaled_start: float = plot_curve.get_point_position(0).y * output_scale.y
    visualizer_line.add_point(Vector2(-visualizer_line.position.x, scaled_start))
    
    for curve_point_idx in plot_curve.point_count:
        visualizer_line.add_point(plot_curve.get_point_position(curve_point_idx) * output_scale)
    
    var scaled_end: float = plot_curve.get_point_position(plot_curve.point_count - 1).y * output_scale.y
    visualizer_line.add_point(Vector2(size.x - visualizer_line.position.x, scaled_end))

func visualize_exp(output_scale: Vector2) -> void:
    visualizer_line.clear_points()
    var scaled_start: float = 1 * output_scale.y
    visualizer_line.add_point(Vector2(-visualizer_line.position.x, scaled_start))
    
    var total_samples: = floori(size.x / 2.0) + 1
    for sample in total_samples:
        var x: float = sample / float(total_samples - 1)
        var y: float = exp_sample(x)
        visualizer_line.add_point(Vector2(x, y) * output_scale)
    
    visualizer_line.add_point(Vector2(size.x - visualizer_line.position.x, 0))

func _draw() -> void:
    # negative size in Y because chart is y-up but godot coordinates are y-down
    var plot_domain_size: = Vector2(horizontal_max - horizontal_min, -vertical_range)
    var margin_vec: = size * Vector2(horizontal_margin, vertical_margin)
    var output_size: = size - margin_vec
    var plot_scale: = output_size / plot_domain_size
    var plot_origin: Vector2
    if v_center:
        plot_origin = Vector2(margin_vec.x / 2.0, size.y / 2.0)
    elif not v_negative:
        plot_origin = Vector2(margin_vec.x / 2.0, size.y - margin_vec.y / 2.0)
    else:
        plot_origin = Vector2(margin_vec.x / 2.0, margin_vec.y / 2.0)
    
    var domain_to_output: Transform2D = Transform2D(0, plot_scale, 0, plot_origin)
    
    draw_region_highlight(domain_to_output)

    draw_axes(plot_origin, Vector2(plot_scale.x, -plot_scale.y))
    draw_curve(domain_to_output)
    draw_point_widgets(domain_to_output)

func draw_region_highlight(domain_to_output: Transform2D) -> void:
    var draw_highlight: = (not is_using_curve) or curve_show_region

    if draw_highlight:
        var y_top: float = 1
        if is_using_curve:
            if v_center:
                y_top = vertical_range / 2.0
            elif v_negative:
                y_top = 0
            else:
                y_top = vertical_range

        var start_point: = domain_to_output * Vector2(0, y_top)
        var rect_size: = Vector2.ONE * domain_to_output.get_scale()
        draw_rect(Rect2(start_point, rect_size), area_highlight_color, true, 0)

func draw_axes(local_origin: Vector2, output_scale: Vector2) -> void:
    var x_grid_step: = Vector2.RIGHT * get_best_step(horizontal_max - horizontal_min, size.x) * output_scale.x
    var lowest_x_step: int = 0
    while (lowest_x_step - 1) * x_grid_step.x > -local_origin.x:
        lowest_x_step -= 1
    prints("lowest x step", lowest_x_step, "x grid step", x_grid_step)

    var x_step_num: int = lowest_x_step
    var x_end: = size.x - local_origin.x
    var x_tick_color: = x_axis_color.darkened(0.3)
    var x_tick_offset: = Vector2(0, 5)
    while x_step_num * x_grid_step.x < x_end:
        var tick_pos: = local_origin + (x_grid_step * x_step_num)
        draw_line(tick_pos - x_tick_offset, tick_pos + x_tick_offset, x_tick_color, -1)
        x_step_num += 1
    draw_line(Vector2(0, local_origin.y), Vector2(size.x, local_origin.y), x_axis_color, -1)

    var y_grid_step: = Vector2.DOWN * get_best_step(vertical_range, size.y) * output_scale.y
    var lowest_y_step: int = 0
    while (lowest_y_step - 1) * y_grid_step.y > -local_origin.y:
        lowest_y_step -= 1
    prints("lowest y step", lowest_y_step, "y grid step", y_grid_step)

    var y_step_num: int = lowest_y_step
    var y_end: = size.y - local_origin.y
    var y_tick_color: = y_axis_color.darkened(0.3)
    var y_tick_offset: = Vector2(5, 0)
    while y_step_num * y_grid_step.y < y_end:
        var tick_pos: = local_origin + (y_grid_step * y_step_num)
        draw_line(tick_pos - y_tick_offset, tick_pos + y_tick_offset, y_tick_color, -1)
        y_step_num += 1
    draw_line(Vector2(local_origin.x, 0), Vector2(local_origin.x, size.y), y_axis_color, -1)

func draw_point_widgets(domain_to_output: Transform2D) -> void:
    if not is_using_curve:
        return
    
    var icon_size: = curve_point_icon.get_size() / point_icon_base_scale
    var scale_factor: float = 1
    if constant_icon_scale:
        scale_factor *= constant_icon_scale_factor / cur_zoom
    scale_factor = maxf(scale_factor, minimum_icon_scale_factor / cur_zoom)
    icon_size *= scale_factor

    for curve_point_idx in plot_curve.point_count:
        var transformed_point: = domain_to_output * plot_curve.get_point_position(curve_point_idx)
        var icon_rect: = Rect2(transformed_point - (icon_size / 2.0), icon_size)
        draw_texture_rect(curve_point_icon, icon_rect, false, point_color)

func get_best_step(val_range: float, render_size: float) -> int:
    var step: int = 1
    var is_5: = false
    var val_factor: = render_size / val_range
    while step <= 1000000:
        var last_step: = step
        if is_5:
            step *= 2
        else:
            step *= 5
        is_5 = not is_5

        if step * val_factor > min_pixels_per_step: 
            return last_step
    return step