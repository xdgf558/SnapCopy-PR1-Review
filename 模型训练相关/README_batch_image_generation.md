# SnapCopy 批量生成试跑图片说明

这个目录里的 `snapcopy_scene_260_prompt_pack.zip` 包含 13 个场景、每类 20 条提示词，共 260 条。它适合用来做第一轮 Create ML 流程试跑：验证文件夹结构、训练流程、Core ML 接入和 App 内识别链路。

重要提醒：AI 生成图只建议做试跑和补缺，不建议作为最终模型的主要训练数据。正式模型仍然要以真实手机生活照片为主，否则模型可能学到“AI 图风格”，到真实照片上准确率会变差。

## 目录输出

脚本会把图片保存到：

```text
/Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关/generated_scene_dataset/dataset/
  train/
  validation/
  test/
```

每张图会按 prompt 包里的 `target_path` 自动落到对应类别和 split 目录中。

## 准备环境

第一版脚本支持三种方式：阿里百炼 DashScope、OpenAI Images API 或 Gemini API 的 Imagen 端点。你有哪家的 key，就用哪家的脚本。

### 方式零：阿里百炼 / qwen-image-plus

如果你手里是阿里云百炼 DashScope key，优先用这个脚本：

```bash
cd /Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关
python3 -m pip install pillow
export DASHSCOPE_API_KEY="你的阿里百炼 API Key"
python3 generate_scene_images_dashscope.py --dry-run
```

注意：阿里百炼的北京地域和新加坡地域 API Key、请求地址是分开的，不能混用。  
如果你的控制台网址里有 `ap-southeast-1`，说明你大概率用的是新加坡地域，需要给命令加：

```bash
--region intl
```

如果是北京地域，就使用默认 `--region cn`。

从当前已生成的图片后面继续，只新增 60 张：

```bash
python3 generate_scene_images_dashscope.py --model qwen-image-plus --max-new 60
```

全量补齐剩余图片：

```bash
python3 generate_scene_images_dashscope.py --model qwen-image-plus
```

脚本会自动跳过已经存在的图片，不会重跑前面已经生成好的文件。

如果 `qwen-image-plus` 在你的账号里不可用，可以改用 `qwen-image-2.0`：

```bash
python3 generate_scene_images_dashscope.py --model qwen-image-2.0 --size '2048*2048' --max-new 20
```

如果你的 API Key 来自新加坡地域：

```bash
python3 generate_scene_images_dashscope.py --region intl --model qwen-image-2.0 --size '2048*2048' --max-new 20
```

`qwen-image-2.0` 使用阿里同步接口，脚本会自动切换，不需要你额外改代码。

如果额度快用完，或者只想用更便宜的轻量文生图模型补训练图，可以用 `z-image-turbo`：

```bash
python3 generate_scene_images_dashscope.py --region intl --model z-image-turbo --size '1280*1280' --max-new 20
```

默认不启用阿里的提示词改写，这样更省钱。如果你想要更强的提示词改写，可以额外加：

```bash
--prompt-extend
```

### 方式一：Gemini / Imagen

如果你手里是 Gemini API key，使用这个脚本：

```bash
cd /Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关
python3 -m pip install pillow
export GEMINI_API_KEY="你的 Gemini API Key"
python3 generate_scene_images_gemini.py --dry-run
```

小批量每类 1 张：

```bash
python3 generate_scene_images_gemini.py --limit-per-label 1
```

全量生成 260 张：

```bash
python3 generate_scene_images_gemini.py
```

默认使用 `imagen-4.0-fast-generate-001`。它比 Standard 更便宜，也更适合当前“场景分类试跑数据”的目标。训练分类器主要需要场景清楚、构图自然、类别多样，不需要最高审美质量。

如果想指定 Standard，可以这样跑：

```bash
python3 generate_scene_images_gemini.py --model imagen-4.0-generate-001
```

如果你的 Google AI Studio 项目没有开通 Imagen 或额度不足，命令会返回 Google API 的错误信息。

如果看到 `Quota exceeded` 或 `RESOURCE_EXHAUSTED`，说明当天这个模型的请求次数用完了，不是脚本错误。脚本默认会停下来，第二天重新运行同一条命令即可；已经生成过的图片会自动跳过。

也可以每天限制新跑一部分，例如只新增 60 张。已经存在的图片会跳过，不算进这 60 张：

```bash
python3 generate_scene_images_gemini.py --max-new 60
```

### 方式二：OpenAI Images API

如果你手里是 OpenAI API key，使用这个脚本：

```bash
cd /Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关
python3 -m pip install openai pillow
export OPENAI_API_KEY="你的 OpenAI API Key"
```

如果你后续改用本地生图软件、ComfyUI、Stable Diffusion 或其他 API，也可以复用 zip 里的 `snapcopy_scene_260_prompts.jsonl`，字段里已经包含 prompt、类别、split 和目标文件路径。

## 先做 dry-run

先确认脚本能读取 260 条提示词，不会真的调用 API：

```bash
cd /Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关
python3 generate_scene_images_openai.py --dry-run
```

只看前 10 条：

```bash
python3 generate_scene_images_openai.py --dry-run --limit 10
```

## 小批量试跑

建议先每类生成 1 张，确认质量和目录没问题：

```bash
python3 generate_scene_images_openai.py --limit-per-label 1
```

只生成早餐和咖啡各 2 张：

```bash
python3 generate_scene_images_openai.py --labels breakfast,cafe --limit-per-label 2
```

## 全量生成 260 张

确认小批量质量可以后，再生成全部：

```bash
python3 generate_scene_images_openai.py
```

如果某些图片已经存在，脚本默认会跳过。想覆盖重生成：

```bash
python3 generate_scene_images_openai.py --overwrite
```

## 生成后检查

每类至少快速看一遍：

1. 场景是否真的符合文件夹类别。
2. 有没有明显 AI 文字、水印、畸形手、奇怪脸、过度插画感。
3. `unknown` 类不要太像某个明确场景，否则会让模型学乱。
4. `pet`、`food`、`home` 这些容易互相重叠的类别，尽量挑主场景很明确的图。

不合格图片直接删掉，后续用真实照片补上。

## 接入 Create ML

生成后可以把 `generated_scene_dataset/dataset` 当作 Create ML 的第一版试跑数据。更完整的整理、训练、导出和接入步骤见：

```text
/Users/shaola/Downloads/软件开发相关/SnapCopy/模型训练相关/local-create-ml-training-guide.md
```
