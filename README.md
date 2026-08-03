# complete_install_mint

Full configuration automation for a **Linux Mint** PC, built for fast reformatting: a single command after the OS install, and the machine gets its entire work environment back.

The project is currently being migrated from hand-written bash scripts to a structured **Ansible** setup — more robust, idempotent, and maintainable.

---

## 🎯 Goal

After a fresh format, run **a single command** to:
- configure the system (DNS, network driver, graphics driver, shell environment)
- install the required software (dev, devops, data eng...)
- restore personal configs (VSCode, themes, wallpapers)

No manual clicking around, no "don't forget to install X" sticky notes.

---

## 🚀 Quick start

```bash
git clone <repo-url>
cd complete_install_mint
./bootstrap.sh
```

`bootstrap.sh` handles everything else: installing Ansible, pulling the required collections, then running the main playbook.

> **For now**, execution is **local only**. Remote execution (on another machine over the network) is planned for a later phase — the inventory layout (`local/` / `remote/`) was designed with that in mind from the start.

---

## 🏗️ Project structure

```
complete_install_mint/
├── bootstrap.sh              # Single entry point — installs Ansible and runs the playbook
├── ansible/                  # Ansible infrastructure (migration in progress)
│   ├── ansible.cfg
│   ├── requirements.yml      # Required external Ansible collections
│   ├── inventories/
│   │   ├── local/             # Runs against the current machine
│   │   └── remote/            # (scaffolded for future remote use)
│   ├── playbooks/
│   │   └── install.yml        # Main playbook, orchestrates all roles
│   └── roles/
│       ├── prerequisites/     # Base system config (DNS, network, shell, drivers...)
│       ├── softwares/         # Software installation, by category
│       ├── consols/           # Terminal/console configuration
│       └── vscode/            # VSCode configuration
│
├── z_resources/               # Legacy bash scripts — kept for reference during
│                               # the migration, to be removed once every
│                               # equivalent Ansible role is finalized
└── configs/                   # Static config files (e.g. VSCode)
```

---

## 📦 `prerequisites` role

The first finished role. Prepares the system *before* installing any business software.

| Task file | Description |
|---|---|
| `system.yml` | System update, DNS configuration, network driver (ethernet speed), blacklisting the Nouveau driver (in favor of the proprietary Nvidia driver) |
| `shell_env.yml` | Custom `.bashrc` aliases, default terminal resizing |
| `packages.yml` | Base system packages, Flatpak + Flathub repo, Python environment (`venv`, `pip`) |
| `desktop.yml` | GTK themes, automatic wallpaper-changer service |
| `network.yml` | Network speed connection adapter

Every task is idempotent: rerunning the playbook only reapplies what actually changed.

---

## 🔧 Requirements

- Linux Mint (or an apt-compatible Ubuntu/Debian derivative)
- `sudo` access
- Internet connection (package installs, Ansible collections, Flathub...)

Everything else (Ansible, collections, dependencies) is installed automatically by `bootstrap.sh`.

---

## 🗺️ Roadmap

- [x] Ansible structure (inventories, playbook, roles)
- [x] `prerequisites` role
- [ ] `softwares` role (dev, devops, data eng)
- [ ] `consols` role
- [ ] `vscode` role
- [ ] `webstorm` role
- [ ] Centralized logging
- [ ] Remote execution support (`remote/` inventory)
- [ ] Remove legacy bash scripts once functional parity is reached

---

## 📝 Notes

- `ansible-lint` is available to check Ansible code quality (`ansible-lint --profile basic`), meant to be run manually during development.
- Secrets and remote inventories are never committed (see `.gitignore`).
- Legacy bash scripts remain in `z_resources/` as a reference until the migration is complete — they are no longer called by `bootstrap.sh`.
