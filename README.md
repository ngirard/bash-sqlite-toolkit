# sqlite-shell-lib

A Bash library for interacting with SQLite databases using coprocesses, allowing for efficient and concurrent database operations within shell scripts.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Opening a connection](#opening-a-connection)
  - [Executing queries](#executing-queries)
  - [Registering an error callback](#registering-an-error-callback)
  - [Setting record separators](#setting-record-separators)
  - [Listing active connections](#listing-active-connections)
  - [Closing a connection](#closing-a-connection)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features

- Persistent SQLite connections using named pipes.
- Supports multiple concurrent database connections.
- Configurable record separators, both globally and per connection.
- Unified query function for data-returning and non-returning queries.
- Automated error handling with customizable error callbacks.
- Automatic cleanup of connections on script exit.
- Detailed logging with adjustable verbosity.

## Requirements

- Bash (version 4.0 or higher recommended)
- SQLite3
- A Linux-based operating system

## Installation

Clone the repository and source the `sqlite-shell-lib.sh` file in your script:

```bash
git clone https://github.com/yourusername/sqlite-shell-lib.git
cd sqlite-shell-lib
```

In your Bash script:

```bash
source "/path/to/sqlite-shell-lib/sqlite-shell-lib.sh"
```

## Usage

### Opening a connection

```bash
connection_id=$(sqlite_open_connection --database "/path/to/database.db" [--record-separator ","])
```

- `--database`: Path to the SQLite database file.
- `--record-separator`: (Optional) Record separator for query results (default is tab `\t`).

### Executing queries

```bash
sqlite_query --connection-id "$connection_id" --query "SQL_STATEMENT" [--callback callback_function]
```

- `--connection-id`: The ID of the connection to use.
- `--query`: The SQL query to execute.
- `--callback`: (Optional) A function to process each row of the result.

### Registering an error callback

```bash
sqlite_register_error_callback --callback error_handler_function
```

- `--callback`: The name of your error handling function.

### Setting record separators

- **Global Record Separator**

  ```bash
  sqlite_set_global_record_separator --separator ","
  ```

- **Per-Connection Record Separator**

  Specify `--record-separator` when opening a connection.

### Listing active connections

```bash
sqlite_list_connections
```

### Closing a connection

```bash
sqlite_close_connection --connection-id "$connection_id"
```

## Examples

### Simple Query Execution

```bash
#!/bin/bash
source "/path/to/sqlite-shell-lib/sqlite-shell-lib.sh"

# Open a connection
sqlite_open_connection --database "/tmp/test.db"
conn_id="$SQLITE_LAST_CONNECTION_ID"

# Create a table
sqlite_query --connection-id "$conn_id" --query "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT);"

# Insert data
sqlite_query --connection-id "$conn_id" --query "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"

# Define a callback function to process query results
function process_row {
    local columns=("$@")
    echo "User ID: ${columns[0]}, Name: ${columns[1]}"
}

# Query data with a callback
sqlite_query --connection-id "$conn_id" --query "SELECT * FROM users;" --callback process_row

# Close the connection
sqlite_close_connection --connection-id "$conn_id"
```

### Using an Error Callback

```bash
function error_handler {
    local error_message="$1"
    local error_code="$2"
    echo "An error occurred: $error_message (Error Code: $error_code)"
    # Handle the error (e.g., clean up resources, notify, etc.)
}

sqlite_register_error_callback --callback error_handler
```

## Testing

A comprehensive set of test scripts is included in the `tests/` directory. To run the tests, execute the test scripts individually or use a test runner.

### Running Tests

```bash
cd tests
./run_tests.sh
```

### Test Scripts

- `test_open_close_connection.sh`: Tests opening and closing connections.
- `test_query_data.sh`: Tests executing queries that return data.
- `test_error_handling.sh`: Tests error handling and callbacks.
- `test_concurrent_connections.sh`: Tests multiple concurrent connections.
- `test_record_separator.sh`: Tests setting and using different record separators.
- `test_logging.sh`: Tests logging output at different severity levels.
- `test_transactions.sh`: Test transaction management functions.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with your improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
