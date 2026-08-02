#! /bin/bash

# ==============================================================================
# Script: bootstrap.sh
#
# Description: This script will launch a battery of installations to
#              let your PC at his PRIME with Ansible !
# Prerequisite: Clone the Github repository into your files right after Linux
# installation.
#
# This script only prepare your computer to use Ansible to run & launch.
#
# Author: [-PSOWL-]
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
INVENTORY="inventories/local/hosts.yml"
PLAYBOOK="playbooks/install.yml"

# log colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# ==============================================================================

# VERIFICATIONS
if [[ ! -d "${ANSIBLE_DIR}" ]]; then
    log_error "Ansible folder was not found next to script (${SCRIPT_DIR})."
    log_error "Launch again after copying all repository."
    exit 1
fi

log_info "Updating apt..."
sudo apt-get update -qq
sudo apt update

if command -v ansible-playbook &> /dev/null; then
  INSTALLED_VERSION="$(ansible --version | head -n1)"
  log_info "Ansible is already installed: ${INSTALLED_VERSION}"
else
  log_info "Installing Ansible..."
  sudo apt-get install -y ansible ansible-lint
  # sudo apt install -y ansible-lint
  log_info "Ansible installé : $(ansible --version | head -n1)"
fi

# LAUNCHING PLAYBOOK
cd "${ANSIBLE_DIR}"

if command -v ansible-lint &> /dev/null; then
    log_info "Linting playbook before run... (informative, not blocking)..."
    ansible-lint --profile min || log_warn "ansible-lint shows some potential errors. Please check before run again."
fi

if [[ -f "requirements.yml" ]]; then
    log_info "Installation Ansible collections (requirements.yml)..."
    ansible-galaxy collection install -r requirements.yml
else
    log_warn "No requirements.yml found — Skipping."
fi

echo "You must enter your ROOT password..."
ansible-playbook \
  -i "${INVENTORY}" \
  "${PLAYBOOK}" \
  -K

log_info "Finished."
