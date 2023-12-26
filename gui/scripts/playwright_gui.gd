@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var add_dialogue_button: Button = $AddDialogueButton

var dialogue_nodes: Array[GraphNode]
var generated_dialogues: Array[Dialogue]

func _enter_tree():
	pass

func _on_add_dialogue_button_pressed():
	var playwright_dialogue_inst: GraphNode = PlaywrightDialogue.instantiate()
	playwright_graph.add_child(playwright_dialogue_inst)
	dialogue_nodes.append(playwright_dialogue_inst)
	# hook up each dialogue node's delete_node signal to the local function listed.
	playwright_dialogue_inst.delete_node.connect(_on_delete_node)

func _on_serialize_dialogue_button_pressed():
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	print(dialogue_connection_list)
	
	for dlg_node: GraphNode in dialogue_nodes:
		var dialogue_res: Dialogue
		for connection: Dictionary in dialogue_connection_list:
			pass

func _on_playwright_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.connect_node(from_node, from_port, to_node, to_port)
	
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.LIME_GREEN)

func _on_playwright_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.disconnect_node(from_node, from_port, to_node, to_port)
	
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.ROYAL_BLUE)

func change_node_port_color(to_node: StringName, to_port: int, color: Color) -> void:
	var to_dlg_node: GraphNode
	for graph_node: Control in playwright_graph.get_children():
		if graph_node.name == to_node:
			to_dlg_node = graph_node
			break
	
	var slot_idx: int = to_dlg_node.get_input_port_slot(to_port)
	to_dlg_node.get_child(slot_idx)
	to_dlg_node.set_slot_color_left(slot_idx, color)

func _on_delete_node(dialogue_node: GraphNode) -> void:
	#print(dialogue_node.name)
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	dialogue_nodes.erase(dialogue_node)
	
	if !dialogue_connection_list.is_empty():
		for connection: Dictionary in dialogue_connection_list:
			if connection["from_node"] == dialogue_node.name || connection["to_node"] == dialogue_node.name:
				playwright_graph.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
			
			dialogue_node.queue_free()
	else:
		dialogue_node.queue_free()
