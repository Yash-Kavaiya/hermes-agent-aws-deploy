# 🏺 Hermes Agent — AWS EC2 Deployment

Deploy **[Hermes Agent](https://hermes-agent.nousresearch.com/)** (Nous Research) on a public AWS EC2 instance with one GitHub push.

```
Your browser / Telegram
        │
        ▼
   Elastic IP (permanent)
        │
   Nginx (port 80/443)
        │
   Docker → Hermes Agent (port 8080)
        │
   OpenRouter / Anthropic / OpenAI
```

---

## ⚡ Quick Overview

| File | What it does |
|---|---|
| `terraform/main.tf` | Creates EC2, Security Group, Elastic IP, IAM role |
| `terraform/userdata.sh.tpl` | Bootstraps the EC2 on first boot (Docker, Nginx, Hermes) |
| `Dockerfile` | Builds Hermes from upstream source |
| `docker-compose.yml` | Runs the container with persistent memory volume |
| `.github/workflows/deploy.yml` | Auto-deploys on every `git push` to `main` |

---

## 📋 Prerequisites

- AWS account with programmatic access
- GitHub account
- `terraform` CLI installed locally — [install guide](https://developer.hashicorp.com/terraform/install)
- `aws` CLI configured — `aws configure`
- An SSH key pair — `ssh-keygen -t ed25519 -C "hermes-ec2"`
- An API key from [OpenRouter](https://openrouter.ai) (free tier available)

---

## 🚀 Step-by-Step Setup

### Step 1 — Fork / clone this repo

```bash
# Fork this repo on GitHub, then clone YOUR fork:
git clone https://github.com/YOUR-USERNAME/hermes-ec2.git
cd hermes-ec2
```

### Step 2 — Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # fill in your values
```

**Key values to set in `terraform.tfvars`:**

| Variable | What to put |
|---|---|
| `aws_region` | e.g. `"us-east-1"` |
| `instance_type` | `"t3.medium"` (see table below) |
| `ssh_public_key` | Output of: `cat ~/.ssh/id_ed25519.pub` |
| `allowed_ssh_cidrs` | Your home IP: `["1.2.3.4/32"]` (run `curl ifconfig.me`) |
| `openrouter_api_key` | Your OpenRouter key |
| `github_repo` | `"your-username/hermes-ec2"` |

### Step 3 — Provision AWS infrastructure

```bash
cd terraform
terraform init
terraform plan    # review what will be created
terraform apply   # type 'yes' to confirm
```

**Terraform creates:**
- 1× EC2 instance (Ubuntu 24.04)
- 1× Elastic IP (permanent public IP — copy this!)
- 1× Security Group (ports 22, 80, 443, 8080)
- 1× IAM Role (SSM access, no secrets in CI/CD)
- 1× Key Pair

After apply, note your **public IP**:
```
Outputs:
  public_ip     = "54.123.456.789"   ← your permanent address
  ssh_command   = "ssh ubuntu@54.123.456.789"
  hermes_web_url = "http://54.123.456.789"
```

### Step 4 — Add GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**

Add all of these:

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_REGION` | e.g. `us-east-1` |
| `EC2_PUBLIC_IP` | The Elastic IP from Step 3 |
| `EC2_SSH_PRIVATE_KEY` | Contents of `~/.ssh/id_ed25519` (private key) |
| `EC2_SSH_PUBLIC_KEY` | Contents of `~/.ssh/id_ed25519.pub` |
| `OPENROUTER_API_KEY` | Your OpenRouter key |
| `HERMES_MODEL` | e.g. `openrouter:anthropic/claude-sonnet-4-5` |
| `ANTHROPIC_API_KEY` | *(optional)* Direct Anthropic key |
| `OPENAI_API_KEY` | *(optional)* Direct OpenAI key |
| `TELEGRAM_BOT_TOKEN` | *(optional)* For Telegram integration |
| `DISCORD_BOT_TOKEN` | *(optional)* For Discord integration |

**Minimum required:** `AWS_*`, `EC2_*`, and at least one LLM API key.

### Step 5 — Deploy!

```bash
git add .
git commit -m "Initial Hermes Agent deployment"
git push origin main
```

GitHub Actions will:
1. SSH into your EC2
2. Pull the latest code
3. Write the `.env` file from your secrets
4. Rebuild the Docker container
5. Start Hermes
6. Health-check the URL

Watch it run in: **GitHub → Actions → Deploy Hermes Agent to EC2**

### Step 6 — Access Hermes

Open your browser: **`http://YOUR-ELASTIC-IP`**

Or SSH in and chat via CLI:
```bash
ssh ubuntu@YOUR-ELASTIC-IP
docker exec -it hermes-agent hermes
```

---

## 💻 Instance Size Guide

| Instance | vCPU | RAM | $/month | Best for |
|---|---|---|---|---|
| `t3.small` | 2 | 2 GB | ~$15 | Very light / testing |
| **`t3.medium`** | 2 | 4 GB | **~$30** | **✅ Recommended default** |
| `t3.large` | 2 | 8 GB | ~$60 | Daily heavy use |
| `t3.xlarge` | 4 | 16 GB | ~$120 | Docker sub-agents, parallelism |
| `g4dn.xlarge` | 4 | 16 GB + GPU | ~$380 | Running a local LLM on-device |

> 💡 You also pay for the Elastic IP (~$4/month) and storage (~$2.40/month for 30 GB gp3).

---

## 🔧 Common Commands

```bash
# SSH into the server
ssh ubuntu@YOUR-ELASTIC-IP

# View Hermes logs
docker compose logs -f hermes

# Restart Hermes
docker compose restart hermes

# Update to latest Hermes upstream
docker compose down && docker compose up --build -d

# Open Hermes CLI inside container
docker exec -it hermes-agent hermes

# Check memory usage
docker stats hermes-agent
```

---

## 🔒 Add HTTPS (optional, after you have a domain)

```bash
ssh ubuntu@YOUR-ELASTIC-IP
sudo certbot --nginx -d yourdomain.com
```

Then point your domain's A record to the Elastic IP.

---

## 🗑 Tear Down

```bash
cd terraform
terraform destroy   # removes ALL AWS resources
```

---

## 📚 Hermes Agent Docs

- [Official Docs](https://hermes-agent.nousresearch.com/docs/)
- [GitHub](https://github.com/NousResearch/hermes-agent)
- [Discord](https://discord.gg/NousResearch)

---

MIT License — built on top of [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research.
