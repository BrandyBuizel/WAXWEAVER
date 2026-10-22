extends Node2D

@onready var sfxSlider = $ScrollContainer/g/buttons/sfxslider/sfxslide
@onready var musicSlider = $ScrollContainer/g/buttons/musicslider/musslide
@onready var ambientSlider = $ScrollContainer/g/buttons/ambientslider/ambslide
@onready var rotationSlider = $ScrollContainer/g/buttons/rotateSlider/rotslide
@onready var widthSlider = $ScrollContainer/g/buttons/widthSlider/widthslide

signal menuClosed

func _ready():
	loadOptions()
	# keeps the "auto: 533" label current while the window is resized
	Options.viewWidthChanged.connect(func(_w): setWidthLabel())

func loadOptions():
	sfxSlider.value = Options.options["sfxVolume"]
	musicSlider.value = Options.options["musicVolume"]
	ambientSlider.value = Options.options["ambientVolume"]
	rotationSlider.value = int(Options.options["cameraRotationOverwrite"] * 100.0)
	
	setShadowText()
	setAutosaveText()
	widthSlider.value = int(Options.options["viewWidth"])
	setWidthLabel()
	setAutoWidthText()
	setHudBarText()
	
	if Options.options["maxfps"] == 0:
		$ScrollContainer/g/buttons/maxfps/maxfpsslider.value = 300
		$ScrollContainer/g/buttons/maxfps/maxfpslabel.text = "unlimited"
	else:
		$ScrollContainer/g/buttons/maxfps/maxfpsslider.value = Options.options["maxfps"]
		$ScrollContainer/g/buttons/maxfps/maxfpslabel.text = str(Options.options["maxfps"])
	
	#await get_tree().create_timer(2.0).timeout
	changevsynctext()
	
func _on_dropshadow_pressed():
	Options.options["showShadow"] = !Options.options["showShadow"]
	Options.applyOptions()
	setShadowText()

func setShadowText():
	if Options.options["showShadow"]:
		$ScrollContainer/g/buttons/dropshadow.buttonText = "show drop shadow: true"
	else:
		$ScrollContainer/g/buttons/dropshadow.buttonText = "show drop shadow: false"

func _on_done_pressed():
	closeMenu()

func closeMenu():
	closeControls()
	hide()
	emit_signal("menuClosed")

const CONTROLS_MENU = preload("res://ui_scenes/options/controls_menu.gd")
var controlsMenu :Node2D = null

func _on_controls_pressed():
	if is_instance_valid(controlsMenu):
		return
	# hide the regular options while the controls panel is open
	$title.hide()
	$ScrollContainer.hide()
	$done.hide()
	$controls.hide()
	
	controlsMenu = Node2D.new()
	controlsMenu.set_script(CONTROLS_MENU)
	add_child(controlsMenu)
	controlsMenu.connect("closed",closeControls)

# if the whole options menu gets hidden (e.g. unpausing), close the controls panel too
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and !visible:
		closeControls()

func closeControls():
	if is_instance_valid(controlsMenu):
		controlsMenu.queue_free()
		controlsMenu = null
	if !is_node_ready():
		return
	$title.show()
	$ScrollContainer.show()
	$done.show()
	$controls.show()




func _on_sfxslide_value_changed(value):
	Options.options["sfxVolume"] = value
	Options.applyOptions()
	$ScrollContainer/g/buttons/sfxslider/Label.text = str(value*100)


func _on_musslide_value_changed(value):
	Options.options["musicVolume"] = value
	Options.applyOptions()
	$ScrollContainer/g/buttons/musicslider/Label.text = str(value*100)


func _on_ambslide_value_changed(value):
	Options.options["ambientVolume"] = value
	Options.applyOptions()
	$ScrollContainer/g/buttons/ambientslider/Label.text = str(value*100)


func _on_sfx_pressed():
	sfxSlider.value = 1.5
func _on_music_pressed():
	musicSlider.value = 1.5
func _on_ambient_pressed():
	ambientSlider.value = 1.5


func _on_fullscreen_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	


func _on_autosaving_pressed():
	Options.options["autosaving"] = !Options.options["autosaving"]
	Options.applyOptions()
	setAutosaveText()

func setAutosaveText():
	$ScrollContainer/g/buttons/autosaving.buttonText = "autosaving: " + str(Options.options["autosaving"])


func _on_rotslide_value_changed(value):
	if value == 0:
		Options.options["cameraRotationOverwrite"] = -1.0
		$ScrollContainer/g/buttons/rotateSlider/Label.text = "normal"
	else:
		Options.options["cameraRotationOverwrite"] = value * 0.01
		$ScrollContainer/g/buttons/rotateSlider/Label.text = str(value)

func _on_rotation_pressed():
	Options.options["cameraRotationOverwrite"] = -1.0
	$ScrollContainer/g/buttons/rotateSlider/Label.text = "normal"
	rotationSlider.value = 0
	


func _on_maxfps_pressed():
	Options.options["maxfps"] = 60
	Options.applyOptions()
	$ScrollContainer/g/buttons/maxfps/maxfpslabel.text = "60"
	$ScrollContainer/g/buttons/maxfps/maxfpsslider.value = 60
	

func _on_maxfpsslider_value_changed(value):
	if value == 300:
		value = 0
	Options.options["maxfps"] = value
	Options.applyOptions()
	if value != 0:
		$ScrollContainer/g/buttons/maxfps/maxfpslabel.text = str(value)
	else:
		$ScrollContainer/g/buttons/maxfps/maxfpslabel.text = "unlimited"


func _on_vsync_pressed():
	Options.options["vsync"] = int(Options.options["vsync"] + 1) % 4
	Options.applyOptions()
	changevsynctext()

func changevsynctext():
	var fuck = int(Options.options["vsync"])
	match fuck:
		0: $ScrollContainer/g/buttons/maxfps/vsync.forceChangeText("vsync: disabled")
		1: $ScrollContainer/g/buttons/maxfps/vsync.forceChangeText("vsync: enabled")
		2: $ScrollContainer/g/buttons/maxfps/vsync.forceChangeText("vsync: adaptive")
		3: $ScrollContainer/g/buttons/maxfps/vsync.forceChangeText("vsync: mailbox")


######################################################################
####################### WIDESCREEN + HUD BAR #########################
######################################################################

func _on_widthslide_value_changed(value):
	Options.options["viewWidth"] = int(value)
	Options.applyViewWidth() # only changes the screen while inside a world
	Options.applyOptions()
	setWidthLabel()

func _on_widthreset_pressed():
	if Options.options.get("autoViewWidth",false):
		return
	widthSlider.value = 400

## "view width: auto" turns the slider off and makes the width follow the window shape.
func _on_autowidth_pressed():
	Options.options["autoViewWidth"] = !Options.options.get("autoViewWidth",false)
	Options.applyViewWidth() # only changes the screen while inside a world
	Options.applyOptions()
	setAutoWidthText()
	setWidthLabel()

func setAutoWidthText():
	var auto :bool = Options.options.get("autoViewWidth",false)
	if auto:
		$ScrollContainer/g/buttons/autowidth.forceChangeText("view width: auto")
	else:
		$ScrollContainer/g/buttons/autowidth.forceChangeText("view width: manual")
	# slider is switched off (and greyed out) while auto is on
	widthSlider.editable = !auto
	widthSlider.modulate.a = 0.35 if auto else 1.0

func setWidthLabel():
	var w :int = int(Options.options["viewWidth"])
	var label :String = str(w)
	if w == 400:
		label = "400 (4:3)"
	if Options.options.get("autoViewWidth",false):
		var vs :Vector2i = Options.getViewSize()
		label = "auto %dx%d" % [vs.x, vs.y]
	$ScrollContainer/g/buttons/widthSlider/Label.text = label

func _on_hudbar_pressed():
	Options.options["hudBarTransparent"] = !Options.options["hudBarTransparent"]
	Options.applyOptions() # the HUD listens for this and updates itself
	setHudBarText()

func setHudBarText():
	if Options.options["hudBarTransparent"]:
		$ScrollContainer/g/buttons/hudbar.forceChangeText("top bar: transparent")
	else:
		$ScrollContainer/g/buttons/hudbar.forceChangeText("top bar: solid")
