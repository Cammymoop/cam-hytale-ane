extends Control
class_name CurvePlot

signal delete_point(point_idx: int)
signal points_adjusted(new_points: Array[Vector2])
signal points_adjustment_ended
signal points_changed(new_points: Array[Vector2])


@export var curve_point_icon: Texture2D = preload("res://ui/assets/draggable_point.tres")

@export var line_color: Color = Color.RED
@export var y_axis_color: Color = Color.GREEN
@export var x_axis_color: Color = Color.PINK
@export var area_highlight_color: Color = Color(Color.WHITE, 0.12)
@export var point_color: Color = Color.GREEN

@export var constant_icon_scale: bool = false
@export var constant_icon_scale_factor: float = 2.0

@export var coordinate_font: Font = preload("res://ui/assets/natural-mono.regular.ttf")

var minimum_icon_scale_factor: float = 0.5

var min_pixels_per_step_h: float = 90
var min_pixels_per_step_v: float = 56

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
var vertical_range: float = 1
# vertical offset of the origin, 0 = origin is at the top of the graph (showing negative quadrants), 0.5 = origin is centered vertically
var vertical_offset: float = 0.0

# horizontal start and end to plot in the curve domain
var horizontal_min: float = 0.0
var horizontal_max: float = 1.0

var horizontal_margin: float = 26
var vertical_margin: float = 44

var visualizer_line_base_thickness: float = 1.0
var cur_zoom: float = 1.0

var point_icon_base_scale: = Vector2(2, 2)


var sorted_points: Array[Vector2] = []

var point_position_cache: Array[Vector2] = []
var can_drag_dist_squared: float = 4 * 4
var dragging_point_idx: int = -1
var dragging_mouse_offset: Vector2 = Vector2.ZERO

@export var snapping_interval: float = 0.01

@export var anim_region_duration: float = 0.167
@export_exp_easing var anim_region_ease_param: = 0.4
var animating_region: bool = false
var anim_info: Dictionary = {}

func _ready() -> void:
    visualizer_line = Line2D.new()
    visualizer_line.name = "VisualizerLine"
    visualizer_line.width = 1
    visualizer_line.default_color = line_color
    visualizer_line.z_index = 1
    add_child(visualizer_line, true)
    resized.connect(update_size)

func hiding() -> void:
    reset_dragging_state()
    stop_animating_region()

func start_animating_region() -> void:
    animating_region = true
    anim_info["time_left"] = anim_region_duration
    anim_info["h_min"] = horizontal_min
    anim_info["h_max"] = horizontal_max
    anim_info["v_range"] = vertical_range
    anim_info["v_offset"] = vertical_offset

func stop_animating_region() -> void:
    animating_region = false

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return

    var new_default_cursor_shape: = mouse_default_cursor_shape
    if dragging_point_idx >= 0:
        new_default_cursor_shape = Control.CURSOR_DRAG
    elif get_global_rect().has_point(get_global_mouse_position()):
        new_default_cursor_shape = Control.CURSOR_ARROW
        var local_mouse_pos: = get_local_mouse_position()
        if Util.is_ctrl_cmd_pressed():
            new_default_cursor_shape = Control.CURSOR_CROSS
        else:
            for point_idx in point_position_cache.size():
                if point_position_cache[point_idx].distance_squared_to(local_mouse_pos) < can_drag_dist_squared:
                    new_default_cursor_shape = Control.CURSOR_POINTING_HAND
                    break
    if new_default_cursor_shape != mouse_default_cursor_shape:
        mouse_default_cursor_shape = new_default_cursor_shape

    if not animating_region:
        return
    
    anim_info["time_left"] -= delta
    if anim_info["time_left"] <= 0:
        stop_animating_region()
        refresh_curve()
    else:
        refresh_curve(true)
    update_point_pos_cache(get_domain_to_output())
    
func set_as_manual_curve() -> void:
    is_curve_linear = true
    is_curve_points_editable = true

func _sort_points(points: Array[Vector2]) -> Array[Vector2]:
    var sort_func: = func(a: Vector2, b: Vector2) -> bool: return a.x < b.x
    points.sort_custom(sort_func)
    return points

func update_size() -> void:
    update_point_pos_cache(get_domain_to_output())

func update_curve(linear_points: Array[Vector2], do_sort: bool = true, do_anim: bool = false, start_anim_if_changed: bool = false) -> void:
    var new_points: = linear_points.duplicate()
    if do_sort:
        sorted_points = _sort_points(new_points)
    else:
        sorted_points = new_points
    
    refresh_curve(do_anim, start_anim_if_changed)
    
    # Do this after calling refresh curve, which will update the domain size
    update_point_pos_cache(get_domain_to_output())
    
func refresh_curve(do_anim: bool = false, start_anim_if_changed: bool = false) -> void:
    _check_for_unsorted()
    queue_redraw()

    is_using_curve = true
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
    
    # leave the plotted size unchanged while dragging, only adjust it once released
    if dragging_point_idx < 0 or do_anim:
        var h_min: = minf(min_x, 0)
        if h_min < 0:
            h_min = minf(-1, h_min)

        var h_max: = maxf(max_x, 0)
        if h_max > 0:
            h_max = maxf(1, h_max)

        if h_max - h_min < 1:
            h_max = h_min + 1
        
        var v_range: float
        var v_offset: float
        if min_y < 0 and max_y > 0:
            v_offset = 0.5
            v_range = maxf(absf(min_y), absf(max_y)) * 2
            v_range = maxf(2, v_range)
        else:
            v_offset = 0.0 if min_y < 0 else 1.0
            v_range = maxf(absf(min_y), absf(max_y))
            v_range = maxf(1, v_range)
        
        if do_anim:
            var t: float = ease(1 - anim_info["time_left"] / anim_region_duration, anim_region_ease_param)
            horizontal_min = lerpf(anim_info["h_min"], h_min, t)
            horizontal_max = lerpf(anim_info["h_max"], h_max, t)
            vertical_range = lerpf(anim_info["v_range"], v_range, t)
            vertical_offset = lerpf(anim_info["v_offset"], v_offset, t)
        else:
            if start_anim_if_changed:
                if horizontal_min != h_min or horizontal_max != h_max or vertical_range != v_range or vertical_offset != v_offset:
                    start_animating_region()
                    return
            horizontal_min = h_min
            horizontal_max = h_max
            vertical_range = v_range
            vertical_offset = v_offset


func update_exponent(new_exponent: float, new_exponent_b: float = 1.0, is_s_curve: bool = false) -> void:
    reset_dragging_state()
    is_using_curve = false
    is_exponent_s_curve = is_s_curve
    exponent = new_exponent
    exponent_b = new_exponent_b
    
    horizontal_min = 0
    horizontal_max = 1
    vertical_range = 1
    vertical_offset = 0.0

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

    var first_point_pos: = plot_curve.get_point_position(0) * output_scale
    if first_point_pos.x > -visualizer_line.position.x:
        visualizer_line.add_point(Vector2(-visualizer_line.position.x, first_point_pos.y))
    
    for curve_point_idx in plot_curve.point_count:
        visualizer_line.add_point(plot_curve.get_point_position(curve_point_idx) * output_scale)
    
    var last_point_pos: = plot_curve.get_point_position(plot_curve.point_count - 1) * output_scale
    if last_point_pos.x < size.x - visualizer_line.position.x:
        visualizer_line.add_point(Vector2(size.x - visualizer_line.position.x, last_point_pos.y))

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

func get_domain_to_output() -> Transform2D:
    # negative size in Y because chart is y-up but godot coordinates are y-down
    var plot_domain_size: = Vector2(horizontal_max - horizontal_min, -vertical_range)
    var h_margin: = horizontal_margin if horizontal_min < -0.5 else horizontal_margin * 2
    var margin_vec: = Vector2(h_margin, vertical_margin)
    var output_size: = size - margin_vec
    var plot_scale: = output_size / plot_domain_size
    var plot_origin: = Vector2(
        (margin_vec.x / 2.0) - (horizontal_min * plot_scale.x), 
        output_size.y * vertical_offset + margin_vec.y / 2.0
    )
    
    return Transform2D(0, plot_scale, 0, plot_origin)
    

func _draw() -> void:
    var domain_to_output: = get_domain_to_output()
    var plot_scale: = domain_to_output.get_scale()
    
    draw_region_highlight(domain_to_output)

    draw_axes(domain_to_output.origin, Vector2(plot_scale.x, -plot_scale.y))
    draw_curve(domain_to_output)
    draw_point_widgets(domain_to_output)

func draw_region_highlight(domain_to_output: Transform2D) -> void:
    var draw_highlight: = (not is_using_curve) or curve_show_region

    if draw_highlight:
        var y_top = vertical_range * vertical_offset

        var start_point: = domain_to_output * Vector2(horizontal_min, y_top)
        var domain_size: = Vector2(horizontal_max - horizontal_min, vertical_range)
        var rect_size: = (domain_size * domain_to_output.get_scale()).abs()
        draw_rect(Rect2(start_point, rect_size), area_highlight_color, true)

func get_tick_val_string(x_step: int, x_step_num: int) -> String:
    var val_str: = str(x_step * x_step_num)
    var vlen: = val_str.length()
    if x_step > 500000:
        val_str = val_str.substr(0, vlen - 6) + "m"
    elif x_step > 5000:
        val_str = val_str.substr(0, vlen - 3) + "k"
    return val_str

func draw_axes(local_origin: Vector2, output_scale: Vector2) -> void:
    var oversample_factor: = cur_zoom
    if oversample_factor < 1:
        oversample_factor = 0
    var x_tick_char_offset: = Vector2(-4, 9)
    var font_size: = 8
    var char_advance: = Vector2(5, 1)
    var char_advance_2: = Vector2(5, 2)

    var x_step: = get_best_step(horizontal_max - horizontal_min, size.x, min_pixels_per_step_h)
    var x_grid_step: = Vector2.RIGHT * x_step * output_scale.x
    var lowest_x_step: int = 0
    while (lowest_x_step - 1) * x_grid_step.x > -local_origin.x:
        lowest_x_step -= 1

    var x_step_num: int = lowest_x_step
    var x_end: = size.x - local_origin.x
    var x_tick_color: = x_axis_color.darkened(0.5)
    var x_tick_offset: = Vector2(0, 5)
    while x_step_num * x_grid_step.x < x_end:
        if x_step_num == 0:
            x_step_num += 1
            continue
        var tick_pos: = local_origin + (x_grid_step * x_step_num)
        var print_val: = absi(x_step_num) == 1 or x_step_num % 5 == 0
        if x_step > 1:
            print_val = true
        var lower_offset: = Vector2(0, 2) if print_val else x_tick_offset
        draw_line(tick_pos - x_tick_offset, tick_pos + lower_offset, x_tick_color, -1)
        if print_val:
            var val_str: = get_tick_val_string(x_step, x_step_num)
            var char_num: = val_str.length()
            var adv: = char_advance if char_num < 4 else char_advance_2
            var half_width: = Vector2(adv.x * mini(3, char_num - 1) / 2.0, 0)
            for i in char_num:
                var char_pos: = tick_pos + x_tick_char_offset + (i * adv) - half_width
                draw_char(coordinate_font, char_pos, val_str[i], font_size, x_axis_color, oversample_factor)
        x_step_num += 1
    draw_line(Vector2(0, local_origin.y), Vector2(size.x, local_origin.y), x_axis_color, -1)

    var y_step: = get_best_step(vertical_range, size.y, min_pixels_per_step_v)
    var y_grid_step: = Vector2.DOWN * y_step * output_scale.y
    var lowest_y_step: int = 0
    while (lowest_y_step - 1) * y_grid_step.y > -local_origin.y:
        lowest_y_step -= 1

    var y_tick_char_offset: = Vector2(-3, 4)

    var y_step_num: int = lowest_y_step
    var y_end: = size.y - local_origin.y
    var y_tick_color: = y_axis_color.darkened(0.5)
    var y_tick_offset: = Vector2(5, 0)
    while y_step_num * y_grid_step.y < y_end:
        if y_step_num == 0:
            y_step_num += 1
            continue
        var tick_pos: = local_origin + (y_grid_step * y_step_num)
        var print_val: = absi(y_step_num) == 1 or y_step_num % 5 == 0
        if y_step > 1:
            print_val = true
        var left_offset: = Vector2(2, 0) if print_val else y_tick_offset
        draw_line(tick_pos - left_offset, tick_pos + y_tick_offset, y_tick_color, -1)
        if print_val:
            var val_str: = get_tick_val_string(y_step, -y_step_num)
            var char_num: = val_str.length()
            for i in char_num:
                var char_pos: = tick_pos + y_tick_char_offset - Vector2(char_advance.x, 0) * (i + 1)
                draw_char(coordinate_font, char_pos, val_str[char_num - i - 1], font_size, y_axis_color, oversample_factor)
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

func get_best_step(val_range: float, render_size: float, min_pixels_per_step: float) -> int:
    var step: int = 1
    var is_5: = false
    var val_factor: = render_size / val_range
    while step <= 1000000000:
        var last_step: = step
        if is_5:
            step *= 2
        else:
            step *= 5
        is_5 = not is_5

        if step * val_factor > min_pixels_per_step: 
            return last_step
    return step


func reset_dragging_state() -> void:
    dragging_point_idx = -1

func drop_point(event: InputEventMouseButton) -> void:
    dragging_point_idx = -1
    if not get_rect().has_point(event.position):
        start_animating_region()
    input_changed_curve(get_domain_to_output())
    points_adjustment_ended.emit()

func _gui_input(event: InputEvent) -> void:
    if not (is_using_curve and is_curve_points_editable):
        return

    var mme: = event as InputEventMouseMotion
    if mme and dragging_point_idx >= 0:
        drag_point(mme)
    
    var mbe: = event as InputEventMouseButton
    if mbe:
        var left_mb_pressed: = mbe.button_index == MOUSE_BUTTON_LEFT and mbe.is_pressed()
        var right_mb_pressed: = mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.is_pressed()
        if dragging_point_idx >= 0:
            if left_mb_pressed:
                stop_animating_region()
            elif mbe.button_index == MOUSE_BUTTON_LEFT and not mbe.is_pressed():
                drop_point(mbe)
        else:
            if left_mb_pressed or right_mb_pressed:
                stop_animating_region()

            if left_mb_pressed:
                if mbe.ctrl_pressed:
                    add_new_point(mbe)
                else:
                    check_for_start_dragging(mbe)
            elif right_mb_pressed:
                check_for_remove_point(mbe)

func add_new_point(mbe: InputEventMouseButton) -> void:
    var domain_to_output: = get_domain_to_output()
    var inv_transform: = domain_to_output.affine_inverse()
    var new_curve_pos: = (inv_transform * mbe.position).snapped(Vector2.ONE * snapping_interval)

    sorted_points.append(new_curve_pos)
    sorted_points = _sort_points(sorted_points)
    points_changed.emit(sorted_points)

    input_changed_curve(domain_to_output)
    
func check_for_start_dragging(mbe: InputEventMouseButton) -> bool:
    for point_idx in point_position_cache.size():
        if point_position_cache[point_idx].distance_squared_to(mbe.position) < can_drag_dist_squared:
            dragging_point_idx = point_idx
            dragging_mouse_offset = point_position_cache[point_idx] - mbe.position 
            return true
    return false

func check_for_remove_point(mbe: InputEventMouseButton) -> bool:
    for point_idx in point_position_cache.size():
        if point_position_cache[point_idx].distance_squared_to(mbe.position) < can_drag_dist_squared:
            # Expects external call to curve_update, so don't need to refresh or update cached point positions
            delete_point.emit(point_idx)
            return true
    return false

func drag_point(mouse_motion_event: InputEventMouseMotion) -> void:
    if not is_using_curve or not is_curve_points_editable:
        print_debug("Not dragging point because not using curve or points are not editable")
        push_warning("Not dragging point because not using curve or points are not editable")
        return

    var new_plot_pos: = mouse_motion_event.position + dragging_mouse_offset
    var new_idx: int = 0
    for i in point_position_cache.size():
        if point_position_cache[i].x > new_plot_pos.x:
            break
        new_idx += 1
    if new_idx > dragging_point_idx:
        new_idx -= 1
    
    var domain_to_output: = get_domain_to_output()
    if new_idx == dragging_point_idx:
        update_point_from_plot_pos(domain_to_output, new_plot_pos)
        input_changed_curve(domain_to_output, false, dragging_point_idx)
    else:
        move_and_reorder_point(domain_to_output, dragging_point_idx, new_idx, new_plot_pos)
        input_changed_curve(domain_to_output, false)
    
func input_changed_curve(domain_to_output: Transform2D, start_anim_if_changed: bool = true, idx_updated: int = -1) -> void:
    refresh_curve(false, start_anim_if_changed)
    update_point_pos_cache(domain_to_output, idx_updated)

func update_point_from_plot_pos(domain_to_output: Transform2D, new_plot_pos: Vector2) -> void:
    var inv_transform: = domain_to_output.affine_inverse()
    var new_curve_pos: = (inv_transform * new_plot_pos).snapped(Vector2.ONE * snapping_interval)
    sorted_points[dragging_point_idx] = new_curve_pos
    points_adjusted.emit(sorted_points)

func move_and_reorder_point(domain_to_output: Transform2D, old_idx: int, new_idx: int, new_plot_pos: Vector2) -> void:
    var inv_transform: = domain_to_output.affine_inverse()

    sorted_points.remove_at(old_idx)
    sorted_points.insert(new_idx, (inv_transform * new_plot_pos).snapped(Vector2.ONE * snapping_interval))
    points_adjusted.emit(sorted_points)
    dragging_point_idx = new_idx


func update_point_pos_cache(domain_to_output: Transform2D, point_idx: int = -1) -> void:
    if point_position_cache.size() != sorted_points.size():
        create_point_pos_cache(domain_to_output)
        return
    if point_idx >= 0:
        point_position_cache[point_idx] = domain_to_output * sorted_points[point_idx]
    else:
        for i in point_position_cache.size():
            point_position_cache[i] = domain_to_output * sorted_points[i]

func create_point_pos_cache(domain_to_output: Transform2D) -> void:
    point_position_cache.clear()
    for i in sorted_points.size():
        point_position_cache.append(domain_to_output * sorted_points[i])

func _check_for_unsorted() -> void:
    if not OS.has_feature("debug"):
        return
    var sorted: = _sort_points(sorted_points)
    assert(sorted == sorted_points, "Curve Plot: assumed sorted points but they are not sorted")