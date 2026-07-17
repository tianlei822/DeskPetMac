# DeskPet 个性时刻与视觉精修设计

日期：2026-07-15
分支：`feature/personality-moments-polish`

## 目标

在保留现有透明 `220×250` macOS 桌面宠物窗口、天气、羁绊、休息提醒和工作计时功能的前提下，让 Cat 与 Pauli 更精致、更有趣，也更像两只有明确性格的伙伴。

首轮核心是“情境化随机个性时刻”：宠物偶尔主动说一句短对白，并配合专属微表情或小动作。它必须安静、短暂，不激活应用、不抢键盘焦点、不发通知。

## 产品原则

- 视觉方向采用“迷你游乐场”：温暖、玩具感、轻松，但不引入复杂游戏系统。
- 主动频率保持克制：每次结束后随机等待 10–20 分钟。
- Cat 与 Pauli 必须无需看名称也能从语气和动作上区分。
- 现有功能优先级不变；个性时刻不能遮挡休息提醒或用户主动打开的界面。
- 尊重 macOS 的 Reduce Motion 设置。

## 角色语言

### Cat

Cat 慵懒、淘气、略带戏剧感。它会评论午睡、天气、用户的点击行为，以及自己对桌面的“管理工作”。语气温暖但略显傲娇。

示例：

- Focus: “Your keyboard seems busy. I’ll guard it.”
- Rain: “Wet outside. Excellent indoor planning.”
- Pat: “Acceptable. You may continue.”

### Pauli

Pauli 认真、好奇、容易开心。它会把桌面生活理解成小型任务：扫描天气、测量专注时间、汇报状态和庆祝小成果。

示例：

- Focus: “Productivity reading: impressively non-zero.”
- Rain: “Droplet count: many. Cozy level: optimal.”
- Pat: “Affection input received!”

首轮为每只宠物提供 12 条专属对白，共 24 条；general、weather、focus 和 interaction 四类各 3 条。最近出现过的 3 条不会立即重复。interaction 对白只在用户点击一个正在显示个性时刻的宠物时使用，普通连续 pat 不额外弹出随机对白。

## 交互模型

一个个性时刻包含三个阶段：

1. 调度：上一个时刻结束后，生成 10–20 分钟随机间隔。
2. 表演：到期后读取当前上下文，筛选候选对白并选择一条，显示约 3.5 秒，同时播放一个微动作。
3. 收尾：气泡淡出，宠物恢复普通 idle 动画，然后重新安排下一次。

以下状态会让本次触发静默跳过并重新安排：

- 宠物正在睡觉；
- 休息提醒正在显示；
- 用户打开了状态、宠物选择或设置界面；
- 天气正在刷新；
- 舞蹈或另一个个性动作正在运行。

用户在个性时刻中点击宠物时，不叠加第二个气泡。现有 pat 行为继续执行，同时当前时刻转为或结束为适合该角色的 interaction 回应。

## 模块边界

### `Sources/DeskPetCore/PersonalityMoment.swift`

新增纯数据与纯逻辑类型：

- `PersonalityMoment`：稳定 `id`、`petKind`、`context`、`pose`、`line` 和选择权重；
- `PersonalityPose`：共享的语义姿态，例如 `peek`、`perk`、`stretch`、`proud`；
- `MomentContext`：宠物、天气、专注进度、近期交互信息，以及由 ViewModel 组装的 `isPresentationBlocked` 状态；
- `PersonalityMomentSelector`：根据上下文、排除列表和注入的随机源筛选并选择时刻；
- 调度间隔生成逻辑：保证结果位于 10–20 分钟。

Core 层不依赖 SwiftUI、AppKit、计时任务或 `UserDefaults`。

### `Sources/DeskPetMac/PetViewModel.swift`

ViewModel 负责：

- 启动和取消个性时刻调度任务；
- 组装当前 `MomentContext`；
- 维护最近 3 个 moment ID；
- 发布 `activePersonalityMoment`；
- 将睡眠、提醒、设置、刷新和动作冲突合并为 `isPresentationBlocked`，交给 Core 选择器返回 `nil`；
- 约 3.5 秒后清除时刻并安排下一次。

计时状态和最近历史不持久化。应用重启后自然开始新的调度周期，不新增迁移或存储键。

### `Sources/DeskPetMac/PetWindowView.swift`

新增独立 `PersonalityBubble`，并将 `PersonalityPose` 传入 Cat / Pauli 绘制视图。显示优先级固定为：

1. `BreakBubble`；
2. 用户主动打开的状态、刷新或设置界面；
3. `PersonalityBubble`；
4. 无气泡 idle 状态。

个性时刻不会调用 `NSApp.activate`、通知服务或声音 API。

## 视觉精修

### Cat 耳朵

现有耳朵轮廓和同步旋转将替换为更自然的结构：

- 宽耳根从头部后方连接，并与头部形成清晰遮挡；
- 外耳采用柔和三角轮廓和圆润尖端；
- 增加内耳色块与轻微高光，让转动方向清晰；
- 左右耳拥有独立的相位、角度和响应幅度；
- idle 使用轻微不对称，好奇时一只耳朵先竖起，玩闹时使用相反方向的弹性跟随。

### 表情与姿态

- Cat 增加 cheek、wink、squint 和 alert 变化；
- Pauli 使用眼屏、指示灯、天线和侧舱变化表达相同的语义姿态；
- 共享 `PersonalityPose` 只表达意图，每只宠物独立解释绘制方式。

### 气泡与控制条

- 个性对白使用温暖的 speech-tail 气泡，与状态信息气泡区分；
- 优化阴影、圆角和文字层级，保持透明窗口上的可读性；
- 控制按钮统一视觉尺寸，并精修 hover / pressed 的 spring 反馈；
- 不改变窗口尺寸和现有快捷键。

## 数据流

```text
random 10–20 min timer
  -> PetViewModel builds MomentContext
  -> conflict guard
  -> PersonalityMomentSelector filters by pet/context/recent IDs
  -> weighted random selection
  -> activePersonalityMoment published
  -> PersonalityBubble + pet-specific pose rendered
  -> clear after ~3.5 sec
  -> schedule next timer
```

如果候选集合为空、任务被取消或显示期间出现更高优先级状态，系统静默结束当前流程并安排下一次，不向用户展示错误。

## 可访问性

- `PersonalityBubble` 提供可读的 accessibility label；
- Reduce Motion 开启时仍显示对白，但取消明显位移、倾斜和大幅弹性动画；
- 现有按钮的 accessibility label / help 保持不变；
- 动画不使用闪烁或声音。

## 测试与验收

自动测试覆盖：

- Cat、Pauli 只能选择各自的专属对白；
- weather、focus 和 interaction 上下文正确筛选候选；
- 最近 3 条被排除；
- 调度间隔始终位于 10–20 分钟；
- `isPresentationBlocked` 为真时选择器返回 `nil`；
- 所有现有 Core 测试继续通过。

视觉和交互验收：

- Cat 耳根自然连接头部，左右耳独立响应；
- 个性时刻不激活应用、不抢焦点、不发通知；
- 气泡约 3.5 秒后自动消失；
- 休息提醒和用户主动界面始终优先；
- Reduce Motion 下保留对白并取消明显位移动画；
- Cat 与 Pauli 的语气和动作可明确区分；
- `swift test`、`swift build` 和 `scripts/package-app.sh` 全部成功。

## 不在范围内

- 任务、连续签到或每日奖励；
- 收集品、货币或商店；
- 需要持久化的复杂情绪值；
- 新权限、网络请求或后端；
- 窗口尺寸调整、快捷键变更或无关重构。
