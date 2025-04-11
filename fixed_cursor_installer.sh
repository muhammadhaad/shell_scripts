#!/bin/bash

# Create a log file in the current directory
LOG_FILE="$(pwd)/cursor_installer_$(date +%Y%m%d%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Cursor AI IDE Installer (v0.48.8) ==="
echo "Logging all operations to $LOG_FILE"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo $0"
  exit 1
fi

# Check if this is an update or fresh install
if [ -d "/opt/cursor" ]; then
  UPDATE_MODE=true
  echo "Existing installation detected. Running in update mode..."
else
  UPDATE_MODE=false
  echo "No existing installation detected. Running in install mode..."
fi

# Function to get currently installed version (if any)
get_current_version() {
  if [ -f "/opt/cursor/resources/app/package.json" ]; then
    grep -o '"version": "[^"]*"' /opt/cursor/resources/app/package.json | cut -d'"' -f4
  elif [ -f "/opt/cursor/version" ]; then
    cat /opt/cursor/version
  else
    echo "Not installed"
  fi
}

CURRENT_VERSION=$(get_current_version)
echo "Current version: $CURRENT_VERSION"
echo "Target version: 0.48.8"

# Install needed tools
echo "Installing dependencies..."
apt-get update
apt-get install -y curl wget

# Direct download URL to version 0.48.8
DOWNLOAD_URL="https://downloads.cursor.com/production/7801a556824585b7f2721900066bc87c4a09b743/linux/x64/Cursor-0.48.8-x86_64.AppImage"

echo "Downloading Cursor v0.48.8..."
cd /tmp
rm -f cursor-*.AppImage

echo "Using direct download URL: $DOWNLOAD_URL"
if ! wget --no-verbose -O "cursor-latest.AppImage" "$DOWNLOAD_URL"; then
  echo "Download with wget failed, trying with curl..."
  if ! curl -L -o "cursor-latest.AppImage" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download Cursor. Check your internet connection."
    exit 1
  fi
fi

# Check if download was successful
if [ ! -f "cursor-latest.AppImage" ] || [ ! -s "cursor-latest.AppImage" ]; then
  echo "Error: Downloaded file is empty or not found."
  exit 1
fi

echo "Download completed. File size: $(du -h cursor-latest.AppImage | cut -f1)"

if [ "$UPDATE_MODE" = true ]; then
  echo "Backing up user settings..."
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  mkdir -p /tmp/cursor_backup_$TIMESTAMP
  
  # Backup user settings if they exist
  if [ -d "/home/$SUDO_USER/.config/Cursor" ]; then
    cp -r /home/$SUDO_USER/.config/Cursor /tmp/cursor_backup_$TIMESTAMP/
    echo "User settings backed up to /tmp/cursor_backup_$TIMESTAMP/"
  fi
fi

echo "Removing previous Cursor installation..."
rm -rf /tmp/squashfs-root || true
rm -rf /opt/cursor || true
rm -f /usr/share/applications/cursor.desktop || true

echo "Extracting AppImage..."
chmod +x /tmp/cursor-latest.AppImage
cd /tmp
./cursor-latest.AppImage --appimage-extract

if [ ! -d "/tmp/squashfs-root" ]; then
  echo "Error: Failed to extract AppImage. The download may be corrupted."
  exit 1
fi

echo "Installing Cursor..."
# Create version file
echo "0.48.8" > /tmp/squashfs-root/version

# Move to installation directory
mv ./squashfs-root /opt/cursor
chown -R root: /opt/cursor

# Set permissions based on new structure
if [ -f "/opt/cursor/chrome-sandbox" ]; then
  chmod 4755 /opt/cursor/chrome-sandbox
fi

# Find the sandbox file if it's in a different location
SANDBOX_FILE=$(find /opt/cursor -name chrome-sandbox -type f | head -1)
if [ -n "$SANDBOX_FILE" ]; then
  chmod 4755 "$SANDBOX_FILE"
  echo "Set permissions for sandbox at $SANDBOX_FILE"
fi

# Make directories readable
find /opt/cursor -type d -exec chmod 755 {} \;

# Locate icon file for desktop entry
ICON_PATH="/usr/share/pixmaps/co.anysphere.cursor.png"
if [ -f "/opt/cursor/usr/share/pixmaps/co.anysphere.cursor.png" ]; then
  ICON_PATH="/opt/cursor/usr/share/pixmaps/co.anysphere.cursor.png"
elif [ -f "/opt/cursor/cursor.png" ]; then
  ICON_PATH="/opt/cursor/cursor.png"
else
  # Look for any PNG file that might be the icon
  FOUND_ICON=$(find /opt/cursor -name "*.png" | grep -i cursor | head -1)
  if [ -n "$FOUND_ICON" ]; then
    ICON_PATH="$FOUND_ICON"
    echo "Found icon at $ICON_PATH"
  fi
fi

echo "Creating desktop entry..."
cat > /usr/share/applications/cursor.desktop <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=/opt/cursor/AppRun
Icon=${ICON_PATH}
Type=Application
Categories=Development;
EOL

chown root: /usr/share/applications/cursor.desktop
chmod 644 /usr/share/applications/cursor.desktop

if [ "$UPDATE_MODE" = true ]; then
  echo "Restoring user settings..."
  # Restore user settings if backup exists
  if [ -d "/tmp/cursor_backup_$TIMESTAMP/Cursor" ]; then
    rm -rf /home/$SUDO_USER/.config/Cursor
    cp -r /tmp/cursor_backup_$TIMESTAMP/Cursor /home/$SUDO_USER/.config/
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/Cursor
    echo "User settings restored."
  fi
fi

# Create version file if it doesn't exist
if [ ! -f "/opt/cursor/version" ]; then
  echo "0.48.8" > /opt/cursor/version
fi

NEW_VERSION="0.48.8"
if [ "$UPDATE_MODE" = true ]; then
  echo "Update complete! Cursor AI IDE has been updated from version $CURRENT_VERSION to $NEW_VERSION."
else
  echo "Installation complete! Cursor AI IDE version $NEW_VERSION has been installed."
  echo "You can now launch Cursor AI IDE from your application menu."
fi

# Create update script for future updates
cat > /usr/local/bin/update-cursor <<EOL
#!/bin/bash
# Simple script to update Cursor AI IDE
sudo $(realpath $0)
EOL

chmod +x /usr/local/bin/update-cursor
echo "A convenient update command has been installed. Run 'update-cursor' anytime to check for updates."
echo "All installation logs have been saved to $LOG_FILE"