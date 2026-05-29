extends Node
class_name ChartManager

var current_chart: Dictionary = {}

func load_chart(chart_path: String) -> bool:
	"""Load a JSON chart file and parse it."""
	if not ResourceLoader.exists(chart_path):
		print("Chart file not found: ", chart_path)
		return false
	
	var json = JSON.new()
	var file_data = FileAccess.get_file_as_string(chart_path)
	
	if json.parse(file_data) != OK:
		print("Failed to parse JSON chart")
		return false
	
	current_chart = json.data
	print("Chart loaded: ", current_chart.metadata.title)
	return true

func get_circles() -> Array:
	"""Return array of circle dictionaries."""
	if current_chart.is_empty():
		return []
	return current_chart.get("circles", [])

func get_metadata() -> Dictionary:
	"""Return chart metadata."""
	if current_chart.is_empty():
		return {}
	return current_chart.get("metadata", {})

func get_duration_ms() -> int:
	"""Return song duration in milliseconds."""
	return get_metadata().get("duration_ms", 0)
