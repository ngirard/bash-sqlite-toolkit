#!/bin/bash
# sqlite_toolkit.sh

# Function to establish a connection to an SQLite database using coproc
connect_to_db() {
  local db_name="$1"
  local db_file="$2"
  coproc "$db_name" { sqlite3 "$db_file"; }
  read -r _ <&"${COPROC[$db_name][0]}"  # Read the SQLite version information
}

# Function to execute an SQL query and retrieve the results
execute_query() {
  local db_name="$1"
  local query="$2"
  local column_separator="${3:-\t}"  # Default column separator is tab
  local row_separator="${4:-\n}"    # Default row separator is newline

  printf "%s;\n" "$query" >&"${COPROC[$db_name][1]}"
  read -r _ <&"${COPROC[$db_name][0]}"  # Read the empty line after the query

  local results=""
  while IFS= read -r line; do
    if [[ "$line" == "" ]]; then
      break
    fi
    results+="$line$row_separator"
  done <&"${COPROC[$db_name][0]}"

  printf "%s" "$results" | while IFS="$column_separator" read -r -a columns; do
    declare -A tuple
    for ((i=0; i<${#columns[@]}; i++)); do
      tuple["column_$i"]="${columns[$i]}"
    done
    printf "%s\n" "$(declare -p tuple)"
  done
}

# Function to execute a query that doesn't produce tuples
execute_non_tuple_query() {
  local db_name="$1"
  local query="$2"

  printf "%s;\n" "$query" >&"${COPROC[$db_name][1]}"
  read -r _ <&"${COPROC[$db_name][0]}"  # Read the empty line after the query
}

# Function to close a database connection
close_db_connection() {
  local db_name="$1"

  printf ".quit\n" >&"${COPROC[$db_name][1]}"
  wait "${COPROC_PID[$db_name]}"
}

# Function to handle SQLite errors
handle_sqlite_error() {
  local db_name="$1"
  local error_message="$2"

  printf "SQLite error in database '%s': %s\n" "$db_name" "$error_message" >&2
  close_db_connection "$db_name"
  exit 1
}

# Trap function to handle errors
trap_errors() {
  local db_name="$1"
  local error_message

  while IFS= read -r error_message; do
    handle_sqlite_error "$db_name" "$error_message"
  done <&"${COPROC[$db_name][0]}"
}

