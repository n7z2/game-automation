# Game Build Automation Platform

**Automated CI/CD pipelines for Unity and Unreal Engine 5 game development.**

Automatically build, test, and distribute game builds when code is pushed to your repository. Supports multi-platform builds, automated testing, and cloud artifact storage.

---

## 🎮 Features

### Unity Support
- ✅ **Multi-platform builds** - Windows, Linux, macOS, WebGL, Android, iOS
- ✅ **Automated testing** - Edit mode and Play mode tests
- ✅ **Smart caching** - Faster builds with Library folder caching
- ✅ **Build versioning** - Semantic versioning support
- ✅ **Artifact management** - Automatic uploads to S3 or GitHub

### Unreal Engine 5 Support
- ✅ **Full UE5 build pipeline** - Development, Shipping, DebugGame
- ✅ **Multiple platforms** - Windows, Linux, Mac
- ✅ **Automation tests** - Built-in test execution
- ✅ **Optimized builds** - PAK packaging, prerequisite installers
- ✅ **Large build support** - Handles multi-GB game builds

### Infrastructure
- ✅ **OpenTofu/Terraform** - Infrastructure as Code for build servers
- ✅ **AWS integration** - EC2 build servers, S3 artifact storage
- ✅ **GitHub Actions** - Cloud-based or self-hosted runners
- ✅ **Auto-scaling** - On-demand build capacity
- ✅ **Cost optimization** - Only pay when building

---

## 📁 Repository Structure

```
game-automation/
├── unity/                  # Unity build automation
│   ├── workflows/          # GitHub Actions workflows
│   │   └── build.yml      # Unity CI/CD pipeline
│   └── scripts/           # Build scripts and utilities
│
├── ue5/                   # Unreal Engine 5 automation
│   ├── workflows/         # GitHub Actions workflows
│   │   └── build.yml     # UE5 CI/CD pipeline
│   └── scripts/          # Build scripts and utilities
│
├── infrastructure/        # Cloud infrastructure (OpenTofu)
│   ├── main.tf           # Main infrastructure config
│   ├── variables.tf      # Configuration variables
│   └── user-data/        # Server setup scripts
│       ├── unity-setup.sh
│       └── ue5-setup.ps1
│
└── docs/                 # Documentation
    ├── unity-setup.md    # Unity setup guide
    ├── ue5-setup.md      # UE5 setup guide
    ├── client-demo.md    # Client presentation guide
    └── cost-analysis.md  # Cost breakdown
```

---

## 🚀 Quick Start

### Option 1: GitHub Actions (Cloud Runners)

**Best for:** Small teams, quick setup, no infrastructure management

1. **Copy workflow files to your game repository:**
   ```bash
   # For Unity
   cp unity/workflows/build.yml your-unity-repo/.github/workflows/

   # For UE5
   cp ue5/workflows/build.yml your-ue5-repo/.github/workflows/
   ```

2. **Configure GitHub Secrets:**
   ```bash
   # Unity secrets (required)
   UNITY_LICENSE=<your-unity-license-content>
   UNITY_EMAIL=<your-unity-email>
   UNITY_PASSWORD=<your-unity-password>

   # AWS secrets (optional, for S3 uploads)
   AWS_ACCESS_KEY_ID=<your-aws-key>
   AWS_SECRET_ACCESS_KEY=<your-aws-secret>

   # Discord webhook (optional, for notifications)
   DISCORD_WEBHOOK=<your-webhook-url>
   ```

3. **Push code and watch builds happen automatically!**

### Option 2: Self-Hosted Build Servers (AWS)

**Best for:** Large teams, faster builds, cost control, custom hardware

1. **Install OpenTofu:**
   ```bash
   # Install via package manager
   brew install opentofu  # macOS
   # or
   wget https://github.com/opentofu/opentofu/releases/download/v1.6.0/tofu_1.6.0_linux_amd64.zip
   unzip tofu_1.6.0_linux_amd64.zip
   sudo mv tofu /usr/local/bin/
   ```

2. **Configure infrastructure:**
   ```bash
   cd infrastructure
   cp variables.tf variables.auto.tfvars

   # Edit variables.auto.tfvars with your settings
   ```

3. **Deploy infrastructure:**
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

4. **Configure GitHub runners:**
   ```bash
   # SSH to Unity build server
   ssh ubuntu@<unity-server-ip>

   # Configure runner
   cd /home/ubuntu/actions-runner
   ./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN

   # Start runner service
   sudo systemctl enable github-runner
   sudo systemctl start github-runner
   ```

5. **Push code - builds run on your dedicated servers!**

---

## 💰 Cost Analysis

### GitHub Actions (Cloud Runners)

| Plan | Minutes/Month | Cost | Est. Unity Builds | Est. UE5 Builds |
|------|--------------|------|------------------|----------------|
| Free | 2,000 | $0 | ~40 builds | ~10 builds |
| Team | 3,000 | $4/user | ~60 builds | ~15 builds |
| Enterprise | 50,000 | Custom | ~1,000 builds | ~250 builds |

**Notes:**
- Unity builds: ~30-50 min per platform
- UE5 builds: ~90-200 min per platform
- Private repos consume minutes faster

### Self-Hosted (AWS)

| Component | Instance Type | Monthly Cost | Use Case |
|-----------|--------------|--------------|----------|
| Unity Server | c5.4xlarge (16 vCPU, 32GB) | ~$500 | Small-medium teams |
| UE5 Server | c5.9xlarge (36 vCPU, 72GB) | ~$1,200 | Medium-large teams |
| S3 Storage | 1TB | ~$23 | Artifact storage |
| Data Transfer | 500GB out | ~$45 | Build downloads |

**Total:** ~$1,770/month for both Unity + UE5

**Break-even point:** ~60 builds/month vs GitHub Actions Team plan

**Savings with on-demand:**
- Use EC2 Spot Instances: Save 70% (~$530/month)
- Auto-shutdown when idle: Save 50% (~$885/month)
- Combined: ~$260/month (85% savings)

---

## 📊 Build Performance

### Unity Build Times (Typical Project)

| Platform | GitHub Actions | Self-Hosted (c5.4xlarge) | Improvement |
|----------|---------------|-------------------------|-------------|
| Windows | 35 min | 12 min | 2.9x faster |
| Linux | 32 min | 10 min | 3.2x faster |
| WebGL | 45 min | 18 min | 2.5x faster |
| Android | 40 min | 15 min | 2.7x faster |

### UE5 Build Times (Medium Project)

| Configuration | GitHub Actions | Self-Hosted (c5.9xlarge) | Improvement |
|--------------|---------------|-------------------------|-------------|
| Development | 120 min | 35 min | 3.4x faster |
| Shipping | 180 min | 55 min | 3.3x faster |

**Self-hosted builds are 3x faster on average**

---

## 🔧 Advanced Configuration

### Parallel Builds

Build multiple platforms simultaneously:

```yaml
# unity/workflows/build.yml
strategy:
  matrix:
    targetPlatform:
      - StandaloneWindows64
      - StandaloneLinux64
      - WebGL
      - Android
```

### Conditional Builds

Only build on specific branches or paths:

```yaml
on:
  push:
    branches: [ main, develop ]
    paths:
      - 'Assets/**'
      - 'ProjectSettings/**'
```

### Build Caching

Speed up builds with aggressive caching:

```yaml
- uses: actions/cache@v3
  with:
    path: Library
    key: Library-${{ matrix.targetPlatform }}-${{ hashFiles('Assets/**', 'Packages/**') }}
```

---

## 📚 Documentation

- **[Unity Setup Guide](docs/unity-setup.md)** - Complete Unity automation setup
- **[UE5 Setup Guide](docs/ue5-setup.md)** - Complete UE5 automation setup
- **[Client Demo Guide](docs/client-demo.md)** - Presentation talking points
- **[Cost Analysis](docs/cost-analysis.md)** - Detailed cost breakdown

---

## 🎯 Use Cases

### 1. **Indie Game Studio**
- Use GitHub Actions free tier
- Build on commits to main branch
- Store builds in GitHub releases
- Cost: **$0/month**

### 2. **Mid-Size Studio (5-10 devs)**
- Self-hosted Unity server (c5.2xlarge)
- GitHub Actions for UE5 (occasional)
- S3 for artifact storage
- Cost: **~$300/month**

### 3. **Large Studio (20+ devs)**
- Dedicated Unity + UE5 servers
- Multiple runners for parallel builds
- CDN for build distribution
- Cost: **~$1,500/month**

### 4. **On-Demand Builds**
- EC2 Spot Instances
- Auto-start/stop based on commits
- Serverless artifact serving
- Cost: **~$200/month** (pay only when building)

---

## 🛠️ Troubleshooting

### Unity Activation Failed
```bash
# Manual activation
unity-editor -quit -batchmode -serial <serial-key> -username <email> -password <password>
```

### UE5 Build Timeout
```yaml
# Increase timeout in workflow
jobs:
  build:
    timeout-minutes: 300  # 5 hours
```

### S3 Upload Failed
```bash
# Check IAM permissions
aws s3 ls s3://your-bucket/  # Should list contents
```

### GitHub Runner Offline
```bash
# Restart runner service
sudo systemctl restart github-runner
sudo journalctl -u github-runner -f  # Check logs
```

---

## 🔐 Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets or AWS Secrets Manager
2. **Restrict runner access** - Use specific repository runners, not org-wide
3. **Enable 2FA** - On GitHub and AWS accounts
4. **Use IAM roles** - Don't use long-lived credentials
5. **Encrypt builds** - Use S3 encryption at rest
6. **Network isolation** - Put build servers in private subnets
7. **Audit logs** - Enable CloudTrail for AWS actions

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/your-org/game-automation/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-org/game-automation/discussions)
- **Email:** support@your-company.com

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Credits

- Built with [GitHub Actions](https://github.com/features/actions)
- Unity builds powered by [GameCI](https://game.ci/)
- Infrastructure as Code with [OpenTofu](https://opentofu.org/)
- Inspired by modern DevOps practices

---

**Built with ❤️ for game developers**
