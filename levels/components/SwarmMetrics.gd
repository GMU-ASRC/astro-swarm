extends RefCounted

static func center_of_mass(positions: Array) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for position in positions:
		total += position
	return total / float(positions.size())

static func is_merged(positions: Array, merge_distance: float) -> bool:
	if positions.size() < 2:
		return false
	var reached := {0: true}
	var frontier: Array = [0]
	while not frontier.is_empty():
		var index: int = frontier.pop_back()
		for other in positions.size():
			if reached.has(other):
				continue
			if positions[index].distance_to(positions[other]) <= merge_distance:
				reached[other] = true
				frontier.append(other)
	return reached.size() == positions.size()

static func circliness(positions: Array, headings: Array) -> float:
	if positions.size() < 2 or headings.size() != positions.size():
		return 0.0
	var center := center_of_mass(positions)
	var smallest_radius: float = INF
	var largest_radius: float = 0.0
	var motion_error: float = 0.0
	for index in positions.size():
		var offset: Vector2 = positions[index] - center
		var radius: float = offset.length()
		smallest_radius = minf(smallest_radius, radius)
		largest_radius = maxf(largest_radius, radius)
		motion_error += absf(cos(angle_difference(headings[index], offset.angle())))
	if largest_radius <= 0.001:
		return 0.0
	motion_error /= float(positions.size())
	var shape_error: float = 1.0 - (smallest_radius * smallest_radius) / (largest_radius * largest_radius)
	return clampf(1.0 - maxf(shape_error, motion_error), 0.0, 1.0)

static func loss(goal_distance: float, circliness_value: float) -> float:
	return goal_distance + 1.0 - circliness_value
