#!/bin/bash

set -e

HORIZONTAL_DIR="$HOME/Pictures/AIwall"
[[ -d "$HORIZONTAL_DIR" ]] || HORIZONTAL_DIR="$HOME/Images/AIwall"

VERTICAL_DIR="$HOME/Pictures/hnta"
[[ -d "$VERTICAL_DIR" ]] || VERTICAL_DIR="$HOME/Images/hnta"

TOTAL_SCREENS="1"

while true; do
  for ((i=0; i<TOTAL_SCREENS; i++)); do
    IMG[i]=$(ls "$HORIZONTAL_DIR"/* | shuf -n1)
  done
  feh --bg-scale "${IMG[@]}"
  sleep 30
done

# You can launch this script to automatically change your wallpapers
# It will automatically be added by main_installer.sh

# TO KILL PROGRAM :
# sudo rm ~/.config/systemd/user/wallpaper.service
# pkill -f wallpapers-changer.sh
