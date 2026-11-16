class_name MouseFX
extends Node2D
## 老鼠偷蛋特效（对应策划文档第 6.3 / 8 节）。
## 慢速潜行 → 东张西望 → 抱蛋 → 转身溜走，动作带小偷式的踮脚和探头。

const SNEAK_IN := 1.35       # 从画面外慢慢潜入
const LOOK_AROUND := 0.55    # 到鸡窝边探头张望
const GRAB := 0.30           # 抱起鸡蛋
const ESCAPE := 1.25         # 抱着蛋溜出画面
const TOTAL_DURATION := SNEAK_IN + LOOK_AROUND + GRAB + ESCAPE

const COLOR_BODY := Color(0.60, 0.60, 0.66)
const COLOR_BELLY := Color(0.80, 0.80, 0.85)
const COLOR_EAR := Color(0.92, 0.74, 0.74)
const COLOR_MASK := Color(0.10, 0.10, 0.14)
const COLOR_EGG := Color(1.0, 0.99, 0.94)
const COLOR_EGG_SHADOW := Color(0.82, 0.78, 0.68)

var _elapsed := 0.0
var _from_left := true
var _start_pos := Vector2.ZERO
var _nest_pos := Vector2.ZERO
var _exit_pos := Vector2.ZERO
var _scale := 1.0
var _facing := 1.0
var _look := 0.0
var _crouch := 0.0
var _carrying := false
var _bob := 0.0


func setup(from_left: bool, target_pos: Vector2, big: bool = false,
		nest_radius: float = 60.0) -> void:
	_from_left = from_left
	_scale = 1.25 if big else 1.0
	_facing = 1.0 if from_left else -1.0
	var vp_w := get_viewport_rect().size.x
	_start_pos = Vector2(-90.0 if from_left else vp_w + 90.0, target_pos.y)
	# 停在鸡窝外沿，伸爪刚好够到鸡蛋
	var approach := nest_radius + 20.0
	_nest_pos = target_pos + Vector2(-approach if from_left else approach, 0.0)
	_exit_pos = _start_pos
	position = _start_pos


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed
	_look = 0.0
	_crouch = 0.0
	_carrying = false
	_bob = 0.0
	# 潜入 / 张望 / 抱蛋时面向鸡窝，逃跑时转身向外
	_facing = 1.0 if _from_left else -1.0

	if t < SNEAK_IN:
		# 踮脚潜行：一快一慢地靠近，身体轻轻起伏
		var k := t / SNEAK_IN
		var e := k - 0.10 * sin(TAU * 2.0 * k)
		position = _start_pos.lerp(_nest_pos, e)
		_bob = sin(k * TAU * 5.0) * 3.0 * _scale
		_look = sin(k * TAU * 1.2) * 0.35
		_crouch = 0.35
	elif t < SNEAK_IN + LOOK_AROUND:
		# 停在窝边左右探头，确认没人
		var k := (t - SNEAK_IN) / LOOK_AROUND
		position = _nest_pos + Vector2(0, sin(_elapsed * 6.0) * 1.5)
		_look = sin(k * TAU * 1.5) * 0.9
		_crouch = 0.5
	elif t < SNEAK_IN + LOOK_AROUND + GRAB:
		# 猛地探身抱起鸡蛋
		var k := (t - SNEAK_IN - LOOK_AROUND) / GRAB
		var lunge := sin(k * PI) * 12.0
		position = _nest_pos + Vector2(lunge * _facing, -lunge * 0.25)
		_look = 0.6
		_crouch = 0.8
		_carrying = k > 0.55
	else:
		# 抱起蛋转身溜走，一颠一颠地跑出画面
		var k := (t - SNEAK_IN - LOOK_AROUND - GRAB) / ESCAPE
		var e := smoothstep(0.0, 1.0, k)
		position = _nest_pos.lerp(_exit_pos, e)
		_facing = -1.0 if _from_left else 1.0
		_crouch = 0.25
		_bob = absf(sin(k * TAU * 3.0)) * 6.0 * _scale
		_carrying = true

	rotation = _look * 0.06
	position.y += _bob
	queue_redraw()
	if _elapsed >= TOTAL_DURATION:
		queue_free()


# ——————————————————————————————————————————————
# 绘制（原点为身体中心）
# ——————————————————————————————————————————————

func _draw() -> void:
	var s := _scale
	var f := _facing
	var body_rx := (22.0 + 3.0 * _crouch) * s
	var body_ry := (15.0 - 4.0 * _crouch) * s

	# 地面影子
	_draw_ellipse(Vector2(0, 15 * s), 24 * s, 6 * s, Color(0, 0, 0, 0.18))

	# 尾巴：来回摆动
	var wag := sin(_elapsed * 9.0) * 7.0 * s
	var tail := PackedVector2Array([
		Vector2(-16 * f * s, 1 * s),
		Vector2(-34 * f * s, -10 * s + wag),
		Vector2(-50 * f * s, 8 * s + wag * 0.6),
	])
	draw_polyline(tail, COLOR_BODY.darkened(0.25), 3.2 * s, true)

	# 踮着脚的小腿
	var step := sin(_elapsed * 12.0) * 3.0 * s
	draw_line(Vector2(-8 * f * s + step, 10 * s), Vector2(-10 * f * s + step, 19 * s),
		COLOR_BODY.darkened(0.2), 3.0 * s, true)
	draw_line(Vector2(8 * f * s - step, 10 * s), Vector2(10 * f * s - step, 19 * s),
		COLOR_BODY.darkened(0.2), 3.0 * s, true)

	# 身体与肚皮
	_draw_ellipse(Vector2(0, 0), body_rx, body_ry, COLOR_BODY)
	_draw_ellipse(Vector2(3 * f * s, 4 * s), body_rx * 0.65, body_ry * 0.6, COLOR_BELLY)

	# 头（张望时左右轻微移动）
	var head := Vector2(18 * f * s + _look * 3 * s * f, (-7.0 - 2.0 * _crouch) * s)
	# 耳朵
	var ear_a := head + Vector2(-7 * f * s, -10 * s)
	var ear_b := head + Vector2(3 * f * s, -12 * s)
	_draw_ellipse(ear_a, 7.5 * s, 7.5 * s, COLOR_EAR)
	_draw_ellipse(ear_a, 4.0 * s, 4.0 * s, COLOR_EAR.darkened(0.15))
	_draw_ellipse(ear_b, 7.5 * s, 7.5 * s, COLOR_EAR)
	_draw_ellipse(ear_b, 4.0 * s, 4.0 * s, COLOR_EAR.darkened(0.15))
	_draw_ellipse(head, 12 * s, 11 * s, COLOR_BODY)

	# 小偷面罩 + 眼睛
	_draw_ellipse(head + Vector2(2 * f * s, -1 * s), 10 * s, 4.2 * s, COLOR_MASK)
	draw_circle(head + Vector2(2 * f * s, -1 * s), 2.5 * s, Color.WHITE)
	draw_circle(head + Vector2(5.5 * f * s, -1 * s), 1.3 * s, Color.BLACK)
	# 鼻子与胡须
	draw_circle(head + Vector2(11 * f * s, 4 * s), 2.2 * s, Color(0.88, 0.45, 0.5))
	draw_line(head + Vector2(10 * f * s, 4 * s), head + Vector2(20 * f * s, 1 * s),
		COLOR_BODY.darkened(0.4), 1.2 * s, true)
	draw_line(head + Vector2(10 * f * s, 5 * s), head + Vector2(20 * f * s, 8 * s),
		COLOR_BODY.darkened(0.4), 1.2 * s, true)

	if _carrying:
		# 抱在胸前的鸡蛋
		var egg_c := Vector2(24 * f * s, 8 * s)
		_draw_ellipse(egg_c + Vector2(0, 2 * s), 7.5 * s, 9.5 * s, COLOR_EGG_SHADOW)
		_draw_ellipse(egg_c, 7.0 * s, 9.0 * s, COLOR_EGG)
		draw_line(head + Vector2(6 * f * s, 7 * s), egg_c + Vector2(-4 * f * s, 0),
			COLOR_BODY.darkened(0.15), 3.0 * s, true)
		draw_line(head + Vector2(4 * f * s, 9 * s), egg_c + Vector2(4 * f * s, 2 * s),
			COLOR_BODY.darkened(0.15), 3.0 * s, true)
	else:
		# 小偷式伸出的前爪
		draw_line(head + Vector2(4 * f * s, 8 * s), head + Vector2(12 * f * s, 12 * s),
			COLOR_BODY.darkened(0.15), 3.0 * s, true)


func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, points: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
