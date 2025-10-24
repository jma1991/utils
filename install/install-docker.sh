#!/bin/bash
# This script installs Docker on an Ubuntu system by:
# 1. Updating package information and installing prerequisite packages.
# 2. Adding Docker’s official GPG key.
# 3. Setting up the Docker APT repository.
# 4. Installing Docker Engine, CLI, containerd, and Docker plugins.
# 5. Verifying the installation by running the "hello-world" container.

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package index and install prerequisites.
echo "Updating package index and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Create directory for Docker’s GPG keyrings if it doesn’t exist.
echo "Creating directory for Docker's keyrings..."
sudo install -m 0755 -d /etc/apt/keyrings

# Add Docker's official GPG key.
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to APT sources.
echo "Adding Docker repository to APT sources..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again to include Docker packages.
echo "Updating package index with Docker packages..."
sudo apt-get update

# Install Docker Engine, CLI, containerd, and Docker plugins.
echo "Installing Docker Engine and related components..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Test Docker installation by running the hello-world container.
echo "Verifying Docker installation by running the hello-world container..."
sudo docker run hello-world

echo "Docker installation completed successfully!"
