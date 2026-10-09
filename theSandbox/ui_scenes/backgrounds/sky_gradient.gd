extends Node2D

@export var gradient :Gradient
@export var evilGradient :Gradient

func _process(delta):
	
	$Sprite2D.modulate = gradient.sample(GlobalRef.currentTime)
	if GlobalRef.bossEvil:
		$Sprite2D.modulate = evilGradient.sample(GlobalRef.currentTime)
	modulate.a = GlobalRef.daylightMult
