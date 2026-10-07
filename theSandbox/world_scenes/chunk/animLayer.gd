extends Sprite2D
# sets the animation frame to update every 20 ticks
var tick = 0
func _physics_process(delta):
	tick += 1
	if tick % 20 == 0:
		if frame < 2:
			frame += 1
		else:
			frame = 0
