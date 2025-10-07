#!/bin/bash

# ==============================================================================
# Script: main_installer.sh
# Description: This script will launch a battery of installations to
#              let your PC at his PRIME !
#              If you want to skip any script from z_resources, just add "_dsbl"
# Author: [-PSOWL-]
# ==============================================================================

set -e
if [[ "$1" == "debug" || "$1" == "DEBUG" ]]; then
  set -x
fi

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
