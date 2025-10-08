#!/bin/bash

set -e

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
fi

###################
#    FUNCTIONS    #
###################
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
      log_error "Script finished with error. (code: $exit_code)"
  fi
  sudo apt autoremove -y
  sudo apt autoclean
  print_separator
}
trap cleanup EXIT

_install_docker() {
    log_info "# Installing DOCKER & DOCKER COMPOSE"

  if command -v docker &>/dev/null && docker --version &>/dev/null; then
    echo "Docker already installed"
    if groups $USER | grep -q docker; then
      echo "USER already in docker_group"
    else
      log_warning "Adding USER to docker_group"
      sudo usermod -aG docker $USER
      log_warning "Relog to use docker without sudo"
    fi
    return 0
  fi

  local prereqs=(ca-certificates curl gnupg)
  local to_install=()

  for package in "${prereqs[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
      to_install+=("$package")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    sudo apt-get update
    sudo apt-get install -y "${to_install[@]}"
  fi

  sudo install -m 0755 -d /etc/apt/keyrings

  if [ ! -f "/etc/apt/keyrings/docker.asc" ]; then
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
  fi

  local docker_list="/etc/apt/sources.list.d/docker.list"
  if [ ! -f "$docker_list" ]; then
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee "$docker_list" > /dev/null
    sudo apt-get update
  fi

  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo usermod -aG docker $USER
  sudo chown root:docker /var/run/docker.sock
  sudo chmod 660 /var/run/docker.sock

  sudo systemctl enable docker
  sudo systemctl start docker

  log_success "Docker installed"
}

_install_kubectl_k3s() {
  log_info "# Installing KUBECTL & K3S..."

  if command -v kubectl &>/dev/null; then
    echo "Kubectl is already installed: ($(kubectl version --client --short 2>/dev/null || echo 'Unknown version'))"
  else
    local kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    log_success "kubectl installed"
  fi

  if command -v k3s &>/dev/null && systemctl is-active --quiet k3s; then
    echo "K3s is already active."
  else
    curl -sfL https://get.k3s.io | sh -
    log_success "K3s installed"
  fi

  local kube_dir="$HOME/.kube"
  local kubeconfig="$kube_dir/config"

  mkdir -p "$kube_dir"

  if [ ! -f "$kubeconfig" ] || [ "/etc/rancher/k3s/k3s.yaml" -nt "$kubeconfig" ]; then
    sudo cp /etc/rancher/k3s/k3s.yaml "$kubeconfig"
    sudo chown $(id -u):$(id -g) "$kubeconfig"
    echo "Config updated"
  else
    log_success "Config up-to-date"
  fi
}

_install_k9s() {
  log_info "# Installing K9S..."

  if command -v k9s &>/dev/null; then
    echo "K9s is already installed ($(k9s version --short 2>/dev/null || echo 'Unknown version'))"
    return 0
  fi

  local temp_file=$(mktemp --suffix=.deb)
  local k9s_version="v0.32.5"
  local k9s_url="https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_linux_amd64.deb"

  if wget -q "$k9s_url" -O "$temp_file"; then
    sudo apt install -y "$temp_file"
    rm -f "$temp_file"
    log_success "K9s installed"
  else
    log_error "Échec du téléchargement de K9s"
    rm -f "$temp_file"
    return 1
  fi
}

_install_helm() {
  log_info "# Installing HELM..."

  if command -v helm &>/dev/null; then
    log_success "      Helm is already installed ($(helm version --short 2>/dev/null || echo 'unknown version'))"
    return 0
  fi

  local temp_script=$(mktemp)

  if curl -fsSL -o "$temp_script" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3; then
    chmod 700 "$temp_script"
    "$temp_script"
    rm -f "$temp_script"
    log_success "Helm installed"
  else
    log_error "Error: Helm installation failed"
    rm -f "$temp_script"
    return 1
  fi
}

_install_terraform() {
  log_info "Installing Terraform..."
  if ! command -v terraform; then
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

    wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

    gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt-get install
  else
    echo "Terraform is already installed"
  fi
  echo "Done"
}


_verify_installations() {
  print_separator
  log_info "Verifying installations..."

  # Docker
  if command -v docker &>/dev/null; then
    log_success "Docker: $(docker --version 2>/dev/null || echo 'Installed but service stopped')"
  else
    log_error "Docker: Not installed"
  fi

  # kubectl
  if command -v kubectl &>/dev/null; then
    log_success "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'Installed')"
  else
    log_error "kubectl: Not installed"
  fi

  # K3s
  if systemctl is-active --quiet k3s 2>/dev/null; then
    log_success "K3s: Active"
  elif command -v k3s &>/dev/null; then
    log_warning "K3s: Installed but inactive"
  else
    log_error "K3s: Not installed"
  fi

  # K9s
  if command -v k9s &>/dev/null; then
    log_success "K9s: $(k9s version --short 2>/dev/null || echo 'Installed')"
  else
    log_error "K9s: Not installed"
  fi

  # Helm
  if command -v helm &>/dev/null; then
    log_success "Helm: $(helm version --short 2>/dev/null || echo 'Installed')"
  else
    log_error "Helm: Not installed"
  fi

  print_separator
}

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
[[ $DEBUG == true ]] && log_warning "DEBUG activated"
print_separator

  _install_docker
  _install_kubectl_k3s
  _install_k9s
  _install_helm
  _install_terraform

  _verify_installations
