@tool
extends Control

# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497

@onready var playwright_graph: GraphEdit = $PlaywrightGraph

func _enter_tree():
	pass
