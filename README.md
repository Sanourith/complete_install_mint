# Linux Auto-Setup Installer

This repository automates the installation and configuration of a complete, ready-to-use Linux environment.
Everything is managed from a single entry point: `main_installer.sh`.

---

## Purpose

This project is designed to:
- Prepare a clean and up-to-date Linux system.
- Automatically install a set of common tools and services (Apps, DevOps & Data softwares, etc.).
- Inject custom resources (themes, configurations, wallpapers, etc.).
- Simplify reinstallations, migrations, or development environment setups.

---

## Project Structure

```
.
├── main_installer.sh          # Main entry point script
├── z_resources/               # Miscellaneous resources (themes, configs, icons, etc.)
│ ├── 1.script.sh              # Specific installation scripts (automatically executed)
│ ├── 2.script.sh
│ ├── ...
│ ├── themes/*
│ └── wallpapers/*
└── README.md
```

---

## Usage

### 1. Clone the repository
```bash
git clone https://github.com/Sanourith/complete_install_mint.git
cd complete_install_mint
```

### 2. Make the main script executable
```bash
chmod +x main_installer.sh
```

### 3. Run the installer helper
```bash
./main_installer.sh --help
```

# WIP
How main_installer.sh Works
The main script performs the following steps:

System update

Runs apt update && apt upgrade -y

Installs basic packages (curl, git, wget, build-essential, etc.)

Automatically runs all scripts in install_scripts/

Scripts are executed in numeric order (1.*, 2.*, etc.)

Each script must be idempotent (safe to re-run without side effects).

Copies resources from z_resources/

GTK themes, icons, wallpapers, configuration files, etc.

Files are copied to the appropriate system or user directories.

Example Script in install_scripts/
```bash
#!/usr/bin/env bash
set -e

echo "=== Installing Docker ==="

if ! command -v docker &> /dev/null; then
  sudo apt install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
else
  echo "Docker already installed — skipping."
fi
```

Best Practices
All installation scripts should be idempotent (safe to re-run without changes).

Prefix files in install_scripts with a number to define execution order.

Use the z_resources folder for non-executable files (themes, configs, assets).
