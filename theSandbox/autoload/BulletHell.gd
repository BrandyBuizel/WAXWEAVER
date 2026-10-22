extends CanvasLayer
# Lunar Beacon boss fight: the game fades to white, everything is hidden and a
# Touhou-style bullet hell takes over. The world is paused while it runs.

var active :bool = false
var white :ColorRect
var field :Node2D = null
var prevMouse :int = Input.MOUSE_MODE_VISIBLE

const FIELD_SCRIPT := preload("res://autoload/bullet_hell_field.gd")

func _ready():
	layer = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	white = ColorRect.new()
	white.color = Color.WHITE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.modulate.a = 0.0
	add_child(white)

func fadeWhite(to:float,time:float):
	var tw := create_tween()
	tw.tween_property(white,"modulate:a",to,time)
	await tw.finished

func start():
	if active:
		return
	active = true
	GlobalRef.controlsLocked = true
	GlobalRef.playerCanUseItem = false
	var p = GlobalRef.player
	if is_instance_valid(p):
		p.velocity = Vector2.ZERO
	
	# 1. fade to white (the screen stays white while the new area is set up, no loading zone)
	sfxWhoosh()
	await fadeWhite(1.0,1.6)
	
	# 2. build the bullet hell behind the white
	get_tree().paused = true
	prevMouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	field = Node2D.new()
	field.set_script(FIELD_SCRIPT)
	add_child(field)
	move_child(white,get_child_count() - 1) # keep the white sheet on top
	await get_tree().create_timer(1.0).timeout
	
	# 3. white fades away into the fight
	await fadeWhite(0.0,1.2)
	field.begin()
	var won :bool = await field.finished
	
	# 4. back to the world through white again
	await fadeWhite(1.0,1.2)
	field.queue_free()
	field = null
	get_tree().paused = false
	Input.mouse_mode = prevMouse
	if won:
		giveRewards()
	await get_tree().create_timer(0.8).timeout
	await fadeWhite(0.0,1.4)
	
	GlobalRef.controlsLocked = false
	GlobalRef.playerCanUseItem = true
	active = false
	if won:
		GlobalRef.sendChat("The alien fled. Rewards collected!",Color(0.6,0.9,1.0))
	else:
		GlobalRef.sendChat("You were driven off. The beacon still works, try again!",Color(1.0,0.6,0.5))

func giveRewards():
	if PlayerData.checkForItemAmount(7162) > 0:
		PlayerData.consumeItems([7162],[1])
	PlayerData.addItem(7212,randi_range(10,16)) # lunar crystal
	PlayerData.addItem(7201,randi_range(3,5)) # andesite alloy
	PlayerData.addItem(7140,randi_range(4,8)) # brass bar
	PlayerData.addMoney(1200)

func sfxWhoosh():
	var base = load("res://sound/enemy/boss/final/beamCharge.ogg")
	if base == null:
		return
	var s :AudioStream = base.duplicate()
	if "loop" in s:
		s.loop = false
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.bus = "SFX"
	pl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()
