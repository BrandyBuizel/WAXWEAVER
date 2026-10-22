extends CanvasLayer
## Debug menu. Press the toggle key (F1 by default) while in a world to open it.
## Every button calls the same code the slash commands in hotbar_banner.gd use,
## so there's nothing to type. UI is built in code, no .tscn needed.
##
## Keyboard controls (mouse still works too):
##   up / down    move between rows (first row is the tab bar)
##   left / right change tab (on tab bar), change a number / dropdown, jump in item list
##   shift        hold with left/right for x10 steps
##   ctrl         select: toggle a checkbox, press a button, give the highlighted item
##
## Note: F3 is already taken by the "screenshot" action, F1 is free.

const TOGGLE_KEY := KEY_F1
## the game's HUD labels use GrapeSoda at its default size 16 (32 on the pause menu),
## so 16 is what matches. 8 looks half-size and blurry.
const FONT_SIZE := 16
const PANEL_WIDTH := 236
const HIGHLIGHT := Color(1.0, 0.9, 0.3)

## all status effect names (files in statusEffects/resources/*.tres)
const EFFECTS :Array[String] = [
	"burning","confused","focused","fragile","frozen","glowing","goodRegen",
	"normalRegen","poison","regen","suffocating","teleportsickness","tough","wet",
]

## fraction of the day (0.0 - 1.0). Darkest at 0.75, brightest around 0.25.
const TIME_PRESETS :Dictionary = {
	"Dawn": 0.0,
	"Noon": 0.25,
	"Dusk": 0.5,
	"Midnight": 0.75,
}

var panel :PanelContainer
var tabs :TabContainer

# keyboard navigation state. tabRows[tab] = array of {kind, ctrl, hl}
var tabRows :Array = [[], [], [], []]
var building :int = 0
var curTab :int = 0
var curRow :int = -1 # -1 = the tab bar itself

# player tab
var godCheck :CheckButton
var flyCheck :CheckButton
var noclipCheck :CheckButton
var fullbrightCheck :CheckButton
var flySpeedSpin :SpinBox

# time tab
var timeLabel :Label
var tickSpin :SpinBox

# effects tab
var effectOption :OptionButton
var effectSecs :SpinBox

# items tab
var itemFilter :LineEdit
var itemList :ItemList
var itemAmount :SpinBox
var allItemIds :Array[int] = []


func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buildUI()
	panel.hide()


func _input(event):
	if event is InputEventKey and event.pressed:
		# toggle / close
		if !event.echo and event.keycode == TOGGLE_KEY:
			_toggleMenu()
			get_viewport().set_input_as_handled()
			return
		if !panel.visible:
			return
		
		# typing in the search box: these keys hand control back to the menu
		var focused := panel.get_viewport().gui_get_focus_owner()
		if focused is LineEdit:
			if event.keycode in [KEY_ESCAPE, KEY_CTRL, KEY_UP, KEY_DOWN]:
				focused.release_focus()
				get_viewport().set_input_as_handled()
			return
		
		match event.keycode:
			KEY_ESCAPE:
				if !event.echo:
					_setOpen(false)
			KEY_UP:
				_navV(-1)
			KEY_DOWN:
				_navV(1)
			KEY_LEFT:
				_navH(-1, event.shift_pressed)
			KEY_RIGHT:
				_navH(1, event.shift_pressed)
			KEY_CTRL:
				if !event.echo:
					_activate()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	
	# clicking away from a text box lets go of it so WASD works again
	if event is InputEventMouseButton and event.pressed and panel.visible:
		var focused := panel.get_viewport().gui_get_focus_owner()
		if focused is LineEdit and !focused.get_global_rect().has_point(event.position):
			focused.release_focus()


# ============================ keyboard navigation ==========================

func _reg(kind :String, ctrl :Control, hl :Control):
	tabRows[building].append({"kind": kind, "ctrl": ctrl, "hl": hl})


func _refreshHighlight():
	for rows in tabRows:
		for r in rows:
			r["hl"].modulate = Color.WHITE
	tabs.get_tab_bar().modulate = Color.WHITE
	if curRow < 0:
		tabs.get_tab_bar().modulate = HIGHLIGHT
	else:
		tabRows[curTab][curRow]["hl"].modulate = HIGHLIGHT


func _selectItem(i :int):
	itemList.select(i)
	itemList.ensure_current_is_visible()


func _selectedItemIndex() -> int:
	var sel := itemList.get_selected_items()
	return sel[0] if sel.size() > 0 else 0


func _navV(dir :int):
	var rows :Array = tabRows[curTab]
	# inside the item list, up/down walk the list until its ends
	if curRow >= 0 and rows[curRow]["kind"] == "list":
		var ni := _selectedItemIndex() + dir
		if ni >= 0 and ni < itemList.item_count:
			_selectItem(ni)
			return
	curRow += dir
	if curRow >= rows.size():
		curRow = -1
	elif curRow < -1:
		curRow = rows.size() - 1
	_refreshHighlight()


func _navH(dir :int, big :bool):
	if curRow < 0: # on the tab bar: switch tabs
		curTab = wrapi(curTab + dir, 0, tabs.get_tab_count())
		tabs.current_tab = curTab
		_refreshHighlight()
		return
	var row :Dictionary = tabRows[curTab][curRow]
	match row["kind"]:
		"spin":
			var sp :SpinBox = row["ctrl"]
			sp.value = sp.value + dir * sp.step * (10.0 if big else 1.0)
		"option":
			var op :OptionButton = row["ctrl"]
			op.select(wrapi(op.selected + dir, 0, op.item_count))
		"list":
			if itemList.item_count > 0:
				var jump := 50 if big else 10
				_selectItem(clampi(_selectedItemIndex() + dir * jump, 0, itemList.item_count - 1))


func _activate():
	if curRow < 0:
		return
	var row :Dictionary = tabRows[curTab][curRow]
	match row["kind"]:
		"check":
			var c :CheckButton = row["ctrl"]
			c.button_pressed = !c.button_pressed # fires the toggled signal
		"button":
			(row["ctrl"] as Button).pressed.emit()
		"list":
			_onGiveItem()
		"search":
			(row["ctrl"] as LineEdit).grab_focus()


func _process(_delta):
	if !panel.visible:
		return
	if !_inGame():
		_setOpen(false)
		return
	timeLabel.text = "tick %d  |  day %d  |  time %.2f" % [
		GlobalRef.globalTick,
		GlobalRef.globalTick / GlobalRef.dayLength,
		GlobalRef.currentTime,
	]


# ============================== open / close ===============================

func _inGame() -> bool:
	return is_instance_valid(GlobalRef.player) and is_instance_valid(GlobalRef.system) \
		and is_instance_valid(GlobalRef.hotbar)


func _toggleMenu():
	if panel.visible:
		_setOpen(false)
	elif _inGame():
		_setOpen(true)


func _setOpen(open :bool):
	panel.visible = open
	if open:
		_syncToggles()
		_refreshHighlight()
	else:
		var focused := panel.get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		_updateChatLock()


## makes the checkboxes match what's really going on in the game
func _syncToggles():
	var p :Player = GlobalRef.player
	godCheck.set_pressed_no_signal(p.healthComponent.god)
	flyCheck.set_pressed_no_signal(p.flyAllowed)
	noclipCheck.set_pressed_no_signal(p.noClip)
	flySpeedSpin.set_value_no_signal(p.flySpeed)
	if is_instance_valid(GlobalRef.lightmap):
		fullbrightCheck.set_pressed_no_signal(!GlobalRef.lightmap.visible)


## stops the player walking around while you type numbers / search text
func _updateChatLock():
	var typing := false
	var focused := panel.get_viewport().gui_get_focus_owner()
	if panel.visible and focused is LineEdit:
		typing = true
	var cheatBoxOpen := false
	if is_instance_valid(GlobalRef.hotbar):
		cheatBoxOpen = GlobalRef.hotbar.cheatOrigin.visible
	GlobalRef.chatIsOpen = typing or cheatBoxOpen


func _hookTextFocus(le :LineEdit):
	le.focus_entered.connect(_updateChatLock)
	le.focus_exited.connect(func(): _updateChatLock.call_deferred())


# ============================= cheat permission ============================

## true = skip the game's cheat system completely: no host-only check, and the
## save is NOT flipped to "cheats enabled". Buttons just run the code directly.
## false = behave like the /commands (host only, first use enables cheats and
## locks achievements for that save).
const BYPASS_CHEAT_SYSTEM := true

func _allowed() -> bool:
	if !_inGame():
		return false
	if BYPASS_CHEAT_SYSTEM:
		return true
	if Network.isMultiplayerGame and !Network.is_host:
		GlobalRef.sendChat("You don't have permission to use commands!")
		return false
	if !GlobalRef.cheatsEnabled:
		GlobalRef.cheatsEnabled = true
		Saving.autosave()
		GlobalRef.sendChat("Cheats enabled!")
		GlobalRef.sendChat("This save can no longer earn achievements.")
	return true


# ================================ actions ==================================

func _onGod(pressed :bool):
	if !_allowed():
		godCheck.set_pressed_no_signal(!pressed)
		return
	GlobalRef.player.healthComponent.god = pressed
	GlobalRef.sendChat("God mode: " + str(pressed))


func _onFly(pressed :bool):
	if !_allowed():
		flyCheck.set_pressed_no_signal(!pressed)
		return
	var p :Player = GlobalRef.player
	if p.flyAllowed != pressed:
		p.toggleFly() # no speed arg = plain on/off
	if pressed:
		GlobalRef.sendChat("Flight enabled! Double-tap space to start/stop flying.")
		GlobalRef.sendChat("Space = up, shift = down. Speed: " + str(p.flySpeed))
	else:
		GlobalRef.sendChat("Flight disabled.")


func _onFlySpeed(value :float):
	if _inGame():
		GlobalRef.player.flySpeed = value


func _onNoclip(pressed :bool):
	if !_allowed():
		noclipCheck.set_pressed_no_signal(!pressed)
		return
	if GlobalRef.player.noClip != pressed:
		GlobalRef.player.toggleNoClip()
	GlobalRef.sendChat("Noclip: " + str(pressed))


func _onFullbright(pressed :bool):
	if !_allowed() or !is_instance_valid(GlobalRef.lightmap):
		fullbrightCheck.set_pressed_no_signal(!pressed)
		return
	GlobalRef.lightmap.visible = !pressed
	GlobalRef.sendChat("Fullbright: " + ("ENABLED" if pressed else "DISABLED"))


func _onHeal():
	if !_allowed():
		return
	GlobalRef.player.healthComponent.heal(99999)
	GlobalRef.sendChat("Healed player.")


func _onRich():
	if !_allowed():
		return
	PlayerData.addMoney(1000)
	GlobalRef.sendChat("Added 1000 money")


func _onKit():
	if !_allowed():
		return
	# same list as the /kit command
	for entry in [[3153,1],[3154,1],[3158,1],[3032,4],[3035,198],[3155,1],
			[3156,1],[3157,1],[3092,1],[3145,1]]:
		PlayerData.addItem(entry[0], entry[1])
	GlobalRef.sendChat("Gave starter kit.")


func _onTimePreset(fraction :float):
	if !_allowed():
		return
	var dl :int = GlobalRef.dayLength
	var dayStart :int = (GlobalRef.globalTick / dl) * dl # keep the current day number
	GlobalRef.globalTick = dayStart + int(fraction * dl)
	GlobalRef.sendChat("Time set.")


## same as "/tick <number>": moves the clock forward by that many ticks
func _onAddTicks():
	if !_allowed():
		return
	var amount := int(tickSpin.value)
	GlobalRef.globalTick += amount
	GlobalRef.sendChat("Advanced time by " + str(amount / 15.0) + " seconds.")


func _onApplyEffect():
	if !_allowed():
		return
	var effect :String = effectOption.get_item_text(effectOption.selected)
	var secs := float(effectSecs.value)
	GlobalRef.player.healthComponent.inflictStatus(effect, secs)
	GlobalRef.sendChat("Inflicted player with " + effect + " for " + str(secs) + " seconds.")


func _onClearEffects():
	if !_allowed():
		return
	GlobalRef.player.healthComponent.clearAllStatus()
	GlobalRef.sendChat("Cleared all effects.")


func _onGiveItem():
	if !_allowed():
		return
	var sel := itemList.get_selected_items()
	if sel.is_empty():
		GlobalRef.sendError("Select an item first.")
		return
	var id :int = itemList.get_item_metadata(sel[0])
	var amount := int(itemAmount.value)
	PlayerData.addItem(id, amount)
	GlobalRef.sendChat("Gave player " + str(amount) + " " + ItemData.getItemName(id))


func _rebuildItemList(filter :String = ""):
	itemList.clear()
	var f := filter.strip_edges().to_lower()
	for id in allItemIds:
		var itemName :String = ItemData.getItemName(id)
		if f != "" and !itemName.to_lower().contains(f) and str(id) != f:
			continue
		var tex = ItemData.getItemTexture(id)
		var idx :int
		if tex is Texture2D:
			idx = itemList.add_item("%s [%d]" % [itemName, id], tex)
		else:
			idx = itemList.add_item("%s [%d]" % [itemName, id])
		itemList.set_item_metadata(idx, id)
	if itemList.item_count > 0:
		itemList.select(0)


# ================================== UI =====================================

func _buildUI():
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	# black text outline like the rest of the game's HUD
	for type in ["Label", "Button", "CheckButton", "OptionButton", "TabBar", "ItemList"]:
		theme.set_color("font_outline_color", type, Color.BLACK)
		theme.set_constant("outline_size", type, 3)
	
	panel = PanelContainer.new()
	panel.theme = theme
	panel.position = Vector2(4, 4)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.93)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	panel.add_child(root)
	
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	
	building = 0
	tabs.add_child(_buildPlayerTab())
	building = 1
	tabs.add_child(_buildTimeTab())
	building = 2
	tabs.add_child(_buildEffectsTab())
	building = 3
	tabs.add_child(_buildItemsTab())


func _tab(tabName :String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = tabName
	box.add_theme_constant_override("separation", 2)
	return box


func _button(text :String, callback :Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE # so space/enter don't re-press it mid-game
	b.pressed.connect(callback)
	return b


func _check(text :String, callback :Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(callback)
	return c


func _spin(minV :float, maxV :float, value :float, step :float = 1.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minV
	s.max_value = maxV
	s.step = step
	s.value = value
	s.select_all_on_focus = true
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hookTextFocus(s.get_line_edit())
	return s


func _row(label :String, control :Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 76
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func _buildPlayerTab() -> Control:
	var t := _tab("Player")
	
	godCheck = _check("God mode", _onGod)
	t.add_child(godCheck)
	_reg("check", godCheck, godCheck)
	flyCheck = _check("Fly (2x space)", _onFly)
	t.add_child(flyCheck)
	_reg("check", flyCheck, flyCheck)
	flySpeedSpin = _spin(50, 2000, 300, 25)
	flySpeedSpin.value_changed.connect(_onFlySpeed)
	var flyRow := _row("fly speed", flySpeedSpin)
	t.add_child(flyRow)
	_reg("spin", flySpeedSpin, flyRow)
	noclipCheck = _check("Noclip", _onNoclip)
	t.add_child(noclipCheck)
	_reg("check", noclipCheck, noclipCheck)
	fullbrightCheck = _check("Fullbright", _onFullbright)
	t.add_child(fullbrightCheck)
	_reg("check", fullbrightCheck, fullbrightCheck)
	
	t.add_child(HSeparator.new())
	for entry in [["Instant heal", _onHeal], ["+1000 money", _onRich], ["Starter kit", _onKit]]:
		var b := _button(entry[0], entry[1])
		t.add_child(b)
		_reg("button", b, b)
	return t


func _buildTimeTab() -> Control:
	var t := _tab("Time")
	
	timeLabel = Label.new()
	timeLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(timeLabel)
	
	t.add_child(HSeparator.new())
	for presetName in TIME_PRESETS:
		var b := _button(presetName, _onTimePreset.bind(TIME_PRESETS[presetName]))
		t.add_child(b)
		_reg("button", b, b)
	
	t.add_child(HSeparator.new())
	var info := Label.new()
	info.text = "like /tick:"
	t.add_child(info)
	tickSpin = _spin(-100000, 100000, 1000, 100)
	var tickRow := _row("ticks", tickSpin)
	t.add_child(tickRow)
	_reg("spin", tickSpin, tickRow)
	var advance := _button("Advance time", _onAddTicks)
	t.add_child(advance)
	_reg("button", advance, advance)
	return t


func _buildEffectsTab() -> Control:
	var t := _tab("Effects")
	
	effectOption = OptionButton.new()
	effectOption.focus_mode = Control.FOCUS_NONE
	for e in EFFECTS:
		effectOption.add_item(e)
	var effectRow := _row("effect", effectOption)
	t.add_child(effectRow)
	_reg("option", effectOption, effectRow)
	
	effectSecs = _spin(5, 99999, 60, 5)
	var secsRow := _row("seconds", effectSecs)
	t.add_child(secsRow)
	_reg("spin", effectSecs, secsRow)
	
	var apply := _button("Apply to me", _onApplyEffect)
	t.add_child(apply)
	_reg("button", apply, apply)
	var clear := _button("Clear all effects", _onClearEffects)
	t.add_child(clear)
	_reg("button", clear, clear)
	return t


func _buildItemsTab() -> Control:
	var t := _tab("Items")
	
	# collect every real item id once
	var ids :Array = ItemData.data.keys()
	ids.sort()
	for id in ids:
		if id == -1 or id == 0: # -1 is empty, 0 just aliases stone
			continue
		if ItemData.getItemName(id) == "":
			continue
		allItemIds.append(id)
	
	itemFilter = LineEdit.new()
	itemFilter.placeholder_text = "search..."
	itemFilter.clear_button_enabled = true
	itemFilter.text_changed.connect(_rebuildItemList)
	_hookTextFocus(itemFilter)
	t.add_child(itemFilter)
	_reg("search", itemFilter, itemFilter)
	
	itemList = ItemList.new()
	itemList.size_flags_vertical = Control.SIZE_EXPAND_FILL
	itemList.custom_minimum_size.y = 84
	itemList.fixed_icon_size = Vector2i(16, 16)
	itemList.focus_mode = Control.FOCUS_NONE
	itemList.item_activated.connect(func(_i): _onGiveItem()) # double click = give
	t.add_child(itemList)
	_reg("list", itemList, itemList)
	_rebuildItemList()
	
	itemAmount = _spin(1, 9999, 1, 1)
	var amountRow := _row("amount", itemAmount)
	t.add_child(amountRow)
	_reg("spin", itemAmount, amountRow)
	var give := _button("Give to me", _onGiveItem)
	t.add_child(give)
	_reg("button", give, give)
	return t
