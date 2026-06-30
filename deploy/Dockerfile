# Dockerfile for serving Gemma via vLLM on Cloud Run L4 GPU
# Uses official vLLM OpenAI-compatible API server image

FROM vllm/vllm-openai:gemma4

# Set environment variables to optimize for FUSE and prevent implicit downloads
ENV HF_HUB_DISABLE_IMPLICIT_DOWNLOAD=1
ENV PYTHONUNBUFFERED=1

# Clean any residual HF cache in the base image to minimize footprint
RUN rm -rf /root/.cache/huggingface/*

# Expose vLLM port
EXPOSE 8000

# Set entrypoint. Optimized for regional L4 GPUs (16GB VRAM):
# - --enforce-eager: Disables CUDA graphs to save ~1-2GB of VRAM (crucial for 16GB GPUs)
# - --max-model-len 8192: Limits context length to fit within GPU VRAM
# - --limit-mm-per-prompt: Disables multimodal input processors to save resources
ENTRYPOINT [ \
    "python3", "-m", "vllm.entrypoints.openai.api_server", \
    "--limit-mm-per-prompt", "{\"image\":0,\"audio\":0}", \
    "--max-model-len", "8192", \
    "--enforce-eager" \
]
