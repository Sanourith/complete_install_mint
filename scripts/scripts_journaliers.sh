#!/bin/bash

echo "Launching daily scripts..."

cd "/home/psowl/work/dst_airlines_remastered"
source venv-data/bin/activate

success=0

scripts=(
  "/home/psowl/work/dst_airlines_remastered/scripts/2_flights.py"
  "/home/psowl/work/dst_airlines_remastered/scripts/4_weather.py"
  "/home/psowl/work/PERSO_sheets/INSTALLATION/AUTOMATIC_BACKUP_SAVE.sh"
)

for script in "${scripts[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "⚠️  Script not found: $script"
    continue
  fi

  script_ext=${script##*.}
  if [[ "$script_ext" == "py" ]]; then
    python3 $script
  elif [[ "$script_ext" == "sh" ]]; then
    bash $script
  else
    echo "❌ Unknown script type: $script"
  fi
done

deactivate
