# Cursor AI IDE Linux Installer

This repository contains a bash script to easily install the Cursor AI IDE on Linux systems.

## Features

- Automatically downloads the latest version of Cursor AI IDE
- Handles removal of previous installations
- Sets up proper file permissions and ownership
- Creates desktop entry for easy launching
- Installs required dependencies

## Prerequisites

- Linux system with `apt` package manager
- `sudo` privileges
- Internet connection

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/muhammadhaad/shell_scripts.git
   cd shell_scripts
   ```
   
   Or download the install script directly:
   ```bash
   wget https://raw.githubusercontent.com/muhammadhaad/shell_scripts/main/install_cursor.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x install_cursor.sh
   ```

3. Run the installation script:
   ```bash
   ./install_cursor.sh
   ```