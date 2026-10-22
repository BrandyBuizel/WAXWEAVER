extends CanvasLayer
## Small settings window for the Creative Motor (opened by right clicking it with the wrench).

var body = null
var tile := Vector2i.ZERO
var rpm :int = 32
var ccw :bool = false

var rpmLabel :Label
var slider :HSlider
var dirButton :Button

func _ready():
	layer = 95
	visible = false
	
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	
	var panel = PanelContainer.new()
	center.add_child(panel)
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	
	var title = Label.new()
	title.text = "Creative Motor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	
	rpmLabel = Label.new()
	rpmLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rpmLabel)
	
	slider = HSlider.new()
	slider.min_value = 1
	slider.max_value = 256
	slider.step = 1
	slider.custom_minimum_size = Vector2(170,14)
	slider.value_changed.connect(onSlider)
	box.add_child(slider)
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for amount in [-10,-1,1,10]:
		var b = Button.new()
		b.text = ("+" if amount > 0 else "") + str(amount)
		b.pressed.connect(addRpm.bind(amount))
		row.add_child(b)
	
	dirButton = Button.new()
	dirButton.pressed.connect(toggleDirection)
	box.add_child(dirButton)
	
	var done = Button.new()
	done.text = "Done"
	done.pressed.connect(close)
	box.add_child(done)

func open(editBody,t:Vector2i):
	body = editBody
	tile = t
	rpm = clampi(body.DATAC.getInfoData(tile.x,tile.y) + 1,1,256)
	ccw = body.DATAC.getTileData(tile.x,tile.y) == 178
	refresh()
	visible = true

func close():
	visible = false
	body = null

func refresh():
	rpmLabel.text = "Speed: " + str(rpm) + " RPM"
	slider.set_value_no_signal(rpm)
	dirButton.text = "Direction: Counter-clockwise" if ccw else "Direction: Clockwise"

func onSlider(v:float):
	rpm = int(v)
	apply()
	refresh()

func addRpm(amount:int):
	rpm = clampi(rpm + amount,1,256)
	apply()
	refresh()

func toggleDirection():
	ccw = !ccw
	apply()
	refresh()

func apply():
	if body == null or !is_instance_valid(body):
		close()
		return
	var id :int = body.DATAC.getTileData(tile.x,tile.y)
	if id != 177 and id != 178:
		close() # motor was removed
		return
	body.DATAC.setInfoData(tile.x,tile.y,rpm - 1)
	body.editTiles( {Vector2i(tile.x,tile.y): (178 if ccw else 177)} )

func _process(_delta):
	if visible and (body == null or !is_instance_valid(body)):
		close()
