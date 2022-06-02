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
	DEALING,		# カード配布中
	OPENING,		# 人間プレイヤーのカードオープン中
	DEALING_COMU,	# 共有カード配布中
	OPENING_COMU,	# 共有カードオープン中
	SEL_ACTION,		# アクション選択
	WAITING,		# アクション選択後のウェイト状態
	SHOW_DOWN,
	#ROUND_FINISHED,
}
enum {				# プレイヤーパネル背景色
	BG_WAIT = 0,
	BG_PLY,			# 手番
	BG_FOLDED,
}
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
const COMU_CARD_PY = 80
const N_PLAYERS = 3				# プレイヤー人数
const ANTE_CHIPS = 1
const BET_CHIPS = 1				# 1chip のみベット可能
const HUMAN_IX = 0
const AI_IX = 1
const AI_IX2 = 2

var state = INIT
var waiting = 0.0		# 0超ならウェイト状態 → 次のプレイヤーに手番を移動
var sec_to_trans = 0	# 次のハンドの自動遷移するまでの秒数（整数）
#var sub_state = READY
var balance
var n_hands = 1			# 何ハンド目か
var sum_rank = 0.0		# ランク合計
var pot = 0				# ベット額合計
var n_act_players = N_PLAYERS	# フォールドしていないプレイヤー数
var n_opening = 0
var n_closing = 0
var n_moving = 0
var n_chip_moving = 0	# 移動中チップ数
var TABLE_CENTER
var n_actions = 0		# プレイヤー行動数
var n_raised = 0		# 現ラウンドでのレイズ回数合計（MAX_N_RAISES 以下）
var nix = -1			# 次の手番
var dealer_ix = 0		# ディーラプレイヤーインデックス
var winner_ix			# 勝者インデックス
var loser1_ix			# 敗者インデックス
var loser2_ix			# 敗者インデックス
#var alpha = 0.0			# Ｊレイズ確率
var act_buttons = []		# アクションボタン
#var cards = [0, 0, 0, 0, 0]		# 使用カード
var deck_ix = 0			# デッキトップインデックス
var deck = []			# 要素：(suit << 4) | rank （※ rank:0～12 の数値、0 for 2,... 11 for King, 12 for Ace）
var comu_cards = []		# コミュニティカード
var players = []			# プレイヤーパネル配列、[0] for Human
var players_card1 = []		# プレイヤーに配られたカード その１
var players_card2 = []		# プレイヤーに配られたカード その２
#var players_card = []		# プレイヤーに配var act_panels = []			# プレイヤーアクション表示パネル
var is_folded = []			# 各プレイヤーが Fold 済みか？
var players_hand = []		# 各プレイヤーの手役
var bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数（パネル下部に表示されるチップ数）
#var round_bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数合計
var act_history = ""		# 行動履歴、F for Fold, c for Check, C for Call, R for Raise
var deck_pos

var strategy = {
	# for 3P RiverOnly
	"A": 0.971014, "AR": 0.0078125, "ARC": 0.00819672, "ARF": 0, "Ac": 0.0873016, "AcR": 0,
	"AcRC": 0, "AcRF": 0, "Acc": 0, "AccR": 0, "AccRC": 0.025641, "AccRF": 0,
	"K": 0.379691, "KR": 0, "KRC": 0.0903955, "KRF": 0, "Kc": 0.474006, "KcR": 0,
	"KcRC": 0, "KcRF": 0.00606061, "Kcc": 0, "KccR": 0.010989, "KccRC": 0, "KccRF": 0.00925926,
	"Q": 0.849412, "QR": 0.352577, "QRC": 1, "QRF": 0.0592885, "Qc": 0.330869, "QcR": 0.022293,
	"QcRC": 0.971014, "QcRF": 0, "Qcc": 0.251121, "QccR": 0.0144092, "QccRC": 0.886364, "QccRF": 0.0454545,
	"J": 0.965726, "JR": 0.937209, "JRC": 1, "JRF": 0.144981, "Jc": 1, "JcR": 0.991935,
	"JcRC": 1, "JcRF": 0.256293, "Jcc": 1, "JccR": 0.375912, "JccRC": 1, "JccRF": 0.0116959,
	"T": 0.978845, "TR": 1, "TRC": 1, "TRF": 1, "Tc": 0.822243, "TcR": 1,
	"TcRC": 1, "TcRF": 1, "Tcc": 0.678679, "TccR": 0.992424, "TccRC": 1, "TccRF": 0.994318,
	# for 3P KuhnPoker
	#"A": 0.178082, "AR": 0, "ARC": 0, "ARF": 0, "Ac": 0.0045977, "AcR": 0, "AcRC": 0,
	#"AcRF": 0, "Acc": 0, "AccR": 0, "AccRC": 0, "AccRF": 0,
	#"K": 0.995745, "KR": 0.939471, "KRC": 1, "KRF": 0.0462529, "Kc": 1, "KcR": 0.00467017,
	#"KcRC": 0.942664, "KcRF": 0.399351, "Kcc": 0.530449, "KccR": 0.00251731, "KccRC": 0.566038, "KccRF": 0.00382409,
	#"Q": 0.952055, "QR": 0.992405, "QRC": 1, "QRF": 0.572205, "Qc": 1, "QcR": 0.659091,
	#"QcRC": 1, "QcRF": 0.99226, "Qcc": 1, "QccR": 0.994743, "QccRC": 1, "QccRF": 0.803985,
	#"J": 0.795006, "JR": 1, "JRC": 1, "JRF": 1, "Jc": 0.649451, "JcR": 1,
	#"JcRC": 1, "JcRF": 1, "Jcc": 0.442053, "JccR": 1, "JccRC": 1, "JccRF": 1,
	#"T": 0.897172, "TR": 1, "TRC": 1, "TRF": 1, "Tc": 0.856365, "TcR": 1,
	#"TcRC": 1, "TcRF": 1, "Tcc": 0.995054, "TccR": 1, "TccRC": 1, "TccRF": 1,	
}

onready var g = get_node("/root/Global")

var CardBF = load("res://CardBF.tscn")		# カード裏表面
var Chip = load("res://Chip.tscn")			# 移動可能チップ
var ActionPanel = load("res://ActionPanel.tscn")

var rng = RandomNumberGenerator.new()


func _ready():
	if false:
		randomize()
		rng.randomize()
	else:
		rng.randomize()
		#var sd = rng.randi_range(0, 9999)
		var sd = OS.get_unix_time()
		#var sd = 0
		#var sd = 3852
		#var sd = 9830		# 引き分けあり
		#var sd = 1653725009
		#var sd = 1653878624		# フォールドすると変？
		
		print("seed = ", sd)
		seed(sd)
		rng.set_seed(sd)
	deck_pos = $Table/CardDeck.get_position()
	players_hand.resize(N_PLAYERS)
	is_folded.resize(N_PLAYERS)
	comu_cards.resize(N_COMU_CARS)
	#n_raised.resize(N_PLAYERS)
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		#pb.get_node("ResultLabel").z_index = 2
		pb.set_hand("")
		pb.set_chips(INIT_CHIPS)
		players.push_back(pb)
		is_folded[i] = false
	balance = g.saved_data[g.KEY_BALANCE]
	balance -= INIT_CHIPS
	$Table/BalanceLabel.text = "balance: %d" % balance
	#
	players[0].set_name(g.saved_data[g.KEY_USER_NAME])
	#players[0].set_BG(1)
	dealer_ix = rng.randi_range(0, N_PLAYERS - 1)
	print("dealer_ix = ", dealer_ix)
	# 行動ボタン
	act_buttons.resize(N_ACT_BUTTONS)
	act_buttons[FOLD] = $FoldButton
	act_buttons[CHECK_CALL] = $CheckCallButton
	#act_buttons[CALL] = $CallButton
	act_buttons[RAISE] = $RaiseButton
	#act_buttons[ALL_IN] = $AllInNextButton
	#act_buttons[BB2] = $BB2Button
	#act_buttons[BB3] = $BB3Button
	#act_buttons[BB4] = $BB4Button
	#act_buttons[BB5] = $BB5Button
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
	#$RaiseSpinBox.set_value(BB_CHIPS)
	#$RaiseSpinBox.editable = false
	update_players_BG()
	update_act_buttons()
	#
	#deal_cards()
	dealing_cards_animation()
	pass
func card_to_suit(cd): return cd >> N_RANK_BITS
func card_to_rank(cd): return cd & RANK_MASK
func shuffle_cards():	# デッキ初期化、カードシャフル
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st : int = i / N_RANK
		var rank : int = i % N_RANK
		deck[i] = (st<<N_RANK_BITS) | rank
	deck.shuffle()
	deck_ix = 0

func deal_cards():	# 各プレイヤーにカード配布
	shuffle_cards()
	players_card1 = []
	var ix = 0
	for i in range(N_PLAYERS):
		players_card1.push_back(deck[ix])
		var st : int = card_to_suit(deck[ix])
		var rank : int = card_to_rank(deck[ix])
		ix += 1
		players[i].set_card1(st, rank)
	players_card2 = []
	for i in range(N_PLAYERS):
		players_card2.push_back(deck[ix])
		var st : int = card_to_suit(deck[ix])
		var rank : int = card_to_rank(deck[ix])
		ix += 1
		players[i].set_card2(st, rank)
func dealing_cards_animation():		# 各プレイヤーにカード配布アニメーション
	shuffle_cards()
	players_card1.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var di = (dealer_ix + 1 + i) % N_PLAYERS
		var cd = CardBF.instance()		# カード裏面
		players_card1[di] = cd
		cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
		deck_ix += 1
		cd.set_position(deck_pos)
		$Table.add_child(cd)
		cd.connect("moving_finished", self, "on_moving_finished")
		cd.connect("opening_finished", self, "on_opening_finished")
		var dst = players[di].get_position() + Vector2(-CARD_WIDTH/2, -4)
		cd.wait_move_to(i * 0.1, dst, 0.3)
	players_card2.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var di = (dealer_ix + 1 + i) % N_PLAYERS
		var cd = CardBF.instance()
		players_card2[di] = cd
		cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
		deck_ix += 1
		cd.set_position(deck_pos)
		$Table.add_child(cd)
		cd.connect("moving_finished", self, "on_moving_finished")
		cd.connect("opening_finished", self, "on_opening_finished")
		var dst = players[di].get_position() + Vector2(CARD_WIDTH/2, -4)
		cd.wait_move_to((N_PLAYERS + i) * 0.1, dst, 0.3)
	state = DEALING
	n_moving = N_PLAYERS * 2
func on_moving_finished():
	n_moving -= 1
	if n_moving == 0:
		#print("on_moving_finished")
		if state == DEALING:			# プレイヤーカード配布終了
			players_card1[HUMAN_IX].do_open()
			players_card2[HUMAN_IX].do_open()
			state = OPENING
			n_opening = 2
		elif state == DEALING_COMU:		# 共有カード配布終了
			n_opening = comu_cards.size()
			for i in range(n_opening):
				comu_cards[i].do_open()
			state = OPENING_COMU
			pass
func on_opening_finished():
	n_opening -= 1
	if n_opening == 0:
		if state == OPENING:		# 人間カードオープン終了
			n_moving = N_COMU_CARS
			state = DEALING_COMU
			for i in range(n_moving):
				var cd = CardBF.instance()
				comu_cards[i] = cd
				cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
				deck_ix += 1
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				cd.connect("moving_finished", self, "on_moving_finished")
				cd.connect("opening_finished", self, "on_opening_finished")
				cd.move_to(Vector2(CARD_WIDTH*(i-2), COMU_CARD_PY), 0.3)
	
func disable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
func enable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = false
func can_check():
	return n_raised == 0
func update_act_buttons():
	if nix != HUMAN_IX:
		disable_act_buttons()
	else:
		$FoldButton.disabled = false
		$CheckCallButton.disabled = false
		print("can_check() = ", can_check())
		if can_check():
			$CheckCallButton.text = "Check"
		else:
			$CheckCallButton.text = "Call 1"
		$RaiseButton.disabled = n_raised != 0
		$NextButton.disabled = true
func update_players_BG():
	bet_chips_plyr.resize(N_PLAYERS)
	#round_bet_chips_plyr.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		players[i].copy_to_prev_chips()
		players[i].show_diff_chips(false)
		var mk = players[i].get_node("Mark")
		if i == dealer_ix:
			mk.show()
		else:
			mk.hide()
		bet_chips_plyr[i] = ANTE_CHIPS
		#round_bet_chips_plyr[i] = ANTE_CHIPS
		players[i].show_bet_chips(true)
		players[i].set_bet_chips(bet_chips_plyr[i])
		players[i].sub_chips(bet_chips_plyr[i])




func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.
