extends Node2D

const N_SUIT = 4
const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT

enum { CLUB = 0, DIAMOND, HEART, SPADE, }

var deck = []		# 要素：(suit << 4) | rank

func _ready():
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st = i / N_RANK
		var rank = i % N_RANK + 1
		deck
	#
	$PlayerBG1.set_name("vivisuke")
	$PlayerBG1.set_card1(SPADE, 1)
	$PlayerBG1.set_card2(SPADE, 13)
	$PlayerBG1.set_BG(1)
	$PlayerBG2.set_BG(2)
	#
	$Table/Card1.set_sr(CLUB, 1)
	$Table/Card2.set_sr(DIAMOND, 5)
	$Table/Card3.set_sr(HEART, 10)
	$Table/Card4.set_sr(SPADE, 12)
	$Table/Card5.set_sr(HEART, 13)
	#
	#$PlayerBG1.open_cards()
	pass

func _input(event):
	if event is InputEventMouseButton:
		$PlayerBG1.open_cards()
		

func _process(delta):
	pass
