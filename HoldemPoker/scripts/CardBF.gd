extends Node2D

signal opening_finished
signal closing_finished
signal moving_finished
enum {		# state
	STATE_NONE = 0,
	OPENING_FH,			# オープン中 前半
	OPENING_SH,			# オープン中 後半
	CLOSING_FH,			# オープン中 前半
	CLOSING_SH,			# オープン中 後半
}
#const STATE_NONE = 0
#const OPENING_FH = 1	# オープン中 前半
#const OPENING_SH = 2	# オープン中 後半
#const CLOSING_FH = 3	# オープン中 前半
#const CLOSING_SH = 4	# オープン中 後半
const TH_SCALE = 1.5
const RANK_10 = 10 - 2
const NumTable = "234567890JQKA"
const N_RANK_BITS = 4

var sr = 0		# (suit << 4) | rank
var rank = 0
var bFront = false				# 表示面
var state : int = 0
var theta = 0.0
var moving = false
var waiting_time = 0.0			# ウェイト時間（単位：秒）
#var wait_elapsed = 0.0			# ウェイト経過時間（単位：秒）
var move_dur = 0.0				# 移動所要時間（単位：秒）
var move_elapsed = 0.0			# 移動経過時間（単位：秒）
var src_pos = Vector2(0, 0)
var dst_pos = Vector2(0, 0)

func _ready():
	#print("_ready()")
	if bFront:
		$Front.show()
		$Back.hide()
	else:
		$Back.show()
		$Front.hide()
	pass
func get_sr():
	return sr
func set_suit(st):
	$Front/Suit.set_frame(st)
func get_rank(): return rank
func set_rank(r):
	rank = r
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
func show_front():
	#print("show_front()")
	bFront = true
	$Front.show()
	$Back.hide()
func do_open():
	state = OPENING_FH
	theta = 0.0
	$Front.hide()
	$Back.show()
	$Back.set_scale(Vector2(1.0, 1.0))
func do_wait_close(wait : float):
	waiting_time = wait
	do_close()
func do_close():
	state = CLOSING_FH
	theta = 0.0
	$Back.hide()
	$Front.show()
	$Front.set_scale(Vector2(1.0, 1.0))
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
			emit_signal("moving_finished")	# 移動終了シグナル発行
	#if state != STATE_NONE:
	#	print("state = ", state)
	if state == OPENING_FH:
		theta += delta * TH_SCALE
		if theta < PI/2:
			$Back.set_scale(Vector2(cos(theta), 1.0))
		else:
			state = OPENING_SH
			$Front.show()
			$Back.hide()
			theta -= PI
			$Front.set_scale(Vector2(cos(theta), 1.0))
	elif state == OPENING_SH:
		theta += delta * TH_SCALE
		theta = min(theta, 0)
		if theta < 0:
			$Front.set_scale(Vector2(cos(theta), 1.0))
		else:
			state = STATE_NONE
			$Front.set_scale(Vector2(1.0, 1.0))
			emit_signal("opening_finished")
	elif state == CLOSING_FH:
		theta += delta * TH_SCALE * 1.5
		if theta < PI/2:
			$Front.set_scale(Vector2(cos(theta), 1.0))
		else:
			state = CLOSING_SH
			$Back.show()
			$Front.hide()
			theta -= PI
			$Back.set_scale(Vector2(cos(theta), 1.0))
	elif state == CLOSING_SH:
		theta += delta * TH_SCALE * 1.5
		theta = min(theta, 0)
		if theta < 0:
			$Back.set_scale(Vector2(cos(theta), 1.0))
		else:
			state = STATE_NONE
			$Back.set_scale(Vector2(1.0, 1.0))
			emit_signal("closing_finished")
	pass
