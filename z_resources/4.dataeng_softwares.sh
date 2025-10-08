#!/bin/bash

set -e

# LOGS COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# LOGGING FUNCTION
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
print_separator() { echo "============================================================================="; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

DEBUG="$1"
if [[ "$DEBUG" == "true" ]]; then
  set -x
fi

###################
#    FUNCTIONS    #
###################
function _install_java() {
  log_info "Installing JAVA JDK"

  if command -v java &>/dev/null && command -v javac &>/dev/null; then
    local java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
    echo "Java JDK is already installed (version: $java_version)"
    return 0
  fi

  sudo apt update
  sudo apt install -y default-jdk
  log_success "Java JDK installed"
}

function _install_pyspark() {
  log_info "Installing PYSPARK..."

  if pip show pyspark &>/dev/null; then
    local pyspark_version=$(pip show pyspark | grep Version | cut -d' ' -f2)
    echo "PySpark is already installed (version: $pyspark_version)"
    return 0
  fi

  pip install pyspark
  log_success "PySpark installed"
}

function _install_additional_data_packages() {
  log_info "# Installing packages of DATA SCIENCE"

  local packages=(
    "pandas"
    "numpy"
    "jupyter"
    "matplotlib"
    "seaborn"
    "scikit-learn"
    "requests"
    "beautifulsoup4"
    "sqlalchemy"
    "psycopg2-binary"
    "pymongo"
  )

  local to_install=()

  for package in "${packages[@]}"; do
    if ! pip show "$package" &>/dev/null; then
      to_install+=("$package")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installation des packages manquants: ${to_install[*]}"
    pip install "${to_install[@]}"
    log_success "Installed packages : ${to_install[*]}"
  else
    echo "All packages are already installed"
  fi
}

function _create_sample_notebook() {
  log_info "Creating sample PySpark notebook..."

  local notebook_dir="$SCRIPT_DIR/notebooks"
  local notebook_file="$notebook_dir/pyspark_intro.ipynb"

  mkdir -p "$notebook_dir"

  if [[ -f "$notebook_file" ]]; then
    log_warning "Notebook already exists: $notebook_file"
    return 0
  fi

  cat > "$notebook_file" << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# PySpark Introduction\n",
    "## Test de l'installation PySpark"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "from pyspark.sql import SparkSession\n",
    "import pyspark\n",
    "\n",
    "print(f\"PySpark version: {pyspark.__version__}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Créer une session Spark\n",
    "spark = SparkSession.builder \\\n",
    "    .appName(\"TestPySpark\") \\\n",
    "    .master(\"local[*]\") \\\n",
    "    .getOrCreate()\n",
    "\n",
    "print(f\"Spark UI: {spark.sparkContext.uiWebUrl}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Test simple avec des données\n",
    "data = [(\"Alice\", 34), (\"Bob\", 45), (\"Charlie\", 28)]\n",
    "columns = [\"Name\", \"Age\"]\n",
    "\n",
    "df = spark.createDataFrame(data, columns)\n",
    "df.show()"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Quelques transformations\n",
    "df.filter(df.Age > 30).show()\n",
    "df.groupBy().avg(\"Age\").show()"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Nettoyage\n",
    "spark.stop()"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.8.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

  log_success "Sample notebook created: $notebook_file"
  log_info "To open it: jupyter notebook $notebook_file"
}

function _install_dbeaver() {
  log_info "Installing DBeaver Community..."

  if command -v dbeaver &>/dev/null; then
    echo "DBeaver is already installed"
    return 0
  fi

  wget -O /tmp/dbeaver.deb https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
  sudo dpkg -i /tmp/dbeaver.deb || sudo apt-get install -f -y
  rm /tmp/dbeaver.deb

  log_success "DBeaver installed"
}

function _verify_installation() {
  log_info "Verifying installation..."
  print_separator

  # Java
  if command -v java &>/dev/null; then
    local java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2)
    log_success "Java: $java_version"
  else
    log_error "Java: NOT FOUND"
  fi

  # PySpark
  if python3 -c "import pyspark" 2>/dev/null; then
    local pyspark_version=$(python3 -c "import pyspark; print(pyspark.__version__)")
    log_success "PySpark: $pyspark_version"
  else
    log_error "PySpark: NOT FOUND"
  fi

  # Jupyter
  if command -v jupyter &>/dev/null; then
    local jupyter_version=$(jupyter --version 2>&1 | head -n1)
    log_success "Jupyter: installed"
  else
    log_error "Jupyter: NOT FOUND"
  fi

  # DBeaver
  if command -v dbeaver &>/dev/null; then
    log_success "DBeaver: installed"
  else
    log_warning "DBeaver: NOT FOUND (optional)"
  fi

  print_separator
  log_info "Installation summary:"
  echo ""
  echo "  To start Jupyter: jupyter notebook"
  echo "  Sample notebook: $SCRIPT_DIR/notebooks/pyspark_intro.ipynb"
  echo "  To test PySpark: python3 -c 'from pyspark.sql import SparkSession; print(SparkSession.builder.master(\"local\").getOrCreate())'"
  echo ""
  print_separator
}

###################
#   MAIN SCRIPT   #
###################
print_separator
log_info "Starting script: $SCRIPT_NAME"
[[ $DEBUG == true ]] && log_warning "DEBUG activated"
print_separator

_install_java
_install_dbeaver
# _install_pyspark
# _install_additional_data_packages
# _create_sample_notebook

# _verify_installation

log_success "Setup complete!"
