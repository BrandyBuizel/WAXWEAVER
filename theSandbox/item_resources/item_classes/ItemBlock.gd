extends Item
class_name ItemBlock

@export var blockID := 0


func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):

	if planet == null:
		# cancel if not on planet
		return "failure"

	if GlobalRef.player.myTile == Vector2(tileX,tileY):
		if BlockData.checkForCollision(blockID):
			return "failed"

	var block = planet.DATAC.getTileData(tileX,tileY)
	var bg = planet.DATAC.getBGData(tileX,tileY)

	if ![0,1,17,77,82,90,131].has(block):
		# cancel if target tile isn't empty
		return "failure"

	if ![0,1].has(bg):
		# succeed if wall tile exists
		var edit = Vector2i(tileX,tileY)
		planet.editTiles({edit:blockID},true)
		PlayerData.consumeSelected()
		playSound(tileX,tileY,planet)
		return "success"

	for i in range(4):
		# search neighboring tiles
		var s = Vector2(1,0).rotated((PI/2)*i)
		var tile = Vector2(tileX,tileY) + Vector2(int(s.x),int(s.y))
		if tile.x < 0 or tile.x >= planet.SIZEINCHUNKS * 8 or tile.y < 0 or tile.y >= planet.SIZEINCHUNKS * 8:
			continue

		if ![0,1].has(planet.DATAC.getTileData(tile.x,tile.y)):
			var edit = Vector2i(tileX,tileY)
			planet.editTiles({edit:blockID},true)
			PlayerData.consumeSelected()
			playSound(tileX,tileY,planet)
			return "success"

	return "failure"

# sounds
func playSound(tileX:int,tileY:int,planet):
	var s = SoundManager.getMineSound(blockID)
	var p = GlobalRef.player.global_position
	SoundManager.playSoundStream( s,p, SoundManager.blockPlaceVol, 0.1,"BLOCKS" )