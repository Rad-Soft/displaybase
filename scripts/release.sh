#!/bin/zsh
# signs, notarizes and zips a release, then signs the update feed. see docs/releasing.md
set -euo pipefail
cd "${0:A:h}/.."

: "${DEVELOPER_ID_IDENTITY:?}" "${ASC_API_KEY_ID:?}" "${ASC_API_ISSUER_ID:?}" "${ASC_API_KEY_P8:?}" "${SPARKLE_ED_PRIVATE_KEY:?}"

version=$(awk '/MARKETING_VERSION/ { print $2 }' project.yml)
number=$(awk '/CURRENT_PROJECT_VERSION/ { print $2 }' project.yml)
app=build/release/Build/Products/Release/Displaybase.app
zip=dist/Displaybase-$version.zip
feed=site/public/appcast.xml

# the feed and the app have to agree on the key, or nobody can update
public=$(swift scripts/SparklePublicKey.swift)
[[ $public == $(plutil -extract SUPublicEDKey raw Displaybase/Info.plist) ]] || { echo "signing key doesn't match Info.plist"; exit 1; }

private=$(mktemp -d)
trap 'rm -rf "$private"' EXIT
(umask 077 && print -r -- "$ASC_API_KEY_P8" > "$private/key.p8")

xcodegen generate --quiet
rm -rf build/release dist
mkdir -p dist
# no base entitlements, notarization rejects the debugger one
xcodebuild -project Displaybase.xcodeproj -scheme Displaybase -configuration Release \
  -derivedDataPath build/release -quiet \
  CODE_SIGN_STYLE=Manual DISPLAYBASE_IDENTITY="$DEVELOPER_ID_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build

# xcode signs the framework but not the helpers inside it
sign() { codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$@" }
sparkle=$app/Contents/Frameworks/Sparkle.framework/Versions/B
sign "$sparkle/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
sign "$sparkle/Autoupdate"
sign "$sparkle/Updater.app"
sign "$app/Contents/Frameworks/Sparkle.framework"
sign "$app"
codesign --verify --deep --strict "$app"

ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --key "$private/key.p8" --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID" --wait
xcrun stapler staple "$app"
rm "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose "$app"

tool=build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
signature=$(print -rn -- "$SPARKLE_ED_PRIVATE_KEY" | "$tool" --ed-key-file - -p "$zip")
cat > "$feed" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Displaybase</title>
    <item>
      <title>$version</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <link>https://github.com/Rad-Soft/displaybase/releases/tag/v$version</link>
      <sparkle:version>$number</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0.0</sparkle:minimumSystemVersion>
      <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
      <enclosure url="https://github.com/Rad-Soft/displaybase/releases/download/v$version/Displaybase-$version.zip" type="application/octet-stream" length="$(stat -f %z "$zip")" sparkle:edSignature="$signature"/>
    </item>
  </channel>
</rss>
XML
print -rn -- "$SPARKLE_ED_PRIVATE_KEY" | "$tool" --ed-key-file - "$feed"
print -rn -- "$SPARKLE_ED_PRIVATE_KEY" | "$tool" --ed-key-file - --verify "$feed"

shasum -a 256 "$zip"
