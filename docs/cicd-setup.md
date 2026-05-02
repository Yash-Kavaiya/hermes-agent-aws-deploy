# CI/CD Setup Guide — Hermes Agent on AWS

This guide walks you through setting up the end-to-end GitHub Actions → AWS deployment pipeline.

## Architecture

```
GitHub Push → GitHub Actions ──► ECR (Docker image)
                            ──► Terraform (infra)
                            ──► ECS Fargate (deploy)
                            ──► ALB (public URL)
```

## Prerequisites

- AWS CLI configured locally (`aws configure`)
- Terraform >= 1.7 installed
- Docker installed
- AWS account with sufficient permissions

## Step 1: Bootstrap Terraform Remote State (Run Once)

```bash
chmod +x scripts/bootstrap-backend.sh
./scripts/bootstrap-backend.sh
```

This creates:
- **S3 bucket** for Terraform state with versioning + encryption
- **DynamoDB table** for state locking

Then update `terraform/backend.tf` with the bucket name printed by the script.

## Step 2: Store Secrets in SSM Parameter Store

```bash
chmod +x scripts/store-secrets.sh
./scripts/store-secrets.sh
```

Or manually:
```bash
aws ssm put-parameter --name /hermes/openai_api_key \
  --value "sk-..." --type SecureString --region us-east-1

aws ssm put-parameter --name /hermes/telegram_bot_token \
  --value "123456:ABC..." --type SecureString --region us-east-1
```

## Step 3: Provision Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan -var="aws_region=us-east-1" -var="openai_api_key=placeholder"
terraform apply -var="aws_region=us-east-1" -var="openai_api_key=placeholder"
```

This creates: VPC, Subnets, ECR repo, ECS Cluster, Fargate Service, ALB, IAM OIDC role.

## Step 4: Configure GitHub Secrets

Add these in **GitHub → Settings → Secrets → Actions**:

| Secret | Value | How to get |
|--------|-------|------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/hermes-github-actions-role` | From Terraform output |
| `OPENAI_API_KEY` | `sk-...` | Your OpenAI key (used in ECS env render step) |
| `TELEGRAM_BOT_TOKEN` | `123456:ABC...` | Optional Telegram bot |

Get the role ARN:
```bash
terraform output github_actions_role_arn
```

## Step 5: Push to main — Pipeline Runs Automatically

Push any code change to `main`:
1. **Lint & Scan** — Hadolint, Trivy, Terraform validate
2. **Build & Push** — Docker image → ECR with SHA tag
3. **Terraform Apply** — Infrastructure drift correction
4. **ECS Deploy** — Rolling update with circuit breaker
5. **Smoke Test** — Waits for stability, checks `/health`

## Pipeline Overview

| Job | Trigger | Duration |
|-----|---------|----------|
| Lint & Scan | Every push/PR | ~2 min |
| Build & Push | Push to main | ~8-12 min |
| Terraform | Push to main | ~3-5 min |
| ECS Deploy | Push to main | ~5-8 min |
| Smoke Test | After deploy | ~2 min |

## Manual Destroy

To tear down all AWS resources:
1. Go to **GitHub Actions → Terraform Destroy (Manual)**
2. Click **Run workflow**
3. Type `DESTROY` in the confirmation field

## Cost Estimate

| Resource | Monthly Cost |
|----------|--------------|
| ECS Fargate (0.5 vCPU, 1GB) | ~$15-20 |
| ALB | ~$18 |
| ECR storage | ~$0.10/GB |
| CloudWatch Logs | ~$0.50 |
| **Total** | **~$35-40/month** |

## Troubleshooting

**Build fails with ECR auth error:**
→ Check `AWS_ROLE_ARN` secret is set correctly.

**ECS service won't stabilize:**
→ Check CloudWatch Logs at `/ecs/hermes-agent`.
→ Verify secrets exist in SSM: `aws ssm get-parameter --name /hermes/openai_api_key`

**Terraform plan fails:**
→ Ensure S3 backend bucket name in `backend.tf` matches the one created by bootstrap script.
