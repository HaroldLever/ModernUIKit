@tool
class_name ModernScrollContainer
extends Container
## 拥有平滑滚动、出界回弹、触摸滑动的现代滚动容器。
## Modern scroll container with features like smooth scrolling, 
## bouncing and touch dragging. 

## 要滚动的内容节点，默认是第一个子节点。
## Content node to scroll, the first child by default. 
@export var content_node :Control

@export var speed := 1000:
	set(val): speed = max(val, 0)

@export var friction_scroll := 100000:
	set(val): friction_scroll = max(val, 0)

@export var friction_drag := 100000:
	set(val): friction_drag = max(val, 0)

@export var bounce_scroll := 400:
	set(val): bounce_scroll = max(val, 0)

@export var bounce_drag := 400:
	set(val): bounce_drag = max(val, 0)

@export var auto_lock_h := true

@export var auto_lock_v := true

# 滚动速度。
# Scrolling velocity. 
var _velocity = Vector2.ZERO
# 最终摩擦力。
# Friction to use. 
var friction = 0
# 最终回弹力。
# Bounce strength to use
var bounce_strength = 0


func _enter_tree() -> void:
	child_entered_tree.connect(_on_child_changed.bind(false))
	child_exiting_tree.connect(_on_child_changed.bind(true))
	child_order_changed.connect(_on_child_changed.bind(null, false))
	resized.connect(_on_self_resized)
	size_flags_changed.connect(_on_self_resized)


func _exit_tree() -> void:
	child_entered_tree.disconnect(_on_child_changed)
	child_exiting_tree.disconnect(_on_child_changed)
	child_order_changed.disconnect(_on_child_changed)
	resized.disconnect(_on_self_resized)
	size_flags_changed.disconnect(_on_self_resized)


func _ready() -> void:
	friction = friction_scroll
	bounce_strength = bounce_scroll


func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					if event.shift_pressed:
						if _should_scroll_horizontal():
							_velocity.x += speed * event.factor
					else:
						if _should_scroll_vertical():
							_velocity.y += speed * event.factor
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					if event.shift_pressed:
						if _should_scroll_horizontal():
							_velocity.x -= speed * event.factor
					else:
						if _should_scroll_vertical():
							_velocity.y -= speed * event.factor
			MOUSE_BUTTON_WHEEL_LEFT:
				if event.pressed:
					if !event.shift_pressed:
						if _should_scroll_horizontal():
							_velocity.x += speed * event.factor
					else:
						if _should_scroll_vertical():
							_velocity.y += speed * event.factor
			MOUSE_BUTTON_WHEEL_RIGHT:
				if event.pressed:
					if !event.shift_pressed:
						if _should_scroll_horizontal():
							_velocity.x -= speed * event.factor
					else:
						if _should_scroll_vertical():
							_velocity.y -= speed * event.factor
	get_tree().get_root().set_input_as_handled()


func _process(delta:float) -> void:
	if !content_node: return
	if Engine.is_editor_hint(): return
	_scroll(delta)


# 是否能够水平滚动
func _should_scroll_horizontal() -> bool:
	var disable_scroll = auto_lock_h and \
		(get_global_rect().size.x >= content_node.get_global_rect().size.x)
	if disable_scroll:
		_velocity.x = 0.0
		return false
	else:
		return true


# 是否能够垂直滚动
func _should_scroll_vertical() -> bool:
	var disable_scroll = auto_lock_v and \
		(get_global_rect().size.y >= content_node.get_global_rect().size.y)
	if disable_scroll:
		_velocity.y = 0.0
		return false
	else:
		return true


func _scroll(delta:float) -> void:
	if !content_node: return
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
	# 伪造 content_node 的尺寸以避免其尺寸小于容器时的错误
	# Falsify the size of the content_node to avoid errors 
	# when the size is smaller than this container
	var content_node_size = Vector2(
		max(content_node.get_global_rect().size.x, get_global_rect().size.x),
		max(content_node.get_global_rect().size.y, get_global_rect().size.y)
	)
	# 计算该容器与 content_node 的尺寸差距
	# Calculate the size difference between this container and content_node
	var content_node_size_diff = Vector2(
		content_node_size.x - get_global_rect().size.x,
		content_node_size.y - get_global_rect().size.y
	)
	# 计算 content_node 到左、右、上、下边界的距离
	# Calculate distance to left, right, top and bottom
	var content_node_boundary_dist = Vector4(
		_get_content_node_position().x,
		_get_content_node_position().x + content_node_size_diff.x,
		_get_content_node_position().y,
		_get_content_node_position().y + content_node_size_diff.y
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
			_velocity.x -= bounce_strength * abs(content_node_boundary_dist.x) * delta
			if _velocity.x <= target_vel.x:
				_velocity.x = target_vel.x
	if _get_content_node_position().x < -content_node_size_diff.x:
		if _velocity.x < target_vel.y:
			_velocity.x += bounce_strength * abs(content_node_boundary_dist.y) * delta
			if _velocity.x >= target_vel.y:
				_velocity.x = target_vel.y
	if _get_content_node_position().y > 0.0:
		if _velocity.y > target_vel.z:
			_velocity.y -= bounce_strength * abs(content_node_boundary_dist.z) * delta
			if _velocity.y <= target_vel.z:
				_velocity.y = target_vel.z
	if _get_content_node_position().y < -content_node_size_diff.y:
		if _velocity.y < target_vel.w:
			_velocity.y += bounce_strength * abs(content_node_boundary_dist.w) * delta
			if _velocity.y >= target_vel.w:
				_velocity.y = target_vel.w


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
	#fake_position.x = min(fake_position.x, node.position.x)
	#fake_position.y = min(fake_position.y, node.position.y) 
	return fake_position


# 根据 content_node 的 size_flag 伪造一个 position setter
# Falsify a position setter based on content_node 's size_flag
func _set_content_node_position(new_position:Vector2) -> void:
	_fit_child_position(content_node, new_position, true)


# 设置子节点位置
func _fit_child_position(node:Control, new_position:Vector2, keep_offset:bool=false) -> void:
	prints(node)
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


func _calculate_velocity_by_time(time:float) -> float:
	if time <= 0.0: return 0.0
	return time*time*time * friction


func _calculate_time_by_velocity(velocity:float) -> float:
	return pow(abs(velocity) / friction, 1.0/3.0)


func _calculate_offset_by_time(time:float) -> float:
	time = max(time, 0.0)
	return 1.0/4.0 * friction * time*time*time*time


func _calculate_time_by_offset(offset:float) -> float:
	return pow(offset * 4.0 / friction, 1.0/4.0)


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
	# 连接信号
	# Connect signals
	if node and node is Control:
		if exit_tree:
			# @Note 设置位置时无故触发，暂时禁用，需要查明原因或绕过
			# @Note This signal will be emitted when setting position for no reason, 
			# banned temporarily, need investigation or another solution
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
	print(get_children().size())
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

