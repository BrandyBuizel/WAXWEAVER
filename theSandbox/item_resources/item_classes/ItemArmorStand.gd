extends Item
class_name ItemArmorStand

# block type
@export var blockID := 0

# Size of the multi-tile structure being placed.
@export var size :Vector2i=Vector2i(3,2)

@export var grounded :bool = false # requires solid ground beneath it
@export var needsWalls :bool = false # requires wall blocks behind it
@export var runLoad :bool = false

var replaceableBlocks :Array[int] = [0,1,17,77,82,90,131]

func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	if planet == null:
		# ignore placement attempts outside a valid planet (just one, but could be expanded upon by modding)
		return "failure"

	if checkIfPlaceable(tileX,tileY,planet):
		playSound(tileX,tileY,planet)
		PlayerData.consumeSelected()
		var tileDic = placeTiles(tileX,tileY,planet)
		planet.editTiles( tileDic,false )
		if runLoad:
			var lookup = BlockData.lookup
			for key in tileDic.keys():
				planet.DATAC.setTimeData(key.x,key.y,0)
				var changes = lookup.runOnLoad(key.x,key.y,planet.DATAC,planetDir,blockID)
				planet.editTiles( changes,false )

func placeTiles(tileX:int,tileY:int,planet):
	var DICK = {}

	var startInfo = (size.x * size.y) - size.x
	var mltY = startInfo / size.x
	var mltX = (size.x * mltY * -1) + startInfo
	var dir = planet.DATAC.getPositionLookup(tileX,tileY)
	var i = 0

	for xi in range(size.x):
		for yi in range(size.y):
			var rot = Vector2( xi - mltX, yi - mltY ).rotated((PI/2)*dir);
			var worldX :int = tileX + round(rot.x)
			var worldY :int = tileY + round(rot.y)
			var replacePos := Vector2i( worldX,worldY )
			DICK[replacePos] = blockID;

			# placement metadata to be reconstructed
			var info = (yi * size.x) + i
			if info == 0:
				info = GlobalRef.playerSide - 1
			planet.DATAC.setInfoData(worldX,worldY,info)
			i += 1

	return DICK # kek

func checkIfPlaceable(tileX:int,tileY:int,planet):
	var startInfo = (size.x * size.y) - size.x
	var mltY = startInfo / size.x
	var mltX = (size.x * mltY * -1) + startInfo
	var dir = planet.DATAC.getPositionLookup(tileX,tileY)

	for xi in range(size.x):
		for yi in range(size.y + int(grounded)):
			var rot = Vector2( xi - mltX, yi - mltY ).rotated((PI/2)*dir);
			var worldX :int = tileX + round(rot.x)
			var worldY :int = tileY + round(rot.y)
			var tile = planet.DATAC.getTileData(worldX,worldY)

			if grounded && yi == size.y:
				# the bottom row must rest on a solid block if grounded placement is required
				if !BlockData.theChunker.getBlockDictionary(tile)["hasCollision"]:
					return false
			elif !replaceableBlocks.has(tile):
				return false

			if needsWalls:
				var BG = planet.DATAC.getBGData(worldX,worldY)
				if BG < 2:
					return false

			if worldX < 0 or worldX >= planet.SIZEINCHUNKS * 8:
				return false
			if worldY < 0 or worldY >= planet.SIZEINCHUNKS * 8:
				return false

			var newDir = planet.DATAC.getPositionLookup(worldX,worldY)
			if newDir != dir:
				return false

	return true

# sounds
func playSound(tileX:int,tileY:int,planet):
	var s = SoundManager.getMineSound(blockID)
	var p = GlobalRef.player.global_position
	SoundManager.playSoundStream( s,p, SoundManager.blockPlaceVol, 0.1,"BLOCKS" )