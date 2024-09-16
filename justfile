# Set the shell to bash
set shell := ["bash", "-c"]

# Default recipe
_default:
    @just --list --unsorted

# Run all tests
test:
    @echo "Running all tests..."
    @env PATH=./src:$PATH ./tests/run_tests.sh

# Clean up temporary files and databases
clean:
    @echo "Cleaning up temporary files..."
    @rm -f /tmp/test*.db
    @rm -f /tmp/sqlite_fifo_* || true
    @rm -f /tmp/sqlite_fifo_*_* || true
    @find . -name "*.db" -type f -delete
    @find . -name "*.log" -type f -delete
    @echo "Cleanup complete."

# Run a specific test
test-one name:
    #!/usr/bin/env bash
    test_file="./tests/test_{{name}}.sh"
    if [[ -x "${test_file}" ]]; then
        echo "Running test: ${test_file}"
        env PATH=./src:$PATH "${test_file}"
    else
        echo "Not executable: ${test_file}"
    fi

# Install dependencies (if any)
install-deps:
    @echo "Installing dependencies..."
    # Add commands to install any required dependencies
    @echo "Dependencies installed."

# Format code (if needed)
format:
    @echo "Formatting code..."
    # Add commands to format code (e.g., shfmt)
    @echo "Code formatted."

# Check code style (if needed)
lint:
    @echo "Linting code..."
    # Add commands to lint code (e.g., shellcheck)
    @shellcheck src/sqlite-shell-lib.sh tests/*.sh
    @echo "Linting complete."

release:
    @ci/release.sh

# Generate a directory snapshot for the project
snapshot:
    #!/usr/bin/env bash
    project_name="$(basename "${PWD%.git}")"
    snapshot_filename="notes/${project_name}_repo_snapshot.md"
    dir2prompt > "${snapshot_filename}"
    wc -c "${snapshot_filename}"
