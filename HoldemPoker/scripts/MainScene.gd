extends Node2D

enum { CLUB = 0, DIAMOND, HEART, SPADE, }

func _ready():
	$PlayerBG1.set_name("vivisuke")
	$PlayerBG1.set_card1(SPADE, 1)
	$PlayerBG1.set_card2(SPADE, 13)
	$PlayerBG1.set_BG(1)
	$PlayerBG2.set_BG(2)
	#
	$Table/Card1.set_sn(CLUB, 1)
	$Table/Card2.set_sn(DIAMOND, 5)
	$Table/Card3.set_sn(HEART, 10)
	$Table/Card4.set_sn(SPADE, 12)
	$Table/Card5.set_sn(HEART, 13)
	#$Table/Card1.set_suit(CLUB)
	#$Table/Card2.set_suit(DIAMOND)
	#$Table/Card3.set_suit(HEART)
	#$Table/Card4.set_suit(SPADE)
	#$Table/Card5.set_suit(HEART)
	#$Table/Card1.set_number(1)
	#$Table/Card2.set_number(5)
	#$Table/Card3.set_number(10)
	#$Table/Card4.set_number(12)
	#$Table/Card5.set_number(13)
	#
	#$PlayerBG1.open_cards()
	pass

func _input(event):
	if event is InputEventMouseButton:
		$PlayerBG1.open_cards()
		

func _process(delta):
	#$Card1.set_suit(0)
	#$Card2.set_suit(1)
	#$Card3.set_suit(2)
	#$Card4.set_suit(3)
	pass
