extends Sprite

signal open_finished

const OPENING_NONE = 0
const OPENING_FH = 1	# 前半
const OPENING_SH = 2	# 後半
const TH_SCALE = 1.5

#var opening : bool = false
var opening : int = 0
var theta = 0.0
var chips = 0

func _ready():
	pass # Replace with function body.

func set_BG(id):
	set_frame(id)
func set_name(name : String):
	$NameLabel.text = name
func set_card1(st, rank):
	#$Card1.set_sr(st, rank)
	pass
func set_card2(st, rank):
	#$Card2.set_sr(st, rank)
	pass
func set_hand(txt):
	$HandLabel.text = txt
func get_chips(): return chips
func set_chips(c : int):
	chips = c
	$ChipsLabel.text = String(chips)
func sub_chips(c : int):
	chips -= c
	$ChipsLabel.text = String(chips)
func open_cards():
	pass
func show_bet_chips(sw : bool):
	if sw: $Chips.show()
	else: $Chips.hide()
func set_bet_chips(ch : int):
	show_bet_chips(true)
	$Chips/BetLabel.text = String(ch)
func _process(delta):
	pass
