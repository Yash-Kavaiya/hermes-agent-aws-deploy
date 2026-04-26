###############################################################
# Dockerfile
# Builds Hermes Agent from the official upstream repo.
###############################################################
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ── System deps ───────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    curl git ca-certificates gnupg \
    python3 python3-pip python3-venv \
    nodejs npm \
    build-essential libssl-dev \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# ── Install uv (fast Python package manager) ─────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:/root/.local/bin:$PATH"

# ── Clone Hermes from upstream ────────────────────────────────
WORKDIR /app
RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent.git . \
    && git submodule update --init mini-swe-agent

# ── Python venv + install ─────────────────────────────────────
RUN uv venv .venv --python 3.11
ENV PATH="/app/.venv/bin:$PATH"
RUN uv pip install -e ".[all]" \
    && uv pip install -e "./mini-swe-agent"

# ── Config directory ──────────────────────────────────────────
RUN mkdir -p /root/.hermes

# ── Copy our custom hermes config ────────────────────────────
COPY hermes-config.yaml /root/.hermes/config.yaml

# ── Expose gateway port ───────────────────────────────────────
EXPOSE 8080

# ── Entrypoint ────────────────────────────────────────────────
# Runs the messaging gateway so you can access Hermes via browser / Telegram
CMD ["python", "-m", "hermes_cli.main", "gateway", "start"]
