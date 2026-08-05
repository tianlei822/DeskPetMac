# DeskPet 鲜活桌面伙伴路线

日期：2026-08-03（更新于 2026-08-05）
分支：`feature/pet-presence-foundation`

## 核心判断

DeskPet 已经具备天气、自治、羁绊、眼神跟随、尾巴、拖拽惯性、点击组合、睡眠和个性对白。下一阶段的重点不是继续堆叠独立功能，而是让这些能力形成连续、可信、有因果关系的生命体验。

产品目标是把当前“精致、会动的悬浮组件”推进为“安静地生活在桌面上、能感知并记住用户的伙伴”。

## 实施状态

截至 2026-08-04，首轮工程化切片已落地：

| 阶段 | 状态 | 已落地 | 后续重点 |
| --- | --- | --- | --- |
| P0.1 | 已完成 | pose 注册、视觉缩放、睡姿校正、接触阴影 | 用正式统一 rig 复核每帧足底线 |
| P0.2 | 已完成增强 | 屏幕边缘气泡布局、主体避让、menu bar 控制层；Cat/Pauli/Dog 独立头部 anchor 驱动 speech tail；顶部受限时 personality speech 自动切换左右侧挂布局 | 在实体多屏与不同 menu bar 配置下继续 QA |
| P0.3 | 已完成增强 | non-activating panel、轮廓 hit mask、稳定显示器 UUID、旧 ID 迁移、多屏独立 anchor、分辨率变化与拔屏安全回落 | 在实体多屏、全屏 Space 与 Stage Manager 下继续 QA |
| P0.4 | 已完成增强 | 12/30/60 fps 角色分级、天气按景深 8/12/18/24 fps、Reduce Motion 8 fps、遮挡暂停；完成 idle、stormy、连续互动三组 5 分钟同机 CPU/RSS/Energy Impact 基线；建立 1638 组合视觉矩阵、81 场景常规离屏渲染、完整 PNG 导出及紧凑视觉基线门禁 | 在远端 macOS CI 校准容差，并在完整统一 atlas 替换后重新审定基线 |
| P1 | 关键动作链持续增强 | `PetActivity` 优先级图、可中断 root motion、边缘转向、同相 stride、落脚保持；locomotion、自主 idle gesture、pat/boop/scratch/swipe 与四类关系动作已切换为每只宠物单一 canonical `base.png` 驱动的分层 2D rig；程序化重心连续驱动蓄力、转身、减速、停步、idle 微动作、触摸承重与关系身体语言；idle 返回使用可中断苏醒链 | 在具备分层源图后扩展眼睑/耳部/手部局部表达，并逐步统一其余非拓扑 personality pose；获得源模型后离线输出正式共享相机/灯光 atlas |
| P2 | 核心互动已完成增强 | 空间点击、boop、nuzzle、scratch、快速滑动、拖窗仲裁；触摸反馈统一消费位置、速度、被中断活动、stormy mood、熟悉度、bond 与角色语气；光标接近使用眼睛/耳部或传感器/头部/身体分阶段注意力；三角色专属玩具、六阶段投喂链、可中断散步、休息仪式、无气泡自然苏醒、Quiet Mode、默认关闭的短音效与触觉 | 实机微调手势阈值 |
| P3 | 本地关系闭环已完成增强 | 每宠物独立 bond、偏好、昵称、近期对白、节律、熟悉度；记忆参与自治动作、克制的主动关系提示；偏好驱动的 invite-touch/lean-close/shared-sway/anticipate-play 已接入 canonical rig；包含按离开时长/熟悉度分层的角色专属重逢仪式 | 在可编辑分层源图可用后扩展耳、眼睑、尾和手部的关系专属局部表达 |

详细验收矩阵见 `docs/quality/desk-pet-presence-verification.md`。

2026-08-03 第二轮补充：

- 新增 `PetStrokeGestureResolver`，按角色耳后/下巴区域、位移速度和方向区分 scratch、swipe 与无效拖动；
- 投喂从即时粒子替换为 `tossing -> watching -> approaching -> sniffing -> eating -> satisfied`，奖励在进食阶段才结算；
- root motion 的窗口位移与 sprite stride 共享同一相位，足部接触区间位移门槛 `< 2 px`；
- 依据实际 `1254 × 1254` alpha bounds 校准 18 个 walk frame，渲染足底线与 idle 的误差 `< 0.25 pt`；
- `familiarity`、`preferredInteraction` 与 `dailyRhythm` 已进入自治状态和主动动作选择，不再只是持久化展示字段；
- 新增默认关闭、Quiet Mode 强制静音的角色合成短音效，以及基于熟悉度、节律和偏好的无压力主动提示；
- 恢复应用级键盘命令，补齐 VoiceOver 自定义动作，并自动解码验证 3 个角色共 51 个正式 PNG 资源；
- 静止 hover 不再常驻 60 fps；角色 idle 降至 12 fps，慢速云/雾为 8 fps，降水按景深使用 12/18/24 fps；短时实测由约 10–19% CPU 降至 5.6–6.5%；
- 新增拖窗意图门槛：快速 swipe、小范围 scratch、nuzzle 不移动窗口，只有持续至少 0.28 秒且位移至少 28 pt 的非 scratch 手势才激活拖窗。
- 新增 `scripts/measure-performance.sh` 和 release-only 诊断覆盖；同机 5 分钟基线为 idle `4.37% CPU / 4.93 Energy Impact`、stormy `9.16% / 10.07`、连续互动 `5.41% / 5.93`，三组 RSS 均无持续上升趋势。

2026-08-04 第三轮补充：

- Cat、Pauli、Dog 各新增 `anticipate`、`turn`、`settle` 三张同源身份约束关键帧，资源总数由 51 增至 60；
- root motion 明确拆分为 `notice -> anticipate -> turn -> walk -> slow -> settle`，左向移动会镜像方向性关键帧；
- `turn` 作为步态淡入桥，`settle` 作为步态淡出桥，避免动作链中途闪回 idle；
- 依据实际 `1254 × 1254` 源图 alpha bounds 对 18 个 walk frame 和 9 个 transition frame 统一足底线，渲染误差 `< 0.25 pt`；
- 新素材生成、抠图和人工检查记录见 `docs/quality/transition-asset-provenance.md`。
- 新增用户主动散步入口：menu bar 控制层、`DeskPet` 应用菜单、右键菜单与 VoiceOver 均可触发；`⌘G` 为键盘入口，重复触发会安全替换路线，pat/dance 等直接互动可立即中断。
- 新增 `PetHeadAnchor` 与共享 `PetBubbleGeometry`：人格气泡固定 194 pt 宽，tail 在 leading/center/trailing 三种屏幕边缘布局下均指向当前角色头部；窗口、角色画布、气泡宽度和 padding 不再各自维护魔法数字。

2026-08-04 第四轮补充：

- 新增 `PetVisualSnapshotCase`，完整枚举 3 pets × 10 states × 7 weather × 3 wallpaper × 2 motion settings，共 1260 个稳定命名组合；
- 常规测试离屏渲染 72 个轴向代表场景，覆盖每只宠物的全部核心状态，以及全部天气、壁纸和 Reduce Motion 组合；
- `petRenderTimeOverride` 冻结角色、受光和天气粒子时间，确保同一视觉用例输出确定性 PNG；
- 新增 `scripts/export-visual-snapshots.sh`，按需导出完整 1260 张 `260 × 290` RGBA PNG，且拒绝覆盖已存在的同名产物；
- 完整矩阵人工抽查发现深色壁纸上的人格气泡文字对比度不足，已改用系统 `.primary` 语义色并加入像素级回归测试。

2026-08-04 第五轮补充：

- 新增 `PetRootTransitionMotion`，在不追加独立 pose 图片的前提下，为 notice、anticipate、turning、slowing、settling 建立连续重心姿态；
- anticipate 会压低身体、扩大接触阴影并向反方向蓄力；turning 沿小幅抬升弧线恢复站姿；slowing 前倾吸收惯性；settling 以克制的回弹回到 neutral；
- 左右方向共享同一标量曲线并严格镜像水平位移、倾角和阴影偏移，Reduce Motion 下完全回退 neutral；
- 角色缩放、位移、倾角与接触阴影消费同一个 `PetRootTransitionPose`，避免身体重心变化时阴影滞后；
- 新增 3 pets × 2 directions × 7 phases 共 42 帧 root-motion 离屏序列测试与按需导出，已人工抽查三个角色的 anticipate、turn、settle 构图。

2026-08-04 第六轮补充：

- 为完整 1260 组合建立 `12 × 14` RGB 分块指纹，每个场景保留 504 字节结构特征；入库 JSON 约 1.08 MB，无需保存约 106 MB 的全量 PNG；
- 基线严格校验用例名称、网格尺寸和签名字节数，并以平均绝对误差 `<= 0.025`、最大分块误差 `<= 0.30`、变化分块比例 `<= 0.12` 判断视觉回归；
- 新增真实离屏渲染的单分块突变测试，证明门禁能够拒绝局部明显变化，同时允许受控的微小像素漂移；
- `scripts/verify-visual-baselines.sh` 只读比较当前 1260 个渲染结果；更新必须显式执行 `scripts/update-visual-baselines.sh --accept-current-rendering`，避免测试过程悄悄覆盖基线；
- 新增 PR/main CI，并将视觉基线验证接入 tag 发布流程；远端 `macos-14` runner 尚待首次实际运行确认跨主机容差。

2026-08-04 第七轮补充：

- `PetBubblePlacement` 新增 `sideLeading`、`sideTrailing`，窗口顶部余量不超过 `max(24 pt, 18% window height)` 时，短 personality speech 自动挂到水平空间更充足的一侧；
- 侧挂气泡采用 `112 × 76 pt` 纵向紧凑构图，tail 从靠近角色的 leading/trailing 边缘向头部伸出，并按各角色 head anchor 校准垂直落点；
- 角色场景向气泡反方向让位 24 pt，布局测试确保头部 anchor 与气泡主体至少相隔 24 pt，190 pt artwork 仍完整位于 260 pt 窗口内；
- reminder 与 status 含交互控件或完整信息，始终保留 194 pt 上方布局，不因靠近 menu bar 被压缩；
- 新增 Cat、Pauli、Dog × leading/trailing 共 6 个离屏渲染与 `scripts/export-side-bubble-snapshots.sh`，已人工复核文字、tail、头部和足底均无裁切。

2026-08-04 第八轮补充：

- 长工作提醒从“姿势与气泡同时出现”改为 `idle -> stretching -> prompting`：角色先独立保持约 1.2 秒 stretch pose，再平滑下移并显示提醒气泡；
- 只有进入 prompting 后才写入 `lastReminderAt` 并发送系统通知；若准备阶段被 pat、dance、treat 等直接互动打断，不消耗提醒冷却，后续工作采样可自然重试；
- Quiet Mode、窗口隐藏、睡眠或正在进行直接互动时不会强行启动准备阶段；准备期间进入这些状态会安全回到 idle；
- 视觉矩阵新增无气泡 `break-stretch` 核心状态，由 10 states / 1260 场景扩展为 11 states / 1386 场景，紧凑基线同步更新至 1386 条；
- 新增 Cat、Pauli、Dog 的 stretching/prompting 共 6 张阶段图及 `scripts/export-break-ritual-snapshots.sh`，已人工复核动作因果、气泡下移、按钮与足底构图。

2026-08-04 第九轮补充：

- 生产界面读取 SwiftUI 公共 `colorSchemeContrast`，系统开启“增强对比度”后，人格、提醒、状态气泡与 menu bar 控制层会自动采用更强的边界、材质层次和辅助文字；
- 提醒按钮在增强模式下改为深色标签与明确轮廓；宠物选择除更强填充和描边外增加勾选标记，不再只依赖颜色表达选中状态；
- 测试环境提供仅用于确定性渲染的 contrast override，不使用 SwiftUI 私有接口，也不改变生产环境对系统设置的读取；
- 新增 4 个 token/视觉自动化用例，以及 personality、reminder、status、menu 的 standard/increased 共 8 张代表图和 `scripts/export-accessibility-contrast-snapshots.sh`；代表图已人工复核文字、边界、按钮和选中语义。

2026-08-04 第十轮补充：

- 显示器位置键由易变化的 `NSScreenNumber` 升级为系统 `CGDisplayCreateUUIDFromDisplayID` 提供的稳定 UUID；旧数字 ID anchor 会在首次命中时无损迁移，已有用户位置不会被主动清空；
- 新增纯逻辑 `PetWindowPlacementResolver`：优先恢复上次显示器；显示器消失时先选择窗口当前重叠屏，再回落主屏；目标屏幕有独立记忆时优先使用，否则继承原屏幕归一化 anchor；
- 分辨率、visible frame 和 menu bar 变化继续通过归一化 anchor 重算安全坐标，窗口始终约束到可见区域；显示器移除后保留相对桌面方位，而不是跳回固定默认点；
- 拖窗位置持久化增加 180 ms 防抖，减少连续 `UserDefaults` 写入；屏幕参数变化会先取消待写任务，避免系统自动搬窗覆盖原屏幕记忆；
- 新增稳定身份、旧 ID 迁移、分辨率缩放、拔屏继承、目标屏独立记忆和重叠屏选择共 8 个自动化用例。

2026-08-04 第十一轮补充：

- 补齐路线图中尚缺的触觉通道：pat、boop、scratch、swipe、玩具命中和进食满足会请求一次克制的系统触控板反馈；被动 greeting 只保留可选短音，不敲击触控板；
- 使用公开 `NSHapticFeedbackManager.defaultPerformer`，按 Apple 语义选择 `.generic` 并在 `.drawCompleted` 与画面变化同步；无兼容触控板、用户偏好或辅助功能不允许时由系统自然抑制；
- 触觉与既有声音共用 `Interaction Feedback` 开关，继续默认关闭；Quiet Mode 同时抑制声音与触觉，不新增权限或后台监听；
- 声音与触觉播放器通过轻量协议注入测试，新增 5 个用例验证 cue 策略、默认关闭、双通道同步、Quiet Mode 和无打扰 greeting；menu bar 文案同步改为 `Sound + trackpad tap · opt-in`。

2026-08-04 第十二轮补充：

- scratch/swipe 从只比较 `start/end/duration` 升级为消费完整 `DragGesture` 轨迹摘要；真实抓挠即使往返后回到起点附近，也不会再因净位移过小被丢弃；
- 新增 O(1) `PetStrokePathTracker`，只累计起终点、质心、总路程、持续时间和明显反向次数，不保存无限采样数组；长时间拖动不会造成轨迹内存增长；
- swipe 继续要求净位移、速度和至少 `0.72` 的路径效率，往返路径不会伪装成快速滑动；scratch 则要求耳后/下巴起点与轨迹质心落在同一触摸区，并限制总路程、平均速度与持续时间；
- 保留原有端点 resolver 作为兼容入口，并由它构造单段 path 复用同一判定；SwiftUI 层已改为在 `onChanged` 连续采样、`onEnded` 一次结算；
- 新增往返 scratch、分段直线 swipe、躯干往返乱划和微小指针抖动 4 个自动化用例，既有 scratch/swipe/拖窗用例继续通过。

2026-08-04 第十三轮补充：

- 新增纯逻辑 `PetGreetingRitualPlanner`，把首次见面、短时返回、普通回归和久别重逢映射为明确的展示层级、角色语气、姿势、持续时间、亲密脉冲和爱心节奏；
- 短时返回继续使用约 0.95 秒轻提示，不用大气泡或爱心；普通回归使用一个克制爱心，熟悉宠物的久别重逢延长至 3.8 秒并使用两阶段爱心；
- Cat、Pauli、Dog 分别保留慵懒、理性和热情的重逢台词与姿势；首次见面会使用每只宠物保存的昵称，但不会制造虚假的高亲密反馈；
- 重逢序列接入统一 `PetActivity` personality 状态，pat、dance 等直接互动和 Quiet Mode 可立即取消尚未发生的爱心与姿势，不会在用户已经开始新动作后继续播放；
- 新增 5 个规划器测试、3 个运行时集成测试，以及三角色 × 首次/普通/久别共 9 张离屏代表图与 `scripts/export-greeting-ritual-snapshots.sh`；代表图已人工复核文字、tail、角色姿势和足底构图。

2026-08-04 第十四轮补充：

- idle monitor 检测到用户从睡眠状态返回后，不再把 `isSleeping` 瞬间切回站立，而是播放无气泡的 `sleep -> stretch -> orient -> ready` 苏醒链；
- 新增 `PetWakeRitualPlanner` 与 `PetWakeRitualTiming`：标准模式保持约 `0.82 s` 伸展和 `0.62 s` 定向，Reduce Motion 跳过大幅伸展，只保留约 `0.32 s` 的短定向；
- `PetActivityKind.waking` 以 25 级优先级位于 sleep 与显式 personality 之间；苏醒期间阻止自治散步、关系提示和休息提醒抢占，但 pat、dance、换宠等直接动作会立即取消剩余阶段；
- sleep monitor 的阈值转换抽为可测试的 `observeIdleState`，自动化直接证明 `91 s` idle 进入 sleep、用户返回至 `0 s` 后触发 wake，而非仅测试独立动画函数；
- 视觉矩阵新增 `wake-stretch`、`wake-orient` 两个无气泡核心状态，由 11 states / 1386 场景扩展为 13 states / 1638 场景，常规轴向渲染由 75 增至 81，紧凑基线同步显式更新；
- 新增三角色 × sleep/stretch/orient 共 9 张阶段图及 `scripts/export-wake-ritual-snapshots.sh`；已人工复核动作因果、足底、阴影、无气泡与无裁切，整身切换继续使用既有 0.24 秒单层 opacity bridge。

2026-08-04 第十五轮补充：

- 新增纯逻辑 `PetTouchResponsePlanner`，将 pat、boop、scratch、swipe 收敛到同一上下文反馈入口；保持手势判定和关系积分不变，补齐路线图要求的触摸位置、速度、当前活动、mood、bond 与角色差异；
- scratch 的耳后/太阳穴与下巴继续给出不同反应；swipe 的归一化强度分为 subtle/warm/delighted，高速输入同时驱动画面位移、台词强度，并仅在熟悉宠物上克制地增加一个爱心；
- 触摸睡眠或正在苏醒的宠物时，会使用 Cat/Pauli/Dog 各自的刚醒语气；stormy mood 使用短安抚反馈；`companion` 以上或熟悉度 `>= 0.55` 时使用记住触摸习惯的关系台词；
- 普通单次 pat 继续只显示状态，不新增文字噪音；只有 5 连击、stormy、刚睡醒或熟悉关系等有意义上下文才显示短 callout；
- `PetInteractionCallout` 从窗口内联样式抽为生产组件，限制为 124 pt、最多两行并支持轻微缩放；组件响应系统 Increase Contrast，在增强模式改用主文字色和更强边界；新增 6 个规划器测试、4 个运行时集成测试、2 个视觉测试和 `scripts/export-touch-callout-snapshots.sh`；
- Cat、Pauli、Dog 的 standard/increased 共 6 张最长熟悉触摸 callout 已人工复核，确认换行、对比度差异、胶囊边界和右侧偏移均完整位于 260 pt 画布内。

2026-08-04 第十六轮补充：

- 新增纯逻辑 `PetAttentionTimeline`，将光标注意力拆为 eye -> ear/sensor -> head -> body 四段；Dog 更快响应，Cat 居中，Pauli 更审慎，完整跟随约在 `0.52...0.62 s` 内完成；
- 新增 O(1) `PetAttentionTracker`：进入既有 480 pt 注意半径后保留起始时刻和当前归一化方向，离开后清零，重新进入会从眼神先行重新开始；非法坐标与时间不会污染状态；
- 窗口外接近与窗口内 hover 共用同一时序；光标跨入宠物窗口时延续已有阶段，不回跳到 base。真实图片角色先在 base 上移动眼神，达到 head 阶段才切好奇姿势，最后才加入整体重心跟随；矢量回退同步延迟耳部/传感器和身体动作；
- Reduce Motion 不播放分阶段位移动画，直接使用稳定注意姿态；自治动作、天气反应和直接互动的既有优先级保持不变；
- 新增 6 个时间线/重入测试、2 个生产视觉测试及 `scripts/export-attention-response-snapshots.sh`；Cat、Pauli、Dog 的 eye-lead/head-follow/settled 共 9 张代表图已人工复核，确认动作因果、足底、阴影和画布边界完整。

2026-08-04 第十七轮补充：

- `PetRelationshipCue` 不再只返回通用 personality pose 和台词，同时携带 `PetRelationshipGesture`；pat/boop/scratch/swipe 映射 invite-touch，nuzzle 映射 lean-close，dance 映射 shared-sway，treat/toy 映射 anticipate-play；
- 新增 `PetRelationshipGestureMotion`，用 3.5 秒 enter/hold/settle 包络叠加偏好驱动的身体重心；Cat 克制侧身、Pauli 精确小幅倾斜、Dog 更热情，四类动作分别强调侧身邀请、靠近放松、共同摇摆和抬升期待；
- relationship gesture 进入统一 `PetActivity`，沿用 personality 的 30 级优先级、3.5 秒展示、30 分钟冷却与直接互动中断，不新增旁路状态；Reduce Motion 保留静态 personality 姿势而不播放程序化位移；
- 图片角色与矢量回退均消费关系动作；图片角色的接触阴影会在期待抬升时同步收窄，避免足底离开但阴影不变；普通 personality、问候和触摸反馈没有 gesture，现有视觉基线保持原样；
- 新增 6 个映射/时序/剪影/活动传播测试、2 个生产视觉测试及 `scripts/export-relationship-gesture-snapshots.sh`；三角色 × 四类动作共 12 张代表图已与同台词、同 pose、无 gesture 对照，人工复核气泡、动作可辨识度、足底、阴影和画布边界。

2026-08-04 第十八轮补充：

- Cat、Pauli、Dog 的 `anticipate`、`turn`、`settle` 从各一张关键 pose 扩展为每段 4 帧连续 clip，共新增 36 张 alpha PNG，正式资源总数由 60 增至 96；
- 新增 `PetTransitionArtworkFrame` 与 `PetTransitionArtworkResolver`：按 `phaseProgress` 在相邻帧间插值；clip 缺帧时先回退旧 transition pose，再回退 base；Reduce Motion 保持既有静态路径；
- walking 前桥使用 `turn4`，slowing/settling 入口使用 `settle1`，避免多帧 clip 接入后重新闪回旧 pose；预加载异步覆盖 clip，但旧 motion set 完整性仍独立判断；
- 依据 `alpha >= 16` 的真实 bounds，对 32 张 `623 × 623` 与 4 张 `627 × 627` 资源逐帧注册，三角色 36 帧与各自 base 足底线误差均 `< 0.25 pt`；
- 新增 atlas 切片与 alpha bounds 报告脚本、7 个 clip 选择/回退/注册测试、36 张生产离屏渲染和 `scripts/export-transition-clip-snapshots.sh`；13 张代表图已人工复核无裁切、白缝、色键残留和明显身份漂移；
- 完整测试通过 325 tests / 73 suites，1638 场景紧凑视觉基线显式比较通过；release 包成功解码并包含 96 张 PNG，其中 36 张位于 `RootMotion/`。

2026-08-04 第十九轮补充：

- 新增 `PetUnifiedRigMotion`、`PetRigLayerMask` 与 `PetUnifiedRigArtwork`：Cat、Pauli、Dog 使用相同 joint pose 契约，以各自唯一 `base.png` 作为 locomotion 的全部纹理来源；
- 前侧、后侧与后肢按角色 silhouette 分层，步态按同一 stride phase 交替摆动；anticipate、turning、slowing、settling 复用同一关节层并与既有重心、窗口位移和接触阴影同步；Cat/Dog 尾巴继续使用同一 base 的双段独立层；
- production renderer 的 root-motion 与自主 walk 不再解析 `walk1...6` 或 `RootMotion/*` 整身图；旧资源保留作 provenance/回退研究，但从 runtime preload 集合移除，单宠预加载由 26 张降为 5 张尚未 rig 化的表达姿势；
- 首轮离屏审图发现关节 mask 白缝后，新增 cutout overlap 缺陷测试并改为较小 body cutout 覆盖移动层边缘；修复后人工复核三角色左右 42 帧动作链与 6 张相反 gait 极值，无白缝、身份跳变或画布裁切；
- 新增 7 个 rig policy/joint/mask/cutout 测试、2 个生产视觉测试与 `scripts/export-unified-rig-snapshots.sh`；Reduce Motion 继续使用 neutral/static 路径，sleep/stretch 等拓扑变化姿势保持既有资源。
- 完整测试通过 334 tests / 74 suites，1638 场景紧凑视觉基线在人工审定后显式重建并复验通过；release app 的严格 codesign、Info.plist、arm64 可执行文件和 96 张资源解码均通过，更新后的应用已重启运行。

2026-08-04 第二十轮补充：

- `PetUnifiedRigPolicy` 将 `idleAction1`、`idleAction2`、`lookAround`、`perkUp` 纳入 canonical rig；四类动作不再切换 `idleAction*.png`、`peek.png` 或 `perk.png`，角色脸型、毛色、材质、镜头和足底注册在动作前后保持同源；
- `PetUnifiedRigPose` 增加 head joint，微动作以同一 enter/hold/settle progress 驱动头部、前肢/腿和后肢重心。Pauli 的刚性颈部实际消费独立 head layer；Cat/Dog 缺少头部背后纹理，保留完整头部 silhouette，并通过整身倾角、前爪换重和尾巴表达方向，避免伪造遮挡区像素；
- runtime preload 从尚未 rig 化的 5 张表达图进一步收敛为仅 `stretch` 1 张；旧 idle/peek/perk 资源继续留在 bundle 作 provenance 与特殊 personality pose 兼容，不参与自主 idle 动作渲染；
- 首轮 21 张离屏图发现 Cat/Dog 头颈 mask 在侧倾时出现背景缝与反向残影；新增至少 4 px cutout overlap 回归门槛，并采用角色拓扑感知的 head articulation 策略，复审 Cat、Pauli、Dog × 7 个 idle gesture 阶段后无白缝、残影或裁切；
- 新增 4 个 idle rig policy/joint 行为测试、2 个离屏视觉/导出测试及 `scripts/export-idle-rig-snapshots.sh`；Reduce Motion 和拓扑变化的 `stretch` 继续走原有静态/显式姿势路径。
- 完整测试通过 340 tests / 75 suites，1638 场景紧凑视觉基线只读复验通过；release app 的严格 codesign、Info.plist、arm64 可执行文件及 96 张 PNG 解码检查通过，更新后的应用已重启运行。

2026-08-05 第二十一轮补充：

- 新增 `PetUnifiedRigDirectTouchMotion`，把既有 `PetAnimationDynamics.patPose` 的同一时序与 combo 能量投射到 head/front-leading/front-trailing/rear joint；触摸峰值时两只前爪向外承重、身体上抬，Pauli 刚性头部轻微下沉，动作起止严格回到 neutral；
- full-motion 的 pat 不再切换 `pat.png` 整身图，`RealisticPetBody` 以 canonical `base.png` 同时消费关节姿态、既有整身重心、接触阴影和受光。Reduce Motion 继续使用静态 `pat.png` 提供无位移反馈，拓扑变化的 `stretch` 保持显式资源；
- pat、boop、scratch、swipe 已验证共用同一个 `affectionPulse` 渲染入口；scratch 继续叠加压低/轻倾，swipe 继续按方向和强度叠加短促位移，因此触摸语义保留但角色身份、毛色、材质和镜头不再跳变；
- combo 1/3/5 直接复用核心动作能量，逐级增强前爪承重，所有采样 joint 均保持有限且位于 `|x| <= 5`、`|y| <= 7`、`|rotation| <= 12°`；
- 新增 5 个 policy/joint/触摸链测试、2 个离屏视觉/导出测试和 `scripts/export-direct-touch-rig-snapshots.sh`；三角色 × pat enter/peak、combo 3/5、scratch、swipe-right/up 共 21 张图已人工复核，无关节白缝、轮廓残影或画布裁切。
- 完整测试通过 347 tests / 76 suites，1638 场景紧凑视觉基线只读复验通过；release app 的严格 codesign、Info.plist、arm64 可执行文件及 96 张 PNG / 36 张 `RootMotion` PNG 检查通过，更新后的应用已重启运行。

2026-08-05 第二十二轮补充：

- 新增 `PetUnifiedRigRelationshipMotion` 与 relationship artwork policy：invite-touch、lean-close、shared-sway、anticipate-play 复用既有 3.5 秒 enter/hold/settle 包络，并将同一身体重心投射到 head/front-leading/front-trailing/rear joint；
- invite-touch 抬起单侧前爪发出邀请，lean-close 以双前爪稳定靠近，shared-sway 交替换重，anticipate-play 在身体上抬时向外撑稳；Pauli 的刚性颈部同步消费 head joint，Cat/Dog 继续保留完整头部 silhouette 以避免伪造遮挡纹理；
- full-motion 关系提示不再切换 `perk.png`、`peek.png` 或 `proud.png` 整身图，生产 `RealisticPetBody` 以 canonical `base.png` 同时消费 joint、整身重心、接触阴影、尾巴与受光；Reduce Motion 继续显示原有静态 personality pose，不播放关节位移；
- 非关系 personality、苏醒、投喂和 reminder 的显式姿势优先级保持不变；runtime preload 仍只有拓扑变化的 `stretch` 1 张，旧 perk/peek/proud 资源保留用于 Reduce Motion、普通 personality 与 provenance；
- 新增 4 个 relationship rig policy/joint 安全测试，并把生产视觉序列由 12 张 hold 代表图扩展为三角色 × 四动作 × enter/hold/settle 共 36 张；全部 hold 和 enter/settle 阶段已复核，无关节白缝、轮廓残影、身份跳变、气泡或画布裁切。
- 完整测试通过 352 tests / 76 suites，1638 场景紧凑视觉基线只读复验通过；release app 的严格 codesign、Info.plist、arm64 可执行文件及 96 张 PNG / 36 张 `RootMotion` PNG 检查通过，更新后的应用已重启运行。

## 产品原则

- 空间真实：身体、脚步、阴影、窗口位移和桌面边界必须互相一致。
- 动作连续：每次状态变化都有预备、主体动作和收尾，不依赖突然切图。
- 交互直接：优先让用户触摸、拖动、投掷和玩耍，减少控制按钮。
- 关系可见：关系通过距离、反应、主动行为和记忆表达，不只显示进度条。
- 安静克制：不抢焦点、不阻挡工作、不用签到或负面情绪制造压力。
- 尊重系统：Reduce Motion、能耗、键盘访问和多显示器行为始终是验收项。

## 当前基础

### 值得保留

- `DeskPetCore` 中确定、可测试的动作、自治、天气和羁绊逻辑；
- Cat、Pauli、Dog 三个清晰身份和不同语气；
- 背景、中景、前景天气层和角色局部受光；
- hover、pat、combo、dance、nuzzle、treat、drag 和 cursor gaze；
- 素材失败时的矢量回退；
- 完整的 Reduce Motion 降级路径。

### 当前剩余差距

- 仓库仍没有可编辑的 3D 源 rig；locomotion 已由单一 canonical base 的运行时分层 2D rig 统一，不再消费此前分别生成的 walk/transition 整身图，但尚不等同于共享 3D 骨骼、相机和灯光的离线 atlas；
- locomotion、自主 idle 表达、pat/boop/scratch/swipe 与四类关系动作的身体/肢体承重已统一到 canonical 2D rig；`stretch`、普通 personality、苏醒和投喂中的拓扑/表情姿势仍会使用独立整身图片。下一步需获得可编辑分层源图，把 Cat/Dog 眼睑/耳部与 Pauli 手部等更细的触摸和关系表情纳入局部层，再逐步迁移其余非拓扑 pose；获得源模型后仍应输出正式 atlas 才能完成全量美术签收；
- speech tail 已按角色头部 anchor 精确落点，顶部受限时 personality speech 已支持左右侧挂；侧挂切换仍需在不同 menu bar 位置与实体多屏组合下复核；
- scratch/swipe 已使用完整轨迹、路径效率、总路程和反向次数参与判定，并与整窗拖动保持确定性仲裁；不同触控板速度下的最终阈值仍需实机微调；
- 多显示器拓扑选择、分辨率变化、拔屏回落和旧 ID 迁移已有确定性自动化覆盖；真实拔插、全屏 Space 和 Stage Manager 仍需要实体环境矩阵 QA；
- 性能基线已覆盖首轮素材与渲染链；替换完整统一 sprite atlas 后需要在同机重新采样。
- 视觉矩阵已完成确定性渲染、完整导出以及 1638 场景紧凑结构基线自动比较；系统“增强对比度”已接入生产环境并完成 8 张确定性代表图验证；为控制仓库体积未入库逐像素 PNG golden，统一 atlas 替换时仍需人工审图后显式重建基线；远端 `macos-14` CI 尚待首次实际运行，系统设置真实切换仍需实体环境复核。

## P0：视觉与窗口基础

### P0.1 Pose 注册与接触阴影

为每个角色状态建立稳定的视觉注册信息：

- artwork scale 与垂直校正；
- ground alignment；
- shadow width、height 与 vertical offset；
- 后续可扩展的 content bounds、body pivot、eye anchors 和 hit mask。

首个切片先使用纯数据布局契约修正 upright/sleep 的视觉占比和阴影，保持现有资源与动作调度不变。

验收：

- 睡眠角色与阴影不再明显分离；
- Cat、Pauli、Dog 默认姿态的视觉高度更接近；
- base/blink 保持完全相同的注册值；
- 所有布局数值有限且处于安全范围；
- 资源缺失或未知名称回退到该宠物的默认布局。

### P0.2 气泡与控制层

- 气泡根据屏幕边缘选择左上、右上或侧面锚点；
- speech tail 指向宠物头部且不遮挡主体；
- 设置与宠物选择逐步迁移到 menu bar popover；
- 桌面角色窗口只保留直接互动反馈。

### P0.3 窗口语义

- 使用 non-activating panel，点击宠物不抢当前应用焦点；
- 透明像素点击穿透，仅角色 hit mask 与可见控件接收事件；
- 记住每块屏幕的安全位置；
- 处理屏幕移除、分辨率变化和全屏空间。

### P0.4 渲染预算

- 直接互动和快速 transition 可使用 60 fps；
- 普通 idle 使用 12 fps，自治/root motion 使用 30 fps；
- 慢速云雾使用 8 fps，降水按背景/中景/前景使用 12/18/24 fps；
- Reduce Motion 使用 8 fps 并静态化天气；
- 静止或遮挡时暂停无意义 Timeline；
- 建立 light/dark wallpaper、Reduce Motion 和能耗基线。

## P1：真实动作系统

### 统一动作图

将分散状态收敛为可中断的 `PetActivity` 和 animation graph：

```text
Context
  -> Needs / Memory
  -> BehaviorPlanner
  -> PetActivity + priority
  -> AnimationGraph
  -> WindowMotion + Renderer
  -> Feedback
  -> Memory update
```

每个动作明确进入、持续、退出、中断和恢复规则。

### 一致的角色 rig

- 不再继续追加互相独立生成的整身 pose PNG；
- 使用同一角色 rig、相机、灯光离线输出 alpha sprite atlas；
- 主循环目标为 12–18 fps；
- 眼睛、耳朵、尾巴、胸腔和 Pauli 关节保留独立层；
- 运行时继续保持原生轻量渲染，不要求完整 3D 引擎。

### Root motion

完整移动序列：

```text
notice target -> anticipate -> turn -> walk -> slow down -> settle/look back
```

脚步与窗口位移同步，首轮在屏幕安全范围移动约 60–160 px。站立脚接触期间的滑动误差应小于 2 px。

## P2：直接而有趣的互动

### 空间 hit zones

- 头部点击：pat；
- 鼻尖轻点：boop；
- 耳后或下巴拖动：scratch；
- 身体长按：nuzzle；
- 快速滑动：毛发、耳朵和身体跟随。

反馈同时考虑位置、速度、当前活动、情绪和 bond。

### 角色专属玩具

- Cat：激光点或羽毛棒；
- Dog：可投掷、追逐并叼回的小球；
- Pauli：扫描目标或能量节点。

投喂升级为物体轨迹：投出、注视、接近、闻、吃、满足，而不是按钮触发粒子。

### 被动互动

- 光标接近时先眼睛/耳朵响应，再转头；
- 用户从 idle 返回时自然苏醒；
- 长工作时先陪伴式伸展，再显示提醒；
- 夜间进入更安静的动作集；
- 提供 Quiet Mode 与默认关闭的短音效/触觉反馈。

## P3：长期伙伴关系

每只宠物独立保存：

```text
bond
lastSeenAt
preferredInteraction
recentMoments
dailyRhythm
trust/familiarity
currentMood
learnedName
```

关系主要通过行为表达：熟悉后的主动靠近、不同离开时长的迎接、偏好互动、关系专属动作和克制的共同回忆。

对白采用上下文模板、记忆变量、近期排除和冷却规则扩展组合性。首选本地、可控、安静的内容系统，不优先接入常驻 LLM 聊天。

## 验证矩阵

- 自动测试：布局元数据、动作优先级、root motion 边界、hit mask、每只宠物记忆隔离；
- 视觉快照：3 pets × 13 core states × 7 weather × light/dark/high-contrast wallpaper × Reduce Motion off/on；
- 真实窗口：气泡避让、透明点击穿透、不抢焦点、多显示器与全屏空间；
- 动作 QA：足部锁定、中断恢复、转向、停步、睡眠过渡；
- 性能：idle/天气/直接互动 CPU 与 energy impact；
- 可访问性：Reduce Motion、键盘操作、VoiceOver label 和 Quiet Mode。

## 暂不优先

- 更多天气粒子或天气层；
- 更多独立 AI pose 图片；
- 货币、签到、商店或惩罚性养成；
- 常驻聊天框或无边界 LLM 对话；
- 需要新权限的 active-window 附着行为。
