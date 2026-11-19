
extends Node3D

# ============================================================
# CHECKPOINT SETTINGS
# ============================================================

@export_group("Checkpoint")
@export var checkpoint_id: StringName = &""

@export_group("Detection")
@export var detection_size: Vector3 = Vector3(4.0, 3.0, 4.0)
@export var detection_offset: Vector3 = Vector3(0, 1, 0)

@export_group("Respawn")
@export var player_spawn_spacing: float = 1.0

@export_group("Visuals")
@export var spin_emblem: bool = true
@export var spin_speed: float = 20.0
@export var float_emblem: bool = true
@export var float_height: float = 0.1
@export var float_speed: float = 2.0


# ============================================================
# VARIABLES
# ============================================================

var nearby_players: Array[Node3D] = []
var interacted_players: Dictionary = {}

var detection_area: Area3D
var emblem: Node3D
var glow: Light3D
var label: Label3D
var respawn_point: Marker3D

var original_emblem_position: Vector3
var elapsed_time: float = 0.0
var activated: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("checkpoints")

	emblem = find_child("Emblem", true, false) as Node3D
	glow = find_child("Glow", true, false) as Light3D
	label = find_child("Label3D", true, false) as Label3D
	respawn_point = find_child("RespawnPoint", true, false) as Marker3D

	if is_instance_valid(emblem):
		original_emblem_position = emblem.position

	# Check whether this checkpoint was already activated.
	var game_manager: Node = get_node_or_null("/root/GameManager")

	if is_instance_valid(game_manager):
		if game_manager.get("checkpoint_active") == true:
			var saved_id = game_manager.get("active_checkpoint_id")

			if str(saved_id) == str(get_checkpoint_id()):
				activated = true

	create_detection_area()
	refresh_visual()

	print(
		"Checkpoint ready: ",
		name,
		" | Activated: ",
		activated
	)


# ============================================================
# CHECKPOINT ID
# ============================================================

func get_checkpoint_id() -> StringName:
	if checkpoint_id != &"":
		return checkpoint_id

	return StringName(name)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	elapsed_time += delta

	if not activated and is_instance_valid(emblem):
		if spin_emblem:
			emblem.rotate_y(deg_to_rad(spin_speed * delta))

		if float_emblem:
			emblem.position.y = (
				original_emblem_position.y
				+ sin(elapsed_time * float_speed) * float_height
			)

	if activated:
		return

	for player in nearby_players.duplicate():
		if not is_instance_valid(player):
			nearby_players.erase(player)
			continue

		if not is_player_in_range(player):
			nearby_players.erase(player)
			continue

		if player_interaction_pressed(player):
			handle_player_interaction(player)


# ============================================================
# DETECTION AREA
# ============================================================

func create_detection_area() -> void:
	detection_area = Area3D.new()
	detection_area.name = "CheckpointDetectionArea"
	detection_area.position = detection_offset
	detection_area.collision_layer = 0
	detection_area.collision_mask = 1
	detection_area.monitoring = true
	detection_area.monitorable = false

	var collision := CollisionShape3D.new()
	collision.name = "DetectionShape"

	var shape := BoxShape3D.new()
	shape.size = detection_size
	collision.shape = shape

	detection_area.add_child(collision)
	add_child(detection_area)

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not is_player(body):
		return

	if not nearby_players.has(body):
		nearby_players.append(body)

	if not activated:
		show_player_message(body, "Both need to interact")


func _on_body_exited(body: Node3D) -> void:
	nearby_players.erase(body)

	if not activated:
		interacted_players.erase(body.get_instance_id())
		refresh_visual()


func is_player(body: Node) -> bool:
	return (
		body.is_in_group("player1")
		or body.is_in_group("player2")
	)


func is_player_in_range(player: Node3D) -> bool:
	return (
		is_instance_valid(detection_area)
		and detection_area.overlaps_body(player)
	)


# ============================================================
# INPUT
# ============================================================

func player_interaction_pressed(player: Node3D) -> bool:
	var keyboard_pressed: bool = false
	var arduino: Node = null

	if player.is_in_group("player1"):
		keyboard_pressed = Input.is_action_just_pressed("mage_interact")
		arduino = get_node_or_null("/root/ArduinoMage")

	elif player.is_in_group("player2"):
		keyboard_pressed = Input.is_action_just_pressed("p2_interact")
		arduino = get_node_or_null("/root/ArduinoKnight")

	if keyboard_pressed:
		return true

	if is_instance_valid(arduino):
		if arduino.has_method("consume_interaction"):
			if arduino.consume_interaction():
				return true
		else:
			var interaction_value = arduino.get("interact_pressed")

			if interaction_value == true:
				arduino.set("interact_pressed", false)
				return true

	return false


# ============================================================
# PLAYER INTERACTION
# ============================================================

func handle_player_interaction(player: Node3D) -> void:
	if activated or not is_instance_valid(player):
		return

	if not is_player_in_range(player):
		return

	var player_id: int = player.get_instance_id()

	if interacted_players.has(player_id):
		return

	# Record this player's interaction.
	interacted_players[player_id] = true

	# Do not display another popup here.
	# The permanent checkpoint label shows who is ready.
	refresh_visual()

	print(
		player.name,
		" interacted with checkpoint: ",
		name
	)

	if both_players_interacted():
		activate_checkpoint()


func both_players_interacted() -> bool:
	var mage_interacted: bool = false
	var knight_interacted: bool = false

	for player in nearby_players:
		if not is_instance_valid(player):
			continue

		if not interacted_players.has(player.get_instance_id()):
			continue

		if player.is_in_group("player1"):
			mage_interacted = true

		elif player.is_in_group("player2"):
			knight_interacted = true

	return mage_interacted and knight_interacted


# ============================================================
# ACTIVATE CHECKPOINT
# ============================================================

func activate_checkpoint() -> void:
	if activated:
		return

	var player1: Node3D = null
	var player2: Node3D = null

	for player in nearby_players:
		if not is_instance_valid(player):
			continue

		if player.is_in_group("player1"):
			player1 = player

		elif player.is_in_group("player2"):
			player2 = player

	if player1 == null or player2 == null:
		return

	var game_manager: Node = get_node_or_null("/root/GameManager")

	if not is_instance_valid(game_manager):
		push_error("Checkpoint: GameManager could not be found.")
		return

	# Remember which checkpoint was activated.
	game_manager.set(
		"active_checkpoint_id",
		get_checkpoint_id()
	)

	game_manager.call(
		"activate_checkpoint",
		player1,
		player2,
		respawn_point
	)

	activated = true

	refresh_visual()

	# Only show the success notification once.
	show_player_message(player1, "Checkpoint Set!")
	show_player_message(player2, "Checkpoint Set!")

	print("CHECKPOINT SET: ", get_checkpoint_id())


# ============================================================
# VISUALS
# ============================================================

func refresh_visual() -> void:
	if is_instance_valid(label):
		if activated:
			label.text = "Checkpoint Set!"
		else:
			label.text = "Both need to interact"

	if is_instance_valid(glow):
		if activated:
			glow.light_energy = 2.0
		elif not interacted_players.is_empty():
			glow.light_energy = 1.5
		else:
			glow.light_energy = 1.0


# ============================================================
# NOTIFICATIONS
# ============================================================

func show_player_message(player: Node, message: String) -> void:
	if not is_instance_valid(player):
		return

	var popup_label := Label3D.new()

	popup_label.text = message
	popup_label.font_size = 42
	popup_label.pixel_size = 0.003
	popup_label.outline_size = 12
	popup_label.outline_modulate = Color.BLACK
	popup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup_label.no_depth_test = true

	# Lower notification position.
	popup_label.position = Vector3(0, 0.65, 0)

	player.add_child(popup_label)

	var tween := popup_label.create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		popup_label,
		"position:y",
		1.0,
		2.0
	)

	tween.tween_property(
		popup_label,
		"modulate:a",
		0.0,
		2.0
	).set_delay(0.8)

	tween.chain().tween_callback(
		popup_label.queue_free
	)
