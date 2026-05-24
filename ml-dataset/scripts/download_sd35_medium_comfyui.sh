#!/usr/bin/env zsh
set -euo pipefail

AI_ROOT="${SNAPCOPY_AI_ROOT:-/Volumes/AI作品素材/SnapCopy_AI}"
COMFY_ROOT="${AI_ROOT}/ComfyUI"
VENV_ROOT="${AI_ROOT}/comfyui-venv"
REPO_ID="stabilityai/stable-diffusion-3.5-medium"

if [[ ! -d "${COMFY_ROOT}" ]]; then
  echo "ComfyUI not found at ${COMFY_ROOT}"
  exit 1
fi

if [[ ! -d "${VENV_ROOT}" ]]; then
  echo "Virtualenv not found at ${VENV_ROOT}"
  exit 1
fi

source "${VENV_ROOT}/bin/activate"

echo "Checking Hugging Face login..."
if ! hf auth whoami >/dev/null 2>&1; then
  echo ""
  echo "You are not logged in to Hugging Face."
  echo "1. Open: https://huggingface.co/stabilityai/stable-diffusion-3.5-medium"
  echo "2. Log in and click Agree on the model page."
  echo "3. Create a read token at: https://huggingface.co/settings/tokens"
  echo "4. Run: source '${VENV_ROOT}/bin/activate' && hf auth login"
  echo "5. Re-run this script."
  exit 2
fi

mkdir -p "${COMFY_ROOT}/models/checkpoints"
mkdir -p "${COMFY_ROOT}/models/text_encoders"
mkdir -p "${COMFY_ROOT}/user/default/workflows"

echo "Downloading SD3.5 Medium checkpoint..."
hf download "${REPO_ID}" \
  sd3.5_medium.safetensors \
  --local-dir "${COMFY_ROOT}/models/checkpoints"

echo "Downloading SD3.5 Medium text encoders for ComfyUI..."
hf download "${REPO_ID}" \
  --include "text_encoders/clip_l.safetensors" \
  --include "text_encoders/clip_g.safetensors" \
  --include "text_encoders/t5xxl_fp8_e4m3fn.safetensors" \
  --local-dir "${COMFY_ROOT}/models"

echo "Downloading example workflow..."
hf download "${REPO_ID}" \
  SD3.5M_example_workflow.json \
  --local-dir "${COMFY_ROOT}/user/default/workflows"

echo ""
echo "SD3.5 Medium files are ready:"
echo "- ${COMFY_ROOT}/models/checkpoints/sd3.5_medium.safetensors"
echo "- ${COMFY_ROOT}/models/text_encoders/clip_l.safetensors"
echo "- ${COMFY_ROOT}/models/text_encoders/clip_g.safetensors"
echo "- ${COMFY_ROOT}/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors"
