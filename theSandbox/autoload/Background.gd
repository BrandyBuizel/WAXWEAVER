extends Node

## awesome epic background script ##
signal backgroundScrolled(amount:Vector2)

var bgDictionary = {
	"forest":"res://ui_scenes/backgrounds/forest/forest_bg.tscn",
	"sun":"res://ui_scenes/backgrounds/sun/sun_bg.tscn",
}

func scroll(amount:Vector2):
	backgroundScrolled.emit(amount)

func setBG(type:String):
	if bgDictionary.has(type):
		GlobalRef.camera.changeBG(bgDictionary[type])

func clearBG():
	GlobalRef.camera.changeBG(null)
