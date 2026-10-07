extends Node2D

var planet = null
var planetDir = 0
var tileX :int= 0
var tileY :int= 0
var blockID = 0

var damage = 0

var mineMultiplier := 1.0

var baseRotation = 0

@onready var texture = $blockTexture
@onready var sound = $digSound
var soundTick :float= 0.1

var blockMiningLevel :int= 0
var cantMineSparkTick :float= 0.51

var stream :AudioStreamOggVorbis= null

func _ready():
	
	if !is_instance_valid(planet):
		return
	
	stream = SoundManager.getMineSound(blockID)
	
	var blockData = BlockData.theChunker.getBlockDictionary(blockID)
	texture.texture = blockData["texture"]
	
	if blockData["breakParticleID"] == -1:
		$particles.texture = blockData["texture"]
	else:
		var particleData = BlockData.theChunker.getBlockDictionary(blockData["breakParticleID"])
		$particles.texture = particleData["texture"]
	
	if blockData["connectedTexture"]:
		texture.hframes = 16
		texture.frame = BlockData.theChunker.scanBlockOpen(planet.DATAC,tileX,tileY,planetDir * int(blockData["rotateTextureToGravity"])) / 8
		$Sprite.hframes = 16
		$Sprite.frame = texture.frame
		
		var img = texture.texture.get_image()
		var croppedImg :Image= img.get_region( Rect2i( Vector2i(0,0), Vector2i(8,8) ) )
		var tex = ImageTexture.create_from_image(croppedImg)
		
		$particles.texture = tex
	elif blockData["multitile"]:
		
		var img = texture.texture.get_image()
		var i = planet.DATAC.getInfoData(tileX,tileY)
		var croppedImg :Image= img.get_region( Rect2i( Vector2i(i*8,0), Vector2i(8,8) ) )
		var tex = ImageTexture.create_from_image(croppedImg)
		
		texture.texture = tex
		$particles.texture = tex
	
	if blockData["animated"]:
		texture.vframes = 3
		$Sprite.vframes = 3
	
	if blockData["rotateTextureToGravity"]:
		texture.rotation = (PI/2) * planet.getBlockPosition(tileX,tileY)
		baseRotation = texture.rotation
		$Sprite.rotation = texture.rotation
		
	$Sprite.texture = texture.texture
	blockMiningLevel = blockData["miningLevel"]
	

func _process(delta):
	
	# this shit sucks fix it
	if planet == null:
		print_debug("BLOCK BREAK HAS NO PLANET ASSIGNED")
		return
	
	if Input.is_action_pressed("mouse_left"):
		
		if blockID > 1:
			playDigSound(delta)
		
		var itemData = ItemData.data[PlayerData.inventory[PlayerData.selectedSlot][0]]
		if itemData is ItemMining:
			damage += delta * itemData.miningMultiplier * Stats.miningMultiplier
			cantMineSparkTick += delta
			
			var canMine :bool= blockMiningLevel <= itemData.miningLevel
			
			if canMine:
				var breakTime = BlockData.theChunker.getBlockDictionary(blockID)["breakTime"]
				texture.position.x = ((randi() % 3)-1) * (damage / breakTime)
				texture.position.y = ((randi() % 3)-1) * (damage / breakTime)
				texture.rotation = baseRotation + ((randi() % 3)-1) * (damage / breakTime) * 0.1
			
				if damage >= breakTime :
					var edit = Vector2i(tileX,tileY)
					planet.editTiles( { edit: -1 },true )
					GlobalRef.player.lastTileItemUsedOn = Vector2(-10,-10)
					queue_free()
			else:
				if cantMineSparkTick >= 0.5: # do failure spark
					cantMineSparkTick -= 0.5
					$spark.emitting = true
					SoundManager.playSound("mining/mineFail",global_position,0.7,0.05)
			
		else:
			queue_free()
	else:
		queue_free()
	
	var mousePos = to_local(get_global_mouse_position())
	if abs(mousePos.y) > 4:
		queue_free()
	if abs(mousePos.x) > 4:
		queue_free()

# sounds
func playDigSound(delta):
	soundTick += delta
	
	if soundTick > 0.2:
		soundTick -= 0.2
		SoundManager.playSoundStream(stream,global_position,SoundManager.blockMineVol,0.1,"BLOCKS")
