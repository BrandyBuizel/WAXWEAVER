class_name KineticGear
extends Node
## Create-style gear: copper diving set, cardboard box and the brass jetpack.
## One instance is added to the player (see rightClicker.gd). The static helpers are used by player.gd and the enemies.

const DIVING_HELMET :int = 7150
const DIVING_BOOTS :int = 7151
const CARDBOARD_BOX :int = 7152
const JETPACK :int = 7153

# armor slots in PlayerData.inventory (helmet, chest, legs)
const SLOT_HELMET :int = 40
const SLOT_CHEST :int = 41
const SLOT_LEGS :int = 42

# jetpack tuning
const FUEL_MAX :float = 1600.0
const WATER_MAX :float = 1600.0
const WOOD_ITEM :int = 13
const WOOD_FUEL :float = 1600.0 / 99.0   # 99 wood fills the bar
const WATER_FILL_RATE :float = 200.0     # per second while crouching in water
const MAX_HEIGHT :int = 27               # blocks above the ground below you
const THRUST_SPEED :float = 110.0
const THRUST_ACCEL :float = 1800.0

static var hiddenFlag :bool = false

static func wearing(id:int) -> bool:
	for slot in [SLOT_HELMET,SLOT_CHEST,SLOT_LEGS]:
		if PlayerData.inventory[slot][0] == id:
			return true
	return false

## 0..1: how much of the speed lost under water the diving gear gives back (half for each piece)
static func divingFactor() -> float:
	var f :float = 0.0
	if wearing(DIVING_HELMET):
		f += 0.5
	if wearing(DIVING_BOOTS):
		f += 0.5
	return f

## true while the cardboard box is on and you are crouching: mobs cannot see you
static func hidden() -> bool:
	return hiddenFlag

## where enemies think the player is. Hidden players look far away (but not so far that bosses despawn)
static func seenPos(pos:Vector2) -> Vector2:
	if hiddenFlag:
		return pos + Vector2(600,0)
	return pos

# ------------------------------------------------------------------ instance (lives on the player)

var player = null
var boxSprite :Sprite2D = null
var wasBox :bool = false
var fuel :float = 0.0
var water :float = 0.0
var useTimer :float = 0.0
var hudBuilt :bool = false
var fuelFill :ColorRect = null
var waterFill :ColorRect = null
var hudRoot :Node2D = null

func _ready():
	player = get_parent()
	boxSprite = Sprite2D.new()
	boxSprite.texture = load("res://items/gear/cardboardBox.png")
	boxSprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boxSprite.position = Vector2(0,2)
	boxSprite.visible = false
	boxSprite.z_index = 2
	player.add_child(boxSprite)

func _physics_process(delta):
	if !is_instance_valid(player):
		return
	var chatOpen :bool = GlobalRef.chatIsOpen
	var crouch :bool = Input.is_action_pressed("crouch") and !chatOpen
	
	# ---- cardboard box: crouch and you turn into a box nobody can see ----
	var box :bool = wearing(CARDBOARD_BOX) and crouch
	hiddenFlag = box
	if box != wasBox:
		wasBox = box
		player.sprite.visible = !box
		player.itemRoot.visible = !box
		boxSprite.visible = box
	
	# ---- jetpack ----
	var hasPack :bool = wearing(JETPACK)
	updateHud(hasPack)
	if hasPack and player.state == 0:
		jetpackStep(delta,crouch,chatOpen)

func jetpackStep(delta:float,crouch:bool,chatOpen:bool) -> void:
	var body = player.getEditingBody()
	if !is_instance_valid(body):
		return
	var local :Vector2 = body.to_local(player.global_position)
	var tile = body.posToTile(local)
	if tile == null:
		return
	
	# crouch in water to fill the water bar
	if crouch and abs(body.DATAC.getWaterData(tile.x,tile.y)) > 0.3:
		water = minf(WATER_MAX,water + WATER_FILL_RATE * delta)
	
	absorbFuel(body,local)
	
	if !Input.is_action_pressed("jump") or chatOpen or fuel <= 0.0 or water <= 0.0:
		return
	var rs :float = player.getProperRotationSource()
	if player.isOnFloor(rs):
		return # the normal jump gets you off the ground, then the pack takes over
	if heightAboveGround(body,tile) >= MAX_HEIGHT:
		return
	
	var up :Vector2 = Vector2(0,-1).rotated(rs)
	var vup :float = player.velocity.dot(up)
	if vup < THRUST_SPEED:
		player.velocity += up * minf(THRUST_SPEED - vup,THRUST_ACCEL * delta)
	
	# one point of fuel and water per second of use
	useTimer += delta
	if useTimer >= 1.0:
		useTimer -= 1.0
		fuel = maxf(0.0,fuel - 1.0)
		water = maxf(0.0,water - 1.0)

## blocks between you and the first solid block below (gravity direction)
func heightAboveGround(body,tile) -> int:
	var d :Vector2i = Vector2i(Vector2(0,1).rotated(player.rotated * (PI/2)).round())
	for i in range(1,MAX_HEIGHT + 3):
		var t :Vector2i = Vector2i(tile.x + d.x * i,tile.y + d.y * i)
		if BlockData.checkForCollision(body.DATAC.getTileData(t.x,t.y)):
			return i - 1
	return 999

## wood that the player dropped right next to himself goes into the fuel bar
func absorbFuel(body,local:Vector2) -> void:
	if fuel >= FUEL_MAX:
		return
	for e in body.entityContainer.get_children():
		if !(e is GroundItem) or e.tweening or e.itemID != WOOD_ITEM or e.droppedByPlayer <= 0.0:
			continue
		if e.position.distance_to(local) > 24.0:
			continue
		var room :int = int(floor((FUEL_MAX - fuel) / WOOD_FUEL))
		var take :int = mini(e.amount,room)
		if take <= 0:
			return
		fuel = minf(FUEL_MAX,fuel + take * WOOD_FUEL)
		e.amount -= take
		if e.amount <= 0:
			e.pickedByHopper = true
			e.queue_free()
		else:
			e.determineAmount()

# ------------------------------------------------------------------ HUD: two bars under the health and mana bars

func buildHud() -> void:
	if GlobalRef.hotbar == null:
		return
	var hb = GlobalRef.hotbar.get_node_or_null("HealthBar")
	if hb == null:
		return
	hudRoot = Node2D.new()
	hb.add_child(hudRoot)
	fuelFill = makeBar(0,Color(0.97,0.55,0.15))
	waterFill = makeBar(1,Color(0.3,0.6,1.0))
	hudBuilt = true

func makeBar(row:int,col:Color) -> ColorRect:
	var y :float = 18.0 + row * 7.0
	var back :ColorRect = ColorRect.new()
	back.color = Color(0.05,0.05,0.08,0.85)
	back.position = Vector2(-100,y - 1)
	back.size = Vector2(102,7)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hudRoot.add_child(back)
	var fill :ColorRect = ColorRect.new()
	fill.color = col
	fill.position = Vector2(-99,y)
	fill.size = Vector2(0,5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hudRoot.add_child(fill)
	return fill

func updateHud(show:bool) -> void:
	if !hudBuilt:
		if !show:
			return
		buildHud()
		if !hudBuilt:
			return
	hudRoot.visible = show
	if show:
		fuelFill.size.x = 100.0 * fuel / FUEL_MAX
		waterFill.size.x = 100.0 * water / WATER_MAX
