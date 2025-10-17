#!/bin/bash

# LOGS COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# LOGGING FUNCTION
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}
print_separator() {
    echo "============================================================================="
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

DEBUG="$1"
if [[ "$DEBUG" == "true" ]]; then
  set -x
  log_warning "DEBUG mode activated"
fi

###################
#    FUNCTIONS    #
###################
cleanup() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "Script finished with errors (exit code: $exit_code)"
  else
    log_success "DevOps tools installation completed"
  fi

  log_info "Cleaning up..."
  sudo apt autoremove -y &>/dev/null
  sudo apt autoclean &>/dev/null
  print_separator
}
trap cleanup EXIT

_install_docker() {
  log_info "# Installing DOCKER & DOCKER COMPOSE..."

  if command -v docker &>/dev/null && docker --version &>/dev/null; then
    echo "       Docker already installed"
    if groups "$USER" | grep -q docker; then
      echo "       User already in docker group"
    else
      log_warning "Adding user to docker group"
      sudo usermod -aG docker "$USER"
      log_warning "You need to log out and back in for group changes to take effect"
    fi
    return 0
  fi

  local prereqs=(ca-certificates curl gnupg)
  local to_install=()

  for package in "${prereqs[@]}"; do
    if ! dpkg -s "$package" &>/dev/null; then
      to_install+=("$package")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    log_info "Installing prerequisites: ${to_install[*]}"
    sudo apt-get update
    sudo apt-get install -y "${to_install[@]}"
  fi

  sudo install -m 0755 -d /etc/apt/keyrings

  if [[ ! -f "/etc/apt/keyrings/docker.asc" ]]; then
    log_info "Downloading Docker GPG key..."
    if ! sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
      log_error "Failed to download Docker GPG key"
      return 1
    fi
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi

  local docker_list="/etc/apt/sources.list.d/docker.list"
  if [[ ! -f "$docker_list" ]]; then
    log_info "Adding Docker repository..."
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee "$docker_list" > /dev/null

    if ! sudo apt-get update; then
      log_error "Failed to update package list after adding Docker repo"
      return 1
    fi
  fi

  log_info "Installing Docker components..."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo usermod -aG docker "$USER"

  sudo systemctl enable docker
  sudo systemctl start docker

  log_success "Docker installed successfully"
  log_warning "You need to log out and back in to use Docker without sudo"
}

_install_kubectl_k3s() {
  log_info "# Installing KUBECTL & K3S..."

  # Install kubectl
  if command -v kubectl &>/dev/null; then
    echo "       kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'Unknown version')"
  else
    log_info "Downloading kubectl..."
    local kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)

    if [[ -z "$kubectl_version" ]]; then
      log_error "Failed to retrieve kubectl version"
      return 1
    fi

    if ! curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"; then
      log_error "Failed to download kubectl"
      return 1
    fi

    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    log_success "kubectl installed"
  fi

  # Install K3s
  if command -v k3s &>/dev/null && systemctl is-active --quiet k3s 2>/dev/null; then
    echo "       K3s already active"
  else
    log_info "Installing K3s (this may take a while)..."
    if curl -sfL https://get.k3s.io | sh -; then
      log_success "K3s installed"
    else
      log_error "K3s installation failed"
      return 1
    fi
  fi

  # Configure kubeconfig
  local kube_dir="$HOME/.kube"
  local kubeconfig="$kube_dir/config"

  mkdir -p "$kube_dir"

  if [[ ! -f "$kubeconfig" ]] || [[ "/etc/rancher/k3s/k3s.yaml" -nt "$kubeconfig" ]]; then
    log_info "Updating kubeconfig..."
    sudo cp /etc/rancher/k3s/k3s.yaml "$kubeconfig"
    sudo chown "$(id -u):$(id -g)" "$kubeconfig"
    log_success "Kubeconfig updated"
  else
    echo "       Kubeconfig up-to-date"
  fi
}

_install_k9s() {
  log_info "# Installing K9S..."

  if command -v k9s &>/dev/null; then
    echo "       K9s already installed: $(k9s version --short 2>/dev/null || echo 'Unknown version')"
    return 0
  fi

  # Fetch latest release from GitHub API
  log_info "Fetching latest K9s version..."
  local k9s_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

  if [[ -z "$k9s_version" ]]; then
    log_warning "Could not fetch latest version, using fallback v0.32.5"
    k9s_version="v0.32.5"
  fi

  local temp_file=$(mktemp --suffix=.deb)
  local k9s_url="https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_linux_amd64.deb"

  log_info "Downloading K9s ${k9s_version}..."
  if wget -q --show-progress "$k9s_url" -O "$temp_file"; then
    sudo apt install -y "$temp_file"
    rm -f "$temp_file"
    log_success "K9s installed"
  else
    log_error "Failed to download K9s"
    rm -f "$temp_file"
    return 1
  fi
}

_install_helm() {
  log_info "# Installing HELM..."

  if command -v helm &>/dev/null; then
    echo "       Helm already installed: $(helm version --short 2>/dev/null || echo 'Unknown version')"
    return 0
  fi

  local temp_script=$(mktemp)

  log_info "Downloading Helm installer..."
  if curl -fsSL -o "$temp_script" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3; then
    chmod 700 "$temp_script"
    if "$temp_script"; then
      log_success "Helm installed"
    else
      log_error "Helm installation script failed"
      rm -f "$temp_script"
      return 1
    fi
    rm -f "$temp_script"
  else
    log_error "Failed to download Helm installer"
    rm -f "$temp_script"
    return 1
  fi
}

_install_terraform() {
  log_info "# Installing TERRAFORM..."

  if command -v terraform &>/dev/null; then
    echo "       Terraform already installed: $(terraform version | head -n1)"
    return 0
  fi

  log_info "Installing prerequisites..."
  sudo apt-get update
  sudo apt-get install -y gnupg software-properties-common

  log_info "Adding HashiCorp GPG key..."
  if ! wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null; then
    log_error "Failed to add HashiCorp GPG key"
    return 1
  fi

  # Get Ubuntu codename
  local codename
  if [[ -f /etc/os-release ]]; then
    codename=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2)
  fi

  if [[ -z "$codename" ]]; then
    codename=$(lsb_release -cs 2>/dev/null)
  fi

  if [[ -z "$codename" ]]; then
    log_error "Could not determine Ubuntu codename"
    return 1
  fi

  log_info "Adding HashiCorp repository..."
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${codename} main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

  if ! sudo apt update; then
    log_error "Failed to update package list after adding HashiCorp repo"
    return 1
  fi

  sudo apt-get install -y terraform
  log_success "Terraform installed"
}


_verify_installations() {
  print_separator
  log_info "Verifying installations..."
  echo ""

  # Docker
  if command -v docker &>/dev/null; then
    log_success "✓ Docker: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
  else
    log_error "✗ Docker: Not installed"
  fi

  # kubectl
  if command -v kubectl &>/dev/null; then
    log_success "✓ kubectl: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
  else
    log_error "✗ kubectl: Not installed"
  fi

  # K3s
  if systemctl is-active --quiet k3s 2>/dev/null; then
    log_success "✓ K3s: Active"
  elif command -v k3s &>/dev/null; then
    log_warning "⚠ K3s: Installed but inactive"
  else
    log_error "✗ K3s: Not installed"
  fi

  # K9s
  if command -v k9s &>/dev/null; then
    log_success "✓ K9s: Installed"
  else
    log_error "✗ K9s: Not installed"
  fi

  # Helm
  if command -v helm &>/dev/null; then
    log_success "✓ Helm: $(helm version --short 2>/dev/null | cut -d':' -f2 | cut -d'+' -f1)"
  else
    log_error "✗ Helm: Not installed"
  fi

  # Terraform
  if command -v terraform &>/dev/null; then
    log_success "✓ Terraform: $(terraform version | head -n1 | cut -d' ' -f2)"
  else
    log_error "✗ Terraform: Not installed"
  fi

  print_separator
}

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
print_separator

_install_docker || log_warning "Docker installation failed, continuing..."
_install_kubectl_k3s || log_warning "Kubectl/K3s installation failed, continuing..."
_install_k9s || log_warning "K9s installation failed, continuing..."
_install_helm || log_warning "Helm installation failed, continuing..."
_install_terraform || log_warning "Terraform installation failed, continuing..."

_verify_installations