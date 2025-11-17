#!/bin/bash
# Unity Build Server Setup Script

set -e

echo "Starting Unity build server setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    build-essential \
    libgconf-2-4 \
    libglu1 \
    libgtk-3-0 \
    libsoup2.4-1 \
    libwebkit2gtk-4.0-37 \
    xvfb \
    awscli \
    jq

# Install Docker for containerized builds
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install GitHub Actions Runner
cd /home/ubuntu
mkdir actions-runner && cd actions-runner

# Download latest runner (update version as needed)
RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz \
    -L https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz

tar xzf ./actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Install Unity Hub (headless)
wget -qO - https://hub.unity3d.com/linux/keys/public | apt-key add -
sh -c 'echo "deb https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'
apt-get update
apt-get install -y unityhub

# Install Unity Editor (specify version)
UNITY_VERSION="2023.2.0f1"
unity-hub install --version $UNITY_VERSION --changeset <changeset>

# Install Unity Build Support modules
unity-hub install-modules --version $UNITY_VERSION \
    --module android \
    --module ios \
    --module webgl \
    --module linux-il2cpp \
    --module windows-il2cpp

# Setup S3 sync script
cat > /usr/local/bin/upload-build.sh << 'EOF'
#!/bin/bash
BUILD_PATH=$1
S3_BUCKET="${s3_bucket}"
COMMIT_SHA=$(git rev-parse --short HEAD)

aws s3 sync $BUILD_PATH s3://$S3_BUCKET/unity/$COMMIT_SHA/ --delete
echo "Build uploaded to s3://$S3_BUCKET/unity/$COMMIT_SHA/"
EOF

chmod +x /usr/local/bin/upload-build.sh

# Setup CloudWatch agent for logging
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Create GitHub runner service
cat > /etc/systemd/system/github-runner.service << EOF
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/actions-runner
ExecStart=/home/ubuntu/actions-runner/run.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Unity build server setup complete!"
echo "Next steps:"
echo "1. Configure GitHub runner: sudo -u ubuntu /home/ubuntu/actions-runner/config.sh --url https://github.com/YOUR_ORG/YOUR_REPO --token YOUR_TOKEN"
echo "2. Start runner service: systemctl enable github-runner && systemctl start github-runner"
echo "3. Configure Unity license"
