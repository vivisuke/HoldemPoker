extends Sprite

const NumTable = "A234567890JQK"
func _ready():
	pass # Replace with function body.

func set_suit(st):
	$Suit.set_frame(st)
func set_rank(rank):
	if rank == 10:
		$Label.text = "10"
	else:
		$Label.text = NumTable[rank-1]
func set_sr(st, rank):
	set_suit(st)
	set_rank(rank)
