
extends Node

var mage_controller: Node
var knight_controller: Node

var _interaction_consumed_frame: Dictionary = {
	1: -1,
	2: -1
}

var _previous_controller_buttons: Dictionary = {}


func _ready() -> void:
	mage_controller = get_node_or_null("/root/ArduinoMage")
	knight_controller = get_node_or_null("/root/ArduinoKnight")

	if mage_controller == null:
		push_warning("PlayerInput: ArduinoMage Autoload was not found.")

	if knight_controller == null:
		push_warning("PlayerInput: ArduinoKnight Autoload was not found.")


# --------------------------------------------------
# INTERNAL HELPERS
# --------------------------------------------------

func _has_action(action: StringName) -> bool:
	return InputMap.has_action(action)


func _action_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_pressed(action)


func _action_just_pressed(action: StringName) -> bool:
	return _has_action(action) and Input.is_action_just_pressed(action)


func _controller_value(controller: Node, property: StringName, fallback = null):
	if controller == null:
		return fallback

	var value = controller.get(property)
	return fallback if value == null else value


func _controller_button_just_pressed(
	player_id: int,
	button_name: StringName,
	currently_pressed: bool
) -> bool:
	var key := "%d_%s" % [player_id, button_name]
	var was_pressed: bool = _previous_controller_buttons.get(key, false)

	_previous_controller_buttons[key] = currently_pressed

	return currently_pressed and not was_pressed


func _keyboard_vector(
	left_action: StringName,
	right_action: StringName,
	forward_action: StringName,
	backward_action: StringName
) -> Vector2:
	return Input.get_vector(
		left_action,
		right_action,
		forward_action,
		backward_action
	)


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func get_move(player_id: int) -> Vector2:
	var keyboard := Vector2.ZERO
	var controller_move := Vector2.ZERO

	if player_id == 1:
		keyboard = _keyboard_vector(
			&"move_left",
			&"move_right",
			&"move_forward",
			&"move_backward"
		)

		if mage_controller != null:
			controller_move = Vector2(
				float(_controller_value(mage_controller, &"joystick_x", 0.0)),
				float(_controller_value(mage_controller, &"joystick_y", 0.0))
			)

	elif player_id == 2:
		keyboard = _keyboard_vector(
			&"p2_left",
			&"p2_right",
			&"p2_forward",
			&"p2_backward"
		)

		if knight_controller != null and knight_controller.has_method("get_movement"):
			controller_move = knight_controller.get_movement()
	else:
		push_warning("PlayerInput: Invalid player ID: %d" % player_id)
		return Vector2.ZERO

	var combined := keyboard + controller_move

	if combined.length() > 1.0:
		combined = combined.normalized()

	return combined


# --------------------------------------------------
# CAMERA LOOK
# --------------------------------------------------


func get_look(player_id: int) -> Vector2:
	if player_id == 1:
		# Mage: read the right analog stick from ArduinoMage.
		if mage_controller != null:
			if mage_controller.has_method("get_look"):
				return mage_controller.get_look()

			return Vector2(
				float(_controller_value(mage_controller, &"camera_x", 0.0)),
				float(_controller_value(mage_controller, &"camera_y", 0.0))
			)

		return Vector2.ZERO

	elif player_id == 2:
		# Knight: preserve existing keyboard and controller look controls.
		var keyboard_look := Vector2(
			float(_action_pressed(&"p2_look_right"))
				- float(_action_pressed(&"p2_look_left")),
			float(_action_pressed(&"p2_look_down"))
				- float(_action_pressed(&"p2_look_up"))
		)

		var controller_look := Vector2.ZERO

		if knight_controller != null:
			if knight_controller.has_method("get_look"):
				controller_look = knight_controller.get_look()

		return keyboard_look + controller_look

	return Vector2.ZERO



# --------------------------------------------------
# JUMP
# --------------------------------------------------

func is_jump_just_pressed(player_id: int) -> bool:
	if player_id == 1:
		var keyboard := _action_just_pressed(&"jump")
		var controller := bool(
			_controller_value(mage_controller, &"jump_pressed", false)
		)

		return keyboard or _controller_button_just_pressed(
			1, &"jump", controller
		)

	elif player_id == 2:
		var keyboard := _action_just_pressed(&"p2_jump")
		var controller := bool(
			_controller_value(knight_controller, &"jump_pressed", false)
		)

		return keyboard or _controller_button_just_pressed(
			2, &"jump", controller
		)

	return false


# --------------------------------------------------
# RUN / SPRINT
# --------------------------------------------------

func is_sprint_held(player_id: int) -> bool:
	if player_id == 1:
		return _action_pressed(&"run") or bool(
			_controller_value(mage_controller, &"sprint_pressed", false)
		)

	elif player_id == 2:
		return _action_pressed(&"p2_run") or bool(
			_controller_value(knight_controller, &"sprint", false)
		)

	return false


# --------------------------------------------------
# ATTACK
# --------------------------------------------------

func is_attack_just_pressed(player_id: int) -> bool:
	if player_id == 2:
		var keyboard := _action_just_pressed(&"p2_attack")
		var controller := bool(
			_controller_value(knight_controller, &"attack_pressed", false)
		)

		return keyboard or _controller_button_just_pressed(
			2, &"attack", controller
		)

	return false


# --------------------------------------------------
# SHIELD
# --------------------------------------------------

func is_shield_held(player_id: int) -> bool:
	if player_id == 2:
		return _action_pressed(&"p2_shield") or bool(
			_controller_value(knight_controller, &"shield", false)
		)

	return false


# --------------------------------------------------
# DODGE
# --------------------------------------------------

func is_dodge_just_pressed(player_id: int) -> bool:
	if player_id == 2:
		var keyboard := _action_just_pressed(&"p2_dodge")
		var controller := bool(
			_controller_value(knight_controller, &"dodge_pressed", false)
		)

		return keyboard or _controller_button_just_pressed(
			2, &"dodge", controller
		)

	return false


# --------------------------------------------------
# INTERACTION
# --------------------------------------------------

func consume_interaction(player_id: int) -> bool:
	var frame := Engine.get_process_frames()

	if int(_interaction_consumed_frame.get(player_id, -1)) == frame:
		return false

	var keyboard := false
	var controller := false

	if player_id == 1:
		keyboard = _action_just_pressed(&"mage_interact")

		if mage_controller != null:
			if mage_controller.has_method("consume_interaction"):
				controller = mage_controller.consume_interaction()
			else:
				controller = bool(
					_controller_value(
						mage_controller,
						&"interact_pressed",
						false
					)
				)

				if controller:
					mage_controller.set("interact_pressed", false)

	elif player_id == 2:
		keyboard = _action_just_pressed(&"p2_interact")

		if knight_controller != null:
			if knight_controller.has_method("consume_interaction"):
				controller = knight_controller.consume_interaction()
			else:
				controller = bool(
					_controller_value(
						knight_controller,
						&"interact_pressed",
						false
					)
				)

				if controller:
					knight_controller.set("interact_pressed", false)
	else:
		return false

	if keyboard or controller:
		_interaction_consumed_frame[player_id] = frame
		return true

	return false


# --------------------------------------------------
# MAGE SPELL INPUT
# --------------------------------------------------

func is_spell_cast_just_pressed() -> bool:
	return _action_just_pressed(&"mage_cast_spell")


func is_previous_spell_just_pressed() -> bool:
	return _action_just_pressed(&"mage_spell_previous")


func is_next_spell_just_pressed() -> bool:
	return _action_just_pressed(&"mage_spell_next")


func get_spell_charge() -> float:
	return float(_controller_value(mage_controller, &"slider", 0.0))


func get_selected_spell():
	return _controller_value(mage_controller, &"selected_spell", null)


# --------------------------------------------------
# PAUSE
# --------------------------------------------------

func is_pause_just_pressed() -> bool:
	return _action_just_pressed(&"pause")
