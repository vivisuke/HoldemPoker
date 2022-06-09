extends Node2D

enum {
	CLUBS = 0, DIAMONDS, HEARTS, SPADES, N_SUIT,
	RANK_BLANK = -1,
	RANK_2 = 0, RANK_3, RANK_4, RANK_5, RANK_6,
	RANK_7, RANK_8, RANK_9, RANK_10,
	RANK_J, RANK_Q, RANK_K, RANK_A, N_RANK,
}
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
const N_PLAYOUT = 5000			# 期待勝率計算 モンテカルロ法試行回数
const RANK_STR = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"]
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
#var players_card = []		# プレイヤーに配
var act_panels = []			# プレイヤーアクション表示パネル
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
	nix = (dealer_ix + 1) % N_PLAYERS
	print("dealer_ix = ", dealer_ix, ", nix = ", nix)
	# 行動パネル
	TABLE_CENTER = $Table.position
	act_panels.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		var ap = ActionPanel.instance()
		act_panels[i] = ap
		ap.hide()
		ap.set_position(TABLE_CENTER + players[i].position - ap.rect_size/2)
		add_child(ap)
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
		elif state == SHOW_DOWN:
			next_hand()
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
		elif state == OPENING_COMU:		# 共有カードオープン終了
			state = SEL_ACTION
			show_hand_name(HUMAN_IX)
			#update_players_BG()
			emphasize_next_player()
		elif state == SHOW_DOWN:
			print("SHOW_DOWN > on_opening_finished()")
			emphasize_next_player()
			for i in range(1, N_PLAYERS):	# 人間以外の手役名表示
				if !is_folded[i]:
					show_hand_name(i)
			determine_who_won()
			#if players_card[HUMAN_IX].get_rank() > players_card[AI_IX].get_rank():
			#	print("User won")
			#	winner_ix = HUMAN_IX		# 勝者
			#	loser_ix = AI_IX
			#else:
			#	print("AI won")
			#	winner_ix = AI_IX
			#	loser_ix = HUMAN_IX		# 敗者
			# undone: AI 手役表示
			settle_chips()
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
	n_moving = 0
	for i in range(comu_cards.size()):
		comu_cards[i].connect("moving_finished", self, "on_moving_finished")
		comu_cards[i].move_to(deck_pos, 0.2)
		n_moving += 1
	for i in range(N_PLAYERS):
		if !is_folded[i]:
			players_card1[i].move_to(deck_pos, 0.2)
			players_card2[i].move_to(deck_pos, 0.2)
			n_moving += 2
	
	##n_moving = cards.size()
	##for i in range(cards.size()):
	##	cards[i].connect("moving_finished", self, "on_moving_finished")
	##	cards[i].move_to(TABLE_CENTER, 0.2)
	##	#cards[i].move_to(TABLE_CENTER + Vector2(CARD_WIDTH/2*(i-1), 0), 0.3)
	pass
func on_closing_finished():
	n_closing -= 1
	if n_closing == 0:
		collect_cards_to_the_deck()		# カードを中央デッキに集める
	
func show_hand_name(pix):
	if is_folded[pix]: return
	calc_players_hand(pix)
	players[pix].set_hand(handName[players_hand[pix][0]])
func calc_players_hand(pix):
	if is_folded[pix]: return
	var v = []
	v.push_back(players_card1[pix].get_sr())
	v.push_back(players_card2[pix].get_sr())
	for k in range(N_COMU_CARS): v.push_back(comu_cards[k].get_sr())
	players_hand[pix] = check_hand(v)
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
# 勝者判定
# 前提：calc_players_hand() がすでにコールされ、players_hand[] が設定済みとする
func determine_who_won():
	winner_ix = HUMAN_IX
	var h = players_hand[HUMAN_IX]
	for i in range(1, N_PLAYERS):
		if !is_folded[i] && compare(players_hand[i], h) > 0:
			h = players_hand[i]
			winner_ix = i
func emphasize_next_player():		# 次の手番のプレイヤー背景上部を黄色強調
	print("nix = ", nix)
	if nix == HUMAN_IX:
		enable_act_buttons()
	for i in range(N_PLAYERS):
		if is_folded[i]:
			players[i].set_BG(BG_FOLDED)
		else:
			players[i].set_BG(BG_PLY if state == SEL_ACTION && i == nix else BG_WAIT)
func do_wait():
	waiting = 0.5		# 0.5秒ウェイト
func _process(delta):
	#if state == SHOW_DOWN:	#|| state == ROUND_FINISHED:
	#	return
	if waiting > 0.0:		# 行動後のウェイト状態の場合
		waiting -= delta
		if sec_to_trans != 0:
			var sec : int = ceil(waiting)
			if sec < sec_to_trans:
				sec_to_trans = sec
				$NextButton.text = "Next %d" % sec
		if waiting <= 0.0:	# ウェイト終了
			if state != SHOW_DOWN:
				next_player()	# 次のプレイヤーに手番を移動
			else:
				close_and_collect_cards()
				#next_hand()
		return
	if state == SEL_ACTION && nix != HUMAN_IX:		# AI の手番
		print("AI is thinking...")
		do_act_AI()
		#
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
	var n_playout = N_PLAYOUT	#if !is_folded[HUMAN_IX] else N_PLAYOUT2
	for nt in range(n_playout):
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
	return wsum / n_playout
func do_act_AI():
	print("act_history = ", act_history)
	var hist = act_history
	if n_raised == 0:
		hist = hist.replace("f", "c")
		print("act_history = ", act_history)
	var wr = calc_win_rate(nix, N_PLAYERS-1)
	print("win rate = ", wr)
	var rnk = min(int(wr * 5), 4)			#	[0, 4]
	#var rnk = players_card1[nix].get_rank()		# 暫定コード
	print("rank = ", rnk)
	var key = "TJQKA"[rnk] + hist
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
	print("*** checked")
	act_history += "c"
	set_act_panel_text(pix, "checked", Color.lightgray)
	do_wait()
func do_call(pix):
	print("*** called")
	act_history += "C"
	set_act_panel_text(pix, "called", Color.lightgray)
	players[pix].sub_chips(BET_CHIPS)
	bet_chips_plyr[pix] += BET_CHIPS
	players[pix].set_bet_chips(bet_chips_plyr[pix])
	do_wait()
func do_raise(pix):
	print("*** raised")
	act_history += "R"
	n_raised += 1
	update_n_raised_label()
	players[pix].sub_chips(BET_CHIPS)
	bet_chips_plyr[pix] += BET_CHIPS
	players[pix].set_bet_chips(bet_chips_plyr[pix])
	set_act_panel_text(pix, "raised", Color.pink)
	do_wait()
func do_fold(pix):
	print("*** folded")
	act_history += "F"
	players[pix].set_hand("")
	is_folded[pix] = true
	n_act_players -= 1
	set_act_panel_text(pix, "folded", Color.darkgray)
	next_player()
	if pix == HUMAN_IX:
		players_card1[pix].show_back()
		players_card2[pix].show_back()
	players_card1[pix].move_to(deck_pos, 0.2)		# カードを中央に移動
	players_card2[pix].move_to(deck_pos, 0.2)		# カードを中央に移動
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
		for i in range(1, N_PLAYERS):	# 人間以外の手役名表示
			if !is_folded[i]:
				calc_players_hand(i)
				#show_hand_name(i)
		determine_who_won();
		#settle_chips()
		#else:						# AI が残っている場合
		n_opening = 0;
		for i in range(N_PLAYERS):
			act_panels[i].hide()		# アクションパネル非表示
			if i != HUMAN_IX && !is_folded[i] && n_act_players > 1:
				n_opening += 2
				players_card1[i].connect("opening_finished", self, "on_opening_finished")
				players_card1[i].do_open()
				players_card2[i].connect("opening_finished", self, "on_opening_finished")
				players_card2[i].do_open()
		#do_show_down()
		if n_opening == 0:		# 全AIがフォールドしている場合
			settle_chips()
		waiting = 6.0
		sec_to_trans = int(waiting)
		$NextButton.text = "Next %d" % sec_to_trans
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
func close_and_collect_cards():
	$NextButton.disabled = true		# Next ボタンディセーブル
	n_closing = 0
	for i in range(comu_cards.size()):
		comu_cards[i].connect("closing_finished", self, "on_closing_finished")
		comu_cards[i].do_close()
		n_closing += 1
	if n_act_players > 1:	# 一人以外降りた場合はカードをオープンしていない
		for i in range(N_PLAYERS):
			if !is_folded[i]:
				players_card1[i].connect("closing_finished", self, "on_closing_finished")
				players_card1[i].do_close()
				players_card2[i].connect("closing_finished", self, "on_closing_finished")
				players_card2[i].do_close()
				n_closing += 2
				players[i].set_hand("")

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
	#else:
	#	collect_cards_to_the_deck()
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
	dealing_cards_animation()
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
		waiting = 0.0
		close_and_collect_cards()
		#next_hand()
