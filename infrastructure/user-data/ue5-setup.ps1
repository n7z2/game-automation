<powershell>
# UE5 Build Server Setup Script

Write-Host "Starting UE5 build server setup..."

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install dependencies
choco install -y git
choco install -y 7zip
choco install -y awscli
choco install -y visualstudio2022buildtools
choco install -y visualstudio2022-workload-vctools

# Install .NET SDK
choco install -y dotnet-sdk

# Create workspace directory
New-Item -ItemType Directory -Force -Path C:\GameBuilds
New-Item -ItemType Directory -Force -Path C:\actions-runner

# Download GitHub Actions Runner
$RunnerVersion = "2.311.0"
$RunnerUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"
Invoke-WebRequest -Uri $RunnerUrl -OutFile C:\actions-runner\runner.zip

# Extract runner
Expand-Archive -Path C:\actions-runner\runner.zip -DestinationPath C:\actions-runner -Force
Remove-Item C:\actions-runner\runner.zip

# Setup S3 upload script
$UploadScript = @'
param(
    [string]$BuildPath,
    [string]$Platform,
    [string]$Config
)

$S3Bucket = "${s3_bucket}"
$CommitSha = (git rev-parse --short HEAD)

Write-Host "Uploading build to S3..."
aws s3 sync $BuildPath "s3://$S3Bucket/ue5/$Platform/$Config/$CommitSha/" --delete

Write-Host "Build uploaded to s3://$S3Bucket/ue5/$Platform/$Config/$CommitSha/"
'@

Set-Content -Path "C:\GameBuilds\upload-build.ps1" -Value $UploadScript

# Install Epic Games Launcher (required for UE5)
Write-Host "Installing Epic Games Launcher..."
$LauncherUrl = "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
Invoke-WebRequest -Uri $LauncherUrl -OutFile C:\Temp\EpicInstaller.msi
Start-Process msiexec.exe -ArgumentList "/i C:\Temp\EpicInstaller.msi /quiet /norestart" -Wait

# Note: UE5 installation requires manual Epic account login
# Or use UE5 from source: https://github.com/EpicGames/UnrealEngine

# Setup CloudWatch agent
$CloudWatchUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
Invoke-WebRequest -Uri $CloudWatchUrl -OutFile C:\Temp\cloudwatch-agent.msi
Start-Process msiexec.exe -ArgumentList "/i C:\Temp\cloudwatch-agent.msi /quiet /norestart" -Wait

# Configure Windows Defender exclusions for faster builds
Add-MpPreference -ExclusionPath "C:\Program Files\Epic Games\"
Add-MpPreference -ExclusionPath "C:\GameBuilds\"
Add-MpPreference -ExclusionPath "C:\actions-runner\"

# Increase page file size (UE5 needs it)
$ComputerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$ComputerSystem.AutomaticManagedPagefile = $false
$ComputerSystem.Put()

$PageFile = Get-WmiObject -Query "Select * From Win32_PageFileSetting"
if ($PageFile) {
    $PageFile.InitialSize = 32768  # 32 GB
    $PageFile.MaximumSize = 65536  # 64 GB
    $PageFile.Put()
}

Write-Host "UE5 build server setup complete!"
Write-Host "Next steps:"
Write-Host "1. Login to Epic Games Launcher and install UE5"
Write-Host "2. Configure GitHub runner: C:\actions-runner\config.cmd --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN"
Write-Host "3. Install runner as service: C:\actions-runner\svc.cmd install"
Write-Host "4. Start service: C:\actions-runner\svc.cmd start"

</powershell>
