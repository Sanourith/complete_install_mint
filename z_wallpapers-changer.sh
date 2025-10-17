#!/bin/bash

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

# Configuration
HORIZONTAL_DIR="$HOME/Pictures/AIwall"
VERTICAL_DIR="$HOME/Pictures/hnta"
TOTAL_SCREENS="3"
SLEEP_TIME=30

log_info "Starting wallpaper changer for $TOTAL_SCREENS screens"

if ! command -v feg &> /dev/null; then
  log_error "feh is not installed"
  exit 1
fi

if [[ ! -d "$HORIZONTAL_DIR" ]]; then
  log_error "Directory not found: $HORIZONTAL_DIR"
  exit 1
fi

wallpaper_count=$(find "$HORIZONTAL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | wc -l)

if [[ $wallpaper_count -eq 0 ]]; then
  log_error "No wallpapers found in $HORIZONTAL_DIR"
  exit 1
fi

while true; do
  declare -a IMG

  for ((i=0; i<TOTAL_SCREENS; i++)); do
    selected=$(find "$HORIZONTAL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n1)

    if [[ -z "$selected" ]]; then
      log_warning "Could not select wallpaper for screen $i"
      continue
    fi

    IMG[i]="$selected"
  done

  feh --bg-scale "${IMG[@]}"
  sleep "$SLEEP_TIME"
done

# You can launch this script to automatically change your wallpapers
# It will automatically be added by main_installer.sh

# TO KILL PROGRAM :
# sudo rm ~/.config/systemd/user/wallpaper.service
# pkill -f wallpapers-changer.sh
