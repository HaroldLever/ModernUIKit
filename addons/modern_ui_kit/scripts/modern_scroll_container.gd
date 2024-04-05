@tool
@icon("res://addons/modern_ui_kit/plugin_icon.svg")
class_name ModernScrollContainer
extends Container
## 拥有平滑滚动、出界回弹、触摸滑动的现代滚动容器。[br]
## Modern scroll container with features like smooth scrolling, 
## bouncing and touch dragging. 


## 键盘修饰键。0代表无任何修饰键被按下。[br]
## Keyboard modifier. 0 means no modifier is pressed. 
enum Modifier{
	NONE = 0,
	CTRL = 1,
	SHIFT = 2,
	ALT = 4,
}


## 鼠标滚轮参数分组
@export_group("Mouse Wheel Params")

## 滚动速度。数值越大，滚动越快。[br]
## Scrolling speed. The higher the value, the faster it scrolls. 
@export_range(0.001, 100000.0, 0.001, "or_greater", "hide_slider")
var speed := 1000.0:
	set(val): speed = max(val, 0.0)

## 鼠标滚轮滑动时使用的 VelocityHelper。[br]
## VelocityHelper for mouse wheel scrolling.
@export var wheel_velocity_helper :VelocityHelper

## 拖拽滚动参数分组
@export_group("Dragging Params")

## 拖动时使用的 VelocityHelper。[br]
## VelocityHelper for dragging.
@export var dragging_velocity_helper :VelocityHelper

## 启用鼠标左键拖动。[br]
## Enable dragging with mouse left button. 
@export var enable_mouse_dragging := true

## 启用触摸拖动。[br]
## Enable dragging with screen touch. 
@export var enable_touch_dragging := true

## 行为设置
@export_group("Behaviors")

## 水平方向修饰键
@export_flags("Ctrl", "Shift", "Alt") var h_scroll_modifier := Modifier.SHIFT as int:
	set(val): h_scroll_modifier = clampi(val, 0, 7)

## 垂直方向修饰键
@export_flags("Ctrl", "Shift", "Alt") var v_scroll_modifier := Modifier.NONE as int:
	set(val): v_scroll_modifier = clampi(val, 0, 7)

## 锁定水平滚动 [br]
## Lock horizontal scrolling 
@export var lock_h := false

## 锁定垂直滚动 [br]
## Lock vertical scrolling 
@export var lock_v := false

## 当 [param content_node] 宽度小于等于此容器时，自动锁定水平滚动。[br]
## Lock horizontal scrolling 
## when [param content_node] 's width is less than or equal to this container 's.
@export var auto_lock_h := true

## 当 [param content_node] 高度小于等于此容器时，自动锁定垂直滚动。[br]
## Lock vertical scrolling 
## when [param content_node] 's height is less than or equal to this container 's.
@export var auto_lock_v := true

## 如果为  [code]true[/code] ，则此容器将自动滚动到获得焦点的子项以确保它们完全可见。[br]
## If  [code]true[/code] , this container will automatically scroll to focused children 
## to make sure they are fully visible.
@export var follow_focus := true

## @experimental
## 为滚动到焦点节点留出间距。[br]
## Margin for focused child if follow focus.
@export_range(0.000, 100.0, 0.001, "or_greater", "hide_slider")
var follow_focus_margin := 0.0:
	set(val): follow_focus_margin = max(val, 0.0)

## 下一帧位移足够接近边界时，吸附至边界
## Snap to boundary if close enough in next frame
@export_range(0.000, 100.0, 0.001, "or_greater", "hide_slider")
var snapping_tolerance := 0.4:
	set(val): snapping_tolerance = max(val, 0.0)

## 子节点动作
@export_group("Child Node Actions")

## 要滚动的内容节点，默认是第一个子节点。[br]
## Content node to scroll, the first child by default. 
@export var content_node :Control

## 自动将第一个子节点作为 [param content_node] [br]
## Automatically sets the first child node as [param content_node]
@export var auto_find_content_node := true:
	set(val): 
		auto_find_content_node = val
		if val: find_content_node()

## 水平滚动条
@export var h_scroll_bar :ScrollBar:
	set(val):
		h_scroll_bar = _set_h_scroll_bar(val)
		_update_h_scroll_bar()

## 垂直滚动条
@export var v_scroll_bar :ScrollBar:
	set(val):
		v_scroll_bar = _set_v_scroll_bar(val)
		_update_v_scroll_bar()

@export_group("Theme")

## 如果为 [code]true[/code] ，使用 ScrollContainer 同样的主题样式，
## 如果为 [code]false[/code] ，寻找 ModernScrollContainer 主题样式。[br]
## if [code]true[/code] , use ScrollContainer theme style，
## if [code]false[/code] , search ModernScrollContainer theme style. 
@export var use_scroll_container_style := true:
	set(val): 
		use_scroll_container_style = val
		queue_redraw()

@export_group("Theme Overrides")

@export_subgroup("Styles", "override_")

## 覆盖
@export var override_panel :StyleBox

# 正在使用的 VelocityHelper
# VelocityHelper in use.
var _velocity_helper :VelocityHelper
# 滚动速度。
# Scrolling velocity. 
var _velocity = Vector2.ZERO
# 是否正在拖拽 content_node
# Dragging content_node or not
var _is_dragging = false
# [0,1] 鼠标或触点累积出界拖拽相对位移，[2,3] 拖拽开始时 content_noe 的位置，
# [4,5,6,7] 左，右，上，下边界距离。
# [0,1] Mouse or touch's relative dragging movement accumulation when out of boundary. 
# [2,3] Content node 's position when dragging starts. 
# [4,5,6,7] Left_distance, right_distance, top_distance, bottom_distance. 
var _drag_temp_data := []


func _enter_tree() -> void:
	# 连接信号
	# Connect signals
	child_entered_tree.connect(_on_child_changed.bind(false))
	child_exiting_tree.connect(_on_child_changed.bind(true))
	child_order_changed.connect(_on_child_changed.bind(null, false))
	resized.connect(_on_self_resized)
	size_flags_changed.connect(_on_self_resized)
	get_window().gui_focus_changed.connect(_on_gui_focus_changed)


func _exit_tree() -> void:
	# 断开信号
	# Disconnect signals
	child_entered_tree.disconnect(_on_child_changed)
	child_exiting_tree.disconnect(_on_child_changed)
	child_order_changed.disconnect(_on_child_changed)
	resized.disconnect(_on_self_resized)
	size_flags_changed.disconnect(_on_self_resized)
	get_window().gui_focus_changed.disconnect(_on_gui_focus_changed)


func _init() -> void:
	if Engine.is_editor_hint():
		wheel_velocity_helper = CubicVelocityHelper.new()
		dragging_velocity_helper = CubicVelocityHelper.new()


func _ready() -> void:
	# 初始化参数
	# Initialize parameters
	_velocity_helper = wheel_velocity_helper
	# 初始化子节点位置
	# Initialize child nodes' position
	for child in get_children():
		_fit_child_size.call_deferred(child)
		_set_child_fake_position.call_deferred(child, Vector2.ZERO, false, true)
	_update_scroll_bars()


func _draw() -> void:
	# 绘制 panel 
	# Draw panel
	var rect = Rect2(0, 0, size.x, size.y)
	var type = "ScrollContainer" if use_scroll_container_style \
			 else "ModernScrollContainer"
	var box = get_theme_stylebox("panel", type)
	draw_style_box(box, rect)


func _gui_input(event:InputEvent) -> void:
	if !content_node: return
	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
			or event.button_index == MOUSE_BUTTON_WHEEL_LEFT \
			or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT \
		):
			# 处理鼠标滚轮输入事件
			_handle_wheel_input(event)
	if (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch \
		or event is InputEventMouseMotion \
		or event is InputEventScreenDrag \
	):
		# 处理拖拽输入事件
		_handle_drag_input(event)


func _process(delta:float) -> void:
	if !content_node: return
	if !_velocity_helper: return
	if Engine.is_editor_hint(): return
	_scroll(delta)
	_update_scroll_bars()


# 处理鼠标滚轮事件
func _handle_wheel_input(event:InputEventMouseButton) -> void:
	if !event.pressed: return
	# 更改参数
	# Change parameters
	_velocity_helper = wheel_velocity_helper
	# 检查修饰键
	# Check modifiers
	var no_modifier = !event.ctrl_pressed and !event.shift_pressed and !event.alt_pressed
	var ctrl_only = event.ctrl_pressed and !event.shift_pressed and !event.alt_pressed
	var shift_only = !event.ctrl_pressed and event.shift_pressed and !event.alt_pressed
	var alt_only = !event.ctrl_pressed and !event.shift_pressed and event.alt_pressed
	var ctrl_shift = event.ctrl_pressed and event.shift_pressed and !event.alt_pressed
	var ctrl_alt = event.ctrl_pressed and !event.shift_pressed and event.alt_pressed
	var shift_alt = !event.ctrl_pressed and event.shift_pressed and event.alt_pressed
	var ctrl_shift_alt = event.ctrl_pressed and event.shift_pressed and event.alt_pressed
	
	var can_h_scroll = false
	var can_v_scroll = false
	var can_zoom_inout = ctrl_only	# 缩放测试 Zoom in/out test
	match h_scroll_modifier:
		0: can_h_scroll = no_modifier
		1: can_h_scroll = ctrl_only
		2: can_h_scroll = shift_only
		3: can_h_scroll = ctrl_shift
		4: can_h_scroll = alt_only
		5: can_h_scroll = ctrl_alt
		6: can_h_scroll = shift_alt
		7: can_h_scroll = ctrl_shift_alt
	match v_scroll_modifier:
		0: can_v_scroll = no_modifier
		1: can_v_scroll = ctrl_only
		2: can_v_scroll = shift_only
		3: can_v_scroll = ctrl_shift
		4: can_v_scroll = alt_only
		5: can_v_scroll = ctrl_alt
		6: can_v_scroll = shift_alt
		7: can_v_scroll = ctrl_shift_alt
	# 应用速度
	var apply_speed = func(vertical:bool, add:bool) -> void:
		if vertical:
			if _should_scroll_vertical(): 
				_velocity.y += speed * event.factor * (1.0 if add else -1.0)
		else:
			if _should_scroll_horizontal(): 
				_velocity.x += speed * event.factor * (1.0 if add else -1.0)
	var zoom_inout = func(is_in:bool) -> void:
		if is_in:
			content_node.scale /= Vector2(1.1, 1.1)
			content_node.position += (event.position - content_node.position) \
				* (0.1/1.1)
		else:
			content_node.scale *= Vector2(1.1, 1.1)
			content_node.position -= (event.position  - content_node.position) \
				* 0.1
	# 处理不同按钮
	# Handle different buttons
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if can_h_scroll:
				apply_speed.call(false, true)
			if can_v_scroll:
				apply_speed.call(true, true)
			if can_zoom_inout:
				zoom_inout.call(false)
		MOUSE_BUTTON_WHEEL_DOWN:
			if can_h_scroll:
				apply_speed.call(false, false)
			if can_v_scroll:
				apply_speed.call(true, false)
			if can_zoom_inout:
				zoom_inout.call(true)
		MOUSE_BUTTON_WHEEL_LEFT:
			if can_h_scroll:
				apply_speed.call(true, true)
			if can_v_scroll:
				apply_speed.call(false, true)
		MOUSE_BUTTON_WHEEL_RIGHT:
			if can_h_scroll:
				apply_speed.call(true, false)
			if can_v_scroll:
				apply_speed.call(false, false)


# 处理拖动事件
func _handle_drag_input(event:InputEvent) -> void:
	# 能否拖拽
	# Can drag and move
	var can_drag_with_mouse = event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and enable_mouse_dragging
	var can_move_with_mouse = event is InputEventMouseMotion \
			and enable_mouse_dragging
	var can_drag_with_touch = event is InputEventScreenTouch \
			and enable_touch_dragging
	var can_move_with_touch = event is InputEventScreenDrag \
			and enable_touch_dragging
	
	if can_drag_with_mouse or can_drag_with_touch:
		if event.pressed:
			_is_dragging = true
			_init_drag_temp_data()
		else:
			_is_dragging = false
			_velocity_helper = dragging_velocity_helper
	if can_move_with_mouse or can_move_with_touch:
		if _is_dragging:
			if _should_scroll_horizontal():
				_drag_temp_data[0] += event.relative.x
			if _should_scroll_vertical():
				_drag_temp_data[1] += event.relative.y
			_handle_content_dragging()


func _handle_content_dragging() -> void:
	if (!dragging_velocity_helper): return
	var pos = _get_content_node_position()
	# 拖拽出界衰减公式
	# Attenuation formula for dragging when out of boundary
	var calculate_dest = func(delta:float, attracting_strength:float) -> float:
		if delta >= 0.0:
			return delta / (1 + delta * attracting_strength * 0.00001)
		else:
			return delta
	# 计算衰减后的实际位置
	# Calculate the actual position after attenuation 
	var calculate_position = func(
		temp_dist1: float,		# Temp distance
		temp_dist2: float,
		temp_relative: float	# Event's relative movement accumulation
	) -> float:
		if temp_relative + temp_dist1 > 0.0:
			var delta = min(temp_relative, temp_relative + temp_dist1)
			var dest = calculate_dest.call(
				delta,
				dragging_velocity_helper.attracting_strength
			)
			return dest - min(0.0, temp_dist1)
		elif temp_relative + temp_dist2 < 0.0:
			var delta = max(temp_relative, temp_relative + temp_dist2)
			var dest = -calculate_dest.call(
				-delta,
				dragging_velocity_helper.attracting_strength
			)
			return dest - max(0.0, temp_dist2)
		else: return temp_relative
	# 直接设置 content_node 的位置，但仍然需要计算速度以便下一帧释放拖拽时有速度
	# Set content_node' position directly, 
	# but it still need to calculate the velocity in case of 
	# releasing dragging in the next frame.
	if _should_scroll_vertical():
		var y_pos = calculate_position.call(
			_drag_temp_data[6],	# Temp top_distance
			_drag_temp_data[7],	# Temp bottom_distance
			_drag_temp_data[1]	# Temp y relative accumulation
		) + _drag_temp_data[3]
		_velocity.y = (y_pos - pos.y) / get_process_delta_time()
		pos.y = y_pos
	if _should_scroll_horizontal():
		var x_pos = calculate_position.call(
			_drag_temp_data[4],	# Temp left_distance
			_drag_temp_data[5],	# Temp right_distance
			_drag_temp_data[0]	# Temp x relative accumulation
		) + _drag_temp_data[2]
		_velocity.x = (x_pos - pos.x) / get_process_delta_time()
		pos.x = x_pos
	_set_content_node_position(pos)


# 初始化临时拖拽数据
func _init_drag_temp_data() -> void:
	# content_node 的位置
	# Content node 's position
	var content_node_position = _get_content_node_position()
	# 计算该容器与 content_node 的尺寸差距
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = _get_child_size_diff(content_node, true, true)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = _get_child_boundary_dist(
		content_node_position,
		content_node_size_diff
	)
	_drag_temp_data = [
		0.0, 
		0.0, 
		content_node_position.x,
		content_node_position.y,
		content_node_boundary_dist.x, 
		content_node_boundary_dist.y, 
		content_node_boundary_dist.z, 
		content_node_boundary_dist.w
	]


# 是否能够水平滚动
func _should_scroll_horizontal() -> bool:
	var disable_scroll = lock_h or (auto_lock_h and \
		(_get_child_size_x_diff(content_node, false) <= 0.0))
	if disable_scroll:
		_velocity.x = 0.0
		return false
	else:
		return true


# 是否能够垂直滚动
func _should_scroll_vertical() -> bool:
	var disable_scroll = lock_v or (auto_lock_v and \
		(_get_child_size_y_diff(content_node, false) <= 0.0))
	if disable_scroll:
		_velocity.y = 0.0
		return false
	else:
		return true


func _scroll(delta:float) -> void:
	if _is_dragging:
		_velocity = Vector2.ZERO
	else:
		# 出界回弹
		# Bounce when out of boundary
		_bounce(delta)
		# 计算 content_node 位置和 _velocity
		# Calculate content_node.position and _velocity
		var slide_result_x = _velocity_helper.slide(_velocity.x, delta)
		var slide_result_y = _velocity_helper.slide(_velocity.y, delta)
		_velocity = Vector2(slide_result_x[0], slide_result_y[0]) * sign(_velocity)
		content_node.position += Vector2(slide_result_x[1], slide_result_y[1]) * sign(_velocity)
		# 下一帧位移足够接近边界时，吸附至边界
		# Snap to boundary if close enough in next frame
		_snap()


# 出界回弹
# Bounce when out of boundary
func _bounce(delta:float) -> void:
	var content_node_position = _get_content_node_position()
	# 计算该容器与 content_node 的尺寸差距
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = _get_child_size_diff(content_node, true, true)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = _get_child_boundary_dist(
		content_node_position,
		content_node_size_diff
	)
	# 计算到左、右、上、下边界所需的速度
	# Calculate velocity to left, right, top and bottom
	var target_vel = Vector4(
		_velocity_helper._calculate_velocity_to_dest(content_node_boundary_dist.x, 0.0),
		_velocity_helper._calculate_velocity_to_dest(content_node_boundary_dist.y, 0.0),
		_velocity_helper._calculate_velocity_to_dest(content_node_boundary_dist.z, 0.0),
		_velocity_helper._calculate_velocity_to_dest(content_node_boundary_dist.w, 0.0)
	)
	# 出界回弹，当原始速度不足以到回到边界时，反向应用一个力，得出修改后的速度
	# 当修改后的速度过快时，应用一个恰好回到边界的速度
	# Bounce when out of boundary. When velocity is not fast enough to go back, 
	# apply a opposite force and get a new velocity. If the new velocity is too fast, 
	# apply a velocity that makes it scroll back exactly.
	if content_node_position.x > 0.0:
		if _velocity.x > target_vel.x:
			_velocity.x = _velocity_helper.attract(
				content_node_boundary_dist.x,
				0.0,
				_velocity.x,
				delta
			)
	if content_node_position.x < -content_node_size_diff.x:
		if _velocity.x < target_vel.y:
			_velocity.x = _velocity_helper.attract(
				content_node_boundary_dist.y,
				0.0,
				_velocity.x,
				delta
			)
	if content_node_position.y > 0.0:
		if _velocity.y > target_vel.z:
			_velocity.y = _velocity_helper.attract(
				content_node_boundary_dist.z,
				0.0,
				_velocity.y,
				delta
			)
	if content_node_position.y < -content_node_size_diff.y:
		if _velocity.y < target_vel.w:
			_velocity.y = _velocity_helper.attract(
				content_node_boundary_dist.w,
				0.0,
				_velocity.y,
				delta
			)


# 下一帧位移足够接近边界时，吸附至边界
# Snap to boundary if close enough in next frame
func _snap() -> void:
	# Content node 的位置
	# Content node 's position
	var content_node_position = _get_content_node_position()
	# 计算该容器与 content_node 的尺寸差距
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = _get_child_size_diff(content_node, true, true)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = _get_child_boundary_dist(
		content_node_position,
		content_node_size_diff
	)
	if (
		content_node_boundary_dist.x > 0.0 \
		and abs(content_node_boundary_dist.x) < snapping_tolerance \
		and abs(_velocity.x) < snapping_tolerance \
	):
		content_node_position.x -= content_node_boundary_dist.x
		_velocity.x = 0.0
	elif (
		content_node_boundary_dist.y < 0.0 \
		and abs(content_node_boundary_dist.y) < snapping_tolerance \
		and abs(_velocity.x) < snapping_tolerance \
	):
		content_node_position.x -= content_node_boundary_dist.y
		_velocity.x = 0.0
	if (
		content_node_boundary_dist.z > 0.0 \
		and abs(content_node_boundary_dist.z) < snapping_tolerance \
		and abs(_velocity.y) < snapping_tolerance \
	):
		content_node_position.y -= content_node_boundary_dist.z
		_velocity.y = 0.0
	elif (
		content_node_boundary_dist.w < 0.0 \
		and abs(content_node_boundary_dist.w) < snapping_tolerance \
		and abs(_velocity.y) < snapping_tolerance \
	):
		content_node_position.y -= content_node_boundary_dist.w
		_velocity.y = 0.0
	_set_content_node_position(content_node_position)


# 计算该容器与子节点的 x 尺寸差距
# Calculate the size x difference between this container and child node
func _get_child_size_x_diff(child:Control, clamp:bool) -> float:
	var child_size_x = child.size.x * child.scale.x
	# 伪造子节点的尺寸以避免其尺寸小于容器时的错误
	# Falsify the size of the child node to avoid errors 
	# when its size is smaller than this container 's
	if clamp:
		child_size_x = max(child_size_x, size.x)
	return child_size_x - size.x


# 计算该容器与子节点的 y 尺寸差距
# Calculate the size y difference between this container and child node
func _get_child_size_y_diff(child:Control, clamp:bool) -> float:
	var child_size_y = child.size.y * child.scale.y
	# 伪造子节点的尺寸以避免其尺寸小于容器时的错误
	# Falsify the size of the child node to avoid errors 
	# when its size is smaller than this container 's
	if clamp:
		child_size_y = max(child_size_y, size.y)
	return child_size_y - size.y


# 计算该容器与子节点的尺寸差距
# Calculate the size difference between this container and child node
func _get_child_size_diff(child:Control, clamp_x:bool, clamp_y:bool) -> Vector2:
	return Vector2(
		_get_child_size_x_diff(child, clamp_x),
		_get_child_size_y_diff(child, clamp_y)
	)


# 计算子节点到左边界的距离
# Calculate distance to left
func _get_child_left_dist(child_pos_x:float, child_size_diff_x:float) -> float:
	return child_pos_x


# 计算子节点到右边界的距离
# Calculate distance to right
func _get_child_right_dist(child_pos_x:float, child_size_diff_x:float) -> float:
	return child_pos_x + child_size_diff_x


# 计算子节点到上边界的距离
# Calculate distance to top
func _get_child_top_dist(child_pos_y:float, child_size_diff_y:float) -> float:
	return child_pos_y


# 计算子节点到右边界的距离
# Calculate distance to bottom
func _get_child_bottom_dist(child_pos_y:float, child_size_diff_y:float) -> float:
	return child_pos_y + child_size_diff_y


# 计算子节点到左、右、上、下边界的距离
# Calculate distance to left, right, top and bottom
func _get_child_boundary_dist(child_pos:Vector2, child_size_diff:Vector2) -> Vector4:
	return Vector4(
		_get_child_left_dist(child_pos.x, child_size_diff.x),
		_get_child_right_dist(child_pos.x, child_size_diff.x),
		_get_child_top_dist(child_pos.y, child_size_diff.y),
		_get_child_bottom_dist(child_pos.y, child_size_diff.y),
	)


# 根据 content_node 的 size_flag 伪造一个 position getter
# Falsify a position getter based on content_node 's size_flag
func _get_content_node_position(clamp:bool=true) -> Vector2:
	var fake_position = _get_child_fake_position(content_node, clamp)
	return fake_position


# 根据 node 的 size_flag 伪造一个 position getter
# Falsify a position getter based on node 's size_flag
func _get_child_fake_position(node:Control, clamp:bool=false) -> Vector2:
	var fake_position = node.position
	var size_diff = _get_child_size_diff(node, true, true)
	var EXPAND_CENTER = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	var EXPAND_END = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	if node.size_flags_horizontal == EXPAND_CENTER:
		fake_position.x -= \
			(size.x - node.size.x * node.scale.x) / 2.0
		if clamp: fake_position.x -= size_diff.x / 2.0
	if node.size_flags_horizontal == EXPAND_END:
		fake_position.x -= \
			size.x - node.size.x * node.scale.x
		if clamp: fake_position.x -= size_diff.x
	if node.size_flags_vertical == EXPAND_CENTER:
		fake_position.y -= \
			(size.y - node.size.y * node.scale.y) / 2.0
		if clamp: fake_position.y -= size_diff.y / 2.0
	if node.size_flags_vertical == EXPAND_END:
		fake_position.y -= \
			size.y - node.size.y * node.scale.y
		if clamp: fake_position.y -= size_diff.y
	return fake_position


# 根据 content_node 的 size_flag 伪造一个 position setter
# Falsify a position setter based on content_node 's size_flag
func _set_content_node_position(new_position:Vector2, clamp:bool=true, keep_offset:bool=true) -> void:
	_set_child_fake_position(content_node, new_position, clamp, keep_offset)


# 根据 node 的 size_flag 伪造一个 position setter
# Falsify a position setter based on node 's size_flag
func _set_child_fake_position(node:Control, new_position:Vector2, clamp:bool=false, keep_offset:bool=false) -> void:
	# 当容器在游戏中更改尺寸时，不应重置滚动位置
	# When container resize in game, scrolling position should not be reset
	if content_node and node == content_node and ! Engine.is_editor_hint() and !keep_offset:
		new_position = _get_child_fake_position(node)
	
	var size_diff = _get_child_size_diff(node, true, true)
	var EXPAND_CENTER = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	var EXPAND_END = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	if node.size_flags_horizontal == EXPAND_CENTER:
		new_position.x += \
			(size.x - node.size.x * node.scale.x) / 2
		if clamp: new_position.x += size_diff.x / 2.0
	if node.size_flags_horizontal == EXPAND_END:
		new_position.x += \
			size.x - node.size.x * node.scale.x
		if clamp: new_position.x += size_diff.x
	if node.size_flags_vertical == EXPAND_CENTER:
		new_position.y += \
			(size.y - node.size.y * node.scale.y) / 2
		if clamp: new_position.y += size_diff.y / 2.0
	if node.size_flags_vertical == EXPAND_END:
		new_position.y += \
			size.y - node.size.y * node.scale.y
		if clamp: new_position.y += size_diff.y
	node.position = new_position


# 刷新滚动条
func _update_scroll_bars() -> void:
	_update_h_scroll_bar()
	_update_v_scroll_bar()


func _update_h_scroll_bar() -> void:
	if !h_scroll_bar: return
	if !content_node: return
	# 设置滚动条参数
	# Set scroll bar 's parameters
	h_scroll_bar.min_value = 0
	h_scroll_bar.page = size.x
	if content_node:
		h_scroll_bar.max_value = max(
			content_node.size.x * content_node.scale.x,
			size.x,
		)
		h_scroll_bar.set_value_no_signal(-_get_content_node_position().x)
	else:
		h_scroll_bar.max_value = size.x
		h_scroll_bar.set_value_no_signal(0)
	h_scroll_bar.queue_redraw()


func _update_v_scroll_bar() -> void:
	if !v_scroll_bar: return
	if !content_node: return
	# 设置滚动条参数
	# Set scroll bar 's parameters
	v_scroll_bar.min_value = 0
	v_scroll_bar.page = size.y
	if content_node:
		v_scroll_bar.max_value = max(
			content_node.size.y * content_node.scale.y,
			size.y,
		)
		v_scroll_bar.set_value_no_signal(-_get_content_node_position().y)
	else:
		v_scroll_bar.max_value = size.y
		v_scroll_bar.set_value_no_signal(0)
	v_scroll_bar.queue_redraw()


func _set_h_scroll_bar(node) -> ScrollBar:
	# 连接与断开信号
	# Connect and disconnect signals
	if h_scroll_bar:
		if h_scroll_bar.value_changed.is_connected(_on_h_scroll_bar_value_changed):
			h_scroll_bar.value_changed.disconnect(_on_h_scroll_bar_value_changed)
		if h_scroll_bar.gui_input.is_connected(_on_h_scroll_bar_gui_input):
			h_scroll_bar.gui_input.disconnect(_on_h_scroll_bar_gui_input)
	if node:
		if !node.value_changed.is_connected(_on_h_scroll_bar_value_changed):
			node.value_changed.connect(_on_h_scroll_bar_value_changed)
		if !node.gui_input.is_connected(_on_h_scroll_bar_gui_input):
			node.gui_input.connect(_on_h_scroll_bar_gui_input)
	return node


func _set_v_scroll_bar(node) -> ScrollBar:
	# 连接与断开信号
	# Connect and disconnect signals
	if v_scroll_bar:
		if v_scroll_bar.value_changed.is_connected(_on_v_scroll_bar_value_changed):
			v_scroll_bar.value_changed.disconnect(_on_v_scroll_bar_value_changed)
		if v_scroll_bar.gui_input.is_connected(_on_v_scroll_bar_gui_input):
			v_scroll_bar.gui_input.disconnect(_on_v_scroll_bar_gui_input)
	if node:
		if !node.value_changed.is_connected(_on_v_scroll_bar_value_changed):
			node.value_changed.connect(_on_v_scroll_bar_value_changed)
		if !node.gui_input.is_connected(_on_v_scroll_bar_gui_input):
			node.gui_input.connect(_on_v_scroll_bar_gui_input)
	return node



func _on_h_scroll_bar_gui_input(event) -> void:
	if event is InputEventMouseButton:
		# 截获滚动条上的滚轮输入事件
		# Intercept wheel event on scroll bar
		if (
			event.button_index == MOUSE_BUTTON_WHEEL_LEFT \
			or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT \
			or event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
		):
			# 根据 h_scroll_modifier 伪造修饰键
			# Falsify modifier based on h_scroll_modifier
			event.ctrl_pressed = (h_scroll_modifier & Modifier.CTRL) != 0
			event.shift_pressed = (h_scroll_modifier & Modifier.SHIFT) != 0
			event.alt_pressed = (h_scroll_modifier & Modifier.ALT) != 0
			_handle_wheel_input(event)


func _on_v_scroll_bar_gui_input(event) -> void:
	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_WHEEL_LEFT \
			or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT \
			or event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
		):
			# 根据 v_scroll_modifier 伪造修饰键
			# Falsify modifier based on v_scroll_modifier
			event.ctrl_pressed = (v_scroll_modifier & Modifier.CTRL) != 0
			event.shift_pressed = (v_scroll_modifier & Modifier.SHIFT) != 0
			event.alt_pressed = (v_scroll_modifier & Modifier.ALT) != 0
			_handle_wheel_input(event)


func _on_h_scroll_bar_value_changed(value) -> void:
	if !content_node: return
	# 如果滚动条被拖拽，直接设置 content_node 的位置
	# Set content_node position directly if scroll bar is dragged
	var pos = _get_content_node_position()
	if (
		!Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_LEFT) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_RIGHT) \
	):
		_velocity = Vector2.ZERO
		_set_content_node_position(Vector2(-value, pos.y))


func _on_v_scroll_bar_value_changed(value) -> void:
	if !content_node: return
	# 如果滚动条被拖拽，直接设置 content_node 的位置
	# Set content_node position directly if scroll bar is dragged
	var pos = _get_content_node_position()
	if (
		!Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_LEFT) \
		and !Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_RIGHT) \
	):
		_velocity = Vector2.ZERO
		_set_content_node_position(Vector2(pos.x, -value))


# 当子节点树状改变时。
func _on_child_changed(node:Node=null, exit_tree:bool=false) -> void:
	# 将第一个子节点赋值给 content_node。
	# Assign the first child node to content_node.
	if auto_find_content_node:
		find_content_node()
	# 连接信号
	# Connect signals
	if node and node is Control:
		if exit_tree:
			node.resized.disconnect(_on_child_resized)
			node.size_flags_changed.disconnect(_on_child_resized)
			node.minimum_size_changed.disconnect(_on_child_resized)
		else:
			node.resized.connect(_on_child_resized.bind(node))
			node.size_flags_changed.connect(_on_child_resized.bind(node))
			node.minimum_size_changed.connect(_on_child_resized.bind(node))


# 当当前节点大小变化时
func _on_self_resized() -> void:
	# 重新设置子节点的尺寸与位置
	# Refresh child node 's size and position
	for child in get_children():
		_fit_child_size(child)
		_set_child_fake_position(child, Vector2.ZERO)
	# 刷新滚动条
	# Refresh scroll bars
	_update_scroll_bars()


# 当子节点大小变化时
func _on_child_resized(node:Control) -> void:
	# 重新设置子节点的尺寸与位置
	# Refresh child node 's size and position
	_fit_child_size(node)
	_set_child_fake_position(node, Vector2.ZERO)
	# 刷新滚动条
	# Refresh scroll bars
	if node == content_node:
		_update_scroll_bars()


# 设置子节点大小
func _fit_child_size(node:Control) -> void:
	if node.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
		node.size.x = size.x
	else:
		node.size.x = 0.0
	if node.size_flags_vertical == Control.SIZE_EXPAND_FILL:
		node.size.y = size.y
	else:
		node.size.y = 0.0


# 当焦点控件变化时
func _on_gui_focus_changed(node:Control) -> void:
	if follow_focus:
		ensure_control_visible(node)


## 将第一个子节点赋值给 content_node。
## Assign the first child node to content_node.
func find_content_node() -> Control:
	if get_children().size() > 0 and get_child(0) is Control:
		content_node = get_child(0)
	else:
		content_node = null
	return content_node


## 确保子节点可见
func ensure_control_visible(child:Control) -> void:
	if !content_node: return
	if !content_node.is_ancestor_of(child): return
	if !_velocity_helper: return
	
	var child_size_diff = (
		child.get_global_rect().size - get_global_rect().size
	) / (get_global_rect().size / size)
	var child_boundary_dist = _get_child_boundary_dist(
		(child.global_position - global_position)  / (get_global_rect().size / size),
		child_size_diff
	)
	var content_node_position = _get_content_node_position()
	if child_boundary_dist.x < 0 + follow_focus_margin:
		scroll_h_to(content_node_position.x - child_boundary_dist.x + follow_focus_margin)
	elif child_boundary_dist.y > 0 - follow_focus_margin:
		scroll_h_to(content_node_position.x - child_boundary_dist.y - follow_focus_margin)
	if child_boundary_dist.z < 0 + follow_focus_margin:
		scroll_v_to(content_node_position.y - child_boundary_dist.z + follow_focus_margin)
	elif child_boundary_dist.w > 0 - follow_focus_margin:
		scroll_v_to(content_node_position.y - child_boundary_dist.w - follow_focus_margin)


## 将 [param content_node] 水平滚动至
func scroll_h_to(destination:float, clamp:bool=true):
	if !content_node: return
	if !_velocity_helper: return
	var content_node_position = _get_content_node_position()
	_velocity.x = _velocity_helper._calculate_velocity_to_dest(
		content_node_position.x,
		destination
	)
	if clamp:
		var size_x_diff = _get_child_size_x_diff(content_node, true)
		if _get_child_left_dist(destination, size_x_diff) > 0.0:
			_velocity.x = _velocity_helper._calculate_velocity_to_dest(
				content_node_position.x,
				0.0
			)
		if _get_child_right_dist(destination, size_x_diff) < 0.0:
			_velocity.x = _velocity_helper._calculate_velocity_to_dest(
				content_node_position.x,
				-size_x_diff
			)


## 将 [param content_node] 垂直滚动至
func scroll_v_to(destination:float, clamp:bool=true):
	if !content_node: return
	if !_velocity_helper: return
	var content_node_position = _get_content_node_position()
	_velocity.y = _velocity_helper._calculate_velocity_to_dest(
		content_node_position.y,
		destination
	)
	if clamp:
		var size_y_diff = _get_child_size_y_diff(content_node, true)
		if _get_child_top_dist(destination, size_y_diff) > 0.0:
			_velocity.y = _velocity_helper._calculate_velocity_to_dest(
				content_node_position.y,
				0.0
			)
		if _get_child_bottom_dist(destination, size_y_diff) < 0.0:
			_velocity.y = _velocity_helper._calculate_velocity_to_dest(
				content_node_position.y,
				-size_y_diff
			)


## 将 [param content_node] 滚动至
func scroll_to(destination:Vector2, clamp_h:bool=true, clamp_v:bool=true):
	if !content_node: return
	if !_velocity_helper: return
	scroll_h_to(destination.x, clamp_h)
	scroll_v_to(destination.y, clamp_v)
