extends Node2D

enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
const RANK_STR = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
enum {
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
	PRE_FLOP,
	FLOP,
	TURN,
	RIVER,
	SHOW_DOWN,
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
enum {
	READY = 0,
	CARD_MOVING,
	CARD_OPENING,
	INITIALIZED,
}
enum {		# アクションボタン
	CHECK_CALL = 0,
	#CALL,
	FOLD,
	RAISE,
	ALL_IN,
	N_ACT_BUTTONS,
}
#const N_SUIT = 4
#const N_RANK = 13
const INIT_CHIPS = 200
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4			# カード：(suit << N_RANK_BITS) | rank
const CARD_WIDTH = 50
const COMU_CARD_PY = 80
const N_FLOP_CARDS = 3
const N_PLAYERS = 6
const BB_CHIPS = 2
const SB_CHIPS = BB_CHIPS / 2
const USER_IX = 0				# プレイヤー： players[USER_IX]
const WAIT_SEC = 0.5			# 次プレイヤーに手番が移るまでの待ち時間（秒）
const N_TRAIALS = 10000			# 期待勝率計算 モンテカルロ法試行回数
const MAX_N_RAISE = 3			# 現ラウンドにおける各プレイヤーの最大レイズ回数
const stateText = [
	"",		# for INIT
	"PreFlop", "Flop", "Turn", "River", "ShowDown",
]
const handName = [
	"highCard",
	"onePair",
	"twoPair",
	"threeOfAKind",
	"straight",
	"flush",
	"fullHouse",
	"fourOfAKind",
	"straightFlush",
	"RoyalFlush",
]

var sum_delta = 0.0
var state = INIT		# 状態
var sub_state = READY	# サブ状態
var bet_chips = 0		# ベットされたチップ数（1プレイヤー分合計）
var pot_chips = 0		# （中央）ポットチップ数
var cur_sum_bet = 0		# 現ラウンドでのベット・コールチップ合計（中央ポットに未移動分）
var nix = -1			# 次の手番
var dealer_ix = 0		# ディーラプレイヤーインデックス
var high_card = 0		# ハイカード
var high_card2 = 0		# ハイカードその２、for ２ペア等
var high_card3 = 0		# ハイカードその３、for ２ペア等
var deck_ix = 0			# デッキトップインデックス
var deck = []			# 要素：(suit << 4) | rank （※ rank:0～12 の数値、0 for 2,... 11 for King, 12 for Ace）
var comu_cards = []		# コミュニティカード
var players = []		# プレイヤーパネル配列、[0] for Human
#var players_cards = []		# プレイヤーカード、[0], [1] for Player-1, ...
var players_card1 = []		#
var players_card2 = []		#
var act_panels = []			# プレイヤーアクション表示パネル
var is_folded = []			# 各プレイヤーが Fold 済みか？
var n_raised = []			# 各プレイヤーの現ラウンドにおけるレイズ回数
var players_hand = []		# 各プレイヤーの手役
var bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数（パネル下部に表示されるチップ数）
#var bet_chips = []			# 各プレイヤー現ラウンドのベットチップ数
#var bet_chips_total = []	# 各プレイヤー現ラウンドのトータルベットチップ数
#var nPlayers = N_PLAYERS		# 6 players
var act_buttons = []
var n_moving = 0
var n_opening = 0
var nActPlayer = N_PLAYERS		# 非フォールドプレイヤー数
var deck_pos

var CardBF = load("res://CardBF.tscn")		# カード裏面
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
	
	deck_pos = $Table/CardDeck.get_position()
	players_hand.resize(N_PLAYERS)
	is_folded.resize(N_PLAYERS)
	n_raised.resize(N_PLAYERS)
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		#pb.get_node("ResultLabel").z_index = 2
		pb.set_hand("")
		pb.set_chips(INIT_CHIPS)
		players.push_back(pb)
		is_folded[i] = false
	print("width = ", players[0].texture.get_width())
	#for i in range(N_COMU_CARS):
	#	var cd = get_node("Table/CardBF%d" % (i+1))
	#	comu_cards.push_back(cd)
	#
	players[0].set_name("vivisuke")
	#players[0].set_BG(1)
	dealer_ix = rng.randi_range(0, N_PLAYERS - 1)
	print("dealer_ix = ", dealer_ix)
	# 行動ボタン
	act_buttons.resize(N_ACT_BUTTONS)
	act_buttons[CHECK_CALL] = $CheckCallButton
	#act_buttons[CALL] = $CallButton
	act_buttons[FOLD] = $FoldButton
	act_buttons[RAISE] = $RaiseButton
	act_buttons[ALL_IN] = $AllInNextButton
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
	$RaiseSpinBox.set_value(BB_CHIPS)
	$RaiseSpinBox.editable = false
	#$RaiseButton.text = "Raise 2"
	#
	update_d_SB_BB()	# D, SB, BB マーク設置
	#update_title_text()
	update_roundLabel()
	pass
func update_roundLabel():
	$RoundLabel.text = stateText[state]
func update_title_text():
	var txt = "6P Ring Game"
	if state != INIT:
		txt += " - " + stateText[state] + " -"
	$TitleBar/Label.text = txt
func update_d_SB_BB():
	cur_sum_bet = 0
	for i in range(N_PLAYERS):
		players[i].copy_to_prev_chips()
		players[i].show_diff_chips(false)
	bet_chips = BB_CHIPS
	bet_chips_plyr.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var mk = players[i].get_node("Mark")
		mk.show()
		if dealer_ix == i:
			mk.frame = DEALER
			bet_chips_plyr[i] = 0
			if state >= FLOP:
				nix = (i + 1) % N_PLAYERS		# 次の手番
		elif (dealer_ix + 1) % N_PLAYERS == i:
			mk.frame = SB
			bet_chips_plyr[i] = SB_CHIPS
			cur_sum_bet += SB_CHIPS
		elif (dealer_ix + 2) % N_PLAYERS == i:
			mk.frame = BB
			bet_chips_plyr[i] = BB_CHIPS
			cur_sum_bet += BB_CHIPS
			#next_player()
			if state < FLOP:
				nix = (i + 1) % N_PLAYERS		# 次の手番
		else:
			mk.hide()
			bet_chips_plyr[i] = 0
		if bet_chips_plyr[i] == 0:
			players[i].show_bet_chips(false)
		else:
			players[i].show_bet_chips(true)
			players[i].set_bet_chips(bet_chips_plyr[i])
			players[i].set_chips(players[i].get_chips() - bet_chips_plyr[i])
	update_next_player()
	#print("nix = ", nix)
func update_next_player():
	for i in range(N_PLAYERS):
		if is_folded[i]:
			players[i].set_BG(BG_FOLDED)
		else:
			players[i].set_BG(BG_PLY if state != INIT && i == nix else BG_WAIT)
	if nix < act_panels.size():
		act_panels[nix].hide()
func card_to_suit(cd): return cd >> N_RANK_BITS
func card_to_rank(cd): return cd & RANK_MASK
func shuffle_cards():
	# デッキカードシャフル
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st : int = i / N_RANK
		var rank : int = i % N_RANK
		deck[i] = (st<<N_RANK_BITS) | rank
	deck.shuffle()
	deck_ix = 0
func deal_cards():
	shuffle_cards()
	#
	# 各プレイヤーにカード配布
	players_card1 = []
	var ix = 0
	for i in range(N_PLAYERS):
		players_card1.push_back(deck[ix])
		#var st : int = deck[ix] >> N_RANK_BITS
		#var rank : int = deck[ix] & RANK_MASK
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
	#
	# 共通カード配布
	#for i in range(N_COMU_CARS):
	#	var st : int = deck[ix] >> N_RANK_BITS
	#	var rank : int = deck[ix] & RANK_MASK
	#	ix += 1
	#	comu_cards[i].set_sr(st, rank)
	#
#func next_game():
#	state = INIT
#	update_roundLabel()
func next_round():
	print("nActPlayer = ", nActPlayer)
	cur_sum_bet = 0
	for i in range(N_PLAYERS): n_raised[i] = 0
	if state >= PRE_FLOP && state <= RIVER:
		var sum = 0
		for i in range(N_PLAYERS):
			sum += bet_chips_plyr[i]
			bet_chips_plyr[i] = 0
			players[i].set_bet_chips(0)
			players[i].show_bet_chips(false)
		pot_chips += sum
		$Table/Chips/PotLabel.text = String(pot_chips)
	if state == INIT:
		state = PRE_FLOP
		comu_cards = []
		#$AllInNextButton.text = "AllIn"
		#$AllInNextButton.disabled = true
		shuffle_cards()
		n_moving = N_PLAYERS * 2		# 各プレイヤーにカードを２枚配布
		sub_state = CARD_MOVING
		#players_cards.resize(N_PLAYERS * 2)
		players_card1.resize(N_PLAYERS)
		for i in range(N_PLAYERS):
			var di = (dealer_ix + 1 + i) % N_PLAYERS
			var cd = CardBF.instance()		# カード裏面
			players_card1[di] = cd
			cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
			deck_ix += 1
			cd.set_position(deck_pos)
			$Table.add_child(cd)
			#players[i].get_node("CardParent").add_child(cd)
			cd.connect("move_finished", self, "move_finished")
			cd.connect("open_finished", self, "open_finished")
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
			cd.connect("move_finished", self, "move_finished")
			cd.connect("open_finished", self, "open_finished")
			var dst = players[di].get_position() + Vector2(CARD_WIDTH/2, -4)
			cd.wait_move_to((N_PLAYERS + i) * 0.1, dst, 0.3)
		act_panels.resize(N_PLAYERS)
		for i in range(N_PLAYERS):
			var ap = ActionPanel.instance()
			act_panels[i] = ap
			ap.hide()
			ap.set_position(players[i].position - ap.rect_size/2)
			$Table.add_child(ap)
		print(act_panels[0].rect_size)
	elif state == PRE_FLOP:
		#deal_cards()
		state = FLOP
		for i in range(N_PLAYERS):		# 暫定コード
			act_panels[i].set_text("called")
			act_panels[i].show()
		#comu_cards = []
		n_moving = N_FLOP_CARDS		# 3 for FLOP
		sub_state = CARD_MOVING
		for i in range(n_moving):
			var cd = CardBF.instance()
			comu_cards.push_back(cd)
			cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
			deck_ix += 1
			cd.set_position(deck_pos)
			$Table.add_child(cd)
			cd.connect("move_finished", self, "move_finished")
			cd.connect("open_finished", self, "open_finished")
			cd.move_to(Vector2(CARD_WIDTH*(i-2), COMU_CARD_PY), 0.3)
	elif state == FLOP:
		state = TURN
		n_moving = 1
		sub_state = CARD_MOVING
		var cd = CardBF.instance()
		comu_cards.push_back(cd)
		cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
		deck_ix += 1
		cd.set_position(deck_pos)
		$Table.add_child(cd)
		cd.connect("move_finished", self, "move_finished")
		cd.connect("open_finished", self, "open_finished")
		cd.move_to(Vector2(CARD_WIDTH, COMU_CARD_PY), 0.3)
	elif state == TURN:
		state = RIVER
		n_moving = 1
		sub_state = CARD_MOVING
		var cd = CardBF.instance()
		comu_cards.push_back(cd)
		cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
		deck_ix += 1
		cd.set_position(deck_pos)
		$Table.add_child(cd)
		cd.connect("move_finished", self, "move_finished")
		cd.connect("open_finished", self, "open_finished")
		cd.move_to(Vector2(CARD_WIDTH*2, COMU_CARD_PY), 0.3)
	elif state == RIVER:
		state = SHOW_DOWN
		disable_act_buttons()			# コマンドボタンディセーブル
		n_opening = N_PLAYERS
		for i in range(N_PLAYERS):		# 暫定コード
			act_panels[i].hide()
			if is_folded[i]: n_opening -= 1
		if !is_folded[USER_IX]: n_opening -= 1		# ユーザプレイヤーのカードはすでにオープンされている
		n_opening *= 2
		sub_state = CARD_OPENING
		for i in range(1, N_PLAYERS):	# 全プレイヤーのカードをオープン
			if !is_folded[i]:
				players_card1[i].do_open()
				players_card2[i].do_open()
		pass
	elif state == SHOW_DOWN:
		state = INIT
		nActPlayer = N_PLAYERS
		dealer_ix = (dealer_ix + 1) % N_PLAYERS
		for i in range(N_PLAYERS):
			#print("chils[", i, "] = ", players[i].get_chips())
			if players[i].get_chips() <= 0:		# バーストした場合
				players[i].set_chips(INIT_CHIPS/2)		# 初期チップの半分を与える
		update_d_SB_BB()
		for i in range(N_PLAYERS):
			players_card1[i].queue_free()
			players_card2[i].queue_free()
			players[i].set_hand("")
			act_panels[i].queue_free()
			is_folded[i] = false
		for i in range(comu_cards.size()):
			comu_cards[i].queue_free()
	hide_act_panels()
	update_roundLabel()
	if state >= FLOP:
		nix = (dealer_ix + 1) % N_PLAYERS		# 次の手番
		bet_chips = 0
	update_next_player()
func hide_act_panels():
	for i in range(N_PLAYERS):
		act_panels[i].hide()
		act_panels[i].set_text("")
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		if n_moving != 0: return;			# カード移動中
		if event.position.y >= 700: return
		if state == INIT || state == SHOW_DOWN:
			next_round()		# 次のラウンドに遷移
		#elif state == SHOW_DOWN:
		#	next_game()
func move_finished():
	n_moving -= 1
	if n_moving == 0:
		print("move_finished")
		sub_state = CARD_OPENING
		if state == PRE_FLOP:
			n_opening = 2
			players_card1[0].do_open()
			players_card2[0].do_open()
		elif state == FLOP:
			n_opening = N_FLOP_CARDS
			for i in range(N_FLOP_CARDS):		# 3 for FLOP
				comu_cards[i].do_open()
		elif state == TURN:
			n_opening = 1
			comu_cards[N_FLOP_CARDS].do_open()
		elif state == RIVER:
			n_opening = 1
			comu_cards[N_FLOP_CARDS + 1].do_open()
		else:
			sub_state = READY
func open_finished():
	n_opening -= 1
	print(n_opening)
	if n_opening == 0:
		sub_state = READY
		if state == PRE_FLOP:
			show_user_hand(0)
		elif state == FLOP:
			show_user_hand(3)
		elif state == TURN:
			show_user_hand(4)
		elif state == RIVER:
			show_user_hand(5)
		elif state == SHOW_DOWN:
			show_hand()
func do_fold(pix):
	nActPlayer -= 1
	is_folded[pix] = true
	#players[pix].set_BG(2)
	players_card1[pix].hide()
	players_card2[pix].hide()
	players[pix].set_hand("")			# 手役表示クリア
	act_panels[pix].set_text("folded")
	act_panels[pix].get_node("PinkPanel").hide()
	act_panels[pix].show()
func do_check(pix):
	act_panels[pix].set_text("checked")
	act_panels[pix].get_node("PinkPanel").hide()
	act_panels[pix].show()
func do_call(pix):
	act_panels[pix].set_text("called")
	act_panels[pix].get_node("PinkPanel").hide()
	act_panels[pix].show()
	players[pix].set_bet_chips(bet_chips)
	cur_sum_bet += bet_chips - bet_chips_plyr[pix]
	players[pix].sub_chips(bet_chips - bet_chips_plyr[pix])
	bet_chips_plyr[pix] = bet_chips
func do_raise(pix, c):
	act_panels[pix].set_text("raised")
	act_panels[pix].get_node("PinkPanel").show()
	act_panels[pix].show()
	bet_chips += c			# コール分＋レイズ分 が実際に場に出される
	players[pix].set_bet_chips(bet_chips)
	cur_sum_bet += bet_chips - bet_chips_plyr[pix]
	players[pix].sub_chips(bet_chips - bet_chips_plyr[pix])
	bet_chips_plyr[pix] = bet_chips
	n_raised[pix] += 1
func max_raise_chips(pix):		# 可能最大レイズ額
	return max(0, players[pix].get_chips() - (bet_chips - bet_chips_plyr[pix]))
func _process(delta):
	if state == SHOW_DOWN: return
	#if nix != USER_IX || state == INIT:
	#	sum_delta += delta
	#	if sum_delta < WAIT_SEC: return
	#	sum_delta -= WAIT_SEC
	#print("state = ", state)
	#print("sub_state = ", sub_state)
	if sub_state != 0:
		#print("sub_state != 0")
		return
	#print("nix = ", nix)
	if nix == USER_IX && is_folded[nix]:		# ユーザプレイヤー手番 && Folded の場合
		next_player()
	elif state == INIT:
		# undone: 一定時間ウェイト？
		next_round()		# 次のラウンドに遷移
	elif state >= PRE_FLOP && nix >= 0:
		if( act_panels[nix].get_text() != "" &&		# 行動済み
			bet_chips_plyr[nix] == bet_chips ):		# チェック可能
				next_round()
		else:
			if !is_folded[nix]:
				if players[nix].get_chips() == 0:		# 所持チップ０の場合
					act_panels[nix].set_text("skipped")
					act_panels[nix].show()
				else:
					var max_raise = max_raise_chips(nix)
					if nix == USER_IX:
						if bet_chips_plyr[USER_IX] < bet_chips:
							act_buttons[CHECK_CALL].text = "Call %d" % (bet_chips - bet_chips_plyr[USER_IX])
						else:
							act_buttons[CHECK_CALL].text = "Check"
						#act_buttons[CHECK].disabled = bet_chips_plyr[USER_IX] < bet_chips
						#act_buttons[CALL].disabled = bet_chips_plyr[USER_IX] == bet_chips
						# コマンドボタン・スピンボックスをイネーブル
						for i in range(N_ACT_BUTTONS):
							act_buttons[i].disabled = false
						$RaiseSpinBox.max_value = max_raise
						$RaiseSpinBox.editable = true
						sub_state = INITIALIZED
						#print("win rate = ", calc_win_rate(USER_IX, nActPlayer - 1))	# 5: 暫定
						return		# 次のプレイヤーに遷移しないように
					else:
						var wrt = calc_win_rate(nix, nActPlayer - 1)		# 期待勝率計算
						print("win rate[", nix, "] = ", wrt)
						#print("wrt = ", wrt)
						print("bet_chips_plyr[", nix, "] = ", bet_chips_plyr[nix])
						if( max_raise > 0 && wrt >= 1.0 / nActPlayer * 1.5 &&		# 期待勝率が1/人数の1.5倍以上の場合
							n_raised[nix] < MAX_N_RAISE ):							# 最大レイズ回数に達していない場合
								var bc = min(max_raise, max(BB_CHIPS, int((pot_chips + cur_sum_bet) / 4)))
								do_raise(nix, bc)
						elif bet_chips_plyr[nix] < bet_chips:		# チェック出来ない場合
							# undone: Fold 判定
							var cc = bet_chips -  bet_chips_plyr[nix]
							var odds = float(pot_chips + cur_sum_bet + cc) / cc
							print("total pot = ", (pot_chips + cur_sum_bet), " odds = ", odds)
							if state == PRE_FLOP || wrt >= 1.0 / odds:
								print("called")
								do_call(nix)
							else:
								do_fold(nix)
						else:		# チェック可能な場合
							if act_panels[nix].get_text() == "":	# 未行動の場合
								do_check(nix)
			next_player()		# 次のプレイヤーに遷移
	pass
func get_unused_card(dk):	# 未使用カードをひとつゲット、そのカードは使用済みに
	var ix
	while true:
		ix = rng.randi_range(0, N_CARDS-1)
		if dk[ix] >= 0: break
	var cd = dk[ix]
	dk[ix] = -1	# 使用済みフラグON
	return cd
# モンテカルロ法による期待勝率計算、return [0.0, 1.0]
func calc_win_rate(pix : int, nEnemy : int) -> float:
	var v = []		# v[0], v[1]：手札、v[2]～ コミュニティカード（無い場合もあり）
	v.push_back(players_card1[pix].get_sr())
	v.push_back(players_card2[pix].get_sr())
	for k in range(comu_cards.size()):
		v.push_back(comu_cards[k].get_sr())
	var wsum = 0.0
	var dk = []				# デッキ用配列
	dk.resize(N_CARDS)
	for nt in range(N_TRAIALS):
		for i in range(N_CARDS):		# デッキ初期化
			var st : int = i / N_RANK
			var rank : int = i % N_RANK
			dk[i] = (st<<N_RANK_BITS) | rank
		for i in range(v.size()):
			var ix = card_to_suit(v[i]) * 13 + card_to_rank(v[i])
			dk[ix] = -1			# 使用済みフラグON
		# 自分の手札
		var u = v.duplicate()
		while u.size() < 7:
			u.push_back(get_unused_card(dk))
		var oh = check_hand(u)
		var nw = 1		# 勝者数
		var win = true
		for e in range(nEnemy):
			u[0] = get_unused_card(dk)
			u[1] = get_unused_card(dk)
			var eh = check_hand(u)
			var r = compare(oh, eh)
			if r < 0:
				win = false
				break		# 負けの場合
			if r == 0:			# 引き分けの場合
				nw += 1
		if win: wsum += 1.0 / nw
	return wsum / N_TRAIALS
func add_rank_pair(v, p1, p2, hand):	# ペアの場合に、ペア以外の数字を大きい順に結果配列に追加
	var rnk = []
	for i in range(v.size()):
		var r = card_to_rank(v[i])
		if r != p1 && r != p2:		# ペアの数字でない場合
			rnk.push_back(r)
	rnk.sort()		# 昇順ソート
	var t = [hand]
	var n = 5		# 配列に追加する枚数
	if p2 >= 0:		# 2ペアの場合
		t.push_back(p1)
		t.push_back(p2)
		n = 1
	elif p1 >= 0:		# 1ペアの場合
		t.push_back(p1)
		n = 3
	n = min(rnk.size(), n)
	for i in range(n):
		t.push_back(rnk[rnk.size()-1-i])		# ランクを降順に格納
	return t
func add_rank(v, s, hand):		# フラッシュの場合に、そのスートの数字を大きい順に結果配列に追加
	var rnk = []
	for i in range(v.size()):
		if( card_to_suit(v[i]) == s ):		# 同一スートの場合
			rnk.push_back(card_to_rank(v[i]))
	rnk.sort()		# 昇順ソート
	var t = [hand]
	for i in range(5):				# 大きいランクから５枚を配列に追加
		t.push_back(rnk[-1-i])		# ランクを降順に格納
	#print("flush: ", t)
	return t
func get_ranks(v, exr1, exr2):			# exr1, exr2 以外のランクリスト（昇順ソート済み）を取得
	var lst = []
	for i in range(v.size()):
		var r = card_to_rank(v[i])
		if r != exr1 && r != exr2:
			lst.push_back(r)
	lst.sort()		# 昇順ソート
	return lst
func print_hand(h):
	var txt = String(h[0]) + " "
	for i in range(1, h.size()):
		txt += RANK_STR[h[i]] + " "
	print("check_hand(): ", txt)
# 手役判定
# return: [手役, ランク１，ランク２,...]
func check_hand(v : Array) -> Array:
	var rcnt = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var scnt = [0, 0, 0, 0]
	for i in range(v.size()):			# 手札のランク、スートの数を数える
		rcnt[card_to_rank(v[i])] += 1
		scnt[card_to_suit(v[i])] += 1
	var s = -1		# フラッシュの場合のスート
	if scnt[CLUBS] >= 5: s = CLUBS
	elif scnt[DIAMONDS] >= 5: s = DIAMONDS
	elif scnt[HEARTS] >= 5: s = HEARTS
	elif scnt[SPADES] >= 5: s = SPADES
	if s >= CLUBS:		# フラッシュ確定
		var bitmap = 0		# ランクをビット値に変換したものの合計
		for i in v.size():
			if( card_to_suit(v[i]) == s ):		# 同一スートの場合
				bitmap |= 1 << card_to_rank(v[i])
		var mask = 0x1f00		# AKQJT
		for i in range(9):
			if( (bitmap & mask) == mask ):
				return [STRAIGHT_FLUSH, mask]
			mask >>= 1
		if( bitmap == 0x100f ):		# 1 0000 00000 1111 = 5432A
			return [STRAIGHT_FLUSH, 0x0f]		# 5432A よりも 65432 の方が強い
	#else:
	#	s = -1
	#
	var threeOfAKindRank = -1		# 3 of a Kind の rcnt インデックス
	var threeOfAKindRank2 = -1	# 3 of a Kind の rcnt インデックス その２
	var pairRank1 = -1			# ペアの場合の rcnt インデックス
	var pairRank2 = -1			# ペアの場合の rcnt インデックス その２、pairRank1 > pairRank2 とする
	for r in range(13):
		if( rcnt[r] == 4):
			return [FOUR_OF_A_KIND, r]		# 4 of a kind は他のプレイヤーと同じ数字になることはない
		if( rcnt[r] == 3):
			if( threeOfAKindRank < 0 ):
				threeOfAKindRank = r
			else:
				threeOfAKindRank2 = r
		elif( rcnt[r] == 2):
			if pairRank1 < 0:
				pairRank1 = r
			elif pairRank2 < 0:
				if pairRank1 > r:
					pairRank2 = r
				else:
					pairRank2 = pairRank1
					pairRank1 = r
			else:
				if r > pairRank1:
					pairRank2 = pairRank1
					pairRank1 = r
				if r > pairRank2:
					pairRank2 = r
	# 3カード*2 もフルハウス
	if( threeOfAKindRank >= 0 && (pairRank1 >= 0 || threeOfAKindRank2 >= 0) ):
		return [FULL_HOUSE, threeOfAKindRank]		# 3 of a kind は他のプレイヤーと同じ数字になることはない
	if( s >= 0 ):
		return add_rank(v, s, FLUSH)
	#
	var bitmap = 0
	var mask = 1
	for i in range(13):
		if( rcnt[i] != 0 ):
			bitmap |= mask
		mask <<= 1
	mask = 0x1f00		#	AKQJT
	for i in range(9):
		if( (bitmap & mask) == mask ):
			return [STRAIGHT, mask]
		mask >>= 1
	if( (bitmap & 0x100f) == 0x100f ):		#	5432A
		return [STRAIGHT, 0x0f]				# 5432A より 65432 の方が強い
	if( threeOfAKindRank >= 0 ):
		return [THREE_OF_A_KIND, threeOfAKindRank]		# 3 of a kind は他のプレイヤーと同じ数字になることはない
	if( pairRank2 >= 0 ):
		#return [TWO_PAIR]
		return add_rank_pair(v, pairRank1, pairRank2, TWO_PAIR)
	if( pairRank1 >= 0 ):
		return add_rank_pair(v, pairRank1, -1, ONE_PAIR)
		#return [ONE_PAIR]
	return add_rank_pair(v, -1, -1, HIGH_CARD)
	#return [HIGH_CARD]
func show_user_hand(n):
	if is_folded[USER_IX]: return
	var v = []
	v.push_back(players_card1[0].get_sr())
	v.push_back(players_card2[0].get_sr())
	for k in range(n): v.push_back(comu_cards[k].get_sr())
	#print("i = ", i, ", v = ", v)
	#print("hand = ", handName[check_hand(v)])
	players[0].set_hand(handName[check_hand(v)[0]])
# ランクも考慮した手役比較
# return: -1 for hand1 < hand2, +1 for hand1 > hand2
func compare(hand1 : Array, hand2 : Array):
	if hand1[0] == hand2[0]:
		for i in range(1, hand1.size()):
			if hand1[i] < hand2[i]: return -1
			elif hand1[i] > hand2[i]: return 1
		return 0
	elif hand1[0] < hand2[0]:
		return -1
	else:
		return 1
func show_hand():		# ShowDown時の処理
	var max_hand = [-1]
	var winners = []
	for i in range(N_PLAYERS):
		if !is_folded[i]:
			var v = []
			v.push_back(players_card1[i].get_sr())
			v.push_back(players_card2[i].get_sr())
			for k in range(5): v.push_back(comu_cards[k].get_sr())
			#print("i = ", i, ", v = ", v)
			#print("hand = ", handName[check_hand(v)])
			players_hand[i] = check_hand(v)
			if players_hand[i][0] == TWO_PAIR:
				print_hand(players_hand[i])
			players[i].set_hand(handName[players_hand[i][0]])
			var r = compare(players_hand[i], max_hand)
			if r > 0:
				max_hand = players_hand[i]
				winners = [i]
			elif r ==  0:
				winners.push_back(i)
	print("winners = ", winners)
	for i in range(N_PLAYERS):
		players[i].set_BG(BG_PLY if winners.find(i) >= 0 else BG_WAIT)
	# ポットのチップを勝者で分配
	if winners.size() == 1:		# 一人勝ちの場合
		players[winners[0]].add_chips(pot_chips)
	else:		# 勝ちが複数いる場合（チョップ）
		#assert(false)		# 未実装
		var c : int = pot_chips / winners.size()	# 取り分
		var m : int = pot_chips % winners.size()	# 余り
		for i in range(N_PLAYERS):
			if winners.find(i) >= 0:
				players[i].add_chips(c)
		if m != 0:		# 余りがある場合
			for i in range(N_PLAYERS):
				var ix = (dealer_ix + 1 + i) % N_PLAYERS	# SB から
				if winners.find(ix) >= 0:
					players[ix].add_chips(1)
					m -= 1
					if m == 0: break		# 余りを分配終了
	for i in range(N_PLAYERS):
		players[i].show_diff_chips(true)
	pot_chips = 0
	$Table/Chips/PotLabel.text = String(pot_chips)
	#
	$AllInNextButton.text = "Next"
	$AllInNextButton.disabled = false
func _on_PlayerBG_open_finished():
	if n_opening != 0:
		n_opening -= 1
		if n_opening == 0:
			print("finished opening")
			sub_state = READY
			for i in range(N_PLAYERS):
				if !is_folded[i]:
					var v = []
					v.push_back(players_card1[i])
					v.push_back(players_card2[i])
					for k in range(5): v.push_back(comu_cards[k].get_sr())
					print("v = ", v)
					print("hand = ", handName[check_hand(v)[0]])
					players[i].set_hand(handName[check_hand(v)[0]])
	pass

func disable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
	$RaiseSpinBox.editable = false
func next_player():
	sub_state = READY
	while true:
		nix = (nix + 1) % N_PLAYERS
		if !is_folded[nix]: break
	update_next_player()
#func _on_CheckButton_pressed():
#	do_check(USER_IX)
#	next_player()
#	pass # Replace with function body.
#func _on_CallButton_pressed():
#	do_call(USER_IX)
#	next_player()
func _on_FoldButton_pressed():
	do_fold(USER_IX)
	disable_act_buttons()
	next_player()
func _on_CheckCallButton_pressed():
	if bet_chips_plyr[USER_IX] < bet_chips:
		do_call(USER_IX)
	else:
		do_check(USER_IX)
	disable_act_buttons()
	next_player()
	pass # Replace with function body.
func _on_RaiseButton_pressed():
	do_raise(USER_IX, $RaiseSpinBox.get_value())
	disable_act_buttons()
	$RaiseSpinBox.set_value(BB_CHIPS)
	next_player()
func _on_AllInNextButton_pressed():
	if state == SHOW_DOWN:
		$AllInNextButton.text = "AllIn"
		$AllInNextButton.disabled = true
		next_round()
	else:
		var tc = bet_chips - bet_chips_plyr[USER_IX]	# コールに必要なチップ数
		var rc = players[USER_IX].get_chips() - tc		# レイズチップ数
		if rc == 0:		# レイズ不可、コール可能
			do_call(USER_IX)
		elif rc > 0:	# レイズ可能
			do_raise(USER_IX, rc)
		next_player()
	pass # Replace with function body.
