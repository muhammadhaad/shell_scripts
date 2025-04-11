#!/bin/bash

echo "=== Cursor Version Diagnostic Tool ==="
echo "This script will check various sources to determine what versions of Cursor are available"

# Create a directory for our tests
mkdir -p ~/cursor_diagnostic
cd ~/cursor_diagnostic

echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl wget jq

echo -e "\n=== Checking Official API Endpoints ==="

# Check x64 endpoint
echo "Checking x64 API endpoint..."
curl -s "https://releases.cursor.sh/x64" > x64_release_info.json
if [ -s "x64_release_info.json" ]; then
  echo "Content found. Analyzing..."
  if command -v jq &> /dev/null; then
    VERSION=$(jq -r '.version // "unknown"' x64_release_info.json)
    URL=$(jq -r '.url // "not found"' x64_release_info.json)
    echo "x64 API reports version: $VERSION"
    echo "x64 download URL: $URL"
  else
    echo "jq not available, raw content:"
    cat x64_release_info.json
  fi
else
  echo "No content received from x64 API endpoint"
fi

# Check arm64 endpoint
echo -e "\nChecking arm64 API endpoint..."
curl -s "https://releases.cursor.sh/arm64" > arm64_release_info.json
if [ -s "arm64_release_info.json" ]; then
  echo "Content found. Analyzing..."
  if command -v jq &> /dev/null; then
    VERSION=$(jq -r '.version // "unknown"' arm64_release_info.json)
    URL=$(jq -r '.url // "not found"' arm64_release_info.json)
    echo "arm64 API reports version: $VERSION"
    echo "arm64 download URL: $URL"
  else
    echo "jq not available, raw content:"
    cat arm64_release_info.json
  fi
else
  echo "No content received from arm64 API endpoint"
fi

# Check alternative endpoint
echo -e "\nChecking alternative API endpoint..."
curl -s "https://downloader.cursor.sh/releases/linux/latest.json" > alt_release_info.json
if [ -s "alt_release_info.json" ]; then
  echo "Content found. Analyzing..."
  if command -v jq &> /dev/null; then
    echo "Data structure from alternative endpoint:"
    jq '.' alt_release_info.json
  else
    echo "jq not available, raw content:"
    cat alt_release_info.json
  fi
else
  echo "No content received from alternative API endpoint"
fi

echo -e "\n=== Checking Website for Version Information ==="
curl -s "https://cursor.sh/download" > download_page.html
VERSION_FROM_PAGE=$(grep -o "Cursor [0-9]\+\.[0-9]\+\.[0-9]\+" download_page.html | head -1 | cut -d' ' -f2)
if [ -n "$VERSION_FROM_PAGE" ]; then
  echo "Version mentioned on download page: $VERSION_FROM_PAGE"
else
  echo "Could not find version information on download page"
fi

echo -e "\n=== Testing Direct Download URLs ==="

# Function to test a download URL
test_download_url() {
  local url="$1"
  local filename="$2"
  
  echo "Testing URL: $url"
  
  # Use wget with timeout to check if the URL responds
  if wget --spider --timeout=10 "$url" 2>&1 | grep -q "200 OK"; then
    echo "URL exists and returns 200 OK"
    return 0
  elif wget --spider --timeout=10 "$url" 2>&1 | grep -q "302 Found"; then
    echo "URL exists and redirects (302 Found)"
    return 0
  else
    echo "URL either doesn't exist or requires authentication"
    return 1
  fi
}

# Test multiple potential download URLs
test_download_url "https://cursor.sh/download/linux" "cursor_website_download.AppImage"
test_download_url "https://download.cursor.sh/linux/Cursor-0.48.0.AppImage" "cursor_0.48.0.AppImage"
test_download_url "https://download.cursor.sh/linux/Cursor-0.47.0.AppImage" "cursor_0.47.0.AppImage"
test_download_url "https://download.cursor.sh/linux/Cursor-0.46.0.AppImage" "cursor_0.46.0.AppImage"
test_download_url "https://download.cursor.sh/linux/Cursor-0.45.14.AppImage" "cursor_0.45.14.AppImage"
test_download_url "https://downloader.cursor.sh/linux/appImage/x64" "cursor_default_x64.AppImage"

echo -e "\n=== Testing GitHub Releases ==="
curl -s "https://api.github.com/repos/getcursor/cursor/releases" > github_releases.json
if [ -s "github_releases.json" ]; then
  echo "Found GitHub releases information"
  if command -v jq &> /dev/null; then
    LATEST_RELEASE=$(jq '.[0].tag_name' github_releases.json)
    echo "Latest GitHub release tag: $LATEST_RELEASE"
    
    # Look for AppImage assets
    echo "Checking for Linux AppImage assets:"
    jq -r '.[0].assets[] | select(.name | contains("AppImage")) | .name + " - " + .browser_download_url' github_releases.json
  else
    echo "jq not available, can't parse GitHub API response"
  fi
else
  echo "No response from GitHub API or repository not found"
fi

echo -e "\n=== Attempting Small Download Test ==="
echo "Downloading a small portion of the file from the default endpoint to check version headers..."
curl -L -r 0-100000 -o cursor_header_sample.bin "https://downloader.cursor.sh/linux/appImage/x64"
VERSION_FROM_HEADER=$(strings cursor_header_sample.bin | grep -o "Cursor-[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1 | cut -d'-' -f2)
if [ -n "$VERSION_FROM_HEADER" ]; then
  echo "Version detected in download header: $VERSION_FROM_HEADER"
else
  echo "Could not detect version in download header"
fi

echo -e "\n=== Diagnostic Summary ==="
echo "1. Current installed version: $(grep -o '\"version\": \"[^\"]*\"' /opt/cursor/resources/app/package.json 2>/dev/null | cut -d'\"' -f4 || echo "Not installed or not found")"
echo "2. Version on download page: $VERSION_FROM_PAGE"
echo "3. Version from API endpoints: $(jq -r '.version // "unknown"' x64_release_info.json 2>/dev/null || echo "unknown")"
echo "4. Version from download header: $VERSION_FROM_HEADER"

echo -e "\nDiagnostic complete. Check the output above to understand what versions are available."
echo "All diagnostic files have been saved to ~/cursor_diagnostic/"