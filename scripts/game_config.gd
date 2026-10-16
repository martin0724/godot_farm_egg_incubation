class_name GameConfig
extends Resource
## 全局数值配置（对应策划文档第 3 节）。
## 所有可调数值集中在此，方便老师 / 开发调整。

enum Mode { MODE_A, MODE_B }

# —— 基础数值 ——
const INITIAL_EGGS := 5                # 每人初始鸡蛋数
const TOTAL_CHICKS_TO_WIN := 5         # 通关所需小鸡数

# —— 孵蛋节奏（秒 / 颗）——
const MODE_A_SECONDS_PER_EGG := 300.0  # 模式 A：5 分钟 1 颗蛋
const MODE_B_SECONDS_PER_EGG := 480.0  # 模式 B：8 分钟 1 颗蛋

# —— 惩罚数值 ——
const EGG_STEAL_ON_LEAVE := 1          # 离座偷 1 颗
const EGG_STEAL_ON_NOISE := 2          # 吵闹偷袭偷 2 颗
const DISTRACTION_PAUSE_SEC := 10.0    # 轻微分心暂停孵蛋的时长（保留字段）

# —— 奖励数值 ——
const FEED_SPEED_BUFF_MULT := 2.0      # 投喂加速倍率
const FEED_BUFF_DURATION_SEC := 30.0   # 加速持续时间
const SHIELD_DURATION_SEC := 60.0      # 保护盾持续时间（期间免疫被偷蛋）
const ANSWER_INSTANT_EGGS := 1         # 举手答题直接孵化 1 颗蛋

@export var mode: Mode = Mode.MODE_A
@export var player_count: int = 20

## 当前模式下每颗蛋所需的孵化秒数。
func seconds_per_egg() -> float:
	return MODE_A_SECONDS_PER_EGG if mode == Mode.MODE_A else MODE_B_SECONDS_PER_EGG

## 模式的中文展示名。
func mode_label() -> String:
	return "模式A（快节奏 5 分钟/蛋）" if mode == Mode.MODE_A else "模式B（长课时 8 分钟/蛋）"
