curl -L0 https://github.com/MhmRdd/Isolation-Policy/releases/download/latest/IsolPolicy-release.apk

REPO="Dr-TSNG/ZygiskNext"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "Fetching latest release information for $REPO..."

# Fetch release JSON and extract the download URL matching the zip asset
DOWNLOAD_URL=$(curl -s "$API_URL" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 | grep '\.zip$' | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find a release zip file." >&2
  exit 1
fi

FILENAME=$(basename "$DOWNLOAD_URL")
echo "Found latest asset: $FILENAME"
echo "Downloading from: $DOWNLOAD_URL"

curl -L -o "$FILENAME" "$DOWNLOAD_URL"
echo "Download complete: $FILENAME"
