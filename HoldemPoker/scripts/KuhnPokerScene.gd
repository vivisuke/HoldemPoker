extends Node2D

enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
const RANK_STR = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
enum {		# 手役
	HIGH_CARD = 0,
	ONE_PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH,
	N_KIND_HAND,
};
enum {		# 状態
	INIT = 0,
	DEAL,
	BET,
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
enum {				# sub_state
	READY = 0,
	CARD_MOVING,
	CARD_OPENING,
	CHIPS_COLLECTING,		# プレイヤーベットチップを中央に移動中
	CHIPS_COLLECTED,		# プレイヤーベットチップを中央に移動中終了
	INITIALIZED,
	SHUFFLE_0,				# カードシャフル中（前半）
	SHUFFLE_1,				# カードシャフル中（後半）
}
enum {		# アクションボタン
	CHECK_CALL = 0,
	#CALL,
	FOLD,
	RAISE,
	ALL_IN,
	BB2,
	BB3,
	BB4,
	BB5,
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

var state = INIT
var sub_state = READY
var balance
var n_opening = 0
var n_closing = 0
var n_moving = 0
var TABLE_CENTER
var n_raised = 0		# 現ラウンドでのレイズ回数合計（MAX_N_RAISES 以下）
var nix = -1			# 次の手番
var dealer_ix = 0		# ディーラプレイヤーインデックス
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
	is_folded.resize(N_PLAYERS)
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		pb.set_hand("")
		pb.set_chips(INIT_CHIPS)
		players.push_back(pb)
		is_folded[i] = false
		if i == nix: pb.set_BG(BG_PLY)
	#
	balance = g.saved_data[g.KEY_BALANCE]
	balance -= INIT_CHIPS
	$Table/BalanceLabel.text = "balance: %d" % balance
	players[0].set_name(g.saved_data[g.KEY_USER_NAME])
	#
	update_players_BG()

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
	n_opening -= 1
	#if n_opening == 0:
	#	if state == INIT:
	#		n_closing = cards.size()
	#		for i in range(cards.size()):
	#			cards[i].connect("closing_finished", self, "on_closing_finished")
	#			cards[i].do_close()
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
			if sub_state == READY:
				sub_state = SHUFFLE_0
				n_moving = cards.size()
				for i in range(cards.size()):
					#cards[i].connect("moving_finished", self, "on_moving_finished")
					cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)
			elif sub_state == SHUFFLE_0:
				sub_state = SHUFFLE_1
				n_moving = cards.size()
				for i in range(cards.size()):
					#cards[i].connect("moving_finished", self, "on_moving_finished")
					cards[i].move_to(TABLE_CENTER, 0.3)
func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.
