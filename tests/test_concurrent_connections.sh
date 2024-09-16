#!/bin/bash

# Test multiple concurrent connections

source "../sqlite-shell-lib.sh"

echo "Testing concurrent connections..."

# Open multiple connections
#conn_id1=$(sqlite_open_connection --database "/tmp/test1.db")
#conn_id2=$(sqlite_open_connection --database "/tmp/test2.db")
sqlite_open_connection --database "/tmp/test1.db"
conn_id1="$SQLITE_LAST_CONNECTION_ID"
sqlite_open_connection --database "/tmp/test2.db"
conn_id2="$SQLITE_LAST_CONNECTION_ID"

# Create tables in both databases
sqlite_query --connection-id "$conn_id1" --query "CREATE TABLE IF NOT EXISTS table1 (id INTEGER);"
sqlite_query --connection-id "$conn_id2" --query "CREATE TABLE IF NOT EXISTS table2 (id INTEGER);"

# Insert data into both databases
sqlite_query --connection-id "$conn_id1" --query "INSERT INTO table1 (id) VALUES (1);"
sqlite_query --connection-id "$conn_id2" --query "INSERT INTO table2 (id) VALUES (2);"

# Verify data
# shellcheck disable=SC2317
function check_data1 {
    local columns=("$@")
    if [[ "${columns[0]}" -ne 1 ]]; then
        echo "Data mismatch in test1.db"
        exit 1
    fi
}

# shellcheck disable=SC2317
function check_data2 {
    local columns=("$@")
    if [[ "${columns[0]}" -ne 2 ]]; then
        echo "Data mismatch in test2.db"
        exit 1
    fi
}

sqlite_query --connection-id "$conn_id1" --query "SELECT id FROM table1;" --callback check_data1
sqlite_query --connection-id "$conn_id2" --query "SELECT id FROM table2;" --callback check_data2

# Clean up
sqlite_close_connection --connection-id "$conn_id1"
sqlite_close_connection --connection-id "$conn_id2"

echo "Concurrent connections test passed."
exit 0
