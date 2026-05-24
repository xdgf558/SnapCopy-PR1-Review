# SnapCopy Local SD3.5 Medium Setup

This environment uses ComfyUI on the external drive.

## Installed Paths

- ComfyUI: `/Volumes/AI作品素材/SnapCopy_AI/ComfyUI`
- Python virtualenv: `/Volumes/AI作品素材/SnapCopy_AI/comfyui-venv`
- Synthetic image output root: `/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images`
- ComfyUI temporary output: `/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/comfyui_output`

## Current Status

ComfyUI and Python dependencies are installed.

PyTorch MPS is available when run outside the Codex sandbox:

```text
mps available True
mps built True
```

The SD3.5 Medium model itself requires Hugging Face approval. Anonymous download is blocked by the model repository.

## One-Time Hugging Face Authorization

1. Open the SD3.5 Medium model page:
   `https://huggingface.co/stabilityai/stable-diffusion-3.5-medium`
2. Log in to Hugging Face.
3. Click the model access / agreement button on the model page.
4. Create a read token:
   `https://huggingface.co/settings/tokens`
5. In Terminal, run:

```bash
source "/Volumes/AI作品素材/SnapCopy_AI/comfyui-venv/bin/activate"
hf auth login
```

Paste the Hugging Face token when prompted.

## Download SD3.5 Medium

After login, run:

```bash
cd "/Users/shaola/Downloads/软件开发相关/SnapCopy"
zsh ml-dataset/scripts/download_sd35_medium_comfyui.sh
```

The script downloads:

- `sd3.5_medium.safetensors`
- `clip_l.safetensors`
- `clip_g.safetensors`
- `t5xxl_fp8_e4m3fn.safetensors`
- `SD3.5M_example_workflow.json`

## Start ComfyUI

```bash
cd "/Users/shaola/Downloads/软件开发相关/SnapCopy"
zsh ml-dataset/scripts/start_comfyui_sd35.sh
```

Then open:

```text
http://127.0.0.1:8188
```

## Recommended First Settings

For MacBook Air 16GB:

- Batch size: `1`
- Resolution: start with `768 x 768`
- Steps: `20` to `28`
- Use the FP8 T5 text encoder.
- Close Xcode and iOS Simulator while generating images.
- Generate a small test batch first, then run longer batches overnight.

## Dataset Output Rule

Generated images should be saved to the exact `save_to` path in:

`ml-dataset/generation_prompts/synthetic_pilot_batch_prompts.md`

The image files stay on the external drive. The project only keeps manifests, prompts, and review notes.
