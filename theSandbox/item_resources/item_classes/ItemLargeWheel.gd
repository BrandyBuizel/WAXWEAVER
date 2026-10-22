extends ItemBlock
class_name ItemLargeWheel
## Places the 3x3 large water wheel centred on the clicked tile.
## Each of the 9 tiles stores its piece number (0..8, row by row) in its info data, bit 4 (16) = vertical axle.

func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	
	if planet == null:
		return "failure"
	
	for iy in range(-1,2):
		for ix in range(-1,2):
			var t :int = planet.DATAC.getTileData(tileX + ix,tileY + iy)
			if ![0,1,17,77,82,90,131].has(t):
				return "failure" # something is in the way
	
	var edits :Dictionary = {}
	for iy in range(-1,2):
		for ix in range(-1,2):
			var piece :int = (iy + 1) * 3 + (ix + 1)
			planet.DATAC.setInfoData(tileX + ix,tileY + iy,piece)
			edits[Vector2i(tileX + ix,tileY + iy)] = blockID
	
	planet.editTiles(edits,true)
	PlayerData.consumeSelected()
	playSound(tileX,tileY,planet)
	return "success"
