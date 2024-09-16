#!/usr/bin/env bash

# sqlite-shell-lib.sh
# Bash SQLite Library
# Allows establishing connections to SQLite databases using coprocesses,
# executing queries, and managing multiple concurrent connections.

# --- Logging Functions ---

# Logs messages with various severity levels to either the console or syslog, depending on configuration.
function log {
    local date_format="${BASHLOG_DATE_FORMAT:-+%F %T}"
    local date_s
    local level="$1"
    local upper_level="${level^^}"
    local debug_level="${DEBUG:-0}"
    local message
    local severity

    shift
    date_s=$(date "+%s")
    message=$(printf "%s" "$@")

    # Severity levels
    local -A severities=( [DEBUG]=7 [INFO]=6 [WARN]=4 [ERROR]=3 )
    severity=${severities[$upper_level]:-3}

    # Log the message based on the debug level and severity
    if (( debug_level > 0 )) || [ "$severity" -lt 7 ]; then
        if [[ "${BASHLOG_SYSLOG:-0}" -eq 1 ]]; then
            log_to_syslog "$date_s" "$upper_level" "$message" "$severity"
        else
            log_to_console "$date_format" "$upper_level" "$message"
        fi
    fi
}

# Sends log messages to the syslog service with appropriate metadata.
function log_to_syslog {
    local date_s="$1"
    local upper_level="$2"
    local message="$3"
    local severity="$4"
    local facility="${BASHLOG_SYSLOG_FACILITY:-user}"

    logger --id=$$ \
           --tag "${PROGRAM}" \
           --priority "${facility}.$severity" \
           "$message" \
      || _log_exception "logger --id=$$ -t ... \"$upper_level: $message\""
}

# Logs messages to the console, with optional JSON formatting.
function log_to_console {
    local date_format="$1"
    local upper_level="$2"
    local message="$3"
    local date
    local console_line
    local colour

    date=$(date "$date_format")

    # Define color codes
    local -A colours=( [DEBUG]='\033[34m' [INFO]='\033[32m' [WARN]='\033[33m' [ERROR]='\033[31m' [DEFAULT]='\033[0m' )
    colour="${colours[$upper_level]:-\033[31m}"

    if [ "${BASHLOG_JSON:-0}" -eq 1 ]; then
        console_line=$(printf '{"timestamp":"%s","level":"%s","message":"%s"}' "$date_s" "$upper_level" "$message")
        printf "%s\n" "$console_line" >&2
    else
        console_line="${colour}$date [$upper_level] $message${colours[DEFAULT]}"
        printf "%b\n" "$console_line" >&2
    fi
}

function _log_exception {
    local log_cmd="$1"
    log "error" "Logging Exception: ${log_cmd}"
}

# Immediately exits the script after logging a fatal error message.
function fatal {
    log error "$@"
    exit 1
}

export -f log log_to_syslog log_to_console _log_exception fatal

# --- End of Logging Functions ---

# --- Bash Version Check ---
if [[ "${BASH_VERSINFO:-0}" -lt 4 ]]; then
    fatal "Error: Bash version 4 or higher is required." >&2
fi

# Global Variables
declare -A SQLITE_CONNECTIONS_READ_FD   # Stores read file descriptors per connection
declare -A SQLITE_CONNECTIONS_WRITE_FD  # Stores write file descriptors per connection
declare -A SQLITE_CONNECTIONS_PID       # Stores PIDs per connection
declare -A SQLITE_RECORD_SEPARATORS     # Stores record separators per connection
declare SQLITE_GLOBAL_RECORD_SEPARATOR=$'\t'  # Default global record separator
declare SQLITE_ERROR_CALLBACK=""        # User-defined error handling callback
declare SQLITE_READ_TIMEOUT=5           # Timeout in seconds for reading from coprocess
declare SQLITE_LAST_CONNECTION_ID=""    # Holds the last connection ID

# Trap to ensure connections are closed upon script exit
trap 'sqlite_cleanup_all_connections' EXIT

# Registers a user-defined error handling callback function.
function sqlite_register_error_callback {
    local callback_function=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --callback)
                callback_function="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    if [[ -z "$callback_function" ]]; then
        fatal "Error callback function name must be provided with --callback"
    fi

    SQLITE_ERROR_CALLBACK="$callback_function"
    log "info" "Registered error callback: $SQLITE_ERROR_CALLBACK"
}

# Sets the global record separator.
function sqlite_set_global_record_separator {
    local separator=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --separator)
                separator="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    SQLITE_GLOBAL_RECORD_SEPARATOR="$separator"
    log "info" "Global record separator set to: $separator"
}

# Sets the read timeout for SQLite queries.
function sqlite_set_read_timeout {
    local timeout=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout)
                timeout="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        fatal "Invalid timeout value: $timeout"
    fi

    SQLITE_READ_TIMEOUT="$timeout"
    log "info" "Read timeout set to: $timeout seconds"
}
# Opens a connection to a SQLite database.
function sqlite_open_connection {
    local database=""
    local record_separator=""
    local read_fd=""
    local write_fd=""
    local pid=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --database)
                database="$2"
                shift 2
                ;;
            --record-separator)
                record_separator="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    if [[ -z "$database" ]]; then
        fatal "Database path must be provided with --database"
    fi

    # Generate unique connection ID
    printf -v connection_id 'conn_%d_%d' "$$" "$RANDOM"

    # Start sqlite3 as a coprocess
    coproc sqlite3_coproc {
        sqlite3 "$database" 2>&1
    }

    if [[ $? -ne 0 ]]; then
        fatal "Failed to start sqlite3 coprocess"
    fi

    # Duplicate the coprocess file descriptors to new file descriptors
    exec {write_fd}>&"${sqlite3_coproc[1]}"
    exec {read_fd}<&"${sqlite3_coproc[0]}"

    # Close the original coprocess file descriptors
    exec {sqlite3_coproc[1]}>&-
    exec {sqlite3_coproc[0]}<&-

    # Get the coprocess PID
    pid=$!

    # Store connection details
    SQLITE_CONNECTIONS_READ_FD["$connection_id"]=$read_fd
    SQLITE_CONNECTIONS_WRITE_FD["$connection_id"]=$write_fd
    SQLITE_CONNECTIONS_PID["$connection_id"]=$pid
    SQLITE_RECORD_SEPARATORS["$connection_id"]="${record_separator:-$SQLITE_GLOBAL_RECORD_SEPARATOR}"

    # Set the last connection ID in a global variable
    # shellcheck disable=SC2034
    SQLITE_LAST_CONNECTION_ID="$connection_id"

    log "info" "Opened SQLite connection: $connection_id (Database: $database)"
}

# Closes a SQLite database connection.
function sqlite_close_connection {
    local connection_id=""
    local read_fd=""
    local write_fd=""
    local pid=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-id)
                connection_id="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    if [[ -z "$connection_id" ]]; then
        fatal "Connection ID must be provided with --connection-id"
    fi

    read_fd=${SQLITE_CONNECTIONS_READ_FD["$connection_id"]}
    write_fd=${SQLITE_CONNECTIONS_WRITE_FD["$connection_id"]}
    pid=${SQLITE_CONNECTIONS_PID["$connection_id"]}

    if [[ -n "$read_fd" && -n "$write_fd" && -n "$pid" ]]; then
        # Send .exit command to sqlite3 process
        echo ".exit" >&"${write_fd}"

        # Close file descriptors
        exec {write_fd}>&-
        exec {read_fd}<&-

        # Wait for the coprocess to exit
        wait "$pid" 2>/dev/null

        # Unset coprocess variables
        unset 'SQLITE_CONNECTIONS_READ_FD["$connection_id"]'
        unset 'SQLITE_CONNECTIONS_WRITE_FD["$connection_id"]'
        unset 'SQLITE_CONNECTIONS_PID["$connection_id"]'
        unset 'SQLITE_RECORD_SEPARATORS["$connection_id"]'

        log "info" "Closed SQLite connection: $connection_id"
    else
        log "warn" "Connection ID not found: $connection_id"
    fi
}

# Executes a SQL query on a given connection.
function sqlite_query {
    local connection_id=""
    local sql=""
    local callback=""
    local read_fd=""
    local write_fd=""
    local record_separator=""
    local error_occurred=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-id)
                connection_id="$2"
                shift 2
                ;;
            --query)
                sql="$2"
                shift 2
                ;;
            --callback)
                callback="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    if [[ -z "$connection_id" ]]; then
        fatal "Connection ID must be provided with --connection-id"
    fi

    if [[ -z "$sql" ]]; then
        fatal "SQL query must be provided with --query"
    fi

    read_fd=${SQLITE_CONNECTIONS_READ_FD["$connection_id"]}
    write_fd=${SQLITE_CONNECTIONS_WRITE_FD["$connection_id"]}
    record_separator="${SQLITE_RECORD_SEPARATORS["$connection_id"]}"

    if [[ -z "$read_fd" || -z "$write_fd" ]]; then
        fatal "Invalid connection ID: $connection_id"
    fi

    # Determine mode and separator
    local sqlite_mode
    if [[ "$record_separator" == $'\t' ]]; then
        sqlite_mode="tabs"
    else
        sqlite_mode="list"
    fi

    # Send the SQL command to the sqlite3 process
    {
        echo ".mode $sqlite_mode"
        echo ".separator '$record_separator'"
        echo "$sql;"
        echo "SELECT 'END-OF-QUERY';"
    } >&"${write_fd}"

    # Read output until 'END-OF-QUERY' is encountered
    local line
    while true; do
        if ! IFS= read -r -t "$SQLITE_READ_TIMEOUT" -u "${read_fd}" line; then
            # If read fails or times out
            log "error" "Failed to read from SQLite process for connection $connection_id"
            error_occurred=1
            if [[ -n "$SQLITE_ERROR_CALLBACK" ]]; then
                "$SQLITE_ERROR_CALLBACK" "Read timeout or failure on connection $connection_id" 1
            fi
            break
        fi

        if [[ "$line" == "END-OF-QUERY" ]]; then
            break
        elif [[ "$line" == "Error: "* ]]; then
            log "error" "SQLite error on connection $connection_id: $line"
            error_occurred=1
            if [[ -n "$SQLITE_ERROR_CALLBACK" ]]; then
                "$SQLITE_ERROR_CALLBACK" "$line" 1
            fi
            break
        else
            if [[ -n "$callback" ]]; then
                IFS="$record_separator" read -r -a row <<< "$line"
                "$callback" "${row[@]}"
            fi
        fi
    done

    if [[ "$error_occurred" -ne 0 ]]; then
        return 1
    fi
}

# Begins a transaction on a given connection.
function sqlite_begin_transaction {
    local connection_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-id)
                connection_id="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    sqlite_query --connection-id "$connection_id" --query "BEGIN TRANSACTION;"
}

# Commits a transaction on a given connection.
function sqlite_commit_transaction {
    local connection_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-id)
                connection_id="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    sqlite_query --connection-id "$connection_id" --query "COMMIT;"
}

# Rolls back a transaction on a given connection.
function sqlite_rollback_transaction {
    local connection_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-id)
                connection_id="$2"
                shift 2
                ;;
            *)
                fatal "Unknown argument: $1"
                ;;
        esac
    done

    sqlite_query --connection-id "$connection_id" --query "ROLLBACK;"
}

# Cleans up all open connections (called on script exit).
function sqlite_cleanup_all_connections {
    for connection_id in "${!SQLITE_CONNECTIONS_PID[@]}"; do
        sqlite_close_connection --connection-id "$connection_id"
    done
    log "debug" "Cleaned up all SQLite connections."
}

# Lists all active connections.
function sqlite_list_connections {
    echo "Active SQLite connections:"
    for connection_id in "${!SQLITE_CONNECTIONS_PID[@]}"; do
        echo " - $connection_id"
    done
}

# Export library functions
export -f sqlite_register_error_callback
export -f sqlite_set_global_record_separator
export -f sqlite_set_read_timeout
export -f sqlite_open_connection
export -f sqlite_close_connection
export -f sqlite_query
export -f sqlite_begin_transaction
export -f sqlite_commit_transaction
export -f sqlite_rollback_transaction
export -f sqlite_cleanup_all_connections
export -f sqlite_list_connections

# End of Bash SQLite Library
