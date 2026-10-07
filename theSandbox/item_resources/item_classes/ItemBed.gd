extends Item
class_name ItemBed

@export var blockID := 0

var size :Vector2 = Vector2(2,1)

@export var grounded :bool = false
@export var needsWalls :bool = false

@export var bedType :int = 0


func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):

	if planet == null:
		# cancel if not on planet
		return "failure"

	var side = (1 - GlobalRef.playerSide) * 2

	var alter := Vector2(tileX,tileY) + Vector2(0,-size.y + 1).rotated((PI/2)*planetDir)

	if planet is Ship:
		alter = Vector2(tileX,tileY) + Vector2(0,-size.y + 1)

	var o = planet.DATAC.getPositionLookup(alter.x,alter.y)
	var d = size.rotated(o*(PI/2))
	if checkAvailableArea(alter.x,alter.y,d,planet,o):
		playSound(tileX,tileY,planet)
		planet.editTiles(makeCoolEditArray(alter.x,alter.y,d,planet,o%2==0,side),true)
		PlayerData.consumeSelected()

# returns whether or not block can be placed
func checkAvailableArea(startX,startY,dimensions:Vector2,planet,originalDir):

	if grounded:
		var find = Vector2( startX , startY)
		for i in range(size.x):
			var rot = find + Vector2( i, size.y ).rotated(originalDir*(PI/2))
			var worldPos = Vector2i( rot.x, rot.y)
			var block = planet.DATAC.getTileData(worldPos.x,worldPos.y)
			if !BlockData.theChunker.getBlockDictionary(block)["hasCollision"]:
				return false


	for x in range( round( abs(dimensions.x) ) ):
		for y in range( round( abs(dimensions.y) ) ):
			var worldPos = Vector2i( startX+x, startY+y)
			# account for negative dimensions
			if dimensions.x < 0:
				worldPos.x = startX-x
			if dimensions.y < 0:
				worldPos.y = startY-y

			var block = planet.DATAC.getTileData(worldPos.x,worldPos.y)
			var curDir = planet.DATAC.getPositionLookup(worldPos.x,worldPos.y)
			#var bg = planet.DATAC.getBGData(tileX,tileY)
			if curDir != originalDir:
				# invalid if on corner of world
				return false
			if ![0,1].has(block):
				# invalid if solid tile exists
				return false

			if worldPos.x < 0 or worldPos.x >= planet.SIZEINCHUNKS * 8 or worldPos.y < 0 or worldPos.y >= planet.SIZEINCHUNKS * 8:
				# invalid if any tile is outside boundaries
				return false

	return true

func makeCoolEditArray(startX,startY,dimensions:Vector2,planet,epicRotate,side):

	var DICK = {}
	var i = 0

	for x in range( round( abs(dimensions.x) ) ):

		for y in range( round( abs(dimensions.y) ) ):
			var worldPos = Vector2i( startX+x, startY+y)
			# account for negative dimensions
			if dimensions.x < 0:
				worldPos.x = startX-x
			if dimensions.y < 0:
				worldPos.y = startY-y

			DICK[worldPos] = blockID

			planet.DATAC.setInfoData(worldPos.x,worldPos.y,i+side)
			i += 1

	return DICK

# sounds
func playSound(tileX:int,tileY:int,planet):
	var s = SoundManager.getMineSound(abs(blockID))
	var p = GlobalRef.player.global_position
	SoundManager.playSoundStream( s,p, SoundManager.blockPlaceVol, 0.1,"BLOCKS" )