#!/bin/bash
# This script installs Miniforge (a minimal conda installer) and configures conda
# with the 'nodefaults' and 'bioconda' channels.
#
# The script performs the following steps:
#   1. Determines the OS and architecture to download the appropriate installer.
#   2. Downloads the latest Miniforge installer from GitHub.
#   3. Installs Miniforge in batch (non-interactive) mode.
#   4. Initializes conda for the current shell session.
#   5. Adds the 'bioconda' and 'nodefaults' channels to your conda configuration.
#
# Exit immediately if a command exits with a non-zero status.
set -e

# Determine the operating system and machine architecture.
OS=$(uname)
ARCH=$(uname -m)
INSTALLER="Miniforge3-${OS}-${ARCH}.sh"

# Download the latest Miniforge installer.
echo "Downloading Miniforge installer for ${OS} (${ARCH})..."
wget "https://github.com/conda-forge/miniforge/releases/latest/download/${INSTALLER}"

# Install Miniforge in batch mode (-b flag) for a non-interactive installation.
echo "Installing Miniforge..."
bash "${INSTALLER}" -b

# Initialize conda for the current shell session.
echo "Initializing conda..."
eval "$($HOME/miniforge3/bin/conda shell.bash hook)"

# Add the 'bioconda' channel.
echo "Adding 'bioconda' channel..."
conda config --add channels bioconda

# Add the 'nodefaults' channel to disable the default channels.
echo "Adding 'nodefaults' channel..."
conda config --add channels nodefaults

echo "Miniforge installation and conda channel configuration completed successfully!"
