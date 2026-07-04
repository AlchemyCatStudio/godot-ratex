@tool
@icon("res://addons/godot_ratex/icon.svg")
class_name RatexLabel
extends VBoxContainer


@export
var debug_children: bool = false

@export_multiline()
var text: String = "":
	set (value):
		text = value
		word_array = parse_bbcode_to_word_array(value)
		generate()

@export var font_size: int = 16:
	set (value):
		font_size = value
		generate()

@export var font_color: Color = Color.BLACK:
	set (value):
		font_color = value
		generate()

@export var space: int = 4:
	set (value):
		space = value
		generate()

@export var line_spacing: int = 4:
	set (value):
		line_spacing = value
		generate()

@export var table_sizing: SizeFlags = SizeFlags.SIZE_EXPAND_FILL:
	set (value):
		table_sizing = value
		generate()

@export var table_border_color: Color = Color(0.4, 0.4, 0.4, 1.0):
	set (value):
		table_border_color = value
		generate()

@export var list_bullet_min_size: float = 15:
	set (value):
		list_bullet_min_size = value
		generate()

var word_array = []


func _find_matching_close_end(p_text: String, start_pos: int, struct_tag: String) -> int:
	var regex := RegEx.new()
	regex.compile("\\[\\/?\\b" + struct_tag + "\\b[^\\]]*\\]")
	var depth := 1
	var pos := start_pos

	while depth > 0:
		var m := regex.search(p_text, pos)
		if not m:
			return -1
		if m.get_string().begins_with("[/"):
			depth -= 1
		else:
			depth += 1
		pos = m.get_end()

	return pos


func _parse_block_structure(p_text: String) -> Array:
	var blocks: Array = []
	var open_regex := RegEx.new()
	open_regex.compile("\\[(table|ul|ol|indent)(?<attrs>[^\\]]*)\\]")
	var last_pos := 0
	var i := 0

	while i < p_text.length():
		var m := open_regex.search(p_text, i)
		if not m:
			break

		var tag: String = m.get_string(1)
		var attrs: String = m.get_string("attrs")
		var opener_start: int = m.get_start()
		var opener_end: int = m.get_end()

		var before = p_text.substr(last_pos, opener_start - last_pos).strip_edges()
		if before != "":
			blocks.append({"type": "paragraph", "bbcode": before})

		var inner_start := opener_end
		var close_end_pos := _find_matching_close_end(p_text, inner_start, tag)

		if close_end_pos == -1:
			i = opener_end
			continue

		var inner = p_text.substr(inner_start, close_end_pos - inner_start - (3 + tag.length()))

		match tag:
			"table":
				blocks.append(_create_table_block(attrs, inner))
			"ul", "ol":
				blocks.append(_create_list_block(tag, attrs, inner))
			"indent":
				blocks.append(_create_indent_block(inner))

		last_pos = close_end_pos
		i = last_pos

	var after = p_text.substr(last_pos).strip_edges()
	if after != "":
		blocks.append({"type": "paragraph", "bbcode": after})

	return blocks


func _create_table_block(attrs: String, inner: String) -> Dictionary:
	var columns := 2
	attrs = attrs.strip_edges()
	if attrs.begins_with("="):
		var eq_val = attrs.substr(1).strip_edges()
		var parts = eq_val.split(",", false)
		if parts.size() > 0 and parts[0].is_valid_int():
			columns = int(parts[0])

	var cells: Array[String] = []
	var cell_regex := RegEx.new()
	cell_regex.compile("\\[cell[^\\]]*\\]([\\s\\S]*?)\\[/cell\\]")
	for cell_match in cell_regex.search_all(inner):
		cells.append(cell_match.get_string(1).strip_edges())

	return {"type": "table", "columns": columns, "cells": cells}


func _create_list_block(tag: String, attrs: String, inner: String) -> Dictionary:
	var bullet := "•"
	var number_type := "1"

	attrs = attrs.strip_edges()

	if tag == "ul":
		var bullet_regex := RegEx.new()
		bullet_regex.compile("bullet\\s*=\\s*(\\S+)")
		var bm := bullet_regex.search(attrs)
		if bm:
			bullet = bm.get_string(1)
	elif tag == "ol":
		var type_regex := RegEx.new()
		type_regex.compile("type\\s*=\\s*(\\S+)")
		var tm := type_regex.search(attrs)
		if tm:
			number_type = tm.get_string(1)

	var items: Array[String] = []
	var struct_regex := RegEx.new()
	struct_regex.compile("\\[(table|ul|ol|indent)[^\\]]*\\]|\\[\\/(table|ul|ol|indent)\\]")
	var structural_open := RegEx.new()
	structural_open.compile("^\\[(table|ul|ol|indent)")
	var item_start := 0
	var depth := 0
	var i := 0

	while i < inner.length():
		if inner[i] == "[":
			var m := struct_regex.search(inner, i)
			if m and m.get_start() == i:
				if m.get_string().begins_with("[/"):
					depth -= 1
				else:
					depth += 1
				i = m.get_end()
				continue
		if inner[i] == "\n" and depth == 0:
			i += 1
			while i < inner.length() and inner[i] == "\n":
				i += 1
			if i < inner.length() and structural_open.search(inner.substr(i)):
				continue
			var line = inner.substr(item_start, i - item_start).strip_edges()
			if line != "":
				items.append(line)
			item_start = i
			continue
		i += 1

	var last = inner.substr(item_start).strip_edges()
	if last != "":
		items.append(last)

	return {"type": "list", "list_tag": tag, "bullet": bullet, "number_type": number_type, "items": items}


func _create_indent_block(inner: String) -> Dictionary:
	var children = _parse_block_structure(inner)
	return {"type": "indent", "children": children}


func generate() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	add_theme_constant_override("separation", line_spacing)

	var blocks = _parse_block_structure(text)
	for block in blocks:
		var control := _build_block(block)
		if control:
			add_child(control)
			if debug_children and Engine.is_editor_hint():
				control.owner = get_tree().edited_scene_root


func _build_block(block: Dictionary, prefix: String = "") -> Control:
	match block.type:
		"paragraph":
			return _build_paragraph(block.bbcode)
		"table":
			return _build_table(block)
		"list":
			return _build_list(block, prefix)
		"indent":
			return _build_indent(block, prefix)
		_:
			return null


func _build_paragraph(bbcode: String) -> Control:
	var tokens = parse_bbcode_to_word_array(bbcode)
	var items: Array = []
	var active_tags: Array[Dictionary] = []
	var align_stack: Array[String] = ["left"]
	var alignment_tags := ["left", "center", "right", "fill"]

	for token in tokens:
		if token.type == "tag":
			if token.tag in alignment_tags:
				if not token.is_close:
					align_stack.push_back(token.tag)
					items.append({"type": "alignment", "value": token.tag})
				else:
					if align_stack.size() > 1:
						align_stack.pop_back()
					items.append({"type": "alignment", "value": align_stack.back() if not align_stack.is_empty() else "left"})
				continue

			if not token.is_close:
				active_tags.append(token)
			else:
				for k in range(active_tags.size() - 1, -1, -1):
					if active_tags[k].tag == token.tag:
						active_tags.remove_at(k)
						break

		elif token.type == "math":
			items.append(_render_math(token.content))

		elif token.type == "image":
			items.append(_build_image(token.path, token.width, token.height))

		elif token.type == "br":
			items.append("\n")

		elif token.type == "text":
			var raw_content: String = token.content.replace("\n", " \n ")
			var words = raw_content.split(" ", false)

			for word in words:
				if word == "\n":
					items.append("\n")
					continue

				var prefix := ""
				var suffix := ""

				for tag_data in active_tags:
					if tag_data.value != "":
						prefix += "[%s=%s]" % [tag_data.tag, tag_data.value]
					else:
						prefix += "[%s]" % tag_data.tag

				for k in range(active_tags.size() - 1, -1, -1):
					suffix += "[/%s]" % active_tags[k].tag

				items.append(_create_word_label(prefix + word + suffix))

	if items.is_empty():
		return null

	var paragraph := VBoxContainer.new()
	paragraph.add_theme_constant_override("separation", line_spacing)

	var current_alignment := "left"
	var current_line: HFlowContainer = null

	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.get("type") == "alignment":
			current_alignment = item.value
			if current_line != null and current_line.get_child_count() > 0:
				current_line = null
			continue

		if typeof(item) == TYPE_STRING and item == "\n":
			if current_line != null and current_line.get_child_count() == 0:
				var spacer = _create_word_label(" ")
				current_line.add_child(spacer)

			current_line = _create_line(current_alignment)
			paragraph.add_child(current_line)
		else:
			if current_line == null:
				current_line = _create_line(current_alignment)
				paragraph.add_child(current_line)
			current_line.add_child(item)

	return paragraph


func _create_line(p_alignment: String) -> HFlowContainer:
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", space)
	line.add_theme_constant_override("v_separation", line_spacing)
	match p_alignment:
		"left":
			line.alignment = FlowContainer.ALIGNMENT_BEGIN
		"center":
			line.alignment = FlowContainer.ALIGNMENT_CENTER
		"right":
			line.alignment = FlowContainer.ALIGNMENT_END
		"fill":
			line.alignment = FlowContainer.ALIGNMENT_BEGIN
	return line


func _build_table(block: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = block.columns
	grid.add_theme_constant_override("h_separation",0)
	grid.add_theme_constant_override("v_separation",0)

	for cell_bbcode in block.cells:
		var cell_content := _build_paragraph(cell_bbcode)

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = table_border_color
		style.bg_color = Color.TRANSPARENT
		style.expand_margin_left = 0.5 * style.border_width_left
		style.expand_margin_top = 0.5 * style.border_width_top
		style.expand_margin_right = 0.5 * style.border_width_right
		style.expand_margin_bottom = 0.5 * style.border_width_bottom
		style.content_margin_left = 4
		style.content_margin_top = 2
		style.content_margin_right = 4
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if cell_content:
			cell_content.size_flags_horizontal = table_sizing
			panel.add_child(cell_content)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, font_size)
			panel.add_child(spacer)

		grid.add_child(panel)

	var remainder : int = block.cells.size() % block.columns
	if remainder > 0:
		for _dummy in range(block.columns - remainder):
			var empty_panel := PanelContainer.new()
			var empty_style := StyleBoxFlat.new()
			empty_style.border_width_left = 1
			empty_style.border_width_top = 1
			empty_style.border_width_right = 1
			empty_style.border_width_bottom = 1
			empty_style.border_color = table_border_color
			empty_style.bg_color = Color.TRANSPARENT
			empty_panel.add_theme_stylebox_override("panel", empty_style)
			empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			grid.add_child(empty_panel)

	return grid


func _build_list(block: Dictionary, prefix: String = "") -> Control:
	var list_container := VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 2)
	var is_ol: bool = block.list_tag == "ol"

	for i in range(block.items.size()):
		var item_bbcode: String = block.items[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var bullet_label := Label.new()
		if is_ol:
			bullet_label.text = prefix
			if prefix != "":
				bullet_label.text += "."
			bullet_label.text += _format_list_number_no_dot(block.number_type, i) + "."
		else:
			bullet_label.text = block.bullet
		bullet_label.add_theme_color_override("font_color", font_color)
		bullet_label.add_theme_font_size_override("font_size", font_size)
		bullet_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bullet_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		bullet_label.custom_minimum_size = Vector2(list_bullet_min_size, 0)
		row.add_child(bullet_label)

		var item_prefix = prefix
		if is_ol:
			if item_prefix != "":
				item_prefix += "."
			item_prefix += str(i + 1)

		var item_blocks = _parse_block_structure(item_bbcode)
		if item_blocks.size() == 1 and item_blocks[0].type == "paragraph":
			var para = _build_paragraph(item_blocks[0].bbcode)
			if para:
				para.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(para)
		else:
			var item_content := VBoxContainer.new()
			item_content.add_theme_constant_override("separation", line_spacing)
			item_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for child_block in item_blocks:
				var child_control := _build_block(child_block, item_prefix)
				if child_control:
					item_content.add_child(child_control)
			row.add_child(item_content)

		list_container.add_child(row)

	return list_container


func _build_indent(block: Dictionary, prefix: String = "") -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", line_spacing)

	for child_block in block.children:
		var child_control := _build_block(child_block, prefix)
		if child_control:
			inner_vbox.add_child(child_control)

	margin.add_child(inner_vbox)
	return margin


## Parses a BBCode string into an Array of token Dictionaries.
func parse_bbcode_to_word_array(p_text: String) -> Array[Dictionary]:
	var parsed_array: Array[Dictionary] = []
	var regex := RegEx.new()

	regex.compile("\\[(?<close>/?)(?<tag>\\w+)(?<attributes>[^\\]]*)\\]")

	var last_end := 0
	var matches: Array = regex.search_all(p_text)
	var i := 0

	while i < matches.size():
		var match: RegExMatch = matches[i]
		var start: int = match.get_start()
		var end: int = match.get_end()
		var is_close_tag := match.get_string("close") == "/"
		var tag_name: String = match.get_string("tag")
		var raw_attributes: String = match.get_string("attributes").strip_edges()

		var content = p_text.substr(last_end, start - last_end)
		if start > last_end and content.strip_edges() != "":
			parsed_array.append({
				"type": "math" if tag_name == "math" and is_close_tag else "text",
				"content": content
			})

		if tag_name == "img" and not is_close_tag:
			var img_attrs := _parse_img_attributes(raw_attributes)
			var img_path_start := end
			var depth := 1
			var j := i + 1
			while j < matches.size() and depth > 0:
				var next_match: RegExMatch = matches[j]
				var next_tag: String = next_match.get_string("tag")
				var next_close := next_match.get_string("close") == "/"
				if next_tag == "img":
					if next_close:
						depth -= 1
					else:
						depth += 1
				j += 1

			if depth == 0:
				var close_match: RegExMatch = matches[j - 1]
				var path = p_text.substr(img_path_start, close_match.get_start() - img_path_start).strip_edges()
				parsed_array.append({
					"type": "image",
					"path": path,
					"width": img_attrs.get("width", -1),
					"height": img_attrs.get("height", -1),
					"valign": img_attrs.get("valign", "")
				})
				last_end = close_match.get_end()
				i = j - 1
			else:
				last_end = end
			i += 1
			continue

		if tag_name == "br" and not is_close_tag:
			parsed_array.append({"type": "br"})
			last_end = end
			i += 1
			continue

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

		last_end = end
		i += 1

	if last_end < p_text.length():
		parsed_array.append({
			"type": "text",
			"content": p_text.substr(last_end)
		})

	return parsed_array


func _render_math(latex_raw: String) -> TextureRect:
	var latex: String = latex_raw.strip_edges()

	var regex = RegEx.new()
	regex.compile("\\\\input{[a-zA-Z0-9_-]*}")
	var regex_matches = regex.search_all(latex)

	for regex_match in regex_matches:
		if regex_match != null:
			var match_string = regex_match.get_string()
			var variable_code = match_string.lstrip("\\input{").rstrip("\\}")

			if variable_code == "":
				variable_code = "\\quad"

			latex = latex.replace(match_string, variable_code)

	var ratex = RaTeXRenderer.new()
	ratex.background_color = Color.TRANSPARENT
	ratex.font_color = font_color
	ratex.font_size = font_size
	ratex.padding = 0
	var svg_string = ratex.render_svg(latex)
	var image = Image.new()
	image.load_svg_from_string(svg_string)
	var texture_rect = TextureRect.new()
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	texture_rect.texture = ImageTexture.create_from_image(image)
	texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return texture_rect


func _build_image(path: String, width: int, height: int) -> Control:
	var texture_rect := TextureRect.new()
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS

	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex = load(path)
		if tex:
			texture_rect.texture = tex
		if texture_rect.texture:
			if width > 0 and height > 0:
				texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture_rect.custom_minimum_size = Vector2(width, height)
				texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
			elif width > 0:
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				texture_rect.custom_minimum_size = Vector2(width, 0)
			elif height > 0:
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
				texture_rect.custom_minimum_size = Vector2(0, height)

	return texture_rect


func _create_word_label(p_text: String) -> RichTextLabel:
	var word_label := RichTextLabel.new()
	word_label.bbcode_enabled = true
	word_label.text = p_text
	word_label.add_theme_color_override("default_color", font_color)
	word_label.add_theme_font_size_override("normal_font_size", font_size)
	word_label.add_theme_font_size_override("bold_font_size", font_size)
	word_label.add_theme_font_size_override("bold_italics_font_size", font_size)
	word_label.add_theme_font_size_override("italics_font_size", font_size)
	word_label.add_theme_font_size_override("mono_font_size", font_size)
	word_label.fit_content = true
	word_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	word_label.scroll_active = false
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.mouse_filter = Control.MOUSE_FILTER_PASS
	return word_label


func _parse_img_attributes(raw: String) -> Dictionary:
	var attrs := {"width": -1, "height": -1, "valign": ""}
	raw = raw.strip_edges()

	if raw == "":
		return attrs

	if raw.begins_with("="):
		var eq_val = raw.substr(1).strip_edges()
		if eq_val.begins_with('"') and eq_val.ends_with('"'):
			eq_val = eq_val.substr(1, eq_val.length() - 2)

		if "x" in eq_val:
			var parts = eq_val.split("x", false, 1)
			attrs.width = _parse_dimension(parts[0])
			if parts.size() > 1:
				attrs.height = _parse_dimension(parts[1])
		elif eq_val in ["top", "center", "bottom", "baseline"]:
			attrs.valign = eq_val
		else:
			attrs.width = _parse_dimension(eq_val)
	else:
		_parse_named_params(raw, attrs, ["width", "height"])

	return attrs


func _parse_named_params(raw: String, target: Dictionary, numeric_keys: Array) -> void:
	var i := 0
	while i < raw.length():
		while i < raw.length() and raw[i] == " ":
			i += 1

		var eq_pos := raw.find("=", i)
		if eq_pos == -1:
			break

		var key := raw.substr(i, eq_pos - i).strip_edges()
		i = eq_pos + 1

		var value: String
		if i < raw.length() and raw[i] == '"':
			var end_quote := raw.find('"', i + 1)
			if end_quote != -1:
				value = raw.substr(i + 1, end_quote - i - 1)
				i = end_quote + 1
			else:
				value = ""
				i = raw.length()
		else:
			var space_pos := raw.find(" ", i)
			if space_pos == -1:
				value = raw.substr(i)
				i = raw.length()
			else:
				value = raw.substr(i, space_pos - i)
				i = space_pos

		if key in numeric_keys:
			target[key] = _parse_dimension(value)
		else:
			target[key] = value


func _parse_dimension(s: String) -> int:
	s = s.strip_edges()
	if s == "":
		return -1
	if s.ends_with("%"):
		return -int(s.rstrip("%"))
	elif s.ends_with("em"):
		return int(float(s.rstrip("em")) * font_size)
	else:
		return int(s)


func _to_roman(n: int) -> String:
	var values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var result := ""
	for k in range(values.size()):
		while n >= values[k]:
			result += numerals[k]
			n -= values[k]
	return result


func _format_list_number(type: String, index: int) -> String:
	return _format_list_number_no_dot(type, index) + "."


func _format_list_number_no_dot(type: String, index: int) -> String:
	var n := index + 1
	match type:
		"1":
			return str(n)
		"a":
			return char(97 + (n - 1) % 26)
		"A":
			return char(65 + (n - 1) % 26)
		"i":
			return _to_roman(n).to_lower()
		"I":
			return _to_roman(n)
		_:
			return str(n)
