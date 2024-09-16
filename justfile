# Set the shell to bash
set shell := ["bash", "-c"]

# Default recipe
default: test

# Recipe to run all tests
test:
    @echo "Running all tests..."
    @cd tests; ./run_tests.sh

# Recipe to clean up temporary files and databases
clean:
    @echo "Cleaning up temporary files..."
    @rm -f /tmp/test*.db
    @rm -f /tmp/sqlite_fifo_* || true
    @rm -f /tmp/sqlite_fifo_*_* || true
    @find . -name "*.db" -type f -delete
    @find . -name "*.log" -type f -delete
    @echo "Cleanup complete."

# Recipe to run a specific test
test-one test-one name:
    @echo "Running test: {{name}}"
    @bash tests/{{name}}

# Recipe to install dependencies (if any)
install-deps:
    @echo "Installing dependencies..."
    # Add commands to install any required dependencies
    @echo "Dependencies installed."

# Recipe to format code (if needed)
format:
    @echo "Formatting code..."
    # Add commands to format code (e.g., shfmt)
    @echo "Code formatted."

# Recipe to check code style (if needed)
lint:
    @echo "Linting code..."
    # Add commands to lint code (e.g., shellcheck)
    @shellcheck sqlite-shell-lib.sh tests/*.sh
    @echo "Linting complete."

# Recipe to show help
help:
    @echo "Available recipes:"
    @just --list

# Alias for help
#.PHONY: help

# Ensure recipes are always executed
#.PHONY: test clean test-one install-deps format lint
