extends Node2D

#enum { CLUB = 0, DIAMOND, HEART, SPADE, }
enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
#const N_SUIT = 4
#const N_RANK = 13
const N_CARDS = N_RANK*N_SUIT
const N_COMU_CARS = 5			# 共通カード枚数
const RANK_MASK = 0x0f
const N_RANK_BITS = 4

var deck = []			# 要素：(suit << 4) | rank
var comu_cards = []		# コミュニティカード
var players = []		# プレイヤーパネル配列、[0] for Human
var nPlayers = 6		# 6 players

func _ready():
	randomize()
	#
	players = []
	for i in range(nPlayers):
		var pb = get_node("Table/PlayerBG%d" % (i+1))
		players.push_back(pb)
	for i in range(N_COMU_CARS):
		var cd = get_node("Table/Card%d" % (i+1))
		comu_cards.push_back(cd)
	#
	$Table/PlayerBG1.set_name("vivisuke")
	#Table/$PlayerBG1.set_card1(SPADES, RANK_A)
	#$Table/PlayerBG1.set_card2(SPADES, RANK_K)
	$Table/PlayerBG1.set_BG(1)
	$Table/PlayerBG2.set_BG(2)
	#
	#$Table/Card1.set_sr(CLUBS, RANK_A)
	#$Table/Card2.set_sr(DIAMONDS, RANK_5)
	#$Table/Card3.set_sr(HEARTS, RANK_10)
	#$Table/Card4.set_sr(SPADES, RANK_Q)
	#$Table/Card5.set_sr(HEARTS, RANK_K)
	#
	#$PlayerBG1.open_cards()
	pass

func deal_cards():
	# デッキカードシャフル
	deck.resize(N_CARDS)
	for i in range(N_CARDS):
		var st : int = i / N_RANK
		var rank : int = i % N_RANK
		deck[i] = (st<<N_RANK_BITS) | rank
	deck.shuffle()
	#
	# 各プレイヤーにカード配布
	var ix = 0
	for i in range(nPlayers):
		var st : int = deck[ix] >> N_RANK_BITS
		var rank : int = deck[ix] & RANK_MASK
		ix += 1
		players[i].set_card1(st, rank)
	for i in range(nPlayers):
		var st : int = deck[ix] >> N_RANK_BITS
		var rank : int = deck[ix] & RANK_MASK
		ix += 1
		players[i].set_card2(st, rank)
	#
	# 共通カード配布
	for i in range(N_COMU_CARS):
		var st : int = deck[ix] >> N_RANK_BITS
		var rank : int = deck[ix] & RANK_MASK
		ix += 1
		comu_cards[i].set_sr(st, rank)
	#
func _input(event):
	if event is InputEventMouseButton:
		deal_cards()
		#$PlayerBG1.open_cards()
		for i in range(nPlayers):
			players[i].open_cards()

func _process(delta):
	pass
