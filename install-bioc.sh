#!/bin/bash
# setup-bioc-run.sh
#
# This script clones the bioc-run repository, copies the bioc-run script to a directory
# where it can be run from anywhere, and then removes the cloned repository.
#
# Options:
#   --copy : Copy the bioc-run script to ~/bin/ (creating the directory if necessary).
#   --path : Copy the bioc-run script to ~/bin/ and print instructions to add it to your $PATH.
#
# Ensure you have git installed and your SSH key set up for GitHub.

# Repository details
REPO_URL="https://github.com/Bioconductor/bioc-run.git"
REPO_DIR="bioc-run"

# Function to print usage information
usage() {
  echo "Usage: $0 [--copy | --path]"
  echo "  --copy : Copy bioc-run to ~/bin/ for immediate use."
  echo "  --path : Copy bioc-run to ~/bin/ and show instructions to add ~/bin to \$PATH."
  exit 1
}

# Check for proper argument
if [ "$#" -ne 1 ]; then
  usage
fi

METHOD="$1"

# Clone the repository if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL" || { echo "Error: Failed to clone repository."; exit 1; }
else
  echo "Repository '$REPO_DIR' already exists; skipping clone."
fi

# Check that the bioc-run file exists and make it executable
if [ -f "$REPO_DIR/bioc-run" ]; then
  chmod a+x "$REPO_DIR/bioc-run" || { echo "Error: Could not set executable permission."; exit 1; }
else
  echo "Error: The bioc-run file was not found in the repository."
  exit 1
fi

# Set the destination directory (default: ~/bin)
DEST_DIR="$HOME/bin"

# Create the destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
  echo "Directory $DEST_DIR does not exist. Creating it..."
  mkdir -p "$DEST_DIR" || { echo "Error: Failed to create $DEST_DIR"; exit 1; }
fi

# Process the chosen option
case "$METHOD" in
  --copy)
    cp "$REPO_DIR/bioc-run" "$DEST_DIR/bioc-run" || { echo "Error: Could not copy bioc-run to $DEST_DIR."; exit 1; }
    echo "bioc-run has been copied to $DEST_DIR/bioc-run."
    ;;
  --path)
    cp "$REPO_DIR/bioc-run" "$DEST_DIR/bioc-run" || { echo "Error: Could not copy bioc-run to $DEST_DIR."; exit 1; }
    echo "bioc-run has been copied to $DEST_DIR/bioc-run."
    echo ""
    echo "If $DEST_DIR is not in your \$PATH, add the following line to your shell configuration file (e.g., ~/.bashrc or ~/.zshrc):"
    echo ""
    echo "export PATH=\"\$PATH:$DEST_DIR\""
    echo ""
    echo "Then reload your configuration (e.g., run 'source ~/.bashrc')."
    ;;
  *)
    usage
    ;;
esac

# Remove the cloned repository after successful installation
echo "Removing cloned repository directory '$REPO_DIR'..."
rm -rf "$REPO_DIR" || { echo "Warning: Could not remove $REPO_DIR"; }
echo "Installation complete."
