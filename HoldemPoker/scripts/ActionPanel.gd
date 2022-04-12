extends ColorRect

func _ready():
	pass
func set_text(txt):
	$Label.text = txt
func get_text():
	return $Label.text
