#!/usr/bin/env zsh
set -euo pipefail

AI_ROOT="${SNAPCOPY_AI_ROOT:-/Volumes/AI作品素材/SnapCopy_AI}"
COMFY_ROOT="${AI_ROOT}/ComfyUI"
VENV_ROOT="${AI_ROOT}/comfyui-venv"
OUTPUT_ROOT="${SNAPCOPY_COMFY_OUTPUT_ROOT:-/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/comfyui_output}"

if [[ ! -d "${COMFY_ROOT}" ]]; then
  echo "ComfyUI not found at ${COMFY_ROOT}"
  exit 1
fi

if [[ ! -d "${VENV_ROOT}" ]]; then
  echo "Virtualenv not found at ${VENV_ROOT}"
  exit 1
fi

mkdir -p "${OUTPUT_ROOT}"

source "${VENV_ROOT}/bin/activate"
export PYTORCH_ENABLE_MPS_FALLBACK=1

cd "${COMFY_ROOT}"
echo "Starting ComfyUI..."
echo "Open http://127.0.0.1:8188 in your browser."
echo "Output directory: ${OUTPUT_ROOT}"

python main.py \
  --listen 127.0.0.1 \
  --port 8188 \
  --output-directory "${OUTPUT_ROOT}"
