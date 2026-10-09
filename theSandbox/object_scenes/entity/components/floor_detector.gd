extends Node

var planet = null

var tile :int = 0
var info :int = 0

var tick :int= 0

@onready var parent = get_parent()

func _ready():
	
	set_process( false )
	
	if parent is Player:
		await get_tree().create_timer(0.5).timeout
	
	planet = get_parent().get_parent().get_parent()
	
	set_process( planet is Planet )

func _process(delta):
	tick += 1
	if tick % 4 != 0:
		return
	
	var t = planet.posToTile(parent.position)
	if t == null:
		return
	var dir = planet.DATAC.getPositionLookup(t.x,t.y)
	var rot = Vector2i(Vector2(0,1).rotated(dir * (PI/2)))
	tile = planet.DATAC.getTileData(t.x + rot.x,t.y + rot.y)
	info = planet.DATAC.getInfoData(t.x + rot.x,t.y + rot.y)

func getFloorTile() -> int:
	return tile

func getFloorInfo() -> int:
	return info
