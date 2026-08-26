#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="Recorder Weather Recorder.app"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME"
DEVELOPER_ID="Developer ID Application: Sachin Kumar (M5Q7N9D29M)"
APPLE_DEVELOPMENT="Apple Development: Sachin Kumar (R8H4RTD7R3)"

cd "$PROJECT_DIR"
/usr/bin/swift build -c release

/bin/mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
/bin/cp "$PROJECT_DIR/.build/release/InterviewRecorder" "$APP_DIR/Contents/MacOS/InterviewRecorder"
/bin/cp "$PROJECT_DIR/AppResources/Info.plist" "$APP_DIR/Contents/Info.plist"

if /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "$DEVELOPER_ID"; then
    SIGNING_IDENTITY="$DEVELOPER_ID"
elif /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "$APPLE_DEVELOPMENT"; then
    SIGNING_IDENTITY="$APPLE_DEVELOPMENT"
else
    echo "No stable Apple code-signing identity is available." >&2
    echo "Refusing an ad-hoc signature because it would invalidate privacy permissions after each rebuild." >&2
    exit 1
fi

/usr/bin/codesign --force --deep --sign "$SIGNING_IDENTITY" --identifier com.sachinkumar.InterviewRecorder "$APP_DIR"

echo "$APP_DIR"
