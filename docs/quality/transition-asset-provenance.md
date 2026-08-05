# Root Motion Transition Asset Provenance

日期：2026-08-04（运行时记录更新于 2026-08-05）

## 范围

本轮为 Cat、Pauli、Dog 各补充三个 root-motion 关键姿势：

- `anticipate.png`：重心前移或抬脚，进入移动前的蓄力；
- `turn.png`：头、胸和支撑脚朝屏幕右侧转向；
- `settle.png`：停止后压低重心、重新站稳。

资源位于 `Sources/DeskPetMac/Resources/Pets/{Cat,Pauli,Dog}/`。每张为 `1254 × 1254`、带 alpha 的 PNG。

## 生成与处理

- 生成模式：Codex 内置 `imagegen`；
- 身份参考：每只宠物始终使用自身 `base.png`，不跨角色混用；
- prompt 约束：保留同一角色身份、毛色/材质、镜头高度、写实光照与正方形构图；每次只生成一个明确姿势；主体完整、足部可见，不添加地面阴影、文字或道具；
- 透明流程：先生成平坦 `#ff00ff` 色键背景，再用本地 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 输出 alpha；Cat、Dog 额外使用 `--edge-contract 1` 收紧毛发色边；
- 未使用外部 API 或运行时下载，应用继续仅加载包内资源。

## 注册数据

alpha 可见区域底边（阈值 `alpha >= 16`，源画布坐标）：

| Pet | base | anticipate | turn | settle |
| --- | ---: | ---: | ---: | ---: |
| Cat | 1079 | 1073 | 1101 | 1049 |
| Pauli | 1185 | 1141 | 1182 | 1188 |
| Dog | 1192 | 1145 | 1141 | 1097 |

`PetArtworkLayout` 使用这些数据把 transition 与 base 注册到同一渲染足底线；自动测试要求误差 `< 0.25 pt`。

## 检查结果与限制

- 已逐张检查轮廓透明、色键残留、完整足部、角色身份和构图覆盖率；
- 三个角色的 `turn` 姿势统一朝右，向左 root motion 由渲染层水平镜像；
- 这 9 张是共享 base 身份约束下的 transition key poses，不等同于共享骨骼/相机/灯光离线输出的完整 12–18 fps sprite atlas；完整 atlas 仍列为后续美术工作。

## 连续 clip 扩展（2026-08-04）

第二批在旧单帧 pose 之外新增 Cat、Pauli、Dog × `anticipate`、`turn`、`settle` × 4 帧，共 36 张 alpha PNG：

- 最终资源：`Sources/DeskPetMac/Resources/Pets/<Pet>/RootMotion/<pose><1...4>.png`；
- 生成模式：Codex 内置 `imagegen`，每组以该角色 `base`、动作起点和旧 transition pose 为身份与 endpoint 参考；
- prompt 族统一要求 `2 × 2` 等分 atlas、固定角色身份/镜头/灯光/足底线、均匀动作增量、完整轮廓，以及纯色 `#ff00ff` 背景；Cat/Dog 保持毛色和解剖，Pauli 保持面板、关节、天线和材质拓扑；
- `scripts/split-sprite-atlas.swift` 将 atlas 切为四帧，并在每格内缩 2 px 排除生成器可能产生的网格缝；
- 使用内置 imagegen 技能提供的 `remove_chroma_key.py` 转 alpha；Cat/Dog 使用 `--edge-contract 1` 收紧毛发边缘，Pauli 保留标准 soft matte；
- `scripts/report-png-alpha-bounds.swift` 以 `alpha >= 16` 测量每帧真实可见底边；`PetArtworkLayout` 按各自 `623/627 px` 画布归一化注册，36 帧渲染足底线与 base 误差均 `< 0.25 pt`；
- 运行时在相邻帧间按 `phaseProgress` 交叉插值；任一 clip 资源缺失时先回退旧 transition pose，再回退 base，不影响 Reduce Motion；
- `PetRootMotionVisualTests` 额外离屏渲染 36 张生产构图，`scripts/export-transition-clip-snapshots.sh` 提供按需导出。本轮人工复核 13 张代表帧，确认无裁切、白缝、色键残留或明显身份漂移。

这 36 张完成的是 root-motion transition clip 首批连续化，不宣称已经具备统一 3D 骨骼。

## 运行时统一 rig 替换（2026-08-04）

- production locomotion 及自主 `idleAction1/2`、`lookAround`、`perkUp` 已改用 `PetUnifiedRigArtwork`：每只宠物只读取自身 `base.png`，由共享 joint pose 契约和角色专属 silhouette mask 组合前肢、后肢、重心及 Cat/Dog 双段尾巴；
- notice、anticipate、turn、walk、slow、settle、completed 全链不再切换本文件记录的独立 walk/transition 整身图，因此不会在链路中发生镜头、毛色、材质或身份跳变；
- `idleAction*.png`、`peek.png`、`perk.png` 与旧 `walk1...6`、transition pose、36 张 clip 继续保留在 bundle，供来源追溯、特殊 personality pose 兼容和对照，但不再参与自主 idle/locomotion 渲染或 preload；运行时仅预加载拓扑仍未 rig 化的 `stretch` 1 张资源；
- 首轮渲染发现 polygon 边缘白缝后，body cutout 改为小于移动层的 overlap mask；自动化约束 cutout 四边关系，并人工复核 42 张左右动作链与 6 张相反 gait 极值；
- idle gesture 首轮 21 张离屏审图发现 Cat/Dog 头颈 polygon 在侧倾时会暴露背景缝，扩大 head cutout overlap 后又会显露原始轮廓残影；最终采用角色拓扑感知策略：Pauli 的刚性颈部消费独立 head layer，Cat/Dog 保留完整头部 silhouette，由整身倾角、前爪换重和尾巴表达方向。复审后无白缝、残影或裁切；
- pat、boop、scratch、swipe 随后也接入同一 canonical `base.png`：既有 pat 时序/combo 能量同时驱动整身重心与前爪承重，scratch/swipe 只在同一 rig 外叠加方向性变形；Reduce Motion 仍使用静态 `pat.png`，不播放关节位移；
- invite-touch、lean-close、shared-sway、anticipate-play 随后复用既有关系动作包络接入相同 joint contract；full-motion 不再切换 perk/peek/proud 整身图，Reduce Motion 继续使用静态 personality pose；
- 这是同一 canonical texture 驱动的真实运行时 2D rig，不是共享 3D source rig。stretch、普通 personality/苏醒/投喂中的显式姿势，以及 Cat/Dog 眼睑/耳部与 Pauli 手部等更细表情仍需可编辑分层源图或正式 3D atlas 才能完成全量签收。
