extends Node2D

signal open_finished

const OPENING_NONE = 0
const OPENING_FH = 1	# 蜑榊濠
const OPENING_SH = 2	# 蠕悟濠
const TH_SCALE = 1.5
const RANK_10 = 10 - 2
const NumTable = "234567890JQKA"
const N_RANK_BITS = 4

var sr = 0		# (suit << 4) | rank
var opening : int = 0
var theta = 0.0

func _ready():
	$Back.show()
	$Front.hide()
	pass
func get_sr():
	return sr
func set_suit(st):
	$Front/Suit.set_frame(st)
func set_rank(rank):
	if rank == RANK_10:
		$Front/Label.text = "10"
	else:
		$Front/Label.text = NumTable[rank]
func set_sr(st, rank):
	sr = (st << N_RANK_BITS) | rank
	set_suit(st)
	set_rank(rank)
func do_open():
	opening = OPENING_FH
	theta = 0.0
	$Front.hide()
	$Back.show()
	$Back.set_scale(Vector2(1.0, 1.0))
func _process(delta):
	if opening == OPENING_FH:
		theta += delta * TH_SCALE
		if theta < PI/2:
			$Back.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_SH
			$Front.show()
			$Back.hide()
			theta -= PI
			$Front.set_scale(Vector2(cos(theta), 1.0))
	elif opening == OPENING_SH:
		theta += delta * TH_SCALE
		theta = min(theta, 0)
		if theta < 0:
			$Front.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_NONE
			$Front.set_scale(Vector2(1.0, 1.0))
			emit_signal("open_finished")
	pass
