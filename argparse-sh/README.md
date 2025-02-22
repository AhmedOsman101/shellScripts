# argparse-sh

## Introduction

`argparse.sh` contains Bash functions that streamlines the management of command-line arguments in Bash scripts, enhancing the robustness and user-friendliness of your code. Its syntax is intentionally designed to be familiar to those who have experience with argument parsing libraries, providing a smooth and intuitive scripting experience.

## Features

- **Easy Integration**: Simply source `argparse.sh` in your script to start using.
- **Supports Various Argument Types**: Handles required, optional, and boolean flag arguments.
- **Default Values**: Define default values for optional arguments.
- **Automatic Help Generation**: Generates a help message based on defined arguments.
- **Error Handling**: Provides user-friendly error messages for missing or incorrect arguments.
- **Bash v3+ compatibility**: Use `argparse3.sh` if your script needs to support Bash v3. `argparse.sh` supports Bash v4+. 

[![asciicast](https://asciinema.org/a/627909.svg)](https://asciinema.org/a/627909)

## Installation

Clone the script repository.

```bash
git clone https://github.com/yaacov/argparse-sh.git
```

You can now source `argparse.sh` in your Bash scripts to leverage its argument parsing capabilities.

> If you need compatiblity with Bash v3+, source `argparse3.sh` instead.

```bash
source /path/to/argparse.sh
# source /path/to/argparse3.sh # Use 'argparse3.sh' if you need compatibility with Bash v3

# Your code here
```

## Usage

### Defining Arguments with `define_arg`

The `define_arg` function allows you to define a new command-line argument. The syntax is:

```bash
define_arg "arg_name" ["default"] ["help text"] ["action"] ["required"]
```

| Parameter | Description | Optional | Default |
| --- | --- | --- | --- |
| arg_name | Name of the argument | No | |
| default | Default value for the argument | Yes | "" (*) |
| help text | Description of the argument for the help message | Yes | "" |
| type | Type of the argument (string or store_true for flags) | Yes | "string" |
| required | Whether the argument is required (`required`' or `optional`) | Yes | "optional" |

*= For compatibility reasons with `argparse3.sh`, you can also use a *placeholder* to set an "empty value" in `argparse.sh`. By default, the *placeholder* value is `"null"`, but it can be defined setting the `_NULL_VALUE_` variable in `argparse.sh`.

#### Setting default empty values in `argparse3.sh`

Bash v3 does not support **associative** arrays, so we store the properties of a defined argument as a *list* (integer-indexed array).
Elements in the list are separated by spaces. That removes the ability to store the default value for an *string* argument as an empty string.
Storing the value `""` (or `" "`, or any number of blank spaces) is interpreted by Bash as "space" and thus, considered an item separator, and not a *value* in the list.

For that reason, you need to use a *placeholder* (`"null"`, by default) if you want to define an "empty string" (`""`) as the default value of an argument of type *string* in `argparse3.sh`.

By default, `argparse3.sh` uses `"null"` as the *placeholder* for an empty default value.
You can define the "empty" value changing the `_NULL_VALUE_` variable in `argparse3.sh`.

```bash
# 'argparse.sh', Bash v4+
define_arg "username" "" "name of the user" "string" "optional"
# 'argparse3.sh', Bash v3+
define_arg "username" "null" "name of the user" "string" "optional"
```

### Setting Script Description with `set_description`

The optional `set_description` function sets a description for your script, which appears at the top of the automatically generated help message. Usage is straightforward:

```bash
set_description "Your script description here"
```

When not set, the help text will show without a description text.

### Parsing Arguments with `parse_args`

After defining your arguments, use the `parse_args` function to parse the command-line inputs. Simply pass `"$@"` (the array of command-line arguments) to this function:

```bash
parse_args "$@"
```

This function will process the inputs based on the defined arguments and handle errors or help message requests automatically.

## Example

Here's a simple example of a script using argparse.sh:

```bash

#!/bin/bash

# Source the argparse script
source ./argparse.sh

# [Optional] Set script description
set_description "This is a simple script that greets the user."

# Define an argument
define_arg "name" "" "Name of the user" "string" "required"

# [Optional] Check for -h and --help
check_for_help "$@"

# Parse the arguments
parse_args "$@"

# Main script logic
echo "Hello, $name!"
```

Run this script using:

```bash
./yourscript.sh --name Alice
```

## Contributing

We warmly welcome contributions to `argparse.sh`. If you have an idea for an improvement or have spotted an issue, feel free to contribute. Start by forking the repository and cloning your fork to your local machine. Create a new branch for your feature or fix. Once you've made your changes, commit them with a clear and descriptive message. After committing your changes, push them to your fork on GitHub. Finally, submit a pull request from your branch to the main repository. We appreciate your efforts in enhancing `argparse.sh` and look forward to your valuable input!

## License

This project is licensed under the [MIT License](https://github.com/licenses/MIT).
