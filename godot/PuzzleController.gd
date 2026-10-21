
extends Node3D

signal station_completed(station_name: String)
signal station_state_changed(station_name: String, state: int)
signal seal_completed
signal gate_unlocked


enum StationState {
	INACTIVE,
	IN_PROGRESS,
	COMPLETE
}


var station_states: Dictionary = {
	"fire": StationState.INACTIVE,
	"ice": StationState.INACTIVE,
	"heal": StationState.INACTIVE
}

var seal_is_complete: bool = false
var gate_is_unlocked: bool = false


func _ready() -> void:
	print("PuzzleController ready.")

	# Restore completion state if configured in the Inspector.
	_check_all_stations()


# ==========================================
# STATION STATE
# ==========================================

func get_station_state(station_name: String) -> int:
	var key := station_name.to_lower()

	if not station_states.has(key):
		push_warning("Unknown station: " + station_name)
		return StationState.INACTIVE

	return int(station_states[key])


func is_station_complete(station_name: String) -> bool:
	return get_station_state(station_name) == StationState.COMPLETE


func set_station_in_progress(station_name: String) -> void:
	var key := station_name.to_lower()

	if not station_states.has(key):
		push_warning("Cannot start unknown station: " + station_name)
		return

	if station_states[key] == StationState.COMPLETE:
		return

	if station_states[key] == StationState.IN_PROGRESS:
		return

	station_states[key] = StationState.IN_PROGRESS
	print("Station in progress: ", key)

	station_state_changed.emit(key, StationState.IN_PROGRESS)


func complete_station(station_name: String) -> void:
	var key := station_name.to_lower()

	if not station_states.has(key):
		push_warning("Cannot complete unknown station: " + station_name)
		return

	if station_states[key] == StationState.COMPLETE:
		return

	station_states[key] = StationState.COMPLETE

	print("Station completed: ", key)

	station_state_changed.emit(key, StationState.COMPLETE)
	station_completed.emit(key)

	_check_all_stations()


# ==========================================
# THREEFOLD SEAL
# ==========================================

func _check_all_stations() -> void:
	if seal_is_complete:
		return

	for station_name in station_states.keys():
		if station_states[station_name] != StationState.COMPLETE:
			return

	complete_seal()


func complete_seal() -> void:
	if seal_is_complete:
		return

	seal_is_complete = true
	print("The Threefold Seal has been completed!")

	seal_completed.emit()


# ==========================================
# ANCIENT GATE
# ==========================================

func unlock_gate() -> void:
	if gate_is_unlocked:
		return

	if not seal_is_complete:
		push_warning("The Ancient Gate cannot unlock before the Threefold Seal.")
		return

	gate_is_unlocked = true
	print("The Ancient Gate is unlocked!")

	gate_unlocked.emit()


func is_seal_complete() -> bool:
	return seal_is_complete


func is_gate_unlocked() -> bool:
	return gate_is_unlocked
