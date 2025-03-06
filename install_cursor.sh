#!/bin/bash

echo "=== Cursor AI IDE Installer ==="

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo $0"
  exit 1
fi

echo "Removing previous Cursor installation..."
rm -rf ./squashfs-root || true
rm -rf /opt/cursor || true
rm -f /usr/share/applications/cursor.desktop || true
rm -f /opt/cursor.appimage || true
rm -f /opt/cursor.png || true

echo "Installing dependencies..."
apt-get update
apt-get install -y curl

echo "Downloading latest Cursor AppImage..."
cd /tmp
rm -f cursor-*.AppImage
curl -JLO https://downloader.cursor.sh/linux/appImage/x64

echo "Extracting AppImage..."
chmod +x ./cursor-*.AppImage
./cursor-*.AppImage --appimage-extract

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

echo "Installation complete! You can now launch Cursor AI IDE from your application menu."