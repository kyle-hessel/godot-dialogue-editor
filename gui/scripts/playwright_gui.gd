@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var add_dialogue_button: Button = $AddDialogueButton

var dialogue_nodes: Array[GraphNode]
var generated_dialogues: Array[Dialogue]

var name_increment: int = 0

func _enter_tree():
	pass

func _on_add_dialogue_button_pressed():
	var playwright_dialogue_inst: GraphNode = PlaywrightDialogue.instantiate()
	playwright_graph.add_child(playwright_dialogue_inst)
	dialogue_nodes.append(playwright_dialogue_inst)
	name_increment += 1
	playwright_dialogue_inst.name = "PlaywrightDialogue" + str(name_increment)
	# hook up each dialogue node's delete_node signal to the local function listed.
	playwright_dialogue_inst.delete_node.connect(_on_delete_node)

func _on_serialize_dialogue_button_pressed():
	# TODO: Put all of this on a separate thread?
	
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	# if there is a connection list, sort dialogue nodes and then serialize them.
	# TODO: serialize non-connected dialogue nodes separately?
	if dialogue_connection_list.size() > 0:
		print("Dialogue chain present: sorting dialogue nodes and serializing them.")
		var sorted_dialogue_node_names: Array[String] = sort_dialogue_nodes(dialogue_connection_list)
		print(sorted_dialogue_node_names)
		
		# use dialogue node name data to fetch the nodes themselves and transcribe them into an array of dialogue resources.
		var dlg_res_array: Array[Dialogue]
		for node_name: String in sorted_dialogue_node_names:
			var node_path_str: String = "PlaywrightGraph/" + node_name
			var dlg_node: GraphNode = get_node(NodePath(node_path_str))
			var dlg: Resource = transcribe_dialogue_node_to_resource(dlg_node)
			dlg_res_array.append(dlg)
		print(dlg_res_array)
		
		# chain each dialogue to the next dialogue in its array, unless its the last element. this is a linked list!
		for dlg_pos: int in dlg_res_array.size():
			if dlg_pos < dlg_res_array.size() - 1:
				var dlg_to_chain: Dialogue = dlg_res_array[dlg_pos]
				dlg_to_chain.next_dialogue = dlg_res_array[dlg_pos + 1]
				print("dlg: " + str(dlg_to_chain) + ", next dlg: " + str(dlg_to_chain.next_dialogue))
			
			# FIXME: this is for debugging, comment it out later or remove it.
			else:
				var dlg_to_chain: Dialogue = dlg_res_array[dlg_pos]
				print("dlg: " + str(dlg_to_chain) + ", end of list.")
		
		# TODO: name each resource (I would add something to name the whole chain at the top of the UI), and save to disk with ResourceSaver.
	
	# if there isn't a connection list, dialogue nodes do not need to be sorted in any way - just serialize them.
	else:
		print("No dialogue chain present, serializing dialogue nodes individually.")
		# TODO: Implement serialization of unconnected dialogue nodes.
	
	# turn every dialogue node into a dialogue resource
	#for dlg_node: GraphNode in dialogue_nodes:
		#var dialogue: Dialogue = transcribe_dialogue_node_to_resource(dlg_node)

# NOTE: this is a helper function for _on_serialize_dialogue_button_pressed just above.
# a function that interprets all existing graph node and connection data to extrapolate a sorted array of dialogue node names.
func sort_dialogue_nodes(connection_list: Array[Dictionary]) -> Array[String]:
	var sorted_dialogue_node_names: Array[String]
	
	# filter for Dialogue connections only (slot 0).
	var dialogue_node_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] == 0 && connection["to_port"] == 0:
			dialogue_node_connections.append(connection)
	
	# convert dictionary data into two separate arrays.
	var from_nodes: Array[String]
	var to_nodes: Array[String]
	for dlg_connection: Dictionary in dialogue_node_connections:
		from_nodes.append(dlg_connection["from_node"])
		to_nodes.append(dlg_connection["to_node"])
	
	# determine the starting dialogue node.
	var starting_node_name: String
	for from_node_name: String in from_nodes:
		#var from_node_path_str: String = "PlaywrightGraph/" + from_node_name
		#var from_node: GraphNode = get_node(NodePath(from_node_path_str))
		
		var match_found: bool = false
		for to_node_name: String in to_nodes:
			#var to_node_path_str: String = "PlaywrightGraph/" + to_node_name
			#var to_node: GraphNode = get_node(NodePath(to_node_path_str))
			if from_node_name == to_node_name:
				match_found = true
			
		if !match_found:
			starting_node_name = from_node_name
			break
	
	# use the determined starting node as a jumping off point, and sort the rest of the dialogue nodes by pouring over their connection keys until everything is accounted for.
	var initial_dialogue_name_array: Array[String]
	initial_dialogue_name_array.append(starting_node_name)
	var node_temp: String = initial_dialogue_name_array[0]
	
	return traverse_dlg_connection_array(dialogue_node_connections, initial_dialogue_name_array, node_temp)

# NOTE: this is a helper function for sort_dialogue_nodes just above.
# a recursive function that traverses the same array of dictionaries over and over until all dialogue connections have been accounted for.
func traverse_dlg_connection_array(dlg_connections_array: Array[Dictionary], sorted_dlg_names: Array[String], node_temp: String) -> Array[String]:
	for dlg_connection: Dictionary in dlg_connections_array:
		if dlg_connection["from_node"] == node_temp:
			node_temp = dlg_connection["to_node"]
			sorted_dlg_names.append(dlg_connection["to_node"])
	
	if sorted_dlg_names.size() - 1 < dlg_connections_array.size():
		return traverse_dlg_connection_array(dlg_connections_array, sorted_dlg_names, node_temp)
	else:
		return sorted_dlg_names

func transcribe_dialogue_node_to_resource(dlg_node: GraphNode) -> Dialogue:
	var dialogue_res: Dialogue = Dialogue.new()
	# fill the obvious fields first - speaker and dialogue type.
	dialogue_res.speaker = dlg_node.speaker_line_edit.text
	dialogue_res.dialogue_type = dlg_node.dialogue_type_button.selected
	
	# loop through each dialogue box on the node
	for dlg_option: TextEdit in dlg_node.dialogue_options:
		if dialogue_res.dialogue_type == Dialogue.DialogueType.DEFAULT:
			var lines: Array[String]
			# loop through each line in each dialogue box.
			for line: int in dlg_option.get_line_count():
				# turn each dialogue box into an array of strings.
				lines.append(dlg_option.get_line(line))
			# add each dialogue box string array as a nested array for dialogue_options (for branching dialogue).
			dialogue_res.dialogue_options.append(lines)
		elif dialogue_res.dialogue_type == Dialogue.DialogueType.RESPONSE:
			# TODO: Implement dialogue option sorting for response transcription.
			pass
		else:
			# TODO: Implement dialogue option sorting for other dialogue type transcription.
			pass
	return dialogue_res

func _on_playwright_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.connect_node(from_node, from_port, to_node, to_port)
	
	# if the port isn't 0 (for dialogue to dialogue connections) change color.
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.LIME_GREEN)
	else:
		change_node_port_color(to_node, to_port, Color.PINK)

func _on_playwright_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.disconnect_node(from_node, from_port, to_node, to_port)
	
	# if the port isn't 0 (for dialogue to dialogue connections) change color back.
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.ROYAL_BLUE)
	else:
		change_node_port_color(to_node, to_port, Color.PURPLE)

func change_node_port_color(node_name: StringName, port: int, color: Color) -> void:
	var dlg_node: GraphNode
	for graph_node: Control in playwright_graph.get_children():
		if graph_node.name == node_name:
			dlg_node = graph_node
			break
	
	var slot_idx: int = dlg_node.get_input_port_slot(port)
	dlg_node.get_child(slot_idx)
	dlg_node.set_slot_color_left(slot_idx, color)

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
