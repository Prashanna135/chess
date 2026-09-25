extends Control

const BOARD_SCENE_PATH := "res://board/mainboard.tscn"
const START_MENU_PATH := "res://board/start_menu.tscn"

var name_edit: LineEdit
var elo_label: Label
var status_label: Label
var code_display: LineEdit
var join_code_edit: LineEdit
var host_btn: Button
var join_btn: Button
var quick_match_btn: Button
var cancel_btn: Button
var history_list: RichTextLabel
var lan_mode_btn: Button
var internet_mode_btn: Button
var port_forward_hint: Label

var _busy := false
var _host_mode_internet := false
var _vbox: VBoxContainer


func _ready() -> void:
	_build_ui()
	NetworkManager.player_connected.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.lobby_found.connect(_on_lobby_found)
	NetworkManager.invite_code_ready.connect(_on_invite_code_ready)


# Mobile-style UI construction
func _build_ui() -> void:
	# --- Backdrop ---
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.062, 0.09, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = 260.0
	glow.color = Color(0.35, 0.27, 0.14, 0.16)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(glow)

	# --- Safe-area margin ---
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	# --- Header ---
	var title := Label.new()
	title.text = "PLAY ONLINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.97, 0.83, 0.53, 1))
	_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Same WiFi or hotspot. No account needed."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78, 1))
	_vbox.add_child(subtitle)

	# --- Profile card ---
	var profile := _add_card("YOUR PROFILE")

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	profile.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(70, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)

	name_edit = LineEdit.new()
	name_edit.text = ProfileManager.player_name
	name_edit.custom_minimum_size = Vector2(0, 54)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(func(): _on_name_submitted(name_edit.text))
	name_row.add_child(name_edit)

	elo_label = Label.new()
	elo_label.text = "Elo %d" % ProfileManager.elo
	elo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elo_label.add_theme_color_override("font_color", Color(0.77, 0.62, 0.31, 1))
	name_row.add_child(elo_label)

	# --- Host card ---
	var host := _add_card("HOST A GAME")

	var host_label := Label.new()
	host_label.text = "Start a game, then share the invite code with a friend."
	host_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	host_label.add_theme_font_size_override("font_size", 14)
	host_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78, 1))
	host.add_child(host_label)

	var host_mode_row := HBoxContainer.new()
	host_mode_row.add_theme_constant_override("separation", 10)
	host.add_child(host_mode_row)

	lan_mode_btn = Button.new()
	lan_mode_btn.text = "Same WiFi"
	lan_mode_btn.toggle_mode = true
	lan_mode_btn.button_pressed = true
	lan_mode_btn.custom_minimum_size = Vector2(0, 52)
	lan_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_mode_btn.pressed.connect(func(): _set_host_mode(false))
	host_mode_row.add_child(lan_mode_btn)

	internet_mode_btn = Button.new()
	internet_mode_btn.text = "Internet"
	internet_mode_btn.toggle_mode = true
	internet_mode_btn.custom_minimum_size = Vector2(0, 52)
	internet_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	internet_mode_btn.pressed.connect(func(): _set_host_mode(true))
	host_mode_row.add_child(internet_mode_btn)

	port_forward_hint = Label.new()
	port_forward_hint.text = "Forward UDP port %d on your router to this device first." % NetworkManager.GAME_PORT
	port_forward_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	port_forward_hint.visible = false
	port_forward_hint.add_theme_font_size_override("font_size", 13)
	port_forward_hint.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4, 1))
	host.add_child(port_forward_hint)

	host_btn = Button.new()
	host_btn.text = "HOST GAME"
	host_btn.theme_type_variation = "PrimaryButton"
	host_btn.custom_minimum_size = Vector2(0, 60)
	host_btn.pressed.connect(_on_host_pressed)
	host.add_child(host_btn)

	code_display = LineEdit.new()
	code_display.editable = false
	code_display.placeholder_text = "Invite code appears here"
	code_display.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_display.custom_minimum_size = Vector2(0, 56)
	code_display.add_theme_font_size_override("font_size", 22)
	host.add_child(code_display)

	# --- Join card ---
	var join := _add_card("JOIN A GAME")

	var join_label := Label.new()
	join_label.text = "Enter a friend's invite code (WiFi or internet)."
	join_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	join_label.add_theme_font_size_override("font_size", 14)
	join_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78, 1))
	join.add_child(join_label)

	join_code_edit = LineEdit.new()
	join_code_edit.placeholder_text = "Enter invite code"
	join_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_code_edit.custom_minimum_size = Vector2(0, 56)
	join_code_edit.add_theme_font_size_override("font_size", 22)
	join.add_child(join_code_edit)

	join_btn = Button.new()
	join_btn.text = "JOIN"
	join_btn.theme_type_variation = "PrimaryButton"
	join_btn.custom_minimum_size = Vector2(0, 60)
	join_btn.pressed.connect(_on_join_pressed)
	join.add_child(join_btn)

	# --- Quick match ---
	quick_match_btn = Button.new()
	quick_match_btn.text = "QUICK MATCH"
	quick_match_btn.theme_type_variation = "SecondaryButton"
	quick_match_btn.custom_minimum_size = Vector2(0, 60)
	quick_match_btn.pressed.connect(_on_quick_match_pressed)
	_vbox.add_child(quick_match_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_color_override("font_color", Color(0.9, 0.91, 0.94, 1))
	_vbox.add_child(status_label)

	cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.visible = false
	cancel_btn.custom_minimum_size = Vector2(0, 56)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	_vbox.add_child(cancel_btn)

	# --- History card ---
	var history := _add_card("RECENT GAMES")

	history_list = RichTextLabel.new()
	history_list.custom_minimum_size = Vector2(0, 150)
	history_list.bbcode_enabled = true
	history_list.scroll_active = true
	_populate_history()
	history.add_child(history_list)

	# --- Back ---
	var back_btn := Button.new()
	back_btn.text = "BACK TO MAIN MENU"
	back_btn.theme_type_variation = "SecondaryButton"
	back_btn.custom_minimum_size = Vector2(0, 56)
	back_btn.pressed.connect(_on_back_pressed)
	_vbox.add_child(back_btn)

	_vbox.add_child(Control.new())


func _add_card(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "SettingsPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	if title_text != "":
		var lbl := Label.new()
		lbl.text = title_text
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.59, 0.69, 1))
		col.add_child(lbl)

	return col


func _populate_history() -> void:
	var text := ""
	var count = min(10, ProfileManager.history.size())
	for i in range(count):
		var entry = ProfileManager.history[i]
		var sign_str = "+" if entry.elo_change >= 0 else ""
		var result_color = "lime" if entry.result == "win" else ("tomato" if entry.result == "loss" else "yellow")
		text += "[color=%s]%s[/color] vs %s (%d)   %s%d elo\n" % [
			result_color, String(entry.result).capitalize(), entry.opponent, entry.opponent_elo, sign_str, entry.elo_change
		]
	if text == "":
		text = "No games played yet."
	history_list.text = text


func _on_name_submitted(new_text: String) -> void:
	ProfileManager.set_player_name(new_text)
	name_edit.text = ProfileManager.player_name


func _set_host_mode(internet: bool) -> void:
	_host_mode_internet = internet
	lan_mode_btn.button_pressed = not internet
	internet_mode_btn.button_pressed = internet
	port_forward_hint.visible = internet


func _on_host_pressed() -> void:
	if _busy:
		return
	NetworkManager.local_profile = ProfileManager.get_profile_dict()
	if _host_mode_internet:
		status_label.text = "Looking up your public IP..."
		_set_busy(true)
		NetworkManager.host_game_internet()
		return
	var code = NetworkManager.host_game()
	if code == "":
		status_label.text = "Could not host — check that WiFi/network is connected."
		return
	code_display.text = code
	status_label.text = "Waiting for a friend to join with this code..."
	_set_busy(true)


func _on_invite_code_ready(code: String) -> void:
	if code == "":
		status_label.text = "Could not get your public IP. Check your internet connection, or that the router allows outbound requests."
		_set_busy(false)
		return
	code_display.text = code
	status_label.text = "Waiting for a friend to join (make sure UDP %d is forwarded on your router)..." % NetworkManager.GAME_PORT


func _on_join_pressed() -> void:
	if _busy:
		return
	var code = join_code_edit.text
	NetworkManager.local_profile = ProfileManager.get_profile_dict()
	if not NetworkManager.join_with_code(code):
		status_label.text = "That code doesn't look right — double check it."
		return
	status_label.text = "Connecting..."
	_set_busy(true)


func _on_quick_match_pressed() -> void:
	if _busy:
		return
	NetworkManager.local_profile = ProfileManager.get_profile_dict()
	var code = NetworkManager.start_quick_match(NetworkManager.local_profile)
	if code == "":
		status_label.text = "Could not start matchmaking — check your network connection."
		return
	status_label.text = "Searching for a nearby opponent..."
	_set_busy(true)


func _on_lobby_found(info: Dictionary) -> void:
	status_label.text = "Found %s (%d elo) — connecting..." % [info.get("name", "?"), info.get("elo", 1200)]
	NetworkManager.stop_matchmaking()
	NetworkManager.join_with_code(info.get("code", ""))


func _on_connected(profile: Dictionary) -> void:
	GameSettings.mode = GameSettings.Mode.ONLINE
	GameSettings.opponent_name = profile.get("name", "Opponent")
	GameSettings.opponent_elo = profile.get("elo", 1200)
	GameSettings.local_player_color = 0 if NetworkManager.is_host else 1  # host plays White
	get_tree().change_scene_to_file(BOARD_SCENE_PATH)


func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Make sure you're both on the same network."
	_set_busy(false)


func _on_cancel_pressed() -> void:
	NetworkManager.stop_matchmaking()
	NetworkManager.disconnect_game()
	status_label.text = ""
	code_display.text = ""
	_set_busy(false)


func _on_back_pressed() -> void:
	NetworkManager.stop_matchmaking()
	if not NetworkManager.is_host or NetworkManager.remote_peer_id == -1:
		NetworkManager.disconnect_game()
	get_tree().change_scene_to_file(START_MENU_PATH)


func _set_busy(busy: bool) -> void:
	_busy = busy
	host_btn.disabled = busy
	join_btn.disabled = busy
	join_code_edit.editable = not busy
	quick_match_btn.disabled = busy
	lan_mode_btn.disabled = busy
	internet_mode_btn.disabled = busy
	cancel_btn.visible = busy
