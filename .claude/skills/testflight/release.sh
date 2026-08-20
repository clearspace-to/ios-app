#!/bin/zsh
# TestFlight release pipeline for Clearspace Mobile.
# Usage: ./release.sh [work_dir]
# Requires: xcodegen, Xcode with iOS platform, and the App Store Connect
# API key at ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
set -euo pipefail

ASC_KEY_ID="342DVT6RFF"
ASC_ISSUER_ID="48a9d8c2-81f0-43e1-a7cb-10a8c146a5ae"
TEAM_ID="W4Y8D5GH62"
SCHEME="ClearspaceMobile"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK="${1:-$(mktemp -d)}"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"

[[ -f "$KEY_PATH" ]] || { echo "ERROR: API key not found at $KEY_PATH"; exit 1; }

cd "$REPO_ROOT"

# 1. Bump build number in project.yml (Apple rejects reused build numbers)
CURRENT=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml)
NEXT=$((CURRENT + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT\"/CURRENT_PROJECT_VERSION: \"$NEXT\"/" project.yml
echo "Build number: $CURRENT -> $NEXT"

# 2. Regenerate the Xcode project
xcodegen generate

# 3. Archive unsigned (team has no registered devices, so automatic dev
#    signing at archive time fails; distribution signing happens at export)
xcodebuild -project ${SCHEME}.xcodeproj -scheme ${SCHEME} -configuration Release \
  -destination 'generic/platform=iOS' archive \
  -archivePath "$WORK/${SCHEME}.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO | tail -3

# 4. Export with cloud-managed App Store distribution signing
cat > "$WORK/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>W4Y8D5GH62</string>
	<key>uploadSymbols</key><true/>
	<key>destination</key><string>export</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$WORK/${SCHEME}.xcarchive" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" -exportPath "$WORK/export" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" | tail -3

# 5. Upload to App Store Connect
xcrun altool --upload-app -f "$WORK/export/${SCHEME}.ipa" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo ""
echo "Uploaded build $NEXT. Apple processing takes ~5-15 min."
echo "Remember to commit the project.yml build-number bump."
