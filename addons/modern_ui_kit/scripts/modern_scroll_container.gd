@tool
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


## 要滚动的内容节点，默认是第一个子节点。[br]
## Content node to scroll, the first child by default. 
@export var content_node :Control

## 鼠标滚轮参数分组
@export_group("Mouse Wheel Params")

## 滚动速度。数值越大，滚动越快。[br]
## Scrolling speed. The higher the value, the faster it scrolls. 
@export var speed := 1000:
	set(val): speed = max(val, 0)

## 鼠标滚轮滑动时的摩擦值，非物理意义。数值越大，减速越明显。[br]
## Friction when scrolling with mouse wheel, not physical. 
## The higher the value, the more obvious the deceleration. 
@export var friction_scroll := 100000:
	set(val): friction_scroll = max(val, 0)

## 鼠标滚轮滑动时的出界回弹力度，数值越大，回弹力度越大。[br]
## Bounce strength when out of boundary with mouse wheel. 
## The higher the value, the greater the strength. 
@export var bounce_scroll := 400:
	set(val): bounce_scroll = max(val, 0)

## 拖拽滚动参数分组
@export_group("Dragging Params")

## 拖拽滚动时的摩擦值，非物理意义。数值越大，减速越明显。[br]
## Friction when scrolling by dragging, not physical. 
## The higher the value, the more obvious the deceleration. 
@export var friction_drag := 100000:
	set(val): friction_drag = max(val, 0)

## 拖拽滑动时的出界回弹力度，数值越大，回弹力度越大。[br]
## Bounce strength when out of boundary with dragging. 
## The higher the value, the greater the strength. 
@export var bounce_drag := 400:
	set(val): bounce_drag = max(val, 0)

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
## when [param content_node] 's height less than or equal to this container 's.
@export var auto_lock_v := true

## 如果为  [code]true[/code] ，则此容器将自动滚动到获得焦点的子项以确保它们完全可见。[br]
## If  [code]true[/code] , this container will automatically scroll to focused children 
## to make sure they are fully visible.
@export var follow_focus := true

## @experimental
## 为滚动到焦点节点留出间距。[br]
## Margin for focused child if follow focus.
var follow_focus_margin := 0

# 滚动速度。
# Scrolling velocity. 
var _velocity = Vector2.ZERO
# 最终摩擦力。
# Friction to use. 
var _friction = 0
# 最终回弹力。
# Bounce strength to use. 
var _bounce_strength = 0
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
	child_entered_tree.connect(_on_child_changed.bind(false))
	child_exiting_tree.connect(_on_child_changed.bind(true))
	child_order_changed.connect(_on_child_changed.bind(null, false))
	resized.connect(_on_self_resized)
	size_flags_changed.connect(_on_self_resized)
	get_window().gui_focus_changed.connect(_on_gui_focus_changed)


func _exit_tree() -> void:
	child_entered_tree.disconnect(_on_child_changed)
	child_exiting_tree.disconnect(_on_child_changed)
	child_order_changed.disconnect(_on_child_changed)
	resized.disconnect(_on_self_resized)
	size_flags_changed.disconnect(_on_self_resized)
	get_window().gui_focus_changed.disconnect(_on_gui_focus_changed)


func _ready() -> void:
	_friction = friction_scroll
	_bounce_strength = bounce_scroll


func _gui_input(event:InputEvent) -> void:
	if !content_node: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP \
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
				or event.button_index == MOUSE_BUTTON_WHEEL_LEFT \
				or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_handle_wheel_input(event)
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
			or event is InputEventScreenTouch \
			or event is InputEventMouseMotion \
			or event is InputEventScreenDrag:
		_handle_drag_input(event)


func _process(delta:float) -> void:
	if !content_node: return
	if Engine.is_editor_hint(): return
	_scroll(delta)


# 处理鼠标滚轮事件
func _handle_wheel_input(event:InputEventMouseButton) -> void:
	if !event.pressed: return
	# 更改参数
	# Change parameters
	_friction = friction_scroll
	_bounce_strength = bounce_scroll
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
				_velocity.y += speed * event.factor * (1 if add else -1)
		else:
			if _should_scroll_horizontal(): 
				_velocity.x += speed * event.factor * (1 if add else -1)
	# 处理不同按钮
	# Handle different buttons
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if can_h_scroll:
				apply_speed.call(false, true)
			if can_v_scroll:
				apply_speed.call(true, true)
		MOUSE_BUTTON_WHEEL_DOWN:
			if can_h_scroll:
				apply_speed.call(false, false)
			if can_v_scroll:
				apply_speed.call(true, false)
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
			_friction = friction_drag
			_bounce_strength = bounce_drag
	if can_move_with_mouse or can_move_with_touch:
		if _is_dragging:
			if _should_scroll_horizontal():
				_drag_temp_data[0] += event.relative.x
			if _should_scroll_vertical():
				_drag_temp_data[1] += event.relative.y
			_handle_content_dragging()


func _handle_content_dragging() -> void:
	var pos = _get_content_node_position()
	
	var calculate_dest = func(delta:float, bounce_strength:float) -> float:
		if delta >= 0.0:
			return delta / (1 + delta * bounce_strength * 0.00001)
		else:
			return delta
	
	var calculate_position = func(
		temp_dist1: float,		# Temp distance
		temp_dist2: float,
		temp_relative: float	# Event's relative movement accumulation
	) -> float:
		if temp_relative + temp_dist1 > 0.0:
			var delta = min(temp_relative, temp_relative + temp_dist1)
			var dest = calculate_dest.call(delta, bounce_drag)
			return dest - min(0.0, temp_dist1)
		elif temp_relative + temp_dist2 < 0.0:
			var delta = max(temp_relative, temp_relative + temp_dist2)
			var dest = -calculate_dest.call(-delta, bounce_drag)
			return dest - max(0.0, temp_dist2)
		else: return temp_relative
	
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
	var content_node_size_diff = _get_child_size_diff(content_node, true)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = _get_child_boundary_dist(
		_get_content_node_position(),
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
		(get_global_rect().size.x >= content_node.get_global_rect().size.x))
	if disable_scroll:
		_velocity.x = 0.0
		return false
	else:
		return true


# 是否能够垂直滚动
func _should_scroll_vertical() -> bool:
	var disable_scroll = lock_v or (auto_lock_v and \
		(get_global_rect().size.y >= content_node.get_global_rect().size.y))
	if disable_scroll:
		_velocity.y = 0.0
		return false
	else:
		return true


func _scroll(delta:float) -> void:
	if !content_node: return
	
	if _is_dragging:
		_velocity = Vector2.ZERO
	else:
		# 出界回弹
		# Bounce when out of boundary
		_bounce(delta)
		# 计算 content_node 位置和 _velocity
		# Calculate content_node.position and _velocity
		var present_time_x = _calculate_time_by_velocity(_velocity.x)
		var present_time_y = _calculate_time_by_velocity(_velocity.y)
		_velocity = Vector2(
			_calculate_velocity_by_time(present_time_x - delta),
			_calculate_velocity_by_time(present_time_y - delta)
		) * sign(_velocity)
		content_node.position += \
			Vector2(
				_calculate_offset_by_time(present_time_x) - _calculate_offset_by_time(present_time_x - delta),
				_calculate_offset_by_time(present_time_y) - _calculate_offset_by_time(present_time_y - delta)
			) * sign(_velocity)


# 出界回弹
# Bounce when out of boundary
func _bounce(delta:float) -> void:
	# 计算该容器与 content_node 的尺寸差距
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = _get_child_size_diff(content_node, true)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = _get_child_boundary_dist(
		_get_content_node_position(),
		content_node_size_diff
	)
	# 计算到左、右、上、下边界所需的速度
	# Calculate velocity to left, right, top and bottom
	var target_vel = Vector4(
		_calculate_velocity_to_dest(_get_content_node_position().x, 0.0),
		_calculate_velocity_to_dest(_get_content_node_position().x, -content_node_size_diff.x),
		_calculate_velocity_to_dest(_get_content_node_position().y, 0.0),
		_calculate_velocity_to_dest(_get_content_node_position().y, -content_node_size_diff.y)
	)
	# 出界回弹，当原始速度不足以到回到边界时，反向应用一个力，得出修改后的速度
	# 当修改后的速度过快时，应用一个恰好回到边界的速度
	# Bounce when out of boundary. When velocity is not fast enough to go back, 
	# apply a opposite force and get a new velocity. If the new velocity is too fast, 
	# apply a velocity that makes it scroll back exactly.
	if _get_content_node_position().x > 0.0:
		if _velocity.x > target_vel.x:
			_velocity.x -= _bounce_strength * abs(content_node_boundary_dist.x) * delta
			if _velocity.x <= target_vel.x:
				_velocity.x = target_vel.x
	if _get_content_node_position().x < -content_node_size_diff.x:
		if _velocity.x < target_vel.y:
			_velocity.x += _bounce_strength * abs(content_node_boundary_dist.y) * delta
			if _velocity.x >= target_vel.y:
				_velocity.x = target_vel.y
	if _get_content_node_position().y > 0.0:
		if _velocity.y > target_vel.z:
			_velocity.y -= _bounce_strength * abs(content_node_boundary_dist.z) * delta
			if _velocity.y <= target_vel.z:
				_velocity.y = target_vel.z
	if _get_content_node_position().y < -content_node_size_diff.y:
		if _velocity.y < target_vel.w:
			_velocity.y += _bounce_strength * abs(content_node_boundary_dist.w) * delta
			if _velocity.y >= target_vel.w:
				_velocity.y = target_vel.w


func _get_child_size_diff(child:Control, clamp:bool) -> Vector2:
	var child_size = child.get_global_rect().size
	# 伪造子节点的尺寸以避免其尺寸小于容器时的错误
	# Falsify the size of the child node to avoid errors 
	# when its size is smaller than this container 's
	if clamp:
		child_size = Vector2(
			max(child.get_global_rect().size.x, get_global_rect().size.x),
			max(child.get_global_rect().size.y, get_global_rect().size.y)
		)
	# 计算该容器与子节点的尺寸差距
	# Calculate the size difference between this container and child node
	var child_size_diff = Vector2(
		child_size.x - get_global_rect().size.x,
		child_size.y - get_global_rect().size.y
	)
	return child_size_diff


func _get_child_boundary_dist(child_pos:Vector2, child_size_diff:Vector2) -> Vector4:
	# 计算子节点到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var child_boundary_dist = Vector4(
		child_pos.x,
		child_pos.x + child_size_diff.x,
		child_pos.y,
		child_pos.y + child_size_diff.y
	)
	return child_boundary_dist


# 根据 content_node 的 size_flag 伪造一个 position getter
# Falsify a position getter based on content_node 's size_flag
func _get_content_node_position() -> Vector2:
	var fake_position = _get_child_fake_position(content_node)
	fake_position.x = min(fake_position.x, content_node.position.x)
	fake_position.y = min(fake_position.y, content_node.position.y)
	return fake_position


func _get_child_fake_position(node:Control) -> Vector2:
	var fake_position = node.position
	var EXPAND_CENTER = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	var EXPAND_END = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	if node.size_flags_horizontal == EXPAND_CENTER:
		fake_position.x -= \
			(get_global_rect().size.x - node.get_global_rect().size.x) / 2
	if node.size_flags_horizontal == EXPAND_END:
		fake_position.x -= \
			get_global_rect().size.x - node.get_global_rect().size.x
	if node.size_flags_vertical == EXPAND_CENTER:
		fake_position.y -= \
			(get_global_rect().size.y - node.get_global_rect().size.y) / 2
	if node.size_flags_vertical == EXPAND_END:
		fake_position.y -= \
			get_global_rect().size.y - node.get_global_rect().size.y
	return fake_position


# 根据 content_node 的 size_flag 伪造一个 position setter
# Falsify a position setter based on content_node 's size_flag
func _set_content_node_position(new_position:Vector2) -> void:
	_fit_child_position(content_node, new_position, true)


# 设置子节点位置
func _fit_child_position(node:Control, new_position:Vector2, keep_offset:bool=false) -> void:
	if content_node and node == content_node and ! Engine.is_editor_hint() and !keep_offset:
		new_position = _get_child_fake_position(node)
	var fake_position = new_position
	var EXPAND_CENTER = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	var EXPAND_END = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	if node.size_flags_horizontal == EXPAND_CENTER:
		fake_position.x += \
			(get_global_rect().size.x - node.get_global_rect().size.x) / 2
	if node.size_flags_horizontal == EXPAND_END:
		fake_position.x += \
			get_global_rect().size.x - node.get_global_rect().size.x
	if node.size_flags_vertical == EXPAND_CENTER:
		fake_position.y += \
			(get_global_rect().size.y - node.get_global_rect().size.y) / 2
	if node.size_flags_vertical == EXPAND_END:
		fake_position.y += \
			get_global_rect().size.y - node.get_global_rect().size.y
	node.position = fake_position


# 用时间求速度
func _calculate_velocity_by_time(time:float) -> float:
	if time <= 0.0: return 0.0
	return time*time*time * _friction


# 用速度求时间
func _calculate_time_by_velocity(velocity:float) -> float:
	return pow(abs(velocity) / _friction, 1.0/3.0)


# 用位移求时间
func _calculate_offset_by_time(time:float) -> float:
	time = max(time, 0.0)
	return 1.0/4.0 * _friction * time*time*time*time


# 用时间求位移
func _calculate_time_by_offset(offset:float) -> float:
	return pow(offset * 4.0 / _friction, 1.0/4.0)


# 计算到达目的地所需的速度
func _calculate_velocity_to_dest(from:float, to:float) -> float:
	var dist = to - from
	var time = _calculate_time_by_offset(abs(dist))
	var vel = _calculate_velocity_by_time(time) * sign(dist)
	return vel


# 当子节点树状改变时。
func _on_child_changed(node:Node=null, exit_tree:bool=false) -> void:
	# 将第一个子节点赋值给 content_node。
	# Assign the first child node to content_node.
	if get_children().size() > 0 and get_child(0) is Control:
		content_node = get_child(0)
	else:
		content_node = null
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
			_on_child_resized.bind(node).call_deferred()


# 当当前节点大小变化时
func _on_self_resized() -> void:
	for child in get_children():
		_fit_child_size(child)
		_fit_child_position(child, Vector2.ZERO)


# 当子节点大小变化时
func _on_child_resized(node:Control) -> void:
	_fit_child_size(node)
	_fit_child_position(node, Vector2.ZERO)


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


func _on_gui_focus_changed(node:Control) -> void:
	ensure_control_visible(node)


func ensure_control_visible(child:Control) -> void:
	if !is_ancestor_of(child): return
	
	var child_size_diff = _get_child_size_diff(child, false)
	var child_boundary_dist = _get_child_boundary_dist(
		child.global_position - global_position,
		child_size_diff
	)
	var vel:Vector2 = _velocity
	if child_boundary_dist.x < 0 + follow_focus_margin:
		vel.x = _calculate_velocity_to_dest(child_boundary_dist.x, 0+follow_focus_margin)
	elif child_boundary_dist.y > 0 - follow_focus_margin:
		vel.x = _calculate_velocity_to_dest(child_boundary_dist.y, 0-follow_focus_margin)
	if child_boundary_dist.z < 0 + follow_focus_margin:
		vel.y = _calculate_velocity_to_dest(child_boundary_dist.z, 0+follow_focus_margin)
	elif child_boundary_dist.w > 0 - follow_focus_margin:
		vel.y = _calculate_velocity_to_dest(child_boundary_dist.w, 0-follow_focus_margin)
	
	_velocity = vel


## 将 [param content_node] 水平滚动至
func scroll_h_to(destination:float):
	if !content_node: return
	_velocity.x = _calculate_velocity_to_dest(content_node.position.x, destination)


## 将 [param content_node] 垂直滚动至
func scroll_v_to(destination:float):
	if !content_node: return
	_velocity.y = _calculate_velocity_to_dest(content_node.position.y, destination)


## 将 [param content_node] 滚动至
func scroll_to(destination:Vector2):
	if !content_node: return
	scroll_h_to(destination.x)
	scroll_v_to(destination.y)
