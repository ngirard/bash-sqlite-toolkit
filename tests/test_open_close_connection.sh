#!/usr/bin/env bash

# Test opening and closing connections

source "$(which sqlite-shell-lib.sh)"

log "info" "Testing opening and closing connections..."

# Open a connection
#conn_id=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"
if [[ -z "$conn_id" ]]; then
    fatal "Failed to open connection."
fi

log "info" "Connection opened with ID: $conn_id"

# Check if connection exists
sqlite_list_connections | grep -q "$conn_id"
if [[ $? -ne 0 ]]; then
    fatal "Connection ID $conn_id not found in active connections."
fi

# Close the connection
sqlite_close_connection --connection-id "$conn_id"

# Check if connection is closed
sqlite_list_connections | grep -q "$conn_id"
if [[ $? -eq 0 ]]; then
    fatal "Connection ID $conn_id still exists after closing."
fi

log "info" "Opening and closing connections test passed."
exit 0
