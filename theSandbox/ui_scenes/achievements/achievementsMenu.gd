extends Node2D

@onready var medalBoxScene = preload("res://ui_scenes/achievements/medal_box.tscn")

signal menuClosed

var nghover :bool = false

func _ready():
	initializeAchievements()
	NG.on_session_change.connect(connectNG)
	if OS.has_feature('web'):
		$Ng.hide()

func initializeAchievements():
	for medal in AchievementData.medalDictionary:
		var ins = medalBoxScene.instantiate()
		var dic = AchievementData.medalDictionary[medal]
		if AchievementData.isMedalUnlocked(medal):
			ins.setData(load(dic["icon"]),dic["name"],dic["desc"])
		else:
			ins.setData(null,dic["name"],dic["desc"])
		$ScrollContainer/VBoxContainer.add_child(ins)

func clear():
	for c in $ScrollContainer/VBoxContainer.get_children():
		c.queue_free()

func _on_text_button_pressed():
	hide()
	emit_signal("menuClosed")

# newgrounds connection
func _on_connecttong_pressed():
	NG.sign_in()
	$Ng.scale = Vector2(0.5,0.5)
	if NG.signed_in:
		$Ng/Label.text = "signed in!"
	
func connectNG(session):
	$Ng/Label.text = "signed in!"
	AchievementData.unlockAllLostMedals()
	clear()
	initializeAchievements()


func _on_connecttong_mouse_entered():
	nghover = true


func _on_connecttong_mouse_exited():
	nghover = false

func _process(delta):
	if nghover:
		$Ng.scale = lerp($Ng.scale,Vector2(1.2,1.2),0.2)
	else:
		$Ng.scale = lerp($Ng.scale,Vector2(1.0,1.0),0.2)
