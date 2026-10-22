extends Camera2D

@onready var map = $SystemMap
@onready var mapbg = $ColorRect2
@onready var compass = $Compass

# background stuff
@onready var bgHolder = $Backgrounds/bgHolder
var currentBG = null
var bgtween :Tween = null

func _ready():
	GlobalRef.camera = self
	Options.viewWidthChanged.connect(onViewWidthChanged)
	onViewWidthChanged(Options.getViewWidth())

## Called when the "view width" setting changes (extra pixels are added on both sides).
var viewWidth :int = 400
var viewHeight :int = 300

func onViewWidthChanged(w:int):
	viewWidth = w
	viewHeight = Options.getViewHeight()
	# backgrounds are anchored to the top-left of the screen, so move them to the new corner
	$Backgrounds.position = Vector2(-w / 2.0, -viewHeight / 2.0)
	# the HUD stays centred; only its top bar stretches across the wider screen
	$HotbarBanner.setViewWidth(w)
	for bg in bgHolder.get_children():
		fitBackground(bg)

## Stretches gradient skies (sky/sun) sideways so they still cover a widened screen.
func fitBackground(bg:Node):
	var w :int = viewWidth
	var h :int = viewHeight
	for s in bg.find_children("*","Sprite2D",true,false):
		if !(s.texture is GradientTexture1D or s.texture is GradientTexture2D):
			continue
		if !s.has_meta("baseScale"):
			s.set_meta("baseScale",s.scale)
			s.set_meta("basePos",s.position)
		var baseScale :Vector2 = s.get_meta("baseScale")
		var basePos :Vector2 = s.get_meta("basePos")
		# these sprites are rotated 90 degrees, so their screen-width is scale.y
		# (and their screen-height is scale.x)
		s.scale = Vector2(baseScale.x * (h / 300.0), baseScale.y * (w / 400.0))
		s.position = basePos + Vector2((w - 400) / 2.0, (h - 300) / 2.0)

func cpass(motion):
	compass.rotation = -rotation
	if motion.length() > 1000:
		$speedPart.rotation = -rotation + motion.angle() + (PI/2)
		$speedPart.emitting = true
		
		$speedPart.scale_amount_max = lerp($speedPart.scale_amount_max,clamp(motion.length()/1200.0,0,1.0),0.2)
		$speedPart.scale_amount_min = $speedPart.scale_amount_max
	else:
		$speedPart.emitting = false
	
func swapBackgrounds(scene:String):
	
	if is_instance_valid(bgtween):
		if bgtween.is_running():
			bgtween.stop()
	
	if scene == "empty" and is_instance_valid(currentBG):
		# return to empty space
		bgtween = get_tree().create_tween()
		bgtween.tween_property(currentBG,"modulate:a",0.0,1.0)
		await bgtween.finished
		currentBG.queue_free()
		currentBG = null
		return
	elif scene == "empty":
		return
	
	# create new background
	var newBG = load(scene).instantiate()
	newBG.modulate.a = 0.0
	bgHolder.add_child(newBG)
	fitBackground(newBG)
	
	# cool fade
	bgtween = get_tree().create_tween()
	bgtween.tween_property(newBG,"modulate:a",1.0,1.0)
	if is_instance_valid(currentBG):
		bgtween.tween_property(currentBG,"modulate:a",0.0,1.0)
		bgtween.set_parallel(true)
	
	await bgtween.finished
	
	if is_instance_valid(currentBG):
		currentBG.queue_free()
	currentBG = newBG

func changeBG(file):
	
	if is_instance_valid(bgtween):
		if bgtween.is_running():
			await bgtween.finished
	
	# rid old background
	for bg in bgHolder.get_children():
		var tween = get_tree().create_tween()
		tween.tween_property(bg,"modulate:a",0.0,1.0)
		await tween.finished
	
	for bg in bgHolder.get_children():
		bg.queue_free()
	
	if file == null:
		return
	
	# create new bg from file
	var newBG = load(file).instantiate()
	newBG.modulate.a = 0.0
	bgHolder.add_child(newBG)
	fitBackground(newBG)
	
	# cool fade
	bgtween = get_tree().create_tween()
	bgtween.tween_property(newBG,"modulate:a",1.0,1.0)
	
	await bgtween.finished

func changeZoom():
	$HotbarBanner.scale = Vector2(1.0/zoom.x,1.0/zoom.y)
	$HotbarBanner.position = (Vector2(400,300) * $HotbarBanner.scale * -0.5) - Vector2(1,1)

func shake(amount:int):
	offset.x = randi_range(-amount,amount)
	offset.y = randi_range(-amount,amount)

func resetShake():
	offset = Vector2.ZERO
