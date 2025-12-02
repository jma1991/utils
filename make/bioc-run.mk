# Use bash as the shell for running all recipe commands
SHELL := bash

# Treat each recipe line as part of a single shell session
.ONESHELL:

# Shell options:
# -e  : Exit immediately if a command fails
# -u  : Treat unset variables as errors
# -o pipefail : Return exit status of the last failed command in a pipeline
.SHELLFLAGS := -eu -o pipefail -c

# Delete output files if a recipe fails
.DELETE_ON_ERROR:

# Makefile flags:
# --warn-undefined-variables : Warn about undefined variables
# --no-builtin-rules          : Disable implicit make rules for speed and predictability
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Check GNU Make version: require >= 4.0 for .RECIPEPREFIX feature
ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif

# Change recipe prefix from tab to ">"
.RECIPEPREFIX = >

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------

# Define the Bioconductor release here
BIOC_RELEASE := RELEASE_3_21

# Define the port here
PORT := 8787

# Declare non-file targets
.PHONY : usage bioc-run bioc-rstudio bioc-bash bioc-r

# ------------------------------------------------------------
# Default help message showing available targets
# ------------------------------------------------------------
usage:
> @echo "Makefile targets:"
> @echo "  bioc-run       - Run Bioconductor Docker container"
> @echo "  bioc-rstudio   - Run Bioconductor Docker container with RStudio"
> @echo "  bioc-bash      - Run Bioconductor Docker container with bash"
> @echo "  bioc-r         - Run Bioconductor Docker container with R"

# ------------------------------------------------------------
# Targets to run Bioconductor Docker container in various modes
# Each uses the helper script bioc-run.sh
# ------------------------------------------------------------

# Run container normally (default entrypoint)
bioc-run : bioc-run.sh
> bash $^ -v $(BIOC_RELEASE) -p $(PORT) -d $(CURDIR)

# Run container with RStudio server
bioc-rstudio : bioc-run.sh
> bash $^ -v $(BIOC_RELEASE) -e rstudio -p $(PORT) -d $(CURDIR)

# Run container with interactive bash shell
bioc-bash : bioc-run.sh
> bash $^ -v $(BIOC_RELEASE) -e bash -p $(PORT) -d $(CURDIR)

# Run container with R console
bioc-r : bioc-run.sh
> bash $^ -v $(BIOC_RELEASE) -e R -p $(PORT) -d $(CURDIR)

# ------------------------------------------------------------
# Rule to download the helper script if it doesn't exist
# ------------------------------------------------------------
bioc-run.sh :
> wget -O $@ https://raw.githubusercontent.com/Bioconductor/bioc-run/refs/heads/devel/bioc-run
