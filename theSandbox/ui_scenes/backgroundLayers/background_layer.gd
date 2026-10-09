extends Node2D

@export var sprite : Texture
@export var multiplierX : float = 1.0
@export var multiplierY : float = 1.0

@export var color : Color = Color.WHITE

var width = 400
var height = 400

var mat = preload("res://ui_scenes/backgroundLayers/background_layer_material.tres").duplicate()

func _ready():
	if sprite == null:
		return
	
	width = sprite.get_size().x
	height = sprite.get_size().y
	
	for i in range(4):
		var ins = Sprite2D.new()
		ins.texture = sprite
		ins.centered = false
		ins.material = mat
		ins.position.x = (i%2)*width
		ins.position.y = int(i>1)*height
		updateModulate(color)
		add_child(ins)

func updatePosition(moveDir):
	position += moveDir * Vector2(multiplierX,multiplierY)
	if position.x < -width:
		position.x += width
	if position.y < -height:
		position.y += height
	if position.x > 0:
		position.x -= width
	if position.y > 0:
		position.y -= height
	
# theres gotta be a better way to do this !!
func updateModulate(newColor):
	mat.set_shader_parameter("modulate",newColor)
