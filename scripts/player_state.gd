class_name PlayerState
extends Resource
## 单个鸡窝 / 单个孩子的运行时状态（对应策划文档第 4.1 节）。

enum PlayerStatus { NORMAL, HEN_LEFT, PAUSED, FAILED, COMPLETED }

@export var id: int = 0
@export var display_name: String = "小鸡窝"
@export var eggs: int = 5                        # 剩余鸡蛋数
@export var chicks: int = 0                      # 已孵出小鸡数
@export var hatch_progress: float = 0.0          # 当前蛋孵化进度 [0.0, 1.0]
@export var shield_seconds: float = 0.0          # 保护盾剩余时间
@export var buff_seconds: float = 0.0            # 加速 buff 剩余时间
@export var shield_active: bool = false
@export var buff_active: bool = false
@export var status: PlayerStatus = PlayerStatus.NORMAL
@export var completed_at_time: float = -1.0      # 通关时刻（用于排名），-1 表示未通关

## 派生属性：保住的成果（蛋 + 已孵小鸡）。
func total_survived() -> int:
	return eggs + chicks

## 是否为本轮出局（失败）。
func is_failed() -> bool:
	return status == PlayerStatus.FAILED

## 是否已通关。
func is_completed() -> bool:
	return status == PlayerStatus.COMPLETED

## 状态角标文字（空字符串表示不显示）。
func status_label() -> String:
	match status:
		PlayerStatus.HEN_LEFT:
			return "离窝!"
		PlayerStatus.PAUSED:
			return "暂停"
		PlayerStatus.FAILED:
			return "失败"
		PlayerStatus.COMPLETED:
			return "通关!"
		_:
			return ""
