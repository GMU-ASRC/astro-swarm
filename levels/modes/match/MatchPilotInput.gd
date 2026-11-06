extends RefCounted

const STICK_DEADZONE := 0.2

func read() -> Vector2:
	var thrust: float = 0.0
	var turn: float = 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		thrust += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		thrust -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		turn -= 1.0
	var pads: Array = Input.get_connected_joypads()
	if not pads.is_empty():
		var pad: int = pads[0]
		var stick_x: float = Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var stick_y: float = Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		if absf(stick_x) > STICK_DEADZONE:
			turn += stick_x
		if absf(stick_y) > STICK_DEADZONE:
			thrust -= stick_y
		thrust += Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
	return Vector2(clampf(thrust, -1.0, 1.0), clampf(turn, -1.0, 1.0))
