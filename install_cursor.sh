#!/bin/bash

# Create a log file in the current directory
LOG_FILE="$(pwd)/cursor_installer_$(date +%Y%m%d%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Cursor AI IDE Installer/Updater ==="
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
  else
    echo "Not installed"
  fi
}

echo "Installing dependencies..."
apt-get update
apt-get install -y curl jq

# Get latest release information from Cursor API
echo "Checking for latest Cursor version..."
RELEASE_INFO=$(curl -s https://releases.cursor.sh/arm64 || curl -s https://downloader.cursor.sh/releases/linux/latest.json)

if [ -z "$RELEASE_INFO" ]; then
  echo "Failed to fetch release information. Using default download link."
  DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
  LATEST_VERSION="unknown"
else
  # Try to extract version and download URL using jq first
  if command -v jq &> /dev/null; then
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.url // .appImage.x64' 2>/dev/null)
    LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.version // "unknown"' 2>/dev/null)
    
    # Fallback if jq parsing fails
    if [ "$DOWNLOAD_URL" = "null" ] || [ -z "$DOWNLOAD_URL" ]; then
      DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
    fi
    
    if [ "$LATEST_VERSION" = "null" ] || [ -z "$LATEST_VERSION" ]; then
      LATEST_VERSION="unknown"
    fi
  else
    # Fallback if jq is not available
    DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
    LATEST_VERSION="unknown"
  fi
fi

echo "Downloading latest Cursor AppImage..."
cd /tmp
rm -f cursor-*.AppImage
echo "Download URL: $DOWNLOAD_URL"
curl -L -o "cursor-latest.AppImage" "$DOWNLOAD_URL"

# Try to extract version from the filename if it wasn't obtained from the API
if [ "$LATEST_VERSION" = "unknown" ]; then
  VERSION_FROM_FILENAME=$(ls -la cursor-latest.AppImage | grep -o 'Cursor-[0-9]\+\.[0-9]\+\.[0-9]\+' | cut -d'-' -f2 || echo "")
  if [ -n "$VERSION_FROM_FILENAME" ]; then
    LATEST_VERSION="$VERSION_FROM_FILENAME"
  fi
fi

CURRENT_VERSION=$(get_current_version)

if [ "$UPDATE_MODE" = true ]; then
  echo "Current version: $CURRENT_VERSION"
  echo "Latest version: $LATEST_VERSION"
  
  if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" != "Not installed" ]; then
    echo "You already have the latest version installed."
    echo "Force update anyway? [y/N]"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo "Update canceled."
      exit 0
    fi
  fi
  
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

echo "Installing Cursor..."
mv ./squashfs-root /opt/cursor
chown -R root: /opt/cursor
chmod 4755 /opt/cursor/chrome-sandbox
find /opt/cursor -type d -exec chmod 755 {} \;
chmod 644 /opt/cursor/cursor.png

echo "Creating desktop entry..."
cat > /usr/share/applications/cursor.desktop <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=/opt/cursor/AppRun
Icon=/opt/cursor/cursor.png
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
  
  NEW_VERSION=$(get_current_version)
  echo "Update complete! Cursor AI IDE has been updated from version $CURRENT_VERSION to $NEW_VERSION."
else
  NEW_VERSION=$(get_current_version)
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