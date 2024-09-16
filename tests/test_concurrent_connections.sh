#!/bin/bash

# Test concurrent connections with concurrent queries

source ../sqlite-shell-lib.sh

set -e

function fatal {
    echo "Fatal: $*" >&2
    exit 1
}

function error_handler {
    local error_message="$1"
    local error_code="$2"
    fatal "Error Handler Invoked: $error_message (Code: $error_code)"
}

function assertEquals {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$expected" != "$actual" ]]; then
        fatal "$message: Expected '$expected', got '$actual'"
    fi
}

log "info" "Testing concurrent connections with concurrent queries..."

# Register error handler
sqlite_register_error_callback --callback error_handler

# Create test databases
test_db1="/tmp/concurrent_test1.db"
test_db2="/tmp/concurrent_test2.db"
rm -f "$test_db1" "$test_db2"

# Open first connection
sqlite_open_connection --database "$test_db1"
conn_id1="$SQLITE_LAST_CONNECTION_ID"

# Open second connection
sqlite_open_connection --database "$test_db2"
conn_id2="$SQLITE_LAST_CONNECTION_ID"

# Function to perform queries in background
function perform_queries {
    local conn_id="$1"
    local db_name="$2"
    local result_var="$3"

    # Register error handler in subshell
    sqlite_register_error_callback --callback error_handler

    # Create table and insert data
    sqlite_query --connection-id "$conn_id" --query "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT);"
    sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('$db_name-Value1');"
    sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('$db_name-Value2');"

    # Collect results
    declare -a results=()
    function collect_results {
        results+=("$1|$2")
    }

    sqlite_query --connection-id "$conn_id" --query "SELECT id, value FROM test ORDER BY id;" --callback collect_results

    # Export results
    declare -p results > "/tmp/${db_name}_results"
}

# Perform queries concurrently
perform_queries "$conn_id1" "DB1" &
pid1=$!

perform_queries "$conn_id2" "DB2" &
pid2=$!

# Wait for background processes to finish and capture exit statuses
wait $pid1 || fatal "Background process 1 failed"
wait $pid2 || fatal "Background process 2 failed"

# Import results from temporary files
source "/tmp/DB1_results"
results1=("${results[@]}")

source "/tmp/DB2_results"
results2=("${results[@]}")

# Clean up temporary files
rm -f "/tmp/DB1_results" "/tmp/DB2_results"

# Assert results
function assertResults {
    local expected_value1="$1"
    local expected_value2="$2"
    local results=("${!3}")
    local db_name="$4"

    assertEquals "2" "${#results[@]}" "Concurrent query test failed for $db_name"

    local expected=("1|$expected_value1" "2|$expected_value2")
    for i in "${!expected[@]}"; do
        assertEquals "${expected[$i]}" "${results[$i]}" "Result mismatch for $db_name at index $i"
    done
}

assertResults "DB1-Value1" "DB1-Value2" results1[@] "DB1"
assertResults "DB2-Value1" "DB2-Value2" results2[@] "DB2"

# Close connections
sqlite_close_connection --connection-id "$conn_id1"
sqlite_close_connection --connection-id "$conn_id2"

log "info" "Concurrent connections test passed."
