#!/bin/bash

# Test setting and using different record separators

source "../sqlite-shell-lib.sh"

echo "Testing record separators..."

# Set global record separator
sqlite_set_global_record_separator --separator ","

# Open a connection without specifying a separator (should use global)
#conn_id1=$(sqlite_open_connection --database "/tmp/test.db")
sqlite_open_connection --database "/tmp/test.db"
conn_id1="$SQLITE_LAST_CONNECTION_ID"

# Open a connection with a specific separator
#conn_id2=$(sqlite_open_connection --database "/tmp/test.db" --record-separator "|")
sqlite_open_connection --database "/tmp/test.db" --record-separator "|"
conn_id2="$SQLITE_LAST_CONNECTION_ID"

# Create table and insert data
sqlite_query --connection-id "$conn_id1" --query "CREATE TABLE IF NOT EXISTS test (id INTEGER, value TEXT);"
sqlite_query --connection-id "$conn_id1" --query "INSERT INTO test (id, value) VALUES (1, 'One'), (2, 'Two');"

# Define callbacks to check separators
# shellcheck disable=SC2317
function check_separator_global {
    IFS="," read -r id value <<< "$*"
    echo "Global Separator - ID: $id, Value: $value"
}

# shellcheck disable=SC2317
function check_separator_specific {
    IFS="|" read -r id value <<< "$*"
    echo "Specific Separator - ID: $id, Value: $value"
}

# Query data
sqlite_query --connection-id "$conn_id1" --query "SELECT * FROM test;" --callback check_separator_global
sqlite_query --connection-id "$conn_id2" --query "SELECT * FROM test;" --callback check_separator_specific

# Clean up
sqlite_close_connection --connection-id "$conn_id1"
sqlite_close_connection --connection-id "$conn_id2"

echo "Record separator test passed."
exit 0
