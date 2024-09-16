#!/bin/bash

# Run all test scripts
echo "Running all tests..."

for test_script in test_*.sh; do
    echo "Executing $test_script..."
    bash "$test_script"
    if [[ $? -eq 0 ]]; then
        echo "$test_script passed."
    else
        echo "$test_script failed."
        exit 1
    fi
done

echo "All tests passed."