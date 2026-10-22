extends Enemy

@onready var sprite = $sprite

var direction :Vector2 = Vector2(1,0)

var blockID :int= 2

var ticks :int= 0

var blockData

var info :int= 0

var ogTile :Vector2 = Vector2.ZERO # USED FOR CHEST MOVEMENT

var savedChest = "poop"

func _ready():
	
	if !is_instance_valid(planet):
		queue_free()
		return
	
	velocity = direction * 200.0
	
	blockData = BlockData.theChunker.getBlockDictionary(blockID)
	var ogImage = blockData["texture"].get_image()
	
	var pos = 0
	if blockData["multitile"]:
		pos = info * 8
	
	var img = ogImage.get_region(Rect2(pos,0,8,8))
	sprite.texture = ImageTexture.create_from_image(img)
	
	if blockData["rotateTextureToGravity"]:
		var tile = planet.posToTile(position)
		var dir = planet.DATAC.getPositionLookup(tile.x,tile.y)
		sprite.rotation = dir * (PI/2)
		
	if blockID == 33:
		if ogTile == PlayerData.currentSelectedChest:
			PlayerData.closeChest()
		if planet.chestDictionary.has(ogTile):
			savedChest = planet.chestDictionary[ogTile]
			planet.chestDictionary.erase(ogTile)
	
	$CPUParticles2D.direction = direction
	$CPUParticles2D.emitting = true
	$CPUParticles2D.reparent(get_parent(),true)
	SoundManager.playSound("blocks/spitter",global_position,1.0,0.1)

func _process(delta):
	var collider = move_and_collide( velocity*delta )
	if collider: # has hit wall
		
		# get position
		var tile = planet.posToTile(position)
		
		if planet.DATAC.getTileData(tile.x,tile.y) > 1:
			
			BlockData.spawnBreakParticle(tile.x,tile.y,blockID,blockData["breakParticleID"],planet,0,true)
			BlockData.spawnGroundItem(tile.x,tile.y,BlockData.getBlockDrop(blockID,blockData["itemToDrop"]),planet)
			
			if blockID == 33: # is chest
				if savedChest != "poop":
					PlayerData.dropChestContainer(planet,Vector2(tile.x,tile.y),savedChest)
			
			queue_free()
			return
		
		planet.DATAC.setInfoData(tile.x,tile.y,info)
		planet.editTiles( { Vector2i( tile.x,tile.y ):blockID },true )
		
		if blockID == 33: # is chest
			if savedChest != "poop":
				planet.chestDictionary[Vector2(tile.x,tile.y)] = savedChest
		
		queue_free()
	#sprite.rotate(6.0*delta)
	
	ticks += 1
