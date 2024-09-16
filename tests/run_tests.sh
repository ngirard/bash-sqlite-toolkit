#!/usr/bin/env bash

# For logging
source "$(which sqlite-shell-lib.sh)"

# Run all test scripts
log "info" "Running all tests..."

for test_script in tests/test_*.sh; do
    log "info" "Executing $test_script..."
    bash "$test_script"
    if [[ $? -eq 0 ]]; then
        log "info" "$test_script passed."
    else
        log "error" "$test_script failed."
        exit 1
    fi
done

log "info" "All tests passed."