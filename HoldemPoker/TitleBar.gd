extends ColorRect

const RADIUS = 5

func _draw():
	var style_box = StyleBoxFlat.new()      # 影、ボーダなどを描画するための矩形スタイルオブジェクト
	style_box.bg_color = color   # 矩形背景色
	style_box.border_color = Color.green
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(RADIUS)
	style_box.shadow_offset = Vector2(0, 4)     # 影オフセット
	style_box.shadow_size = 8                   # 影（ぼかし）サイズ
	draw_style_box(style_box, Rect2(Vector2(0, 0), self.rect_size))      # style_box に設定した矩形を描画

func _ready():
	pass # Replace with function body.
