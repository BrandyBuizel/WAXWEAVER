extends Item
class_name ItemLunarBeacon

# Lunar Beacon: only works on the moon. Fades the game to white and starts the bullet hell fight.
func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	if BulletHell.active or Rocket.launching:
		return
	if !Rocket.isOnMoon():
		GlobalRef.sendError("The beacon only works on the moon.")
		return
	if Network.isMultiplayerGame:
		GlobalRef.sendError("The beacon doesn't work in multiplayer yet.")
		return
	BulletHell.start()
