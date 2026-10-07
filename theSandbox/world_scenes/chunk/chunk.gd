extends Node2D

@onready var mainLayerSprite = $mainLayer
@onready var backLayerSprite = $backLayer
@onready var waterLayerSprite = $waterLayer
@onready var animLayerSprite = $animLayer
#@onready var backlayerImmune = $backlayerImmune
@onready var body = $StaticBody2D

const CHUNKSIZE :int= 8

var pos :Vector2= Vector2.ZERO
var onScreen :bool= false
var id4 :int= 0

var MUSTUPDATELIGHT :bool= false

var planet :Planet= null
var drawnForFirstTime :bool = false

func _ready():
	planet = get_parent().get_parent()
	
	pos = position
	position = (pos * 64) - Vector2(planet.SIZEINCHUNKS*32,32*planet.SIZEINCHUNKS)
	
	# chunk variant used for tick timing/lighting state.
	id4 = (int(pos.x) % 2)+((int(pos.y) % 2)*2)
	
	set_process(false)
	body.set_process(false)
	
	drawData()
	var d :Dictionary= BlockData.theChunker.runOnLoad(planet.DATAC,Vector2i(pos))
	planet.editTiles(d)

func tickUpdate():
	MUSTUPDATELIGHT = true
	# call c++ chunkcode and return
	return BlockData.theChunker.tickUpdate(planet.DATAC,pos,onScreen,GlobalRef.daylightMult)

func drawData():
	# redraw the chunk's collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(8,8)
	clearCollisions()

	# use c++ to generate the textures for the chunk's layers
	var images = BlockData.theChunker.generateTexturesFromData(planet.DATAC,pos,body,shape,false)
	mainLayerSprite.texture = ImageTexture.create_from_image(images[0])
	backLayerSprite.texture = ImageTexture.create_from_image(images[1])
	animLayerSprite.texture = ImageTexture.create_from_image(images[2])
	#backlayerImmune.texture = ImageTexture.create_from_image(images[3])
	
	drawLiquid()
	return

# liquid blocks drawn separately to allow for animation and transparency
func drawLiquid():
	var images = BlockData.theChunker.drawLiquid(planet.DATAC,pos,false)
	waterLayerSprite.texture = ImageTexture.create_from_image(images[0])

func clearCollisions():
	for i in body.get_children():
		i.queue_free()

func _on_visible_on_screen_notifier_2d_screen_entered():
	onScreen = true
	mainLayerSprite.visible = onScreen
	backLayerSprite.visible = onScreen

func _on_visible_on_screen_notifier_2d_screen_exited():
	onScreen = false
	mainLayerSprite.visible = onScreen
	backLayerSprite.visible = onScreen

# debug show/hide icon when testing
func flicker(visshow):
	$Icon.visible = visshow

func _exit_tree():
	BlockData.theChunker.resetLight(planet.DATAC,Vector2i(pos))
