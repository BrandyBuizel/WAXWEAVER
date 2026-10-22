extends Node2D

@export var texture :Texture2D
@export var scrollAmount :Vector2 = Vector2(1,1)
var ar :Array[Vector2]= [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2(1,1)]

@onready var origin = $origin

var s :Vector2= Vector2.ZERO

# The picture is repeated in a grid. The grid is rebuilt to be big enough to cover the
# screen whenever the view size changes (wide / tall windows need more tiles).
var cols :int = 0
var rows :int = 0
var tiles :Array[Sprite2D] = []

func _ready():
	s = texture.get_size()
	buildTiles()
	Background.backgroundScrolled.connect(scroll)
	Options.viewWidthChanged.connect(func(_w): buildTiles())

func buildTiles():
	var view :Vector2i = Options.getViewSize()
	# origin can sit up to one tile off-screen, so the grid needs one extra row/column
	var newCols :int = maxi(3, ceili(view.x / s.x) + 1)
	var newRows :int = maxi(2, ceili(view.y / s.y) + 1)
	if newCols == cols and newRows == rows:
		return
	cols = newCols
	rows = newRows
	
	for t in tiles:
		t.queue_free()
	tiles.clear()
	
	for y in range(rows):
		for x in range(cols):
			var ins = Sprite2D.new()
			ins.texture = texture
			ins.centered = false
			ins.position = ar[i] * s
			origin.add_child(ins)
			tiles.append(ins)
			
	Background.backgroundScrolled.connect(scroll)

func scroll(amount:Vector2):
	origin.position += amount * scrollAmount
	
	if origin.position.x > 0:
		origin.position.x -= s.x
	if origin.position.y > 0:
		origin.position.y -= s.y
	if origin.position.x < -s.x:
		origin.position.x += s.x
	if origin.position.y < -s.y:
		origin.position.y += s.y
