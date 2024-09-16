#!/bin/bash

# Test transaction management functions

source ../sqlite-shell-lib.sh

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

echo "Testing transaction management..."

# Register error handler
sqlite_register_error_callback --callback error_handler

# Create a test database
test_db="/tmp/transaction_test.db"
rm -f "$test_db"

# Open connection
sqlite_open_connection --database "$test_db"
conn_id="$SQLITE_LAST_CONNECTION_ID"

# Create table
sqlite_query --connection-id "$conn_id" --query "CREATE TABLE test (id INTEGER PRIMARY KEY, value TEXT);"

# Begin transaction
sqlite_begin_transaction --connection-id "$conn_id"

# Insert data
sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('First');"
sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('Second');"

# Rollback transaction
sqlite_rollback_transaction --connection-id "$conn_id"

# Query data
declare -a results=()
function collect_results {
    results+=("$1|$2")
}

sqlite_query --connection-id "$conn_id" --query "SELECT id, value FROM test;" --callback collect_results

# Assert that no data was inserted
assertEquals "0" "${#results[@]}" "Transaction rollback failed"

# Begin transaction again
sqlite_begin_transaction --connection-id "$conn_id"

# Insert data
sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('Third');"
sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('Fourth');"

# Commit transaction
sqlite_commit_transaction --connection-id "$conn_id"

# Clear results
results=()

# Query data again
sqlite_query --connection-id "$conn_id" --query "SELECT id, value FROM test;" --callback collect_results

# Assert that data was inserted
assertEquals "2" "${#results[@]}" "Transaction commit failed"

# Close connection
sqlite_close_connection --connection-id "$conn_id"

echo "Transaction management test passed."
