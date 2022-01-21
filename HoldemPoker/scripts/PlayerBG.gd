extends Sprite

const OPENING_NONE = 0
const OPENING_FH = 1	# 前半
const OPENING_SH = 2	# 後半
const TH_SCALE = 1.5

#var opening : bool = false
var opening : int = 0
var theta = 0.0

func _ready():
	$Card1.hide()
	$Card2.hide()
	pass # Replace with function body.

func set_BG(id):
	set_frame(id)
func set_name(name : String):
	$NameLabel.text = name
func open_cards():
	#opening = true
	opening = OPENING_FH
	theta = 0.0
	$Card1.hide()
	$Card2.hide()
	$FaceDownCard1.show()
	$FaceDownCard2.show()
	$FaceDownCard1.set_scale(Vector2(1.0, 1.0))
	$FaceDownCard2.set_scale(Vector2(1.0, 1.0))
func _process(delta):
	if opening == OPENING_FH:
		theta += delta * TH_SCALE
		if theta < PI/2:
			#theta = min(theta, PI/2)
			$FaceDownCard1.set_scale(Vector2(cos(theta), 1.0))
			$FaceDownCard2.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_SH
			$Card1.show()
			$Card2.show()
			$FaceDownCard1.hide()
			$FaceDownCard2.hide()
			theta -= PI
			$Card1.set_scale(Vector2(cos(theta), 1.0))
			$Card2.set_scale(Vector2(cos(theta), 1.0))
	elif opening == OPENING_SH:
		theta += delta * TH_SCALE
		theta = min(theta, 0)
		if theta < 0:
			$Card1.set_scale(Vector2(cos(theta), 1.0))
			$Card2.set_scale(Vector2(cos(theta), 1.0))
		else:
			opening = OPENING_NONE
			$Card1.set_scale(Vector2(1.0, 1.0))
			$Card2.set_scale(Vector2(1.0, 1.0))
	pass
