#!/usr/bin/env bash

# Test opening and closing connections

source "$(which sqlite-shell-lib.sh)"

echo "Testing opening and closing connections..."

# Open a connection
#conn_id=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"
if [[ -z "$conn_id" ]]; then
    echo "Failed to open connection."
    exit 1
fi

echo "Connection opened with ID: $conn_id"

# Check if connection exists
sqlite_list_connections | grep -q "$conn_id"
if [[ $? -ne 0 ]]; then
    echo "Connection ID $conn_id not found in active connections."
    exit 1
fi

# Close the connection
sqlite_close_connection --connection-id "$conn_id"

# Check if connection is closed
sqlite_list_connections | grep -q "$conn_id"
if [[ $? -eq 0 ]]; then
    echo "Connection ID $conn_id still exists after closing."
    exit 1
fi

echo "Opening and closing connections test passed."
exit 0
