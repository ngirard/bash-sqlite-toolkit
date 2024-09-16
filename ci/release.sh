#!/usr/bin/env bash

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

#!/usr/bin/env bash

# Check if only the version file has been modified
if ! git diff --name-only --cached | grep -q "^version$"; then
    if [[ $(git diff --name-only) != "version" ]]; then
        fatal "The only allowed change for the release is the version file.\n"
    fi
fi

# Check if the version file exists and is not empty
if [[ ! -f version ]]; then
    fatal "Version file not found!\n"
fi

version="$(cat version)"
if [[ -z "$version" ]]; then
    fatal "Version is empty!\n"
fi

# Check if the tag already exists
if git rev-parse "v${version}" >/dev/null 2>&1; then
    fatal "Tag v${version} already exists. Please bump the version.\n"
fi

# Commit, tag, and push
# Add the version file to the commit
git add version
if ! git commit -m "Release ${version}."; then
    fatal "Git commit failed.\n"
fi

if ! git tag "v${version}"; then
    fatal "Tagging failed.\n"
fi

if ! git push; then
    fatal "Git push failed.\n"
fi

if ! git push --tags; then
    fatal "Git push tags failed.\n"
fi

log "info" "Release ${version} completed successfully.\n"
