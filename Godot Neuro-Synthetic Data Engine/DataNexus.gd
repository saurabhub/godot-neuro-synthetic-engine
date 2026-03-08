extends Node
class_name DataNexusSingleton

## DataNexus (Singleton/Global)
## Centralized logging node that handles multi-agent data streams.
## Buffers data in memory and implements an asynchronous export to a structured JSON file.

var data_buffer: Array[Dictionary] = []
var export_path: String = "user://output_data.json"
var is_exporting: bool = false
var export_thread: Thread

# Mutex to ensure thread safety when modifying the buffer during async export
var mutex: Mutex

func _ready() -> void:
	mutex = Mutex.new()
	print("DataNexus initialized. Logging to: ", ProjectSettings.globalize_path(export_path))

func log_agent_data(agent_id: String, position: Vector3, state: String, feature_vector: Array[float], angle_to_target: float, decision_trigger: String) -> void:
	var data_point: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"frame": Engine.get_process_frames(),
		"agent_id": agent_id,
		"pos_x": position.x,
		"pos_y": position.y,
		"pos_z": position.z,
		"state": state,
		"angle_to_target": angle_to_target,
		"decision_trigger": decision_trigger
	}
	
	# Flatten feature vector into individual columns for Pandas-ready export
	for i in range(feature_vector.size()):
		data_point["dist_obs_%d" % i] = feature_vector[i]
		
	mutex.lock()
	data_buffer.append(data_point)
	mutex.unlock()

func get_data_count() -> int:
	mutex.lock()
	var count = data_buffer.size()
	mutex.unlock()
	return count

func trigger_export() -> void:
	if is_exporting or data_buffer.is_empty():
		return
		
	is_exporting = true
	
	if export_thread != null and export_thread.is_started():
		export_thread.wait_to_finish()
		
	export_thread = Thread.new()
	export_thread.start(_export_data_async)

func _export_data_async() -> void:
	mutex.lock()
	var data_to_export: Array[Dictionary] = data_buffer.duplicate(true)
	data_buffer.clear()
	mutex.unlock()
	
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data_to_export, "\t")
		file.store_string(json_string)
		file.close()
		print("Async export completed: ", data_to_export.size(), " records written.")
	else:
		printerr("Failed to open output file for writing.")
		
	is_exporting = false

func _exit_tree() -> void:
	if export_thread != null and export_thread.is_started():
		export_thread.wait_to_finish()
	# Ensure remaining data is saved before exit
	trigger_export()
	if export_thread != null and export_thread.is_started():
		export_thread.wait_to_finish()
