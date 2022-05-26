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
const N_PLAYERS = 2				# プレイヤー人数（2 for ヘッズ・アップ）
const ANTE_CHIPS = 1
const BET_CHIPS = 1				# 1chip のみベット可能
const USER_IX = 0
const AI_IX = 1

var state = INIT
var waiting = 0.0		# 0超ならウェイト状態 → 次のプレイヤーに手番を移動
#var sub_state = READY
var balance
var n_hands = 1			# 何ハンド目か
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
#var round_bet_chips_plyr = []		# 各プレイヤー現ラウンドのベットチップ数合計

onready var g = get_node("/root/Global")

var CardBF = load("res://CardBF.tscn")		# カード裏表面
var Chip = load("res://Chip.tscn")			# 移動可能チップ
var ActionPanel = load("res://ActionPanel.tscn")

var rng = RandomNumberGenerator.new()

func _ready():
	pass # Replace with function body.


func _on_BackButton_pressed():
	get_tree().change_scene("res://TopScene.tscn")
	pass # Replace with function body.
