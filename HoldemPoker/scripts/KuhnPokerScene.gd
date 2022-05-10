extends Node2D

enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
const RANK_STR = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
enum {		# 状態
	INIT = 0,
	SHUFFLE_0,		# カードシャフル中（前半）
	SHUFFLE_1,		# カードシャフル中（後半）
	DEALING,		# カード配布中
	OPENING,		# 人間プレイヤーのカードオープン中
	SEL_ACTION,		# アクション選択
	SHOW_DOWN,
	ROUND_FINISHED,
}
enum {
	DEALER = 0,
	SB,
	BB,
}
enum {
	BG_WAIT = 0,
	BG_PLY,			# 手番
	BG_FOLDED,
}
#enum {				# sub_state
#	READY = 0,
#	CARD_MOVING,
#	CARD_OPENING,
#	CHIPS_COLLECTING,		# プレイヤーベットチップを中央に移動中
#	CHIPS_COLLECTED,		# プレイヤーベットチップを中央に移動中終了
#	INITIALIZED,
#	SHUFFLE_0,				# カードシャフル中（前半）
#	SHUFFLE_1,				# カードシャフル中（後半）
#	DEALING,				# カード配布中
#	OPENING,				# 人間プレイヤーのカードオープン中
#}
enum {		# アクションボタン
	FOLD = 0,
	CHECK_CALL,
	RAISE,
	N_ACT_BUTTONS,
}

const INIT_CHIPS = 200
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4			# カード：(suit << N_RANK_BITS) | rank
const CARD_WIDTH = 50
const N_PLAYERS = 2				# プレイヤー人数（2 for ヘッズ・アップ）
const ANTE_CHIPS = 1
const BET_CHIPS = 1				# 1chip のみベット可能
const USER_IX = 0

var state = INIT
#var sub_state = READY
var balance
var n_opening = 0
var n_closing = 0
var n_moving = 0
var TABLE_CENTER
var n_raised = 0		# 現ラウンドでのレイズ回数合計（MAX_N_RAISES 以下）
var nix = -1			# 次の手番
var dealer_ix = 0		# ディーラプレイヤーインデックス
var act_buttons = []		# アクションボタン
var cards = [0, 0, 0]			# 使用カード
var players = []		# プレイヤーパネル配列、[0] for Human
var players_card = []		# プレイヤーに配られたカード
var act_panels = []			# プレイヤーアクション表示パネル
var is_folded = []			# 各プレイヤーが Fold 済みか？
var bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数（パネル下部に表示されるチップ数）
var round_bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数合計

onready var g = get_node("/root/Global")

var CardBF = load("res://CardBF.tscn")		# カード裏表面
var Chip = load("res://Chip.tscn")			# 移動可能チップ
var ActionPanel = load("res://ActionPanel.tscn")

var rng = RandomNumberGenerator.new()

func _ready():
	if true:
		randomize()
		rng.randomize()
	else:
		rng.randomize()
		#var sd = rng.randi_range(0, 9999)
		#print("seed = ", sd)
		var sd = 0		# SPR#111
		#var sd = 1
		#var sd = 7
		#var sd = 3852
		#var sd = 9830		# 引き分けあり
		seed(sd)
		rng.set_seed(sd)
	#
	players_card.resize(N_PLAYERS)
	state = INIT
	TABLE_CENTER = $Table.position
	dealer_ix = rng.randi_range(0, N_PLAYERS - 1)
	print("dealer_ix = ", dealer_ix)
	nix = (dealer_ix + 1) % N_PLAYERS		# 次の手番
	#
	n_closing = cards.size()
	for i in range(cards.size()):
		cards[i] = CardBF.instance()
		cards[i].set_position(TABLE_CENTER + Vector2(CARD_WIDTH*(i-1), 0))
		cards[i].set_sr(HEARTS, RANK_J + i)
		#cards[i].connect("opening_finished", self, "on_opening_finished")
		#cards[i].do_open()
		cards[i].show_front()
		cards[i].connect("closing_finished", self, "on_closing_finished")
		cards[i].do_close()
		add_child(cards[i])
	cards.shuffle()			# カードシャフル
	is_folded.resize(N_PLAYERS)
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		pb.set_hand("")
		pb.set_chips(INIT_CHIPS)
		players.push_back(pb)
		is_folded[i] = false
		if i == nix: pb.set_BG(BG_PLY)
	# 行動ボタン
	act_buttons.resize(N_ACT_BUTTONS)
	act_buttons[FOLD] = $FoldButton
	act_buttons[CHECK_CALL] = $CheckCallButton
	act_buttons[RAISE] = $RaiseButton
	disable_act_buttons()			# 全コマンドボタンディセーブル
	#
	balance = g.saved_data[g.KEY_BALANCE]
	balance -= INIT_CHIPS
	$Table/BalanceLabel.text = "balance: %d" % balance
	players[0].set_name(g.saved_data[g.KEY_USER_NAME])
	#
	update_players_BG()
func disable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
func enable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = false

func update_players_BG():
	bet_chips_plyr.resize(N_PLAYERS)
	round_bet_chips_plyr.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var mk = players[i].get_node("Mark")
		if i == dealer_ix:
			mk.show()
		else:
			mk.hide()
		bet_chips_plyr[i] = ANTE_CHIPS
		round_bet_chips_plyr[i] = ANTE_CHIPS
		players[i].show_bet_chips(true)
		players[i].set_bet_chips(bet_chips_plyr[i])
		players[i].set_chips(players[i].get_chips() - bet_chips_plyr[i])
	
func on_opening_finished():
	if state == OPENING:		# 人間カードオープン
		state = SEL_ACTION		# アクション選択可能状態
	#n_opening -= 1
	#if n_opening == 0:
	#	if state == INIT:
	#		n_closing = cards.size()
	#		for i in range(cards.size()):
	#			cards[i].connect("closing_finished", self, "on_closing_finished")
	#			cards[i].do_close()
	pass
func on_closing_finished():
	n_closing -= 1
	if n_closing == 0:
		n_moving = cards.size()
		for i in range(cards.size()):
			cards[i].connect("moving_finished", self, "on_moving_finished")
			cards[i].move_to(TABLE_CENTER, 0.2)
			#cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)

func on_moving_finished():
	n_moving -= 1
	if n_moving == 0:
		if state == INIT:
			state = SHUFFLE_0			# シャフルアニメーション前半
			n_moving = cards.size()
			for i in range(cards.size()):
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)
		elif state == SHUFFLE_0:
			state = SHUFFLE_1			# シャフルアニメーション後半
			n_moving = cards.size()
			for i in range(cards.size()):
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				cards[i].move_to(TABLE_CENTER, 0.3)
		elif state == SHUFFLE_1:
			state = DEALING				# 2人のプレイヤーにカードを配る
			n_moving = N_PLAYERS
			for i in range(N_PLAYERS):
				players_card[i] = cards[i]
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				var dst = players[i].get_global_position() + Vector2(0, 4)
				cards[i].move_to(dst, 0.3)
		elif state == DEALING:
			state = OPENING				# 人間プレイヤーのカードをオープン
			players_card[USER_IX].connect("opening_finished", self, "on_opening_finished")
			players_card[USER_IX].do_open()
func update_next_player():
	for i in range(N_PLAYERS):
		if is_folded[i]:
			players[i].set_BG(BG_FOLDED)
		else:
			players[i].set_BG(BG_PLY if state != INIT && i == nix else BG_WAIT)
	#if nix < act_panels.size():
	#	act_panels[nix].hide()
func _process(delta):
	if state == SHOW_DOWN || state == ROUND_FINISHED:
		return
	if state == SEL_ACTION && nix != USER_IX:		# AI の手番
		print("AI is thinking...")
		# undone: AI アクション
		nix = USER_IX			# 人間の手番に
		update_next_player()
		enable_act_buttons()	# 行動ボタンイネーブル
func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.
