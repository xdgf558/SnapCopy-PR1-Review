# SnapCopy Local Create ML Training Guide

这份文档用于训练 SnapCopy 第一版本地轻量场景分类模型。目标不是训练大型通用模型，而是先用 Mac + Apple Create ML 做一个粗模型，验证它是否能提升生活照片场景识别。

当前 App 已经保留了 Core ML 接入口：如果 App Bundle 里存在 `SnapCopySceneClassifier.mlmodelc`，`CoreMLSceneClassifier` 会尝试加载；如果没有模型，App 会继续使用 Apple Vision + OCR + SceneResolver，不影响现有功能。

## 目标场景

第一版只训练以下 13 类，文件夹名和模型标签必须完全一致：

```text
breakfast
cafe
walking
street
travel
pet
outfit
fitness
sunset
home
work
food
unknown
```

## 第一版数据规模

建议每类先收集 50 到 100 张图片。优先目标是每类 80 张，总量约 1040 张。

每类 80 张时，按 70% / 15% / 15% 划分：

```text
train: 56 张
validation: 12 张
test: 12 张
```

每类 50 张时，可以近似划分：

```text
train: 35 张
validation: 8 张
test: 7 张
```

每类 100 张时：

```text
train: 70 张
validation: 15 张
test: 15 张
```

## 图片收集原则

真实生活照片优先。GPT 或其他 AI 生成图可以作为补充，但第一版不要超过总量的 20% 到 30%。

优先保留这些真实情况：

- 低光、逆光、夜晚
- 随手拍、构图歪、主体偏小
- 桌面杂物多
- 室内家具容易误判
- 宠物和食物同框
- 咖啡和早餐同框
- 工作桌面和居家桌面相似
- 街景、散步、旅行容易混淆
- 截图、拼图、模糊图放入 `unknown`

不要把同一张图片的连续截图或几乎完全一样的照片重复放入训练集。重复图片会让模型看起来准确，但真机泛化变差。

## 图片规格建议

保留一份原图备份，不直接修改原图。

训练副本建议：

- 长边压缩到 768 到 1280 px
- 格式使用 `.jpg` 或 `.png`
- 文件名使用英文、数字、下划线，避免空格和特殊符号
- Create ML 训练输入尺寸选择 224 或 256

示例文件名：

```text
breakfast_0001.jpg
cafe_0023.jpg
pet_0048.jpg
unknown_0012.jpg
```

## 文件夹结构

在 Mac 上新建一个数据集根目录，例如：

```text
SnapCopySceneDataset/
  dataset/
    train/
      breakfast/
      cafe/
      walking/
      street/
      travel/
      pet/
      outfit/
      fitness/
      sunset/
      home/
      work/
      food/
      unknown/
    validation/
      breakfast/
      cafe/
      walking/
      street/
      travel/
      pet/
      outfit/
      fitness/
      sunset/
      home/
      work/
      food/
      unknown/
    test/
      breakfast/
      cafe/
      walking/
      street/
      travel/
      pet/
      outfit/
      fitness/
      sunset/
      home/
      work/
      food/
      unknown/
```

Create ML 会把每个子文件夹名当作分类标签，所以文件夹名必须使用上面的英文标签。

## 如何整理图片

1. 先把所有原图放进 `originals/` 备份目录。
2. 按照片主场景填 `docs/dataset-labeling-template.csv`。
3. 每张图只选一个 `primary_scene`。
4. 如果照片有第二元素，例如猫和牛排，`primary_scene` 可以填 `pet`，`secondary_tags` 填 `food,tableware`。
5. 把图片复制到对应 split 和类别文件夹。
6. 不确定的、模糊的、没主体的、截图拼图类图片放进 `unknown`。

建议你先手动整理每类 20 张，确认分类标准统一，再继续扩大到每类 80 张。

## 场景标注口径

`breakfast`：早餐、早午餐、吐司、鸡蛋、面包、晨间餐桌。  
`cafe`：咖啡、咖啡馆、杯子、拿铁、咖啡桌面。  
`walking`：散步路上、公园小路、人行道、日常户外移动感。  
`street`：城市街角、道路、建筑、车流、街区。  
`travel`：旅行风景、海边、山、酒店、机场、地标。  
`pet`：猫、狗、宠物主体，即使旁边有食物也优先标宠物。  
`outfit`：穿搭、自拍、镜子、衣服、鞋包。  
`fitness`：健身房、运动、跑步、瑜伽、器械。  
`sunset`：日落、晚霞、黄昏天空。  
`home`：居家、家具、卧室、客厅、厨房、室内生活。  
`work`：电脑、键盘、显示器、办公桌、会议、工作笔记。  
`food`：非早餐的食物、餐厅菜品、正餐、甜点。  
`unknown`：模糊、遮挡、无主体、截图、拼图、无法明确归类。

## 如何用 Create ML 新建项目

1. 打开 Xcode。
2. 在 Dock 中 Control-click Xcode 图标。
3. 选择 `Open Developer Tool`。
4. 打开 `Create ML`。
5. 选择 `New Document`。
6. 选择 `Image Classification` 模板。
7. 项目名建议填写 `SnapCopySceneClassifier`。
8. 保存到你的训练目录旁边，例如 `SnapCopySceneDataset/CreateML/`。

## 如何导入训练数据

在 Create ML 的 Image Classification 项目里：

1. 找到 Training Data 区域。
2. 选择 `dataset/train` 文件夹。
3. 找到 Validation Data 区域。
4. 选择 `dataset/validation` 文件夹。
5. 如果 Create ML 版本允许单独设置 Testing Data，选择 `dataset/test`。
6. 如果 Create ML 版本没有独立 Testing Data 入口，训练完成后用 Preview 或 App DebugView 手动测试 `dataset/test`。

导入后，确认 Create ML 能看到 13 个标签，并且每个标签数量接近。

## 如何训练

1. 在 Create ML 中点击 Train。
2. 第一版先使用默认参数。
3. 输入尺寸优先选择 224 或 256。
4. 不要第一版就追求极高准确率，先看错误分布。
5. 训练完成后查看 Training Accuracy 和 Validation Accuracy。

第一版参考目标：

```text
Validation Accuracy >= 70% 可以进入 App 测试
Validation Accuracy < 60% 先检查数据标签和类别混淆
某一类明显很差  优先补那一类真实样本
```

如果训练集准确率很高但验证集很低，通常说明数据太少、重复图太多，或者类别标准不一致。

## 如何导出 .mlmodel

1. 训练完成后，在 Create ML 中找到 Export 或 Output。
2. 导出 Core ML model。
3. 文件名必须改成：

```text
SnapCopySceneClassifier.mlmodel
```

4. 保存到安全位置，例如：

```text
SnapCopySceneDataset/models/SnapCopySceneClassifier.mlmodel
```

## 如何放进 Xcode

1. 打开 `SnapCopy.xcodeproj`。
2. 把 `SnapCopySceneClassifier.mlmodel` 拖进 Xcode 左侧项目导航。
3. 建议放在 `SnapCopy/Models/` 或新建 `SnapCopy/MLModels/` 分组里。
4. 勾选 `Copy items if needed`。
5. 勾选目标 `SnapCopy` 的 Target Membership。
6. Clean Build 一次：`Shift + Command + K`。
7. Run App。

Xcode 会在构建时把 `.mlmodel` 编译为 `.mlmodelc`。App 当前会自动查找 Bundle 里的 `SnapCopySceneClassifier.mlmodelc`。

## 如何在 App 中测试识别结果

1. 用 Xcode Debug 运行 App。
2. 选择 `dataset/test` 里的照片，或用手机拍真实照片。
3. 打开首页的 `照片理解诊断`。
4. 查看 `自定义轻量模型` 区域。
5. 如果显示 `status: available`，说明 Core ML 模型已加载。
6. 如果显示 `status: disabled`，说明模型没有加入 App Bundle，系统仍在使用 Vision + OCR + rules。
7. 查看 top 3 scene candidates。
8. 如果 customModel 预测正确但 final scene 不正确，说明融合权重需要调。
9. 如果 customModel 预测错误，说明训练数据或标签需要调整。

## 如何记录评估指标

用 `dataset/test` 做固定测试，不要用训练集评估。

每张测试图记录：

- 真实标签
- 自定义模型 Top-1
- 自定义模型 Top-3
- App final scene
- confidence
- 是否手动修正
- 文案是否贴图
- 模型耗时

指标计算：

```text
Top-1 scene accuracy = Top-1 预测正确数量 / test 总数量
Top-3 scene coverage = 正确标签出现在 top 3 的数量 / test 总数量
unknown rate = 预测为 unknown 的数量 / test 总数量
low confidence rate = confidence < 0.75 的数量 / test 总数量
caption match rate = 文案贴图数量 / test 总数量
```

第一版建议目标：

```text
Top-1 scene accuracy >= 70%
Top-3 scene coverage >= 85%
unknown rate <= 20%
low confidence rate <= 35%
caption match rate 比纯 Vision + rules 明显提升
```

## 如何使用 App 导出的识别日志

Debug 版本中：

1. 进入设置。
2. 找到 `开发者诊断`。
3. 点击 `分享识别日志文件`。
4. 导出 JSON。
5. 把 JSON 和你整理的 `dataset-labeling-template.csv` 一起保存。

识别日志不包含照片原图，只包含预测、top 3、手动修正、评分、耗时和图片尺寸。

## 常见问题

如果模型没有生效：

- 确认文件名是 `SnapCopySceneClassifier.mlmodel`
- 确认 Target Membership 勾选了 `SnapCopy`
- 确认重新 Clean Build
- 打开 DebugView 看 `自定义轻量模型` 是否从 `disabled` 变成 `available`

如果 `unknown` 很多：

- 检查训练集中 `unknown` 是否过多或过杂
- 检查其他类别是否样本太少
- 检查低光、模糊、截图是否都被塞进 unknown，导致模型过度保守

如果 `home` 和 `work` 混淆：

- 给 `work` 多放电脑、键盘、显示器、办公笔记
- 给 `home` 多放沙发、床、柜子、厨房、无电脑的室内生活
- 避免同一张居家办公图在两个类别里重复出现

如果 `pet` 和 `food` 混淆：

- 宠物是主体时标 `pet`
- 食物是主体时标 `food`
- 宠物加食物同框时，优先看画面主角是谁

## 后续路线

第一版只用 Create ML。不要从零训练 RepViT、MobileNetV4 或 EfficientFormerV2。

当本地日志证明 Create ML 粗模型有效后，再考虑：

1. 扩大每类样本到 200 到 500 张。
2. 用云端多模态模型做 teacher 生成初始标签。
3. 人工修正常错类别。
4. 云端训练 MobileNetV4 small、RepViT small 或 EfficientFormerV2 small。
5. 转 Core ML 并做量化。

## 参考

- Apple Developer Documentation: [Creating an Image Classifier Model](https://developer.apple.com/documentation/createml/creating-an-image-classifier-model)
- Apple Developer Documentation: [MLImageClassifier](https://developer.apple.com/documentation/createml/mlimageclassifier/)
