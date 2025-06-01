# Python scripts

## Prerequisites

Before running this project, ensure the following requirements are met:

- **Python 3.7 or later**
- A valid internet connection

## Setup Instructions

### Step 1: Create a Virtual Environment

#### Linux

```bash
mkdir "your_script_name" && cd "your_script_name"
python3 -m venv .venv
source .venv/bin/activate
```

Run this command `mkscript "your_script_name"` then add the following line:

```bash
runpy "$0" "$@"
```

#### Windows

Create a new folder with the name of your script then run the following commands:

```shell
python -m venv .venv
.venv\Scripts\activate
```

### Step 3 (optional): Install Dependencies if any

Run the following command to install the required Python packages:

```shell
pip install -r requirements.txt
```

To list your existing packages run the following inside your script directory:

```shell
pip freeze > requirements.txt
```
