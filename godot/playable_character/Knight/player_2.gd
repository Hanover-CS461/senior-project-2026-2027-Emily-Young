
extends CharacterBody3D

const WALK_SPEED: float = 2.0
const RUN_SPEED: float = 4.0
const JUMP_VELOCITY: float = 4.5
const CAMERA_SENSITIVITY: float = 2.0
const VERTICAL_CAMERA_SENSITIVITY: float = 1.0

const DODGE_SPEED: float = 7.0
const DODGE_DURATION: float = 0.22
const DODGE_COOLDOWN: float = 0.8
const DODGE_RECOVERY: float = 0.12

const LEVER_PULL_ANIMATION: String = "Rig_Medium_Tools/Fishing_Struggling"
const LEVER_PULL_ANGLE: float = 120.0
const LEVER_ROTATION_AXIS: Vector3 = Vector3.BACK
const LEVER_ROTATION_DIRECTION: float = 1.0
const LEVER_MOVEMENT_SPEED: float = 70.0
const LEVER_JOYSTICK_DEADZONE: float = 0.15

const FIRE_GEAR_ANIMATION: String = "Rig_Medium_Tools/Lockpicking"

const SHIELD_BLOCK_ANIMATION: String = "Rig_Medium_CombatMelee/Melee_Block"
const SHIELD_HOLD_ANIMATION: String = "Rig_Medium_CombatMelee/Melee_Blocking"
const SHIELD_ATTACK_ANIMATION: String = "Rig_Medium_CombatMelee/Melee_Block_Attack"
const SHIELD_HIT_ANIMATION: String = "Rig_Medium_CombatMelee/Melee_Block_Hit"

const NORMAL_ATTACK_ANIMATION: String = "Rig_Medium_CombatMelee/Melee_Unarmed_Attack_Punch_A"

@onready var animation_player: AnimationPlayer = $Knight/AnimationPlayer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var arduino_knight = ArduinoKnight

var current_animation: String = ""

var is_jumping: bool = false
var is_landing: bool = false
var is_hit: bool = false
var is_dead: bool = false
var health: int = 100

var attack_damage: int = 20
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var is_attacking: bool = false
var attack_range: float = 1.5

var is_shielding: bool = false
var shield_starting: bool = false
var is_blocking_hit: bool = false

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_recovery_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

# Fire Gear
var near_fire_gear: bool = false
var is_operating_fire_gear: bool = false

# Ice Shrine
var water_inlet_interaction: Area3D = null
var lever_interaction: Area3D = null
var ice_shrine: Node = null
var channel_inlet: Node3D = null
var ice_lever_handle: Node3D = null

# Lever
var is_pulling_lever: bool = false
var lever_start_basis: Basis = Basis.IDENTITY
var lever_current_angle: float = 0.0


func _ready() -> void:
	play_animation("Rig_Medium_General/Idle_A")
	print("Knight: Waiting for the dungeon and Ice Shrine.")

	await get_tree().process_frame

	while is_inside_tree():
		if (
			not is_instance_valid(water_inlet_interaction)
			or not is_instance_valid(lever_interaction)
		):
			find_ice_shrine()

		if (
			is_instance_valid(water_inlet_interaction)
			and is_instance_valid(lever_interaction)
		):
			break

		await get_tree().create_timer(0.5, true, false, true).timeout


# ==========================================
# COMBINED KEYBOARD + ARDUINO INPUT
# ==========================================

func get_combined_movement() -> Vector2:
	var keyboard: Vector2 = Input.get_vector(
		"p2_left",
		"p2_right",
		"p2_forward",
		"p2_backward"
	)

	var controller: Vector2 = Vector2.ZERO

	if is_instance_valid(arduino_knight):
		controller = arduino_knight.get_movement()

	var combined: Vector2 = keyboard + controller

	if combined.length() > 1.0:
		combined = combined.normalized()

	return combined


func get_combined_look() -> Vector2:
	var keyboard_look: Vector2 = Vector2(
		float(Input.is_action_pressed("p2_look_right"))
			- float(Input.is_action_pressed("p2_look_left")),
		float(Input.is_action_pressed("p2_look_down"))
			- float(Input.is_action_pressed("p2_look_up"))
	)

	var controller_look: Vector2 = Vector2.ZERO

	if is_instance_valid(arduino_knight):
		controller_look = arduino_knight.get_look()

	var combined: Vector2 = keyboard_look + controller_look

	if combined.length() > 1.0:
		combined = combined.normalized()

	return combined


func is_sprinting() -> bool:
	var keyboard_sprint: bool = Input.is_action_pressed("p2_run")
	var controller_sprint: bool = false

	if is_instance_valid(arduino_knight):
		controller_sprint = arduino_knight.sprint

	return keyboard_sprint or controller_sprint


func is_shield_held() -> bool:
	var keyboard_shield: bool = Input.is_action_pressed("p2_shield")
	var controller_shield: bool = false

	if is_instance_valid(arduino_knight):
		controller_shield = arduino_knight.shield

	return keyboard_shield or controller_shield


func is_dodge_requested() -> bool:
	var keyboard_dodge: bool = Input.is_action_just_pressed("p2_dodge")
	var controller_dodge: bool = false

	if is_instance_valid(arduino_knight):
		controller_dodge = arduino_knight.dodge_pressed

	if controller_dodge:
		arduino_knight.dodge_pressed = false

	return keyboard_dodge or controller_dodge


# ==========================================
# FIND ICE SHRINE
# ==========================================

func find_ice_shrine() -> void:
	var root: Node = get_tree().root

	var found_node: Node = root.find_child(
		"WaterInletInteraction", true, false
	)

	if found_node == null:
		found_node = root.find_child(
			"IceShrineInteraction", true, false
		)

	if found_node == null:
		return

	if not found_node is Area3D:
		push_warning("Knight: Water inlet interaction is not an Area3D.")
		return

	water_inlet_interaction = found_node as Area3D
	ice_shrine = water_inlet_interaction

	var shrine_parent: Node = water_inlet_interaction.get_parent()
	if shrine_parent == null:
		return

	var lever_node: Node = shrine_parent.find_child(
		"LeverInteraction", true, false
	)

	if lever_node == null:
		push_warning("Knight: Could not find LeverInteraction.")
		return

	if not lever_node is Area3D:
		push_warning("Knight: LeverInteraction is not an Area3D.")
		return

	lever_interaction = lever_node as Area3D

	water_inlet_interaction.monitoring = true
	lever_interaction.monitoring = true

	for layer: int in range(1, 33):
		water_inlet_interaction.set_collision_mask_value(layer, true)
		lever_interaction.set_collision_mask_value(layer, true)

	var puzzle_room: Node = shrine_parent

	while puzzle_room != null:
		if puzzle_room.name in ["PuzzleRoom", "PuzzleRoom1"]:
			break
		puzzle_room = puzzle_room.get_parent()

	if puzzle_room == null:
		puzzle_room = shrine_parent

	channel_inlet = puzzle_room.find_child(
		"Channel_Inlet", true, false
	) as Node3D

	ice_lever_handle = puzzle_room.find_child(
		"Ice_Lever_Handle", true, false
	) as Node3D

	if is_instance_valid(ice_lever_handle):
		print("Knight: Ice lever handle found.")
	else:
		push_warning("Knight: Could not find Ice_Lever_Handle.")

	print("Knight: Ice Shrine found.")
	print("Knight: Water inlet interaction ready.")
	print("Knight: Lever interaction ready.")


# ==========================================
# INTERACTION INPUT
# ==========================================

func interaction_just_pressed() -> bool:
	var keyboard_pressed: bool = Input.is_action_just_pressed(
		"p2_interact"
	)

	if not is_instance_valid(arduino_knight):
		return keyboard_pressed

	if arduino_knight.has_method("consume_interaction"):
		if arduino_knight.consume_interaction():
			return true
	elif arduino_knight.interact_pressed:
		arduino_knight.interact_pressed = false
		return true

	return keyboard_pressed


func handle_interaction() -> void:
	print("Knight: Player 2 interaction detected!")

	if (
		not is_instance_valid(water_inlet_interaction)
		or not is_instance_valid(lever_interaction)
		or not is_instance_valid(ice_shrine)
	):
		find_ice_shrine()

	if (
		not is_instance_valid(water_inlet_interaction)
		or not is_instance_valid(lever_interaction)
		or not is_instance_valid(ice_shrine)
	):
		print("Knight: Ice Shrine interaction areas are not ready.")
		return

	var inside_water_area: bool = (
		water_inlet_interaction.monitoring
		and water_inlet_interaction.get_overlapping_bodies().has(self)
	)

	var inside_lever_area: bool = (
		lever_interaction.monitoring
		and lever_interaction.get_overlapping_bodies().has(self)
	)

	if inside_water_area:
		if bool(ice_shrine.get("shrine_completed")):
			print("Knight: The Ice Shrine is already complete!")
			return

		if not ice_shrine.has_method("start_water"):
			push_error("Knight: Ice Shrine is missing start_water().")
			return

		if not bool(ice_shrine.get("water_started")):
			ice_shrine.call("start_water")
		else:
			print("Knight: The water is already flowing.")
			print("Knight: The Mage must freeze it before using the lever.")
		return

	if inside_lever_area:
		if bool(ice_shrine.get("shrine_completed")):
			print("Knight: The Ice Shrine is already complete!")
			return

		if not bool(ice_shrine.get("water_started")):
			print("Knight: Start the water at the water inlet first!")
			return

		if not bool(ice_shrine.get("channel_frozen")):
			print("Knight: The Mage must freeze the flowing water first!")
			return

		if not bool(ice_shrine.get("lever_enabled")):
			print("Knight: The Ice Shrine lever is still locked.")
			return

		if not ice_shrine.has_method("pull_lever"):
			push_error("Knight: Ice Shrine is missing pull_lever().")
			return

		start_lever_pull()
		return

	print("Knight: No Ice Shrine interaction at this position.")


# ==========================================
# ICE LEVER
# ==========================================

func start_lever_pull() -> void:
	if is_pulling_lever:
		return

	if not is_instance_valid(ice_lever_handle):
		push_warning("Knight: Cannot pull lever; handle was not found.")
		return

	is_pulling_lever = true
	velocity = Vector3.ZERO
	lever_current_angle = 0.0

	is_jumping = false
	is_landing = false
	is_attacking = false
	is_shielding = false
	shield_starting = false
	is_blocking_hit = false
	is_hit = false
	is_dodging = false
	dodge_timer = 0.0
	dodge_recovery_timer = 0.0

	lever_start_basis = ice_lever_handle.transform.basis

	if animation_player.has_animation(LEVER_PULL_ANIMATION):
		animation_player.play(LEVER_PULL_ANIMATION)
		current_animation = LEVER_PULL_ANIMATION
	else:
		push_warning("Knight: Lever-pulling animation was not found.")

	print("Knight: Use the movement joystick or arrow keys to operate the lever.")


func update_lever_pull(delta: float) -> void:
	hold_player_in_place(delta)

	if not is_instance_valid(ice_lever_handle):
		push_warning("Knight: Lever handle disappeared.")
		is_pulling_lever = false
		current_animation = ""
		return

	if (
		animation_player.has_animation(LEVER_PULL_ANIMATION)
		and animation_player.current_animation != LEVER_PULL_ANIMATION
	):
		animation_player.play(LEVER_PULL_ANIMATION)
		current_animation = LEVER_PULL_ANIMATION

	var joystick: Vector2 = get_combined_movement()

	if joystick.y < -LEVER_JOYSTICK_DEADZONE:
		lever_current_angle -= LEVER_MOVEMENT_SPEED * delta
	elif joystick.y > LEVER_JOYSTICK_DEADZONE:
		lever_current_angle += LEVER_MOVEMENT_SPEED * delta

	lever_current_angle = clampf(
		lever_current_angle, 0.0, LEVER_PULL_ANGLE
	)

	var axis: Vector3 = LEVER_ROTATION_AXIS.normalized()

	if axis.length_squared() > 0.0:
		ice_lever_handle.transform.basis = (
			lever_start_basis
			* Basis(
				axis,
				deg_to_rad(
					lever_current_angle * LEVER_ROTATION_DIRECTION
				)
			)
		)

	if lever_current_angle >= LEVER_PULL_ANGLE:
		finish_lever_pull()


func finish_lever_pull() -> void:
	if not is_pulling_lever:
		return

	lever_current_angle = LEVER_PULL_ANGLE

	if is_instance_valid(ice_lever_handle):
		var axis: Vector3 = LEVER_ROTATION_AXIS.normalized()

		if axis.length_squared() > 0.0:
			ice_lever_handle.transform.basis = (
				lever_start_basis
				* Basis(
					axis,
					deg_to_rad(
						LEVER_PULL_ANGLE * LEVER_ROTATION_DIRECTION
					)
				)
			)

	is_pulling_lever = false

	if (
		is_instance_valid(ice_shrine)
		and ice_shrine.has_method("pull_lever")
	):
		ice_shrine.call("pull_lever")
		print("Knight: Lever reached 120 degrees. Ice Shrine completed!")
	else:
		push_error("Knight: Could not complete the Ice Shrine.")

	current_animation = ""
	play_animation("Rig_Medium_General/Idle_A")


# ==========================================
# ANIMATION HELPER
# ==========================================

func play_animation(animation_name: String) -> void:
	if is_pulling_lever or is_operating_fire_gear:
		return

	if current_animation != animation_name:
		animation_player.play(animation_name)
		current_animation = animation_name


# ==========================================
# STATIONARY MODE
# ==========================================

func hold_player_in_place(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= get_gravity().length() * delta
	else:
		velocity.y = 0.0

	move_and_slide()


# ==========================================
# MAIN PHYSICS
# ==========================================

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var interaction_pressed: bool = interaction_just_pressed()

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()
		return

	if is_operating_fire_gear:
		hold_player_in_place(delta)

		if (
			animation_player.has_animation(FIRE_GEAR_ANIMATION)
			and animation_player.current_animation != FIRE_GEAR_ANIMATION
		):
			animation_player.play(FIRE_GEAR_ANIMATION)
			current_animation = FIRE_GEAR_ANIMATION

		return

	if is_pulling_lever:
		update_lever_pull(delta)
		return

	if interaction_pressed:
		handle_interaction()

		if is_operating_fire_gear:
			hold_player_in_place(delta)
			return

		if is_pulling_lever:
			update_lever_pull(delta)
			return

	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta

	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		move_and_slide()

		if dodge_timer <= 0.0:
			is_dodging = false
			dodge_recovery_timer = DODGE_RECOVERY
			velocity.x = 0.0
			velocity.z = 0.0

		return

	if dodge_recovery_timer > 0.0:
		dodge_recovery_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0

		if dodge_recovery_timer <= 0.0:
			dodge_recovery_timer = 0.0

		return

	# Check whether dodge is allowed BEFORE consuming the controller press.
	if (
		dodge_cooldown_timer <= 0.0
		and not is_jumping
		and not is_landing
		and not is_attacking
		and not is_shielding
		and not is_hit
		and is_dodge_requested()
	):
		start_dodge()
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	# Shield
	var shield_held: bool = is_shield_held()

	if (
		shield_held
		and not is_attacking
		and not is_jumping
		and not is_landing
		and not is_hit
	):
		if not is_shielding:
			is_shielding = true
			shield_starting = true
			is_blocking_hit = false
			play_animation(SHIELD_BLOCK_ANIMATION)

		elif is_blocking_hit:
			pass

		elif shield_starting:
			if animation_player.current_animation != SHIELD_BLOCK_ANIMATION:
				play_animation(SHIELD_BLOCK_ANIMATION)

			var block_length: float = animation_player.current_animation_length
			var block_position: float = animation_player.current_animation_position

			if (
				animation_player.current_animation == SHIELD_BLOCK_ANIMATION
				and block_position >= block_length - 0.05
			):
				shield_starting = false
				play_animation(SHIELD_HOLD_ANIMATION)

		elif animation_player.current_animation != SHIELD_HOLD_ANIMATION:
			play_animation(SHIELD_HOLD_ANIMATION)

	else:
		if not shield_held and is_shielding:
			is_shielding = false
			shield_starting = false
			is_blocking_hit = false

	# Shield hit animation
	if is_blocking_hit:
		if animation_player.current_animation != SHIELD_HIT_ANIMATION:
			is_blocking_hit = false

		elif (
			animation_player.current_animation_position
			>= animation_player.current_animation_length - 0.05
		):
			is_blocking_hit = false

			if shield_held and is_shielding:
				shield_starting = false
				play_animation(SHIELD_HOLD_ANIMATION)
			else:
				is_shielding = false
				shield_starting = false

	# Attack input
	var controller_attack: bool = false

	if is_instance_valid(arduino_knight):
		controller_attack = arduino_knight.attack_pressed

	if (
		(
			Input.is_action_just_pressed("p2_attack")
			or controller_attack
		)
		and attack_timer <= 0.0
		and not is_attacking
		and not is_hit
		and not is_blocking_hit
	):
		if is_instance_valid(arduino_knight):
			arduino_knight.attack_pressed = false

		attack()
		return

	# Attack animation and damage
	if is_attacking:
		var attack_length: float = animation_player.current_animation_length
		var attack_position: float = animation_player.current_animation_position

		if attack_position < attack_length:
			return

		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		var hit_enemy: bool = false

		for enemy: Node in enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy is Node3D:
				continue

			var enemy_node: Node3D = enemy as Node3D
			var distance: float = global_position.distance_to(
				enemy_node.global_position
			)

			if distance <= attack_range and enemy.has_method("take_damage"):
				enemy.call("take_damage", attack_damage)
				print("Knight hits enemy!")
				hit_enemy = true
				break

		if not hit_enemy:
			print("Knight missed!")

		is_attacking = false
		attack_timer = attack_cooldown

		if shield_held and is_shielding:
			shield_starting = false
			is_blocking_hit = false
			play_animation(SHIELD_HOLD_ANIMATION)
		else:
			play_animation("Rig_Medium_General/Idle_A")

		return

	# Camera: keyboard and Arduino
	var look: Vector2 = get_combined_look()

	if look.length() > 0.0:
		rotate_y(-look.x * CAMERA_SENSITIVITY * delta)

		camera_pivot.rotate_x(
			look.y * VERTICAL_CAMERA_SENSITIVITY * delta
		)

		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x, -0.4, 0.4
		)

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Movement: keyboard and Arduino
	var joystick: Vector2 = get_combined_movement()
	var direction: Vector3 = Vector3.ZERO

	if joystick.length() > 0.0:
		direction.x = -joystick.x
		direction.z = -joystick.y
		direction = direction.normalized()
		direction = transform.basis * direction
		direction.y = 0.0
		direction = direction.normalized()

	# Jump
	var jump_requested: bool = Input.is_action_just_pressed("p2_jump")

	if is_instance_valid(arduino_knight):
		if arduino_knight.jump_pressed:
			jump_requested = true
			arduino_knight.jump_pressed = false

	if (
		jump_requested
		and is_on_floor()
		and not is_landing
		and not is_shielding
		and not is_hit
	):
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		play_animation("Rig_Medium_MovementBasic/Jump_Start")

	# Movement speed and animations
	if direction.length() > 0.0:
		var sprinting: bool = is_sprinting()

		if sprinting:
			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED

			if (
				not is_jumping
				and not is_landing
				and not is_shielding
				and not is_hit
			):
				if joystick.y < -0.15:
					play_animation("Rig_Medium_MovementBasic/Running_B")
				else:
					play_animation("Rig_Medium_MovementAdvanced/Walking_Backwards")
		else:
			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED

			if (
				not is_jumping
				and not is_landing
				and not is_shielding
				and not is_hit
			):
				if joystick.y < -0.15:
					play_animation("Rig_Medium_MovementBasic/Walking_B")
				else:
					play_animation("Rig_Medium_MovementAdvanced/Walking_Backwards")
	else:
		velocity.x = 0.0
		velocity.z = 0.0

		if (
			not is_jumping
			and not is_landing
			and not is_shielding
			and not is_hit
		):
			play_animation("Rig_Medium_General/Idle_A")

	move_and_slide()

	# Landing
	if is_jumping and is_on_floor():
		is_jumping = false
		is_landing = true
		play_animation("Rig_Medium_MovementBasic/Jump_Land")

	if is_landing:
		var land_length: float = animation_player.current_animation_length
		var land_position: float = animation_player.current_animation_position

		if land_position >= land_length - 0.05:
			is_landing = false

			if direction.length() > 0.0:
				play_animation("Rig_Medium_MovementBasic/Walking_B")
			else:
				play_animation("Rig_Medium_General/Idle_A")


# ==========================================
# DODGE
# ==========================================

func start_dodge() -> void:
	is_dodging = true
	dodge_timer = DODGE_DURATION
	dodge_cooldown_timer = DODGE_COOLDOWN

	var movement: Vector2 = get_combined_movement()
	var direction: Vector3 = Vector3.ZERO

	if movement.length() > 0.0:
		direction.x = -movement.x
		direction.z = -movement.y
		direction = direction.normalized()
		dodge_direction = (transform.basis * direction).normalized()
	else:
		dodge_direction = -transform.basis.z

	print("Knight dodges!")


# ==========================================
# FIRE GEAR MODE
# ==========================================

func set_near_fire_gear(is_near: bool) -> void:
	near_fire_gear = is_near


func start_fire_gear_mode() -> void:
	if is_dead or is_operating_fire_gear:
		return

	is_operating_fire_gear = true
	velocity = Vector3.ZERO

	is_dodging = false
	dodge_timer = 0.0
	dodge_recovery_timer = 0.0
	is_attacking = false
	is_jumping = false
	is_landing = false
	is_shielding = false
	shield_starting = false
	is_blocking_hit = false
	is_hit = false

	if animation_player.has_animation(FIRE_GEAR_ANIMATION):
		animation_player.play(FIRE_GEAR_ANIMATION)
		current_animation = FIRE_GEAR_ANIMATION
	else:
		push_warning(
			"Knight: Fire Gear animation not found: "
			+ FIRE_GEAR_ANIMATION
		)

	print("Knight: Started operating the Fire Gear.")


func stop_fire_gear_mode() -> void:
	is_operating_fire_gear = false

	velocity = Vector3.ZERO
	is_jumping = false
	is_landing = false
	is_attacking = false
	is_shielding = false
	shield_starting = false
	is_blocking_hit = false
	is_hit = false
	is_dodging = false
	dodge_timer = 0.0
	dodge_recovery_timer = 0.0

	current_animation = ""

	if animation_player.has_animation("Rig_Medium_General/Idle_A"):
		animation_player.play("Rig_Medium_General/Idle_A")
		current_animation = "Rig_Medium_General/Idle_A"

	print("Knight: Fire Gear mode ended. Movement restored.")


# ==========================================
# COMBAT
# ==========================================

func attack() -> void:
	is_attacking = true

	if is_shielding:
		play_animation(SHIELD_ATTACK_ANIMATION)
	else:
		play_animation(NORMAL_ATTACK_ANIMATION)


func take_damage(amount: int) -> void:
	if (
		is_dead
		or is_pulling_lever
		or is_operating_fire_gear
	):
		return

	if is_shielding:
		is_blocking_hit = true
		is_hit = false
		is_attacking = false
		shield_starting = false

		if animation_player.has_animation(SHIELD_HIT_ANIMATION):
			animation_player.play(SHIELD_HIT_ANIMATION)
			current_animation = SHIELD_HIT_ANIMATION
			print("Knight blocks the incoming hit!")
		else:
			push_warning(
				"Knight: Shield hit animation not found: "
				+ SHIELD_HIT_ANIMATION
			)

		return

	health -= amount
	print("Knight health: ", health)

	if health <= 0:
		is_dead = true
		play_animation("Rig_Medium_General/Death_A")
		return

	is_hit = true
	play_animation("Rig_Medium_CombatMelee/Hit_A")
