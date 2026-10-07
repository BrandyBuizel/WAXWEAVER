extends Node2D

var medalName = "openGame"

var ticks :int = 0

func _ready():
	position = Vector2(400,370)
	$icon.texture = load(AchievementData.medalDictionary[medalName]["icon"])
	$ScrollContainer/Label.text = AchievementData.medalDictionary[medalName]["name"]
	
	play()

func play():
	var tweenUp = get_tree().create_tween() # animate popup positionally
	tweenUp.tween_property(self,"position:y",300,0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	
	await get_tree().create_timer(6.0).timeout
	
	var tweenDown = get_tree().create_tween()
	tweenDown.tween_property(self,"position:y",370,0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)

func _process(delta):
	ticks += 1
	
	if ticks > 90 and ticks % 3 == 0:
		$ScrollContainer.scroll_horizontal += 1
