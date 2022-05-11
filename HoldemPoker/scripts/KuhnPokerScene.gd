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
const AI_IX = 1

var state = INIT
var waiting = 0.0		# 0超ならウェイト状態 → 次のプレイヤーに手番を移動
#var sub_state = READY
var balance
var n_opening = 0
var n_closing = 0
var n_moving = 0
var TABLE_CENTER
var n_actions = 0		# プレイヤー行動数
var n_raised = 0		# 現ラウンドでのレイズ回数合計（MAX_N_RAISES 以下）
var nix = -1			# 次の手番
var dealer_ix = 0		# ディーラプレイヤーインデックス
var winner_ix			# 勝者インデックス
var loser_ix			# 敗者インデックス
var alpha = 0.0			# Ｊレイズ確率
var act_buttons = []		# アクションボタン
var cards = [0, 0, 0]		# 使用カード
var players = []			# プレイヤーパネル配列、[0] for Human
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
	if false:
		randomize()
		rng.randomize()
	else:
		rng.randomize()
		#var sd = rng.randi_range(0, 9999)
		var sd = OS.get_unix_time()
		print("seed = ", sd)
		#var sd = 0
		#var sd = 2
		#var sd = 7
		#var sd = 3852
		#var sd = 9830		# 引き分けあり
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
		cards[i].set_position(TABLE_CENTER + Vector2(CARD_WIDTH*(i-1), 0))
		cards[i].set_sr(HEARTS, RANK_J + i)
		#cards[i].connect("opening_finished", self, "on_opening_finished")
		#cards[i].do_open()
		cards[i].show_front()
		cards[i].connect("closing_finished", self, "on_closing_finished")
		cards[i].do_close()
		add_child(cards[i])
	cards.shuffle()			# カードシャフル
	#for i in range(cards.size()):
	#	print("rank = ", RANK_STR[cards[i].get_rank()])
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

#func emphasize_next_player():		# 次の手番のプレイヤー背景上部を黄色強調
#	for i in range(N_PLAYERS):
#		players[i].set_BG(
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
		#players[i].set_chips(players[i].get_chips() - bet_chips_plyr[i])
		players[i].sub_chips(bet_chips_plyr[i])
	
func on_opening_finished():
	if state == OPENING:		# 人間カードオープン
		state = SEL_ACTION		# アクション選択可能状態
		emphasize_next_player()
		if nix == USER_IX:
			enable_act_buttons()
	elif state == SHOW_DOWN:
		print("SHOW_DOWN > on_opening_finished()")
		#emphasize_next_player()
		if players_card[USER_IX].get_rank() > players_card[AI_IX].get_rank():
			print("User won")
			winner_ix = USER_IX		# 勝者
			loser_ix = AI_IX
		else:
			print("AI won")
			winner_ix = AI_IX
			loser_ix = USER_IX		# 敗者
		settle_chips()
		pass
	#n_opening -= 1
	#if n_opening == 0:
	#	if state == INIT:
	#		n_closing = cards.size()
	#		for i in range(cards.size()):
	#			cards[i].connect("closing_finished", self, "on_closing_finished")
	#			cards[i].do_close()
	pass
func settle_chips():
	players[loser_ix].show_bet_chips(false)
	var ch = Chip.instance()
	ch.position = players[loser_ix].get_chip_pos()
	add_child(ch)
	#n_moving = 1
	ch.connect("moving_finished", self, "on_chip_moving_finished")
	ch.move_to(players[winner_ix].get_chip_pos(), 0.5)
func on_closing_finished():
	n_closing -= 1
	if n_closing == 0:
		n_moving = cards.size()
		for i in range(cards.size()):
			cards[i].connect("moving_finished", self, "on_moving_finished")
			cards[i].move_to(TABLE_CENTER, 0.2)
			#cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)

func on_chip_moving_finished():
	if state == SHOW_DOWN:
		var ch = bet_chips_plyr[winner_ix] + bet_chips_plyr[loser_ix]
		players[winner_ix].add_chips(ch)
		players[winner_ix].show_bet_chips(false)
		pass
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
				#var rnk = players_card[i].get_rank()		# 
				#print(i, " rank = ", RANK_STR[rnk])
				#cards[i].connect("moving_finished", self, "on_moving_finished")
				var dst = players[i].get_global_position() + Vector2(0, 4)
				cards[i].move_to(dst, 0.3)
		elif state == DEALING:
			state = OPENING				# 人間プレイヤーのカードをオープン
			players_card[USER_IX].connect("opening_finished", self, "on_opening_finished")
			players_card[USER_IX].do_open()
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
	if state == SEL_ACTION && nix != USER_IX:		# AI の手番
		print("AI is thinking...")
		do_act_AI()
		#
func do_act_AI():
	var rnk = players_card[AI_IX].get_rank()		# 
	print("rank = ", RANK_STR[rnk])
	var rd = rng.randf_range(0.0, 1.0)		# [0.0, 1.0] 乱数
	var can_check = bet_chips_plyr[USER_IX] == bet_chips_plyr[AI_IX]
	var can_raise = n_raised == 0
	print("can_check = ", can_check, ", can_raise = ", can_raise)
	if n_actions == 0:		# 初手
		if( rnk == RANK_J && rd <= alpha ||
			rnk == RANK_K && rd <= alpha*3 ):
				do_raise(AI_IX)
		else:
			do_check_call(AI_IX)
	if n_actions == 1:		# ２手目
		if rnk == RANK_K:
			if can_raise:
				do_raise(AI_IX)
			else:
				do_check_call(AI_IX)
		elif rnk == RANK_Q:
			if can_check || rd <= 1.0/3.0:
				do_check_call(AI_IX)
			else:
				do_fold(AI_IX)
		else:	# Ｊの場合
			if can_raise && rd <= 1.0/3.0:
				do_raise(AI_IX)
			else:
				do_fold(AI_IX)
	else:	# ３手目
		if rd <= alpha + 1.0/3.0:
			do_check_call(AI_IX)
		else:
			do_fold(AI_IX)
func do_check_call(pix):
	if bet_chips_plyr[AI_IX] == bet_chips_plyr[USER_IX]:
		set_act_panel_text(pix, "checked")
	else:
		players[pix].sub_chips(BET_CHIPS)
		bet_chips_plyr[pix] += BET_CHIPS
		players[pix].set_bet_chips(bet_chips_plyr[pix])
	do_wait()
	#next_player()
func do_raise(pix):
	n_raised += 1
	players[pix].sub_chips(BET_CHIPS)
	bet_chips_plyr[pix] += BET_CHIPS
	players[pix].set_bet_chips(bet_chips_plyr[pix])
	set_act_panel_text(pix, "raised")
	do_wait()
func do_fold(pix):
	is_folded[pix] = true		# 必要？
	state = SHOW_DOWN
	loser_ix = pix
	winner_ix = (USER_IX + AI_IX) - pix
	settle_chips()
func next_player():
	n_actions += 1
	if n_actions >= 2 && bet_chips_plyr[AI_IX] == bet_chips_plyr[USER_IX]:
		state = SHOW_DOWN
		emphasize_next_player()		# 次の手番非強調
		disable_act_buttons()		# 行動ボタンディセーブル
		for i in range(N_PLAYERS): act_panels[i].hide()		# アクションパネル非表示
		players_card[AI_IX].connect("opening_finished", self, "on_opening_finished")
		players_card[AI_IX].do_open()
		#do_show_down()
	else:
		nix = (nix + 1) % N_PLAYERS
		emphasize_next_player()
		if nix == USER_IX:
			enable_act_buttons()	# 行動ボタンイネーブル
#func do_show_down():
#	pass
func set_act_panel_text(i, txt):
	act_panels[i].set_text(txt)
	act_panels[i].show()
func next_hand():
	pass
func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.
func _on_FoldButton_pressed():
	do_fold(USER_IX)
func _on_CheckCallButton_pressed():
	do_check_call(USER_IX)
func _on_RaiseButton_pressed():
	do_raise(USER_IX)
func _on_NextButton_pressed():
	if state == SHOW_DOWN:
		next_hand()
	pass # Replace with function body.
