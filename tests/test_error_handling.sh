#!/bin/bash

# Test error handling and callbacks

source "../sqlite-shell-lib.sh"

echo "Testing error handling..."

# Define an error callback
# shellcheck disable=SC2317
function error_handler {
    local error_message="$1"
    local error_code="$2"
    echo "Error Callback Invoked: $error_message (Code: $error_code)"
}

sqlite_register_error_callback --callback error_handler

# Open a connection
conn_id=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"

# Execute an invalid query
sqlite_query --connection-id "$conn_id" --query "INVALID SQL STATEMENT;"

# Clean up
sqlite_close_connection --connection-id "$conn_id"

echo "Error handling test passed."
exit 0