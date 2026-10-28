extends Area3D
## HEAL STATION - the Damaged Guardian.
##
##   Stage 1 (Knight): stand by the guardian and press interact  -> it AWAKENS   (station "in progress")
##   Stage 2 (Mage):   cast Heal at the guardian                  -> its core is HEALED (station complete)
##
## Follows the same pattern as fire_station.gd / ice_shrine.gd:
##   finds PuzzleController + the imported guardian visuals by name, calls
##   set_station_in_progress(station_id) then complete_station(station_id).

signal guardian_awakened
signal guardian_healed

enum State { DORMANT, AWAKENED, HEALED }

## Must match the name your PuzzleController uses for this station ("fire" and "ice" are used already).
@export var station_id: String = "heal"
## How many Heal casts it takes to finish (1 = a single cast heals it).
@export_range(1, 10) var heal_pulses_required: int = 1
## Also light Seal_Symbol_Heal / Gate_Symbol_Heal / Conduit_Heal when healed (safe if puzzle_room.gd does it too).
@export var light_heal_symbols: bool = true

@export_group("Glow levels (emission energy)")
@export var core_dormant: float = 0.15
@export var core_awake: float = 1.0
@export var core_healed: float = 4.0
@export var eyes_awake: float = 1.5
@export var eyes_healed: float = 3.0
@export var runes_dormant: float = 0.1
@export var runes_awake: float = 0.6
@export var runes_healed: float = 2.0
@export var crystals_dormant: float = 0.25
@export var crystals_healed: float = 1.4
@export var symbols_lit: float = 3.0
@export var light_awake_factor: float = 0.5
@export var light_healed_factor: float = 1.0

@export_group("Motion")
@export var transition_seconds: float = 1.2
@export var breathing_height: float = 0.008
@export var breathing_speed: float = 1.4

@export_group("Optional")
## Show "Awaken the guardian" through the Virelune HUD if one exists (does nothing otherwise).
@export var use_hud_prompts: bool = false
@export var prompt_input_hint: String = "SLASH"
## Testing without both players: F7 = awaken, F8 = heal. Turn off for the real game.
@export var debug_hotkeys: bool = false

const CORE_COLOR := Color(0.21, 1.0, 0.6)
const EYE_COLOR := Color(0.38, 1.0, 0.69)
const RUNE_COLOR := Color(0.25, 0.88, 0.69)
const CRYSTAL_COLOR := Color(0.25, 1.0, 0.6)
const SYMBOL_COLOR := Color(0.36, 1.0, 0.6)

var state: State = State.DORMANT
var heals_received: int = 0

var puzzle_controller: Node = null
var knight: CharacterBody3D = null
var knight_in_range: bool = false

var _core: Node = null
var _eyes: Node = null
var _runes: Node = null
var _platform_runes: Node = null
var _crystals: Array[Node] = []
var _head: Node3D = null
var _body: Node3D = null
var _light: Light3D = null
var _puzzle_room: Node = null

var _mats := {"core": [], "eyes": [], "runes": [], "crystals": [], "symbols": []}
var _light_base: float = 1.0
var _head_base_rotation: Vector3 = Vector3.ZERO
var _body_base_y: float = 0.0
var _tween: Tween = null
var _time: float = 0.0
var _prev_key: bool = false
var _prev_pad: bool = false
var _last_spell_frame: int = -1

## 0 = dormant, 1 = awakened, 2 = healed. Tweened so the change eases in.
var _progress: float = 0.0:
	set(value):
		_progress = value
		_apply_visuals(value)


func _ready() -> void:
	print("DEBUG: Heal Station ready.")

	monitoring = true
	for layer in range(1, 33):
		set_collision_mask_value(layer, true)

	# Run BEFORE other stations' _process so a controller press is not consumed by fire_gear_interaction.gd first.
	process_priority = -10

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_puzzle_room = _find_puzzle_room()
	_find_nodes()
	_prepare_materials()

	# The guardian starts dormant and dim.
	_apply_visuals(0.0)

	if puzzle_controller == null:
		push_error("Heal Station: PuzzleController not found.")
	else:
		print("DEBUG: PuzzleController found.")

	_check_missing_visuals()
	print("DEBUG: Heal Station setup complete.")


# ==========================================
# SETUP
# ==========================================

func _find_puzzle_room() -> Node:
	# Walk up until we reach the node that contains the imported guardian.
	var n: Node = get_parent()
	while n != null:
		if n.find_child("Guardian_Core", true, false) != null:
			return n
		n = n.get_parent()
	return get_tree().current_scene


func _find_nodes() -> void:
	var room: Node = _puzzle_room
	puzzle_controller = room.get_node_or_null("PuzzleController")
	if puzzle_controller == null:
		puzzle_controller = get_tree().root.find_child("PuzzleController", true, false)

	_core = room.find_child("Guardian_Core", true, false)
	_eyes = room.find_child("Guardian_Eyes", true, false)
	_runes = room.find_child("Guardian_Runes", true, false)
	_platform_runes = room.find_child("Guardian_Platform_Runes", true, false)
	_head = room.find_child("Guardian_Head", true, false) as Node3D
	_body = room.find_child("Guardian_Body", true, false) as Node3D
	_light = room.find_child("Guardian_Light", true, false) as Light3D

	_crystals.clear()
	for i in range(1, 4):
		var c: Node = room.find_child("Guardian_Crystal_%d" % i, true, false)
		if c != null:
			_crystals.append(c)

	if is_instance_valid(_head):
		_head_base_rotation = _head.rotation
	if is_instance_valid(_body):
		_body_base_y = _body.position.y
	if is_instance_valid(_light):
		_light_base = _light.light_energy


func _prepare_materials() -> void:
	_collect("core", _core)
	_collect("eyes", _eyes)
	_collect("runes", _runes)
	_collect("runes", _platform_runes)
	for c in _crystals:
		_collect("crystals", c)


## Gives every mesh under `node` its own copy of its material, so this station can
## change the glow without touching other objects that share the imported material.
func _collect(group: String, node: Node) -> void:
	if node == null:
		return
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			if mi.mesh != null:
				for i in range(mi.mesh.get_surface_count()):
					var original: Material = mi.get_active_material(i)
					if original is StandardMaterial3D:
						var copy: StandardMaterial3D = (original as StandardMaterial3D).duplicate() as StandardMaterial3D
						copy.emission_enabled = true
						mi.set_surface_override_material(i, copy)
						_mats[group].append(copy)
		for child in n.get_children():
			stack.append(child)


func _check_missing_visuals() -> void:
	var missing: Array[String] = []
	if _core == null: missing.append("Guardian_Core")
	if _eyes == null: missing.append("Guardian_Eyes")
	if _runes == null: missing.append("Guardian_Runes")
	if _platform_runes == null: missing.append("Guardian_Platform_Runes")
	if _head == null: missing.append("Guardian_Head")
	if _body == null: missing.append("Guardian_Body")
	if _light == null: missing.append("Guardian_Light")
	if _crystals.size() < 3: missing.append("Guardian_Crystal_1..3")
	if missing.is_empty():
		print("DEBUG: All Heal Station visuals found.")
	else:
		print("DEBUG: Heal Station could not find: ", ", ".join(missing))
		push_warning("Heal Station: missing visual node(s): " + ", ".join(missing))


# ==========================================
# VISUALS
# ==========================================

func _blend(a: float, b: float, c: float, p: float) -> float:
	if p <= 1.0:
		return lerpf(a, b, clampf(p, 0.0, 1.0))
	return lerpf(b, c, clampf(p - 1.0, 0.0, 1.0))


func _set_glow(group: String, color: Color, energy: float) -> void:
	for m in _mats[group]:
		var mat: StandardMaterial3D = m
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy


func _apply_visuals(p: float) -> void:
	_set_glow("core", CORE_COLOR, _blend(core_dormant, core_awake, core_healed, p))
	_set_glow("eyes", EYE_COLOR, _blend(0.0, eyes_awake, eyes_healed, p))
	_set_glow("runes", RUNE_COLOR, _blend(runes_dormant, runes_awake, runes_healed, p))
	_set_glow("crystals", CRYSTAL_COLOR, _blend(crystals_dormant, (crystals_dormant + crystals_healed) * 0.5, crystals_healed, p))

	if is_instance_valid(_light):
		var factor: float = _blend(0.0, light_awake_factor, light_healed_factor, p)
		_light.light_energy = _light_base * factor
		_light.visible = factor > 0.01

	# The guardian slowly lifts its head as it wakes (starts bowed).
	if is_instance_valid(_head):
		var bow: float = _blend(1.0, 0.55, 0.0, p)
		_head.rotation = _head_base_rotation * bow


func _go_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_progress", target, transition_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _light_heal_symbols() -> void:
	for node_name in ["Seal_Symbol_Heal", "Gate_Symbol_Heal", "Conduit_Heal"]:
		var n: Node = _puzzle_room.find_child(node_name, true, false)
		if n == null:
			push_warning("Heal Station: could not find " + node_name)
			continue
		_collect("symbols", n)
	_set_glow("symbols", SYMBOL_COLOR, symbols_lit)


# ==========================================
# MOTION
# ==========================================

func _process(delta: float) -> void:
	_time += delta

	# The awake guardian "breathes" with a tiny bob.
	if state != State.DORMANT and is_instance_valid(_body):
		var strength: float = 0.5 if state == State.AWAKENED else 1.0
		_body.position.y = _body_base_y + sin(_time * breathing_speed) * breathing_height * strength

	if debug_hotkeys:
		if Input.is_key_pressed(KEY_F7) and state == State.DORMANT:
			awaken()
		if Input.is_key_pressed(KEY_F8) and state != State.HEALED:
			if state == State.DORMANT:
				awaken()
			heal_guardian()

	if _read_interact_pressed() and knight_in_range:
		_try_knight_awaken()


# ==========================================
# STAGE 1: KNIGHT AWAKENS THE GUARDIAN
# ==========================================

func _read_interact_pressed() -> bool:
	var key_down: bool = Input.is_key_pressed(KEY_SLASH)
	var key_pressed: bool = key_down and not _prev_key
	_prev_key = key_down

	var pad_down: bool = false
	var arduino: Node = get_node_or_null("/root/ArduinoKnight")
	if arduino != null:
		pad_down = arduino.get("interact_pressed") == true
	var pad_pressed: bool = pad_down and not _prev_pad
	_prev_pad = pad_down

	# Only consume the controller press if we are actually the one using it.
	if pad_pressed and knight_in_range and arduino != null:
		arduino.set("interact_pressed", false)

	return key_pressed or pad_pressed


func _try_knight_awaken() -> void:
	if not is_instance_valid(knight):
		return
	if knight.get("is_dead") == true:
		return
	if state == State.HEALED:
		print("Heal Station: The guardian is already healed.")
		return
	if state == State.AWAKENED:
		print("Heal Station: The guardian is already awake. The Mage must heal it!")
		return
	awaken()


func awaken() -> void:
	print("DEBUG: Attempting to awaken the guardian.")

	if state != State.DORMANT:
		print("DEBUG: The guardian is already awake.")
		return

	if puzzle_controller == null:
		push_warning("Cannot awaken guardian: PuzzleController missing.")
		return

	state = State.AWAKENED
	_go_to(1.0)
	_hide_prompt()

	if puzzle_controller.has_method("set_station_in_progress"):
		puzzle_controller.set_station_in_progress(station_id)
	else:
		push_warning("PuzzleController is missing set_station_in_progress().")

	guardian_awakened.emit()

	print("The Knight awakens the guardian!")
	print("The Mage can now use Heal on the guardian's core.")


# ==========================================
# STAGE 2: MAGE HEALS THE GUARDIAN
# ==========================================

func receive_spell(spell_name: String) -> void:
	print("DEBUG: Heal Station received spell: ", spell_name)

	if not spell_name.to_lower().contains("heal"):
		print("DEBUG: The guardian needs Heal, not ", spell_name)
		return

	# If both this Area and a HealSpellTarget forward the same cast, count it once.
	var frame: int = Engine.get_physics_frames()
	if frame == _last_spell_frame:
		return
	_last_spell_frame = frame

	heal_guardian()


func heal_guardian() -> void:
	print("DEBUG: Attempting to heal the guardian.")

	if state == State.HEALED:
		print("DEBUG: The guardian is already healed.")
		return

	if state == State.DORMANT:
		print("The guardian is dormant. The Knight must awaken it before the Mage can heal it!")
		return

	heals_received += 1

	if heals_received < heal_pulses_required:
		# Partial progress: the glow builds with each cast.
		var partial: float = 1.0 + float(heals_received) / float(heal_pulses_required)
		_go_to(minf(partial, 1.95))
		print("The guardian's core flickers... (", heals_received, "/", heal_pulses_required, ")")
		return

	if puzzle_controller == null:
		push_error("Cannot complete Heal Station: PuzzleController missing.")
		return

	if not puzzle_controller.has_method("complete_station"):
		push_error("PuzzleController is missing complete_station().")
		return

	state = State.HEALED
	_go_to(2.0)

	# Complete the station first so the room receives its signal.
	puzzle_controller.complete_station(station_id)

	if light_heal_symbols:
		_light_heal_symbols()

	guardian_healed.emit()

	print("The Mage restores the guardian's core!")
	print("DEBUG: Heal Station puzzle completed successfully.")


# ==========================================
# KNIGHT DETECTION
# ==========================================

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player2"):
		knight_in_range = true
		knight = body as CharacterBody3D
		print("Heal Station: Knight detected in range.")
		if use_hud_prompts and state == State.DORMANT:
			get_tree().call_group("virelune_hud", "show_prompt", 2, "Healing", "Awaken the guardian", prompt_input_hint)


func _on_body_exited(body: Node3D) -> void:
	if body == knight:
		knight_in_range = false
		knight = null
		_hide_prompt()
		print("Heal Station: Knight left the interaction area.")


func _hide_prompt() -> void:
	if use_hud_prompts:
		get_tree().call_group("virelune_hud", "hide_prompt", 2, "Healing")
