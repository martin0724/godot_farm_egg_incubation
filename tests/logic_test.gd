extends SceneTree
## 逻辑回归测试（对应策划文档第 14 节验收用例 T1–T9）。
##
## 运行方式（无需打开编辑器，headless）：
##   godot --headless --path <项目路径> --script res://tests/logic_test.gd
##
## 全部通过时进程退出码为 0，否则为 1。

var _passed := 0
var _failed := 0
var _gm


func _initialize() -> void:
	print("==== 农场孵蛋 · 逻辑测试开始 ====")
	# 手动实例化逻辑中枢（不依赖 autoload，保证测试独立可跑）
	_gm = (load("res://autoload/game_manager.gd") as GDScript).new()
	# 显式赋值 config，避免依赖 _ready 的调用时机
	_gm.config = GameConfig.new()
	root.add_child(_gm)

	# 事件计数，用于验证信号是否按预期发出
	var stolen := {"count": 0, "last": []}
	var hatched := {"count": 0}
	var blocked := {"count": 0}
	var destroyed := {"count": 0}
	var completed := {"count": 0}
	_gm.egg_stolen.connect(func(id, amount, noise):
		stolen["count"] += 1
		stolen["last"] = [id, amount, noise])
	_gm.egg_hatched.connect(func(_id): hatched["count"] += 1)
	_gm.shield_blocked.connect(func(_id): blocked["count"] += 1)
	_gm.nest_destroyed.connect(func(_id): destroyed["count"] += 1)
	_gm.player_completed.connect(func(_id): completed["count"] += 1)

	# —— 初始化（对应 T1 前置条件）——
	_gm.start_game(0, 3)  # 0 = GameConfig.Mode.MODE_A
	_check("初始：玩家人数 = 3", _gm.players.size() == 3)
	_check("初始：每人 5 颗蛋", _gm.players[0].eggs == 5)
	_check("初始：状态为 PLAYING", _gm.is_playing())

	# —— T1：等待 300s（模式 A）每人孵出 1 只小鸡 ——
	_gm._process(300.0)
	_check("T1：孵出 1 只小鸡", _gm.players[0].chicks == 1)
	_check("T1：剩余 4 颗蛋", _gm.players[0].eggs == 4)
	_check("T1：进度已重置", _gm.players[0].hatch_progress < 0.001)
	_check("T1：egg_hatched 信号发出 3 次", hatched["count"] == 3)

	# —— T2：离座偷 1 颗蛋 ——
	_gm.trigger_leave(0)
	_check("T2：离座后剩 3 颗蛋", _gm.players[0].eggs == 3)
	_check("T2：偷蛋后状态回到 NORMAL", _gm.players[0].status == PlayerState.PlayerStatus.NORMAL)
	_check("T2：egg_stolen 记录为 (0,1,false)", stolen["last"] == [0, 1, false])

	# —— T3：保护盾挡偷蛋 ——
	_gm.trigger_shield(0)
	var eggs_before: int = _gm.players[0].eggs
	_gm.trigger_noise(0)
	_check("T3：盾挡住，蛋数不变", _gm.players[0].eggs == eggs_before)
	_check("T3：shield_blocked 信号发出", blocked["count"] == 1)

	# —— T5：吵闹偷 2 颗蛋 / 蛋归零即失败 ——
	# 先移除玩家0 的保护盾，再连续吵闹
	_gm.players[0].shield_seconds = 0.0
	_gm.players[0].shield_active = false
	_gm.trigger_noise(1)
	_check("T5：1号鸡窝吵闹偷 2 颗蛋", _gm.players[1].eggs == 2)
	_gm.trigger_noise(0)  # 3 -> 1
	_check("T5：玩家0 剩 1 颗蛋", _gm.players[0].eggs == 1)
	_gm.trigger_noise(0)  # 1 -> 0 -> 失败
	_check("T5：蛋归零 → 鸡窝破损失败", _gm.players[0].is_failed())
	_check("T5：nest_destroyed 信号发出", destroyed["count"] == 1)

	# —— T4：投喂加速 buff 使孵化速率为 2× ——
	var p1: PlayerState = _gm.players[1]
	var p2: PlayerState = _gm.players[2]
	p1.hatch_progress = 0.0
	p2.hatch_progress = 0.0
	p1.buff_active = false
	p1.buff_seconds = 0.0
	p2.buff_active = true
	p2.buff_seconds = 120.0
	for i in 60:
		_gm._process(1.0)
	_check("T4：加速玩家进度≈0.4（2×）", absf(p2.hatch_progress - 0.4) < 0.02)
	_check("T4：普通玩家进度≈0.2（1×）", absf(p1.hatch_progress - 0.2) < 0.02)

	# —— T6：答题奖励直接孵化，直到通关 ——
	var guard := 0
	while not p2.is_completed() and p2.eggs > 0 and guard < 12:
		_gm.trigger_answer(2)
		guard += 1
	_check("T6：通关（孵满 5 只小鸡）", p2.is_completed() and p2.chicks == 5)
	_check("T6：player_completed 信号发出", completed["count"] == 1)

	# —— T7/T8/T9：结束并结算排名 ——
	_gm.end_game()
	_check("T9：状态切换为 ENDED", _gm.is_ended())
	var ranking: Array = _gm.get_ranking()
	_check("T7：排名人数 = 3", ranking.size() == 3)
	_check("T7：金牌母鸡 = 最先通关者（2号）",
		ranking[0]["player"].id == 2 and ranking[0]["title"] == "农场金牌母鸡")
	_check("T7：存活成果第 2 名为 1 号",
		ranking[1]["player"].id == 1 and ranking[1]["title"] == "优秀孵蛋小能手")
	_check("T8：失败者排末位并标记需努力",
		ranking[2]["player"].id == 0 and ranking[2]["title"] == "需要下节课继续努力")

	# —— 结果汇总 ——
	print("--------------------------------")
	print("通过 %d 项，失败 %d 项" % [_passed, _failed])
	print("==== 逻辑测试结束 ====")
	quit(1 if _failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  [PASS] " + name)
	else:
		_failed += 1
		print("  [FAIL] " + name)
