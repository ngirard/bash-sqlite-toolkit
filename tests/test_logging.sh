#!/usr/bin/env bash

# Test logging output at different severity levels

source "$(which sqlite-shell-lib.sh)"

log "info" "Testing logging..."

export DEBUG=1  # Enable debug level logging

# Open a connection (should log info)
#conn_id=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"

# Execute a query (should log info)
sqlite_query --connection-id "$conn_id" --query "SELECT 1;"

# Cause an error to test error logging
sqlite_query --connection-id "$conn_id" --query "INVALID SQL;"

# Close the connection (should log info)
sqlite_close_connection --connection-id "$conn_id"

log "info" "Logging test passed."
exit 0
