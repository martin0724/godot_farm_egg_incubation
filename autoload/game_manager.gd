extends Node
## 全局管理器（Autoload 单例 `GameManager`，对应策划文档第 4.3 / 5 节）。
## 负责：持有玩家列表、全局状态、计时、派发信号、结算。

signal state_changed(new_state: int)
signal player_updated(player)
signal egg_stolen(player_id: int, amount: int, noise_level: bool)
signal egg_hatched(player_id: int)
signal hen_left_nest(player_id: int)
signal hen_returned(player_id: int)
signal mouse_appeared(player_id: int)
signal reward_fed(player_id: int, buff: bool, shield: bool)
signal shield_activated(player_id: int)
signal shield_blocked(player_id: int)
signal nest_destroyed(player_id: int)
signal player_completed(player_id: int)
signal game_ended(ranking: Array)

enum State { INTRO, PLAYING, ENDED }

var config: GameConfig
var players: Array = []
var current_state: int = State.INTRO
var elapsed_time: float = 0.0
var winner_id: int = -1


func _ready() -> void:
	config = GameConfig.new()


# ——————————————————————————————————————————————
# 生命周期
# ——————————————————————————————————————————————

## 开始一局新游戏（对应 `start_game(mode, player_count)`）。
func start_game(mode: int, count: int) -> void:
	config.mode = mode
	config.player_count = count
	players.clear()
	for i in count:
		var p := PlayerState.new()
		p.id = i
		p.display_name = "%d号鸡窝" % (i + 1)
		p.eggs = GameConfig.INITIAL_EGGS
		p.chicks = 0
		p.hatch_progress = 0.0
		p.status = PlayerState.PlayerStatus.NORMAL
		players.append(p)
	elapsed_time = 0.0
	winner_id = -1
	_set_state(State.PLAYING)


func _process(delta: float) -> void:
	if current_state != State.PLAYING:
		return
	elapsed_time += delta
	for p in players:
		_tick_player(p, delta)


# ——————————————————————————————————————————————
# 每帧推进（对应策划文档第 5.1 节）
# ——————————————————————————————————————————————

func _tick_player(p: PlayerState, delta: float) -> void:
	# 衰减加速 buff
	if p.buff_seconds > 0.0:
		p.buff_seconds = maxf(0.0, p.buff_seconds - delta)
		if p.buff_seconds == 0.0 and p.buff_active:
			p.buff_active = false
			player_updated.emit(p)
	# 衰减保护盾
	if p.shield_seconds > 0.0:
		p.shield_seconds = maxf(0.0, p.shield_seconds - delta)
		if p.shield_seconds == 0.0 and p.shield_active:
			p.shield_active = false
			player_updated.emit(p)
	# 推进孵化
	if p.status == PlayerState.PlayerStatus.NORMAL and p.eggs > 0:
		var mult := GameConfig.FEED_SPEED_BUFF_MULT if p.buff_active else 1.0
		p.hatch_progress += delta / config.seconds_per_egg() * mult
		if p.hatch_progress >= 1.0:
			_hatch_one(p)


# ——————————————————————————————————————————————
# 奖励 / 惩罚操作（教师控制台调用）
# ——————————————————————————————————————————————

## 离座惩罚：母鸡离窝 → 老鼠偷 1 蛋 → 母鸡回窝。
func trigger_leave(player_id: int) -> void:
	var p := get_player(player_id)
	if not _can_be_punished(p):
		return
	p.status = PlayerState.PlayerStatus.HEN_LEFT
	hen_left_nest.emit(p.id)
	mouse_appeared.emit(p.id)
	_steal(p, GameConfig.EGG_STEAL_ON_LEAVE, false)
	if p.status == PlayerState.PlayerStatus.HEN_LEFT:
		p.status = PlayerState.PlayerStatus.NORMAL
	hen_returned.emit(p.id)
	player_updated.emit(p)


## 吵闹惩罚：老鼠大偷袭，一次性偷 2 蛋。
func trigger_noise(player_id: int) -> void:
	var p := get_player(player_id)
	if not _can_be_punished(p):
		return
	mouse_appeared.emit(p.id)
	_steal(p, GameConfig.EGG_STEAL_ON_NOISE, true)
	player_updated.emit(p)


## 轻微分心：孵蛋暂停（进度冻结，蛋不会被偷）。
func trigger_distraction(player_id: int) -> void:
	var p := get_player(player_id)
	if p == null or p.status != PlayerState.PlayerStatus.NORMAL:
		return
	p.status = PlayerState.PlayerStatus.PAUSED
	player_updated.emit(p)


## 恢复被暂停的玩家。
func resume_player(player_id: int) -> void:
	var p := get_player(player_id)
	if p == null or p.status != PlayerState.PlayerStatus.PAUSED:
		return
	p.status = PlayerState.PlayerStatus.NORMAL
	player_updated.emit(p)


## 投喂奖励：随机给「加速 buff」或「保护盾」。
func trigger_feed(player_id: int) -> void:
	var p := get_player(player_id)
	if not _can_be_punished(p):
		return
	if randi() % 2 == 0:
		p.buff_seconds = GameConfig.FEED_BUFF_DURATION_SEC
		p.buff_active = true
		reward_fed.emit(p.id, true, false)
	else:
		p.shield_seconds = GameConfig.SHIELD_DURATION_SEC
		p.shield_active = true
		reward_fed.emit(p.id, false, true)
		shield_activated.emit(p.id)
	player_updated.emit(p)


## 直接给玩家保护盾。
func trigger_shield(player_id: int) -> void:
	var p := get_player(player_id)
	if not _can_be_punished(p):
		return
	p.shield_seconds = GameConfig.SHIELD_DURATION_SEC
	p.shield_active = true
	reward_fed.emit(p.id, false, true)
	shield_activated.emit(p.id)
	player_updated.emit(p)


## 答题奖励：直接立刻孵化 1 颗蛋。
func trigger_answer(player_id: int) -> void:
	var p := get_player(player_id)
	if not _can_be_punished(p):
		return
	for i in GameConfig.ANSWER_INSTANT_EGGS:
		if p.eggs > 0:
			_hatch_one(p)


## 全员投喂（全班奖励）。
func trigger_feed_all() -> void:
	for p in players:
		if p.status == PlayerState.PlayerStatus.NORMAL:
			trigger_feed(p.id)


# ——————————————————————————————————————————————
# 结算（对应策划文档第 5.4 节）
# ——————————————————————————————————————————————

## 结束本课，计算排名并发射 `game_ended`。
func end_game() -> void:
	if current_state == State.ENDED:
		return
	var ranking := get_ranking()
	_set_state(State.ENDED)
	game_ended.emit(ranking)


## 计算排名榜（返回 {player, title, rank} 数组）。
func get_ranking() -> Array:
	var completed: Array = []
	var survivors: Array = []
	var failed: Array = []
	for p in players:
		if p.is_completed():
			completed.append(p)
		elif p.is_failed():
			failed.append(p)
		else:
			survivors.append(p)
	# 通关者按完成时间升序（最早通关排最前）
	completed.sort_custom(func(a, b): return a.completed_at_time < b.completed_at_time)
	# 未通关者按存活成果降序
	survivors.sort_custom(func(a, b): return a.total_survived() > b.total_survived())

	var ranking: Array = []
	var rank := 1
	for i in completed.size():
		var title := "农场金牌母鸡" if i == 0 else "优秀孵蛋小能手"
		ranking.append({"player": completed[i], "title": title, "rank": rank})
		rank += 1
	for p in survivors:
		ranking.append({"player": p, "title": "优秀孵蛋小能手", "rank": rank})
		rank += 1
	for p in failed:
		ranking.append({"player": p, "title": "需要下节课继续努力", "rank": rank})
		rank += 1
	return ranking


# ——————————————————————————————————————————————
# 内部工具
# ——————————————————————————————————————————————

## 回到开场状态并清空玩家（重新开始前调用）。
func reset_to_intro() -> void:
	players.clear()
	winner_id = -1
	elapsed_time = 0.0
	_set_state(State.INTRO)


func is_intro() -> bool:
	return current_state == State.INTRO


func is_playing() -> bool:
	return current_state == State.PLAYING


func is_ended() -> bool:
	return current_state == State.ENDED


func get_player(player_id: int) -> PlayerState:
	if player_id < 0 or player_id >= players.size():
		return null
	return players[player_id]


func completed_count() -> int:
	var c := 0
	for p in players:
		if p.is_completed():
			c += 1
	return c


func failed_count() -> int:
	var c := 0
	for p in players:
		if p.is_failed():
			c += 1
	return c


## 是否可被执行奖惩（未出局、未通关）。
func _can_be_punished(p: PlayerState) -> bool:
	if p == null:
		return false
	return not (p.is_failed() or p.is_completed())


## 偷蛋逻辑（离座 / 吵闹共用，对应策划文档第 5.2 节）。
func _steal(p: PlayerState, amount: int, noise_level: bool) -> void:
	if p.is_failed() or p.is_completed():
		return
	if p.shield_active:
		shield_blocked.emit(p.id)
		return
	p.eggs = maxi(0, p.eggs - amount)
	egg_stolen.emit(p.id, amount, noise_level)
	if p.eggs <= 0:
		p.status = PlayerState.PlayerStatus.FAILED
		p.buff_active = false
		p.shield_active = false
		nest_destroyed.emit(p.id)


## 孵化一颗蛋（对应策划文档第 5.3 节）。
func _hatch_one(p: PlayerState) -> void:
	p.eggs = maxi(0, p.eggs - 1)
	p.chicks += 1
	p.hatch_progress = 0.0
	egg_hatched.emit(p.id)
	if p.chicks >= GameConfig.TOTAL_CHICKS_TO_WIN:
		p.status = PlayerState.PlayerStatus.COMPLETED
		p.completed_at_time = elapsed_time
		if winner_id == -1:
			winner_id = p.id
		player_completed.emit(p.id)
	player_updated.emit(p)


func _set_state(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(new_state)
