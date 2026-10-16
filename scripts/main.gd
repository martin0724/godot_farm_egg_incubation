extends Control
## 主场景控制器（对应策划文档第 6.1 / 7 / 10 节）。
## 负责搭建整个界面、教师控制台交互、特效与流程（开场 → 游戏 → 结算）。
## 全部 UI 以代码构建，配合程序化绘制，无需外部资源。

# —— 调色板 ——
const SKY_TOP := Color(0.49, 0.78, 0.93)
const SKY_BOTTOM := Color(0.78, 0.91, 0.98)
const GRASS := Color(0.47, 0.74, 0.33)
const GRASS_DARK := Color(0.37, 0.63, 0.27)
const PANEL_BG := Color(0.09, 0.11, 0.14, 0.86)

var ui_font: SystemFont

# —— 界面层 ——
var bg_layer: Control
var farm_view: Control
var fx_layer: Control
var ui_layer: Control
var grid: GridContainer

# —— 顶栏控件 ——
var mode_label: Label
var time_label: Label
var clear_label: Label

# —— 教师控制台 ——
var teacher_panel: PanelContainer
var teacher_label: Label

# —— 浮层 ——
var intro_overlay: Control
var result_overlay: Control
var result_text: Label
var start_button: Button

# —— 运行时数据 ——
var slots: Array = []
var selected_id: int = -1
var chosen_mode: int = GameConfig.Mode.MODE_A

const SEPARATION := 18.0


func _ready() -> void:
	ui_font = _make_font()
	var th := Theme.new()
	th.default_font = ui_font
	th.default_font_size = 20
	theme = th
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_background()
	_build_farm()
	_build_fx_layer()
	_build_ui_layer()
	_build_topbar()
	_build_teacher_panel()
	_build_intro()
	_build_result()

	_connect_signals()
	resized.connect(_on_resized)


func _make_font() -> SystemFont:
	# 使用系统字体，保证中文可正常显示（Windows 优先微软雅黑）
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "PingFang SC", "sans-serif",
	])
	return font


# ——————————————————————————————————————————————
# 背景（第 8 节：天空 / 草地 / 太阳 / 云）
# ——————————————————————————————————————————————

func _build_background() -> void:
	bg_layer = Control.new()
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_full(bg_layer)
	add_child(bg_layer)
	bg_layer.draw.connect(_draw_background)


func _draw_background() -> void:
	var s := bg_layer.size
	# 天空渐变
	var bands := 32
	for i in bands:
		var t := float(i) / float(bands - 1)
		bg_layer.draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	# 太阳
	bg_layer.draw_circle(Vector2(s.x * 0.90, s.y * 0.16), 96.0, Color(1.0, 0.93, 0.55, 0.95))
	bg_layer.draw_circle(Vector2(s.x * 0.90, s.y * 0.16), 72.0, Color(1.0, 0.97, 0.72, 0.95))
	# 云
	_draw_cloud(bg_layer, Vector2(s.x * 0.18, s.y * 0.14), 1.0)
	_draw_cloud(bg_layer, Vector2(s.x * 0.55, s.y * 0.09), 0.75)
	_draw_cloud(bg_layer, Vector2(s.x * 0.78, s.y * 0.24), 0.6)
	# 草地
	var horizon := s.y * 0.62
	if horizon < 80:
		horizon = 80
	bg_layer.draw_rect(Rect2(0, horizon, s.x, s.y - horizon), GRASS)
	bg_layer.draw_rect(Rect2(0, horizon, s.x, 10.0), GRASS_DARK)
	# 栅栏装饰
	var fence_x := 40.0
	while fence_x < s.x - 40:
		bg_layer.draw_rect(Rect2(fence_x, horizon - 40, 14, 46), Color(0.85, 0.75, 0.55))
		fence_x += 64.0
	bg_layer.draw_rect(Rect2(0, horizon - 26, s.x, 8), Color(0.80, 0.70, 0.50))


func _draw_cloud(c: CanvasItem, center: Vector2, scale_factor: float) -> void:
	var col := Color(1, 1, 1, 0.85)
	# 三个圆拼成一朵云，用椭圆近似
	for i in 3:
		var offset := Vector2((i - 1) * 34.0 * scale_factor, 0)
		var rx := (36.0 if i == 1 else 26.0) * scale_factor
		_ellipse(c, center + offset, rx, rx * 0.7, col)


# ——————————————————————————————————————————————
# 农场区（鸡窝格子）
# ——————————————————————————————————————————————

func _build_farm() -> void:
	farm_view = Control.new()
	farm_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_full(farm_view)
	farm_view.offset_top = 84.0
	farm_view.offset_bottom = -140.0
	add_child(farm_view)
	farm_view.resized.connect(_fit_grid)

	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", int(SEPARATION))
	grid.add_theme_constant_override("v_separation", int(SEPARATION))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	farm_view.add_child(grid)


func _fit_grid() -> void:
	if grid == null or slots.is_empty():
		return
	var cols: int = max(1, grid.columns)
	var n := slots.size()
	var rows := int(ceil(float(n) / float(cols)))
	var cell := NestSlot.SLOT_SIZE
	var total := Vector2(
		cols * cell.x + (cols - 1) * SEPARATION,
		rows * cell.y + (rows - 1) * SEPARATION)
	var avail := farm_view.size
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	var sc := minf(avail.x / total.x, avail.y / total.y)
	sc = minf(sc, 1.15)
	grid.scale = Vector2(sc, sc)
	grid.position = (avail - total * sc) * 0.5


func _columns_for(n: int) -> int:
	var c := int(ceil(sqrt(float(n) * 1.7)))
	return clampi(c, 3, 5)


# ——————————————————————————————————————————————
# 特效层 & UI 层
# ——————————————————————————————————————————————

func _build_fx_layer() -> void:
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_full(fx_layer)
	add_child(fx_layer)


func _build_ui_layer() -> void:
	ui_layer = Control.new()
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_full(ui_layer)
	add_child(ui_layer)


func _build_topbar() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.09, 0.11, 0.14, 0.72)
	bar.anchor_right = 1.0
	bar.offset_bottom = 72.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	_anchor_full(hb)
	hb.offset_left = 20.0
	hb.offset_right = -20.0
	hb.offset_top = 12.0
	hb.offset_bottom = -12.0
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hb)

	mode_label = _make_label("超级农场", 22, Color(1, 1, 1, 0.9))
	hb.add_child(mode_label)
	hb.add_child(_make_spacer())

	var title := _make_label("超级农场 · 孵蛋大作战", 30, Color(1.0, 0.94, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(title)
	hb.add_child(_make_spacer())

	time_label = _make_label("时间 00:00", 22, Color(1, 1, 1, 0.9))
	hb.add_child(time_label)
	hb.add_child(_make_spacer())
	clear_label = _make_label("通关 0 / 0", 22, Color(0.7, 1.0, 0.7))
	hb.add_child(clear_label)


# ——————————————————————————————————————————————
# 教师控制台（第 7 节）
# ——————————————————————————————————————————————

func _build_teacher_panel() -> void:
	teacher_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	teacher_panel.add_theme_stylebox_override("panel", style)
	teacher_panel.anchor_left = 0.0
	teacher_panel.anchor_right = 1.0
	teacher_panel.anchor_top = 1.0
	teacher_panel.anchor_bottom = 1.0
	teacher_panel.offset_top = -136.0
	teacher_panel.offset_bottom = 0.0
	teacher_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(teacher_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	teacher_panel.add_child(v)

	teacher_label = _make_label("未选中鸡窝 · 点击鸡窝选中，或按 Tab 隐藏本面板", 20, Color(1.0, 0.9, 0.6))
	v.add_child(teacher_label)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)

	_add_teacher_button(hb, "离座 -1  (Q)", func() -> void: _require_sel(GameManager.trigger_leave))
	_add_teacher_button(hb, "吵闹 -2  (W)", func() -> void: _require_sel(GameManager.trigger_noise))
	_add_teacher_button(hb, "分心暂停 (E)", func() -> void: _require_sel(GameManager.trigger_distraction))
	_add_teacher_button(hb, "恢复继续 (R)", func() -> void: _require_sel(GameManager.resume_player))
	_add_teacher_button(hb, "投喂奖励 (A)", func() -> void: _require_sel(GameManager.trigger_feed))
	_add_teacher_button(hb, "答题+1 (S)", func() -> void: _require_sel(GameManager.trigger_answer))
	_add_teacher_button(hb, "全班投喂", func() -> void: GameManager.trigger_feed_all())
	_add_teacher_button(hb, "开始/结束 (空格)", _toggle_game)


func _add_teacher_button(parent: Node, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", ui_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(func() -> void:
		Sfx.play("click")
		cb.call())
	parent.add_child(btn)


# ——————————————————————————————————————————————
# 开场浮层（第 10.2 节）
# ——————————————————————————————————————————————

func _build_intro() -> void:
	intro_overlay = ColorRect.new()
	intro_overlay.color = Color(0.05, 0.07, 0.10, 0.90)
	_anchor_full(intro_overlay)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(intro_overlay)

	var cc := CenterContainer.new()
	_anchor_full(cc)
	intro_overlay.add_child(cc)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	cc.add_child(v)

	var title := _make_label("超级农场 · 母鸡孵蛋计划", 52, Color(1.0, 0.94, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var story := _make_label(
		"今天我们的英语教室变身【超级农场】！\n"
		+ "每个小朋友都变成温柔的母鸡，每个人都有一座专属鸡窝。\n"
		+ "任务：安静坐在鸡窝里孵蛋，孵出可爱的小鸡！\n\n"
		+ "★ 乱跑离窝 → 小老鼠跑来偷蛋\n"
		+ "★ 认真听课跟读 → 农场主人投喂加速\n"
		+ "★ 表现优秀 → 获得超级鸡窝保护盾\n\n"
		+ "孵满 5 只小鸡即可通关，下课结算排名！",
		24, Color(1, 1, 1, 0.92))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.custom_minimum_size = Vector2(980, 0)
	v.add_child(story)

	v.add_child(_make_spacer(10.0))

	# 模式选择
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 16)
	v.add_child(mode_row)
	var mode_lbl := _make_label("孵蛋节奏：", 24, Color(1, 1, 1, 0.9))
	mode_row.add_child(mode_lbl)
	var mode_a := _make_toggle_button("模式A（5 分钟/蛋）", true)
	mode_a.pressed.connect(func() -> void: _choose_mode(GameConfig.Mode.MODE_A))
	mode_row.add_child(mode_a)
	var mode_b := _make_toggle_button("模式B（8 分钟/蛋）", false)
	mode_b.pressed.connect(func() -> void: _choose_mode(GameConfig.Mode.MODE_B))
	mode_row.add_child(mode_b)

	# 人数选择
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 12)
	v.add_child(count_row)
	count_row.add_child(_make_label("参与人数：", 24, Color(1, 1, 1, 0.9)))
	var spin := SpinBox.new()
	spin.min_value = 5
	spin.max_value = 30
	spin.value = 20
	spin.add_theme_font_override("font", ui_font)
	spin.custom_minimum_size = Vector2(140, 0)
	count_row.add_child(spin)

	v.add_child(_make_spacer(10.0))

	start_button = Button.new()
	start_button.text = "开始上课"
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.add_theme_font_override("font", ui_font)
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.custom_minimum_size = Vector2(320, 64)
	start_button.pressed.connect(func() -> void:
		Sfx.play("click")
		_start_game(chosen_mode, int(spin.value)))
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(start_button)
	v.add_child(center)


func _make_toggle_button(text: String, pressed: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = pressed
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", ui_font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(240, 52)
	# 分组互斥
	btn.button_group = _mode_group()
	return btn


var _mode_group_ref: ButtonGroup

func _mode_group() -> ButtonGroup:
	if _mode_group_ref == null:
		_mode_group_ref = ButtonGroup.new()
	return _mode_group_ref


func _choose_mode(mode: int) -> void:
	chosen_mode = mode


# ——————————————————————————————————————————————
# 结算浮层（第 10.3 节）
# ——————————————————————————————————————————————

func _build_result() -> void:
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0.05, 0.07, 0.10, 0.92)
	_anchor_full(result_overlay)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.visible = false
	ui_layer.add_child(result_overlay)

	var cc := CenterContainer.new()
	_anchor_full(cc)
	result_overlay.add_child(cc)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	cc.add_child(v)

	var title := _make_label("本课结算 · 排名榜", 46, Color(1.0, 0.94, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	result_text = _make_label("", 24, Color(1, 1, 1, 0.95))
	result_text.custom_minimum_size = Vector2(1000, 0)
	v.add_child(result_text)

	v.add_child(_make_spacer(10.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)

	var again := Button.new()
	again.text = "再来一节课"
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_override("font", ui_font)
	again.add_theme_font_size_override("font_size", 26)
	again.custom_minimum_size = Vector2(240, 56)
	again.pressed.connect(func() -> void:
		Sfx.play("click")
		_reset_to_intro())
	row.add_child(again)

	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_override("font", ui_font)
	close.add_theme_font_size_override("font_size", 26)
	close.custom_minimum_size = Vector2(200, 56)
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		result_overlay.visible = false)
	row.add_child(close)


# ——————————————————————————————————————————————
# 信号连线
# ——————————————————————————————————————————————

func _connect_signals() -> void:
	GameManager.egg_hatched.connect(_on_egg_hatched)
	GameManager.egg_stolen.connect(_on_egg_stolen)
	GameManager.reward_fed.connect(_on_reward_fed)
	GameManager.shield_blocked.connect(_on_shield_blocked)
	GameManager.nest_destroyed.connect(_on_nest_destroyed)
	GameManager.player_completed.connect(_on_player_completed)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.state_changed.connect(_on_state_changed)


# ——————————————————————————————————————————————
# 流程
# ——————————————————————————————————————————————

func _start_game(mode: int, count: int) -> void:
	intro_overlay.visible = false
	result_overlay.visible = false
	selected_id = -1
	GameManager.start_game(mode, count)
	_build_nests()


func _reset_to_intro() -> void:
	result_overlay.visible = false
	GameManager.reset_to_intro()
	for slot in slots:
		slot.queue_free()
	slots.clear()
	intro_overlay.visible = true
	selected_id = -1
	_update_teacher_label()


func _toggle_game() -> void:
	if GameManager.is_intro():
		_start_game(chosen_mode, 20)
	elif GameManager.is_playing():
		GameManager.end_game()


func _build_nests() -> void:
	for slot in slots:
		slot.queue_free()
	slots.clear()
	var n: int = GameManager.players.size()
	grid.columns = _columns_for(n)
	for p in GameManager.players:
		var slot := NestSlot.new()
		slot.setup(p)
		slot.selected_slot.connect(_on_slot_selected)
		grid.add_child(slot)
		slots.append(slot)
	call_deferred("_fit_grid")


func _on_slot_selected(id: int) -> void:
	selected_id = id
	for slot in slots:
		slot.selected = (slot.player.id == id)
		slot.queue_redraw()
	Sfx.play("click")
	_update_teacher_label()


func _update_teacher_label() -> void:
	if selected_id < 0:
		teacher_label.text = "未选中鸡窝 · 点击鸡窝选中，或按 Tab 隐藏本面板"
	else:
		teacher_label.text = "已选中：%d号鸡窝（快捷键 Q/W/E/R/A/S 直接操作）" % (selected_id + 1)


func _require_sel(cb: Callable) -> void:
	if selected_id < 0 or selected_id >= slots.size():
		teacher_label.text = "⚠ 请先点击选中一个鸡窝！"
		return
	cb.call(selected_id)


# ——————————————————————————————————————————————
# 输入（第 7.2 节）
# ——————————————————————————————————————————————

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	match k:
		KEY_TAB:
			teacher_panel.visible = not teacher_panel.visible
		KEY_SPACE:
			_toggle_game()
		KEY_ESCAPE:
			if GameManager.is_playing():
				GameManager.end_game()
		KEY_Q:
			_require_sel(GameManager.trigger_leave)
		KEY_W:
			_require_sel(GameManager.trigger_noise)
		KEY_E:
			_require_sel(GameManager.trigger_distraction)
		KEY_R:
			_require_sel(GameManager.resume_player)
		KEY_A:
			if event.shift_pressed:
				GameManager.trigger_feed_all()
			else:
				_require_sel(GameManager.trigger_feed)
		KEY_S:
			_require_sel(GameManager.trigger_answer)
		_:
			return
	get_viewport().set_input_as_handled()


# ——————————————————————————————————————————————
# 每帧刷新
# ——————————————————————————————————————————————

func _process(_delta: float) -> void:
	if GameManager.is_playing():
		mode_label.text = GameManager.config.mode_label()
		time_label.text = "时间 %s" % _fmt_time(GameManager.elapsed_time)
		clear_label.text = "通关 %d / %d" % [GameManager.completed_count(), GameManager.players.size()]
		for slot in slots:
			slot.queue_redraw()


func _on_resized() -> void:
	if bg_layer != null:
		bg_layer.queue_redraw()
	_fit_grid()


func _fmt_time(t: float) -> String:
	var total := int(t)
	return "%02d:%02d" % [total / 60, total % 60]


# ——————————————————————————————————————————————
# 事件 → 特效（第 8 节）
# ——————————————————————————————————————————————

func _slot_for(id: int) -> NestSlot:
	for slot in slots:
		if slot.player.id == id:
			return slot
	return null


func _on_egg_hatched(id: int) -> void:
	Sfx.play("hatch")
	var slot := _slot_for(id)
	if slot != null:
		_spawn_float(slot, "+1 小鸡", Color(1.0, 0.85, 0.25))


func _on_egg_stolen(id: int, amount: int, noise_level: bool) -> void:
	Sfx.play("steal")
	var slot := _slot_for(id)
	if slot != null:
		_spawn_float(slot, "-%d 蛋" % amount, Color(1.0, 0.35, 0.35))
		_spawn_mouse(slot, noise_level)


func _on_reward_fed(id: int, buff: bool, shield: bool) -> void:
	Sfx.play("reward")
	var slot := _slot_for(id)
	if slot != null:
		if buff:
			_spawn_float(slot, "农场投喂：加速!", Color(0.4, 1.0, 0.5))
		if shield:
			_spawn_float(slot, "获得保护盾!", Color(0.5, 0.8, 1.0))


func _on_shield_blocked(id: int) -> void:
	Sfx.play("shield")
	var slot := _slot_for(id)
	if slot != null:
		_spawn_float(slot, "盾挡住了!", Color(0.55, 0.85, 1.0))


func _on_nest_destroyed(id: int) -> void:
	Sfx.play("fail")
	var slot := _slot_for(id)
	if slot != null:
		_spawn_float(slot, "鸡窝塌了…", Color(1.0, 0.4, 0.4))


func _on_player_completed(id: int) -> void:
	Sfx.play("win")
	var slot := _slot_for(id)
	if slot != null:
		_spawn_float(slot, "通关!", Color(1.0, 0.92, 0.4))


func _on_game_ended(ranking: Array) -> void:
	_show_result(ranking)


func _on_state_changed(_new_state: int) -> void:
	pass


# ——————————————————————————————————————————————
# 特效生成
# ——————————————————————————————————————————————

func _spawn_float(slot: NestSlot, text: String, color: Color) -> void:
	var ft := FloatText.new()
	fx_layer.add_child(ft)
	ft.setup(text, color, ui_font)
	var rect := slot.get_global_rect()
	ft.size = Vector2(200, 40)
	ft.position = Vector2(rect.get_center().x - 100.0, rect.position.y + 40.0)


func _spawn_mouse(slot: NestSlot, big: bool) -> void:
	var rect := slot.get_global_rect()
	var center := rect.get_center()
	var from_left := center.x < size.x * 0.5
	var mouse := MouseFX.new()
	fx_layer.add_child(mouse)
	mouse.setup(from_left, center, big)


# ——————————————————————————————————————————————
# 结算榜填充
# ——————————————————————————————————————————————

func _show_result(ranking: Array) -> void:
	var lines: Array = []
	for entry in ranking:
		var p: PlayerState = entry["player"]
		var mark := ""
		match p.status:
			PlayerState.PlayerStatus.COMPLETED:
				mark = "★"
			PlayerState.PlayerStatus.FAILED:
				mark = "×"
			_:
				mark = "☆"
		var time_str := "未通关"
		if p.completed_at_time >= 0.0:
			time_str = _fmt_time(p.completed_at_time) + " 通关"
		lines.append("%s 第%d名  %s —— %s ｜ 剩蛋 %d ｜ 小鸡 %d ｜ %s" % [
			mark, entry["rank"], p.display_name, entry["title"],
			p.eggs, p.chicks, time_str])
	result_text.text = "\n".join(lines)
	result_overlay.visible = true
	Sfx.play("win")


# ——————————————————————————————————————————————
# UI 工具
# ——————————————————————————————————————————————

func _anchor_full(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", ui_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_spacer(min_height: float = 0.0) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, min_height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * float(i) / float(points)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, color)
