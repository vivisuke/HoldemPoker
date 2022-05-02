extends Sprite

signal open_finished

enum {
	BG_WAIT = 0,
	BG_PLY,			# 手番
	BG_FOLDED,
}
const OPENING_NONE = 0
const OPENING_FH = 1	# 蜑榊濠
const OPENING_SH = 2	# 蠕悟濠
const TH_SCALE = 1.5

#var opening : bool = false
var opening : int = 0
var theta = 0.0
var chips = 0
var prev_chips = 0		# 各ゲーム開始時チップ数

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
func get_chip_pos():	# 下部チップ位置（グローバル座標系）を返す
	return $Chips.get_global_position()
func get_chips(): return chips
func set_chips(c : int):
	chips = c
	$ChipsLabel.text = String(chips)
func add_chips(c : int):
	chips += c
	$ChipsLabel.text = String(chips)
func sub_chips(c : int):
	add_chips(-c)
	#chips -= c
	#$ChipsLabel.text = String(chips)
func open_cards():
	pass
func show_bet_chips(sw : bool):
	if sw: $Chips.show()
	else: $Chips.hide()
func set_bet_chips(ch : int):
	show_bet_chips(true)
	$Chips/BetLabel.text = String(ch)
func copy_to_prev_chips():		# 各ゲーム開始時チップ数保存
	prev_chips = chips
func show_diff_chips(b : bool):		# b: true for チップ増減を表示
	var txt = String(chips)
	if b:
		txt += " ("
		if chips > prev_chips:
			txt += "+"
			set_BG(BG_PLY)		# 黄色
		else:
			set_BG(BG_WAIT)		# グレイ
		txt += String(chips - prev_chips) + ")"
	$ChipsLabel.text = txt
	pass
func _process(delta):
	pass
