#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_SCRIPT="$PROJECT_DIR/scripts/build_app.sh"
BUILT_APP="$PROJECT_DIR/dist/Interview Recorder.app"
INSTALLED_APP="/Applications/Interview Recorder.app"
EXECUTABLE_PATH="$INSTALLED_APP/Contents/MacOS/InterviewRecorder"
RECORDINGS_PATH="$HOME/Library/Application Support/screensessions"

cd "$PROJECT_DIR"

echo "Running tests..."
/usr/bin/swift test

echo "Building and signing the Release application..."
"$BUILD_SCRIPT"

echo "Verifying the built application..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$BUILT_APP"

CURRENT_PID=$(/usr/bin/pgrep -f "^$EXECUTABLE_PATH$" || true)
if test -n "$CURRENT_PID"; then
    ACTIVE_RECORDING=$(
        /usr/sbin/lsof -p "$CURRENT_PID" 2>/dev/null |
        /usr/bin/awk -v folder="$RECORDINGS_PATH/" '
            index($0, folder) && $NF ~ /\.mp4$/ { print $NF; exit }
        '
    )

    if test -n "$ACTIVE_RECORDING"; then
        echo "Installation stopped: a recording is active." >&2
        echo "Stop and finalize this recording first: $ACTIVE_RECORDING" >&2
        exit 42
    fi

    echo "Stopping the installed application..."
    /bin/kill "$CURRENT_PID"

    WAIT_COUNT=0
    while /bin/kill -0 "$CURRENT_PID" 2>/dev/null; do
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if test "$WAIT_COUNT" -ge 10; then
            echo "Installation stopped: the existing application did not quit safely." >&2
            echo "Quit Interview Recorder manually and run this script again." >&2
            exit 43
        fi
        /bin/sleep 1
    done
fi

echo "Deleting older build from /Applications..."
/bin/rm -rf "$INSTALLED_APP"

echo "Installing new build in /Applications..."
/usr/bin/ditto "$BUILT_APP" "$INSTALLED_APP"

echo "Verifying the installed application..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP"

echo "Launching Interview Recorder..."
/usr/bin/open "$INSTALLED_APP"
/bin/sleep 3

NEW_PID=$(/usr/bin/pgrep -f "^$EXECUTABLE_PATH$" || true)
if test -z "$NEW_PID"; then
    echo "Installation completed, but the application did not remain running." >&2
    echo "Check ~/Library/Logs/DiagnosticReports and run the app manually." >&2
    exit 44
fi

echo "Installed successfully."
echo "Application: $INSTALLED_APP"
echo "Process ID: $NEW_PID"
