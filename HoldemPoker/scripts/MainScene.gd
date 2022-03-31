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
#const N_SUIT = 4
#const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4
const CARD_WIDTH = 40
const COMU_CARD_PY = 80
const N_FLOP_CARDS = 3
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

var state = INIT		# 状態
var dealer_ix = 0
var deck_ix = 0			# デッキトップインデックス
var deck = []			# 要素：(suit << 4) | rank
var comu_cards = []		# コミュニティカード
var players = []		# プレイヤーパネル配列、[0] for Human
#var players_cards = []		# プレイヤーカード、[0], [1] for Player-1, ...
var players_card1 = []		#
var players_card2 = []		#
var action_panels = []		# プレイヤーアクション表示パネル
var nPlayers = 6		# 6 players
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
	for i in range(nPlayers):
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
	players[0].set_BG(1)
	dealer_ix = rng.randi_range(0, players.size() - 1)
	print("dealer_ix = ", dealer_ix)
	update_d_SB_BB()
	update_title_text()
	pass
func update_title_text():
	var txt = "6P Ring Game"
	if state != INIT:
		txt += " " + stateText[state]
	$TitleBar/Label.text = txt
func update_d_SB_BB():
	for i in range(players.size()):
		var mk = players[i].get_node("Mark")
		mk.show()
		if dealer_ix == i:
			mk.frame = DEALER
		elif (dealer_ix + 1) % players.size() == i:
			mk.frame = SB
		elif (dealer_ix + 2) % players.size() == i:
			mk.frame = BB
		else:
			mk.hide()
			
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
	for i in range(nPlayers):
		players_card1.push_back(deck[ix])
		#var st : int = deck[ix] >> N_RANK_BITS
		#var rank : int = deck[ix] & RANK_MASK
		var st : int = card_to_suit(deck[ix])
		var rank : int = card_to_rank(deck[ix])
		ix += 1
		players[i].set_card1(st, rank)
	players_card2 = []
	for i in range(nPlayers):
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
func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		if n_moving != 0: return;		# カード移動中
		if state == INIT:
			state = PRE_FLOP
			shuffle_cards()
			n_moving = nPlayers * 2		# 各プレイヤーにカードを２枚配布
			#players_cards.resize(nPlayers * 2)
			players_card1.resize(nPlayers)
			for i in range(nPlayers):
				var cd = CardBF.instance()		# カード裏面
				players_card1[i] = cd
				cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
				deck_ix += 1
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				#players[i].get_node("CardParent").add_child(cd)
				cd.connect("move_finished", self, "move_finished")
				cd.connect("open_finished", self, "open_finished")
				var dst = players[i].get_position() + Vector2(-CARD_WIDTH/2, -4)
				cd.wait_move_to(i * 0.1, dst, 0.3)
			players_card2.resize(nPlayers)
			for i in range(nPlayers):
				var cd = CardBF.instance()
				players_card2[i] = cd
				cd.set_sr(card_to_suit(deck[deck_ix]), card_to_rank(deck[deck_ix]))
				deck_ix += 1
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				cd.connect("move_finished", self, "move_finished")
				cd.connect("open_finished", self, "open_finished")
				var dst = players[i].get_position() + Vector2(CARD_WIDTH/2, -4)
				cd.wait_move_to((nPlayers + i) * 0.1, dst, 0.3)
			action_panels.resize(nPlayers)
			for i in range(nPlayers):
				var ap = ActionPanel.instance()
				action_panels[i] = ap
				ap.hide()
				ap.set_position(players[i].position - ap.rect_size/2)
				$Table.add_child(ap)
			print(action_panels[0].rect_size)
		elif state == PRE_FLOP:
			#deal_cards()
			state = FLOP
			comu_cards = []
			n_moving = N_FLOP_CARDS		# 3 for FLOP
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
			n_opening = (nPlayers - 1)*2
			for i in range(1, nPlayers):
				players_card1[i].do_open()
				players_card2[i].do_open()
			pass
		elif state == SHOW_DOWN:
			state = INIT
			dealer_ix = (dealer_ix + 1) % players.size()
			update_d_SB_BB()
			for i in range(nPlayers):
				players_card1[i].queue_free()
				players_card2[i].queue_free()
				players[i].set_hand("")
				action_panels[i].queue_free()
			for i in range(comu_cards.size()):
				comu_cards[i].queue_free()
		update_title_text()
func move_finished():
	n_moving -= 1
	if n_moving == 0:
		print("move_finished")
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
func open_finished():
	n_opening -= 1
	print(n_opening)
	if n_opening == 0:
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

func _process(delta):
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
	for i in range(nPlayers):
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
			for i in range(nPlayers):
				var v = []
				v.push_back(players_card1[i])
				v.push_back(players_card2[i])
				for k in range(5): v.push_back(comu_cards[k].get_sr())
				print("v = ", v)
				print("hand = ", handName[check_hand(v)])
				players[i].set_hand(handName[check_hand(v)])
	pass
