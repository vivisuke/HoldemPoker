extends Node2D

enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
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
	READY = 0,
	CARD_MOVING,
	CARD_OPENING,
}
enum {		# アクションボタン
	CHECK = 0,
	CALL,
	FOLD,
	RAISE,
	ALL_IN,
	N_ACT_BUTTONS,
}
#const N_SUIT = 4
#const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4
const CARD_WIDTH = 50
const COMU_CARD_PY = 80
const N_FLOP_CARDS = 3
const N_PLAYERS = 6
const BB_CHIPS = 2
const SB_CHIPS = BB_CHIPS / 2
const USER_IX = 0					# プレイヤー： players[USER_IX]
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
var bet_chip = 0		# ベットされたチップ（1プレイヤー分合計）
var nix = -1			# 次の手番
var dealer_ix = 0
var deck_ix = 0			# デッキトップインデックス
var deck = []			# 要素：(suit << 4) | rank
var comu_cards = []		# コミュニティカード
var players = []		# プレイヤーパネル配列、[0] for Human
#var players_cards = []		# プレイヤーカード、[0], [1] for Player-1, ...
var players_card1 = []		#
var players_card2 = []		#
var act_panels = []			# プレイヤーアクション表示パネル
var bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数（パネル下部に表示されるチップ数）
#var bet_chips = []			# 各プレイヤー現ラウンドのベットチップ数
#var bet_chips_total = []	# 各プレイヤー現ラウンドのトータルベットチップ数
#var nPlayers = N_PLAYERS		# 6 players
var act_buttons = []
var n_moving = 0
var n_opening = 0
var deck_pos

var CardBF = load("res://CardBF.tscn")		# カード裏面
var ActionPanel = load("res://ActionPanel.tscn")

var rng = RandomNumberGenerator.new()

func _ready():
	randomize()
	rng.randomize()
	#seed(0)
	#
	
	deck_pos = $Table/CardDeck.get_position()
	players = []
	for i in range(N_PLAYERS):
		var pb = get_node("Table/PlayerBG%d" % (i+1))		# プレイヤーパネル
		#pb.get_node("ResultLabel").z_index = 2
		pb.set_hand("")
		pb.set_chips(200)
		players.push_back(pb)
	print("width = ", players[0].texture.get_width())
	#for i in range(N_COMU_CARS):
	#	var cd = get_node("Table/CardBF%d" % (i+1))
	#	comu_cards.push_back(cd)
	#
	players[0].set_name("vivisuke")
	#players[0].set_BG(1)
	dealer_ix = rng.randi_range(0, N_PLAYERS - 1)
	print("dealer_ix = ", dealer_ix)
	#
	act_buttons.resize(N_ACT_BUTTONS)
	act_buttons[CHECK] = $CheckButton
	act_buttons[CALL] = $CallButton
	act_buttons[FOLD] = $FoldButton
	act_buttons[RAISE] = $RaiseButton
	act_buttons[ALL_IN] = $AllInButton
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
	#
	update_d_SB_BB()	# D, SB, BB マーク設置
	update_title_text()
	pass
func update_title_text():
	var txt = "6P Ring Game"
	if state != INIT:
		txt += " " + stateText[state]
	$TitleBar/Label.text = txt
func update_d_SB_BB():
	bet_chip = BB_CHIPS
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
		elif (dealer_ix + 2) % N_PLAYERS == i:
			mk.frame = BB
			bet_chips_plyr[i] = BB_CHIPS
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
	print("nix = ", nix)
func update_next_player():
	for i in range(N_PLAYERS):
		players[i].set_BG(1 if state != INIT && i == nix else 0)
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
		var st : int = deck[ix] >> N_RANK_BITS
		var rank : int = deck[ix] & RANK_MASK
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
func next_round():
	if state == INIT:
		state = PRE_FLOP
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
		comu_cards = []
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
		for i in range(N_PLAYERS):		# 暫定コード
			act_panels[i].hide()
		n_opening = (N_PLAYERS - 1)*2
		sub_state = CARD_OPENING
		for i in range(1, N_PLAYERS):
			players_card1[i].do_open()
			players_card2[i].do_open()
		pass
	elif state == SHOW_DOWN:
		state = INIT
		dealer_ix = (dealer_ix + 1) % N_PLAYERS
		update_d_SB_BB()
		for i in range(N_PLAYERS):
			players_card1[i].queue_free()
			players_card2[i].queue_free()
			players[i].set_hand("")
			act_panels[i].queue_free()
		for i in range(comu_cards.size()):
			comu_cards[i].queue_free()
	hide_act_panels()
	update_title_text()
	if state >= FLOP:
		nix = (dealer_ix + 1) % N_PLAYERS		# 次の手番
	update_next_player()
func hide_act_panels():
	for i in range(N_PLAYERS):
		act_panels[i].hide()
		act_panels[i].set_text("")
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		if n_moving != 0: return;			# カード移動中
		if event.position.y >= 700: return
		if state == INIT:
			next_round()		# 次のラウンドに遷移
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
func do_check(pix):
	act_panels[pix].set_text("checked")
	act_panels[pix].show()
func do_call(pix):
	act_panels[pix].set_text("called")
	act_panels[pix].show()
	players[pix].set_bet_chips(bet_chip)
	players[pix].sub_chips(bet_chip - bet_chips_plyr[pix])
	bet_chips_plyr[pix] = bet_chip
func _process(delta):
	sum_delta += delta
	if sum_delta < 1.0: return
	sum_delta -= 1.0
	print("state = ", state)
	if state == INIT || state == SHOW_DOWN: return
	print("sub_state = ", sub_state)
	if sub_state != 0:
		print("sub_state != 0")
		return
	print("nix = ", nix)
	if state >= PRE_FLOP && nix >= 0:
		if( act_panels[nix].get_text() != "" &&		# 行動済み
			bet_chips_plyr[nix] == bet_chip ):		# チェック可能
				next_round()
		else:
			if nix == USER_IX:
				act_buttons[CHECK].disabled = bet_chips_plyr[USER_IX] < bet_chip
				act_buttons[CALL].disabled = bet_chips_plyr[USER_IX] == bet_chip
				for i in range(FOLD, N_ACT_BUTTONS):
					act_buttons[i].disabled = false
			else:
				print("bet_chips_plyr[", nix, "] = ", bet_chips_plyr[nix])
				if bet_chips_plyr[nix] < bet_chip:		# チェック出来ない場合
					print("called")
					do_call(nix)
				else:		# チェック可能な場合
					if act_panels[nix].get_text() == "":	# 未行動の場合
						do_check(nix)
				next_player()
	pass

func check_hand(v : Array):
	var rcnt = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var scnt = [0, 0, 0, 0]
	for i in range(v.size()):
		rcnt[v[i] & RANK_MASK] += 1
		scnt[v[i] >> N_RANK_BITS] += 1
	var s = -1
	if scnt[CLUBS] >= 5: s = CLUBS
	elif scnt[DIAMONDS] >= 5: s = DIAMONDS
	elif scnt[HEARTS] >= 5: s = HEARTS
	elif scnt[SPADES] >= 5: s = SPADES
	if s >= CLUBS:		# フラッシュ確定
		var bitmap = 0;
		for i in v.size():
			if( (v[i] >> N_RANK_BITS) == s ):
				bitmap |= 1 << (v[i] & RANK_MASK);
		var mask = 0x1f00;		# AKQJT
		for i in range(9):
			if( (bitmap & mask) == mask ):
				return STRAIGHT_FLUSH;
			mask >>= 1
		if( bitmap == 0x100f ):		# 1 0000 00000 1111 = A5432
			return STRAIGHT_FLUSH;
	else:
		s = -1;
	#
	var threeOfAKindIX = -1;
	var threeOfAKindIX2 = -1;
	var pairIX1 = -1;
	var pairIX2 = -1;
	for i in range(13):
		if( rcnt[i] == 4):
			return FOUR_OF_A_KIND;
		if( rcnt[i] == 3):
			if( threeOfAKindIX < 0 ):
				threeOfAKindIX = i;
			else:
				threeOfAKindIX2 = i;
		elif( rcnt[i] == 2):
			pairIX2 = pairIX1;
			pairIX1 = i;
	# 3カード*2 もフルハウス
	if( threeOfAKindIX >= 0 && (pairIX1 >= 0 || threeOfAKindIX2 >= 0) ):
		return FULL_HOUSE;
	if( s >= 0 ):
		return FLUSH;
	#
	var bitmap = 0;
	var mask = 1;
	for i in range(13):
		if( rcnt[i] != 0 ):
			bitmap |= mask;
		mask <<= 1
	mask = 0x1f00;		#	AKQJT
	for i in range(9):
		if( (bitmap & mask) == mask ):
			return STRAIGHT;
		mask >>= 1
	if( (bitmap & 0x100f) == 0x100f ):		#	5432A
		return STRAIGHT;
	if( threeOfAKindIX >= 0 ):
		return THREE_OF_A_KIND;
	if( pairIX2 >= 0 ):
		return TWO_PAIR;
	if( pairIX1 >= 0 ):
		return ONE_PAIR;
	return HIGH_CARD
func show_user_hand(n):
	var v = []
	v.push_back(players_card1[0].get_sr())
	v.push_back(players_card2[0].get_sr())
	for k in range(n): v.push_back(comu_cards[k].get_sr())
	#print("i = ", i, ", v = ", v)
	#print("hand = ", handName[check_hand(v)])
	players[0].set_hand(handName[check_hand(v)])
func show_hand():
	for i in range(N_PLAYERS):
		var v = []
		v.push_back(players_card1[i].get_sr())
		v.push_back(players_card2[i].get_sr())
		for k in range(5): v.push_back(comu_cards[k].get_sr())
		#print("i = ", i, ", v = ", v)
		#print("hand = ", handName[check_hand(v)])
		players[i].set_hand(handName[check_hand(v)])
func _on_PlayerBG_open_finished():
	if n_opening != 0:
		n_opening -= 1
		if n_opening == 0:
			print("finished opening")
			sub_state = READY
			for i in range(N_PLAYERS):
				var v = []
				v.push_back(players_card1[i])
				v.push_back(players_card2[i])
				for k in range(5): v.push_back(comu_cards[k].get_sr())
				print("v = ", v)
				print("hand = ", handName[check_hand(v)])
				players[i].set_hand(handName[check_hand(v)])
	pass

func disable_act_buttons():
	for i in range(N_ACT_BUTTONS):
		act_buttons[i].disabled = true
func next_player():
	nix = (nix + 1) % N_PLAYERS
	update_next_player()
func _on_CheckButton_pressed():
	next_player()
	pass # Replace with function body.
func _on_CallButton_pressed():
	do_call(USER_IX)
	next_player()
