#!/bin/bash

# ==============================================================================
# Script: webstorm_setup.sh
# Description: Idempotent WebStorm installation and configuration for Linux
# ==============================================================================

set -u

# ==============================================================================
# COLORS & LOGGING
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

separator() {
    echo -e "\n${BLUE}================= $1 =================${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_separator() {
    echo "============================================================================="
}

# ==============================================================================
# GLOBAL VARIABLES
# ==============================================================================

WEBSTORM_VERSION="2025.2.3"
INSTALL_DIR="/opt/webstorm"
DESKTOP_FILE="$HOME/.local/share/applications/webstorm.desktop"
SYMLINK_PATH="/usr/local/bin/webstorm"
DOWNLOAD_URL="https://download.jetbrains.com/webstorm/WebStorm-${WEBSTORM_VERSION}.tar.gz"
WEBSTORM_ARCHIVE="WebStorm-${WEBSTORM_VERSION}.tar.gz"
CONFIG_DIR="$HOME/.config/JetBrains"
LOGFILE="/tmp/webstorm-setup.log"

WEBSTORM_INSTALLED=0
CONFIG_APPLIED=0

# ==============================================================================
# HEADER DISPLAY
# ==============================================================================

print_header() {
  echo -e "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║        WebStorm Automatic Installation & Config          ║"
  echo "║              Version: ${WEBSTORM_VERSION}                           ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo
}

# ==============================================================================
# PREREQUISITES CHECK
# ==============================================================================

check_java() {
  if command -v java >/dev/null 2>&1; then
    local java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
    log_success "Java detected: $java_version"
    return 0
  else
    log_warning "Java not found"
    return 1
  fi
}

install_java() {
  separator "INSTALLING JAVA"

  log_info "Installing OpenJDK 17..."
  if sudo apt update && sudo apt install -y openjdk-17-jdk; then
    log_success "Java installed successfully"
    return 0
  else
    log_error "Failed to install Java"
    return 1
  fi
}

check_prerequisites() {
  separator "CHECKING PREREQUISITES"

  # Check Java
  if ! check_java; then
    read -p "Install Java? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      if ! install_java; then
          log_error "Cannot proceed without Java"
          return 1
      fi
    else
      log_error "Java is required for WebStorm"
      return 1
    fi
  fi

  # Check wget or curl
  if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    log_warning "Neither wget nor curl found"
    log_info "Installing wget..."
    sudo apt update && sudo apt install -y wget
  fi
  log_success "Download tools available"

  return 0
}

# ==============================================================================
# WEBSTORM DETECTION
# ==============================================================================

detect_webstorm() {
  local installed=0

  # Check installation directory
  if [[ -d "$INSTALL_DIR" ]]; then
    log_info "WebStorm installation found: $INSTALL_DIR"
    installed=1
  fi

  # Check symlink
  if [[ -L "$SYMLINK_PATH" ]]; then
    log_info "WebStorm symlink found: $SYMLINK_PATH"
    installed=1
  fi

  # Check desktop file
  if [[ -f "$DESKTOP_FILE" ]]; then
    log_info "WebStorm desktop shortcut found"
    installed=1
  fi

  # Check if executable exists
  if command -v webstorm >/dev/null 2>&1; then
    log_info "WebStorm command available in PATH"
    installed=1
  fi

  return $installed
}

# ==============================================================================
# DOWNLOAD FUNCTIONS
# ==============================================================================

download_webstorm() {
  separator "DOWNLOADING WEBSTORM"

  # Check if already downloaded
  if [[ -f "$WEBSTORM_ARCHIVE" ]]; then
    log_info "Archive already exists, checking integrity..."
    if tar -tzf "$WEBSTORM_ARCHIVE" >/dev/null 2>&1; then
      log_success "Using existing archive: $WEBSTORM_ARCHIVE"
      return 0
    else
      log_warning "Existing archive corrupted, re-downloading..."
      rm -f "$WEBSTORM_ARCHIVE"
    fi
  fi

  log_info "Downloading WebStorm ${WEBSTORM_VERSION}..."

  if command -v wget >/dev/null 2>&1; then
    if wget -q --show-progress -O "$WEBSTORM_ARCHIVE" "$DOWNLOAD_URL"; then
      log_success "Download completed: $WEBSTORM_ARCHIVE"
      return 0
    fi
  elif command -v curl >/dev/null 2>&1; then
    if curl -L --progress-bar -o "$WEBSTORM_ARCHIVE" "$DOWNLOAD_URL"; then
      log_success "Download completed: $WEBSTORM_ARCHIVE"
      return 0
    fi
  fi

  log_error "Download failed"
  return 1
}

# ==============================================================================
# INSTALLATION FUNCTIONS
# ==============================================================================

remove_existing_installation() {
  local removed=0

  if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Removing existing installation: $INSTALL_DIR"
    sudo rm -rf "$INSTALL_DIR"
    removed=1
  fi

  if [[ -L "$SYMLINK_PATH" ]]; then
    log_info "Removing existing symlink: $SYMLINK_PATH"
    sudo rm -f "$SYMLINK_PATH"
    removed=1
  fi

  if [[ -f "$DESKTOP_FILE" ]]; then
    log_info "Removing existing desktop file: $DESKTOP_FILE"
    rm -f "$DESKTOP_FILE"
    removed=1
  fi

  if [[ $removed -eq 1 ]]; then
    log_success "Previous installation removed"
  fi

  return 0
}

install_webstorm() {
  separator "INSTALLING WEBSTORM"

  # Create temporary directory
  local temp_dir
  if ! temp_dir=$(mktemp -d); then
    log_error "Failed to create temporary directory"
    return 1
  fi

  log_info "Extracting archive..."
  if ! tar -xzf "$WEBSTORM_ARCHIVE" -C "$temp_dir"; then
    log_error "Failed to extract archive"
    rm -rf "$temp_dir"
    return 1
  fi

  # Find extracted directory
  local extracted_dir
  extracted_dir=$(find "$temp_dir" -maxdepth 1 -name "WebStorm-*" -type d | head -1)

  if [[ -z "$extracted_dir" ]]; then
    log_error "Cannot find extracted directory"
    rm -rf "$temp_dir"
    return 1
  fi

  log_info "Installing to $INSTALL_DIR..."
  sudo mkdir -p "$(dirname "$INSTALL_DIR")"

  if ! sudo mv "$extracted_dir" "$INSTALL_DIR"; then
    log_error "Failed to move files to installation directory"
    rm -rf "$temp_dir"
    return 1
  fi

  # Set permissions
  sudo chown -R root:root "$INSTALL_DIR"
  sudo chmod +x "$INSTALL_DIR/bin/webstorm.sh"

  # Cleanup
  rm -rf "$temp_dir"

  log_success "WebStorm installed: $INSTALL_DIR"
  WEBSTORM_INSTALLED=1
  return 0
}

create_symlink() {
  log_info "Creating symlink..."

  if [[ -L "$SYMLINK_PATH" ]]; then
    log_warning "Symlink already exists, recreating..."
    sudo rm -f "$SYMLINK_PATH"
  fi

  if sudo ln -s "$INSTALL_DIR/bin/webstorm.sh" "$SYMLINK_PATH"; then
    log_success "Symlink created: $SYMLINK_PATH"
    return 0
  else
    log_error "Failed to create symlink"
    return 1
  fi
}

create_desktop_shortcut() {
  log_info "Creating desktop shortcut..."

  # Create directory if needed
  mkdir -p "$(dirname "$DESKTOP_FILE")"

  # Find icon (try multiple possible locations)
  local icon_path="$INSTALL_DIR/bin/webstorm.svg"
  if [[ ! -f "$icon_path" ]]; then
    icon_path="$INSTALL_DIR/bin/webstorm.png"
  fi

  cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebStorm
Icon=$icon_path
Exec="$INSTALL_DIR/bin/webstorm.sh" %f
Comment=JavaScript IDE by JetBrains
Categories=Development;IDE;WebDevelopment;
Terminal=false
StartupWMClass=jetbrains-webstorm
StartupNotify=true
Keywords=javascript;typescript;react;angular;vue;nodejs;
EOF

  chmod +x "$DESKTOP_FILE"

  # Update desktop database if available
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  fi

  log_success "Desktop shortcut created"
  return 0
}

# ==============================================================================
# CONFIGURATION FUNCTIONS
# ==============================================================================

create_webstorm_config() {
  separator "APPLYING WEBSTORM CONFIGURATION"

  # Create config directory
  mkdir -p "$CONFIG_DIR"

  # Find the latest WebStorm config directory or create one
  local webstorm_config_dir
  webstorm_config_dir=$(find "$CONFIG_DIR" -maxdepth 1 -name "WebStorm*" -type d | sort -V | tail -1)

  if [[ -z "$webstorm_config_dir" ]]; then
    webstorm_config_dir="$CONFIG_DIR/WebStorm${WEBSTORM_VERSION}"
    mkdir -p "$webstorm_config_dir"
  fi

  log_info "Configuration directory: $webstorm_config_dir"

  # Create options directory
  local options_dir="$webstorm_config_dir/options"
  mkdir -p "$options_dir"

  cat > "$options_dir/editor.xml" << 'EOF'
<application>
  <component name="EditorSettings">
    <option name="IS_WHITESPACES_SHOWN" value="true" />
    <option name="IS_INDENT_GUIDES_SHOWN" value="true" />
    <option name="IS_ANIMATED_SCROLLING" value="true" />
    <option name="IS_CAMEL_WORDS" value="true" />
    <option name="SHOW_INTENTION_BULB" value="true" />
    <option name="IS_FOLDING_OUTLINE_SHOWN" value="true" />
    <option name="SHOW_BREADCRUMBS" value="true" />
    <option name="USE_SOFT_WRAPS" value="CONSOLE" />
  </component>
  <component name="CodeInsightSettings">
    <option name="COMPLETION_CASE_SENSITIVE" value="2" />
    <option name="AUTOCOMPLETE_ON_CODE_COMPLETION" value="true" />
    <option name="SHOW_PARAMETER_NAME_HINTS" value="true" />
  </component>
</application>
EOF

  cat > "$options_dir/ide.general.xml" << 'EOF'
<application>
  <component name="GeneralSettings">
    <option name="confirmExit" value="false" />
    <option name="showTipsOnStartup" value="false" />
    <option name="reopenLastProject" value="true" />
    <option name="autoSaveFiles" value="true" />
  </component>
  <component name="Registry">
    <entry key="ide.instant.shutdown" value="true" />
    <entry key="editor.zero.latency.typing" value="true" />
  </component>
</application>
EOF

  cat > "$options_dir/colors.scheme.xml" << 'EOF'
<application>
  <component name="EditorColorsManagerImpl">
    <global_color_scheme name="Darcula" />
  </component>
</application>
EOF

  cat > "$options_dir/keymap.xml" << 'EOF'
<application>
  <component name="KeymapManager">
    <active_keymap name="$default" />
  </component>
</application>
EOF

  local codestyles_dir="$webstorm_config_dir/codestyles"
  mkdir -p "$codestyles_dir"

  cat > "$codestyles_dir/Default.xml" << 'EOF'
<code_scheme name="Default" version="173">
  <JSCodeStyleSettings version="0">
    <option name="INDENT_SIZE" value="2" />
    <option name="TAB_SIZE" value="2" />
    <option name="USE_DOUBLE_QUOTES" value="false" />
    <option name="SPACES_WITHIN_OBJECT_LITERAL_BRACES" value="true" />
    <option name="SPACES_WITHIN_IMPORTS" value="true" />
  </JSCodeStyleSettings>
  <TypeScriptCodeStyleSettings version="0">
    <option name="INDENT_SIZE" value="2" />
    <option name="TAB_SIZE" value="2" />
    <option name="USE_DOUBLE_QUOTES" value="false" />
    <option name="SPACES_WITHIN_OBJECT_LITERAL_BRACES" value="true" />
    <option name="SPACES_WITHIN_IMPORTS" value="true" />
  </TypeScriptCodeStyleSettings>
  <codeStyleSettings language="JavaScript">
    <option name="INDENT_SIZE" value="2" />
    <option name="CONTINUATION_INDENT_SIZE" value="2" />
    <option name="TAB_SIZE" value="2" />
  </codeStyleSettings>
  <codeStyleSettings language="TypeScript">
    <option name="INDENT_SIZE" value="2" />
    <option name="CONTINUATION_INDENT_SIZE" value="2" />
    <option name="TAB_SIZE" value="2" />
  </codeStyleSettings>
</code_scheme>
EOF

  cat > "$options_dir/code.style.schemes.xml" << 'EOF'
<application>
  <component name="CodeStyleSchemeSettings">
    <option name="CURRENT_SCHEME_NAME" value="Default" />
  </component>
</application>
EOF

  cat > "$options_dir/laf.xml" << 'EOF'
<application>
  <component name="LafManager" autodetect="false">
    <laf class-name="com.intellij.ide.ui.laf.darcula.DarculaLaf" />
  </component>
</application>
EOF

  log_success "Configuration files created"
  CONFIG_APPLIED=1
  return 0
}

# ==============================================================================
# POST-INSTALLATION
# ==============================================================================

cleanup_archive() {
  if [[ -f "$WEBSTORM_ARCHIVE" ]]; then
    log_info "Cleaning up download archive..."
    rm -f "$WEBSTORM_ARCHIVE"
    log_success "Archive removed"
  fi
}

verify_installation() {
  separator "VERIFYING INSTALLATION"

  local issues=0

  # Check installation directory
  if [[ -d "$INSTALL_DIR" ]]; then
    log_success "Installation directory: $INSTALL_DIR"
  else
    log_error "Installation directory not found"
    ((++issues))
  fi

  # Check executable
  if [[ -x "$INSTALL_DIR/bin/webstorm.sh" ]]; then
    log_success "Executable found and is runnable"
  else
    log_error "Executable not found or not executable"
    ((++issues))
  fi

  # Check symlink
  if [[ -L "$SYMLINK_PATH" ]]; then
    log_success "Symlink: $SYMLINK_PATH"
  else
    log_warning "Symlink not found"
  fi

  # Check desktop file
  if [[ -f "$DESKTOP_FILE" ]]; then
    log_success "Desktop shortcut created"
  else
    log_warning "Desktop shortcut not found"
  fi

  # Check command availability
  if command -v webstorm >/dev/null 2>&1; then
    log_success "WebStorm command available"
  else
    log_warning "WebStorm command not in PATH"
  fi

  return $issues
}

# ==============================================================================
# SUMMARY DISPLAY
# ==============================================================================

print_summary() {
  echo
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║                    INSTALLATION SUMMARY                    ║${NC}"
  echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"

  if [[ $WEBSTORM_INSTALLED -eq 1 ]]; then
      echo -e "${BLUE}║${NC} ${GREEN}📥 WebStorm:              INSTALLED${NC}                       ${BLUE}║${NC}"
  else
      echo -e "${BLUE}║${NC} ${YELLOW}📥 WebStorm:              ALREADY PRESENT${NC}                 ${BLUE}║${NC}"
  fi

  if [[ $CONFIG_APPLIED -eq 1 ]]; then
      echo -e "${BLUE}║${NC} ${GREEN}⚙️  Configuration:        APPLIED${NC}                         ${BLUE}║${NC}"
  else
      echo -e "${BLUE}║${NC} ${YELLOW}⚙️  Configuration:        SKIPPED${NC}                         ${BLUE}║${NC}"
  fi

  echo -e "${BLUE}║${NC} ${GREEN}📍 Install Location:     $INSTALL_DIR${NC}"
  printf "${BLUE}║${NC}                                                            ${BLUE}║${NC}\n"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

  echo
  log_success "Installation completed log_successfully!"
  echo
  log_info "WebStorm can be launched:"
  echo "  • Command: webstorm"
  echo "  • Desktop: Applications Menu → WebStorm"
  echo "  • Direct: $INSTALL_DIR/bin/webstorm.sh"
  echo

  log_info "Configuration location:"
  echo "  • $CONFIG_DIR"
  echo

  log_warning "First launch may take a few moments to initialize"
  echo
}

bin_version() {
  sudo rm -f /usr/local/bin/webstorm
  sudo ln -s /opt/webstorm/bin/webstorm /usr/local/bin/webstorm
  sed -i 's|Exec=.*|Exec="/opt/webstorm/bin/webstorm" %f|' ~/.local/share/applications/webstorm.desktop
  update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
}

print_uninstall_info() {
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}UNINSTALL INSTRUCTIONS${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  echo "To completely remove WebStorm:"
  echo
  echo -e "${CYAN}# Remove installation${NC}"
  echo "sudo rm -rf $INSTALL_DIR"
  echo "sudo rm -f $SYMLINK_PATH"
  echo "rm -f $DESKTOP_FILE"
  echo
  echo -e "${CYAN}# Remove all configuration and cache (optional)${NC}"
  echo "rm -rf ~/.config/JetBrains/WebStorm*"
  echo "rm -rf ~/.cache/JetBrains/WebStorm*"
  echo "rm -rf ~/.local/share/JetBrains/WebStorm*"
  echo
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================

# Debug mode
DEBUG="${1:-false}"
if [[ "$DEBUG" == "true" ]]; then
    set -x
fi

print_header

if detect_webstorm; then
  log_warning "WebStorm installation detected"
  echo
  read -p "Reinstall WebStorm? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation skipped"
    log_info "To reconfigure, remove: $CONFIG_DIR/WebStorm*"
    exit 0
  fi
fi

# Confirm installation
read -p "Proceed with WebStorm installation? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    log_warning "Installation cancelled"
    exit 0
fi

# Run installation steps
if ! check_prerequisites; then
    log_error "Prerequisites check failed"
    exit 1
fi

if ! download_webstorm; then
    log_error "Download failed"
    exit 1
fi

remove_existing_installation

if ! install_webstorm; then
    log_error "Installation failed"
    exit 1
fi

create_symlink
create_desktop_shortcut
create_webstorm_config
bin_version
cleanup_archive

if ! verify_installation; then
    log_warning "Installation completed with some issues"
fi

print_summary
print_uninstall_info

# Trap interruptions
trap 'log_error "Installation interrupted"; rm -f "$WEBSTORM_ARCHIVE" 2>/dev/null; exit 1' INT TERM
