# DeskPet Presence Verification

日期：2026-08-03（更新于 2026-08-05）

## 自动化门槛

- `swift test`
- `scripts/verify-visual-baselines.sh`
- `swift build -c release --product DeskPetMac`
- `git diff --check`
- `scripts/package-app.sh`
- `codesign --verify --deep --strict .build/release/DeskPetMac.app`
- `scripts/export-visual-snapshots.sh [output-directory]`（按需完整视觉导出）
- `scripts/export-root-motion-snapshots.sh [output-directory]`（按需导出 42 帧移动序列）
- `scripts/export-transition-clip-snapshots.sh [output-directory]`（按需导出 36 帧 transition clip）
- `scripts/export-unified-rig-snapshots.sh [output-directory]`（按需导出 6 个相反 gait 极值）
- `scripts/export-idle-rig-snapshots.sh [output-directory]`（按需导出 21 个统一 idle gesture 阶段）
- `scripts/export-direct-touch-rig-snapshots.sh [output-directory]`（按需导出 21 个统一 pat/combo/scratch/swipe 阶段）
- `scripts/export-side-bubble-snapshots.sh [output-directory]`（按需导出 6 个侧挂气泡场景）
- `scripts/export-break-ritual-snapshots.sh [output-directory]`（按需导出 6 个伸展/提醒阶段）
- `scripts/export-accessibility-contrast-snapshots.sh [output-directory]`（按需导出 8 个 standard/increased contrast 场景）
- `scripts/export-greeting-ritual-snapshots.sh [output-directory]`（按需导出 9 个首次/普通/久别问候场景）
- `scripts/export-wake-ritual-snapshots.sh [output-directory]`（按需导出 9 个 sleep/stretch/orient 苏醒场景）
- `scripts/export-touch-callout-snapshots.sh [output-directory]`（按需导出 6 个 standard/increased 最长上下文触摸 callout）
- `scripts/export-attention-response-snapshots.sh [output-directory]`（按需导出 9 个 eye/head/settled 光标注意力阶段）
- `scripts/export-relationship-gesture-snapshots.sh [output-directory]`（按需导出 36 个统一关系动作阶段）

仅在人工审定并明确接受当前视觉结果时更新基线：

```bash
scripts/update-visual-baselines.sh --accept-current-rendering
```

覆盖重点：pose 注册、气泡避让、稳定显示器身份、多屏独立 anchor、拓扑变化回落、hit mask、渲染 cadence、活动优先级、root motion、程序化重心连续性、stride/足底同步、分阶段光标注意力、空间交互、上下文触摸反馈、scratch/swipe、拖窗仲裁、玩具轨迹、六阶段投喂、默认关闭音效/触觉、Quiet Mode、每宠物记忆隔离、记忆驱动自治、分层重逢仪式、偏好驱动关系动作和正式图片资源解码。

## 视觉矩阵

每个组合检查主体不裁切、足底与阴影接触、气泡不遮头、天气前后景深度正确、文字可读：

| 维度 | 取值 |
| --- | --- |
| Pet | Cat、Pauli、Dog |
| State | idle、hover、pat、sleep、wake stretch、wake orient、dance、nuzzle、personality、break stretch、reminder、toy、root motion |
| Weather | sunny、cloudy、foggy、rainy、snowy、stormy、cozy |
| Wallpaper | light、dark、high-contrast wallpaper |
| Accessibility | Reduce Motion off/on；Increase Contrast 针对关键表面做 standard/increased 成对渲染；VoiceOver 单独做语义检查 |

自动化策略：

- `swift test` 常规执行 81 个轴向代表场景的离屏 AppKit 渲染，覆盖每只宠物的 13 个核心状态，以及全部天气、壁纸、Reduce Motion 组合；
- `PetVisualSnapshotCase.standardMatrix` 校验完整 1638 个组合的唯一、稳定文件名；
- `scripts/export-visual-snapshots.sh` 显式导出完整 1638 张 `260 × 290` RGBA PNG，默认写入被忽略的 `dist/visual-snapshots/<timestamp>/`；
- 渲染时钟固定为同一时间点，重复渲染同一用例必须得到相同 PNG 字节；
- `Tests/DeskPetMacTests/VisualBaselines/deskpet-visual-fingerprints.json` 为全部 1638 个场景保存 `12 × 14` RGB 分块指纹，文件约 1.41 MB；
- `scripts/verify-visual-baselines.sh` 以平均绝对误差 `<= 0.025`、最大分块误差 `<= 0.30`、变化分块比例 `<= 0.12` 做紧凑结构回归判定；该门禁不等同于逐像素 PNG golden，完整美术变更仍需人工审图；
- `PetAccessibilityContrastVisualTests` 成对离屏渲染 personality、reminder、status、menu 四类生产表面，确认 standard/increased 输出均有效且增强模式确实改变视觉；`scripts/export-accessibility-contrast-snapshots.sh` 导出 8 张代表图供人工审定；
- `PetGreetingRitualVisualTests` 离屏渲染三只宠物的首次见面、普通回归和久别重逢，确认 9 张图的专属台词、姿势、气泡与足底构图；
- `PetWakeRitualVisualTests` 离屏渲染三只宠物的 sleep、wake stretch 和 wake orient，确认 9 张图的因果顺序、无气泡、足底与阴影构图；
- `PetTouchResponseVisualTests` 使用生产 `PetInteractionCallout` 成对渲染三只宠物最长的熟悉触摸台词，确认 124 pt、两行限制、窗口内偏移无裁切，且 standard/increased 输出确实不同；
- `PetAttentionResponseVisualTests` 使用生产 `RealisticPetBody` 渲染三只宠物的 eye-lead、head-follow、settled 阶段，确认每阶段不同且主体、足底与阴影无裁切；
- `PetRelationshipGestureVisualTests` 通过生产 `RealisticPetBody` 使用 canonical rig 渲染三只宠物 × invite-touch/lean-close/shared-sway/anticipate-play × enter/hold/settle 共 36 个阶段，并以相同台词/pose、无 gesture 的显式姿势作 hold 对照；
- `PetRootMotionVisualTests` 除左右方向 42 帧完整移动链外，逐帧渲染三角色 × anticipate/turn/settle × 4 帧共 36 张 transition clip，验证每组四帧均有不同生产输出；
- `PetIdleGestureVisualTests` 直接通过生产 `PetUnifiedRigArtwork` 渲染三角色 × idle-left/right、look-left/right、perk-enter/peak/settle 共 21 张图，验证 canonical texture、关节层、整身重心与接触阴影组合；
- `PetDirectTouchRigVisualTests` 直接通过生产 `PetUnifiedRigArtwork` 渲染三角色 × pat-enter/peak、combo-three/five、scratch、swipe-right/up 共 21 张图，验证 canonical texture、combo 关节承重与方向性触摸变形；
- 基线更新脚本没有 `--accept-current-rendering` 会拒绝执行；PR/main CI 与 tag release 均执行只读验证。远端 `macos-14` runner 尚待首次推送后确认跨主机容差；系统“增强对比度”生产读取与确定性渲染已覆盖，真实系统设置切换仍属于实体 QA。

Debug 预览入口：

```bash
DESKPET_WEATHER_PREVIEW=rainy swift run DeskPetMac
DESKPET_MOTION_PREVIEW=walk swift run DeskPetMac
```

## 真实窗口 QA

- 点击宠物时，当前前台应用不失去焦点；
- 窗口透明角落可点击穿透，角色、玩具和提醒按钮仍可操作；
- 拖到屏幕左右边缘后，气泡朝可用空间展开；
- 窗口靠近 menu bar 时，personality speech 切换到空间更充足的一侧，角色头部与文字均不被遮挡；reminder/status 仍使用完整上方布局；
- 重启后恢复当前显示器内的安全位置；
- 每块显示器保留独立位置；重启或显示器编号变化后通过稳定 UUID 恢复，旧数字 ID 数据会自动迁移；
- 拔出显示器后优先使用回落屏幕自己的记忆，否则继承原屏幕相对位置；改变分辨率、Dock 或 menu bar 布局后仍位于 visible frame；
- root motion 保持在 visible frame 内，用户拖动或互动可立即中断；
- 工作达到提醒阈值时先出现无气泡 stretch pose，约 1.2 秒后再平滑显示提醒；准备阶段的直接互动会取消本次展示且不消耗冷却；
- menu bar、右键菜单、VoiceOver `Take a Stroll` 和 `⌘G` 均可主动触发 root motion；
- menu bar 可完成换宠、昵称、玩具、提醒间隔、Quiet Mode、天气刷新和退出；
- 切换系统“增强对比度”后，无需重启即可提升气泡、辅助文字和 menu 选择边界；当前宠物同时显示勾选标记；
- 全屏 Space、Stage Manager 和多显示器分别验证。

## 动作 QA

- `notice -> anticipate -> turn -> walk -> slow -> settle` 阶段没有突然切回 idle；
- `PetRootTransitionMotion` 在所有阶段边界连续；左右方向严格镜像，数值有限且有界，Reduce Motion 下为 neutral；
- anticipate 压低重心并扩大阴影，turn 恢复站姿，slow 吸收前向惯性，settle 回弹至 neutral；角色和接触阴影消费同一姿态；
- 自动测试验证站立脚接触区间窗口位移 `< 2 px`，并验证 walk artwork 消费同一 stride phase；
- 18 个 walk frame 和 9 个 transition frame 按实际 `1254 × 1254` alpha bounds 注册到 idle 足底线，误差 `< 0.25 pt`；
- 新增 36 个 transition clip frame 按各自 `623/627 px` 实测 alpha bounds 注册到 idle 足底线，误差同样 `< 0.25 pt`；
- pat、dance、nuzzle、reminder 能按优先级中断自治动作；
- 快速 swipe、小范围 scratch 与 nuzzle 不移动窗口；非 scratch 手势持续 `>= 0.28 s` 且位移 `>= 28 pt` 后才激活拖窗；
- 往返 scratch 即使终点回到起点附近，仍依据总路程和反向次数识别；同样轨迹若位于躯干则不误触，路径效率 `< 0.72` 的往返动作不伪装成 swipe；
- pat/boop/scratch/swipe 的反馈按位置、速度、被中断活动、stormy mood、熟悉度和 bond 选择；普通 pat 不制造 callout 噪音，熟悉高速 swipe 最多增加一个爱心；
- sleep/wake、pose 切换和 root motion 结束时无明显跳帧；
- idle 返回以 bubble-free stretch/orient 苏醒；直接互动立即中断，Reduce Motion 只保留短 orient；
- 自主 `idleAction1/2`、`lookAround`、`perkUp` 全程只使用 canonical `base.png`；前爪换重、Pauli 头部和整身倾角同相进入与退出，`stretch` 因拓扑变化继续使用显式姿势；
- full-motion 的 pat/boop/scratch/swipe 全程只使用 canonical `base.png`；combo 增强前爪承重，scratch/swipe 在同一 rig 外叠加语义方向；Reduce Motion 使用静态 `pat.png`，动作起止必须回到 neutral；
- full-motion 的 invite-touch/lean-close/shared-sway/anticipate-play 全程只使用 canonical `base.png`；单爪邀请、双爪靠近、交替换重和期待承重必须具备不同 joint silhouette，并在 enter/settle 回到 neutral；Reduce Motion 保留静态 personality pose；
- Dog 球轨迹保持屏内，Cat 激光点和 Pauli 能量节点可连续拖动。
- 开启 `Interaction Feedback` 后，pat、boop、scratch、swipe、玩具命中和进食满足各产生一次克制的系统触控板反馈；greeting 不产生触觉；Quiet Mode 下声音与触觉均停止。

## 性能基线

渲染预算：

- idle 主循环目标 12 fps；
- 自治/天气动作上限 30 fps；
- 直接互动短时上限 60 fps；
- 慢速云/雾为 8 fps，降水按背景/中景/前景为 12/18/24 fps；
- Reduce Motion 为 8 fps 且天气静态化；
- 窗口不可见时角色与天气 Timeline 暂停；
- 观察 CPU、内存和 Activity Monitor 的 Energy Impact，不接受持续高能耗。

2026-08-03 同机 release 基线：MacBook Pro (`Mac17,2`)、Apple M5、24 GB、macOS 26.5.2 (`25F84`)。每个场景运行 300 秒，每 5 秒采样一次，共 60 个样本：

```bash
scripts/measure-performance.sh <pid> 300 5
```

| 场景 | CPU 平均 / 最小 / 最大 | RSS KB 平均 / 最小 / 最大 | Energy Impact 平均 / 最小 / 最大 |
| --- | --- | --- | --- |
| idle | 4.37 / 3.30 / 5.10 | 95837.60 / 85808 / 103968 | 4.93 / 3.70 / 5.50 |
| stormy | 9.16 / 7.60 / 10.60 | 91556.00 / 89600 / 107328 | 10.07 / 8.60 / 11.00 |
| sustained interactions | 5.41 / 2.20 / 12.70 | 116480.53 / 116208 / 117264 | 5.93 / 2.20 / 13.10 |

- stormy 使用 release-only、显式 opt-in 的天气覆盖，确认雨层、湿地反射和角色受光同时运行；
- sustained interactions 每 5 秒循环 pat、dance、scratch、swipe、treat、boop，诊断期间不写入 bond 或 memory；
- 自动化环境把窗口报告为 occluded 时，诊断模式仅强制开启渲染 cadence；正式用户模式仍会在遮挡时暂停 Timeline；
- 三组 RSS 均无持续上升趋势；stormy 的稳定能耗最高，符合多景深降水预期，未出现失控增长。

## 当前人工证据与剩余项

- 已实机检查 Cat sleep 的构图、缩放和接触阴影；
- 已实机检查状态气泡向屏幕内侧避让，未遮挡 Cat 头部与尾巴；
- `swift test` 于 2026-08-05 最新通过 352 tests / 76 suites；
- scratch/swipe 分类、六阶段投喂、默认关闭音效/触觉、记忆驱动自治、关系提示、落脚保持和 walk frame 足底注册已有自动化覆盖；
- 全轨迹手势测试覆盖往返 scratch、分段直线 swipe、躯干乱划和微小抖动；O(1) tracker 不保留无界 sample 数组，旧端点调用仍走同一 resolver；
- 自动化成功解码 3 个角色的 96 个正式 PNG 资源，缩略图边长限制为 512 px；
- 自动化覆盖 non-activating panel 配置、透明 hit mask 与位置归一化；
- 自动化覆盖稳定显示器身份、旧 `NSScreenNumber` anchor 迁移、分辨率变化、拔屏继承、目标屏独立记忆和重叠屏选择；拖动持久化使用防抖并在屏幕参数变化前取消，降低拓扑切换竞态；
- 2026-08-04 release app 真实启动后，`deskpet.window.lastScreenID` 已写入 `display-<UUID>` 形式，确认 ColorSync 稳定身份路径在当前实体显示器生效；
- 自动化以注入式播放器验证 Interaction Feedback 默认关闭，直接互动开启后声音与单次触觉同步，Quiet Mode 双通道抑制，pet-selection greeting 不产生触觉；standard/increased menu 代表图已复核文案与 toggle 无裁切；
- Computer Use 已确认 non-activating `DeskPet` 窗口、状态可访问描述，以及 Pat、Boop、Dance、Give Treat 的 VoiceOver 自定义动作；menu bar 全流程、焦点穿透、多屏和 Stage Manager 仍需人工完成；
- release app 已完成 idle、stormy、连续互动三组同机 5 分钟 CPU/RSS/Energy Impact 基线，均未出现内存爬升；
- 2026-08-04 release build、app 打包、Info.plist 校验与严格 codesign 校验通过，包内 PNG 资源计数为 96，其中 36 张位于 `RootMotion/`；
- 2026-08-04 在 release app 中确认 VoiceOver 暴露 `Take a Stroll`；通过 `⌘G` 触发后窗口由 `(2900, 887)` 移至 `(2798, 887)`，完成 102 px 同屏水平 root motion；
- 自动化验证 Cat、Pauli、Dog 的 normalized head anchor，并覆盖 leading/center/trailing 共 9 组 personality bubble 离屏 AppKit 渲染；气泡宽度稳定为 194 pt，tail 目标与头部投影误差 `< 0.001 pt`；
- 自动化增加 Cat、Pauli、Dog × sideLeading/sideTrailing 共 6 个侧挂场景：气泡为 `112 × 76 pt`，角色反向让位 24 pt，head anchor 与气泡主体至少相隔 24 pt；6 张代表图已导出并人工复核无裁切；
- 自动化定义 1638 组合视觉矩阵，常规渲染 81 个轴向代表场景；完整导出能力同步覆盖 1638 张 `260 × 290` RGBA PNG；人工抽查发现并修复深色壁纸人格气泡文字对比度问题，对应像素回归测试已加入；
- 紧凑视觉基线已覆盖并比较全部 1638 个稳定命名场景；真实离屏渲染的单分块突变可被门禁拒绝，显式全量验证通过；
- 自动化覆盖 reminder ritual 的 stretching、prompting、直接互动中断和 Quiet Mode 中断；三角色共 6 张阶段图已人工复核，确认先动作后提示且冷却仅在气泡真正出现时开始；
- 自动化覆盖系统 contrast resolver 的 standard/increased 分支与测试 override 优先级；personality、reminder、status、menu 共 8 张对比图已人工复核，确认辅助文字、边界、提醒按钮与非颜色选中语义均清晰；
- 自动化覆盖 first/soon/welcome/long 四级问候的展示层级、角色语气、熟悉度爱心节奏与直接互动中断；三角色共 9 张首次/普通/久别代表图已人工复核，确认文本无截断、tail 指向正确且姿势符合角色；
- 自动化覆盖 idle 阈值进入 sleep、返回触发标准/Reduce Motion 苏醒时序和直接互动中断；三角色共 9 张 sleep/stretch/orient 代表图已人工复核，确认无气泡、无裁切且动作顺序清晰；
- 自动化覆盖触摸位置、swipe 强度、睡眠/苏醒中断、stormy mood、bond/familiarity、三角色语气和 Increase Contrast；三角色 standard/increased 共 6 张最长熟悉触摸 callout 已人工复核，确认两行文本、对比度差异与胶囊均未裁切；
- 自动化覆盖 eye/ear/head/body 四阶段顺序、三角色节奏、Reduce Motion、非法输入、离开后重入和跨窗口连续性；三角色共 9 张注意力阶段图已人工复核，确认眼神先行、抬头随后、身体最后跟随，且足底与阴影无裁切；
- 自动化覆盖 8 种偏好到 4 类关系动作的映射、enter/hold/settle 包络、三角色差异、动作剪影、Reduce Motion、`PetActivity` 传播与 canonical artwork policy；36 张生产关系动作阶段已人工复核，确认角色身份连续，joint 变化可辨，且气泡、足底、阴影无裁切；
- 自动化覆盖 Cat、Pauli、Dog 左右两个方向的 notice、anticipate、turn、walk、slow、settle、completed 共 42 帧移动序列；人工抽查确认三个角色的关键构图、左右镜像和接触阴影无新增裁切；
- 自动化新增 7 个 clip 帧选择/回退/注册测试和 36 张生产离屏渲染；人工抽查 13 张代表帧，确认三角色动作递进、毛发/关节边缘、阴影与画布边界无异常；
- locomotion 与自主 idle gestures 已切换为单一 canonical base 驱动的分层 2D rig：11 个 joint/policy/mask/cutout 测试、4 个生产视觉测试覆盖三角色；42 张左右动作链、6 张相反 gait 极值及 21 张 idle gesture 阶段已人工复核，无关节白缝、轮廓残影、身份跳变或裁切；旧 walk/transition/idle/peek/perk 整身图不再参与对应生产动作或预加载。
- pat/boop/scratch/swipe 已接入相同 canonical rig：5 个 policy/joint/触摸链测试及 2 个视觉/导出测试覆盖三角色；21 张 pat/combo/scratch/swipe 阶段已人工复核，无关节白缝、轮廓残影、身份跳变或裁切。
- runtime motion preload 已从每宠物 26 张降为仅 `stretch` 1 张；关系动作已经接入 canonical rig，普通 personality/苏醒/投喂中的显式 pose，以及 Cat/Dog 眼睑/耳部与 Pauli 手部等更细表情，仍需可编辑局部分层。仓库无 3D 源模型，因此共享 3D rig/相机/灯光 atlas 仍是后续美术签收项。
- 本轮 1638 场景紧凑视觉基线只读复验通过；release app 严格签名、Info.plist、arm64 可执行文件、96 张 PNG / 36 张 `RootMotion` PNG 均验证通过，更新后的应用已重启为 PID `19566`。
