
extends CharacterBody3D

const WALK_SPEED: float = 2.0
const RUN_SPEED: float = 4.0
const JUMP_VELOCITY: float = 4.5

@export var mouse_sensitivity: float = 0.002
@export var joystick_camera_sensitivity: float = 2.0
@export var camera_dead_zone: float = 0.08
@export var look_up_down_limit: float = 0.4

@onready var camera_pivot: Node3D = $CameraPivot
@onready var animation_player: AnimationPlayer = $Mage/AnimationPlayer

var current_animation: String = ""
var is_jumping: bool = false
var is_landing: bool = false
var is_hit: bool = false
var is_dead: bool = false

var health: int = 100
var arduino: Variant = null

# Read by the aiming script to trigger the existing projectile system.
var keyboard_cast_requested: bool = false


func _ready() -> void:
	# Register Player 1 so the gate can find and revive the Mage.
	add_to_group("players")

	arduino = ArduinoMage
	play_animation("Rig_Medium_General/Idle_A")


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused:
		return

	if event.is_action_pressed("mage_spell_previous"):
		_cycle_spell(-1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("mage_spell_next"):
		_cycle_spell(1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("mage_cast_spell"):
		keyboard_cast_requested = true
		get_viewport().set_input_as_handled()


func _cycle_spell(direction: int) -> void:
	if not is_instance_valid(arduino):
		return

	var spells_value: Variant = arduino.get("spells")

	if not spells_value is Array:
		push_warning("ArduinoMage has no valid spells array.")
		return

	var spells: Array = spells_value

	if spells.is_empty():
		return

	var selected_spell: int = int(arduino.get("selected_spell"))

	selected_spell = posmod(
		selected_spell + direction,
		spells.size()
	)

	arduino.set("selected_spell", selected_spell)

	print("Mage selected spell: ", spells[selected_spell])


func play_animation(animation_name: String) -> void:
	if current_animation != animation_name:
		animation_player.play(animation_name)
		current_animation = animation_name


func _input(event: InputEvent) -> void:
	# Escape and pausing are handled by the existing pause system.
	if is_dead or get_tree().paused:
		return

	# Mouse camera control.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)

			camera_pivot.rotate_x(
				event.relative.y * mouse_sensitivity
			)

			camera_pivot.rotation.x = clampf(
				camera_pivot.rotation.x,
				-look_up_down_limit,
				look_up_down_limit
			)

	# Capture the mouse when clicking in the game.
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	# Gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Dead players cannot move.
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Hit animation state.
	if is_hit:
		if (
			animation_player.current_animation_position
			>= animation_player.current_animation_length
		):
			is_hit = false

	# --------------------------------------------------
	# ARDUINO CAMERA
	# --------------------------------------------------
	if is_instance_valid(arduino):
		var camera_x: float = float(arduino.camera_x)
		var camera_y: float = float(arduino.camera_y)

		if absf(camera_x) < camera_dead_zone:
			camera_x = 0.0

		if absf(camera_y) < camera_dead_zone:
			camera_y = 0.0

		rotate_y(
			-camera_x * joystick_camera_sensitivity * delta
		)

		camera_pivot.rotate_x(
			camera_y * joystick_camera_sensitivity * delta
		)

		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			-look_up_down_limit,
			look_up_down_limit
		)

	# --------------------------------------------------
	# MOVEMENT: KEYBOARD + ARDUINO
	# --------------------------------------------------
	var direction: Vector3 = Vector3.ZERO
	var joystick_x: float = 0.0
	var joystick_y: float = 0.0

	if is_instance_valid(arduino):
		joystick_x = float(arduino.joystick_x)
		joystick_y = float(arduino.joystick_y)

	# Preserve the original Arduino movement mapping.
	direction.x = -joystick_x
	direction.z = -joystick_y

	# Keyboard actions come from Project Settings > Input Map.
	if Input.is_action_pressed("move_forward"):
		direction.z += 1.0

	if Input.is_action_pressed("move_backward"):
		direction.z -= 1.0

	if Input.is_action_pressed("move_left"):
		direction.x += 1.0

	if Input.is_action_pressed("move_right"):
		direction.x -= 1.0

	var local_direction: Vector3 = direction

	if direction.length() > 1.0:
		direction = direction.normalized()

	if direction.length() > 0.0:
		direction = transform.basis * direction
		direction.y = 0.0
		direction = direction.normalized()

	# --------------------------------------------------
	# JUMP: KEYBOARD + ARDUINO
	# --------------------------------------------------
	var jump_requested: bool = Input.is_action_just_pressed("jump")

	if is_instance_valid(arduino) and arduino.jump_pressed:
		jump_requested = true
		arduino.jump_pressed = false

	if (
		jump_requested
		and is_on_floor()
		and not is_landing
		and not is_hit
	):
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		play_animation("Rig_Medium_MovementBasic/Jump_Start")

	# --------------------------------------------------
	# SPRINT: KEYBOARD + ARDUINO
	# --------------------------------------------------
	var should_run: bool = Input.is_action_pressed("run")

	if is_instance_valid(arduino) and arduino.sprint_pressed:
		should_run = true

	# --------------------------------------------------
	# MOVEMENT SPEED + ANIMATIONS
	# --------------------------------------------------
	if direction.length() > 0.0:
		if should_run:
			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED

			if not is_jumping and not is_landing and not is_hit:
				play_animation(
					"Rig_Medium_MovementBasic/Running_A"
				)
		else:
			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED

			if not is_jumping and not is_landing and not is_hit:
				if local_direction.z > 0.15:
					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)
				elif local_direction.z < -0.15:
					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)
				else:
					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

		if not is_jumping and not is_landing and not is_hit:
			play_animation("Rig_Medium_General/Idle_A")

	move_and_slide()

	# --------------------------------------------------
	# LANDING
	# --------------------------------------------------
	if is_jumping and is_on_floor():
		is_jumping = false
		is_landing = true
		play_animation("Rig_Medium_MovementBasic/Jump_Land")

	if is_landing:
		var landing_length: float = (
			animation_player.current_animation_length
		)
		var landing_position: float = (
			animation_player.current_animation_position
		)

		if landing_position < landing_length - 0.35:
			return

		is_landing = false

		if direction.length() > 0.0:
			if should_run:
				play_animation(
					"Rig_Medium_MovementBasic/Running_A"
				)
			elif local_direction.z > 0.15:
				play_animation(
					"Rig_Medium_MovementBasic/Walking_C"
				)
			elif local_direction.z < -0.15:
				play_animation(
					"Rig_Medium_MovementAdvanced/Walking_Backwards"
				)
			else:
				play_animation(
					"Rig_Medium_MovementBasic/Walking_C"
				)
		else:
			play_animation("Rig_Medium_General/Idle_A")


# --------------------------------------------------
# HEALTH / DAMAGE
# --------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(0, health - amount)
	print("Player 1 health: ", health)

	if health <= 0:
		is_dead = true
		is_hit = false
		is_jumping = false
		is_landing = false
		keyboard_cast_requested = false
		velocity = Vector3.ZERO

		animation_player.stop()
		current_animation = ""
		animation_player.play("Rig_Medium_General/Death_B")
		current_animation = "Rig_Medium_General/Death_B"

		print("Player 1 defeated! Waiting for revival.")
		return

	is_hit = true
	play_animation("Rig_Medium_General/Hit_A")


# --------------------------------------------------
# REVIVE
# Called by the room-clear system when the partner
# clears the room.
# --------------------------------------------------
func revive(spawn_position: Vector3) -> void:
	if not is_dead:
		return

	global_position = spawn_position
	velocity = Vector3.ZERO
	health = 100

	is_dead = false
	is_hit = false
	is_jumping = false
	is_landing = false
	keyboard_cast_requested = false

	animation_player.stop()
	current_animation = ""
	play_animation("Rig_Medium_General/Idle_A")

	print("Player 1 revived with ", health, " health!")
