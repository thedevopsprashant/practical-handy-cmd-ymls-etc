#!/usr/bin/env bash

#This scriptt installs awscli, docker, kubectl, helm, eksctl, terraform

set -u  # avoid undefined vars (but NOT set -e, we want resilience)

LOG_FILE="install_tools.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting DevOps Tools Installation ====="

# Helper to run steps safely
run_step() {
    STEP_NAME="$1"
    shift

    echo -e "\n--- Installing: $STEP_NAME ---"
    "$@"
    if [ $? -ne 0 ]; then
        echo "❌ $STEP_NAME installation failed. Continuing..."
    else
        echo "✅ $STEP_NAME installed successfully"
    fi
}

# Update system
run_step "System Update" sudo apt-get update -y

# Install dependencies
run_step "Dependencies" sudo apt-get install -y \
    curl unzip tar gzip ca-certificates gnupg lsb-release software-properties-common

########################################
# AWS CLI
########################################
install_aws_cli() {
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    sudo ./aws/install --update
    rm -rf aws awscliv2.zip
}
run_step "AWS CLI" install_aws_cli

########################################
# kubectl (latest stable)
########################################
install_kubectl() {
    VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
}
run_step "kubectl" install_kubectl

########################################
# eksctl (latest)
########################################
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

########################################
# Helm (latest)
########################################
install_helm() {
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}
run_step "Helm" install_helm

########################################
# Terraform (latest via HashiCorp repo)
########################################
install_terraform() {
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
        sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list

    sudo apt-get update -y
    sudo apt-get install -y terraform
}
run_step "Terraform" install_terraform

########################################
# Docker (latest official repo)
########################################
install_docker() {
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}
run_step "Docker" install_docker

########################################
# Add user to docker group
########################################
add_user_to_docker_group() {
    sudo usermod -aG docker "$USER"
    sudo usermod -aG docker ${USER} #To login again: sudo su, sudo su ubuntu
    sudo usermod -aG docker jenkins
    sudo usermod -aG docker ubuntu
    sudo systemctl restart docker
    sudo chmod 777 /var/run/docker.sock
    echo "⚠️  You may need to log out and log back in for docker group changes to take effect."
}
run_step "Add user to docker group" add_user_to_docker_group

########################################
# Verify installations
########################################
echo -e "\n===== Verification ====="

command -v aws && aws --version
command -v kubectl && kubectl version --client
command -v eksctl && eksctl version
command -v helm && helm version
command -v terraform && terraform version
command -v docker && docker --version

echo -e "\n===== Installation Completed ====="
echo "Logs saved in $LOG_FILE"
