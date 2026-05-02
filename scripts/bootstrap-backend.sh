#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# bootstrap-backend.sh
# Creates S3 bucket + DynamoDB table for Terraform remote state.
# Run ONCE before your first `terraform init`.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="hermes-terraform-state-${ACCOUNT_ID}"
DYNAMODB_TABLE="hermes-terraform-locks"

echo "==> Creating S3 state bucket: ${BUCKET_NAME}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "    Bucket already exists — skipping"
else
  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi

  # Enable versioning for state history
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  # Block all public access
  aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  # Enable server-side encryption
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  echo "    ✅ Bucket created and secured"
fi

echo "==> Creating DynamoDB lock table: ${DYNAMODB_TABLE}"
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" 2>/dev/null; then
  echo "    Table already exists — skipping"
else
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}"
  echo "    ✅ DynamoDB table created"
fi

echo ""
echo "==> Update terraform/backend.tf with:"
echo "    bucket = \"${BUCKET_NAME}\""
echo ""
echo "==> Store secrets in SSM Parameter Store:"
echo "    aws ssm put-parameter --name /hermes/openai_api_key --value '<KEY>' --type SecureString"
echo "    aws ssm put-parameter --name /hermes/telegram_bot_token --value '<TOKEN>' --type SecureString"
echo ""
echo "==> Add to GitHub Secrets:"
echo "    AWS_ROLE_ARN  = $(aws iam get-role --role-name hermes-github-actions-role --query Role.Arn --output text 2>/dev/null || echo 'run terraform apply first')"
echo ""
echo "✅ Bootstrap complete!"
