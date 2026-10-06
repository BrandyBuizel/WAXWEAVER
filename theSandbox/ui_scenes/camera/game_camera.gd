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
