extends Node2D
## Controls menu: lists every rebindable action and lets the player pick a new key
## (keyboard tab) or a new gamepad button/stick direction (gamepad tab).
## It is created and shown by options_menu.gd, which sits behind it.
## The UI is built in code so there is no scene to keep in sync.

signal closed

const TEXT_BUTTON = preload("res://ui_scenes/mainMenu/textbutton/text_button.tscn")
const ROW_HEIGHT := 18
const KEY_COLUMN_X := 102
const GRAY := Color(0.368627, 0.368627, 0.368627, 1)

const PAD_WAIT_SECONDS := 8.0 # a gamepad-only player can't press esc, so waiting times out

var keyButtons :Dictionary = {} # action : text_button
var waitingFor :String = ""
var hintLabel :Label
var padMode :bool = false # false = keyboard tab, true = gamepad tab
var scroll :ScrollContainer
var content :Control
var modeButton
var waitLeft :float = 0.0

func _ready():
	_buildUI()
	_populateRows()
	refreshAll()

func _buildUI():
	# title
	var title := Label.new()
	title.text = "controls"
	title.position = Vector2(9, 11)
	title.size = Vector2(180, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 32
	ls.font_color = GRAY
	title.label_settings = ls
	add_child(title)
	
	# scrolling list of rows (filled in by _populateRows, which depends on the tab)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(9, 49)
	scroll.size = Vector2(177, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# reuse the options menu's scrollbar look if it is available
	var optionsScroll = get_parent().get_node_or_null("ScrollContainer")
	if optionsScroll != null:
		scroll.theme = optionsScroll.theme
	add_child(scroll)
	
	# hint / status line
	hintLabel = Label.new()
	hintLabel.position = Vector2(9, 247)
	hintLabel.size = Vector2(180, 16)
	hintLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hintLabel.modulate = GRAY
	hintLabel.text = _idleHint()
	add_child(hintLabel)
	
	# reset + done buttons (same spots as the options menu's OK button)
	var reset = TEXT_BUTTON.instantiate()
	reset.position = Vector2(12, 267)
	add_child(reset)
	reset.forceChangeText("reset")
	reset.pressed.connect(_on_reset_pressed)
	
	# keyboard / gamepad tab switch
	modeButton = TEXT_BUTTON.instantiate()
	modeButton.position = Vector2(66, 267)
	add_child(modeButton)
	modeButton.forceChangeText("keyboard")
	modeButton.pressed.connect(_on_mode_pressed)
	
	var done = TEXT_BUTTON.instantiate()
	done.position = Vector2(170, 267)
	add_child(done)
	done.forceChangeText("OK")
	done.pressed.connect(_on_done_pressed)

func _idleHint() -> String:
	return "click a button to change it" if padMode else "click a key to change it"

## (Re)builds the list of rows for the current tab.
func _populateRows():
	keyButtons.clear()
	if is_instance_valid(content):
		scroll.remove_child(content)
		content.queue_free()
	
	var entries :Array = Gamepad.PAD_ACTIONS if padMode else Options.REBINDABLE
	
	content = Control.new()
	content.custom_minimum_size = Vector2(3, entries.size() * ROW_HEIGHT + 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	scroll.scroll_vertical = 0
	
	var y := 2
	for entry in entries:
		var action :String = entry[0]
		
		var label := Label.new()
		label.text = entry[1]
		label.modulate = GRAY
		label.position = Vector2(10, y)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		
		var button = TEXT_BUTTON.instantiate()
		button.position = Vector2(KEY_COLUMN_X, y)
		content.add_child(button)
		button.pressed.connect(_on_key_button_pressed.bind(action))
		keyButtons[action] = button
		
		y += ROW_HEIGHT

func _on_mode_pressed():
	stopWaiting()
	padMode = !padMode
	modeButton.forceChangeText("gamepad" if padMode else "keyboard")
	_populateRows()
	refreshAll()
	hintLabel.text = _idleHint()

func refreshAll():
	for action in keyButtons:
		if padMode:
			keyButtons[action].forceChangeText(Gamepad.bindName(Gamepad.getBind(action)))
		else:
			keyButtons[action].forceChangeText(Options.keyName(Options.getKeybind(action)))

func _on_key_button_pressed(action:String):
	if waitingFor == action: # clicking again cancels
		stopWaiting()
		hintLabel.text = _idleHint()
		return
	if waitingFor != "":
		stopWaiting()
	
	waitingFor = action
	Options.suspendKeybinds()
	if padMode:
		Gamepad.capturing = true # freeze the stick cursor + bumper clicks while listening
		waitLeft = PAD_WAIT_SECONDS
		keyButtons[action].forceChangeText("press input...")
		hintLabel.text = "esc / wait = cancel"
	else:
		keyButtons[action].forceChangeText("press a key...")
		hintLabel.text = "esc = cancel"

func stopWaiting():
	if waitingFor == "":
		return
	waitingFor = ""
	Gamepad.capturing = false
	Options.resumeKeybinds()
	refreshAll()

func _process(delta):
	# gamepad capture gives up by itself (there may be no keyboard to press esc on)
	if waitingFor != "" and padMode:
		waitLeft -= delta
		if waitLeft <= 0.0:
			stopWaiting()
			hintLabel.text = "cancelled"

func _input(event):
	if waitingFor == "":
		return
	
	if padMode:
		# esc still cancels, anything on the gamepad is the new binding
		if event is InputEventKey and event.pressed and !event.echo and event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			stopWaiting()
			hintLabel.text = _idleHint()
			return
		var bind :Dictionary = Gamepad.bindFromEvent(event)
		if bind.is_empty():
			return
		get_viewport().set_input_as_handled()
		var padAction := waitingFor
		# give the real binds back first, then apply the new one
		waitingFor = ""
		Gamepad.capturing = false
		Options.resumeKeybinds()
		var padSwapped :String = Gamepad.setBind(padAction,bind)
		refreshAll()
		hintLabel.text = ("swapped with: " + padSwapped) if padSwapped != "" else "saved!"
		return
	
	if !(event is InputEventKey) or !event.pressed or event.echo:
		return
	
	get_viewport().set_input_as_handled()
	
	var action := waitingFor
	if event.physical_keycode == KEY_ESCAPE:
		stopWaiting()
		hintLabel.text = _idleHint()
		return
	
	# give the real keybinds back first, then apply the new one
	waitingFor = ""
	Options.resumeKeybinds()
	var swapped :String = Options.setKeybind(action,event.physical_keycode)
	refreshAll()
	
	if swapped != "":
		hintLabel.text = "swapped with: " + swapped
	else:
		hintLabel.text = "saved!"

func _on_reset_pressed():
	stopWaiting()
	if padMode:
		Gamepad.resetBinds()
	else:
		Options.resetKeybinds()
	refreshAll()
	hintLabel.text = "controls reset"

func _on_done_pressed():
	stopWaiting()
	emit_signal("closed")

# if the menu gets hidden/removed while waiting for a key (e.g. unpausing), don't leave controls disabled
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and !is_visible_in_tree():
		stopWaiting()

func _exit_tree():
	stopWaiting()
