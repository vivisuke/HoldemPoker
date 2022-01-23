extends Sprite

#const NumTable = "A234567890JQK"
const RANK_10 = 10 - 2
const NumTable = "234567890JQKA"
const N_RANK_BITS = 4

var sr = 0		# (suit << 4) | rank

func _ready():
	pass # Replace with function body.

func get_sr():
	return sr
func set_suit(st):
	$Suit.set_frame(st)
func set_rank(rank):
	if rank == RANK_10:
		$Label.text = "10"
	else:
		$Label.text = NumTable[rank]
func set_sr(st, rank):
	sr = (st << N_RANK_BITS) | rank
	set_suit(st)
	set_rank(rank)
