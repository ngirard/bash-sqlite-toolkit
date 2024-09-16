#!/usr/bin/env bash

# Test executing queries that return data

source "$(which sqlite-shell-lib.sh)"

log "info" "Testing data-returning queries..."

# Open a connection
#conn_id=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"

# Create a table and insert data
sqlite_query --connection-id "$conn_id" --query "CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, value TEXT);"
sqlite_query --connection-id "$conn_id" --query "INSERT INTO test (value) VALUES ('Hello'), ('World');"

# Define a callback to process results
# shellcheck disable=SC2317
function process_row {
    local columns=("$@")
    log "info" "Row: ID=${columns[0]}, Value=${columns[1]}"
}

# Query data
sqlite_query --connection-id "$conn_id" --query "SELECT * FROM test;" --callback process_row

# Clean up
sqlite_close_connection --connection-id "$conn_id"

log "info" "Data-returning queries test passed."
exit 0
