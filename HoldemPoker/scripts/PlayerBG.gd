extends Sprite


func _ready():
	pass # Replace with function body.

func set_BG(id):
	set_frame(id)
func set_name(name : String):
	$NameLabel.text = name
