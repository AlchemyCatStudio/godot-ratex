@tool
@icon("res://addons/godot_ratex/icon.svg")
extends VBoxContainer # 1. Changed from HFlowContainer

@export
var debug_children: bool = false

@export_multiline()
var text: String = "":
	set (value):
		text = value
		word_array = parse_bbcode_to_word_array(value) 
		generate(word_array)

@export var font_size: int = 16:
	set (value):
		font_size = value
		generate(word_array)

@export var space: int = 4:
	set (value):
		space = value
		generate(word_array)

@export var line_spacing: int = 4:
	set (value):
		line_spacing = value
		generate(word_array)

var word_array = []


## Parses a BBCode string into an Array of token Dictionaries.
func parse_bbcode_to_word_array(p_text: String) -> Array[Dictionary]:
	var parsed_array: Array[Dictionary] = []
	var regex := RegEx.new()
	
	regex.compile("\\[(?<close>/?)(?<tag>\\w+)(?<attributes>[^\\]]*)\\]")
	
	var last_end := 0
	var matches := regex.search_all(p_text)

	for match in matches:
		var start := match.get_start()
		
		var is_close_tag := match.get_string("close") == "/"
		var tag_name := match.get_string("tag")
		var raw_attributes := match.get_string("attributes").strip_edges()
		
		var content = p_text.substr(last_end, start - last_end)
		
		if start > last_end and content.strip_edges() != "" :
			parsed_array.append({
				"type": "math" if tag_name == "math" and is_close_tag else "text",
				"content": content
			})
		
		var value := ""
		
		if raw_attributes.begins_with("="):
			value = raw_attributes.substr(1)
			if value.begins_with('"') and value.ends_with('"'):
				value = value.substr(1, value.length() - 2)
		else:
			value = raw_attributes
		
		if tag_name != "math":
			parsed_array.append({
				"type": "tag",
				"tag": tag_name,
				"is_close": is_close_tag,
				"value": value
			})
		
		last_end = match.get_end()
		
	if last_end < p_text.length():
		parsed_array.append({
			"type": "text",
			"content": p_text.substr(last_end)
		})
		
	return parsed_array


## Takes the parsed BBCode array and returns an Array containing configured RichTextLabels AND "\n" strings
func generate(parsed_array: Array[Dictionary]) -> void:
	var items: Array = [] # Changed type to untyped Array so it can hold Strings and Nodes
	var active_tags: Array[Dictionary] = []
	
	for child in get_children():
			remove_child(child)
			child.queue_free()
	
	# 1. create texts/items
	for token in parsed_array:
		if token.type == "tag":
			if not token.is_close:
				active_tags.append(token)
			else:
				for i in range(active_tags.size() - 1, -1, -1):
					if active_tags[i].tag == token.tag:
						active_tags.remove_at(i)
						break
		
		elif token.type == "math":
			var latex: String = token.content.strip_edges()
			
			var regex = RegEx.new()
			regex.compile("\\\\input{[a-zA-Z0-9_-]*}")
			var regex_matches = regex.search_all(latex)
			
			for regex_match in regex_matches:
				if regex_match != null:
					var match_string = regex_match.get_string()
					var variable_code = match_string.lstrip("\\input{").rstrip("\\}")
					
					if variable_code == "":
						variable_code = "\\quad" 
					
					latex = latex.replace(match_string,  variable_code)
			
			var ratex = RaTeXRenderer.new()
			ratex.background_color = Color.TRANSPARENT
			ratex.font_color = Color.WHITE
			ratex.font_size = font_size
			var svg_string = ratex.render_svg(latex)
			var image = Image.new()
			image.load_svg_from_string(svg_string)
			var texture_rect = TextureRect.new()
			texture_rect.texture = ImageTexture.create_from_image(image)
			items.append(texture_rect)
			
		elif token.type == "text":
			# ISOLATING NEWLINES: 
			# By padding \n with spaces, split() will treat it as its own isolated word.
			var raw_content: String = token.content.replace("\n", " \n ")
			var words = raw_content.split(" ", false)
			
			for word in words:
				if word == "\n":
					items.append("\n") # Pass the newline marker to the array
					continue # Skip the rest of the label generation for this character
					
				var prefix := ""
				var suffix := ""
				
				for tag_data in active_tags:
					if tag_data.value != "":
						prefix += "[%s=%s]" % [tag_data.tag, tag_data.value]
					else:
						prefix += "[%s]" % tag_data.tag
				
				for i in range(active_tags.size() - 1, -1, -1):
					suffix += "[/%s]" % active_tags[i].tag
				
				items.append(_create_word_label(prefix + word + suffix))
	
	# 2. Create the first line container
	var current_line := HFlowContainer.new()
	current_line.add_theme_constant_override("h_separation", space)
	current_line.add_theme_constant_override("v_separation", line_spacing)
	
	add_child(current_line)
	
	if debug_children and Engine.is_editor_hint():
		current_line.owner = get_tree().edited_scene_root
	
	# 3. Build the UI
	add_theme_constant_override("separation", line_spacing)
	
	for item in items:
		if typeof(item) == TYPE_STRING and item == "\n":
			# We hit a newline! Spawn a new HFlowContainer line
			if current_line.get_child_count() == 0:
				var child = _create_word_label(" ")
				if debug_children and Engine.is_editor_hint():
					child.owner = get_tree().edited_scene_root
				current_line.add_child(child)
			
			current_line = HFlowContainer.new()
			current_line.add_theme_constant_override("h_separation", space)
			current_line.add_theme_constant_override("v_separation", line_spacing)
			add_child(current_line)
			if debug_children and Engine.is_editor_hint():
				current_line.owner = get_tree().edited_scene_root
		else:
			# It's a word label, add it to the current HFlowContainer line
			current_line.add_child(item)
			if debug_children and Engine.is_editor_hint():
				item.owner = get_tree().edited_scene_root
	
	return


func _create_word_label(p_text: String) -> RichTextLabel:
	var word_label := RichTextLabel.new()
	word_label.bbcode_enabled = true
	word_label.text = p_text
	word_label.add_theme_font_size_override("normal_font_size", font_size)
	word_label.add_theme_font_size_override("bold_font_size", font_size)
	word_label.add_theme_font_size_override("bold_italics_font_size", font_size)
	word_label.add_theme_font_size_override("italics_font_size", font_size)
	word_label.add_theme_font_size_override("mono_font_size", font_size)
	word_label.fit_content = true
	word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	word_label.scroll_active = false
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return word_label
