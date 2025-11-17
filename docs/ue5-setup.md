# Unreal Engine 5 Build Automation Setup Guide

Complete guide to setting up automated UE5 builds with GitHub Actions.

---

## Prerequisites

- Unreal Engine 5 project in Git repository
- GitHub account
- Windows build server (for most platforms)
- Epic Games account with UE5 access

---

## Step 1: Prepare Your UE5 Project

### Generate Visual Studio Project Files

```bash
# Right-click .uproject file → Generate Visual Studio project files
# Or use command line:
"C:\Program Files\Epic Games\UE_5.4\Engine\Build\BatchFiles\Build.bat" ^
  -projectfiles ^
  -project="C:\Path\To\YourProject.uproject" ^
  -game -engine
```

### Verify BuildCookRun Works Locally

Test the build command locally first:

```bash
"C:\Program Files\Epic Games\UE_5.4\Engine\Build\BatchFiles\RunUAT.bat" ^
  BuildCookRun ^
  -project="C:\Path\To\YourProject.uproject" ^
  -platform=Win64 ^
  -configuration=Development ^
  -cook -build -stage -package ^
  -archive -archivedirectory="C:\Builds"
```

---

## Step 2: Copy Workflow File

1. **Create workflow directory:**
   ```bash
   mkdir -p .github/workflows
   ```

2. **Copy UE5 workflow:**
   ```bash
   cp /path/to/game-automation/ue5/workflows/build.yml .github/workflows/ue5-build.yml
   ```

3. **Update configuration:**
   ```yaml
   # Edit .github/workflows/ue5-build.yml

   env:
     UE_VERSION: '5.4'
     PROJECT_NAME: YourGameProject
     UPROJECT_FILE: YourProject.uproject
   ```

---

## Step 3: Self-Hosted Runner Setup

UE5 builds are too large for GitHub's cloud runners. You NEED self-hosted runners.

### Option A: Windows Build Server (Recommended)

**Deploy with OpenTofu:**

```bash
cd infrastructure
tofu init
tofu apply -var="enable_ue5_builder=true"
```

**Manual Setup:**

1. **Install UE5:**
   - Download Epic Games Launcher
   - Install UE5 (same version as your project)
   - Install to: `C:\Program Files\Epic Games\UE_5.4\`

2. **Install Build Tools:**
   ```powershell
   # Install Visual Studio 2022 Build Tools
   choco install visualstudio2022buildtools
   choco install visualstudio2022-workload-vctools

   # Install .NET SDK
   choco install dotnet-sdk
   ```

3. **Install GitHub Runner:**
   ```powershell
   # Download runner
   mkdir C:\actions-runner
   cd C:\actions-runner

   Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip -OutFile runner.zip

   Expand-Archive -Path runner.zip -DestinationPath .

   # Configure
   .\config.cmd --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN --labels ue5,windows

   # Install as service
   .\svc.cmd install
   .\svc.cmd start
   ```

### Option B: Linux Build Server (Cross-Platform)

For Linux/Mac builds, you need Linux runners with UE5 source build.

```bash
# Clone UE5 source (requires Epic Games account)
git clone https://github.com/EpicGames/UnrealEngine.git
cd UnrealEngine
git checkout 5.4

# Build UE5 from source
./Setup.sh
./GenerateProjectFiles.sh
make
```

---

## Step 4: Configure GitHub Secrets

Add these secrets in GitHub repo Settings → Secrets:

| Secret Name | Description | Required |
|------------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key | For S3 uploads |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | For S3 uploads |
| `DISCORD_WEBHOOK` | Discord webhook URL | For notifications |

---

## Step 5: Update Workflow for Your Project

### Set Project Path

```yaml
env:
  UE_VERSION: '5.4'
  PROJECT_NAME: MyAwesomeGame  # Your project name
  PROJECT_PATH: UnrealProject
  UPROJECT_FILE: UnrealProject/MyAwesomeGame.uproject  # Path to .uproject
```

### Configure Build Platforms

```yaml
strategy:
  matrix:
    include:
      - os: windows-latest
        platform: Win64
        config: Development
      - os: windows-latest
        platform: Win64
        config: Shipping
      - os: ubuntu-latest  # Requires UE5 source build
        platform: Linux
        config: Development
```

### Add Custom Build Steps

```yaml
- name: Custom Pre-Build
  run: |
    # Download assets from LFS
    git lfs pull

    # Run custom scripts
    powershell -File Scripts/PreBuild.ps1
```

---

## Step 6: Test the Pipeline

1. **Push to GitHub:**
   ```bash
   git add .github/workflows/ue5-build.yml
   git commit -m "Add UE5 CI/CD pipeline"
   git push origin main
   ```

2. **Monitor build:**
   - Go to GitHub → Actions tab
   - First build: 60-120 minutes (compiles everything)
   - Incremental builds: 15-30 minutes

3. **Download build:**
   - Completed workflow → Artifacts section
   - Download `Build-Win64-Development`
   - Extract and run .exe

---

## Step 7: Optimize Build Performance

### Enable Incremental Builds

UE5 supports incremental compilation - only rebuild changed files.

```yaml
- name: Restore Build Cache
  uses: actions/cache@v3
  with:
    path: |
      ${{ env.PROJECT_PATH }}/Intermediate
      ${{ env.PROJECT_PATH }}/Saved
    key: ue5-build-${{ matrix.platform }}-${{ hashFiles('**/*.cpp', '**/*.h') }}
```

### Use UnrealBuildTool Optimizations

```bash
RunUAT.bat BuildCookRun \
  -project="YourProject.uproject" \
  -nocompileeditor \      # Don't rebuild editor
  -nodebuginfo \          # Skip debug symbols
  -Manifest \             # Generate file manifest
  -SkipCookingEditorContent  # Skip editor-only content
```

### Parallel Cooking

```bash
RunUAT.bat BuildCookRun \
  -cook \
  -cookonthefly \         # Faster cooking
  -iterativecooking \     # Only cook changed assets
  -cookthreads=8          # Parallel cooking
```

---

## Step 8: S3 Upload Configuration

Store large UE5 builds in S3.

1. **Create S3 bucket:**
   ```bash
   aws s3 mb s3://your-ue5-builds

   # Enable versioning
   aws s3api put-bucket-versioning \
     --bucket your-ue5-builds \
     --versioning-configuration Status=Enabled
   ```

2. **Update workflow:**
   ```yaml
   - name: Upload to S3
     run: |
       aws s3 sync builds/ \
         s3://your-ue5-builds/win64/development/${{ github.sha }}/ \
         --storage-class INTELLIGENT_TIERING
   ```

3. **Generate pre-signed download URLs:**
   ```bash
   aws s3 presign s3://your-ue5-builds/win64/development/abc123/YourGame.exe \
     --expires-in 604800  # 7 days
   ```

---

## Step 9: Advanced Configuration

### Custom Build Graph

UE5 BuildGraph allows complex build pipelines.

Create `BuildGraph.xml`:

```xml
<?xml version='1.0' ?>
<BuildGraph xmlns="http://www.epicgames.com/BuildGraph" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Agent Name="Default Agent" Type="Win64">

    <!-- Compile game -->
    <Node Name="Compile Game">
      <Compile Target="YourGame" Platform="Win64" Configuration="Development"/>
    </Node>

    <!-- Cook content -->
    <Node Name="Cook" Requires="Compile Game">
      <Cook Project="YourGame" Platform="Win64"/>
    </Node>

    <!-- Package -->
    <Node Name="Package" Requires="Cook">
      <Package Project="YourGame" Platform="Win64"/>
    </Node>

    <!-- Run tests -->
    <Node Name="Test" Requires="Package">
      <Command Name="RunAutomationTests" Arguments="-project=YourGame.uproject"/>
    </Node>

  </Agent>
</BuildGraph>
```

Run with:

```bash
RunUAT.bat BuildGraph \
  -Script=BuildGraph.xml \
  -Target="Package" \
  -Clean
```

### Dedicated Server Builds

```yaml
- name: Build Dedicated Server
  run: |
    RunUAT.bat BuildCookRun \
      -project="${{ env.UPROJECT_FILE }}" \
      -platform=Win64 \
      -configuration=Development \
      -server \
      -serverconfig=Development \
      -noclient \
      -cook -build -stage -package
```

### Plugin Development

```yaml
- name: Build Plugin
  run: |
    RunUAT.bat BuildPlugin \
      -Plugin=MyPlugin/MyPlugin.uplugin \
      -Package=Output/MyPlugin \
      -CreateSubFolder
```

---

## Troubleshooting

### Build Timeout

UE5 builds can take hours. Increase timeout:

```yaml
jobs:
  build:
    timeout-minutes: 300  # 5 hours
```

### Out of Disk Space

UE5 builds are HUGE (10-50 GB). Free space:

```powershell
# Clean intermediate files
Remove-Item -Recurse -Force "$env:PROJECT_PATH\Intermediate"
Remove-Item -Recurse -Force "$env:PROJECT_PATH\Saved\Cooked"

# Clean old builds
Get-ChildItem C:\Builds -Directory |
  Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-7)} |
  Remove-Item -Recurse -Force
```

### Shader Compilation Timeout

```ini
; Add to DefaultEngine.ini
[DevOptions.Shaders]
bAllowCompilingThroughWorkers=True
bAllowAsynchronousShaderCompiling=True
MaxShaderJobBatchSize=100
```

### Missing Dependencies

```bash
# Install prerequisites
.\Engine\Extras\Redist\en-us\UEPrereqSetup_x64.exe /quiet
```

### Automation Tests Fail

```bash
# Run tests with verbose logging
RunUAT.bat BuildCookRun \
  -project="YourProject.uproject" \
  -RunAutomationTests \
  -ReportOutputPath="TestReports" \
  -log="AutomationTests.log" \
  -verbose
```

---

## Best Practices

1. **Use incremental builds** - Cache Intermediate folders
2. **Parallel cooking** - Use `-cookonthefly` for faster cooking
3. **Skip debug info in Shipping** - Reduces build size 50%
4. **Clean builds weekly** - Prevent build corruption
5. **Separate editor and game builds** - `-nocompileeditor`
6. **Monitor disk space** - UE5 builds consume 30-100 GB
7. **Use BuildGraph for complex pipelines** - Better than shell scripts
8. **Test builds locally first** - Saves CI time

---

## Performance Benchmarks

### Build Times (Medium Project, 20GB)

| Configuration | Cloud Runner | Self-Hosted (c5.4xlarge) | Self-Hosted (c5.9xlarge) |
|--------------|--------------|-------------------------|-------------------------|
| Development | N/A (too large) | 45 min | 25 min |
| Shipping | N/A (too large) | 75 min | 40 min |

### Disk Usage

| Component | Size |
|-----------|------|
| UE5 Engine | 50 GB |
| Project Source | 5-20 GB |
| Intermediate Files | 10-30 GB |
| Cooked Content | 10-40 GB |
| Packaged Build | 5-20 GB |
| **Total** | **80-160 GB** |

---

## Cost Optimization

### EC2 Instance Recommendations

| Team Size | Instance Type | vCPU | RAM | Monthly Cost | Build Time |
|-----------|--------------|------|-----|--------------|------------|
| 1-3 devs | c5.2xlarge | 8 | 16 GB | $250 | 60 min |
| 4-10 devs | c5.4xlarge | 16 | 32 GB | $500 | 35 min |
| 10+ devs | c5.9xlarge | 36 | 72 GB | $1,200 | 20 min |

### Spot Instances

Save 70% with EC2 Spot:

```bash
# Use Spot instances in OpenTofu
resource "aws_instance" "ue5_build_server" {
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.50"  # per hour
    }
  }
}
```

---

## Next Steps

- [ ] Set up automated testing
- [ ] Configure Steam upload
- [ ] Add crash reporting
- [ ] Set up build analytics
- [ ] Create custom Build Graph
- [ ] Implement dedicated server builds
- [ ] Add plugin CI/CD

---

## Resources

- [UE5 Automation Documentation](https://docs.unrealengine.com/5.4/en-US/automation-system-overview-in-unreal-engine/)
- [BuildGraph Reference](https://docs.unrealengine.com/5.4/en-US/buildgraph-for-unreal-engine/)
- [UnrealBuildTool](https://docs.unrealengine.com/5.4/en-US/unreal-build-tool-in-unreal-engine/)
- [GitHub Actions for UE5](https://github.com/marketplace?type=actions&query=unreal)
