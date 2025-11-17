# Unity Build Automation Setup Guide

Complete guide to setting up automated Unity builds with GitHub Actions.

---

## Prerequisites

- Unity project in a Git repository
- GitHub account
- Unity license (Plus, Pro, or Enterprise for build automation)

---

## Step 1: Get Unity Activation License

Unity requires a license file for CI/CD builds.

### Option A: Personal/Plus License

1. **Get activation file:**
   ```bash
   docker run -it --rm \
     -v "$(pwd):/unity" \
     unityci/editor:2023.2.0f1 \
     unity-editor -quit -batchmode -nographics \
     -logfile - -createManualActivationFile
   ```

2. **Upload to Unity:**
   - Go to https://license.unity3d.com/manual
   - Upload `Unity_v2023.x.alf` file
   - Download `Unity_v2023.x.ulf` license file

3. **Add to GitHub Secrets:**
   ```bash
   # Copy contents of .ulf file
   cat Unity_v2023.2.0f1.ulf | pbcopy

   # Add to GitHub repo:
   # Settings → Secrets → New repository secret
   # Name: UNITY_LICENSE
   # Value: [paste file contents]
   ```

### Option B: Pro/Enterprise License

Add these GitHub Secrets:
- `UNITY_EMAIL`: Your Unity account email
- `UNITY_PASSWORD`: Your Unity account password
- `UNITY_SERIAL`: Your Unity Pro/Enterprise serial key

---

## Step 2: Copy Workflow File

1. **Create workflow directory:**
   ```bash
   mkdir -p .github/workflows
   ```

2. **Copy build workflow:**
   ```bash
   cp /path/to/game-automation/unity/workflows/build.yml .github/workflows/unity-build.yml
   ```

3. **Update configuration:**
   ```yaml
   # Edit .github/workflows/unity-build.yml

   env:
     UNITY_VERSION: 2023.2.0f1  # Your Unity version
     PROJECT_PATH: .             # Path to Unity project (if in root)
   ```

---

## Step 3: Configure GitHub Secrets

Add these secrets in GitHub repo Settings → Secrets:

| Secret Name | Description | Required |
|------------|-------------|----------|
| `UNITY_LICENSE` | License file content (.ulf) | ✅ Yes |
| `UNITY_EMAIL` | Unity account email | For Pro/Enterprise |
| `UNITY_PASSWORD` | Unity account password | For Pro/Enterprise |
| `AWS_ACCESS_KEY_ID` | AWS access key | For S3 uploads |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | For S3 uploads |
| `DISCORD_WEBHOOK` | Discord webhook URL | For notifications |

---

## Step 4: Test the Pipeline

1. **Push to GitHub:**
   ```bash
   git add .github/workflows/unity-build.yml
   git commit -m "Add Unity CI/CD pipeline"
   git push origin main
   ```

2. **Watch build:**
   - Go to GitHub → Actions tab
   - See workflow run automatically
   - First build takes ~30-45 min (caches library)
   - Subsequent builds: ~10-15 min

3. **Download artifacts:**
   - Go to completed workflow run
   - See "Artifacts" section
   - Download `Build-StandaloneWindows64`

---

## Step 5: Customize Build Targets

### Build Specific Platforms

Edit workflow matrix:

```yaml
strategy:
  matrix:
    targetPlatform:
      - StandaloneWindows64  # Windows
      - StandaloneLinux64    # Linux
      - StandaloneOSX        # macOS
      - WebGL                # Browser
      - Android              # Android
      - iOS                  # iOS (requires macOS runner)
```

### Build on Specific Branches

```yaml
on:
  push:
    branches:
      - main
      - develop
      - release/*
```

### Build on Schedule

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
```

---

## Step 6: S3 Upload Configuration (Optional)

Store builds in AWS S3 for easy access.

1. **Create S3 bucket:**
   ```bash
   aws s3 mb s3://your-game-builds
   ```

2. **Update workflow:**
   ```yaml
   # Change bucket name in build.yml
   aws s3 sync builds/${{ matrix.targetPlatform }} \
     s3://your-game-builds/unity/${{ matrix.targetPlatform }}/$(git rev-parse --short HEAD)/
   ```

3. **Create IAM user:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::your-game-builds",
           "arn:aws:s3:::your-game-builds/*"
         ]
       }
     ]
   }
   ```

---

## Step 7: Self-Hosted Runner (Advanced)

For faster builds and lower costs.

### Deploy with OpenTofu

```bash
cd infrastructure
tofu init
tofu apply -var="enable_unity_builder=true"
```

### Configure Runner

```bash
# SSH to server
ssh ubuntu@<unity-server-ip>

# Configure GitHub runner
cd /home/ubuntu/actions-runner
./config.sh \
  --url https://github.com/YOUR_ORG/YOUR_REPO \
  --token YOUR_REGISTRATION_TOKEN \
  --labels unity,self-hosted

# Start runner
sudo systemctl start github-runner
```

### Update Workflow

```yaml
jobs:
  build:
    runs-on: [self-hosted, unity]  # Use self-hosted runner
```

---

## Troubleshooting

### Build Fails: "License Not Valid"

**Solution:**
```bash
# Re-generate activation file
docker run -it --rm unityci/editor:2023.2.0f1 \
  unity-editor -quit -batchmode -createManualActivationFile

# Upload to Unity and get new .ulf file
# Update UNITY_LICENSE secret
```

### Build Timeout

**Solution:**
```yaml
jobs:
  build:
    timeout-minutes: 90  # Increase timeout
```

### Library Cache Not Working

**Solution:**
```yaml
- uses: actions/cache@v3
  with:
    path: Library
    key: Library-${{ matrix.targetPlatform }}-${{ hashFiles('Assets/**', 'Packages/**', 'ProjectSettings/**') }}
```

### Out of Disk Space

**Solution:**
```yaml
- name: Free Disk Space
  run: |
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
    sudo apt-get clean
```

---

## Best Practices

1. **Use Library caching** - Speeds up builds 3x
2. **Build matrix for multiple platforms** - Parallel builds
3. **Run tests before build** - Catch issues early
4. **Tag releases** - Link builds to versions
5. **Store artifacts in S3** - GitHub has 90-day retention
6. **Use self-hosted for large projects** - Much faster
7. **Enable build notifications** - Keep team informed

---

## Cost Optimization

### GitHub Actions Minutes

- **Free tier:** 2,000 minutes/month
- **Unity build:** ~30 min/platform
- **Max builds:** ~66 builds/month on free tier

### Self-Hosted Savings

- **GitHub Actions (team):** $4/user/month + build minutes
- **Self-hosted (c5.4xlarge):** ~$500/month
- **Break-even:** ~60 builds/month

**Recommendation:**
- < 50 builds/month: Use GitHub Actions
- \> 50 builds/month: Use self-hosted

---

## Next Steps

- [ ] Set up automated tests (Edit mode + Play mode)
- [ ] Configure build versioning
- [ ] Add performance profiling
- [ ] Set up asset bundle builds
- [ ] Integrate with Steam/Epic/App Store deployment
- [ ] Add code coverage reporting

---

## Resources

- [Unity CI/CD Docs](https://docs.unity3d.com/Manual/CommandLineArguments.html)
- [GameCI Documentation](https://game.ci/)
- [Unity Test Framework](https://docs.unity3d.com/Packages/com.unity.test-framework@latest)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
