# Custom Scene Classifier Roadmap

SnapCopy 当前目标不是训练大型通用视觉模型，而是在生活照片场景里提高识别稳定性，让后续文案生成更贴图。现阶段保留 Apple Vision + OCR + SceneResolver，同时预留轻量自定义场景分类器入口。

## 目标场景

- breakfast
- cafe
- walking
- street
- travel
- pet
- outfit
- fitness
- sunset
- home
- work
- food
- unknown

## 当前架构

1. Apple Vision 继续负责基础标签识别。
2. OCR 继续识别图片中的文字。
3. `SceneResolver` 继续保留规则推断。
4. `CustomSceneClassifier` 作为可插拔协议预留。
5. `CoreMLSceneClassifier` 当前没有真实模型时返回 disabled。
6. `SceneFusionEngine` 融合 Vision、OCR、自定义模型、用户修正记录和规则结果，输出 top 3 候选、最终场景、置信度和解释。
7. `ImageRecognitionMetricsLogger` 只在本地记录 debug 评估数据，不上传照片和用户偏好。

## 阶段 A：TestFlight 匿名识别结果

收集 TestFlight 用户的识别结果和手动修正结果。这个阶段先不上传图片，只记录匿名识别结果、top 3 候选、用户选择、是否需要修正、文案评分、模型耗时、图片尺寸和时间。

目标是先定位错误集中在哪些类别，比如宠物与食物混合、咖啡与早餐混淆、室内生活与工作桌面混淆。

## 阶段 B：用户明确同意后的少量样本

在用户明确同意后，收集少量训练样本。每个类别至少准备 200 到 500 张图片。

样本必须覆盖真实生活照片，而不是只用干净的商品图或公开数据集图片。重点覆盖低光、构图偏斜、截图、拼图、多人、宠物加食物等高频失败场景。

## 阶段 C：云端多模态 teacher 生成初始标签

使用云端多模态模型作为 teacher，为样本自动生成初始标签、场景标签和错误解释。

人工抽查并修正高频错误类别。优先处理：

- pet + food
- cafe vs breakfast
- home vs work
- walking vs street
- travel vs sunset
- outfit vs portrait

## 阶段 D：训练轻量场景分类模型

训练目标是生活场景分类，不是通用 ImageNet 识别。优先评估：

- MobileNetV4 small
- RepViT small
- EfficientFormerV2 small

根据研究报告结论，选择模型时不只看参数量和 FLOPs，还要看真实 iPhone 延迟、Core ML 兼容性、算子融合友好度和量化后的精度保持。

## 阶段 E：转 Core ML 与量化

将模型转换为 Core ML。优先使用 INT8 或 Core ML 支持的量化方式优化本地推理。

量化前后需要对比：

- Top-1 scene accuracy
- Top-3 scene coverage
- unknown rate
- latency
- model size
- memory usage
- caption match rate

## 阶段 F：真机评估

在真实 iPhone 上评估，不只看模拟器结果。

核心指标：

- Top-1 scene accuracy
- Top-3 scene coverage
- unknown rate
- latency
- model size
- memory usage
- caption match rate

上线标准不是“模型看起来更聪明”，而是同一批测试照片里，手动修正率下降，文案贴图率上升，并且本地推理不会明显拖慢生成体验。

## 隐私与安全边界

- 当前阶段不上传用户照片。
- 当前阶段不接云端 API。
- 当前阶段不训练模型。
- 不把大模型 API key 放进 App。
- 后续只有在用户明确同意时，才收集少量训练样本。
- 所有模型训练、teacher 标注、API 成本记录都放在后续云端增强阶段处理。
