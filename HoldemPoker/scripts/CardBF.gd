extends Node2D

signal open_finished
signal move_finished

const OPENING_NONE = 0
const OPENING_FH = 1	# 蜑榊濠
const OPENING_SH = 2	# 蠕悟濠
const TH_SCALE = 1.5
const RANK_10 = 10 - 2
const NumTable = "234567890JQKA"
const N_RANK_BITS = 4

var sr = 0		# (suit << 4) | rank
var opening : int = 0
var theta = 0.0
var moving = false
var waiting_time = 0.0			# ウェイト時間（単位：秒）
#var wait_elapsed = 0.0			# ウェイト経過時間（単位：秒）
var move_dur = 0.0				# 移動所要時間（単位：秒）
var move_elapsed = 0.0			# 移動経過時間（単位：秒）
var src_pos = Vector2(0, 0)
var dst_pos = Vector2(0, 0)

func _ready():
	$Back.show()
	$Front.hide()
	pass
func get_sr():
	return sr
func set_suit(st):
	$Front/Suit.set_frame(st)
func set_rank(rank):
	if rank == RANK_10:
		$Front/Label.text = "10"
	else:
		$Front/Label.text = NumTable[rank]
func set_sr(st, rank):
	sr = (st << N_RANK_BITS) | rank
	set_suit(st)
	set_rank(rank)
func wait_move_to(wait : float, dst : Vector2, dur : float):
	waiting_time = wait
	#wait_elapsed = 0.0
	move_to(dst, dur)
func move_to(dst : Vector2, dur : float):
	src_pos = get_position()
	dst_pos = dst
	move_dur = dur
	move_elapsed = 0.0
	moving = true
	pass
func set_open():
	$Front.show()
	$Back.hide()
func do_open():
	opening = OPENING_FH
	theta = 0.0
	$Front.hide()
	$Back.show()
	$Back.set_scale(Vector2(1.0, 1.0))
func _process(delta):
	if waiting_time > 0.0:
		waiting_time -= delta
		return
	if moving:		# 移動処理中
		move_elapsed += delta	# 経過時間
		move_elapsed = min(move_elapsed, move_dur)	# 行き過ぎ防止
		var r = move_elapsed / move_dur				# 位置割合
		set_position(src_pos * (1.0 - r) + dst_pos * r)		# 位置更新
		if move_elapsed == move_dur:		# 移動終了の場合
			moving = false
			emit_signal("move_finished")	# 移動終了シグナル発行
	if opening == OPENING_FH:
		theta += delta * TH_SCALE
		if theta < PI/2:
			$Back.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_SH
			$Front.show()
			$Back.hide()
			theta -= PI
			$Front.set_scale(Vector2(cos(theta), 1.0))
	elif opening == OPENING_SH:
		theta += delta * TH_SCALE
		theta = min(theta, 0)
		if theta < 0:
			$Front.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_NONE
			$Front.set_scale(Vector2(1.0, 1.0))
			emit_signal("open_finished")
	pass
