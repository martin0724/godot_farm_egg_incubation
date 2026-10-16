class_name NestSlot
extends Control
## 单个鸡窝的视图（对应策划文档第 6.2 / 10.4 节）。
## 全部使用 `_draw()` 程序化绘制，无需外部贴图。

signal selected_slot(id: int)

const SLOT_SIZE := Vector2(230, 260)

# 配色
const COLOR_NEST := Color(0.66, 0.44, 0.24)
const COLOR_NEST_DARK := Color(0.50, 0.32, 0.16)
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


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func setup(p: PlayerState) -> void:
	player = p
	queue_redraw()


func _process(delta: float) -> void:
	# 仅用于蛋的呼吸 / 抖动动画
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		selected_slot.emit(player.id)
		accept_event()


# ——————————————————————————————————————————————
# 绘制
# ——————————————————————————————————————————————

func _draw() -> void:
	if player == null:
		return
	var s := size
	var cx := s.x * 0.5

	# 选中高亮边框
	if selected:
		draw_rect(Rect2(Vector2(2, 2), s - Vector2(4, 4)), Color(1.0, 0.85, 0.20), false, 4.0)

	# 背景卡片（按状态着色）
	var bg := Color(1, 1, 1, 0.10)
	match player.status:
		PlayerState.PlayerStatus.FAILED:
			bg = Color(0.55, 0.15, 0.15, 0.28)
		PlayerState.PlayerStatus.COMPLETED:
			bg = Color(1.0, 0.85, 0.25, 0.26)
		PlayerState.PlayerStatus.PAUSED:
			bg = Color(0.95, 0.80, 0.20, 0.22)
	draw_rect(Rect2(Vector2.ZERO, s), bg, true)

	# 名称
	_draw_text(player.display_name, Vector2(12, 30), 22, Color(1, 1, 1, 0.95), false)
	# 状态角标（右对齐）
	var badge := player.status_label()
	if badge != "":
		var badge_font := get_theme_default_font()
		var badge_w := 0.0
		if badge_font != null:
			badge_w = badge_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_draw_text(badge, Vector2(s.x - 12 - badge_w, 30), 22, _status_color(), false)

	# 母鸡（离窝时上移淡出）
	var hen_center := Vector2(cx, s.y * 0.40)
	var hen_alpha := 1.0
	if player.status == PlayerState.PlayerStatus.HEN_LEFT:
		hen_center += Vector2(0, -34)
		hen_alpha = 0.35
	_draw_hen(hen_center, 1.0, hen_alpha)

	# 鸡窝
	var nest_c := Vector2(cx, s.y * 0.70)
	_draw_ellipse(nest_c, s.x * 0.44, s.y * 0.13, COLOR_NEST)
	_draw_ellipse(nest_c + Vector2(0, -6), s.x * 0.38, s.y * 0.09, COLOR_NEST_DARK)

	# 鸡窝里的蛋
	var egg_c := nest_c + Vector2(0, -4)
	_draw_egg_row(egg_c, player.eggs)

	# 已孵出的小鸡（排在鸡窝前方）
	_draw_chick_row(Vector2(cx, s.y * 0.86), player.chicks)

	# 保护盾光罩
	if player.shield_active:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		_draw_ellipse(nest_c, s.x * 0.48, s.y * 0.22, Color(0.4, 0.75, 1.0, 0.18 + 0.18 * pulse))

	# 孵化进度条
	_draw_progress(Vector2(18, s.y - 22), s.x - 36, 12)

	# buff / shield 图标
	var icon_pos := Vector2(20, s.y * 0.55)
	if player.buff_active:
		_draw_ellipse(icon_pos, 13, 13, Color(0.30, 0.85, 0.40, 0.95))
		_draw_text("加", icon_pos + Vector2(0, 6), 18, Color.WHITE, true)
		icon_pos.y += 34
	if player.shield_active:
		_draw_ellipse(icon_pos, 13, 13, Color(0.35, 0.65, 1.0, 0.95))
		_draw_text("盾", icon_pos + Vector2(0, 6), 18, Color.WHITE, true)


func _draw_hen(center: Vector2, scale_factor: float, alpha: float) -> void:
	var body := COLOR_HEN_BODY
	var wing := COLOR_HEN_WING
	if alpha < 1.0:
		body.a = alpha
		wing.a = alpha
	var comb := COLOR_COMB
	var beak := COLOR_BEAK
	if alpha < 1.0:
		comb.a = alpha
		beak.a = alpha
	var sf := scale_factor
	# 身体
	_draw_ellipse(center, 46 * sf, 40 * sf, body)
	# 翅膀
	_draw_ellipse(center + Vector2(-6 * sf, 6 * sf), 26 * sf, 22 * sf, wing)
	# 头
	var head := center + Vector2(30 * sf, -32 * sf)
	_draw_ellipse(head, 22 * sf, 22 * sf, body)
	# 鸡冠
	_draw_ellipse(head + Vector2(-2 * sf, -22 * sf), 13 * sf, 9 * sf, comb)
	# 喙
	var beak_pts := PackedVector2Array([
		center + Vector2(48 * sf, -36 * sf),
		center + Vector2(66 * sf, -30 * sf),
		center + Vector2(48 * sf, -24 * sf),
	])
	draw_colored_polygon(beak_pts, beak)
	# 眼睛
	var eye := Color.BLACK
	if alpha < 1.0:
		eye.a = alpha
	draw_circle(center + Vector2(34 * sf, -38 * sf), 3.4 * sf, eye)


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
		_draw_ellipse(pos + Vector2(0, 3), 14, 17, COLOR_EGG_SHADOW)
		# 蛋身
		_draw_ellipse(pos, 13, 16, COLOR_EGG)
	# 计数文字
	_draw_text("x%d" % count, center + Vector2(0, -30), 20, Color(1, 1, 1, 0.9), true)


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
