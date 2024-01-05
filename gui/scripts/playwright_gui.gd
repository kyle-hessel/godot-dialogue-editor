@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")

var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
var res_prev: EditorResourcePreview = EditorInterface.get_resource_previewer()

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var dialogue_name_line_edit: LineEdit = $DialogueNameLineEdit
@onready var add_dialogue_button: Button = $AddDialogueButton
@onready var dlg_file_dialog: FileDialog = $DialogueFileDialog

signal file_operation_complete

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
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	# if there is a connection list, sort dialogue nodes and then serialize them.
	if dialogue_connection_list.size() > 0:
		print("Dialogue chain present: sorting dialogue nodes and serializing them.")
		var sorted_dialogue_node_names: Array[String] = sort_dialogue_nodes(dialogue_connection_list)
		#print(sorted_dialogue_node_names)
		
		# use dialogue node name data to fetch the nodes themselves and transcribe them into an array of dialogue resources.
		var dlg_res_array: Array[Dialogue]
		var last_node_name: String = ""
		
		var dialogue_line_connections: Array[Dictionary] = filter_dialogue_line_connections(dialogue_connection_list)
		for node_name: String in sorted_dialogue_node_names:
			var node_path_str: String = "PlaywrightGraph/" + node_name
			var dlg_node: GraphNode = get_node(NodePath(node_path_str))
			var dlg: Resource = transcribe_dialogue_node_to_resource(dlg_node, last_node_name, dialogue_line_connections)
			dlg_res_array.append(dlg)
			last_node_name = dlg_node.name
		#print(dlg_res_array)
		
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
		
		# save the first resource in the array to disk as a .tres. each resource afterwards is a nested subresource,
		# ... so only this is needed for the entire dialogue tree.
		save_dialogue_res_to_disk(dlg_res_array[0], dialogue_name_line_edit.text)
		await file_operation_complete
		
		# next, figure out if there are any non-connected dialogue nodes and save them separately.
		if sorted_dialogue_node_names.size() != dialogue_nodes.size():
			var floating_dialogues: Array[GraphNode]
			print("danglers spotted!!")
			for dlg_node: GraphNode in dialogue_nodes:
				if sorted_dialogue_node_names.find(dlg_node.name) == -1:
					floating_dialogues.append(dlg_node)
			
			serialize_unconnected_dlg_nodes(floating_dialogues)
	
	# if there isn't a connection list, dialogue nodes do not need to be sorted in any way - just serialize them.
	else:
		print("No dialogue chain present, serializing dialogue nodes individually.")
		serialize_unconnected_dlg_nodes(dialogue_nodes)

func serialize_unconnected_dlg_nodes(dlg_node_array: Array[GraphNode]) -> void:
	var dlg_res_array: Array[Dialogue]
	for dlg_node: GraphNode in dlg_node_array:
		var dlg: Resource = transcribe_dialogue_node_to_resource(dlg_node)
		dlg_res_array.append(dlg)
	
	var count_num: int = 0
	for dlg: Resource in dlg_res_array:
		count_num += 1
		var res_name: String = dialogue_name_line_edit.text + str(count_num)
		save_dialogue_res_to_disk(dlg, res_name)
		await file_operation_complete

func save_dialogue_res_to_disk(dlg_res: Dialogue, res_name: String):
	var dlg_filename: String = res_name + ".tres"
	dlg_file_dialog.current_path = dlg_filename
	
	var confirmed_func: Callable = func():
		var save_result: Error = ResourceSaver.save(dlg_res, dlg_file_dialog.current_path)
		
		if save_result != OK:
			print(save_result)
		else:
			fs.scan()
			fs.update_file(dlg_file_dialog.current_path)
			res_prev.preview_invalidated.connect(func(path: String): print("I KNEW IT!"))
			res_prev.check_for_invalidation(dlg_file_dialog.current_path)
			print("File saved!")
		
		flush_file_dlg_signals(["confirmed", "canceled"])
		file_operation_complete.emit()
	
	var canceled_func: Callable = func():
		print("File save aborted.")
		
		flush_file_dlg_signals(["confirmed", "canceled"])
		file_operation_complete.emit()
	
	dlg_file_dialog.confirmed.connect(confirmed_func)
	dlg_file_dialog.canceled.connect(canceled_func)
	
	dlg_file_dialog.visible = true

func flush_file_dlg_signals(signals: Array[String]):
	var decrement: int = 1
	for sig in signals:
		var signal_list: Array[Dictionary] = dlg_file_dialog.get_signal_connection_list(sig)
		dlg_file_dialog.disconnect(sig, signal_list[decrement]["callable"])
		decrement -= 1 # this may have to change later, but maybe not

func filter_dialogue_line_connections(connection_list: Array[Dictionary]) -> Array[Dictionary]:
	# filter for dlg line connections only (any slot but 0).
	var dialogue_line_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] != 0 && connection["to_port"] != 0:
			dialogue_line_connections.append(connection)
	
	return dialogue_line_connections

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
	
	# determine the starting dialogue node by finding the one that doesn't act as a to_node anywhere.
	var starting_node_name: String
	for from_node_name: String in from_nodes:
		var match_found: bool = false
		for to_node_name: String in to_nodes:
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

func transcribe_dialogue_node_to_resource(dlg_node: GraphNode, last_node_name: String = "", dlg_line_connections: Array[Dictionary] = []) -> Dialogue:
	var dialogue_res: Dialogue = Dialogue.new()
	# fill the obvious fields first - speaker and dialogue type.
	dialogue_res.speaker = dlg_node.speaker_line_edit.text
	dialogue_res.dialogue_type = dlg_node.dialogue_type_button.selected
	
	if dialogue_res.dialogue_type == Dialogue.DialogueType.DEFAULT:
		# loop through each dialogue box on the node
		for dlg_lines: TextEdit in dlg_node.dialogue_options:
			var lines: Array[String]
			# loop through each line in each dialogue box.
			for line: int in dlg_lines.get_line_count():
				# turn each dialogue box into an array of strings.
				lines.append(dlg_lines.get_line(line))
			# add each dialogue box string array as a nested array for dialogue_options (for branching dialogue).
			dialogue_res.dialogue_options.append(lines)
		
	elif dialogue_res.dialogue_type == Dialogue.DialogueType.RESPONSE:
		# find relevant node connections for the given node.
		var relevant_connections: Array[Dictionary]
		for connection: Dictionary in dlg_line_connections:
			if connection["from_node"] == last_node_name:
				relevant_connections.append(connection)
		
		# sort relevant_connections in order of from_port number, ascending.
		relevant_connections.sort_custom(func(a, b): return a["from_port"] < b["from_port"])
		print(relevant_connections)
		
		# determine number of ports to know how large to size the dialogue_res.dialogue_options array.
		var port_count: int = 1
		for connection_idx: int in relevant_connections.size():
			if connection_idx + 1 < relevant_connections.size():
				if relevant_connections[connection_idx + 1]["from_port"] != port_count:
					port_count += 1
		
		# use the number of ports, the relevant_connections list, and the dialogue node's dialogue_options array
		# ... to extrapolate how response options are sorted when they are transcribed prior to serialization.
		for port_num: int in port_count:
			var responses: Array[String]
			for connection: Dictionary in relevant_connections:
				if connection["from_port"] == port_num + 1:
					responses.append(dlg_node.dialogue_options[connection["to_port"] - 1].text)
			dialogue_res.dialogue_options.append(responses)
		
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

