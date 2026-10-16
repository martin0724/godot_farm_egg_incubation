class_name FloatText
extends Label
## 飘字特效：向上浮动并淡出，随后自毁（对应策划文档第 6.3 / 8 节）。

const LIFETIME := 1.1
const RISE_SPEED := 70.0

var _age := 0.0
var _rise := RISE_SPEED


func setup(txt: String, col: Color, font: Font) -> void:
	text = txt
	add_theme_color_override("font_color", col)
	if font != null:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 34)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = col
	# 让文字在给定坐标处居中
	pivot_offset = Vector2.ZERO


func _process(delta: float) -> void:
	_age += delta
	position.y -= _rise * delta
	_rise = lerpf(_rise, 10.0, delta * 2.0)
	modulate.a = clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
