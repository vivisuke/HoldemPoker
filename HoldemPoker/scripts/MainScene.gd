extends Node2D

#enum { CLUB = 0, DIAMOND, HEART, SPADE, }
enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
#const N_SUIT = 4
#const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT

var deck = []		# 要素：(suit << 4) | rank

func _ready():
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st = i / N_RANK
		var rank = i % N_RANK + 1
		deck
	#
	$PlayerBG1.set_name("vivisuke")
	$PlayerBG1.set_card1(SPADES, RANK_A)
	$PlayerBG1.set_card2(SPADES, RANK_K)
	$PlayerBG1.set_BG(1)
	$PlayerBG2.set_BG(2)
	#
	$Table/Card1.set_sr(CLUBS, RANK_A)
	$Table/Card2.set_sr(DIAMONDS, RANK_5)
	$Table/Card3.set_sr(HEARTS, RANK_10)
	$Table/Card4.set_sr(SPADES, RANK_Q)
	$Table/Card5.set_sr(HEARTS, RANK_K)
	#
	#$PlayerBG1.open_cards()
	pass

func _input(event):
	if event is InputEventMouseButton:
		$PlayerBG1.open_cards()
		

func _process(delta):
	pass
