extends Node
## Gamepad support.
##
## - Right stick moves the on-screen cursor (the same cursor the mouse uses), so aiming,
##   menus, the inventory and the pause menu all work without touching the mouse.
## - Right trigger = left click (break / attack), left trigger = right click (place / use).
## - Left stick walks with analog speed (see player.gd), bumper left/right cycles the hotbar.
## - Every binding can be changed in options > controls > gamepad.
##
## Cursor movement and clicks are fed to the game as real mouse events, so no other
## script has to know a gamepad exists.

const CURSOR_SPEED := 300.0   # game pixels per second with the stick fully pushed
const CURSOR_DEADZONE := 0.2
const CURSOR_CURVE := 1.6     # >1 = gentle near the centre for precise aiming, fast at the edge

## Actions shown in the gamepad tab of the controls menu: [action, label]
const PAD_ACTIONS :Array = [
	["move_left","move left"],
	["move_right","move right"],
	["move_up","move up/climb"],
	["move_down","move down"],
	["jump","jump"],
	["crouch","crouch"],
	["pad_break","break / attack"],
	["pad_place","place / use"],
	["aim_left","cursor left"],
	["aim_right","cursor right"],
	["aim_up","cursor up"],
	["aim_down","cursor down"],
	["pad_hotbar_prev","hotbar prev"],
	["pad_hotbar_next","hotbar next"],
	["inventory","inventory"],
	["shift","stack modifier"],
	["pause","pause"],
	["openCommand","chat/command"],
	["fullscreen","fullscreen"],
	["screenshot","screenshot"],
]

## Actions that only exist for the gamepad (created at startup)
const PAD_ONLY_ACTIONS :Array = [
	"pad_break","pad_place","pad_hotbar_prev","pad_hotbar_next",
	"aim_left","aim_right","aim_up","aim_down",
]

## Default layout (Xbox naming). Anything not listed is unbound.
## {"t":"b","i":button} = button, {"t":"a","i":axis,"v":-1 or 1} = stick/trigger direction
const DEFAULT_BINDS :Dictionary = {
	"move_left":  {"t":"a","i":JOY_AXIS_LEFT_X,"v":-1},
	"move_right": {"t":"a","i":JOY_AXIS_LEFT_X,"v":1},
	"move_up":    {"t":"a","i":JOY_AXIS_LEFT_Y,"v":-1},
	"move_down":  {"t":"a","i":JOY_AXIS_LEFT_Y,"v":1},
	"jump":       {"t":"b","i":JOY_BUTTON_A},
	"crouch":     {"t":"b","i":JOY_BUTTON_X},
	"inventory":  {"t":"b","i":JOY_BUTTON_Y},
	"shift":      {"t":"b","i":JOY_BUTTON_B},
	"pause":      {"t":"b","i":JOY_BUTTON_START},
	"pad_break":  {"t":"a","i":JOY_AXIS_TRIGGER_RIGHT,"v":1},
	"pad_place":  {"t":"a","i":JOY_AXIS_TRIGGER_LEFT,"v":1},
	"pad_hotbar_prev": {"t":"b","i":JOY_BUTTON_LEFT_SHOULDER},
	"pad_hotbar_next": {"t":"b","i":JOY_BUTTON_RIGHT_SHOULDER},
	"aim_left":   {"t":"a","i":JOY_AXIS_RIGHT_X,"v":-1},
	"aim_right":  {"t":"a","i":JOY_AXIS_RIGHT_X,"v":1},
	"aim_up":     {"t":"a","i":JOY_AXIS_RIGHT_Y,"v":-1},
	"aim_down":   {"t":"a","i":JOY_AXIS_RIGHT_Y,"v":1},
}

const BUTTON_NAMES :Dictionary = {
	JOY_BUTTON_A:"A", JOY_BUTTON_B:"B", JOY_BUTTON_X:"X", JOY_BUTTON_Y:"Y",
	JOY_BUTTON_BACK:"back", JOY_BUTTON_GUIDE:"guide", JOY_BUTTON_START:"start",
	JOY_BUTTON_LEFT_STICK:"L3", JOY_BUTTON_RIGHT_STICK:"R3",
	JOY_BUTTON_LEFT_SHOULDER:"LB", JOY_BUTTON_RIGHT_SHOULDER:"RB",
	JOY_BUTTON_DPAD_UP:"D-up", JOY_BUTTON_DPAD_DOWN:"D-down",
	JOY_BUTTON_DPAD_LEFT:"D-left", JOY_BUTTON_DPAD_RIGHT:"D-right",
	JOY_BUTTON_MISC1:"misc", JOY_BUTTON_PADDLE1:"paddle1", JOY_BUTTON_PADDLE2:"paddle2",
	JOY_BUTTON_PADDLE3:"paddle3", JOY_BUTTON_PADDLE4:"paddle4", JOY_BUTTON_TOUCHPAD:"touchpad",
}

## True while the controls menu is waiting for the player to press a gamepad input.
## Everything below stands still so the press isn't also treated as a click or cursor move.
var capturing :bool = false

var _cursor :Vector2 = Vector2.ZERO # sub-pixel cursor position in game (viewport) pixels
var _held :Dictionary = {MOUSE_BUTTON_LEFT:false, MOUSE_BUTTON_RIGHT:false} # virtual buttons currently down


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # the cursor has to work in the pause menu too
	_registerPadOnlyActions()
	applyAllBinds()


######################################################################
############################ CURSOR / CLICKS #########################
######################################################################

func _process(delta:float):
	if capturing or !_windowFocused():
		_releaseAll()
		return
	
	_moveCursor(delta)
	
	_handleVirtualClick("pad_break",MOUSE_BUTTON_LEFT)
	_handleVirtualClick("pad_place",MOUSE_BUTTON_RIGHT)
	
	if Input.is_action_just_pressed("pad_hotbar_prev"):
		_cycleHotbar(-1)
	if Input.is_action_just_pressed("pad_hotbar_next"):
		_cycleHotbar(1)

func _windowFocused() -> bool:
	return DisplayServer.window_is_focused()

func _moveCursor(delta:float):
	var stick :Vector2 = Input.get_vector("aim_left","aim_right","aim_up","aim_down",CURSOR_DEADZONE)
	if stick == Vector2.ZERO:
		return
	
	var vp :Viewport = get_viewport()
	
	# If a real mouse moved the cursor since last frame, continue from where it is now.
	# Small differences are just the OS rounding our own position, so those are ignored
	# (this keeps slow, sub-pixel stick movement from being rounded away).
	var actual :Vector2 = vp.get_mouse_position()
	if actual.distance_to(_cursor) > 2.5:
		_cursor = actual
	
	var amount :float = pow(stick.length(),CURSOR_CURVE)
	_cursor += stick.normalized() * amount * CURSOR_SPEED * delta
	
	var area :Vector2 = vp.get_visible_rect().size
	_cursor = _cursor.clamp(Vector2.ZERO,area - Vector2.ONE)
	
	_sendMotion(_cursor)

## Window ("screen") position of a game-pixel position. Injected events use screen
## coordinates and the engine converts them back, exactly like real mouse events.
func _toScreen(gamePos:Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * gamePos

func _sendMotion(gamePos:Vector2):
	var vp :Viewport = get_viewport()
	var screenPos :Vector2 = _toScreen(gamePos)
	var ev := InputEventMouseMotion.new()
	ev.position = screenPos
	ev.global_position = screenPos
	ev.relative = screenPos - _toScreen(vp.get_mouse_position())
	ev.button_mask = _buttonMask()
	Input.parse_input_event(ev)
	# keep the (hidden) OS cursor in the same place so switching back to the mouse doesn't jump
	vp.warp_mouse(gamePos)

func _buttonMask() -> int:
	var mask :int = 0
	if _held[MOUSE_BUTTON_LEFT]:
		mask |= MOUSE_BUTTON_MASK_LEFT
	if _held[MOUSE_BUTTON_RIGHT]:
		mask |= MOUSE_BUTTON_MASK_RIGHT
	return mask

func _handleVirtualClick(action:String,button:int):
	if Input.is_action_just_pressed(action):
		_sendButton(button,true)
	elif Input.is_action_just_released(action):
		_sendButton(button,false)

func _sendButton(button:int,pressed:bool):
	if _held[button] == pressed:
		return
	_held[button] = pressed
	
	var screenPos :Vector2 = _toScreen(get_viewport().get_mouse_position())
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	ev.pressed = pressed
	ev.position = screenPos
	ev.global_position = screenPos
	ev.button_mask = _buttonMask()
	Input.parse_input_event(ev)

## Lets go of any virtual button (used when a menu steals focus, so a click can't get stuck down)
func _releaseAll():
	for button in _held:
		if _held[button]:
			_sendButton(button,false)

func _cycleHotbar(step:int):
	if GlobalRef.chatIsOpen or !is_instance_valid(GlobalRef.hotbar):
		return
	var slot :int = posmod(PlayerData.selectedSlot + step,10)
	GlobalRef.hotbar.selectSlot(slot)


######################################################################
############################## BINDINGS ##############################
######################################################################

func _registerPadOnlyActions():
	for action in PAD_ONLY_ACTIONS:
		if !InputMap.has_action(action):
			InputMap.add_action(action,0.5)

## Puts the default (or saved) gamepad layout into the InputMap. Keyboard keys are never touched.
func applyAllBinds():
	# The shoulder buttons used to only adjust noclip speed, and Y used to press focused UI
	# buttons. Free them up so they can be break/place/inventory.
	for action in ["scroll_up","scroll_down","ui_select"]:
		_eraseJoypadEvents(action)
	
	for entry in PAD_ACTIONS:
		_applyOne(entry[0])
	
	# walking left/right is analog, so give the stick a small deadzone instead of the default 0.5.
	# (up/down stay at 0.5: those are on/off things like ladders)
	for action in ["move_left","move_right"]:
		InputMap.action_set_deadzone(action,0.2)
	for action in ["aim_left","aim_right","aim_up","aim_down"]:
		InputMap.action_set_deadzone(action,CURSOR_DEADZONE)

func _applyOne(action:String):
	_eraseJoypadEvents(action)
	var bind :Dictionary = getBind(action)
	var ev :InputEvent = _eventFromBind(bind)
	if ev != null:
		InputMap.action_add_event(action,ev)

func _eraseJoypadEvents(action:String):
	if !InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			InputMap.action_erase_event(action,e)

## Current binding of an action (saved one, else the default, else none).
func getBind(action:String) -> Dictionary:
	var saved :Dictionary = Options.options["padbinds"]
	if saved.has(action):
		return saved[action]
	return DEFAULT_BINDS.get(action,{"t":"n"})

func _eventFromBind(bind:Dictionary) -> InputEvent:
	match bind.get("t","n"):
		"b":
			var b := InputEventJoypadButton.new()
			b.device = -1 # any controller
			b.button_index = int(bind["i"]) as JoyButton
			return b
		"a":
			var m := InputEventJoypadMotion.new()
			m.device = -1
			m.axis = int(bind["i"]) as JoyAxis
			m.axis_value = float(bind["v"])
			return m
	return null

## Turns a captured InputEvent into a binding. Returns {} if the event isn't usable.
func bindFromEvent(event:InputEvent) -> Dictionary:
	if event is InputEventJoypadButton and event.pressed:
		return {"t":"b","i":int(event.button_index)}
	if event is InputEventJoypadMotion and absf(event.axis_value) >= 0.6:
		return {"t":"a","i":int(event.axis),"v":int(signf(event.axis_value))}
	return {}

func sameBind(a:Dictionary,b:Dictionary) -> bool:
	var ta :String = a.get("t","n")
	if ta == "n" or ta != b.get("t","n"):
		return false
	if int(a["i"]) != int(b["i"]):
		return false
	return ta == "b" or int(a["v"]) == int(b["v"])

## Readable name for a binding, e.g. "RB" or "LS left"
func bindName(bind:Dictionary) -> String:
	match bind.get("t","n"):
		"b":
			return BUTTON_NAMES.get(int(bind["i"]),"btn " + str(int(bind["i"])))
		"a":
			var axis :int = int(bind["i"])
			var positive :bool = int(bind["v"]) > 0
			match axis:
				JOY_AXIS_LEFT_X:
					return "LS right" if positive else "LS left"
				JOY_AXIS_LEFT_Y:
					return "LS down" if positive else "LS up"
				JOY_AXIS_RIGHT_X:
					return "RS right" if positive else "RS left"
				JOY_AXIS_RIGHT_Y:
					return "RS down" if positive else "RS up"
				JOY_AXIS_TRIGGER_LEFT:
					return "LT"
				JOY_AXIS_TRIGGER_RIGHT:
					return "RT"
			return "axis " + str(axis) + (" +" if positive else " -")
	return "none"

## Rebinds a gamepad action. If another action already uses that input the two swap,
## so nothing silently ends up unbound. Returns the label of the swapped action ("" if none).
func setBind(action:String,bind:Dictionary) -> String:
	var swapped :String = ""
	var oldBind :Dictionary = getBind(action)
	
	for entry in PAD_ACTIONS:
		var other :String = entry[0]
		if other != action and sameBind(getBind(other),bind):
			Options.options["padbinds"][other] = oldBind.duplicate()
			_applyOne(other)
			swapped = entry[1]
			break
	
	Options.options["padbinds"][action] = bind.duplicate()
	_applyOne(action)
	Options.applyOptions() # also saves
	return swapped

func resetBinds():
	Options.options["padbinds"] = {}
	applyAllBinds()
	Options.applyOptions()
