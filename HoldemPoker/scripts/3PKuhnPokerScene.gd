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
	WAITING,		# アクション選択後のウェイト状態
	SHOW_DOWN,
	ROUND_FINISHED,
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
const N_PLAYERS = 3				# プレイヤー人数
const ANTE_CHIPS = 1
const BET_CHIPS = 1				# 1chip のみベット可能
const HUMAN_IX = 0
const AI_IX = 1
const AI_IX2 = 2

var state = INIT
var waiting = 0.0		# 0超ならウェイト状態 → 次のプレイヤーに手番を移動
#var sub_state = READY
var balance
var n_hands = 1			# 何ハンド目か
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
var alpha = 0.0			# Ｊレイズ確率
var act_buttons = []		# アクションボタン
var cards = [0, 0, 0, 0, 0]		# 使用カード
var players = []			# プレイヤーパネル配列、[0] for Human
var players_card = []		# プレイヤーに配られたカード
var act_panels = []			# プレイヤーアクション表示パネル
var is_folded = []			# 各プレイヤーが Fold 済みか？
var bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数（パネル下部に表示されるチップ数）
#var round_bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数合計
var act_history = ""		# 行動履歴、F for Fold, c for Check, C for Call, R for Raise

var strategy = {
	"A": 0.178082, "AR": 0, "ARC": 0, "ARF": 0, "Ac": 0.0045977, "AcR": 0, "AcRC": 0,
	"AcRF": 0, "Acc": 0, "AccR": 0, "AccRC": 0, "AccRF": 0,
	"K": 0.995745, "KR": 0.939471, "KRC": 1, "KRF": 0.0462529, "Kc": 1, "KcR": 0.00467017,
	"KcRC": 0.942664, "KcRF": 0.399351, "Kcc": 0.530449, "KccR": 0.00251731, "KccRC": 0.566038, "KccRF": 0.00382409,
	"Q": 0.952055, "QR": 0.992405, "QRC": 1, "QRF": 0.572205, "Qc": 1, "QcR": 0.659091,
	"QcRC": 1, "QcRF": 0.99226, "Qcc": 1, "QccR": 0.994743, "QccRC": 1, "QccRF": 0.803985,
	"J": 0.795006, "JR": 1, "JRC": 1, "JRF": 1, "Jc": 0.649451, "JcR": 1,
	"JcRC": 1, "JcRF": 1, "Jcc": 0.442053, "JccR": 1, "JccRC": 1, "JccRF": 1,
	"T": 0.897172, "TR": 1, "TRC": 1, "TRF": 1, "Tc": 0.856365, "TcR": 1,
	"TcRC": 1, "TcRF": 1, "Tcc": 0.995054, "TccR": 1, "TccRC": 1, "TccRF": 1,	
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
		print("seed = ", sd)
		seed(sd)
		rng.set_seed(sd)
	#
	alpha = rng.randf_range(0.1, 0.3)
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
		#cards[i].set_position(Vector2(CARD_WIDTH*(i-1), 0) - TABLE_CENTER)
		cards[i].set_position(TABLE_CENTER + Vector2(CARD_WIDTH*(i-2), 0))
		cards[i].set_sr(HEARTS, RANK_10 + i)
		#cards[i].connect("opening_finished", self, "on_opening_finished")
		#cards[i].do_open()
		cards[i].show_front()
		cards[i].connect("closing_finished", self, "on_closing_finished")
		cards[i].do_wait_close(1.0)
		add_child(cards[i])
	is_folded.resize(N_PLAYERS)
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		pb.set_hand("")
		pb.set_chips(INIT_CHIPS)
		players.push_back(pb)
		is_folded[i] = false
		#if i == nix: pb.set_BG(BG_PLY)
	# 行動パネル
	act_panels.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var ap = ActionPanel.instance()
		act_panels[i] = ap
		ap.hide()
		ap.set_position(TABLE_CENTER + players[i].position - ap.rect_size/2)
		add_child(ap)
		#$Table.add_child(ap)
	# 行動ボタン
	act_buttons.resize(N_ACT_BUTTONS)
	act_buttons[FOLD] = $FoldButton
	act_buttons[CHECK_CALL] = $CheckCallButton
	act_buttons[RAISE] = $RaiseButton
	disable_act_buttons()			# 全コマンドボタンディセーブル
	$NextButton.disabled = true
	#
	balance = g.saved_data[g.KEY_BALANCE]
	balance -= INIT_CHIPS
	$Table/BalanceLabel.text = "balance: %d" % balance
	players[0].set_name(g.saved_data[g.KEY_USER_NAME])
	#
	update_players_BG()
	update_act_buttons()
	pass # Replace with function body.

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
#func emphasize_next_player():		# 次の手番のプレイヤー背景上部を黄色強調
#	for i in range(N_PLAYERS):
#		players[i].set_BG(
func update_n_raised_label():
	$NRaisedLabel.text = "# raised: %d/1" % n_raised
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
	
func determine_who_won():
	var mxc = 0
	#var mxi
	for i in range(N_PLAYERS):
		if !is_folded[i] && players_card[i].get_rank() > mxc:
			mxc = players_card[i].get_rank()
			winner_ix = i
	#loser1_ix = (winner_ix + 1) % N_PLAYERS
	#loser2_ix = (winner_ix + 2) % N_PLAYERS
func on_opening_finished():
	if state == OPENING:		# 人間カードオープン
		state = SEL_ACTION		# アクション選択可能状態
		emphasize_next_player()
		if nix == HUMAN_IX:
			enable_act_buttons()
	elif state == SHOW_DOWN:
		print("SHOW_DOWN > on_opening_finished()")
		#emphasize_next_player()
		determine_who_won()
		#if players_card[HUMAN_IX].get_rank() > players_card[AI_IX].get_rank():
		#	print("User won")
		#	winner_ix = HUMAN_IX		# 勝者
		#	loser_ix = AI_IX
		#else:
		#	print("AI won")
		#	winner_ix = AI_IX
		#	loser_ix = HUMAN_IX		# 敗者
		settle_chips()
		pass
func settle_chips():
	#n_chip_moving = 0
	if n_chip_moving != 0: return		# 複数回呼ばれてしまった場合は無視
	for i in range(N_PLAYERS):
		if i != winner_ix:
			players[i].show_bet_chips(false)
			var ch = Chip.instance()
			ch.position = players[i].get_chip_pos()
			add_child(ch)
			ch.connect("moving_finished", self, "on_chip_moving_finished")
			ch.move_to(players[winner_ix].get_chip_pos(), 0.5)
			n_chip_moving += 1
	#n_chip_moving = N_PLAYERS - 1
	print("n_chip_moving = ", n_chip_moving)
func on_chip_moving_finished():
	print("on_chip_moving_finished(): ", n_chip_moving)
	n_chip_moving -= 1
	if n_chip_moving == 0 && state == SHOW_DOWN:
		for i in range(N_PLAYERS):
			players[winner_ix].add_chips(bet_chips_plyr[i])
			players[i].show_diff_chips(true)		# チップ増減表示
		players[winner_ix].show_bet_chips(false)
		players[winner_ix].show_diff_chips(true)	# チップ増減表示
		disable_act_buttons()
		$NextButton.disabled = false
		pass
func collect_cards_to_the_deck():
	n_moving = cards.size()
	for i in range(cards.size()):
		cards[i].connect("moving_finished", self, "on_moving_finished")
		cards[i].move_to(TABLE_CENTER, 0.2)
		#cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)
func on_closing_finished():
	n_closing -= 1
	if n_closing == 0:
		collect_cards_to_the_deck()		# カードを中央デッキに集める

func on_moving_finished():
	print("on_moving_finished(): ", n_moving)
	n_moving -= 1
	if n_moving == 0:
		if state == INIT:
			state = SHUFFLE_0			# シャフルアニメーション前半
			n_moving = cards.size()
			for i in range(cards.size()):
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-2), 0), 0.3)
		elif state == SHUFFLE_0:
			state = SHUFFLE_1			# シャフルアニメーション後半
			n_moving = cards.size()
			for i in range(cards.size()):
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				cards[i].move_to(TABLE_CENTER, 0.3)
		elif state == SHUFFLE_1:
			state = DEALING				# 2人のプレイヤーにカードを配る
			cards.shuffle()
			n_moving = N_PLAYERS
			for i in range(N_PLAYERS):
				players_card[i] = cards[i]
				#var rnk = players_card[i].get_rank()		# 
				#print(i, " rank = ", RANK_STR[rnk])
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				var dst = players[i].get_global_position() + Vector2(0, 4)
				cards[i].move_to(dst, 0.3)
		elif state == DEALING:
			state = OPENING				# 人間プレイヤーのカードをオープン
			players_card[HUMAN_IX].connect("opening_finished", self, "on_opening_finished")
			players_card[HUMAN_IX].do_open()
func emphasize_next_player():		# 次の手番のプレイヤー背景上部を黄色強調
	for i in range(N_PLAYERS):
		if is_folded[i]:
			players[i].set_BG(BG_FOLDED)
		else:
			players[i].set_BG(BG_PLY if state == SEL_ACTION && i == nix else BG_WAIT)
	#if nix < act_panels.size():
	#	act_panels[nix].hide()
func do_wait():
	waiting = 0.5		# 0.5秒ウェイト
func _process(delta):
	if state == SHOW_DOWN || state == ROUND_FINISHED:
		return
	if waiting > 0.0:		# 行動後のウェイト状態の場合
		waiting -= delta
		if waiting <= 0.0:	# ウェイト終了
			next_player()	# 次のプレイヤーに手番を移動
		return
	if state == SEL_ACTION && nix != HUMAN_IX:		# AI の手番
		print("AI is thinking...")
		do_act_AI()
		#
func do_act_AI():
	print("act_history = ", act_history)
	var hist = act_history
	if n_raised == 0:
		hist = hist.replace("f", "c")
		print("act_history = ", act_history)
	var rnk = players_card[nix].get_rank()		# 
	print("rank = ", RANK_STR[rnk])
	var key = RANK_STR[rnk] + hist
	var th = 0.5		# 閾値
	if strategy.has(key):
		th = strategy[key]
	var rd = rng.randf_range(0.0, 1.0)		# [0.0, 1.0] 乱数
	if rd < th:		# 乱数が th 未満なら弱気の行動を選択
		if n_raised == 0:
			do_check(nix)
		else:
			do_fold(nix)
	else:	# 強気の行動を選択
		if n_raised == 0:
			do_raise(nix)
		else:
			do_call(nix)
func do_check_call(pix):
	#if bet_chips_plyr[AI_IX] == bet_chips_plyr[HUMAN_IX]:
	if n_raised == 0:
		do_check(pix)
	else:
		do_call(pix)
	do_wait()
	#next_player()
func do_check(pix):
	act_history += "c"
	set_act_panel_text(pix, "checked", Color.lightgray)
	do_wait()
func do_call(pix):
	act_history += "C"
	set_act_panel_text(pix, "called", Color.lightgray)
	players[pix].sub_chips(BET_CHIPS)
	bet_chips_plyr[pix] += BET_CHIPS
	players[pix].set_bet_chips(bet_chips_plyr[pix])
	do_wait()
func do_raise(pix):
	act_history += "R"
	n_raised += 1
	update_n_raised_label()
	players[pix].sub_chips(BET_CHIPS)
	bet_chips_plyr[pix] += BET_CHIPS
	players[pix].set_bet_chips(bet_chips_plyr[pix])
	set_act_panel_text(pix, "raised", Color.pink)
	do_wait()
func do_fold(pix):
	act_history += "F"
	is_folded[pix] = true
	n_act_players -= 1
	set_act_panel_text(pix, "folded", Color.darkgray)
	next_player()
	if pix == HUMAN_IX:
		players_card[pix].show_back()
	players_card[pix].move_to(TABLE_CENTER, 0.2)		# カードを中央に移動
	#state = SHOW_DOWN
	#loser_ix = pix
	#winner_ix = (HUMAN_IX + AI_IX) - pix
	#settle_chips()
func next_player():
	n_actions += 1
	nix = (nix + 1) % N_PLAYERS
	if( n_act_players == 1 ||		# 一人以外全員降りた場合
			bet_chips_plyr[nix] == ANTE_CHIPS + BET_CHIPS ||
			act_history == "ccc" || act_history == "fcc" || act_history == "cfc" || act_history == "ccf" ):
		#n_actions >= 2 && bet_chips_plyr[AI_IX] == bet_chips_plyr[HUMAN_IX]:
		state = SHOW_DOWN
		emphasize_next_player()		# 次の手番非強調
		disable_act_buttons()		# 行動ボタンディセーブル
		#if !is_folded[HUMAN_IX]:		# 人間が残っている場合
		determine_who_won();
		#settle_chips()
		#else:						# AI が残っている場合
		n_opening = 0;
		for i in range(N_PLAYERS):
			act_panels[i].hide()		# アクションパネル非表示
			if i != HUMAN_IX && !is_folded[i] && n_act_players > 1:
				n_opening += 1
				players_card[i].connect("opening_finished", self, "on_opening_finished")
				players_card[i].do_open()
		#do_show_down()
		if n_opening == 0:		# 外AIがフォールドしている場合
			settle_chips()
	else:
		while true:
			if !is_folded[nix]: break
			nix = (nix + 1) % N_PLAYERS
		emphasize_next_player()
		if nix == HUMAN_IX:
			act_panels[HUMAN_IX].hide()
			update_act_buttons()
			#enable_act_buttons()	# 行動ボタンイネーブル
#func do_show_down():
#	pass
func set_act_panel_text(i, txt, col):
	act_panels[i].set_text(txt)
	act_panels[i].color = col
	act_panels[i].show()
func next_hand():
	state = INIT
	n_hands += 1
	$NHandsLabel.text = "# hands: " + String(n_hands)
	dealer_ix = (dealer_ix + 1) % N_PLAYERS
	nix = (dealer_ix + 1) % N_PLAYERS
	act_history = ""
	n_actions = 0
	n_raised = 0
	pot = 0
	#cards.shuffle()
	update_n_raised_label()
	update_players_BG()
	n_closing = 0
	if n_act_players > 1 || !is_folded[HUMAN_IX]:
		for i in range(N_PLAYERS):
			if !is_folded[i]:
				players_card[i].connect("closing_finished", self, "on_closing_finished")
				players_card[i].do_close()
				n_closing += 1
	else:
		collect_cards_to_the_deck()
	n_act_players = N_PLAYERS
	#if !is_folded[AI_IX] && !is_folded[HUMAN_IX]:
	#	n_closing = 2
	#	players_card[AI_IX].connect("closing_finished", self, "on_closing_finished")
	#	players_card[AI_IX].do_close()
	for i in range(N_PLAYERS):
		act_panels[i].hide()
		is_folded[i] = false
	$NextButton.disabled = true
	$CheckCallButton.text = "Check"
	pass

func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.


func _on_FoldButton_pressed():
	do_fold(HUMAN_IX)
func _on_CheckCallButton_pressed():
	do_check_call(HUMAN_IX)
func _on_RaiseButton_pressed():
	do_raise(HUMAN_IX)
func _on_NextButton_pressed():
	if state == SHOW_DOWN:
		next_hand()
