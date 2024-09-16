#!/usr/bin/env bash

# Test record separators

source "$(which sqlite-shell-lib.sh)"

set -e

function fatal {
    echo "Fatal: $*" >&2
    exit 1
}

function assertEquals {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" != "$actual" ]]; then
        fatal "$message: Expected '$expected', got '$actual'"
    fi
}

function error_handler {
    local error_message="$1"
    local error_code="$2"
    fatal "Error Handler Invoked: $error_message (Code: $error_code)"
}

echo "Testing record separators..."

# Register error handler
sqlite_register_error_callback --callback error_handler

# Set global record separator to comma
sqlite_set_global_record_separator --separator ","

# Create a test database
test_db="/tmp/record_separator_test.db"
rm -f "$test_db"

# Open connection with global separator
sqlite_open_connection --database "$test_db"
conn_id_global="$SQLITE_LAST_CONNECTION_ID"

# Open connection with specific separator (semicolon)
sqlite_open_connection --database "$test_db" --record-separator ";"
conn_id_specific="$SQLITE_LAST_CONNECTION_ID"

# Create table and insert data
sqlite_query --connection-id "$conn_id_global" --query "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT);"
sqlite_query --connection-id "$conn_id_global" --query "INSERT INTO test (value) VALUES ('One');"
sqlite_query --connection-id "$conn_id_global" --query "INSERT INTO test (value) VALUES ('Two');"

# Collect results with global separator
declare -a results_global=()
function collect_results_global {
    results_global+=("$1,$2")
}

sqlite_query --connection-id "$conn_id_global" --query "SELECT id, value FROM test ORDER BY id;" --callback collect_results_global

# Assert results with global separator
assertEquals "2" "${#results_global[@]}" "Global separator test failed"

expected_global=("1,One" "2,Two")
for i in "${!expected_global[@]}"; do
    assertEquals "${expected_global[$i]}" "${results_global[$i]}" "Global separator result mismatch at index $i"
done

# Collect results with specific separator
declare -a results_specific=()
function collect_results_specific {
    results_specific+=("$1;$2")
}

sqlite_query --connection-id "$conn_id_specific" --query "SELECT id, value FROM test ORDER BY id;" --callback collect_results_specific

# Assert results with specific separator
assertEquals "2" "${#results_specific[@]}" "Specific separator test failed"

expected_specific=("1;One" "2;Two")
for i in "${!expected_specific[@]}"; do
    assertEquals "${expected_specific[$i]}" "${results_specific[$i]}" "Specific separator result mismatch at index $i"
done

# Close connections
sqlite_close_connection --connection-id "$conn_id_global"
sqlite_close_connection --connection-id "$conn_id_specific"

echo "Record separator test passed."
