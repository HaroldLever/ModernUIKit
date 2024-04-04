extends Resource
class_name VelocityHelper

## 抽象类
## Abstract class

## 吸引力度。数值越大，吸引越快。[br]
## Attracting strength. The higher the value, the faster it attracts. 
@export_range(0.001, 100000.0, 0.001, "or_greater", "hide_slider")
var attracting_strength := 400.0:
	set(val): attracting_strength= max(val, 0.001)


# 抽象方法，用时间求速度
# Abstract methods
func _calculate_velocity_by_time(time:float) -> float:
	return 0.0

# 抽象方法，用速度求时间
# Abstract methods
func _calculate_time_by_velocity(velocity:float) -> float:
	return 0.0

# 抽象方法
# Abstract methods
# 用位移求时间
func _calculate_offset_by_time(time:float) -> float:
	return 0.0

# 抽象方法
# Abstract methods
# 用时间求位移
func _calculate_time_by_offset(offset:float) -> float:
	return 0.0


# 计算到达目的地所需的速度
func _calculate_velocity_to_dest(from:float, to:float) -> float:
	var dist = to - from
	var time = _calculate_time_by_offset(abs(dist))
	var vel = _calculate_velocity_by_time(time) * sign(dist)
	return vel


# 计算下一帧的速度
func _calculate_next_velocity(present_time:float, delta_time:float) -> float:
	return _calculate_velocity_by_time(present_time - delta_time)


# 计算下一帧的位移
func _calculate_next_offset(present_time:float, delta_time:float) -> float:
	return _calculate_offset_by_time(present_time) \
		 - _calculate_offset_by_time(present_time - delta_time)


## 滑动
func slide(velocity:float, delta_time:float) -> Array:
	var present_time = _calculate_time_by_velocity(velocity)
	var offset = _calculate_offset_by_time(present_time)
	return [
		_calculate_next_velocity(present_time, delta_time),
		_calculate_next_offset(present_time, delta_time)
	]


## 吸引
func attract(from:float, to:float, velocity:float, delta_time:float) -> float:
	var dist = to - from
	var target_vel = _calculate_velocity_to_dest(from, to)
	velocity += attracting_strength * dist * delta_time
	if (
		(dist > 0 and velocity >= target_vel) \
		or (dist < 0 and velocity <= target_vel) \
	):
		velocity = target_vel
	return velocity

