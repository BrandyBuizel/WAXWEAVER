extends CharacterBody2D
class_name GroundItem

@onready var texture = $textureRoot/texture
@onready var back = $textureRoot/back

@onready var tint = $textureRoot/texture/tint

@onready var floorDetector = $FloorDetector

var rotSide = 0

var gravity = 600

var itemID = 0
var amount = 1
var maxAmount = 99

var ticks = 0

var tweening = false

var parent

var droppedByPlayer :float= 0
var dropvel :Vector2 = Vector2.ZERO

var frozen = false

var coolVelcoity :bool = false
var pickedByHopper :bool = false

# --- Create-style machines (see KineticItems.gd) ---
var heldByMachine :bool = false   # a machine is working on this item: it freezes in place
var holdSilence :float = 0.0      # seconds since the machine last confirmed the hold
var beltWait :bool = false        # waiting on a belt (held, or queued behind something that is)
var beltBlockTick :int = 0
var chuteCheck :int = 0
var inChute :bool = false
var chuteCenterX :float = 0.0

var droppedByEnemy :bool = false

func _ready():
	var itemData = ItemData.getItem(itemID)
	
	var img = itemData.texture.get_image()
	img.resize(int(img.get_width()*0.75),int(img.get_height()*0.75),0)
	
	texture.texture = ImageTexture.create_from_image(img)
	back.texture = texture.texture
	maxAmount = itemData.maxStackSize
	
	if !itemData is ItemBlock:
		texture.material = null
	
	parent = get_parent().get_parent()
	
	if droppedByPlayer <= 0 and !coolVelcoity:
		var randVelocity = Vector2(randi_range(-70,70),-60)
		rotSide = getPlanetPosition()
		velocity = randVelocity.rotated(rotSide*(PI/2))
	else:
		rotSide = getPlanetPosition()
		velocity = dropvel.rotated(GlobalRef.player.rotated*(PI/2))
	

	
	determineAmount()
	
func _process(delta):
	
	droppedByPlayer -= 60.0 * delta
	
	if tweening:
		return
	
	if heldByMachine:
		holdSilence += delta
		if holdSilence > 0.6:
			heldByMachine = false # the machine stopped (no power / broken), let go
		else:
			velocity = Vector2.ZERO
			beltWait = true
			return
	
	ticks += 1 * delta * 80.0
	rotSide = getPlanetPosition()
	
	var newVelocity = velocity.rotated(-rotSide*(PI/2))
	
	if !coolVelcoity:
		if !frozen:
			newVelocity.x = lerp(newVelocity.x,0.0,8.0*delta)
			newVelocity.y += gravity * delta
			newVelocity.y = min(newVelocity.y,150)
		else:
			newVelocity = lerp(newVelocity,Vector2.ZERO,0.2)
	else:
		#newVelocity.x = lerp(newVelocity.x,0.0,8.0*delta)
		newVelocity.y += gravity * delta
		newVelocity.y = min(newVelocity.y,150)
	
	match floorDetector.getFloorTile():
		105:
			newVelocity.x = GlobalRef.conveyorspeed
		106:
			newVelocity.x = -GlobalRef.conveyorspeed
		185: # mechanical belt carrying right
			newVelocity.x = 0.0 if isBeltBlocked(1) else getKineticBeltSpeed()
		186: # mechanical belt carrying left
			newVelocity.x = 0.0 if isBeltBlocked(-1) else -getKineticBeltSpeed()
		_:
			beltWait = false
	
	# chute: pulls the item to the middle of its tile and lets it sink slowly
	chuteCheck -= 1
	if chuteCheck <= 0:
		chuteCheck = 4
		inChute = isInChute()
	if inChute and rotSide == 0:
		newVelocity.x = clampf(chuteCenterX - position.x,-3.0,3.0) * 12.0
		newVelocity.y = minf(newVelocity.y,35.0)
	
	velocity = newVelocity.rotated(rotSide*(PI/2))
	
	move_and_slide()
	
	if parent is Ship:
		$textureRoot.rotation = 0
	else:
		$textureRoot.rotation = rotSide*(PI/2)
	
	texture.offset.y = (sin(ticks*0.12) * 2.0) - 2
	back.offset.y = texture.offset.y
	
	if parent is Ship:
		var t = parent.posToTile(position)
		if t == null:
			return # gay
		if parent.DATAC.getBGData(t.x,t.y) <= 1:
			if parent.get_parent().is_in_group("planet"):
				# on planet
				reparent(parent.get_parent().get_parent().entityContainer)
			else:
				frozen = true
	
# --- Create-style mechanical belt: speed follows the RPM of the belt's kinetic network ---
var kineticBeltSpeed :float = 0.0
var kineticBeltCheck :int = 0

func getKineticBeltSpeed() -> float:
	kineticBeltCheck -= 1
	if kineticBeltCheck > 0:
		return kineticBeltSpeed
	kineticBeltCheck = 8
	kineticBeltSpeed = 0.0
	if !is_instance_valid(parent) or parent is Ship:
		return 0.0
	var t = parent.posToTile(position)
	if t == null:
		return 0.0
	var dir :int = parent.DATAC.getPositionLookup(t.x,t.y)
	var rot :Vector2i = Vector2i(Vector2(0,1).rotated(dir * (PI/2)))
	var info :Dictionary = BlockData.theChunker.getKineticInfo(parent.DATAC,t.x + rot.x,t.y + rot.y)
	kineticBeltSpeed = GlobalRef.conveyorspeed * clampf(float(info["rpm"]) / 32.0,0.0,6.0)
	return kineticBeltSpeed

func isInChute() -> bool:
	if !is_instance_valid(parent) or parent is Ship:
		return false
	var t = parent.posToTile(position)
	if t == null:
		return false
	if parent.DATAC.getTileData(t.x,t.y) != 201:
		return false
	chuteCenterX = parent.tileToPos(Vector2(t.x,t.y)).x
	return true

# items queue up behind anything that is waiting just ahead of them on the belt
func isBeltBlocked(dirSign:int) -> bool:
	beltBlockTick -= 1
	if beltBlockTick > 0:
		return beltWait
	beltBlockTick = 3
	beltWait = false
	if !is_instance_valid(parent) or parent is Ship:
		return false
	for o in parent.entityContainer.get_children():
		if o == self or !(o is GroundItem) or !o.beltWait or o.tweening:
			continue
		var d :Vector2 = (o.position - position).rotated(-rotSide * (PI/2))
		if absf(d.y) < 5.0 and d.x * dirSign > 0.0 and d.x * dirSign < 7.0:
			beltWait = true
			return true
	return false

func getPlanetPosition():
	if !is_instance_valid(parent):
		return 0
	if parent is Ship:
		if parent.get_parent().is_in_group("planet"):
				# on planet
				return parent.targetRot
		return 0
		
	var p = parent.posToTile(position)
	if p == null:
		var angle1 = Vector2(1,1)
		var angle2 = Vector2(-1,1)
		
		var dot1 = int(position.dot(angle1) >= 0)
		var dot2 = int(position.dot(angle2) > 0) * 2
		
		return [0,1,3,2][dot1 + dot2]
	return parent.DATAC.getPositionLookup(p.x,p.y)

func _on_area_2d_body_entered(body):
	
	if tweening:
		return
	if body is FakePlayer:
		if droppedByEnemy: # don't let other players pick up our sick loot
			return
		tweenAndDestroy(body.global_position,false)
		return
	tweenAndDestroy(body.global_position,true)


func _on_stack_body_entered(body):
	
	## Stack with items of same type ##
	
	if tweening or body == self:
		return

	if body is GroundItem:
		if body.itemID != itemID or body.tweening:
			return
		if body.ticks >= ticks:
			if amount + body.amount > maxAmount: return
			amount += body.amount
			determineAmount()
			body.tweenAndDestroy(global_position,false)
			return

func determineAmount():
	if amount > 1:
		tint.color.a = (amount - 1) * 0.05

func tweenAndDestroy(pos,shouldAddItem):
	if tweening:
		return
	
	if droppedByPlayer > 0:
		return
		
	tweening = true
	var tween = get_tree().create_tween()
	tween.tween_property(self,"global_position",pos,0.1)
	await tween.finished
	
	if shouldAddItem:
		var amountLeft = PlayerData.addItem(itemID,amount)
		if amountLeft == 0:
			var itemData = ItemData.getItem(itemID)
			Indicators.itemPopup(itemData.itemName,amount,global_position)
			SoundManager.playSound("inventory/pickupItem",global_position,1.0,0.12,"INVENTORY")
			queue_free()
		else:
			tweening = false
			amount = amountLeft
	else:
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
