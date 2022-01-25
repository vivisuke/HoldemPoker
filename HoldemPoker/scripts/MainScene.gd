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
	REVER,
	
}
#const N_SUIT = 4
#const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4
const CARD_WIDTH = 40
const COMU_CARD_PY = 80
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
var deck = []			# 要素：(suit << 4) | rank
var comu_cards = []		# コミュニティカード
var players = []		# プレイヤーパネル配列、[0] for Human
#var players_cards = []		# プレイヤーカード、[0], [1] for Player-1, ...
var players_card1 = []		#
var players_card2 = []		#
var nPlayers = 6		# 6 players
var n_moving = 0
var n_opening = 0
var deck_pos

var CardBF = load("res://CardBF.tscn")

func _ready():
	randomize()
	#seed(0)
	#
	deck_pos = $Table/CardDeck.get_position()
	players = []
	for i in range(nPlayers):
		var pb = get_node("Table/PlayerBG%d" % (i+1))
		pb.set_chips(200)
		players.push_back(pb)
	#for i in range(N_COMU_CARS):
	#	var cd = get_node("Table/CardBF%d" % (i+1))
	#	comu_cards.push_back(cd)
	#
	$Table/PlayerBG1.set_name("vivisuke")
	#Table/$PlayerBG1.set_card1(SPADES, RANK_A)
	#$Table/PlayerBG1.set_card2(SPADES, RANK_K)
	$Table/PlayerBG1.set_BG(1)
	#$Table/PlayerBG2.set_BG(2)
	pass

func shuffle_cards():
	# デッキカードシャフル
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st : int = i / N_RANK
		var rank : int = i % N_RANK
		deck[i] = (st<<N_RANK_BITS) | rank
	deck.shuffle()
func deal_cards():
	shuffle_cards()
	#
	# 各プレイヤーにカード配布
	players_card1 = []
	var ix = 0
	for i in range(nPlayers):
		players_card1.push_back(deck[ix])
		var st : int = deck[ix] >> N_RANK_BITS
		var rank : int = deck[ix] & RANK_MASK
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
				var cd = CardBF.instance()
				players_card1[i] = cd
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				cd.connect("move_finished", self, "move_finished")
				var dst = players[i].get_position() + Vector2(-CARD_WIDTH/2, -4)
				cd.wait_move_to(i * 0.1, dst, 0.3)
			players_card2.resize(nPlayers)
			for i in range(nPlayers):
				var cd = CardBF.instance()
				players_card2[i] = cd
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				cd.connect("move_finished", self, "move_finished")
				var dst = players[i].get_position() + Vector2(CARD_WIDTH/2, -4)
				cd.wait_move_to((nPlayers + i) * 0.1, dst, 0.3)
		elif state == PRE_FLOP:
			#deal_cards()
			state = FLOP
			comu_cards = []
			n_moving = 3		# 3 for FLOP
			for i in range(n_moving):
				var cd = CardBF.instance()
				comu_cards.push_back(cd)
				cd.set_position(deck_pos)
				$Table.add_child(cd)
				cd.connect("move_finished", self, "move_finished")
				cd.move_to(Vector2((i-2)*CARD_WIDTH, COMU_CARD_PY), 0.3)
				
		#for i in range(nPlayers):
		#	players[i].set_hand("")
		#n_opening = nPlayers
		#for i in range(nPlayers):
		#	players[i].open_cards()
		#for i in range(N_COMU_CARS):
		#	comu_cards[i].do_open()
		#print(comu_cards[0].get_position())
		#comu_cards[0].do_move(Vector2(0, 0), 0.3)
func move_finished():
	n_moving -= 1
	if n_moving == 0:
		print("move_finished")
		if state == PRE_FLOP:
			players_card1[0].do_open()
			players_card2[0].do_open()
		elif state == FLOP:
			for i in range(3):		# 3 for FLOP
				comu_cards[i].do_open()

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
