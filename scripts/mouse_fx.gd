class_name MouseFX
extends Node2D
## 老鼠偷蛋特效：从屏幕一侧跑向鸡窝，再叼着蛋跑回（对应策划文档第 6.3 / 8 节）。

const DURATION := 1.1

var _elapsed := 0.0
var _start_pos := Vector2.ZERO
var _end_pos := Vector2.ZERO
var _scale := 1.0


func setup(from_left: bool, target_pos: Vector2, big: bool = false) -> void:
	_scale = 1.35 if big else 1.0
	_start_pos = Vector2(-80.0 if from_left else 2000.0, target_pos.y)
	_end_pos = target_pos + Vector2(-60.0 if from_left else 60.0, -6.0)
	position = _start_pos


func _process(delta: float) -> void:
	_elapsed += delta
	var k := clampf(_elapsed / DURATION, 0.0, 1.0)
	# sin 曲线：去程 0→1，回程 1→0（老鼠跑进又跑出）
	var travel := sin(PI * k)
	position = _start_pos.lerp(_end_pos, travel)
	queue_redraw()
	if _elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var body := Color(0.62, 0.62, 0.68)
	var belly := Color(0.80, 0.80, 0.85)
	var ear := Color(0.90, 0.72, 0.72)
	var s := _scale
	# 身体
	draw_circle(Vector2(0, 0), 20 * s, body)
	# 肚皮
	draw_circle(Vector2(0, 4 * s), 13 * s, belly)
	# 头
	draw_circle(Vector2(16 * s, -4 * s), 13 * s, body)
	# 耳朵
	draw_circle(Vector2(14 * s, -16 * s), 8 * s, ear)
	draw_circle(Vector2(24 * s, -14 * s), 8 * s, ear)
	# 眼睛
	draw_circle(Vector2(20 * s, -6 * s), 2.4 * s, Color.BLACK)
	# 鼻子
	draw_circle(Vector2(28 * s, -1 * s), 2.2 * s, Color(0.9, 0.5, 0.55))
	# 尾巴
	var points := PackedVector2Array([
		Vector2(-16 * s, 2 * s),
		Vector2(-40 * s, -14 * s),
		Vector2(-52 * s, 6 * s),
	])
	draw_polyline(points, body.darkened(0.2), 3.0 * s)
