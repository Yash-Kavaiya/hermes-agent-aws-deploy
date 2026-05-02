#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# store-secrets.sh
# Stores API keys in AWS SSM Parameter Store (encrypted).
# Usage: ./scripts/store-secrets.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"

read -rsp "Enter OPENAI_API_KEY: " OPENAI_KEY; echo
read -rsp "Enter TELEGRAM_BOT_TOKEN (press Enter to skip): " TELEGRAM_TOKEN; echo

echo "==> Storing /hermes/openai_api_key in SSM..."
aws ssm put-parameter \
  --name "/hermes/openai_api_key" \
  --value "${OPENAI_KEY}" \
  --type "SecureString" \
  --region "${AWS_REGION}" \
  --overwrite
echo "    ✅ OpenAI API key stored"

if [ -n "${TELEGRAM_TOKEN}" ]; then
  echo "==> Storing /hermes/telegram_bot_token in SSM..."
  aws ssm put-parameter \
    --name "/hermes/telegram_bot_token" \
    --value "${TELEGRAM_TOKEN}" \
    --type "SecureString" \
    --region "${AWS_REGION}" \
    --overwrite
  echo "    ✅ Telegram token stored"
fi

echo ""
echo "✅ Secrets stored. ECS tasks will pull them at runtime via IAM."
