
extends Area3D

@export var gear_name: String = "Fire_Gear"
@export var gear_rotation_speed: float = 1.5
@export var joystick_dead_zone: float = 0.2

@export_range(-359.0, 359.0, 1.0)
var target_angle_degrees: float = -90.0

@export_range(1.0, 20.0, 1.0)
var alignment_tolerance_degrees: float = 5.0

@onready var stand_position: Marker3D = $KnightStandPosition

var knight_in_range: bool = false
var operating: bool = false
var gear_aligned: bool = false

var knight: CharacterBody3D = null
var fire_gear: Node3D = null
var fire_station: Node = null
var puzzle_controller: Node = null

var starting_gear_angle: float = 0.0
var previous_keyboard_state: bool = false
var previous_controller_state: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		push_error("Fire Gear: Current scene was not found.")
		return

	fire_gear = current_scene.find_child(
		gear_name, true, false
	) as Node3D

	if fire_gear == null:
		push_warning("Fire Gear: Could not find " + gear_name)
	else:
		starting_gear_angle = fire_gear.rotation.z

	fire_station = current_scene.find_child(
		"FireInteraction", true, false
	)

	if fire_station == null:
		push_warning("Fire Gear: Could not find FireInteraction.")

	puzzle_controller = current_scene.find_child(
		"PuzzleController", true, false
	)

	if puzzle_controller == null:
		push_warning("Fire Gear: Could not find PuzzleController.")

	print("Fire Gear: Interaction ready.")


func _process(delta: float) -> void:
	var keyboard_down: bool = Input.is_key_pressed(KEY_E)
	var keyboard_pressed: bool = (
		keyboard_down and not previous_keyboard_state
	)
	previous_keyboard_state = keyboard_down

	var controller_down: bool = false

	if is_instance_valid(ArduinoKnight):
		controller_down = ArduinoKnight.interact_pressed

	var controller_pressed: bool = (
		controller_down and not previous_controller_state
	)
	previous_controller_state = controller_down

	if controller_pressed:
		ArduinoKnight.interact_pressed = false

	var interact_requested: bool = (
		keyboard_pressed or controller_pressed
	)

	if operating:
		if not is_instance_valid(knight):
			operating = false
			return

		if interact_requested:
			exit_gear_mode()
		else:
			control_gear(delta)

		return

	if not interact_requested or not knight_in_range:
		return

	if not is_instance_valid(knight):
		return

	if knight.is_dead:
		return

	if gear_aligned:
		print("Fire Gear: Already aligned.")
		return

	if not is_instance_valid(fire_gear):
		push_warning("Fire Gear: Gear node is missing.")
		return

	if not is_fire_lit():
		print("Fire Gear: The furnace is still cold.")
		return

	enter_gear_mode()


func is_fire_lit() -> bool:
	if not is_instance_valid(fire_station):
		return false

	return fire_station.get("fire_started") == true


func enter_gear_mode() -> void:
	if operating or not is_instance_valid(knight):
		return

	if not is_instance_valid(stand_position):
		push_warning("Fire Gear: KnightStandPosition is missing.")
		return

	operating = true

	# Move and face the Knight toward the gear.
	knight.global_position = stand_position.global_position
	knight.global_rotation.y = stand_position.global_rotation.y
	knight.velocity = Vector3.ZERO

	# Explicitly start the Knight's operating mode.
	if knight.has_method("start_fire_gear_mode"):
		knight.call("start_fire_gear_mode")
	else:
		operating = false
		push_warning("Fire Gear: Knight has no start_fire_gear_mode().")
		return

	print("Fire Gear: Knight entered gear mode.")


func control_gear(delta: float) -> void:
	if not is_instance_valid(knight):
		exit_gear_mode()
		return

	if not is_fire_lit():
		print("Fire Gear: Operation stopped because the furnace is cold.")
		exit_gear_mode()
		return

	if not is_instance_valid(fire_gear) or gear_aligned:
		return

	var movement: Vector2 = Vector2.ZERO

	if is_instance_valid(ArduinoKnight):
		movement = ArduinoKnight.get_movement()

	if abs(movement.x) > joystick_dead_zone:
		fire_gear.rotate_object_local(
			Vector3(0.0, 0.0, 1.0),
			-movement.x * gear_rotation_speed * delta
		)

		check_gear_alignment()


func check_gear_alignment() -> void:
	if not is_instance_valid(fire_gear):
		return

	var current_relative_angle: float = wrapf(
		fire_gear.rotation.z - starting_gear_angle,
		-PI,
		PI
	)

	var target_angle: float = deg_to_rad(target_angle_degrees)

	var angle_remaining: float = wrapf(
		target_angle - current_relative_angle,
		-PI,
		PI
	)

	if abs(angle_remaining) <= deg_to_rad(
		alignment_tolerance_degrees
	):
		align_gear(angle_remaining)


func align_gear(angle_remaining: float) -> void:
	if not is_instance_valid(fire_gear):
		return

	fire_gear.rotate_object_local(
		Vector3(0.0, 0.0, 1.0),
		angle_remaining
	)

	gear_aligned = true

	print("Fire Gear: Correct angle reached.")

	if is_instance_valid(puzzle_controller):
		if puzzle_controller.has_method("complete_station"):
			puzzle_controller.call("complete_station", "fire")
		else:
			push_warning(
				"Fire Gear: PuzzleController lacks complete_station()."
			)

	exit_gear_mode()


func exit_gear_mode() -> void:
	if not operating:
		return

	operating = false

	if is_instance_valid(knight):
		if knight.has_method("stop_fire_gear_mode"):
			knight.call("stop_fire_gear_mode")

	print("Fire Gear: Knight exited gear mode.")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player2"):
		knight_in_range = true
		knight = body as CharacterBody3D
		print("Fire Gear: Knight detected in range.")


func _on_body_exited(body: Node3D) -> void:
	if body == knight:
		knight_in_range = false

		if operating:
			exit_gear_mode()

		knight = null
		print("Fire Gear: Knight left the interaction area.")
