extends Node2D

@onready var container = $container
@onready var label = $Label

signal clicked

var materialsToLoad = [
	"res://object_scenes/ground_item/groundItemOutlineShader.tres",
	"res://object_scenes/ground_item/tintItemShader.tres",
	"res://object_scenes/lightmapCover/lightmap.tres",
	"res://ui_scenes/playerHUD/inventory/slotMaterial.tres",
]

var motd :Array[String]= [ # messages to display when opening the window
	"hi",
	"bring it back!",
	"what if goku was betrayed and imprisoned in the hyberbolic time chamber?",
	"please play my hideo game",
	"buy bug ball 3D NOW!",
	"gordon feetman",
	"your's truly, the pee man",
	"shoutout tom fulp",
	"goodnight, back to the future on VHS",
	"proud daily second award winner",
	"green square!!",
	"oldest trick in the book...",
	"okay, seventh gear!",
	"so unorganized...",
	"dude, like... spiral out dude... learn to swim man...",
	"billions must smile",
	"stay prog my friends",
	"fat fucking squishy snail",
	"True...",
	"you live only once so try to spend as much time on Computer as it is possible.",
	"top dog entertainment",
	"oohh fiddlesticks, what now?",
	"secret: try naming your world 'skyblock' !!",
	"this is half life 3 actually",
	"game by poop studios",
	"fish",
	"A whole orange will float on water, but a peeled orange, will sink. Who gives a shit?",
	"it looks, robot lived in.",
	"timmy christmas 2",
	"have you seen the movie tron? I haven't",
	"a chair ! its MINE !",
	"shoutout fallenchungus",
	"fuck my stupid chud life",
	"basically, this shit is yummy to me",
	"secret: try naming your world 'lattice' ???",
	"wanna play in hardcore? name your world 'hardcore'",
	"geoff keighley said this was his favorite game ever",
	"you can reach me at gabeN at valve software dot com",
	"tiddlywinks...",
	"tobuscus adventures",
	"macs are for dumbs and nerds and jocks",
	"newgrounds 4ever",
]


func _ready():
	
	var r = randi() % motd.size()
	DisplayServer.window_set_title("waxweaver - " + motd[r])
	
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	var count = 0
	
	container.position.x = 216 - (16*materialsToLoad.size())
	
	label.text = "compiling shaders ( " + str(count+1) + " / " + str(materialsToLoad.size()) + " )"
	
	for i in materialsToLoad:
		
		var img = Sprite2D.new()
		img.texture = load("res://world_scenes/main_menu/shaderLoader/shaderPreview.png")
		img.position.x = count * 32
		img.material = load(i)
		container.add_child(img)
		
		label.text = "compiling shaders ( " + str(count+1) + " / " + str(materialsToLoad.size()) + " )"
		count += 1
		await get_tree().create_timer(0.15).timeout
	
	if OS.has_feature("web"):
		label.text = "click to focus window"
		await clicked
	
	get_tree().change_scene_to_file("res://ui_scenes/mainMenu/main_menu.tscn")


func _on_button_pressed():
	emit_signal("clicked")
