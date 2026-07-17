# DeskPet 写实角色重塑与 Dog 扩展设计

日期：2026-07-15
分支：`feature/personality-moments-polish`

## 目标

把当前 Cat 与 Pauli 从简单 SwiftUI 几何角色重塑为写实 3D 桌面伙伴，并新增 Dog。三只宠物必须在默认 idle 状态中就有明显不同的轮廓、材质、表情和常驻微动作，不再依赖低频 personality moment 才显得有生命力。

本轮保持现有透明 `220×250` macOS 窗口、天气、羁绊、休息提醒、工作计时和快捷操作。写实素材加载失败时保留现有矢量绘制作为安全回退。

## 视觉方向

采用写实 3D 角色渲染：真实动物毛发与眼睛高光、Pauli 的 PBR 塑料和金属材质、统一柔和棚拍光和克制的接触阴影。三只宠物使用固定身份，不随天气整体换色；天气仅改变光线、表情和局部视觉细节。

固定身份如下：

- Cat：橘色虎斑，慵懒、淘气，身体微侧，轮廓灵巧。
- Pauli：象牙白与青绿色机身，认真、好奇，轮廓机械且挺拔。
- Dog：金棕色垂耳犬，热情、忠诚，身体前倾并随时准备互动。

透明窗口中不保留摄影背景或地面，只显示角色和柔和接触阴影。

## 常驻动态

默认 idle 必须持续表达生命感：

- Cat：肩背呼吸、左右耳独立转向、瞳孔轻微追随、尾巴自然摆动。
- Pauli：头部小幅校准、屏幕眼睛微调、天线扫描、关节或侧舱轻微响应。
- Dog：胸腔呼吸、张嘴轻喘、尾巴摇动、耳朵轻晃，偶尔歪头或抬前爪。

鼠标靠近时，宠物的眼睛和头部克制地朝指针方向偏移。点击时播放短促、明显且符合角色的回应。Reduce Motion 开启时取消头身位移、尾巴大幅摇动和弹性动作，只保留淡入、眨眼与小幅状态变化。

## 素材系统

每只宠物拥有固定身份的写实状态素材，覆盖：

- `idle`
- `blink`
- `hover`
- `pat`
- `sleep`
- personality poses：`peek`、`perk`、`stretch`、`proud`

素材按可独立动画的视觉部件组织：主体、头部或眼睛、耳朵或天线、尾巴或侧舱、接触阴影。优先使用约 512px 的 Retina PNG，在 `220×250` 窗口内以 aspect-fit 方式绘制。实际资源路径为：

```text
Sources/DeskPetMac/Resources/Pets/
  Cat/
  Pauli/
  Dog/
```

素材通过当前会话可用的内置图像生成工具创建，先生成纯色色键背景，再使用本地抠图工具输出带 alpha 的 PNG。由于 ChatGPT 订阅不包含 API credits，本轮不依赖 CLI API 原生透明输出。每张结果必须检查透明角落、角色覆盖率、色键残留、毛发边缘、身份一致性和 Retina 缩放效果；边缘不合格时仅针对该素材重新生成或调整抠图参数。

写实素材或资源清单加载失败时，渲染层自动使用现有 Cat / Pauli 矢量实现。Dog 必须拥有可用的轻量矢量回退，确保任何资源错误都不会产生空白宠物窗口。

## SwiftUI 架构

### 角色资源描述

新增纯数据资源描述，用稳定文件名映射 `PetKind`、显示状态和 personality pose。资源存在性与回退选择集中处理，不把文件名判断散落在视图层。

### 渲染层

新增一个聚焦的写实宠物渲染视图，负责：

- 从资源描述加载角色部件；
- 根据 idle、hover、pat、sleep 和 personality pose 选择或组合素材；
- 将时间轴、鼠标相对位置和 Reduce Motion 转换为小幅 transform；
- 在资源不可用时调用现有矢量回退视图。

现有 `PetWindowView` 继续负责窗口级气泡、控件、心形粒子和状态优先级，不承担具体素材文件判断。

### 交互数据流

```text
PetViewModel state + pointer position + timeline
  -> pet presentation state
  -> resource descriptor resolves layered assets
  -> realistic renderer applies small transforms
  -> asset missing or invalid
       -> vector fallback renderer
```

写实素材不新增网络请求、权限或运行时生成操作。

## Dog 产品接入

`PetKind` 新增 `.dog`。宠物选择器新增 Dog，快捷键新增 `⌘3`。已有 `.cat` 和 `.pauli` 的持久化值保持不变，旧版本存储可继续读取。

Dog 完整接入现有天气、羁绊、点击、睡眠、舞蹈、休息提醒和 personality moment 系统。新增 12 条 Dog 专属对白，general、weather、focus、interaction 四类各 3 条，语气热情、忠诚并期待参与。

Dog 对共享语义姿态的视觉解释如下：

- `peek`：身体前探并快速摇尾；
- `perk`：耳朵抬起并歪头；
- `stretch`：前腿伸展、尾巴上扬；
- `proud`：坐直并张嘴微笑。

Dog 与 Cat、Pauli 共用选择与调度规则，不新增独立计时器或持久化系统。

## 兼容性与失败处理

- 保持窗口尺寸、透明度和现有快捷键；Dog 只新增 `⌘3`。
- 保持现有 Cat、Pauli 存储 raw value，不迁移用户数据。
- 图片缺失、文件名错误或 `NSImage` 解码失败时静默回退到矢量角色。
- 不在运行时下载素材，不显示面向用户的资源错误提示。
- 气泡、休息提醒和用户主动界面的优先级不变。

## 测试

自动测试覆盖：

- `PetKind.dog` 的枚举和存储兼容性；
- Dog personality catalog 恰好包含 12 条唯一对白、每类 3 条；
- selector 只为 Dog 选择 Dog 对白，并继续遵守上下文与最近记录排除；
- 三只宠物所需资源清单完整且文件名稳定；
- 缺失写实资源时选择矢量回退；
- 所有现有 Core 测试继续通过。

工程验证运行：

```bash
swift test
swift build
scripts/package-app.sh
```

视觉验收逐只覆盖 idle、hover、pat、sleep 和四种 personality pose：

- 静止截图中不看名称也能区分三只宠物；
- 连续观察 10 秒可看到自然呼吸、视线或机械微调；
- Cat 与 Dog 毛发边缘无明显色键残留；
- Pauli 的塑料、金属和屏幕材质与动物处于同一棚拍光环境；
- 三只宠物在 Retina 缩放下不发虚、不裁切；
- Reduce Motion 下无明显位移或大幅循环动作；
- 任意一项素材缺失时仍显示对应矢量角色。

## 不在范围内

- 改变窗口大小或引入可调整窗口；
- 3D runtime、SceneKit 模型或实时骨骼动画；
- 声音、语音、后端或新权限；
- 商店、货币、任务或复杂情绪系统；
- ChatGPT/API 运行时调用；
- 与角色重塑和 Dog 接入无关的重构。
