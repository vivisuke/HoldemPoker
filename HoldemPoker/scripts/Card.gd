extends Sprite

const NumTable = "A234567890JQK"
func _ready():
	pass # Replace with function body.

func set_suit(st):
	$Suit.set_frame(st)
func set_number(num):
	if num == 10:
		$Label.text = "10"
	else:
		$Label.text = NumTable[num-1]
func set_sn(st, num):
	set_suit(st)
	set_number(num)
