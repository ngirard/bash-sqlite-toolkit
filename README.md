# Bash SQLite library

This project provides an ergonomic Bash library for Linux that leverages `coproc` to connect to an SQLite database using `sqlite3` and allows performing queries against it while retrieving results efficiently and ergonomically.

## Features

- Establishes a connection to an SQLite database using `coproc`
- Executes SQL queries and retrieves the results
- Efficiently loops through the results and recognizes tuples as pairs of `{ column name, value }`
- Configurable separators between datums within a tuple and between tuples
- Handles SQLite errors gracefully

## Installation

### Using `deb` Package

1. Download the latest `deb` package from the [Releases](https://github.com/ngirard/sqlite-shell-lib/releases) page.
2. Install the package using the following command:
   ```sh
   sudo dpkg -i sqlite-shell-lib_<version>_all.deb
   ```

   The library will be installed in `/usr/local`.

## Usage

1. Include the library in your Bash script:
   ```bash
   source /usr/local/lib/sqlite-shell-lib.sh
   ```

2. Use the provided functions to interact with SQLite databases:
   
     `connect_to_db <db_name> <db_file>`: Establishes a connection to an SQLite database.
     `execute_query <db_name> <query> [<column_separator>] [<row_separator>]`: Executes an SQL query and retrieves the results.
     `execute_non_tuple_query <db_name> <query>`: Executes a query that doesn't produce tuples.
     `close_db_connection <db_name>`: Closes a database connection.

Refer to the comments in the sqlite-shell-lib.sh file for more details on each function.
Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.
License

This project is licensed under the MIT License.

