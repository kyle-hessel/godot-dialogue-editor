@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

#region CONSTANTS
const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")
const DLG_OFFSET_INCREMENT_X: float = 250.0
const DLG_OFFSET_INCREMENT_Y: float = 500.0
const DLG_TYPE_DEFAULT: int = 0
const DLG_TYPE_RESPONSE: int = 1
const DLG_TYPE_CALL: int = 2
const DLG_TYPE_MESSAGE: int = 3
const DLG_TYPE_SHOUT: int = 4
#endregion

var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
var res_prev: EditorResourcePreview = EditorInterface.get_resource_previewer()

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var dialogue_name_line_edit: LineEdit = $DialogueNameLineEdit
@onready var add_dialogue_button: Button = $AddDialogueButton
@onready var dlg_file_dialog: FileDialog = $DialogueFileDialog
@onready var import_file_dialog: FileDialog = $ImportFileDialog

signal file_operation_complete

var dialogue_nodes: Array[GraphNode]
var generated_dialogues: Array[Dialogue]
var selected_files: Array

var dlg_offset_x: float = 0
var dlg_offset_y: float = 0
var name_increment: int = 0

func _enter_tree():
	pass
	#res_prev.preview_invalidated.connect(func(preview_path: String): print("Resource: " + preview_path + " invalidated."))

# use the ready signal of the parent node, as children may instantiate first but not yet have a parent.
func _on_ready():
	playwright_graph.snapping_enabled = false
	playwright_graph.show_grid = false
	
	# handle ImportFileDialog if one file is selected.
	import_file_dialog.file_selected.connect(
		func(file_path: String):
			selected_files.clear()
			selected_files.append(file_path)
			import_dialogue_files(selected_files)
	)
	# handle ImportFileDialog if multiple files are selected.
	import_file_dialog.files_selected.connect(
		func(file_paths: PackedStringArray):
			selected_files.clear()
			selected_files = Array(file_paths)
			import_dialogue_files(selected_files)
	)

func _on_add_dialogue_button_pressed():
	dialogue_nodes.append(instantiate_dialogue_node())

func _on_import_dialogue_button_pressed():
	import_file_dialog.visible = true

func _on_playwright_graph_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2):
	if from_port == 0:
		var dlg_node_inst: GraphNode = instantiate_dialogue_node()
		dialogue_nodes.append(dlg_node_inst)
		dlg_node_inst.position_offset = release_position
		playwright_graph.connection_request.emit(from_node, 0, StringName(dlg_node_inst.name), 0)

func instantiate_dialogue_node() -> GraphNode:
	var playwright_dialogue_inst: GraphNode = PlaywrightDialogue.instantiate()
	playwright_graph.add_child(playwright_dialogue_inst)
	dialogue_nodes.append(playwright_dialogue_inst)
	name_increment += 1
	playwright_dialogue_inst.name = "PlaywrightDialogue" + str(name_increment)
	playwright_dialogue_inst.delete_node.connect(_on_delete_node)
	return playwright_dialogue_inst

func import_dialogue_files(file_paths: Array) -> void:
	# import every dialogue file that was selected.
	for file_path: String in file_paths:
		dlg_offset_x = 0.0
		var dlg_res: Dialogue = load(file_path)
		# Take the loaded dialogue resource and use it to make parallel arrays of dialogue nodes and resources.
		var dlg_node_array: Array[GraphNode]
		var dlg_res_array: Array[Dialogue]
		deserialize_dialogue(dlg_res, dlg_node_array, dlg_res_array)
		
		# if there's more than one dialogue node in the chain during deserialization, determine how to rewire connections between nodes.
		if dlg_node_array.size() > 1:
			for node_num: int in dlg_node_array.size():
				if node_num < dlg_node_array.size() - 1:
					var current_node: GraphNode = dlg_node_array[node_num]
					var next_node: GraphNode = dlg_node_array[node_num + 1]
					# rewire dialogue connections by manually firing GraphEdit's connection_request signal.
					playwright_graph.connection_request.emit(StringName(current_node.name), 0, StringName(next_node.name), 0)
					# for default nodes, just do a one-to-one match for wires (for now).
					if next_node.dialogue_type_button.selected == DLG_TYPE_DEFAULT:
						# normal branching dialogue rewiring
						if current_node.dialogue_options.size() == next_node.dialogue_options.size():
							for text_pos: int in current_node.dialogue_options.size():
								playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), text_pos + 1)
						# dialogue branch collapse rewiring
						elif next_node.dialogue_options.size() == 1:  #
							for text_pos: int in current_node.dialogue_options.size():
								playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), 1)
						else:
							print("Next dialogue node does not have the right amount of slots!")
					# for response nodes, use array positioning from the resource itself. this is where the parallel arrays come into play.
					elif next_node.dialogue_type_button.selected == DLG_TYPE_RESPONSE:
						var slot_pos: int = 0
						for text_edit_pos: int in current_node.dialogue_options.size():
							var connection_count: int = dlg_res_array[node_num + 1].dialogue_options[text_edit_pos].size()
							for con_num: int in connection_count:
								playwright_graph.connection_request.emit(StringName(current_node.name), text_edit_pos + 1, StringName(next_node.name), slot_pos + 1 + con_num)
								print("current node: " + str(current_node) + ". " + "slot left: " + str(text_edit_pos + 1) + ", slot right: " + str(slot_pos + 1))
							slot_pos += connection_count
					# TODO: Decide how to handle other dialogue types in terms of rewiring nodes.
					else:
						pass
		
		dlg_offset_y += DLG_OFFSET_INCREMENT_Y

func deserialize_dialogue(dlg_res: Dialogue, out_node_array: Array[GraphNode], out_res_array: Array[Dialogue]) -> void:
	var dlg_node_inst: GraphNode = instantiate_dialogue_node()
	dialogue_nodes.append(dlg_node_inst)
	out_node_array.append(dlg_node_inst)
	out_res_array.append(dlg_res)
	
	# offset dialogue nodes on the graph so they do not overlap.
	dlg_node_inst.position_offset.x += dlg_offset_x
	dlg_node_inst.position_offset.y += dlg_offset_y
	dlg_offset_x += DLG_OFFSET_INCREMENT_X
	
	# deserialize the straightforward information.
	dlg_node_inst.speaker_line_edit.text = dlg_res.speaker
	dlg_node_inst.dialogue_type_button.selected = dlg_res.dialogue_type
	
	if dlg_res.dialogue_type == Dialogue.DialogueType.DEFAULT:
		# determine how many TextEdits are needed for default dialogue data and instantiate them.
		var boxes_needed: int = dlg_res.dialogue_options.size() - 1
		for num: int in boxes_needed:
			dlg_node_inst.add_dialogue_text()
		
		# fill each TextEdit with each string in an array of dialogue lines being on a new line.
		for dlg_num: int in dlg_res.dialogue_options.size():
			var dlg_res_lines: Array = dlg_res.dialogue_options[dlg_num]
			for dlg_line_num: int in dlg_res_lines.size():
				var dlg_line: TextEdit = dlg_node_inst.dialogue_options[dlg_num]
				if dlg_line_num < dlg_res_lines.size() - 1:
					dlg_line.text += dlg_res_lines[dlg_line_num] + "\n"
				else:
					dlg_line.text += dlg_res_lines[dlg_line_num]
		
	elif dlg_res.dialogue_type == Dialogue.DialogueType.RESPONSE:
		# determine how many TextEdits are needed for response dialogue data and instantiate them.
		var boxes_needed: int = 0
		for dlg_option in dlg_res.dialogue_options:
			boxes_needed += dlg_option.size()
		for num: int in boxes_needed - 1:
			dlg_node_inst.add_dialogue_text()
		
		# make each response occupy its own TextEdit, regardless of whether or not they sit in different nested arrays.
		var dlg_pos: int = 0
		for dlg in dlg_res.dialogue_options:
			for dlg_line in dlg:
				dlg_node_inst.dialogue_options[dlg_pos].text = dlg_line
				dlg_pos += 1
	
	# if there is a next dialogue, recursively call this function again.
	if dlg_res.next_dialogue != null:
		deserialize_dialogue(dlg_res.next_dialogue, out_node_array, out_res_array)

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
			print("Saving separate dialogue nodes.")
			for dlg_node: GraphNode in dialogue_nodes:
				# FIXME: This can throw the following in certain instances: "Invalid get index 'name' (on base: 'previously freed')."
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
			# there isn't an easy fix for immediate resource updating upon overwrite, see: https://github.com/godotengine/godot/issues/30302
			# but, relaunching the editor or sometimes clicking around a bit afterwards does the job.
			fs.update_file(dlg_file_dialog.current_path)
			#res_prev.check_for_invalidation(dlg_file_dialog.current_path)
			print("File saved!")
		
		flush_file_dlg_signals(dlg_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	var canceled_func: Callable = func():
		print("File save aborted.")
		
		flush_file_dlg_signals(dlg_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	dlg_file_dialog.confirmed.connect(confirmed_func)
	dlg_file_dialog.canceled.connect(canceled_func)
	
	dlg_file_dialog.visible = true

func flush_file_dlg_signals(file_dlg: FileDialog, signals: Array[String]):
	var decrement: int = 1
	for sig in signals:
		var signal_list: Array[Dictionary] = file_dlg.get_signal_connection_list(sig)
		file_dlg.disconnect(sig, signal_list[decrement]["callable"])
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
