extends Node

var defaultOptions :Dictionary= {
	"showShadow":true,
	"musicVolume":1.5,
	"sfxVolume":1.5,
	"ambientVolume":1.5,
	"autosaving":true,
	"cameraRotationOverwrite":-1.0,
	"maxfps":60,
	"vsync":1,
	"keybinds":{}, # action name : physical keycode
	"padbinds":{}, # gamepad: action name : {"t":"b","i":button} / {"t":"a","i":axis,"v":-1|1} / {"t":"n"} (none)
	"viewWidth":400, # how many pixels wide the game renders (400 = original 4:3)
	"hudBarTransparent":false, # top HUD bar: solid black or see-through
	"autoViewWidth":false, # true = ignore the slider, view width follows the window shape
}

var options :Dictionary = {}

## [action name, label shown in the controls menu]
const REBINDABLE :Array = [
	["move_left","move left"],
	["move_right","move right"],
	["move_up","move up/climb"],
	["move_down","move down"],
	["jump","jump"],
	["crouch","crouch"],
	["inventory","inventory"],
	["shift","stack modifier"],
	["openCommand","chat/command"],
	["pause","pause"],
	["fullscreen","fullscreen"],
	["screenshot","screenshot"],
]

var defaultKeybinds :Dictionary = {} # action : Array[InputEvent]
var _suspended :Dictionary = {}

signal updatedOptions
signal viewWidthChanged(width:int)

const BASE_VIEW := Vector2i(400,300)
## The lightmap (made by the C++ extension) only covers a fixed area around the player,
## so going wider than this would show unlit strips at the edges.
const MAX_VIEW_WIDTH := 512
## --- automatic view size ("view width: auto" in the options menu) ---
## Window pixels per game pixel. The window decides how much of the world you see:
## a bigger window shows MORE world (sideways and up/down) instead of bigger pixels.
## 2.0 matches the default 800x600 window. Try 3.0 for fullscreen on a big monitor.
## (If the window is too short to fit the 300px-tall HUD at this scale, it shrinks to fit.)
const AUTO_PIXEL_SCALE := 2.0
## Limits for the automatic size. The darkness overlay only covers about 576 pixels around
## the player, so very big views may look unlit near the edges. Lower these to limit it.
const AUTO_MAX_VIEW_WIDTH := 2400
const AUTO_MAX_VIEW_HEIGHT := 1600
var inGame :bool = false # widescreen only applies inside a world, menus stay 400x300
var _appliedSize :Vector2i = Vector2i(400,300)

func _ready():
	get_window().size_changed.connect(_onWindowResized)
	# remember the default keys (from project settings) so "reset" can restore them
	for entry in REBINDABLE:
		defaultKeybinds[entry[0]] = InputMap.action_get_events(entry[0])
	
	options = defaultOptions.duplicate(true)
	var saved = Saving.read_save("options")
	if saved != null:
		for key in saved:
			options[key] = saved[key]
			# we do this iteration in case new options have appeared. 
			# this will make future default values not get overridden
	
	applyKeybinds()
	applyOptions()

func applyOptions():
	
	# sets audio bus volume
	var musicBus= AudioServer.get_bus_index("MUSIC")
	AudioServer.set_bus_volume_db(musicBus, linear_to_db(options["musicVolume"]) )
	var sfxBus= AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfxBus, linear_to_db(options["sfxVolume"]) )
	var ambientBus= AudioServer.get_bus_index("AMBIENT")
	AudioServer.set_bus_volume_db(ambientBus, linear_to_db(options["ambientVolume"]) )
	
	Engine.max_fps = options["maxfps"]
	match options["vsync"]:
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		3:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
	
	Saving.write_save("options",options)
	emit_signal("updatedOptions")


######################################################################
############################# KEYBINDS ###############################
######################################################################

## Applies every saved keybind to the InputMap (called on startup).
func applyKeybinds():
	var binds :Dictionary = options["keybinds"]
	for action in binds:
		if InputMap.has_action(action):
			_setActionKey(action,int(binds[action]))

## Returns the physical keycode currently used for an action, or 0 if none.
func getKeybind(action:String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode
	return 0

## Readable name for a physical keycode, e.g. 65 -> "A"
func keyName(physicalKeycode:int) -> String:
	if physicalKeycode == 0:
		return "none"
	var code :int = DisplayServer.keyboard_get_keycode_from_physical(physicalKeycode)
	if code == 0:
		code = physicalKeycode
	return OS.get_keycode_string(code)

## Rebinds an action. If another rebindable action already uses that key, the two swap
## keys so nothing ends up unbound. Returns the name of the swapped action ("" if none).
func setKeybind(action:String,physicalKeycode:int) -> String:
	var swapped :String = ""
	var oldKey :int = getKeybind(action)
	
	for entry in REBINDABLE:
		var other :String = entry[0]
		if other != action and getKeybind(other) == physicalKeycode:
			if oldKey != 0:
				_setActionKey(other,oldKey)
				options["keybinds"][other] = oldKey
			swapped = entry[1]
			break
	
	_setActionKey(action,physicalKeycode)
	options["keybinds"][action] = physicalKeycode
	applyOptions() # also saves
	return swapped

func resetKeybinds():
	# only the keyboard events are reset here, so gamepad bindings on the same actions survive
	for action in defaultKeybinds:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action,e)
		for e in defaultKeybinds[action]:
			if e is InputEventKey:
				InputMap.action_add_event(action,e)
	options["keybinds"] = {}
	applyOptions()

## Replaces all keyboard events of an action with one key (mouse/joypad events are kept).
func _setActionKey(action:String,physicalKeycode:int):
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action,e)
	var ev := InputEventKey.new()
	ev.physical_keycode = physicalKeycode as Key
	InputMap.action_add_event(action,ev)

## While the player is choosing a new key, the game shouldn't react to it
## (otherwise pressing P or Esc would unpause, F would fullscreen, etc).
func suspendKeybinds():
	if !_suspended.is_empty():
		return
	for entry in REBINDABLE:
		_suspended[entry[0]] = InputMap.action_get_events(entry[0])
		InputMap.action_erase_events(entry[0])

func resumeKeybinds():
	for action in _suspended:
		InputMap.action_erase_events(action)
		for e in _suspended[action]:
			InputMap.action_add_event(action,e)
	_suspended.clear()


######################################################################
############################ VIEW WIDTH ##############################
######################################################################

## Size (in game pixels) the game should currently render at.
func getViewSize() -> Vector2i:
	if !inGame:
		return BASE_VIEW
	if options.get("autoViewWidth",false):
		var ws :Vector2i = get_window().size
		if ws.y <= 0 or ws.x <= 0:
			return BASE_VIEW
		# normally AUTO_PIXEL_SCALE, but never so big that the 300px HUD gets cut off
		var pixelScale :float = minf(AUTO_PIXEL_SCALE, float(ws.y) / BASE_VIEW.y)
		var w :int = clampi(ceili(ws.x / pixelScale), BASE_VIEW.x, AUTO_MAX_VIEW_WIDTH)
		var h :int = clampi(ceili(ws.y / pixelScale), BASE_VIEW.y, AUTO_MAX_VIEW_HEIGHT)
		return Vector2i(w,h)
	return Vector2i(clampi(int(options["viewWidth"]), BASE_VIEW.x, MAX_VIEW_WIDTH), BASE_VIEW.y)

## Width (in game pixels) the game should currently render at.
func getViewWidth() -> int:
	return getViewSize().x

## Height (in game pixels). Always 300 unless automatic view size is on.
func getViewHeight() -> int:
	return getViewSize().y

## Called by the world when it loads (true) and by the main menu (false).
func setInGame(value:bool):
	inGame = value
	applyViewWidth()

## Changes how many pixels render. Extra size is added equally on every side of the player.
## (viewWidthChanged fires when the width OR the height changed; read getViewHeight() too.)
func applyViewWidth():
	var vs :Vector2i = getViewSize()
	var win :Window = get_window()
	
	# the drop shadow is drawn from its own viewport, which has to match the screen size
	if is_instance_valid(GlobalRef.dropShadowRenderVP):
		GlobalRef.dropShadowRenderVP.size = vs
	
	if vs == _appliedSize:
		return
	var oldW :int = win.content_scale_size.x
	win.content_scale_size = vs
	
	# in a normal window, grow/shrink the window too so pixels keep the same size
	# (fullscreen/maximized windows can't change shape, so they just get a different fit)
	# (not in auto mode, there the window is what drives the size)
	if win.mode == Window.MODE_WINDOWED and oldW > 0 and !options.get("autoViewWidth",false):
		var newSize := Vector2i(roundi(win.size.x * float(vs.x) / float(oldW)), win.size.y)
		var diff :int = newSize.x - win.size.x
		win.size = newSize
		win.position.x = maxi(0, win.position.x - diff/2)
	
	_appliedSize = vs
	viewWidthChanged.emit(vs.x)

## In auto mode, dragging the window edge (or fullscreen/maximize) re-fits the view width.
func _onWindowResized():
	if inGame and options.get("autoViewWidth",false):
		applyViewWidth()
