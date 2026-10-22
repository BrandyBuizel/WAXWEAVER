extends Resource
class_name EnemyAI

var frame = 0
var flipped = false

func onFrame(delta,enemy):
	pass

func onHit(enemy):
	pass

func onDeath(enemy):
	pass

func onSpawn(enemy):
	pass

func getAggro():
	if is_instance_valid(GlobalRef.player) and !KineticGear.hidden(): # cardboard box: you are not seen
		return GlobalRef.player
	return null
