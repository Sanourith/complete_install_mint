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
function _install_flatpak() {

}

function _install_python_suite() {

}

function _install_nvidia_drivers() {

}

function _blacklist_nouveau() {

}

function _update_system() {

}

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
[[ $DEBUG == true ]] && log_warning "DEBUG activated"
print_separator

_update_system
_blacklist_nouveau
#_install_nvidia_drivers
_install_python_suite
_install_flatpak
