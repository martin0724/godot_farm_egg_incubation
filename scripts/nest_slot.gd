class_name NestSlot
extends Control
## 单个鸡窝的视图（对应策划文档第 6.2 / 10.4 节）。
## 全部使用 `_draw()` 程序化绘制，无需外部贴图。
## 鸡窝采用稻草编织造型，直接平铺在背景草坪上，不使用卡片底板。

signal selected_slot(id: int)

const SLOT_SIZE := Vector2(230, 260)
const HEN_WALK_SECONDS := 1.5

# 稻草 / 母鸡 / 蛋 配色
const COLOR_STRAW_LIGHT := Color(0.96, 0.85, 0.53)
const COLOR_STRAW := Color(0.88, 0.71, 0.36)
const COLOR_STRAW_DARK := Color(0.68, 0.50, 0.22)
const COLOR_BOWL := Color(0.42, 0.29, 0.12)
const COLOR_HEN_BODY := Color(0.99, 0.97, 0.90)
const COLOR_HEN_WING := Color(0.90, 0.86, 0.76)
const COLOR_COMB := Color(0.90, 0.24, 0.24)
const COLOR_BEAK := Color(0.97, 0.62, 0.12)
const COLOR_EGG := Color(1.0, 0.99, 0.94)
const COLOR_EGG_SHADOW := Color(0.82, 0.78, 0.68)
const COLOR_CHICK := Color(1.0, 0.85, 0.22)

var player: PlayerState
var selected := false

var _time := 0.0
# 母鸡走出画面动画
var _hen_walk := 0.0          # 0 = 坐在窝里，1 = 已完全走出画面
var _hen_walk_phase := 0.0
var _hen_exit_dir := 0.0      # -1 向左 / +1 向右
var _hen_exit_dist := 0.0
var _hen_hold := 0.0          # 离座动画结束后继续保持出画面的秒数
var _hen_facing := 1.0


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func setup(p: PlayerState) -> void:
	player = p
	queue_redraw()


## 离座时调用：母鸡先走出画面，hold_seconds 秒后再自己走回鸡窝。
func hen_leave(hold_seconds: float = 0.0) -> void:
	_hen_hold = maxf(_hen_hold, hold_seconds)
	_ensure_exit_dir()


func _process(delta: float) -> void:
	_time += delta
	if player != null:
		_tick_hen(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		selected_slot.emit(player.id)
		accept_event()


# ——————————————————————————————————————————————
# 母鸡离窝动画
# ——————————————————————————————————————————————

func _tick_hen(delta: float) -> void:
	if _hen_hold > 0.0:
		_hen_hold = maxf(0.0, _hen_hold - delta)
	var want_out := _hen_hold > 0.0 \
		or player.status == PlayerState.PlayerStatus.PAUSED \
		or player.status == PlayerState.PlayerStatus.HEN_LEFT
	if want_out:
		_ensure_exit_dir()

	var target := 1.0 if want_out else 0.0
	# 鸡头始终朝着行走方向：出画时朝外，回窝时朝鸡窝
	var step := target - _hen_walk
	if absf(step) > 0.001 and _hen_exit_dir != 0.0:
		_hen_facing = _hen_exit_dir * signf(step)
	if absf(step) > 0.001:
		_hen_walk_phase += delta * 13.0
	_hen_walk = move_toward(_hen_walk, target, delta / HEN_WALK_SECONDS)

	# 回到窝里后重置出口方向，下次离窝时重新选择最近的一侧
	if _hen_walk <= 0.001 and not want_out:
		_hen_exit_dir = 0.0
		_hen_facing = 1.0


## 选择离屏幕较近的一侧作为出口，并换算成鸡窝局部坐标距离。
func _ensure_exit_dir() -> void:
	if _hen_exit_dir != 0.0:
		return
	var r := get_global_rect()
	var vp := get_viewport_rect()
	_hen_exit_dir = -1.0 if r.get_center().x <= vp.size.x * 0.5 else 1.0
	var sc := maxf(r.size.x / maxf(size.x, 1.0), 0.01)
	var edge := -260.0 if _hen_exit_dir < 0.0 else vp.size.x + 260.0
	_hen_exit_dist = absf(edge - r.get_center().x) / sc
	_hen_facing = _hen_exit_dir


# ——————————————————————————————————————————————
# 绘制
# ——————————————————————————————————————————————

func _draw() -> void:
	if player == null:
		return
	var s := size
	var cx := s.x * 0.5
	var nest_c := Vector2(cx, s.y * 0.70)
	var nest_rx := s.x * 0.42
	var nest_ry := s.y * 0.115

	# 状态色柔和地铺在草坪上（不使用卡片底板，让鸡窝平铺在草地上）
	var tint := Color(0, 0, 0, 0)
	match player.status:
		PlayerState.PlayerStatus.FAILED:
			tint = Color(0.55, 0.15, 0.15, 0.22)
		PlayerState.PlayerStatus.COMPLETED:
			tint = Color(1.0, 0.85, 0.25, 0.22)
		PlayerState.PlayerStatus.PAUSED:
			tint = Color(0.95, 0.80, 0.20, 0.18)
		PlayerState.PlayerStatus.HEN_LEFT:
			tint = Color(0.45, 0.35, 0.10, 0.16)
	if tint.a > 0.0:
		_draw_ellipse(nest_c + Vector2(0, 10), nest_rx * 1.3, nest_ry * 1.8, tint)

	# 名称
	_draw_text_shadow(player.display_name, Vector2(12, 28), 22, Color(1, 1, 1, 0.96), false)
	# 状态角标（右对齐）
	var badge := player.status_label()
	if badge != "":
		var badge_font := get_theme_default_font()
		var badge_w := 0.0
		if badge_font != null:
			badge_w = badge_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_draw_text_shadow(badge, Vector2(s.x - 12 - badge_w, 28), 22, _status_color(), false)

	# 母鸡（离座 / 分心时走出画面）
	var hen_center := nest_c + Vector2(-4, -38) \
		+ Vector2(_hen_exit_dir * _hen_exit_dist * _hen_walk, 0)
	var hen_walking := _hen_walk > 0.001 and _hen_walk < 0.999
	_draw_hen(hen_center, 1.0, _hen_facing, hen_walking, _hen_walk_phase)

	# 稻草鸡窝（平铺在草地上）
	_draw_straw_nest(nest_c, nest_rx, nest_ry)

	# 窝里的蛋
	_draw_egg_row(nest_c + Vector2(0, -6), player.eggs)

	# 已孵出的小鸡（排在鸡窝前方）
	_draw_chick_row(Vector2(cx, s.y * 0.88), player.chicks)

	# 保护盾光罩
	if player.shield_active:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		_draw_ellipse(nest_c + Vector2(0, -8), nest_rx * 1.14, nest_ry * 2.0,
			Color(0.4, 0.75, 1.0, 0.14 + 0.14 * pulse))
		_draw_ellipse_outline(nest_c + Vector2(0, -8), nest_rx * 1.14, nest_ry * 2.0,
			Color(0.45, 0.80, 1.0, 0.55 + 0.30 * pulse), 3.0)

	# buff / shield 图标
	var icon_pos := Vector2(26, 58)
	if player.buff_active:
		_draw_ellipse(icon_pos, 14, 14, Color(0.30, 0.85, 0.40, 0.95))
		_draw_text("加", icon_pos + Vector2(0, 6), 18, Color.WHITE, true)
		icon_pos.y += 36
	if player.shield_active:
		_draw_ellipse(icon_pos, 14, 14, Color(0.35, 0.65, 1.0, 0.95))
		_draw_text("盾", icon_pos + Vector2(0, 6), 18, Color.WHITE, true)

	# 孵化进度条
	_draw_progress(Vector2(24, s.y - 20), s.x - 48, 12)

	# 选中高亮：贴着鸡窝画一圈金边
	if selected:
		var pulse := 0.65 + 0.35 * sin(_time * 5.0)
		_draw_ellipse_outline(nest_c, nest_rx * 1.12, nest_ry * 2.1,
			Color(1.0, 0.85, 0.20, pulse), 4.0)


func _draw_straw_nest(center: Vector2, rx: float, ry: float) -> void:
	# 草坪上的投影
	_draw_ellipse(center + Vector2(0, ry * 0.9), rx * 1.04, ry * 0.55,
		Color(0.16, 0.28, 0.09, 0.22))
	# 稻草堆外轮廓
	_draw_ellipse(center + Vector2(0, -ry * 0.05), rx, ry, COLOR_STRAW_DARK)
	_draw_ellipse(center + Vector2(0, -ry * 0.14), rx * 0.97, ry * 0.88, COLOR_STRAW)
	# 内凹的窝心
	_draw_ellipse(center + Vector2(0, -ry * 0.20), rx * 0.70, ry * 0.56,
		COLOR_STRAW_DARK.darkened(0.22))
	_draw_ellipse(center + Vector2(0, -ry * 0.14), rx * 0.60, ry * 0.44, COLOR_BOWL)

	# 交织的稻草：沿椭圆环铺一圈短稻草
	var strands := 30
	for i in strands:
		var a := TAU * float(i) / float(strands)
		var ca := cos(a)
		var sa := sin(a)
		var base := center + Vector2(ca * rx * 0.84, sa * ry * 0.72 - ry * 0.14)
		var tangent := Vector2(-sa * rx, ca * ry).normalized()
		var outward := Vector2(ca, sa * 0.6).normalized()
		var dir := (tangent * (0.8 + 0.4 * _hash01(i * 7 + 3))
			+ outward * (0.15 + 0.3 * _hash01(i * 13 + 1))).normalized()
		var length := rx * (0.16 + 0.16 * _hash01(i * 5 + 2))
		var col := COLOR_STRAW_LIGHT
		match i % 3:
			1:
				col = COLOR_STRAW
			2:
				col = COLOR_STRAW_DARK
		draw_line(base - dir * length * 0.5, base + dir * length * 0.5, col, 2.2, true)

	# 前沿（下半圈）再压几根亮色稻草，突出平铺的立体感
	for i in 8:
		var a := lerpf(0.18, PI - 0.18, float(i) / 7.0)
		var ca := cos(a)
		var sa := sin(a)
		var base := center + Vector2(ca * rx * 0.80, sa * ry * 0.92 - ry * 0.04)
		var tangent := Vector2(-sa * rx, ca * ry).normalized()
		var length := rx * (0.22 + 0.10 * _hash01(i * 11 + 9))
		draw_line(base - tangent * length * 0.5, base + tangent * length * 0.5,
			COLOR_STRAW_LIGHT, 2.6, true)


func _draw_hen(center: Vector2, sf: float, facing: float, walking: bool, walk_phase: float) -> void:
	var body := COLOR_HEN_BODY
	var wing := COLOR_HEN_WING
	var comb := COLOR_COMB
	var beak := COLOR_BEAK
	var bob := 0.0
	var leg_swing := 0.0
	if walking:
		bob = -absf(sin(walk_phase)) * 4.0 * sf
		leg_swing = sin(walk_phase) * 9.0 * sf
	var c := center + Vector2(0, bob)

	# 走路时露出两条鸡腿，交替摆动
	if walking:
		draw_line(c + Vector2(-10 * sf * facing, 26 * sf),
			c + Vector2((-10 * sf + leg_swing) * facing, 47 * sf), beak, 3.2 * sf, true)
		draw_line(c + Vector2(10 * sf * facing, 26 * sf),
			c + Vector2((10 * sf - leg_swing) * facing, 47 * sf), beak, 3.2 * sf, true)

	# 身体
	_draw_ellipse(c, 46 * sf, 40 * sf, body)
	# 翅膀
	_draw_ellipse(c + Vector2(-6 * sf * facing, 6 * sf), 26 * sf, 22 * sf, wing)
	# 头
	var head := c + Vector2(30 * sf * facing, -32 * sf)
	_draw_ellipse(head, 22 * sf, 22 * sf, body)
	# 鸡冠
	_draw_ellipse(head + Vector2(-2 * sf * facing, -22 * sf), 13 * sf, 9 * sf, comb)
	# 喙
	var beak_pts := PackedVector2Array([
		c + Vector2(48 * sf * facing, -36 * sf),
		c + Vector2(66 * sf * facing, -30 * sf),
		c + Vector2(48 * sf * facing, -24 * sf),
	])
	draw_colored_polygon(beak_pts, beak)
	# 眼睛
	draw_circle(c + Vector2(34 * sf * facing, -38 * sf), 3.4 * sf, Color.BLACK)


func _draw_egg_row(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	var spacing := 26.0
	var start_x := center.x - spacing * (count - 1) * 0.5
	# 孵化中的当前蛋会抖动
	var wobble := 0.0
	if player.hatch_progress > 0.05 and player.status == PlayerState.PlayerStatus.NORMAL:
		wobble = sin(_time * 18.0) * 2.2 * player.hatch_progress
	for i in count:
		var pos := Vector2(start_x + i * spacing + wobble, center.y)
		# 蛋影
		_draw_ellipse(pos + Vector2(0, 3), 13, 16, COLOR_EGG_SHADOW)
		# 蛋身
		_draw_ellipse(pos, 12.5, 15.5, COLOR_EGG)
	# 计数放到鸡窝右侧，避免压住母鸡
	_draw_text_shadow("x%d" % count, Vector2(center.x + 68, center.y + 10), 18,
		Color(1, 1, 1, 0.95), false)


func _draw_chick_row(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	var spacing := 26.0
	var start_x := center.x - spacing * (count - 1) * 0.5
	for i in count:
		var pos := Vector2(start_x + i * spacing, center.y)
		_draw_chick(pos, 1.0)


func _draw_chick(center: Vector2, sf: float) -> void:
	# 身体
	_draw_ellipse(center, 11 * sf, 10 * sf, COLOR_CHICK)
	# 头
	_draw_ellipse(center + Vector2(0, -10 * sf), 8 * sf, 8 * sf, COLOR_CHICK)
	# 眼睛
	draw_circle(center + Vector2(3 * sf, -12 * sf), 1.6 * sf, Color.BLACK)
	# 喙
	var beak_pts := PackedVector2Array([
		center + Vector2(6 * sf, -12 * sf),
		center + Vector2(12 * sf, -10 * sf),
		center + Vector2(6 * sf, -8 * sf),
	])
	draw_colored_polygon(beak_pts, COLOR_BEAK)


func _draw_progress(pos: Vector2, width: float, height: float) -> void:
	# 背景槽
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0, 0, 0, 0.28), true)
	var ratio := 0.0
	if player.status == PlayerState.PlayerStatus.NORMAL:
		ratio = clampf(player.hatch_progress, 0.0, 1.0)
	elif player.status == PlayerState.PlayerStatus.COMPLETED:
		ratio = 1.0
	# 填充
	var fill := Color(0.45, 0.85, 0.40)
	if player.buff_active:
		fill = Color(1.0, 0.78, 0.20)
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2((width - 2) * ratio, height - 2)), fill, true)


# ——————————————————————————————————————————————
# 绘制工具
# ——————————————————————————————————————————————

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color,
		width: float, points: int = 44) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


## 绘制文字。centered=true 时 pos 视为水平中心，否则为左端。pos.y 为文字基线。
func _draw_text(txt: String, pos: Vector2, font_size: int, color: Color, centered: bool) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var origin := pos
	if centered:
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		origin = Vector2(pos.x - w * 0.5, pos.y)
	draw_string(font, origin, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 带描边阴影的文字，保证在草坪上也能看清。
func _draw_text_shadow(txt: String, pos: Vector2, font_size: int, color: Color,
		centered: bool) -> void:
	_draw_text(txt, pos + Vector2(1.5, 1.5), font_size, Color(0, 0, 0, 0.45), centered)
	_draw_text(txt, pos, font_size, color, centered)


## 稳定伪随机（避免每帧纹理跳动）。
func _hash01(v: int) -> float:
	var x := sin(float(v) * 12.9898) * 43758.5453
	return x - floor(x)


func _status_color() -> Color:
	match player.status:
		PlayerState.PlayerStatus.PAUSED:
			return Color(1.0, 0.85, 0.25)
		PlayerState.PlayerStatus.FAILED:
			return Color(1.0, 0.45, 0.45)
		PlayerState.PlayerStatus.COMPLETED:
			return Color(1.0, 0.92, 0.40)
		_:
			return Color.WHITE
