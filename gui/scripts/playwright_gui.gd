@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var add_dialogue_button: Button = $AddDialogueButton

func _enter_tree():
	pass

func _on_add_dialogue_button_pressed():
	var playwright_dialogue_inst: GraphNode = PlaywrightDialogue.instantiate()
	playwright_graph.add_child(playwright_dialogue_inst)
	playwright_dialogue_inst.delete_node.connect(_on_delete_node)

func _on_serialize_dialogue_button_pressed():
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	print(dialogue_connection_list)

func _on_playwright_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.connect_node(from_node, from_port, to_node, to_port)

func _on_playwright_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.disconnect_node(from_node, from_port, to_node, to_port)

func _on_delete_node(dialogue_node: GraphNode) -> void:
	print(dialogue_node.name)
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	for connection: Dictionary in dialogue_connection_list:
		if connection["from_node"] == dialogue_node.name || connection["to_node"] == dialogue_node.name:
			playwright_graph.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
		
		dialogue_node.queue_free()
